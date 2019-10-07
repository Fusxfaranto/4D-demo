
import std.stdio : write, writeln;
import std.conv : to;
import std.math : PI, sin, cos, acos, sgn, sqrt, abs, atan2;
import std.range : back, popBack;
import std.array : array, empty;
import std.algorithm : sum, map, schwartzSort, sort;
import std.traits : EnumMembers;
import std.typecons : Tuple, tuple;

import util;
import render_bindings;
import shapes;
import matrix;
import chunk;
import world;


private {
    ChunkPos[] cs_stack;
    ChunkPos[] processed_cps;
}


// TODO there is still allocations (and therefore GC) happening in this function at steady state.  array literals are probably the culprit

void generate_cross_section(ref World world, ChunkGLData** gl_data_p, ref float[] objects, float render_radius, bool cube_culling,
                            Vec4 base_pos, Vec4 up, Vec4 front, Vec4 normal, Vec4 right)
{
    objects.unsafe_reset();

    assert(processed_cps.length == 0);

    ChunkPos center_cp = ChunkPos(base_pos);
    cs_stack.unsafe_reset();
    cs_stack ~= center_cp;

    bool skip_render(int N)(in Vec4 pos)
    {
        enum float RADIUS = 2 ^^ N;
        enum Vec4 CENTER_OFFSET = RADIUS * Vec4(0.5, 0.5, 0.5, 0.5);

        Vec4 rel_center = pos + CENTER_OFFSET - base_pos;

        if (abs(dot_p(rel_center, normal)) > RADIUS)
        {
            return true;
        }

        if (dot_p(rel_center, front) > RADIUS)
        {
            return true;
        }
        // TODO frustum culling?

        return false;
    }

    void process_chunk(ref Chunk c, ChunkPos cp)
    {
        //writeln("processing ", cp);
        //scratch_strings ~= cp.to!string();
        processed_cps ~= cp;
        c.processing_status = ChunkProcessingStatus.PROCESSED;

        assert(c.state != ChunkDataState.INVALID);

        final switch (c.state) {
        case ChunkDataState.INVALID:
            assert(0);

        case ChunkDataState.LOADED:
            assert(c.gl_data);
            *gl_data_p++ = c.gl_data;
            break;

        case ChunkDataState.EMPTY:
        case ChunkDataState.OCCLUDED_UNLOADED:
            break;
        }
    }

    assert(center_cp in world.loaded_chunks);
    process_chunk(world.loaded_chunks[center_cp], center_cp);

    while (!cs_stack.empty())
    {
        ChunkPos cp = cs_stack.back();
        cs_stack.unsafe_popback();

        for (int i = 0; i < 8; i++)
        {
            // TODO this logic can probably be reordered more optimally
            ChunkPos new_cp = void;
            final switch (i) {
            case 0: new_cp = cp.shift!"x"(1); break;
            case 1: new_cp = cp.shift!"y"(1); break;
            case 2: new_cp = cp.shift!"z"(1); break;
            case 3: new_cp = cp.shift!"w"(1); break;
            case 4: new_cp = cp.shift!"x"(-1); break;
            case 5: new_cp = cp.shift!"y"(-1); break;
            case 6: new_cp = cp.shift!"z"(-1); break;
            case 7: new_cp = cp.shift!"w"(-1); break;
            }

            Vec4 rel_center = new_cp.to_vec4_centered() - base_pos;
            if (abs(dot_p(rel_center, normal)) > CHUNK_SIZE)
            {
                continue;
            }

            if (dot_p(rel_center, front) > CHUNK_SIZE)
            {
                continue;
            }

            if (rel_center.l1_norm() > render_radius)
            {
                continue;
            }

            //writeln(cs_stack.length, ' ', cs_stack.capacity);
            Chunk* p = new_cp in world.loaded_chunks;
            if (p && p.processing_status == ChunkProcessingStatus.NOT_PROCESSED)
            {
                cs_stack ~= new_cp;
                //debug(prof) sw.stop();
                process_chunk(*p, new_cp);
                //debug(prof) sw.start();
            }
            //writeln(cs_stack.length, ' ', cs_stack.capacity);
            //writeln();
        }
    }

    //writeln(processed_cps);
    foreach (cp; processed_cps)
    {
        world.loaded_chunks[cp].processing_status = ChunkProcessingStatus.NOT_PROCESSED;
    }
    processed_cps.unsafe_reset();

    //writeln(objects[0..10]);
    debug(prof) profile_checkpoint();


    void run(ref in Vertex[4][] tets)
    {
        Vec4[4] rel_pos;  // potentially slower to store this instead of just recomputing?
        bool[4] pos_side;
        foreach (ref tet; tets)
        {
            for (int i = 0; i < 4; i++)
            {
                rel_pos[i] = tet[i].loc - base_pos;
                pos_side[i] = dot_p(rel_pos[i], normal) > 0;
            }

            int verts_added = 0;
            for (int i = 0; i < 4; i++)
            {
                for (int j = i; j < 4; j++)
                {
                    if (pos_side[i] != pos_side[j])
                    {
                        Vec4 diff = tet[i].loc - tet[j].loc;
                        float d = dot_p(normal, diff);
                        // this would fire sometimes, but i don't think it's actually important to ensure
                        //assert(abs(d) > 1e-6);
                        Vec4 rel_intersection_point = tet[i].loc +
                            diff * (-dot_p(rel_pos[i], normal) / d) - base_pos;

                        if (verts_added == 3)
                        {
                            objects ~= objects[($ - 2 * 6)..($ - 1 * 6)];
                            objects ~= objects[($ - 2 * 6)..($ - 1 * 6)];
                            verts_added += 2;
                        }

                        // http://stackoverflow.com/questions/23472048/projecting-3d-points-to-2d-plane i guess
                        objects ~= dot_p(right, rel_intersection_point);
                        objects ~= dot_p(up, rel_intersection_point);
                        objects ~= dot_p(front, rel_intersection_point);
                        objects ~= tet[i].color_r;
                        objects ~= tet[i].color_g;
                        objects ~= tet[i].color_b;
                        verts_added++;
                    }
                }
            }

            assert(verts_added == 0 || verts_added == 3 || verts_added == 6);
        }
    }

    run(world.scene);
    run(world.character);
    debug(prof) profile_checkpoint();
}


