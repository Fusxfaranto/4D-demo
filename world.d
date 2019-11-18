import std.algorithm : min;
import std.range : back, empty;

import util;
import matrix;
import shapes;
import chunk;
import cross_section;
import render_bindings;
import world_gen;
import workers;


struct BlockFace {
    BlockPos pos;
    Vec4BasisSigned face;

    enum INVALID = BlockFace(BlockPos.INVALID, Vec4BasisSigned.init);
}


struct LoadParams {
    Vec4 center;
    int chunk_radius;
    int chunk_height;
}
shared Locked!LoadParams load_params;


ChunkPosStack cps_to_load = ChunkPosStack(1024 * 32);


class World
{
    Vertex[4][] scene;
    Vertex[4][] character;

    ChunkIndex loaded_chunks;
    //ChunkData[] chunk_data_pool;

    WorkerGroup workers;

    this() {
        // TODO don't hardcode
        loaded_chunks = ChunkIndex(512 / CHUNK_SIZE);

        workers = WorkerGroup(totalCPUs, {
                load_chunks(load_params.get());
            });
    }


    private void if_loaded(alias F)(ChunkPos loc) {
        auto c = loc in loaded_chunks;
        if (c is null) {
            return;
        }

        F(*c);
    }

    private void update_surrounding_chunks(ChunkPos cp) {
        for (int i = 0; i < 8; i++)
        {
            ChunkPos adjacent_cp = void;
            final switch (i) {
            case 0: adjacent_cp = cp.shift!"x"(1); break;
            case 1: adjacent_cp = cp.shift!"y"(1); break;
            case 2: adjacent_cp = cp.shift!"z"(1); break;
            case 3: adjacent_cp = cp.shift!"w"(1); break;
            case 4: adjacent_cp = cp.shift!"x"(-1); break;
            case 5: adjacent_cp = cp.shift!"y"(-1); break;
            case 6: adjacent_cp = cp.shift!"z"(-1); break;
            case 7: adjacent_cp = cp.shift!"w"(-1); break;
            }

            // TODO this very overcomputes
            update_chunk_from_surroundings(adjacent_cp);
        }
    }


    private void update_chunk_from_surroundings(ChunkPos loc) {
        ubyte occluded_from = 0;
        for (int i = 0; i < 8; i++)
        {
            ChunkPos adjacent_loc = void;
            final switch (i) {
            case 0: adjacent_loc = loc.shift!"x"(1); break;
            case 1: adjacent_loc = loc.shift!"y"(1); break;
            case 2: adjacent_loc = loc.shift!"z"(1); break;
            case 3: adjacent_loc = loc.shift!"w"(1); break;
            case 4: adjacent_loc = loc.shift!"x"(-1); break;
            case 5: adjacent_loc = loc.shift!"y"(-1); break;
            case 6: adjacent_loc = loc.shift!"z"(-1); break;
            case 7: adjacent_loc = loc.shift!"w"(-1); break;
            }

            auto p = adjacent_loc in loaded_chunks;
            int relative_side = (i + 4) & 0b111;
            // an unloaded chunk counts as completely occluding
            if (p is null || p.occludes_side(relative_side)) {
                occluded_from |= 1 << i;
            }
        }

        auto c = loc in loaded_chunks;
        if (!c) {
            // TODO anything better to do in this case?
            return;
        }

        if (occluded_from == 0xff) {
            c.unload_data!(ChunkDataState.OCCLUDED_UNLOADED)();
        } else {
            // TODO something more graceful than this
            if (c.get_state() == ChunkDataState.OCCLUDED_UNLOADED) {
                assert(c.get_gl_data() is null);
                // TODO does this leak stuff?
                fetch_chunk(*c, loc);
            }

            if (c.get_state() != ChunkDataState.EMPTY) {
                c.update_gl_data();
            }
        }
    }

