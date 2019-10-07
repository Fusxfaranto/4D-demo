


import util;
import matrix;
import shapes;
import chunk;
import cross_section;



alias BlockPos = IPos!1;

struct World
{
    Vertex[4][] scene;
    Vertex[4][] character;

    Chunk[ChunkPos] loaded_chunks;
    //ChunkData[] chunk_data_pool;

    BlockType get_block(BlockPos p) {
        ChunkPos cp = containing_chunkpos(p);

        Chunk* c = cp in loaded_chunks;
        assert(c); // TODO

        BlockPos rel_p = p - cp;
        //writefln("%s %s %s", p, cp, rel_p);
        assert(rel_p.all!(format("a >= 0 && a < %s", CHUNK_SIZE))());

        final switch (c.state) {
        case ChunkDataState.INVALID:
            assert(0);

        case ChunkDataState.EMPTY:
            return BlockType.NONE;

        case ChunkDataState.LOADED:
        case ChunkDataState.OCCLUDED_UNLOADED: // TODO
            assert(c.data);
            return c.data.grid[rel_p.x][rel_p.y][rel_p.z][rel_p.w];
        }
    }

    BlockPos target_nonempty(Vec4 base_pos, Vec4 dir, float max_dist = 20) {
        Vec4BasisSigned[4] possible_sides = void;
        possible_sides[0] = dir.x > 0 ? Vec4BasisSigned.X : Vec4BasisSigned.NX;
        possible_sides[1] = dir.y > 0 ? Vec4BasisSigned.Y : Vec4BasisSigned.NY;
        possible_sides[2] = dir.z > 0 ? Vec4BasisSigned.Z : Vec4BasisSigned.NZ;
        possible_sides[3] = dir.w > 0 ? Vec4BasisSigned.W : Vec4BasisSigned.NW;

        Vec4 start_pos = base_pos;

        do {
            BlockPos bp = BlockPos(start_pos);

            if (get_block(bp) != BlockType.NONE) {
                return bp;
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
                return BlockPos.INVALID;
            }

            //start_pos += min_d * dir;
            // TODO this is a horrible hack that will blow up in my face eventually
            start_pos += (min_d + 1e-4) * dir;
            assert(BlockPos(start_pos) != bp);

        } while (distance(start_pos, base_pos) < max_dist);

        writeln("reached max dist");
        return BlockPos.INVALID;
    }
}


ChunkPos containing_chunkpos(BlockPos pos) {
    return pos.divide!CHUNK_SIZE();
}
