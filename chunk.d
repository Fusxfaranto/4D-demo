
import std.range : back;
import std.array : empty;
import std.conv : to;
import std.math : abs, sqrt, floor;
import std.traits : EnumMembers;
import core.memory : GC;

import matrix;
import render_bindings;
import util;



enum size_t CHUNK_SIZE = 2 ^^ 4;
enum size_t BLOCKS_IN_CHUNK = CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE;


enum BlockType : ubyte
{
    NONE,
    TEST,
}

bool is_transparent(BlockType b) {
    return b == BlockType.NONE;
}


struct ChunkPos
{
    int x;
    int y;
    int z;
    int w;

    ChunkPos shift(string d)(int val) pure const
    {
        ChunkPos c = this.dup();
        mixin("c." ~ d) += val;
        return c;
    }

    Vec4 to_vec4() pure const
    {
        return Vec4(x, y, z, w) * CHUNK_SIZE;
    }

    Vec4 to_vec4_centered() pure const
    {
        return Vec4(x + 0.5, y + 0.5, z + 0.5, w + 0.5) * CHUNK_SIZE;
    }

    ChunkPos dup() pure const
    {
        return ChunkPos(x, y, z, w);
    }
}


alias ChunkGrid = BlockType[CHUNK_SIZE][CHUNK_SIZE][CHUNK_SIZE][CHUNK_SIZE];
struct ChunkData {
    union {
        ChunkGrid grid;
        BlockType[BLOCKS_IN_CHUNK] data;
    }

    BlockType* begin()
    {
        return &data[0];
    }

    BlockType* end()
    {
        return &data[0] + BLOCKS_IN_CHUNK;
    }
}

enum ChunkDataState {
    INVALID,
    LOADED,
    EMPTY,
    OCCLUDED_UNLOADED,
//    SPARSE, // TODO?
}

enum ChunkProcessingStatus
{
    NOT_PROCESSED,
    PROCESSED,
}

struct Chunk
{
    //ChunkPos location;

    ChunkData *data;
    ChunkGLData *gl_data;

    ubyte occludes_side;
    ubyte occluded_from;

    ChunkDataState state;
    ChunkProcessingStatus processing_status;

    void update_from_internal() {
        final switch (state) {
        case ChunkDataState.INVALID:
            assert(0);

        case ChunkDataState.EMPTY:
            return;

        case ChunkDataState.LOADED:
        case ChunkDataState.OCCLUDED_UNLOADED: // TODO
            break;
        }

        assert(data);

        // TODO this is naive and can probably be an order faster
        occludes_side = 0xff;
        for (size_t x = 0; x < CHUNK_SIZE; x++) {
            for (size_t y = 0; y < CHUNK_SIZE; y++) {
                for (size_t z = 0; z < CHUNK_SIZE; z++) {
                    for (size_t w = 0; w < CHUNK_SIZE; w++) {
                        if (x == 0 && is_transparent(data.grid[x][y][z][w])) {
                            occludes_side &= ~(1 << 0);
                        }
                        if (y == 0 && is_transparent(data.grid[x][y][z][w])) {
                            occludes_side &= ~(1 << 1);
                        }
                        if (z == 0 && is_transparent(data.grid[x][y][z][w])) {
                            occludes_side &= ~(1 << 2);
                        }
                        if (w == 0 && is_transparent(data.grid[x][y][z][w])) {
                            occludes_side &= ~(1 << 3);
                        }
                        if (x == CHUNK_SIZE - 1 && is_transparent(data.grid[x][y][z][w])) {
                            occludes_side &= ~(1 << 4);
                        }
                        if (y == CHUNK_SIZE - 1 && is_transparent(data.grid[x][y][z][w])) {
                            occludes_side &= ~(1 << 5);
                        }
                        if (z == CHUNK_SIZE - 1 && is_transparent(data.grid[x][y][z][w])) {
                            occludes_side &= ~(1 << 6);
                        }
                        if (w == CHUNK_SIZE - 1 && is_transparent(data.grid[x][y][z][w])) {
                            occludes_side &= ~(1 << 7);
                        }
                    }
                }
            }
        }
    }

    void update_from_surroundings(ChunkPos loc, const ref Chunk[ChunkPos] chunks) {
        final switch (state) {
        case ChunkDataState.INVALID:
            assert(0);

        case ChunkDataState.LOADED:
        case ChunkDataState.OCCLUDED_UNLOADED:
            break;

        case ChunkDataState.EMPTY:
            return;
        }

        occluded_from = 0;
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

            const Chunk* p = adjacent_loc in chunks;
            int relative_side = (i + 4) & 0b111;
            if (p is null || p.occludes_side & (1 << relative_side)) {
                occluded_from |= 1 << i;
            }
        }

