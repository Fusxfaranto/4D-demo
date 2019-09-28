
import std.stdio : write, writeln;
import std.conv : to;
import std.math : PI, sin, cos, acos, sgn, sqrt, abs;
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

void generate_cross_section(ref World world, ref float[] objects, float render_radius, bool cube_culling,
                            Vec4 base_pos, Vec4 up, Vec4 front, Vec4 normal, Vec4 right)
{
    objects.unsafe_reset();

    assert(processed_cps.length == 0);

    ChunkPos center_cp = coords_to_chunkpos(base_pos);
    cs_stack.unsafe_reset();
    cs_stack ~= center_cp;

    void process_cube(Vec4 pos, Vec4BasisSigned dir)
    {
        if (cube_culling && dot_p(pos - base_pos, dir.from_basis()) > 0)
        {
            return;
        }

        Vec4[8] corner_offsets;
        final switch (dir)
        {
        case Vec4BasisSigned.X: case Vec4BasisSigned.NX:
            corner_offsets = [
                Vec4(0, 0, 0, 0),
                Vec4(0, 1, 0, 0),
                Vec4(0, 0, 1, 0),
                Vec4(0, 0, 0, 1),
                Vec4(0, 1, 1, 0),
                Vec4(0, 1, 0, 1),
                Vec4(0, 0, 1, 1),
                Vec4(0, 1, 1, 1),
                ];
            break;

        case Vec4BasisSigned.Y: case Vec4BasisSigned.NY:
            corner_offsets = [
                Vec4(0, 0, 0, 0),
                Vec4(1, 0, 0, 0),
                Vec4(0, 0, 1, 0),
                Vec4(0, 0, 0, 1),
                Vec4(1, 0, 1, 0),
                Vec4(1, 0, 0, 1),
                Vec4(0, 0, 1, 1),
                Vec4(1, 0, 1, 1),
                ];
            break;

        case Vec4BasisSigned.Z: case Vec4BasisSigned.NZ:
            corner_offsets = [
                Vec4(0, 0, 0, 0),
                Vec4(1, 0, 0, 0),
                Vec4(0, 1, 0, 0),
                Vec4(0, 0, 0, 1),
                Vec4(1, 1, 0, 0),
                Vec4(1, 0, 0, 1),
                Vec4(0, 1, 0, 1),
                Vec4(1, 1, 0, 1),
                ];
            break;

        case Vec4BasisSigned.W: case Vec4BasisSigned.NW:
            corner_offsets = [
                Vec4(0, 0, 0, 0),
                Vec4(1, 0, 0, 0),
                Vec4(0, 1, 0, 0),
                Vec4(0, 0, 1, 0),
                Vec4(1, 1, 0, 0),
                Vec4(1, 0, 1, 0),
                Vec4(0, 1, 1, 0),
                Vec4(1, 1, 1, 0),
                ];
            break;
        }

        float[3] color;
        final switch (dir)
        {
        case Vec4BasisSigned.X:
            color = [.0, .8, .0];
            break;

        case Vec4BasisSigned.NX:
            color = [.8, .0, .0];
            break;

        case Vec4BasisSigned.Y:
            color = [.0, .0, .8];
            break;

        case Vec4BasisSigned.NY:
            color = [.0, .8, .8];
            break;

        case Vec4BasisSigned.Z:
            color = [.8, .0, .8];
            break;

        case Vec4BasisSigned.NZ:
            color = [.8, .8, .0];
            break;

        case Vec4BasisSigned.W:
            color = [.2, .2, .2];
            break;

        case Vec4BasisSigned.NW:
            color = [.7, .7, .7];
            break;
        }

        enum Tuple!(int, int)[12] adjacent_corners = [
            tuple(0, 1),
            tuple(0, 2),
            tuple(0, 3),
            tuple(1, 4),
            tuple(1, 5),
            tuple(2, 4),
            tuple(2, 6),
            tuple(3, 5),
            tuple(3, 6),
            tuple(4, 7),
            tuple(5, 7),
            tuple(6, 7),
            ];

        Vec4[8] rel_pos;
        bool[8] pos_side;
        for (int i = 0; i < 8; i++)
        {
            rel_pos[i] = corner_offsets[i] + pos - base_pos;
            pos_side[i] = dot_p(rel_pos[i], normal) > 0;
        }

        static size_t[] verts;
        verts.unsafe_reset();

        foreach (i, t; adjacent_corners)
        {
            if (pos_side[t[0]] != pos_side[t[1]])
            {
                verts ~= i;
                //writeln(t);
            }
        }

        // i don't like this but it'll have to do for now
        // if this looks like it's here to stay, at least replace it with a trie or something
        if (verts.length >= 5)
        {
            if (verts.length == 6)
            {
                if (verts == [3, 4, 5, 6, 7, 8])
                {
                    swap(verts[3], verts[4]);
                }
            }
            else
            {
                if (verts == [0, 5, 6, 7, 8])
                {
                    swap(verts[0], verts[1]);
                }
                else if (verts == [0, 1, 6, 7, 11])
                {
                    swap(verts[0], verts[1]);
                }
                else if (verts == [3, 5, 6, 8, 10])
                {
                    swap(verts[0], verts[1]);
                    swap(verts[1], verts[2]);
                }
                else if (verts == [1, 2, 4, 5, 9])
                {
                    swap(verts[0], verts[1]);
                }
                else if (verts == [4, 6, 7, 8, 9])
                {
                    swap(verts[0], verts[3]);
                    swap(verts[3], verts[4]);
                }
                else if (verts == [2, 3, 4, 5, 6])
                {
                    swap(verts[0], verts[2]);
                }
                else if (verts == [1, 3, 4, 7, 8])
                {
                    swap(verts[0], verts[1]);
                    swap(verts[3], verts[4]);
                }
            }
        }

        foreach (i, v; verts)
        {
            //writeln(i, " ", verts);
            Vec4 diff = rel_pos[adjacent_corners[v][0]] - rel_pos[adjacent_corners[v][1]];
            float d = dot_p(normal, diff);
            Vec4 rel_intersection_point = rel_pos[adjacent_corners[v][0]] +
                diff * (-dot_p(rel_pos[adjacent_corners[v][0]], normal) / d);

            if (i >= 3)
            {
                objects ~= objects[($ - 2 * 6)..($ - 1 * 6)];
                objects ~= objects[($ - 2 * 6)..($ - 1 * 6)];
            }

            objects ~= dot_p(right, rel_intersection_point);
            objects ~= dot_p(up, rel_intersection_point);
            objects ~= dot_p(front, rel_intersection_point);
            objects ~= color[0];
            objects ~= color[1];
            objects ~= color[2];
        }
        if (verts.length >= 1)
        {
            //scratch_strings ~= verts.to!string();
        }
        //writeln(verts);

        //writeln(objects[($ - ((verts.length - 2) * 3) * 6)..$]);

        assert(objects.length % 3 == 0);
    }

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

    void process_hdtree(T : HDTree!N, int N)(ref T tree, IndexVec4 idx, ref in Chunk c, in ChunkPos cp)
    {
        if (tree.visibility == HDTreeVisibility.EMPTY)
        {
            if (N < 5)
            {
                //writeln("found empty subtree at level ", N, " in ", cp);
            }
            return;
        }

        //writeln("nonempty subtree at level ", N, " in ", cp);

        Vec4 section_pos = cp.to_vec4() + indexvec4_to_vec4(idx);
        if (skip_render!N(section_pos))
        {
            return;
        }

        //writeln("processing ", cp, " at level ", N);

        // static if (N == 0)
        // {
        //     if (c.data[idx] == BlockType.NONE)
        //     {
        //         return;
        //     }

        //     process_cube(pos + Vec4(0, 0, 0, 0), Vec4BasisSigned.NX);
        //     process_cube(pos + Vec4(0, 0, 0, 0), Vec4BasisSigned.NY);
        //     process_cube(pos + Vec4(0, 0, 0, 0), Vec4BasisSigned.NZ);
        //     process_cube(pos + Vec4(0, 0, 0, 0), Vec4BasisSigned.NW);
        //     process_cube(pos + Vec4(1, 0, 0, 0), Vec4BasisSigned.X);
        //     process_cube(pos + Vec4(0, 1, 0, 0), Vec4BasisSigned.Y);
        //     process_cube(pos + Vec4(0, 0, 1, 0), Vec4BasisSigned.Z);
        //     process_cube(pos + Vec4(0, 0, 0, 1), Vec4BasisSigned.W);
        // }
        static if (N <= HDTREE_RES + 1)
        {
            const(BlockType)* b = &c.data[idx.to_index()];
            for (size_t x = 0; x < 2 ^^ N; x++, b += CHUNK_SIZE ^^ 3 - Y_SPAN!N)
            {
                for (size_t y = 0; y < 2 ^^ N; y++, b += CHUNK_SIZE ^^ 2 - Z_SPAN!N)
                {
                    for (size_t z = 0; z < 2 ^^ N; z++, b += CHUNK_SIZE - W_SPAN!N)
                    {
                        for (size_t w = 0; w < 2 ^^ N; w++, b++)
                        {
                            assert(IndexVec4(x, y, z, w).to_index() == b - &c.data[idx.to_index()]);

                            if (*b == BlockType.NONE)
                            {
                                continue;
                            }

                            Vec4 block_pos = section_pos + Vec4(x, y, z, w);
                            if (skip_render!0(block_pos))
                            {
                                continue;
                            }

                            // TODO add actual "transparent" property
                            // TODO do something smarter at chunk boundaries?
                            if (b - CHUNK_SIZE ^^ 3 < c.begin() || b[-(CHUNK_SIZE ^^ 3)] == BlockType.NONE)
                            {
                                process_cube(block_pos, Vec4BasisSigned.NX);
                            }
                            if (b - CHUNK_SIZE ^^ 2 < c.begin() || b[-(CHUNK_SIZE ^^ 2)] == BlockType.NONE)
                            {
                                process_cube(block_pos, Vec4BasisSigned.NY);
                            }
                            if (b - CHUNK_SIZE ^^ 1 < c.begin() || b[-(CHUNK_SIZE ^^ 1)] == BlockType.NONE)
                            {
                                process_cube(block_pos, Vec4BasisSigned.NZ);
                            }
                            if (b - CHUNK_SIZE ^^ 0 < c.begin() || b[-(CHUNK_SIZE ^^ 0)] == BlockType.NONE)
                            {
                                process_cube(block_pos, Vec4BasisSigned.NW);
                            }
                            if (b + CHUNK_SIZE ^^ 3 >= c.end() || b[CHUNK_SIZE ^^ 3] == BlockType.NONE)
                            {
                                process_cube(block_pos + Vec4(1, 0, 0, 0), Vec4BasisSigned.X);
                            }
                            if (b + CHUNK_SIZE ^^ 2 >= c.end() || b[CHUNK_SIZE ^^ 2] == BlockType.NONE)
                            {
                                process_cube(block_pos + Vec4(0, 1, 0, 0), Vec4BasisSigned.Y);
                            }
                            if (b + CHUNK_SIZE ^^ 1 >= c.end() || b[CHUNK_SIZE ^^ 1] == BlockType.NONE)
                            {
                                process_cube(block_pos + Vec4(0, 0, 1, 0), Vec4BasisSigned.Z);
                            }
                            if (b + CHUNK_SIZE ^^ 0 >= c.end() || b[CHUNK_SIZE ^^ 0] == BlockType.NONE)
                            {
                                process_cube(block_pos + Vec4(0, 0, 0, 1), Vec4BasisSigned.W);
                            }
                        }
                    }
                }
            }
        }
        else
        {
            foreach (i; 0..16)
            {
                //writeln(i, ' ', idx, ' ', get_hdtree_index!N(i));
                process_hdtree(tree[i], idx + get_hdtree_index!N(i), c, cp);
            }
        }
    }

    ChunkGLData** gl_data_p = &cuboid_data[0];
    void process_chunk(ref Chunk c, ChunkPos cp)
    {
        //writeln("processing ", cp);
        //scratch_strings ~= cp.to!string();
        processed_cps ~= cp;
        c.status = ChunkStatus.PROCESSED;

        if (false) {
            process_hdtree(c.tree, IndexVec4.init, c, cp);
        } else {
            // if (skip_render!HDTREE_N(cp.to_vec4())) {
            //     return;
            // }

            *gl_data_p++ = c.gl_data;
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
            if (p && p.status == ChunkStatus.NOT_PROCESSED)
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
        world.loaded_chunks[cp].status = ChunkStatus.NOT_PROCESSED;
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

immutable Vec4[8] reference_cube = [
    Vec4(0, 0, 0, 0),
    Vec4(1, 0, 0, 0),
    Vec4(0, 0, 1, 0),
    Vec4(0, 0, 0, 1),
    Vec4(1, 0, 1, 0),
    Vec4(1, 0, 0, 1),
    Vec4(0, 0, 1, 1),
    Vec4(1, 0, 1, 1),
    ];


// TODO since this is probably going to need to be per-orientation, would it
// be better to enumerate the edges and order those?  (rather than pairs of corners)
void order_adjacent_corners(ref int[2][12] adjacent_corners, Vec4 front, Vec4 right) {
    Vec4[8] projected_corners = void;
    size_t[8] idxs = void;
    float[8] corner_dists = void;

    writeln(front);
    writeln(right);

    foreach (i, v; reference_cube) {
        idxs[i] = i;
        projected_corners[i] = proj(v, front);
        corner_dists[i] = dot_p(projected_corners[i], front);
        writeln(corner_dists[i], '\t', projected_corners[i]);
    }

    sort!((a, b) => corner_dists[a] < corner_dists[b])(idxs[]);

    static bool[12] edge_done;
    edge_done[] = false;
    size_t progress_front = 0;
    size_t progress_back = 11;

    for (size_t i = 0; i < 7; i++) {
        //Vec4 midpoint = 0.5 * (projected_corners[idxs[i]] + projected_corners[idxs[i + 1]]);
        size_t[3] adjacent_edges = corner_edge_map[idxs[i]];
        size_t[3] adjacent_edge_corners = corner_adjacency_map[idxs[i]];
        size_t[3] adjacent_edge_idxs = void;
        for (size_t j = 0; j < 3; j++) adjacent_edge_idxs[j] = j;

        sort!((a, b) => corner_dists[adjacent_edge_corners[a]] < corner_dists[adjacent_edge_corners[b]])(adjacent_edge_idxs[]);

        foreach (adjacent_edge_idx; adjacent_edge_idxs) {
            size_t edge_idx = adjacent_edges[adjacent_edge_idx];
            if (!edge_done[edge_idx]) {
                int[2] corners = reference_adjacent_corners[edge_idx];
                Vec4 edge_midpoint = 0.5 * (reference_cube[corners[0]] + reference_cube[corners[1]]);

                if (dot_p(edge_midpoint, right) > 0) {
                    adjacent_corners[progress_front++] = corners;
                } else {
                    adjacent_corners[progress_back--] = corners;
                }

                edge_done[edge_idx] = true;
                write(edge_idx, ", ");
            }
        }
    }

    writeln();
    assert(progress_front - progress_back == 1);

    //writeln(adjacent_corners);
}

void order_adjacent_corners_alt(ref int[2][12] adjacent_corners, Vec4 normal) {
    // TODO
    immutable Vec4 cube_perp = from_basis(Vec4BasisSigned.Y);

    bool[12][12] edge_dag = false;

    writeln(normal);

    Vec4[8] projected_corners = void;
    size_t[8] idxs = void;
    float[8] corner_dists = void;

    foreach (i, v; reference_cube) {
        idxs[i] = i;
        projected_corners[i] = proj(v, normal);
        corner_dists[i] = dot_p(projected_corners[i], normal);
        writeln(corner_dists[i], '\t', projected_corners[i]);
    }

    sort!((a, b) => corner_dists[a] < corner_dists[b])(idxs[]);

    for (size_t i = 0; i < 7; i++) {
        Vec4 midpoint = 0.5 * (projected_corners[idxs[i]] + projected_corners[idxs[i + 1]]);

        Vec4[8] rel_pos = void;
        bool[8] pos_side = void;
        for (size_t j = 0; j < 8; j++) {
            rel_pos[j] = reference_cube[j] - midpoint;
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

        sort!((a, b) => dot_p(normal, cross_p(cube_perp, intersection_points[a] - centroid, intersection_points[b] - centroid)) < 0)(intersection_point_idxs);

        for (size_t j = 0; j < intersection_points.length - 1; j++) {
            size_t idx1 = intersection_point_idxs[j];
            size_t idx2 = intersection_point_idxs[j + 1];
            edge_dag[intersecting_edges[idx1]][intersecting_edges[idx2]] = true;
            write(intersecting_edges[idx1], ", ");
        }
        writeln(intersecting_edges[intersection_point_idxs[$-1]]);
    }

    void print_dag() {
        for (size_t i = 0; i < 12; i++) {
            for (size_t j = 0; j < 12; j++) {
                if (edge_dag[i][j]) {
                    writeln(i, " ", j);
                }
            }
        }
        writeln();
    }

    print_dag();

    static size_t[] start_nodes;
    start_nodes.unsafe_reset();
    for (size_t i = 0; i < 12; i++) {
        bool has_incoming_edge = false;
        for (size_t j = 0; j < 12; j++) {
            if (edge_dag[j][i]) {
                has_incoming_edge = true;
                break;
            }
        }
        if (!has_incoming_edge) {
            start_nodes ~= i;
        }
    }
    assert(start_nodes.length > 0);

    static size_t[] edge_ordering;
    edge_ordering.unsafe_reset();
    while (start_nodes.length > 0) {
        size_t n = start_nodes.back();
        start_nodes.unsafe_popback();
        edge_ordering ~= n;

        for (size_t i = 0; i < 12; i++) {
            if (edge_dag[n][i]) {
                edge_dag[n][i] = false;

                bool has_incoming_edge = false;
                for (size_t j = 0; j < 12; j++) {
                    if (edge_dag[j][i]) {
                        has_incoming_edge = true;
                        break;
                    }
                }
                if (!has_incoming_edge) {
                    start_nodes ~= i;
                }
            }
        }
    }

    print_dag();

    for (size_t i = 0; i < 12; i++) {
        for (size_t j = 0; j < 12; j++) {
            assert(!edge_dag[i][j]);
        }
    }
    assert(edge_ordering.length == 12);

    for (size_t i = 0; i < 12; i++) {
        adjacent_corners[i] = reference_adjacent_corners[edge_ordering[i]];
    }
}
