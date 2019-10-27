
import std.math : PI, sin, cos, acos, sgn, abs;

import chunk;
import matrix;
import world;
import util;




enum Vec4 GLOBAL_UP = Vec4(0, 1, 0, 0);
struct PosDir {
    enum float Y_LIMIT = 0.99;
    enum FIELDS = ["front", "up", "normal"];

    enum HS_TOP = 0.2;
    enum HS_BOTTOM = -1.5;
    enum HS_RAD = 0.3;

    Vec4 pos;

    static foreach (F; FIELDS) {
        mixin(format("Vec4 %s;", F));
    }

    Vec4 velocity;

    Vec4 right() const pure {
        Vec4 r = cross_p(up, front, normal);
        assert(abs(r.magnitude() - 1) < 1e-5);
        return r;
    }

    void do_intersection(BlockType block, BlockPos bp) {
        if (block.has_collision()) {
            Vec4 rel_block_pos = bp.to_vec4() - pos;
            Vec4 closest_dir = (rel_block_pos + Vec4(0.5, -rel_block_pos.y, 0.5, 0.5)).normalized();
            Vec4 closest_point = HS_RAD * closest_dir - rel_block_pos;

            //writefln("%s %s %s", rel_block_pos, closest_point + rel_block_pos, closest_dir);
            if (rel_block_pos.y + 1 > HS_BOTTOM &&
                rel_block_pos.y < HS_TOP &&
                closest_point.x < 1 && closest_point.x > 0 &&
                closest_point.z < 1 && closest_point.z > 0 &&
                closest_point.w < 1 && closest_point.w > 0
                ) {

                //enum Y_NUDGE = 0.2;
                // TODO figure out some justification for this
                float y_nudge = abs(velocity.y) + 0.2;
                if (rel_block_pos.y + 1 < HS_BOTTOM + y_nudge) {
                    pos.y += rel_block_pos.y + 1 - HS_BOTTOM;
                } else if (rel_block_pos.y > HS_TOP - y_nudge) {
                    pos.y += rel_block_pos.y - HS_TOP;
                } else {
                    float[6] diffs = void;
                    diffs[0] = 1 - closest_point.x;
                    diffs[1] = 1 - closest_point.z;
                    diffs[2] = 1 - closest_point.w;
                    diffs[3] = closest_point.x;
                    diffs[4] = closest_point.z;
                    diffs[5] = closest_point.w;
                    float min_diff = diffs[0];
                    int min_diff_i = 0;
                    for (int i = 1; i < 6; i++) {
                        if (diffs[i] < min_diff) {
                            min_diff = diffs[i];
                            min_diff_i = i;
                        }
                    }
                    final switch (min_diff_i) {
                    case 0: pos.x += min_diff; break;
                    case 1: pos.z += min_diff; break;
                    case 2: pos.w += min_diff; break;
                    case 3: pos.x -= min_diff; break;
                    case 4: pos.z -= min_diff; break;
                    case 5: pos.w -= min_diff; break;
                    }
                }
            }
        }
    }

    void move(string Field)(float f, ref World w) {
        mixin(format("pos += f * %s;", Field));

        // TODO don't run every intersection on every move
        BlockPos[24] possible_intersects;
        Vec4 col_pos = pos - Vec4(0.5, -(HS_TOP + 0.1), 0.5, 0.5);
        possible_intersects[0..8] = BlockPos.flat_corners(col_pos);
        col_pos.y -= 1;
        possible_intersects[8..16] = BlockPos.flat_corners(col_pos);
        col_pos.y -= 1;
        possible_intersects[16..24] = BlockPos.flat_corners(col_pos);

        foreach (ref bp; possible_intersects) {
            do_intersection(w.get_block(bp), bp);
        }
    }

    void move_flat(string Field)(float f, ref World w) {
        move!(format("(%s - proj(%s, GLOBAL_UP)).normalized()", Field, Field))(f, w);
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

    void jump() {
        if (velocity.y == 0) {
            velocity.y = 0.17;
        }
    }

    void process_gravity(ref World w) {
        enum G = 0.009;
        velocity.y -= G;

        float last_y = pos.y;
        move!"GLOBAL_UP"(velocity.y, w);
        if (abs(pos.y - last_y) < 1e-7) {
            velocity.y = 0;
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