        if (occluded_from == 0xff) {
            // TODO actually unload data?
            state = ChunkDataState.OCCLUDED_UNLOADED;
        }

        update_gl_data(loc);
    }

    private void update_gl_data(ChunkPos loc) {
        // TODO implement actually updating more than once
        //assert(gl_data is null);
        if (gl_data !is null) {
            writeln("NOT RELOADING GL DATA ", loc);
            return;
        }

        assert(data);

        // TODO double check that this is actually the right type lol
        float* vert_data = cast(float*)(gen_chunk_gl_data(&gl_data));
        assert(vert_data);
        float* vert_data_init = vert_data;
        scope(exit) finish_chunk_gl_data(gl_data, (vert_data - vert_data_init) / 8);

        // TODO uhh not this
        const(BlockType)* b = data.begin();
        for (size_t x = 0; x < CHUNK_SIZE; x++)
        {
            for (size_t y = 0; y < CHUNK_SIZE; y++)
            {
                for (size_t z = 0; z < CHUNK_SIZE; z++)
                {
                    for (size_t w = 0; w < CHUNK_SIZE; w++, b++)
                    {
                        if (*b == BlockType.NONE)
                        {
                            continue;
                        }

                        Vec4 block_pos = Vec4(x, y, z, w) + loc.to_vec4();

                        void process_cube(Vec4 pos, Vec4BasisSigned dir) {
                            *vert_data++ = pos.x;
                            *vert_data++ = pos.y;
                            *vert_data++ = pos.z;
                            *vert_data++ = pos.w;

                            Vec4 rel_corner;
                            final switch (dir)
                            {
                            case Vec4BasisSigned.NX:
                                rel_corner = Vec4(0, 1, 1, 1);
                                break;

                            case Vec4BasisSigned.NY:
                                rel_corner = Vec4(1, 0, 1, 1);
                                break;

                            case Vec4BasisSigned.NZ:
                                rel_corner = Vec4(1, 1, 0, 1);
                                break;

                            case Vec4BasisSigned.NW:
                                rel_corner = Vec4(1, 1, 1, 0);
                                break;

                            case Vec4BasisSigned.X:
                                rel_corner = Vec4(0, -1, -1, -1);
                                break;

                            case Vec4BasisSigned.Y:
                                rel_corner = Vec4(-1, 0, -1, -1);
                                break;

                            case Vec4BasisSigned.Z:
                                rel_corner = Vec4(-1, -1, 0, -1);
                                break;

                            case Vec4BasisSigned.W:
                                rel_corner = Vec4(-1, -1, -1, 0);
                                break;
                            }

                            *vert_data++ = rel_corner.x;
                            *vert_data++ = rel_corner.y;
                            *vert_data++ = rel_corner.z;
                            *vert_data++ = rel_corner.w;
                        }

                        if (x == 0 || x == CHUNK_SIZE - 1 || b[-(CHUNK_SIZE ^^ 3)] == BlockType.NONE)
                        {
                            process_cube(block_pos, Vec4BasisSigned.NX);
                        }
                        if (y == 0 || y == CHUNK_SIZE - 1 || b[-(CHUNK_SIZE ^^ 2)] == BlockType.NONE)
                        {
                            process_cube(block_pos, Vec4BasisSigned.NY);
                        }
                        if (z == 0 || z == CHUNK_SIZE - 1 || b[-(CHUNK_SIZE ^^ 1)] == BlockType.NONE)
                        {
                            process_cube(block_pos, Vec4BasisSigned.NZ);
                        }
                        if (w == 0 || w == CHUNK_SIZE - 1 || b[-(CHUNK_SIZE ^^ 0)] == BlockType.NONE)
                        {
                            process_cube(block_pos, Vec4BasisSigned.NW);
                        }

                        block_pos += Vec4(1, 1, 1, 1);

                        if (x == 0 || x == CHUNK_SIZE - 1 || b[CHUNK_SIZE ^^ 3] == BlockType.NONE)
                        {
                            process_cube(block_pos, Vec4BasisSigned.X);
                        }
                        if (y == 0 || y == CHUNK_SIZE - 1 || b[CHUNK_SIZE ^^ 2] == BlockType.NONE)
                        {
                            process_cube(block_pos, Vec4BasisSigned.Y);
                        }
                        if (z == 0 || z == CHUNK_SIZE - 1 || b[CHUNK_SIZE ^^ 1] == BlockType.NONE)
                        {
                            process_cube(block_pos, Vec4BasisSigned.Z);
                        }
                        if (w == 0 || w == CHUNK_SIZE - 1 || b[CHUNK_SIZE ^^ 0] == BlockType.NONE)
                        {
                            process_cube(block_pos, Vec4BasisSigned.W);
                        }
                    }
                }
            }
        }
    }
}



