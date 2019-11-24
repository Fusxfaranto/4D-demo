import std.math : PI, abs, sin, cos, tan, sqrt, acos, isNaN;

import std.range : back, empty;

import chunk;
import cross_section;
import matrix;
import util;
import world;



immutable int[2][] block_edges = [
    [0, 1],
    [0, 2],
    [0, 4],
    [0, 8],
    [1, 3],
    [1, 5],
    [1, 9],
    [2, 3],
    [2, 6],
    [2, 10],
    [3, 7],
    [3, 11],
    [4, 5],
    [4, 6],
    [4, 12],
    [5, 7],
    [5, 13],
    [6, 7],
    [6, 14],
    [7, 15],
    [8, 9],
    [8, 10],
    [8, 12],
    [9, 11],
    [9, 13],
    [10, 11],
    [10, 14],
    [11, 15],
    [12, 13],
    [12, 14],
    [13, 15],
    [14, 15],
    ];

immutable Vec4[16] block_verts = [
    Vec4(0, 0, 0, 0),
    Vec4(0, 0, 0, 1),
    Vec4(0, 0, 1, 0),
    Vec4(0, 0, 1, 1),
    Vec4(0, 1, 0, 0),
    Vec4(0, 1, 0, 1),
    Vec4(0, 1, 1, 0),
    Vec4(0, 1, 1, 1),
    Vec4(1, 0, 0, 0),
    Vec4(1, 0, 0, 1),
    Vec4(1, 0, 1, 0),
    Vec4(1, 0, 1, 1),
    Vec4(1, 1, 0, 0),
    Vec4(1, 1, 0, 1),
    Vec4(1, 1, 1, 0),
    Vec4(1, 1, 1, 1),
    ];


//enum float aspect_ratio = 1;
enum float fov = deg_to_rad(45);
enum float tan_half_fov = tan(fov / 2);

enum float near_w = 0.1;
enum float far_w = 3;


void gen_block_projection(ref float[] verts_out, BlockType t, BlockPos bp, Vec4 center, const ref Mat4 rot) {
    final switch (t) {
    case BlockType.NONE:
        return;

    case BlockType.TEST:
        break;
    }

    Vec4 rel_pos = bp.to_vec4() - center;

    // TODO missing camera angle?

    Vec3[16] proj_verts;
    for (int i = 0; i < 16; i++) {
        Vec4 rel_vert = rot * (block_verts[i] + rel_pos);
        proj_verts[i] = Vec3(
            rel_vert.x / tan_half_fov - rel_vert.w,
            rel_vert.y / tan_half_fov - rel_vert.w,
            rel_vert.z / tan_half_fov - rel_vert.w,
            );
    }

    // TODO culling?
    foreach (ref edge; block_edges) {
        foreach (i; 0..2) {
            verts_out ~= proj_verts[edge[i]].x;
            verts_out ~= proj_verts[edge[i]].y;
            verts_out ~= proj_verts[edge[i]].z;
        }
    }
}


void gen_projection(ref float[] verts_out, ref World w, Vec4 center, float radius, float height, const ref Mat4 rot) {
    verts_out.unsafe_reset();

    BlockPos center_bp = BlockPos(center);

    static BlockPos[] bp_stack;
    bp_stack.unsafe_reset();

    static BlockPos[] to_process;
    to_process.unsafe_reset();

    bp_stack ~= center_bp;

    while (!bp_stack.empty()) {
        BlockPos bp = bp_stack.back();
        bp_stack.unsafe_popback();

        to_process ~= bp;

        float bp_dist = distance(bp, center_bp);

        for (int i = 0; i < 8; i++) {
            BlockPos new_bp = void;
            final switch (i) {
            case 0: new_bp = bp.shift!"x"(1); break;
            case 1: new_bp = bp.shift!"y"(1); break;
            case 2: new_bp = bp.shift!"z"(1); break;
            case 3: new_bp = bp.shift!"w"(1); break;
            case 4: new_bp = bp.shift!"x"(-1); break;
            case 5: new_bp = bp.shift!"y"(-1); break;
            case 6: new_bp = bp.shift!"z"(-1); break;
            case 7: new_bp = bp.shift!"w"(-1); break;
            }

            // TODO is this correct?
            if (distance(new_bp, center_bp) < bp_dist) {
                continue;
            }

            if (in_vert_sph(new_bp - center_bp, radius, height)) {
                if (!contains(to_process, new_bp)) {
                    bp_stack ~= new_bp;
                }
            }
        }
    }

    foreach (ref bp; to_process) {
        gen_block_projection(verts_out, w.get_block(bp), bp, center, rot);
    }
}
