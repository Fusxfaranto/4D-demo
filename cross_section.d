
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
        assert(c.processing_status == ChunkProcessingStatus.NOT_PROCESSED);
        c.processing_status = ChunkProcessingStatus.PROCESSED;

        assert(c.state != ChunkDataState.INVALID);

        final switch (c.state) {
        case ChunkDataState.INVALID:
            assert(0);

        case ChunkDataState.LOADED:
            assert(c.gl_data);
            //writefln("adding %s", cp);
            *gl_data_p++ = c.gl_data;
            break;

        case ChunkDataState.EMPTY:
        case ChunkDataState.OCCLUDED_UNLOADED:
            break;
        }
    }

    Chunk* center = center_cp in world.loaded_chunks;
    assert(center);
    process_chunk(*center, center_cp);

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
            // radius of circumscribing 3-sphere
            enum R = (CHUNK_SIZE * Vec4(1, 1, 1, 1)).magnitude() / 2;
            if (abs(dot_p(rel_center, normal)) > R)
            {
                continue;
            }

            if (dot_p(rel_center, front) > R)
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

    *gl_data_p++ = null;

    //writeln(processed_cps);
    foreach (cp; processed_cps)
    {
        Chunk* c = cp in world.loaded_chunks;
        assert(c);
        c.processing_status = ChunkProcessingStatus.NOT_PROCESSED;
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



int[8][0x80] gen_selected_edges() {
    immutable reference_cube = reference_cubes[Vec4BasisSigned.NW];
    immutable cube_perp = Vec4BasisSigned.NW.to_vec4();
    int[8][0x100] selected_edges;

    for (size_t pos_side_b = 0; pos_side_b < 0x100; pos_side_b++) {
        bool[8] pos_side = void;
        for (size_t j = 0; j < 8; j++) {
            pos_side[j] = cast(bool)(pos_side_b & (1 << j));
        }

        static size_t[] intersecting_edges;
        intersecting_edges.unsafe_reset();
        static size_t[] intersection_point_idxs;
        intersection_point_idxs.unsafe_reset();
        foreach (j, t; reference_adjacent_corners) {
            if (pos_side[t[0]] != pos_side[t[1]]) {
                intersecting_edges ~= j;
                intersection_point_idxs ~= intersection_point_idxs.length;
            }
        }

        if (intersecting_edges.length < 3 || intersecting_edges.length > 6) {
            selected_edges[pos_side_b] = -1;
            continue;
        }


        Vec4 centroid = Vec4(0, 0, 0, 0);
        static Vec4[] intersection_points;
        intersection_points.unsafe_reset();
        for (size_t j = 0; j < intersecting_edges.length; j++) {
            auto cs = reference_adjacent_corners[intersecting_edges[j]];
            intersection_points ~= (reference_cube[cs[0]] + reference_cube[cs[1]]) / 2;

            centroid += intersection_points[j];
        }
        centroid = centroid / intersection_points.length;

        assert(intersecting_edges.length == intersection_points.length);
        assert(intersecting_edges.length == intersection_point_idxs.length);

        const Vec4 plane_vec_a = (intersection_points[1] - intersection_points[0]).normalized();
        const Vec4 plane_vec_b = (intersection_points[2] - intersection_points[0]).normalized();
        const Vec4 normal = cross_p(cube_perp, plane_vec_a, plane_vec_b).normalized();

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

        for (size_t j = 0; j < 8; j++) {
            if (j < intersection_points.length) {
                size_t idx = j % 2 == 0 ? intersection_point_idxs[j / 2] : intersection_point_idxs[intersection_points.length - 1 - (j / 2)];
                selected_edges[pos_side_b][j] = cast(int)intersecting_edges[idx];
                //write(intersecting_edges[idx], ", ");
            } else {
                selected_edges[pos_side_b][j] = -1;
            }
        }
        //writefln("%b %s", pos_side_b, selected_edges[pos_side_b][0..intersection_points.length]);
    }

    for (size_t pos_side_b = 0; pos_side_b < 0x100; pos_side_b++) {
        assert(selected_edges[pos_side_b] == selected_edges[~pos_side_b & 0xff]);
    }

    return selected_edges[0..0x80];
}