ChunkPos coords_to_chunkpos(Vec4 v)
{
    return ChunkPos(
        to!int(floor(v.x / CHUNK_SIZE)),
        to!int(floor(v.y / CHUNK_SIZE)),
        to!int(floor(v.z / CHUNK_SIZE)),
        to!int(floor(v.w / CHUNK_SIZE)),
        );
}

// Vec4 chunk_idx_to_vec4(size_t idx)
// {
//     return Vec4(
//         idx / (CHUNK_SIZE ^^ 3),
//         (idx / (CHUNK_SIZE ^^ 2)) % CHUNK_SIZE,
//         (idx / CHUNK_SIZE) % CHUNK_SIZE,
//         idx % CHUNK_SIZE,
//         );
// }

// float chunkpos_dist(ChunkPos a, ChunkPos b)
// {
//     return sqrt(to!real((a.x - b.x) ^^ 2 + (a.y - b.y) ^^ 2 + (a.z - b.z) ^^ 2 + (a.w - b.w) ^^ 2));
// }

int chunkpos_l1_dist(ChunkPos a, ChunkPos b)
{
    return abs(a.x - b.x) + abs(a.y - b.y) + abs(a.z - b.z) + abs(a.w - b.w);
}


Chunk gen_fixed_chunk()
{
    Chunk c;
    c.data = new ChunkData;
    c.state = ChunkDataState.LOADED;
    BlockType* b = c.data.begin();
    foreach (x; 0..CHUNK_SIZE)
    {
        foreach (y; 0..CHUNK_SIZE)
        {
            foreach (z; 0..CHUNK_SIZE)
            {
                for (size_t w = 0; w < CHUNK_SIZE; w++, b++)
                {
                    enum n = 11;
                    //if (w == x && w == y && w == z)
                    //if (x < 8 && y < 8 && z < 8 && w < 8)
                    //if (x < n && y < n && z < n && w < n)
                    //if ((b - &c.data[0]) % 1755 == 0)
                    //if ((b - &c.data[0]) % 37 == 8)
                    //if (w == x && w == y && w == z && w == 0)
                    //if (x == 0 && y == 0 && z == 0 && w == 0)
                    //if (x < 5 && x % 2 == 0 && w == y && w == z && w == 0)
                    //if ((x != 0) + (y != 0) + (z != 0) + (w != 0) <= 1)
                    if (true)
                    {
                        *b = BlockType.TEST;
                    }
                }
            }
        }
    }

    return c;
}

Chunk fetch_chunk(ChunkPos loc)
{
    static Chunk* fixed_chunk = null;

    Chunk c;

    if (
        //true
        //loc == ChunkPos(-1, -1, -1, 0)
        loc.y < 0
        //loc == ChunkPos(0, 0, 0, 0)
        //loc == ChunkPos(1, 0, 1, 0)
        )
    {
        if (!fixed_chunk)
        {
            fixed_chunk = new Chunk();
            *fixed_chunk = gen_fixed_chunk();
        }

        c = *fixed_chunk;
    } else {
        c.state = ChunkDataState.EMPTY;
    }

    //c.update_gl_data(loc);

    c.update_from_internal();

    return c;
}


// TODO this need some general rethinking
void load_chunks(Vec4 center, int l1_radius, ref Chunk[ChunkPos] loaded_chunks)
{
    static ChunkPos[] load_stack;
    load_stack.unsafe_reset();

    //GC.disable();
    //scope(exit) GC.enable();

    ChunkPos center_cp = coords_to_chunkpos(center);
    //if (center_cp in loaded_chunks)
    if (true)
    {
        for (int i = 0; i < 8; i++)
        {
            ChunkPos start_cp = void;
            final switch (i) {
            case 0: start_cp = center_cp.shift!"x"(1); break;
            case 1: start_cp = center_cp.shift!"y"(1); break;
            case 2: start_cp = center_cp.shift!"z"(1); break;
            case 3: start_cp = center_cp.shift!"w"(1); break;
            case 4: start_cp = center_cp.shift!"x"(-1); break;
            case 5: start_cp = center_cp.shift!"y"(-1); break;
            case 6: start_cp = center_cp.shift!"z"(-1); break;
            case 7: start_cp = center_cp.shift!"w"(-1); break;
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
            if (chunkpos_l1_dist(center_cp, new_cp) <= l1_radius && new_cp !in loaded_chunks)
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
