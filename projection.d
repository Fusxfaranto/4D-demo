import std.algorithm : clamp, sort;
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



bool proj_type = true;


bool vert_in_targeted_cell(int vert_idx, int targeted_cell) {
    if (targeted_cell <= -1) {
        return false;
    }
    assert(targeted_cell <= Vec4BasisSigned.max);

    return !!(targeted_cell >= 4) ^ !!(vert_idx & (1 << (3 - (targeted_cell & 3))));
}


/*

  the core bug here:
  this is using the regular camera (which points towards z)
  for the 4d -> 3d projection, and then is projecting that in
  the z direction from 3d -> 2d, which doesn't actually make
  sense.

  the solution:
  for the 4d -> 3d projection, the camera needs to be facing
  the normal direction, which should be as simple as a 90 degree
  rotation to `rot`

 */

void gen_block_projection(ref float[6][2][] edges_out, BlockType t, BlockPos bp, Vec4 center, int targeted_cell, const ref Mat4 rot) {
    final switch (t) {
    case BlockType.NONE:
        return;

    case BlockType.TEST:
        break;
    }

    Vec4 rel_pos = bp.to_vec4() - center;


    //enum float aspect_ratio = 1;
    enum float fov = deg_to_rad(45);
    enum float tan_half_fov = tan(fov / 2);

    enum float near_w = 0.1;
    enum float far_w = 3;

    Vec3[16] proj_verts;
    Vec4[16] rel_verts;
    for (int i = 0; i < 16; i++) {
        rel_verts[i] = rot * (block_verts[i] + rel_pos);
        Vec4 rel_vert = rel_verts[i];
        if (proj_type) {
            float adj_w;
            if (rel_vert.w > 0) {
                adj_w = rel_vert.w + 1;
            } else {
                adj_w = -rel_vert.w + 1;
            }
            float scale = 1 / (tan_half_fov * adj_w);
            proj_verts[i] = Vec3(
                rel_vert.x * scale,
                rel_vert.y * scale,
                rel_vert.z * scale,
                );
        } else {
            float scale = 3;
            proj_verts[i] = Vec3(
                rel_vert.x * scale,
                rel_vert.y * scale,
                rel_vert.z * scale,
                );
        }
    }

    bool all_hidden = true;
    for (int i = 0; i < 16; i++) {
        if (dot_p(rel_verts[i], Vec4(0, 0, -1, 0)) > 0) {
            all_hidden = false;
            break;
        }
    }
    if (all_hidden) {
        return;
    }

    // TODO culling?
    foreach (ref edge; block_edges) {
        if (rel_verts[edge[0]].w <= 0 ||
            rel_verts[edge[1]].w <= 0) {
            continue;
        }

        bool is_targeted = vert_in_targeted_cell(edge[0], targeted_cell) && vert_in_targeted_cell(edge[1], targeted_cell);

        edges_out ~= (float[6][2]).init;

        foreach (i; 0..2) {
            edges_out[$ - 1][i][0] = proj_verts[edge[i]].x;
            edges_out[$ - 1][i][1] = proj_verts[edge[i]].y;
            edges_out[$ - 1][i][2] = proj_verts[edge[i]].z;

            if (is_targeted) {
                // TODO hack
                edges_out[$ - 1][i][2] += 0.01;

                edges_out[$ - 1][i][3] = 1.0;
                edges_out[$ - 1][i][4] = 1.0;
                edges_out[$ - 1][i][5] = 0.3;

                Vec4 avg_rel_vert = Vec4(0, 0, 0, 0);
                for (int j = 0; j < 16; j++) {
                    avg_rel_vert += rel_verts[j];
                }
                writeln(avg_rel_vert * (1 / 16.));
            } else {
                float c;
                //c = clamp(1.0 - 1.0 * sigmoid(rel_verts[edge[i]].magnitude()), 0.0, 1.0);
                //c = clamp(1.0 - 1.1 * sigmoid(rel_verts[edge[i]].magnitude()), 0.0, 1.0);
                c = 2 * clamp(1.4 * sigmoid(rel_verts[edge[i]].w) - 0.2, 0.0, 1.0) - 1.0;

                // TODO why did i do this??
                if (abs(c) <= 1e-5) {
                    // verts_out.unsafe_popback();
                    // verts_out.unsafe_popback();
                    // verts_out.unsafe_popback();
                    // continue;
                }

                bool red_side = rel_verts[edge[i]].w > 0;
                if (red_side) {
                    edges_out[$ - 1][i][3] = 1 - c * c;
                    edges_out[$ - 1][i][4] = 1 - abs(c);
                } else {
                    edges_out[$ - 1][i][3] = 1 - abs(c);
                    edges_out[$ - 1][i][4] = 1 - c * c;
                }
                edges_out[$ - 1][i][5] = 1 - c * c;
            }
        }
    }
}


private bool edge_sort(const ref float[6][2] a, const ref float[6][2] b) {
    Vec3 midpoint_a = 0.5 * (reinterpret!(Vec3, float[3])(a[0][0..3]) + reinterpret!(Vec3, float[3])(a[1][0..3]));
    Vec3 midpoint_b = 0.5 * (reinterpret!(Vec3, float[3])(b[0][0..3]) + reinterpret!(Vec3, float[3])(b[1][0..3]));
    return midpoint_a.magnitude() > midpoint_b.magnitude();
}

void gen_projection(ref float[] verts_out, ref World w, Vec4 center, float radius, float height, BlockFace targeted, const ref Mat4 rot) {
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

    static float[6][2][] edges;
    edges.unsafe_reset();

    bool will_render_targeted = false;
    foreach (ref bp; to_process) {
        if (targeted.pos == bp) {
            // TODO i don't think we want to do this
            if (false) {
                will_render_targeted = true;
            } else {
                gen_block_projection(edges, w.get_block(targeted.pos), targeted.pos, center, targeted.face, rot);
            }
            continue;
        }
        gen_block_projection(edges, w.get_block(bp), bp, center, -1, rot);
    }

    if (will_render_targeted) {
        // ensure targeted is drawn above others
        gen_block_projection(edges, w.get_block(targeted.pos), targeted.pos, center, targeted.face, rot);
    }

    if (edges.length > 0) {
        sort!edge_sort(edges);
        verts_out = (&edges[0][0][0])[0..(edges.length * 2 * 6)];
    } else {
        verts_out = null;
    }
}
