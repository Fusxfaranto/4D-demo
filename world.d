
import util;
import matrix;
import shapes;
import chunk;
import cross_section;



alias BlockPos = IPos!1;


struct BlockFace {
    BlockPos pos;
    Vec4BasisSigned face;

    enum INVALID = BlockFace(BlockPos.INVALID, Vec4BasisSigned.init);
}


struct World
{
    Vertex[4][] scene;
    Vertex[4][] character;

    Chunk[ChunkPos] loaded_chunks;
    //ChunkData[] chunk_data_pool;

    void update_chunk(ChunkPos cp) {
        Chunk* c = cp in loaded_chunks;
        assert(c); // TODO

        c.update_from_internal();
        c.update_from_surroundings(cp, loaded_chunks);
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

            Chunk* p = adjacent_cp in loaded_chunks;
            if (p) {
                p.update_from_surroundings(adjacent_cp, loaded_chunks);
            }
        }
    }


    // TODO this need some general rethinking
    void load_chunks(Vec4 center, int radius)
    {
        static ChunkPos[] load_stack;
        load_stack.unsafe_reset();

        //GC.disable();
        //scope(exit) GC.enable();

        ChunkPos center_cp = ChunkPos(center);
        //if (center_cp in loaded_chunks)
        if (true)
        {
            for (int i = 0; i < 8; i++)
            {
                ChunkPos start_cp = void;
                final switch (i) {
                case 0: start_cp = center_cp.shift!"x"(radius); break;
                case 1: start_cp = center_cp.shift!"y"(radius); break;
                case 2: start_cp = center_cp.shift!"z"(radius); break;
                case 3: start_cp = center_cp.shift!"w"(radius); break;
                case 4: start_cp = center_cp.shift!"x"(-radius); break;
                case 5: start_cp = center_cp.shift!"y"(-radius); break;
                case 6: start_cp = center_cp.shift!"z"(-radius); break;
                case 7: start_cp = center_cp.shift!"w"(-radius); break;
                }
                if (start_cp !in loaded_chunks)
                {
                    load_stack ~= start_cp;
                    break;
                }
            }
        }
        else
        {
            load_stack ~= center_cp;
        }


        static ChunkPos[] newly_loaded;
        newly_loaded.unsafe_reset();

        while (!load_stack.empty())
        {
            ChunkPos cp = load_stack.back();
            load_stack.unsafe_popback();

            if (cp in loaded_chunks)
            {
                continue;
            }

            newly_loaded ~= cp;
            loaded_chunks[cp] = fetch_chunk(cp);
            writeln("loaded ", cp);
            debug(prof) profile_checkpoint();

            for (int i = 0; i < 8; i++)
            {
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
                if (distance(center_cp, new_cp) <= radius && new_cp !in loaded_chunks)
                {
                    load_stack ~= new_cp;
                }
            }
        }

        // TODO i think this basically works but it overprocesses
        // should reuse processing_status?
        foreach (ref cp; newly_loaded) {
            loaded_chunks[cp].update_from_surroundings(cp, loaded_chunks);

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

                Chunk* p = adjacent_cp in loaded_chunks;
                if (p) {
                    p.update_from_surroundings(adjacent_cp, loaded_chunks);
                }
            }
        }
    }


    BlockType get_block(BlockPos p) {
        ChunkPos cp = containing_chunkpos(p);

        Chunk* c = cp in loaded_chunks;
        assert(c); // TODO

        BlockPos rel_p = p - cp;
        //writefln("%s %s %s", p, cp, rel_p);
        assert(rel_p.all!(format("a >= 0 && a < %s", CHUNK_SIZE))());

        final switch (c.state) {
        case ChunkDataState.INVALID:
        case ChunkDataState.OCCLUDED_UNLOADED: // TODO
            assert(0);

        case ChunkDataState.EMPTY:
            return BlockType.NONE;

        case ChunkDataState.LOADED:
            assert(c.data);
            return c.data.grid[rel_p.x][rel_p.y][rel_p.z][rel_p.w];
        }
    }

    void set_block(BlockPos p, BlockType t) {
        ChunkPos cp = containing_chunkpos(p);

        Chunk* c = cp in loaded_chunks;
        assert(c); // TODO

        BlockPos rel_p = p - cp;
        //writefln("%s %s %s", p, cp, rel_p);
        assert(rel_p.all!(format("a >= 0 && a < %s", CHUNK_SIZE))());

        final switch (c.state) {
        case ChunkDataState.INVALID:
        case ChunkDataState.OCCLUDED_UNLOADED: // TODO
            assert(0);

        case ChunkDataState.EMPTY:
            c.allocate_data();
            goto case ChunkDataState.LOADED;

        case ChunkDataState.LOADED:
            assert(c.data);
            c.data.grid[rel_p.x][rel_p.y][rel_p.z][rel_p.w] = t;
        }

        update_chunk(cp);
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
