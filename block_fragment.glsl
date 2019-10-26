#version 430 core

in vec4 blended_pos;
in flat int signed_orientation_f;

out vec4 color;

const vec3[] colors = {
    vec3(0.90, 0.10, 0.29), //  0 red
    vec3(0.24, 0.71, 0.29), //  1 green
    vec3(1.00, 0.88, 0.10), //  2 yellow
    vec3(0.00, 0.51, 0.78), //  3 blue
    vec3(0.96, 0.51, 0.19), //  4 orange
    vec3(0.57, 0.12, 0.71), //  5 purple
    vec3(0.27, 0.94, 0.94), //  6 cyan
    vec3(0.94, 0.20, 0.90), //  7 magenta
    vec3(0.82, 0.96, 0.24), //  8 lime
    vec3(0.98, 0.75, 0.75), //  9 pink
    vec3(0.00, 0.50, 0.50), // 10 teal
    vec3(0.90, 0.75, 1.00), // 11 lavender
    vec3(0.67, 0.43, 0.16),
    vec3(1.00, 0.98, 0.78),
    vec3(0.50, 0.00, 0.00),
    vec3(0.67, 1.00, 0.76),
    vec3(0.50, 0.50, 0.00),
    vec3(1.00, 0.84, 0.71),
    vec3(0.00, 0.00, 0.50),
    vec3(0.50, 0.50, 0.50),
    vec3(1.00, 1.00, 1.00),
    vec3(0.00, 0.00, 0.00)
};

const vec3[] colors_alt = {
    vec3(0.35, 0.30, 0.33),
    vec3(0.22, 0.13, 0.09),
    vec3(0.22, 0.13, 0.09),
    vec3(0.22, 0.13, 0.09),
    vec3(0.22, 0.13, 0.09),
    vec3(0.20, 0.10, 0.08),
    vec3(0.20, 0.10, 0.08),
    vec3(0.20, 0.10, 0.08),
    vec3(0.26, 0.13, 0.11),
    vec3(0.26, 0.13, 0.11),
    vec3(0.26, 0.13, 0.11),
    vec3(0.26, 0.13, 0.11),
    vec3(0.22, 0.13, 0.09),
    vec3(0.20, 0.10, 0.08),
    vec3(0.20, 0.10, 0.08),
    vec3(0.20, 0.10, 0.08),
    vec3(0.26, 0.13, 0.11),
    vec3(0.26, 0.13, 0.11),
    vec3(0.26, 0.13, 0.11),
    vec3(0.22, 0.13, 0.09),
    vec3(0.22, 0.13, 0.09),
    vec3(0.22, 0.13, 0.09),
    vec3(0.22, 0.13, 0.09),
    vec3(0.20, 0.10, 0.08),
    vec3(0.20, 0.10, 0.08),
    vec3(0.20, 0.10, 0.08),
    vec3(0.26, 0.13, 0.11),
    vec3(0.26, 0.13, 0.11),
    vec3(0.26, 0.13, 0.11),
    vec3(0.22, 0.13, 0.09),
    vec3(0.22, 0.13, 0.09),
    vec3(0.22, 0.13, 0.09),
    vec3(0.22, 0.13, 0.09),
    vec3(0.20, 0.10, 0.08),
    vec3(0.20, 0.10, 0.08),
    vec3(0.20, 0.10, 0.08),
    vec3(0.26, 0.13, 0.11),
    vec3(0.26, 0.13, 0.11),
    vec3(0.26, 0.13, 0.11),
    vec3(0.42, 0.16, 0.09)
};


