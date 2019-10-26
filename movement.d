
import std.math : PI, sin, cos, acos, sgn, abs;

import matrix;
import world;
import util;




enum Vec4 GLOBAL_UP = Vec4(0, 1, 0, 0);
struct PosDir {
    enum float Y_LIMIT = 0.99;
    enum FIELDS = ["front", "up", "normal"];

    Vec4 pos;

    static foreach (F; FIELDS) {
        mixin(format("Vec4 %s;", F));
    }

    Vec4 right() const pure {
        Vec4 r = cross_p(up, front, normal);
        assert(abs(r.magnitude() - 1) < 1e-5);
        return r;
    }

    void move(string Field)(float f) {
        mixin(format("pos += f * %s;", Field));

        // TODO collision
    }

    void move_flat(string Field)(float f) {
        move!(format("(%s - proj(%s, GLOBAL_UP)).normalized()", Field, Field))(f);
    }


    void rotate(string FieldA, string FieldB)(float f) {
        mixin(format("Mat4 r = rot!false(%s, %s, f);", FieldA, FieldB));

        static foreach (F; FIELDS) {
            static if (F != FieldA && F != FieldB) {
                mixin(format("%s = (r * %s).normalized;", F, F));
            }
        }
    }

    void y_rotate(float f) {
        if (
            (front.y > -Y_LIMIT && f > 0) ||
            (front.y < Y_LIMIT && f < 0)
            ) {
            Mat4 r = rot(up, front, f);
            front = (r * front).normalized();
            up = (r * up).normalized();
        }
    }


    void fixup() {
        // TODO: else if?
        if (abs(dot_p(normal, up)) > 1e-7) {
            //writeln("normal/up offset");
            normal = cross_p(up, right(), front).normalized();
        }
        if (abs(dot_p(front, up)) > 1e-7) {
            //writeln("front/up offset");
            front = cross_p(right(), up, normal).normalized();
        }
        if (abs(dot_p(front, normal)) > 1e-7) {
            //writeln("front/normal offset");
            front = cross_p(right(), up, normal).normalized();
        }
    }
}