immutable int[2][12] reference_adjacent_corners = [
    [6, 7],
    [7, 4],
    [4, 2],
    [2, 6],

    [3, 6],
    [5, 7],
    [1, 4],
    [0, 2],

    [3, 5],
    [5, 1],
    [1, 0],
    [0, 3],

    // [0, 1],
    // [0, 2],
    // [0, 3],
    // [1, 4],
    // [1, 5],
    // [2, 4],
    // [2, 6],
    // [3, 5],
    // [3, 6],
    // [4, 7],
    // [5, 7],
    // [6, 7],

    ];

immutable size_t[3][8] corner_edge_map = [
    [10, 7, 11],
    [10, 6, 9],
    [7,  2, 3],
    [11, 8, 4],
    [6,  2, 1],
    [9,  8, 5],
    [3,  4, 0],
    [1,  5, 0],

    // [0, 1, 2],
    // [0, 3, 4],
    // [1, 5, 6],
    // [2, 7, 8],
    // [3, 5, 9],
    // [4, 7, 10],
    // [6, 8, 11],
    // [9, 10, 11],
    ];

immutable size_t[3][8] corner_adjacency_map = [
    [1, 2, 3],
    [0, 4, 5],
    [0, 4, 6],
    [0, 5, 6],
    [1, 2, 3],
    [1, 3, 7],
    [2, 3, 7],
    [4, 5, 6],
    ];