const vec4[4][8] corner_offsets = {
    {
        vec4(0, 0, 0, 0),
        vec4(0, 1, 0, 0),
        vec4(0, 0, 1, 0),
        vec4(0, 0, 0, 1),
        vec4(0, 1, 1, 0),
        vec4(0, 1, 0, 1),
        vec4(0, 0, 1, 1),
        vec4(0, 1, 1, 1)
    },
    {
        vec4(0, 0, 0, 0),
        vec4(1, 0, 0, 0),
        vec4(0, 0, 1, 0),
        vec4(0, 0, 0, 1),
        vec4(1, 0, 1, 0),
        vec4(1, 0, 0, 1),
        vec4(0, 0, 1, 1),
        vec4(1, 0, 1, 1)
    },
    {
        vec4(0, 0, 0, 0),
        vec4(1, 0, 0, 0),
        vec4(0, 1, 0, 0),
        vec4(0, 0, 0, 1),
        vec4(1, 1, 0, 0),
        vec4(1, 0, 0, 1),
        vec4(0, 1, 0, 1),
        vec4(1, 1, 0, 1)
    },
    {
        vec4(0, 0, 0, 0),
        vec4(1, 0, 0, 0),
        vec4(0, 1, 0, 0),
        vec4(0, 0, 1, 0),
        vec4(1, 1, 0, 0),
        vec4(1, 0, 1, 0),
        vec4(0, 1, 1, 0),
        vec4(1, 1, 1, 0)
    }
};

const vec3[8] local_corners = {
    vec3(0, 0, 0),
    vec3(1, 0, 0),
    vec3(0, 1, 0),
    vec3(0, 0, 1),
    vec3(1, 1, 0),
    vec3(1, 0, 1),
    vec3(0, 1, 1),
    vec3(1, 1, 1)
};

#define UINT_MAX 0xffffffffu

#define PI 3.1415926535897932384626433832795

#if 0
// https://stackoverflow.com/questions/4200224/random-noise-functions-for-glsl
float rand(vec4 seed) {
    return fract(sin(dot(seed, vec4(12.9898, 78.233, 381.9813, 937.1512))) * 43758.5453);
}

#else
// TODO very visible patterns when using this
uint xorshift(uint a)
{
    a ^= a << 13;
    a ^= a >> 17;
    a ^= a << 5;
    return a;
}

uint urand(uint a) {
    a = (a ^ 61) ^ (a >> 16);
    a = a + (a << 3);
    a = a ^ (a >> 4);
    a = a * 0x27d4eb2d;
    a = a ^ (a >> 15);
    return a;
}

uint urand4(uvec4 seed, uint a) {
    a = urand(seed.x ^ a);
    a = urand(seed.y ^ a);
    a = urand(seed.z ^ a);
    a = urand(seed.w ^ a);
    return a;
}

vec3 urand_to_rand3(uvec3 a) {
    return a / float(UINT_MAX);
}

float urand_to_rand(uint a) {
    return a / float(UINT_MAX);
}

float rand4(uvec4 seed, uint a) {
    return urand_to_rand(urand4(seed, a));
}
#endif


void main()
{
    int unsigned_orientation = signed_orientation_f & 3;
    bool positive_orientation = signed_orientation_f > 3;

    //ivec3 sub_cube_offset;
    //vec3 local_tex_coords = modf(rescaled_tex_coords, sub_cube_offset);

    vec4 sub_cube_pos = floor(blended_pos);

    vec4 local_tex_coords = blended_pos - sub_cube_pos;

    // TODO there's almost certainly a better way to deal with these boundary issues
    vec4 adjusted_pos = blended_pos + vec4(1e-5);

    if (true) {
        vec3 c = colors[signed_orientation_f];
        uint r1 = urand4(
            // uvec4(local_tex_coords * 8),
            // urand4(uvec4(ivec4(sub_cube_pos)), 0)
            uvec4(ivec4(floor(adjusted_pos * 8))), 861706333u
            );
        uint r2 = r1;//urand(r1);
        uint r3 = r1;//urand(r2);
        //vec3 c = signed_orientation_f == 1 ? colors[1] : colors_alt[urand(r3) % colors_alt.length()];
        color = vec4(
            clamp(
                c + urand_to_rand3(uvec3(r1, r2, r3)) * 0.1,
                vec3(0, 0, 0),
                vec3(1, 1, 1)
                ),
            1.0);
    } else {
        vec3 f = vec3(
            sin(blended_pos.x * 5 * PI),
            sin(blended_pos.y * 5 * PI + PI / 3),
            sin(blended_pos.z * 5 * PI + 2 * PI / 3)
            ) * 0.3 + 0.6;

        color = vec4(mix(colors[signed_orientation_f], colors[signed_orientation_f + 8], length(f)), 1.0);
    }
}