    // TODO something better
    auto load_chunk(ChunkPos cp) {
        loaded_chunks.fetch(cp);
        update_chunk_from_surroundings(cp);
        update_surrounding_chunks(cp);
        return cp in loaded_chunks;
    }

    // TODO really looks like workers are deadlocking somewhere
    void load_chunks(LoadParams params)
    {
        static load_count = 0;
        dwritef!"chunk"("load count %s", load_count);

        ChunkPos center_cp = ChunkPos(params.center);

        // TODO tweak
        bool should_queue_chunks = cps_to_load.empty();
        if (should_queue_chunks) {
        queue_chunks_outer:
            for (int r = 1;;) {
                for (int i = 0; i < 8; i++)
                {
                    ChunkPos start_cp = void;
                    final switch (i) {
                    case 0: start_cp = center_cp.shift!"x"(r); break;
                    case 1: start_cp = center_cp.shift!"y"(r); break;
                    case 2: start_cp = center_cp.shift!"z"(r); break;
                    case 3: start_cp = center_cp.shift!"w"(r); break;
                    case 4: start_cp = center_cp.shift!"x"(-r); break;
                    case 5: start_cp = center_cp.shift!"y"(-r); break;
                    case 6: start_cp = center_cp.shift!"z"(-r); break;
                    case 7: start_cp = center_cp.shift!"w"(-r); break;
                    }
                    if (start_cp !in loaded_chunks)
                    {
                        if (!cps_to_load.push(start_cp)) {
                            break queue_chunks_outer;
                        }
                        break queue_chunks_outer; // TODO?
                    }
                }
                if (r == params.chunk_radius) {
                    // TODO sleep or something?
                    // should probably come up with a better
                    // way to yield when workload is low
                    break;
                }
                r = min(r + 2, params.chunk_radius);
                // TODO this should be totally fine, but for some
                // reason results in no chunks being loaded
                // (when priority is min on worker threads?)
                // r++;
            }
        }

        static ChunkPos[] newly_loaded;
        newly_loaded.unsafe_reset();

        // TODO tweak?
        for (int iter = 0; iter < 64; iter++) {
            ChunkPos cp;
            if (!cps_to_load.pop(cp)) {
                break;
            }

            if (cp in loaded_chunks) {
                iter--;
                continue;
            }

            newly_loaded ~= cp;
            //loaded_chunks.set(fetch_chunk(cp));
            loaded_chunks.fetch(cp);
            load_count++;
            //writeln("loaded ", cp);

            for (int i = 0; i < 8; i++) {
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
                //writeln("try to queue ", new_cp);

                if (in_vert_sph(new_cp - center_cp, params.chunk_radius, params.chunk_height) && new_cp !in loaded_chunks) {
                    if (!cps_to_load.push(new_cp)) {
                        // TODO when cps_to_load is full (which is often), this can result in chunks never getting loaded (without further movement)
                        break;
                    }
                }
            }
        }

        // TODO i think this basically works but it overprocesses
        // should reuse processing_status?
        foreach (ref cp; newly_loaded) {
            update_chunk_from_surroundings(cp);

            for (int i = 0; i < 8; i++)
            {
                ChunkPos adjacent_cp = void;
                final switch (i) {
                case 0: adjacent_cp = cp.shift!"x"(1); break;
                case 1: adjacent_cp = cp.shift!"y"(1); break;
                case 2: adjacent_cp = cp.shift!"z"(1); break;
                case 3: adjacent_cp = cp.shift!"w"(1); break;
                case 4: adjacent_cp = cp.shift!"x"(-1); break;
                case 5: adjacent_cp = cp.shift!"y"(-1); break;
                case 6: adjacent_cp = cp.shift!"z"(-1); break;
                case 7: adjacent_cp = cp.shift!"w"(-1); break;
                }

                update_chunk_from_surroundings(adjacent_cp);
            }
        }
    }