immutable Vec4[8][8] reference_cubes =
    [
        [
            Vec4(0, 0, 0, 0),
            Vec4(0, -1, 0, 0),
            Vec4(0, 0, -1, 0),
            Vec4(0, 0, 0, -1),
            Vec4(0, -1, -1, 0),
            Vec4(0, -1, 0, -1),
            Vec4(0, 0, -1, -1),
            Vec4(0, -1, -1, -1),
            ],
        [
            Vec4(0, 0, 0, 0),
            Vec4(-1, 0, 0, 0),
            Vec4(0, 0, -1, 0),
            Vec4(0, 0, 0, -1),
            Vec4(-1, 0, -1, 0),
            Vec4(-1, 0, 0, -1),
            Vec4(0, 0, -1, -1),
            Vec4(-1, 0, -1, -1),
            ],

        [
            Vec4(0, 0, 0, 0),
            Vec4(-1, 0, 0, 0),
            Vec4(0, -1, 0, 0),
            Vec4(0, 0, 0, -1),
            Vec4(-1, -1, 0, 0),
            Vec4(-1, 0, 0, -1),
            Vec4(0, -1, 0, -1),
            Vec4(-1, -1, 0, -1),
            ],
        [
            Vec4(0, 0, 0, 0),
            Vec4(-1, 0, 0, 0),
            Vec4(0, -1, 0, 0),
            Vec4(0, 0, -1, 0),
            Vec4(-1, -1, 0, 0),
            Vec4(-1, 0, -1, 0),
            Vec4(0, -1, -1, 0),
            Vec4(-1, -1, -1, 0),
            ],
        [
            Vec4(0, 0, 0, 0),
            Vec4(0, 1, 0, 0),
            Vec4(0, 0, 1, 0),
            Vec4(0, 0, 0, 1),
            Vec4(0, 1, 1, 0),
            Vec4(0, 1, 0, 1),
            Vec4(0, 0, 1, 1),
            Vec4(0, 1, 1, 1),
            ],
        [
            Vec4(0, 0, 0, 0),
            Vec4(1, 0, 0, 0),
            Vec4(0, 0, 1, 0),
            Vec4(0, 0, 0, 1),
            Vec4(1, 0, 1, 0),
            Vec4(1, 0, 0, 1),
            Vec4(0, 0, 1, 1),
            Vec4(1, 0, 1, 1),
            ],

        [
            Vec4(0, 0, 0, 0),
            Vec4(1, 0, 0, 0),
            Vec4(0, 1, 0, 0),
            Vec4(0, 0, 0, 1),
            Vec4(1, 1, 0, 0),
            Vec4(1, 0, 0, 1),
            Vec4(0, 1, 0, 1),
            Vec4(1, 1, 0, 1),
            ],
        [
            Vec4(0, 0, 0, 0),
            Vec4(1, 0, 0, 0),
            Vec4(0, 1, 0, 0),
            Vec4(0, 0, 1, 0),
            Vec4(1, 1, 0, 0),
            Vec4(1, 0, 1, 0),
            Vec4(0, 1, 1, 0),
            Vec4(1, 1, 1, 0),
            ],
        ];



