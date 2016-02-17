import std.stdio : writeln;
import std.format : format;
import std.conv : to;
import std.math : PI, abs, sin, cos, tan, sqrt;


float deg_to_rad(float n)
{
    return n * PI / 180;
}

struct Vec3
{
    float x;
    float y;
    float z;

    string toString()
    {
        return (data()[0..3]).to!string();
    }

    float* data()
    {
        return &x;
    }

    Vec3 opBinary(string op)(auto ref in Vec3 b) const if (op == "-" || op == "+")
    {
        return mixin("Vec3(x" ~ op ~ "b.x, y" ~ op ~ "b.y, z" ~ op ~ "b.z)");
    }

    ref Vec3 opOpAssign(string op)(auto ref in Vec3 b) if (op == "-" || op == "+")
    {
        this = mixin("this" ~ op ~ "b");
        return this;
    }

    Vec3 opBinaryRight(string op)(float a) if (op == "*")
    {
        return Vec3(a * x, a * y, a * z);
    }
}

Vec3 cross_p()(auto ref in Vec3 a, auto ref in Vec3 b)
{
    return Vec3(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x,
        );
}

float dot_p()(auto ref in Vec3 a, auto ref in Vec3 b)
{
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

float magnitude()(auto ref in Vec3 a)
{
    return sqrt(a.x * a.x + a.y * a.y + a.z * a.z);
}

Vec3 normalized()(auto ref in Vec3 a)
{
    immutable float m = magnitude(a);
    return Vec3(a.x / m, a.y / m, a.z / m);
}


struct Vec4
{
    float x;
    float y;
    float z;
    float w;

    string toString()
    {
        return (data()[0..4]).to!string();
    }

    float* data()
    {
        return &x;
    }

    float magnitude() const pure
    {
        return sqrt(x * x + y * y + z * z + w * w);
    }

    void normalize()
    {
        float m = magnitude();
        x /= m;
        y /= m;
        z /= m;
        w /= m;
    }

    Vec4 opBinary(string op)(auto ref in Vec4 b) const if (op == "-" || op == "+")
    {
        return mixin("Vec4(x" ~ op ~ "b.x, y" ~ op ~ "b.y, z" ~ op ~ "b.z, w" ~ op ~ "b.w)");
    }

    Vec4 opBinary(string op)(float b) const if (op == "*" || op == "/")
    {
        return mixin("Vec4(x " ~ op ~ " b, y " ~ op ~ " b, z " ~ op ~ " b, w " ~ op ~ " b)");
    }

    Vec4 opBinaryRight(string op)(float a) const if (op == "*" || op == "/")
    {
        return mixin("Vec4(a " ~ op ~ " x, a " ~ op ~ " y, a " ~ op ~ " z, a " ~ op ~ " w)");
    }

    ref Vec4 opOpAssign(string op)(auto ref in Vec4 b) if (op == "-" || op == "+")
    {
        this = mixin("this" ~ op ~ "b");
        return this;
    }
}

Vec4 cross_p()(auto ref in Vec4 a, auto ref in Vec4 b, auto ref in Vec4 c) pure
{
    // TODO: this can be optimized, see http://steve.hollasch.net/thesis/chapter2.html
    return Vec4(
        a.w * b.y * c.z - a.w * c.y * b.z - b.w * a.y * c.z + b.w * c.y * a.z + c.w * a.y * b.z - c.w * b.y * a.z,
        -a.w * b.x * c.z + a.w * c.x * b.z + b.w * a.x * c.z - b.w * c.x * a.z - c.w * a.x * b.z + c.w * b.x * a.z,
        a.w * b.x * c.y - a.w * c.x * b.y - b.w * a.x * c.y + b.w * c.x * a.y + c.w * a.x * b.y - c.w * b.x * a.y,
        -a.x * b.y * c.z + a.x * c.y * b.z + b.x * a.y * c.z - b.x * c.y * a.z - c.x * a.y * b.z + c.x * b.y * a.z
        );
}

float dot_p()(auto ref in Vec4 a, auto ref in Vec4 b) pure
{
    return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;
}

Vec4 ewise_p()(auto ref in Vec4 a, auto ref in Vec4 b) pure
{
    return Vec4(a.x * b.x, a.y * b.y, a.z * b.z, a.w * b.w);
}

Vec4 normalized()(auto ref in Vec4 a) pure
{
    immutable float m = a.magnitude();
    return Vec4(a.x / m, a.y / m, a.z / m, a.w / m);
}


struct EMV3
{
    // scalar part
    float s;
    // bivector part
    Vec3 b;

    string toString()
    {
        return (data()[0..4]).to!string();
    }

    float* data()
    {
        return &s;
    }

    this(float angle, Vec3 axis)
    {
        assert(abs(axis.magnitude() - 1) < 0.0001);
        s = cos(angle / 2);
        b = sin(angle / 2) * axis;
    }

    this(float s_, float bx, float by, float bz)
    {
        s = s_;
        b.x = bx;
        b.y = by;
        b.z = bz;
    }

    float magnitude()
    {
        return sqrt(s * s + b.x * b.x + b.y * b.y + b.z * b.z);
    }

    void normalize()
    {
        float m = magnitude();
        s /= m;
        b.x /= m;
        b.y /= m;
        b.z /= m;
    }

    EMV3 conj() const
    {
        return EMV3(s, -b.x, -b.y, -b.z);
    }

    Mat4 to_Mat4()
    {
        return Mat4(
            1 - 2 * b.y * b.y - 2 * b.z * b.z,
            2 * (b.x * b.y + b.z * s),
            2 * (b.x * b.z - b.y * s),
            0,

            2 * (b.x * b.y - b.z * s),
            1 - 2 * b.x * b.x - 2 * b.z * b.z,
            2 * (b.y * b.z + b.x * s),
            0,

            2 * (b.x * b.z + b.y * s),
            2 * (b.y * b.z - b.x * s),
            1 - 2 * b.x * b.x - 2 * b.y * b.y,
            0,

            0,
            0,
            0,
            1,
            );
    }

    Vec3 to_Vec3()
    {
        //return b.normalized();
        if (s != 0)
        {
            //writeln("scalar not zero, normalizing: ", s);
            s = 0;
            normalize();
        }
        return b;
    }


    EMV3 opBinary(string op)(auto ref in EMV3 rhs) const if (op == "*")
    {
        return EMV3(
            s * rhs.s - b.x * rhs.b.x - b.y * rhs.b.y - b.z * rhs.b.z,
            s * rhs.b.x + b.x * rhs.s + b.y * rhs.b.z - b.z * rhs.b.y,
            s * rhs.b.y - b.x * rhs.b.z + b.y * rhs.s + b.z * rhs.b.x,
            s * rhs.b.z + b.x * rhs.b.y - b.y * rhs.b.x + b.z * rhs.s,
            );
    }
}


struct EMV4
{
    // scalar part
    float s;
    // bivector part
    float bxy;
    float bzx;
    float byz;
    float bwx;
    float bwy;
    float bwz;
    // quadvector part
    float q;

    string toString()
    {
        return (data()[0..8]).to!string();
    }

    float* data()
    {
        return &s;
    }

    float magnitude() const
    {
        return sqrt(s * s + bxy * bxy + bzx * bzx + byz * byz + bwx * bwx + bwy * bwy + bwz * bwz + q * q);
    }

    void normalize()
    {
        float m = magnitude();
        s /= m;
        bxy /= m;
        bzx /= m;
        byz /= m;
        bwx /= m;
        bwy /= m;
        bwz /= m;
        q /= m;
    }

    EMV4 reverse() const pure
    {
        // TODO: make sure this is actually correct
        return EMV4(s, -bxy, -bzx, -byz, -bwx, -bwy, -bwz, q);
    }

    Vec4 rotate()(auto ref in Vec4 v) const
    {
        // TODO: pretty sure this really doesn't work, try it again later i guess lol...
        float tx = +s * v.x + bxy * v.y + bzx * v.z + bwx * v.w;
        float ty = +s * v.y - bxy * v.x + byz * v.z - bwy * v.w;
        float tz = +s * v.z - bzx * v.x - byz * v.y + bwz * v.w;
        float tw = +s * v.w - bwx * v.x + bwy * v.y - bwz * v.z;
        float txyz = -bxy * v.z + bzx * v.y - byz * v.x - q * v.w;
        float txwy = +bxy * v.w - bwx * v.y - bwy * v.x - q * v.z;
        float txzw = -bzx * v.w + bwx * v.z - bwz * v.x - q * v.y;
        float tzyw = +byz * v.w + bwy * v.z + bwz * v.y - q * v.x;

        EMV4 rev = reverse();

        writeln(+tx * rev.s - ty * rev.bxy - tz * rev.bzx - tw * rev.bwx + txyz * rev.byz + txwy * rev.bwy + txzw * rev.bwz + tzyw * rev.q);
        writeln(+tx * rev.bxy + ty * rev.s - tz * rev.byz + tw * rev.bwy - txyz * rev.bzx + txwy * rev.bwx + txzw * rev.q - tzyw * rev.bwz);
        writeln(+tx * rev.bzx + ty * rev.byz + tz * rev.s - tw * rev.bwz + txyz * rev.bxy + txwy * rev.q - txzw * rev.bwx - tzyw * rev.bwy);
        writeln(+tx * rev.bwx - ty * rev.bwy + tz * rev.bwz + tw * rev.s + txyz * rev.q - txwy * rev.bxy + txzw * rev.bzx - tzyw * rev.byz);
        writeln(-tx * rev.byz + ty * rev.bzx - tz * rev.bxy + tw * rev.q + txyz * rev.s + txwy * rev.bwz - txzw * rev.bwy + tzyw * rev.bwx);
        writeln(-tx * rev.bwy - ty * rev.bwx + tz * rev.q + tw * rev.bxy - txyz * rev.bwz + txwy * rev.s + txzw * rev.byz + tzyw * rev.bzx);
        writeln(-tx * rev.bwz + ty * rev.q + tz * rev.bwx - tw * rev.bzx + txyz * rev.bwy - txwy * rev.byz + txzw * rev.s + tzyw * rev.bxy);
        writeln(+tx * rev.q + ty * rev.bwz + tz * rev.bwy + tw * rev.byz - txyz * rev.bwx - txwy * rev.bzx - txzw * rev.bxy + tzyw * rev.s);

        assert(0);
    }


    EMV4 opBinary(string op)(auto ref in EMV4 rhs) const if (op == "*")
    {
        // TODO: verify
        return EMV4(
            s * rhs.s - bxy * rhs.bxy - bzx * rhs.bzx - bwx * rhs.bwx - byz * rhs.byz - bwy * rhs.bwy - bwz * rhs.bwz + q * rhs.q,

            s * rhs.bxy + bxy * rhs.s + byz * rhs.bzx - bzx * rhs.byz + bwx * rhs.bwy - bwy * rhs.bwx - bwz * rhs.q - q * rhs.bwz,
            s * rhs.bzx + bzx * rhs.s + bxy * rhs.byz - byz * rhs.bxy + bwz * rhs.bwx - bwx * rhs.bwz - bwy * rhs.q - q * rhs.bwy,
            s * rhs.byz + byz * rhs.s + bzx * rhs.bxy - bxy * rhs.bzx + bwy * rhs.bwz - bwz * rhs.bwy - bwx * rhs.q - q * rhs.bwx,
            s * rhs.bwx + bwx * rhs.s + bwy * rhs.bxy - bxy * rhs.bwy + bzx * rhs.bwz - bwz * rhs.bzx - byz * rhs.q - q * rhs.byz,
            s * rhs.bwy + bwy * rhs.s + bxy * rhs.bwx - bwx * rhs.bxy + bwz * rhs.byz - byz * rhs.bwz - bzx * rhs.q - q * rhs.bzx,
            s * rhs.bwz + bwz * rhs.s + bwx * rhs.bzx - bzx * rhs.bwx + byz * rhs.bwy - bwy * rhs.byz - bxy * rhs.q - q * rhs.bxy,

            s * rhs.q + bxy * rhs.bwz + byz * rhs.bwx + bzx * rhs.bwy + bwx * rhs.byz + bwy * rhs.bzx + bwz * rhs.bxy + q * rhs.s
            );
    }
}


struct Mat4
{
    float xx = 1;
    float yx = 0;
    float zx = 0;
    float wx = 0;
    float xy = 0;
    float yy = 1;
    float zy = 0;
    float wy = 0;
    float xz = 0;
    float yz = 0;
    float zz = 1;
    float wz = 0;
    float xw = 0;
    float yw = 0;
    float zw = 0;
    float ww = 1;

    string toString()
    {
        return (data()[0..16]).to!string();
    }

    float* data()
    {
        return &xx;
    }


    float determinant()
    {
        return
            xx * yy * zz * ww +
            xx * yz * zw * wy +
            xx * yw * zy * wz +
            xy * yx * zw * wz +
            xy * yz * zx * ww +
            xy * yw * zz * wx +
            xz * yx * zy * ww +
            xz * yy * zw * wx +
            xz * yw * zx * wy +
            xw * yx * zz * wy +
            xw * yy * zx * wz +
            xw * yz * zy * wx -
            xx * yy * zw * wz -
            xx * yz * zy * ww -
            xx * yw * zz * wy -
            xy * yx * zz * ww -
            xy * yz * zw * wx -
            xy * yw * zx * wz -
            xz * yx * zw * wy -
            xz * yy * zx * ww -
            xz * yw * zy * wx -
            xw * yx * zy * wz -
            xw * yy * zz * wx -
            xw * yz * zx * wy;
    }

    Mat4 inverse()
    {
        float det = determinant();
        assert(abs(det) > 1e-6);

        return Mat4(
            (yy * zz * ww + yz * zw * wy + yw * zy * wz - yy * zw * wz - yz * zy * ww - yw * zz * wy) / det,
            (yx * zw * wz + yz * zx * ww + yw * zz * wx - yx * zz * ww - yz * zw * wx - yw * zx * wz) / det,
            (yx * zy * ww + yy * zw * wx + yw * zx * wy - yx * zw * wy - yy * zx * ww - yw * zy * wx) / det,
            (yx * zz * wy + yy * zx * wz + yz * zy * wx - yx * zy * wz - yy * zz * wx - yz * zx * wy) / det,

            (xy * zw * wz + xz * zy * ww + xw * zz * wy - xy * zz * ww - xz * zw * wy - xw * zy * wz) / det,
            (xx * zz * ww + xz * zw * wx + xw * zx * wz - xx * zw * wz - xz * zx * ww - xw * zz * wx) / det,
            (xx * zw * wy + xy * zx * ww + xw * zy * wx - xx * zy * ww - xy * zw * wx - xw * zx * wy) / det,
            (xx * zy * wz + xy * zz * wx + xz * zx * wy - xx * zz * wy - xy * zx * wz - xz * zy * wx) / det,

            (xy * yz * ww + xz * yw * wy + xw * yy * wz - xy * yw * wz - xz * yy * ww - xw * yz * wy) / det,
            (xx * yw * wz + xz * yx * ww + xw * yz * wx - xx * yz * ww - xz * yw * wx - xw * yx * wz) / det,
            (xx * yy * ww + xy * yw * wx + xw * yx * wy - xx * yw * wy - xy * yx * ww - xw * yy * wx) / det,
            (xx * yz * wy + xy * yx * wz + xz * yy * wx - xx * yy * wz - xy * yz * wx - xz * yx * wy) / det,

            (xy * yw * zz + xz * yy * zw + xw * yz * zy - xy * yz * zw - xz * yw * zy - xw * yy * zz) / det,
            (xx * yz * zw + xz * yw * zx + xw * yx * zz - xx * yw * zz - xz * yx * zw - xw * yz * zx) / det,
            (xx * yw * zy + xy * yx * zw + xw * yy * zx - xx * yy * zw - xy * yw * zx - xw * yx * zy) / det,
            (xx * yy * zz + xy * yz * zx + xz * yx * zy - xx * yz * zy - xy * yx * zz - xz * yy * zx) / det,
            );
    }


    Mat4 opBinary(string op)(auto ref in Mat4 b) if (op == "*")
    {
        return Mat4(
            xx * b.xx + xy * b.yx + xz * b.zx + xw * b.wx,
            yx * b.xx + yy * b.yx + yz * b.zx + yw * b.wx,
            zx * b.xx + zy * b.yx + zz * b.zx + zw * b.wx,
            wx * b.xx + wy * b.yx + wz * b.zx + ww * b.wx,

            xx * b.xy + xy * b.yy + xz * b.zy + xw * b.wy,
            yx * b.xy + yy * b.yy + yz * b.zy + yw * b.wy,
            zx * b.xy + zy * b.yy + zz * b.zy + zw * b.wy,
            wx * b.xy + wy * b.yy + wz * b.zy + ww * b.wy,

            xx * b.xz + xy * b.yz + xz * b.zz + xw * b.wz,
            yx * b.xz + yy * b.yz + yz * b.zz + yw * b.wz,
            zx * b.xz + zy * b.yz + zz * b.zz + zw * b.wz,
            wx * b.xz + wy * b.yz + wz * b.zz + ww * b.wz,

            xx * b.xw + xy * b.yw + xz * b.zw + xw * b.ww,
            yx * b.xw + yy * b.yw + yz * b.zw + yw * b.ww,
            zx * b.xw + zy * b.yw + zz * b.zw + zw * b.ww,
            wx * b.xw + wy * b.yw + wz * b.zw + ww * b.ww,
            );
    }

    Vec4 opBinary(string op)(auto ref in Vec4 b) if (op == "*")
    {
        return Vec4(
            xx * b.x + xy * b.y + xz * b.z + xw * b.w,
            yx * b.x + yy * b.y + yz * b.z + yw * b.w,
            zx * b.x + zy * b.y + zz * b.z + zw * b.w,
            wx * b.x + wy * b.y + wz * b.z + ww * b.w,
            );
    }

    Mat4 opBinaryRight(string op)(float a) if (op == "*")
    {
        return Mat4(
            a * xx,
            a * yx,
            a * zx,
            a * wx,

            a * xy,
            a * yy,
            a * zy,
            a * wy,

            a * xz,
            a * yz,
            a * zz,
            a * wz,

            a * xw,
            a * yw,
            a * zw,
            a * ww,
            );
    }
}



Mat4 translate()(auto ref in Mat4 a, float tx, float ty, float tz)
{
    return Mat4(
        a.xx,
        a.yx,
        a.zx,
        a.wx,

        a.xy,
        a.yy,
        a.zy,
        a.wy,

        a.xz,
        a.yz,
        a.zz,
        a.wz,

        a.xx * tx + a.xy * ty + a.xz * tz + a.xw,
        a.yx * tx + a.yy * ty + a.yz * tz + a.yw,
        a.zx * tx + a.zy * ty + a.zz * tz + a.zw,
        a.wx * tx + a.wy * ty + a.wz * tz + a.ww,
        );
}

Mat4 scale()(auto ref in Mat4 a, float n)
{
    return Mat4(
        a.xx * n,
        a.yx * n,
        a.zx * n,
        a.wx * n,

        a.xy * n,
        a.yy * n,
        a.zy * n,
        a.wy * n,

        a.xz * n,
        a.yz * n,
        a.zz * n,
        a.wz * n,

        a.xw,
        a.yw,
        a.zw,
        a.ww,
        );
}

// https://github.com/g-truc/glm/blob/78f686b4be6c623df829db58b974bf8d79461987/glm/gtc/matrix_transform.inl#L330
Mat4 perspective(float fov_y, float aspect_ratio, float near_z, float far_z)
{
    immutable float tan_half_fov_y = tan(fov_y / 2);
    return Mat4(
        1 / (aspect_ratio * tan_half_fov_y),
        0,
        0,
        0,

        0,
        1 / tan_half_fov_y,
        0,
        0,

        0,
        0,
        (far_z + near_z) / (near_z - far_z),
        -1,

        0,
        0,
        (2 * far_z * near_z) / (near_z - far_z),
        0,
        );
}

// https://github.com/g-truc/glm/blob/78f686b4be6c623df829db58b974bf8d79461987/glm/gtc/matrix_transform.inl#L195
Mat4 orthographic(float left, float right, float bottom, float top, float near_z, float far_z)
{
    return Mat4(
        2 / (right - left),
        0,
        0,
        -(right + left) / (right - left),

        0,
        2 / (top - bottom),
        0,
        -(top + bottom) / (top - bottom),

        0,
        0,
        -2 / (far_z - near_z),
        //-1 / (far_z - near_z),
        0,

        0,
        0,
        -(far_z + near_z) / (far_z - near_z),
        //-near_z / (far_z - near_z),
        1,
        );
}

// https://github.com/g-truc/glm/blob/78f686b4be6c623df829db58b974bf8d79461987/glm/gtc/matrix_transform.inl#L649
Mat4 look_at(Vec3 eye, Vec3 center, Vec3 up)
{
    Vec3 f = normalized(center - eye);
    Vec3 s = normalized(cross_p(f, up));
    Vec3 u = cross_p(s, f);

    return Mat4(
        s.x,
        u.x,
        -f.x,
        0,

        s.y,
        u.y,
        -f.y,
        0,

        s.z,
        u.z,
        -f.z,
        0,

        -dot_p(s, eye),
        -dot_p(u, eye),
        dot_p(f, eye),
        1,
        );
}



Vec4 proj()(auto ref in Vec4 v, auto ref in Vec4 onto)
{
    assert(abs(onto.magnitude() - 1) < 1e-6);
    return dot_p(v, onto) * onto;
}


// when this_plane is true, the vector arguments define the plane of rotation
// otherwise, they define the axis plane of rotation (i.e. fixed plane)
// http://forums.xkcd.com/viewtopic.php?p=956761&sid=f4887c64a6a886e7e1fc5ee96cadbf3a#p956761
Mat4 rot(bool this_plane = true)(auto ref in Vec4 basis1, auto ref in Vec4 basis2, float theta)
{
    // enum Vec4[4] standard_basis = [
    //     Vec4(1, 0, 0, 0),
    //     Vec4(0, 1, 0, 0),
    //     Vec4(0, 0, 1, 0),
    //     Vec4(0, 0, 0, 1),
    //     ];

    // TODO: is there a cleaner way to do this?
    if (abs(dot_p(basis1, basis2) / (basis1.magnitude() * basis2.magnitude)) > (1 - 1e-6))
    {
        //writeln(basis1, "\t", basis2);
        return Mat4.init;
    }

    Mat4 b;
    // gross hack to get a Vec4 "array" out of a Mat4
    Vec4* e = cast(Vec4*)b.data;

    // TODO: should these be asserted to be normal to begin with, or be normalized here
    e[0] = basis1.normalized();

    e[1] = (basis2 - proj(basis2, e[0])).normalized();

    e[2] = Vec4(
        e[0].y * e[1].z - e[0].z * e[1].y,
        e[0].z * e[1].x - e[0].x * e[1].z,
        e[0].x * e[1].y - e[0].y * e[1].x,
        0
        );
    if (abs(e[2].magnitude()) < 1e-6)
    {
        e[2] = Vec4(
            e[0].y * e[1].z - e[0].z * e[1].y,
            e[0].z * e[1].w - e[0].w * e[1].z,
            e[0].w * e[1].y - e[0].y * e[1].w,
            0
            );

        if (abs(e[2].magnitude()) < 1e-6)
        {
            e[2] = Vec4(
                e[0].x * e[1].z - e[0].z * e[1].x,
                e[0].z * e[1].w - e[0].w * e[1].z,
                e[0].w * e[1].x - e[0].x * e[1].w,
                0
                );
            assert(abs(e[2].magnitude()) > 1e-6, format("\n%s\n%s\n%s\n%s", e[0], e[1],
                                                        Vec4(
                                                            e[0].y * e[1].z - e[0].z * e[1].y,
                                                            e[0].z * e[1].x - e[0].x * e[1].z,
                                                            e[0].x * e[1].y - e[0].y * e[1].x,
                                                            0
                                                            ),
                                                        Vec4(
                                                            e[0].y * e[1].z - e[0].z * e[1].y,
                                                            e[0].z * e[1].w - e[0].w * e[1].z,
                                                            e[0].w * e[1].y - e[0].y * e[1].w,
                                                            0
                                                            ), e[2]));
        }
    }
    e[2].normalize();

    e[3] = cross_p(e[0], e[1], e[2]);
    assert(abs(e[3].magnitude() - 1) < 1e-6, format("%s", b)); // is this going to always be true?

/*
  for (int i = 0, j = 2; i < 4 && j < 4; i++)
  {
  e[j] = standard_basis[i];
  writeln(e[j]);
  for (int k = 0; k < j; k++)
  {
  e[j] -= proj(e[j], e[k]);
  writeln(e[j], " ", e[k]);
  }

  if (abs(e[j].magnitude()) > 5e-5)
  {
  writeln("normalizing ", e[j]);
  writeln();
  e[j].normalize();
  j++;
  }
  else
  {
  writeln("throwing away ", e[j]);
  writeln();
  }
  }
  writeln();*/

    for (int i = 0; i < 4; i++)
    {
        //writeln(e[i]);
        for (int j = i + 1; j < 4; j++)
        {
            //writeln(e[j]);
            // TODO: this numerical instability seems to cause some issues...
            //       ... did i fix it?
            if (abs(dot_p(e[i], e[j])) > 1e-6)
            {
                writeln();
                writeln(this_plane);
                writeln(theta);
                writeln(basis1);
                writeln(basis2);
                writeln(b);
                writeln(e[i]);
                writeln(e[j]);
                writeln(dot_p(e[i], e[j]));
                assert(0);
            }
        }
        //writeln();
    }


    static if (this_plane)
    {
        immutable Mat4 r = Mat4(
            cos(theta),
            sin(theta),
            0,
            0,

            -sin(theta),
            cos(theta),
            0,
            0,

            0,
            0,
            1,
            0,

            0,
            0,
            0,
            1,
            );
    }
    else
    {
        immutable Mat4 r = Mat4(
            1,
            0,
            0,
            0,

            0,
            1,
            0,
            0,

            0,
            0,
            cos(theta),
            sin(theta),

            0,
            0,
            -sin(theta),
            cos(theta),
            );
    }


    return b * r * b.inverse();
}