    void sync_assign_chunk_gl_data() {
        assert(readable_tid() == 0); // TODO

        ChunkPos cp;
        while (assign_chunk_gl_data_stack.pop(cp)) {
            auto c = cp in loaded_chunks;
            c.sync_assign_chunk_gl_data();
        }
    }


    BlockType get_block(BlockPos p) {
        ChunkPos cp = containing_chunkpos(p);

        auto c = cp in loaded_chunks;
        // TODO
        if (c is null) {
            c = load_chunk(cp);
        }
        assert(c);

        BlockPos rel_p = p - cp;
        return c.get_block(rel_p);
    }

    void set_block(BlockPos p, BlockType t) {
        ChunkPos cp = containing_chunkpos(p);

        {
            auto c = cp in loaded_chunks;
            assert(c); // TODO

            BlockPos rel_p = p - cp;

            c.set_block(rel_p, t);

            c.update_from_internal();
        }

        update_chunk_from_surroundings(cp);
        update_surrounding_chunks(cp);
    }

    BlockFace target_nonempty(Vec4 base_pos, Vec4 dir, float max_dist = 10) {
        Vec4BasisSigned[4] possible_sides = void;
        possible_sides[0] = dir.x > 0 ? Vec4BasisSigned.X : Vec4BasisSigned.NX;
        possible_sides[1] = dir.y > 0 ? Vec4BasisSigned.Y : Vec4BasisSigned.NY;
        possible_sides[2] = dir.z > 0 ? Vec4BasisSigned.Z : Vec4BasisSigned.NZ;
        possible_sides[3] = dir.w > 0 ? Vec4BasisSigned.W : Vec4BasisSigned.NW;

        Vec4 start_pos = base_pos;

        do {
            BlockPos bp = BlockPos(start_pos);

            if (get_block(bp) != BlockType.NONE) {
                Vec4 from_center = start_pos - bp.to_vec4_centered();
                int max_p_i = -1;
                float max_p = -LARGE_FLOAT;
                for (int i = 0; i < 8; i++)
                {
                    float p = dot_p(from_center, i.to!Vec4BasisSigned().from_basis());
                    if (p > max_p) {
                        max_p = p;
                        max_p_i = i;
                    }
                }
                assert(max_p_i != -1);
                return BlockFace(bp, max_p_i.to!Vec4BasisSigned());
            }

            Vec4 cube_pos_n = bp.to_vec4();
            Vec4 cube_pos_p = cube_pos_n + Vec4(1, 1, 1, 1);

            float min_d = LARGE_FLOAT;
            size_t min_d_i = -1;
            for (size_t i = 0; i < 4; i++) {
                const Vec4* cube_pos = (possible_sides[i] < 4) ? &cube_pos_p : &cube_pos_n;
                Vec4 cube_normal = possible_sides[i].from_basis();
                if (dot_p(dir, cube_normal) == 0) {
                    //writefln("dot zero");
                    continue; // TODO in principle an intersection is still possible here
                }
                float d = dot_p(*cube_pos - start_pos, cube_normal) / dot_p(dir, cube_normal);

                //writefln("%s %s %s", d, min_d, dot_p(dir, cube_normal));
                if (d < min_d) {
                    min_d = d;
                    min_d_i = i;
                }
            }

            if (min_d_i == cast(size_t)(-1)) {
                // TODO is there something better to do here?
                writefln("no intersections found at %s", dir);
                return BlockFace.INVALID;
            }

            //start_pos += min_d * dir;
            // TODO this is a horrible hack that will blow up in my face eventually
            start_pos += (min_d + 1e-3) * dir;
            assert(BlockPos(start_pos) != bp);

        } while (distance(start_pos, base_pos) < max_dist);

        //writeln("reached max dist");
        return BlockFace.INVALID;
    }
}


ChunkPos containing_chunkpos(BlockPos pos) {
    return pos.divide!CHUNK_SIZE();
}