// TODO edge_ordering can be halved in size using unsigned orientation
void order_edges(ref int[6][8][8] edge_ordering, Vec4 normal) {
    for (size_t dir = 0; dir < 8; dir++) {
        immutable Vec4 cube_perp = from_basis(to!Vec4BasisSigned(dir));

        // TODO test
        // if (to!Vec4BasisSigned(dir) != Vec4BasisSigned.X) {
        //     for (size_t i = 0; i < 8; i++) {
        //         for (size_t j = 0; j < 6; j++) {
        //             edge_ordering[dir][i][j] = -1;
        //         }
        //     }
        //     continue;
        // }

        // writeln(normal);
        // writeln(front);
        // writeln(right);

        Vec4 plane_vec_a = arbitrary_perp_vec(cube_perp, normal);
        Vec4 plane_vec_b = cross_p(cube_perp, normal, plane_vec_a);

        Vec4[8] projected_corners = void;
        size_t[8] idxs = void;
        float[8] corner_dists = void;

        foreach (i, v; reference_cubes[dir]) {
            idxs[i] = i;
            projected_corners[i] = proj(v, normal);
            corner_dists[i] = dot_p(v, normal);
            assert(abs(dot_p(projected_corners[i], normal) - corner_dists[i]) < 1e-5);
            //writeln(corner_dists[i], '\t', projected_corners[i]);
        }

        sort!((a, b) => corner_dists[a] < corner_dists[b])(idxs[]);

        static size_t[] copy_to;
        copy_to.unsafe_reset();

        for (size_t i = 0; i < 7; i++) {
            float dist = distance(projected_corners[idxs[i]], projected_corners[idxs[i + 1]]);
            // TODO threshold
            if (dist < 1e-6) {
                copy_to ~= i;
                //writeln("skipping ", idxs[i], " (", dist, ")");
                continue;
            }
            Vec4 midpoint = 0.5 * (projected_corners[idxs[i]] + projected_corners[idxs[i + 1]]);

            Vec4[8] rel_pos = void;
            bool[8] pos_side = void;
            for (size_t j = 0; j < 8; j++) {
                rel_pos[j] = reference_cubes[dir][j] - midpoint;
                pos_side[j] = dot_p(rel_pos[j], normal) > 0;
            }

            Vec4 centroid = Vec4(0, 0, 0, 0);
            static size_t[] intersecting_edges;
            intersecting_edges.unsafe_reset();
            static Vec4[] intersection_points;
            intersection_points.unsafe_reset();
            static size_t[] intersection_point_idxs;
            intersection_point_idxs.unsafe_reset();
            foreach (j, t; reference_adjacent_corners) {
                if (pos_side[t[0]] != pos_side[t[1]]) {
                    intersecting_edges ~= j;
                    intersection_point_idxs ~= intersection_point_idxs.length;

                    Vec4 diff = rel_pos[t[0]] - rel_pos[t[1]];
                    float d = dot_p(normal, diff);
                    intersection_points ~= rel_pos[t[0]] + diff * (-dot_p(rel_pos[t[0]], normal) / d);

                    centroid += intersection_points[$-1];
                }
            }
            centroid = centroid / intersection_points.length;

            assert(intersecting_edges.length == intersection_points.length);
            assert(intersecting_edges.length == intersection_point_idxs.length);

            if (intersecting_edges.length == 0) {
                continue; // TODO ??? is this ok
            }

            static float[] intersection_point_angles;
            intersection_point_angles.unsafe_reset();
            foreach (p; intersection_points) {
                float t = dot_p(normal, cross_p(cube_perp, p - centroid, plane_vec_a));
                float u = dot_p(normal, cross_p(cube_perp, p - centroid, plane_vec_b));
                intersection_point_angles ~= atan2(u, t);
            }

            //sort!((a, b) => dot_p(normal, cross_p(cube_perp, intersection_points[a] - centroid, intersection_points[b] - centroid)) < 0)(intersection_point_idxs);
            sort!((a, b) => intersection_point_angles[a] < intersection_point_angles[b])(intersection_point_idxs);

            // write(idxs[i], " (", corner_dists[idxs[i]], "):\t");
            // foreach (x; intersection_point_idxs) {
            //     write(intersecting_edges[x], " (", intersection_point_angles[x], "), ");
            // }
            // TODO this fires sometimes, but i think it's probably just a precision issue with is_coplanar
            //assert(is_coplanar!(1e-4)(intersection_points));

            for (size_t j = 0; j < 6; j++) {
                if (j < intersection_points.length) {
                    size_t idx = j % 2 == 0 ? intersection_point_idxs[j / 2] : intersection_point_idxs[intersection_points.length - 1 - (j / 2)];
                    edge_ordering[dir][idxs[i]][j] = cast(int)intersecting_edges[idx];
                    //write(intersecting_edges[idx], ", ");
                } else {
                    edge_ordering[dir][idxs[i]][j] = -1; // TODO ??
                }
            }
            //writeln();
        }

        foreach_reverse (i; copy_to) {
            //writeln("copied ", idxs[i + 1], " to ", idxs[i]);
            edge_ordering[dir][idxs[i]] = edge_ordering[dir][idxs[i + 1]];
        }
    }
}
