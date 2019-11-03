import std.functional : memoize;
import std.random : isUniformRNG, uniform, Xorshift32;
import std.traits : Parameters;

import chunk;
import matrix;
import util;



__gshared Vec4[16] rand_normal_vec4_table;
static this() {
    alias RGen = Xorshift32;

    enum SEED = 876476;
    auto rgen = RGen(SEED);
    alias gen = uniform!("[]", double, double, RGen);

    for (int i = 0; i < rand_normal_vec4_table.length; i++) {
        do {
            rand_normal_vec4_table[i] = Vec4(
                gen(-1, 1, rgen),
                gen(-1, 1, rgen),
                gen(-1, 1, rgen),
                gen(-1, 1, rgen),
                );
        } while (rand_normal_vec4_table[i].magnitude <= 1 && rand_normal_vec4_table[i].magnitude >= 1e-2);
        rand_normal_vec4_table[i].normalize();
    }
}

uint hash(uint a) {
    a = (a ^ 61) ^ (a >> 16);
    a = a + (a << 3);
    a = a ^ (a >> 4);
    a = a * 0x27d4eb2d;
    a = a ^ (a >> 15);
    return a;
}

uint hash4(T)(T v) {
    static assert(v.x.sizeof == uint.sizeof);
    uint a;
    a = hash(reinterpret!uint(v.x));
    a = hash(reinterpret!uint(v.y) ^ a);
    a = hash(reinterpret!uint(v.z) ^ a);
    a = hash(reinterpret!uint(v.w) ^ a);
    return a;
}

Vec4 rand_normal_vec4(RGen, T)(T s) if (isUniformRNG!RGen) {
    auto rgen = RGen(s);
    static if (false) {
        alias gen = uniform!("[]", double, double, RGen);
        Vec4 r = void;
        do {
            r = Vec4(
                gen(-1, 1, rgen),
                gen(-1, 1, rgen),
                gen(-1, 1, rgen),
                gen(-1, 1, rgen),
                );
        } while (r.magnitude <= 1 && r.magnitude >= 1e-2);

        return r.normalized();
    } else {
        alias gen = uniform!("[)", int, int, RGen);
        return rand_normal_vec4_table[gen(0, rand_normal_vec4_table.length, rgen)];
    }
}


double clamp(double x) {
    if (x < 0) {
        return 0;
    } else if (x > 1) {
        return 1;
    } else {
        return x;
    }
}


double smootherstep(double x) {
    x = clamp(x);
    return x * x * x * (x * (x * 6. - 15.) + 10.);
}

double lerp(double t, double a, double b) {
    return a + t * (b - a);
}


double perlin3(Vec4 pos) {
    alias RGen = Xorshift32;
    assert(pos.y == 0);
    //pos = Vec4(pos.x, 0, pos.z, pos.w);

    BlockPos[8] bps = BlockPos.flat_corners(pos);

    //writeln(pos);
    //writeln(bps);

    //Vec4[8] vs = void;
    Vec4[8] rel_vs = void;
    double[8] dps = void;
    for (int i = 0; i < 8; i++) {
        Vec4 gradient = rand_normal_vec4!RGen(hash4(bps[i]));
        //vs[i] = bps[i].to_vec4();
        rel_vs[i] = pos - bps[i].to_vec4();
        //writefln("%s: %s %s %s", i, gradient, rel_vs[i], rel_vs[i].magnitude());
        //assert(rel_vs[i].magnitude() <= 1);
        dps[i] = dot_p(rel_vs[i], gradient);
    }

    double t = smootherstep(rel_vs[0].x);
    double[4] r_a = void;
    r_a[0] = lerp(t, dps[0], dps[1]);
    r_a[1] = lerp(t, dps[2], dps[3]);
    r_a[2] = lerp(t, dps[4], dps[5]);
    r_a[3] = lerp(t, dps[6], dps[7]);

    t = smootherstep(rel_vs[0].z);
    double[2] r_b = void;
    r_b[0] = lerp(t, r_a[0], r_a[1]);
    r_b[1] = lerp(t, r_a[2], r_a[3]);

    t = smootherstep(rel_vs[0].w);
    return lerp(t, r_b[0], r_b[1]);
}

alias memo_perlin3 = memoize!(perlin3, 1024 * 1024 * 128);


struct OctaveInfo {
    float period;
    float amp;
}

double octaves(alias F, T)(auto ref const T p, auto ref const OctaveInfo[] ois) {
    double f = 0;
    foreach (oi; ois) {
        f += oi.amp * F(p * oi.period);
    }
    return f;
}


/+
 struct ChunkHeightMap {
 alias T = double;
 alias Grid = T[CHUNK_SIZE][CHUNK_SIZE][CHUNK_SIZE];

 union {
 Grid grid;
 T[CHUNK_SIZE ^^ 3] data;
 }
 }

 ChunkHeightMap gen_height_map(Vec4 pos) {
 ChunkHeightMap c = void;
 for (int i = 0)
 perlin3!Xorshift32(pos);
 }
 +/
