
import std.stdio : writeln, stdout;
import std.range : back, popBack;
import std.array : empty;
import std.conv : to;
import std.math : abs, sqrt, floor;
import std.traits : EnumMembers;
import core.memory : GC;

import matrix;
import render_bindings;
import util;


enum size_t HDTREE_N = 4;
enum size_t HDTREE_RES = 2;
enum size_t CHUNK_SIZE = 2 ^^ HDTREE_N;
enum size_t BLOCKS_IN_CHUNK = CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE;

enum W_SPAN(int N) = 2 ^^ N;
enum Z_SPAN(int N) = (2 ^^ N) * CHUNK_SIZE;
enum Y_SPAN(int N) = (2 ^^ N) * (CHUNK_SIZE ^^ 2);


enum BlockType : ubyte
{
    NONE,
    TEST,
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


struct IndexVec4
{
    size_t x;
    size_t y;
    size_t z;
    size_t w;

    IndexVec4 opBinary(string op)(auto ref in IndexVec4 b) const pure if (op == "+")
    {
        return mixin("IndexVec4(x" ~ op ~ "b.x, y" ~ op ~ "b.y, z" ~ op ~ "b.z, w" ~ op ~ "b.w)");
    }

    size_t to_index() const pure
    {
        return w + CHUNK_SIZE * (z + CHUNK_SIZE * (y + CHUNK_SIZE * x));
    }
}


// TODO mark "surrounded" segments as invisible
// (n.b. an unloaded neighboring chunk counts as an opaque wall)
enum HDTreeVisibility
{
    VISIBLE,
    EMPTY,
}

struct HDTree(int N)
{
    static assert (N >= HDTREE_RES);

    static if (N <= HDTREE_RES)
    {
        // TODO should we really keep an index here?
        //size_t _index;
        //alias _index this;
    }
    else
    {
        HDTree!(N - 1)[16] _subtrees;
        alias _subtrees this;
    }

    HDTreeVisibility visibility = HDTreeVisibility.VISIBLE;
}


// really the offset for the subtrees of N
IndexVec4 get_hdtree_index(int N)(size_t i)
{
    IndexVec4 o = IndexVec4(
        (i & (1 << 0)) ? (2 ^^ (N - 1)) : 0,
        (i & (1 << 1)) ? (2 ^^ (N - 1)) : 0,
        (i & (1 << 2)) ? (2 ^^ (N - 1)) : 0,
        (i & (1 << 3)) ? (2 ^^ (N - 1)) : 0,
        );

    return o;
}


enum ChunkStatus
{
    NOT_PROCESSED,
    PROCESSED,
}

alias ChunkGrid = BlockType[CHUNK_SIZE][CHUNK_SIZE][CHUNK_SIZE][CHUNK_SIZE];
struct Chunk
{
    //ChunkPos location;
    union
    {
        ChunkGrid grid;
        BlockType[BLOCKS_IN_CHUNK] data;
    }

    ChunkGLData *gl_data;
    ChunkStatus status;
    HDTree!HDTREE_N tree;

    const(BlockType*) begin() const pure
    {
        return &data[0];
    }

    const(BlockType*) end() const pure
    {
        return &data[0] + BLOCKS_IN_CHUNK;
    }

    void update_gl_data(ChunkPos loc) {
        // TODO implement actually updating more than once
        assert(gl_data is null);

        // TODO double check that this is actually the right type lol
        float* vert_data = cast(float*)(gen_chunk_gl_data(&gl_data));
        assert(vert_data);
        float* vert_data_init = vert_data;
        scope(exit) finish_chunk_gl_data(gl_data, (vert_data - vert_data_init) / 8);

        // TODO uhh not this
        const(BlockType)* b = begin();
        for (size_t x = 0; x < CHUNK_SIZE; x++)
        {
            for (size_t y = 0; y < CHUNK_SIZE; y++)
            {
                for (size_t z = 0; z < CHUNK_SIZE; z++)
                {
                    for (size_t w = 0; w < CHUNK_SIZE; w++, b++)
                    {
                        assert(IndexVec4(x, y, z, w).to_index() == b - begin());

                        if (*b == BlockType.NONE)
                        {
                            continue;
                        }

                        Vec4 block_pos = Vec4(x, y, z, w) + loc.to_vec4();

                        void process_cube(Vec4 pos, Vec4BasisSigned dir) {
                            // TODO debug
                            if (dir != Vec4BasisSigned.Y) return;

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

Vec4 indexvec4_to_vec4(IndexVec4 idx)
{
    return Vec4(idx.x, idx.y, idx.z, idx.w);
}

// float chunkpos_dist(ChunkPos a, ChunkPos b)
// {
//     return sqrt(to!real((a.x - b.x) ^^ 2 + (a.y - b.y) ^^ 2 + (a.z - b.z) ^^ 2 + (a.w - b.w) ^^ 2));
// }

int chunkpos_l1_dist(ChunkPos a, ChunkPos b)
{
    return abs(a.x - b.x) + abs(a.y - b.y) + abs(a.z - b.z) + abs(a.w - b.w);
}



void initialize_hdtree(T : HDTree!N, int N)(in Chunk c, ref T tree, IndexVec4 idx = IndexVec4.init)
{
    static if (N <= HDTREE_RES + 1)
    {
        const(BlockType)* b = &c.data[idx.to_index()];
        bool all_empty = true;

    outer:
        for (size_t x = 0; x < 2 ^^ N; x++, b += CHUNK_SIZE ^^ 3 - Y_SPAN!N)
        {
            for (size_t y = 0; y < 2 ^^ N; y++, b += CHUNK_SIZE ^^ 2 - Z_SPAN!N)
            {
                for (size_t z = 0; z < 2 ^^ N; z++, b += CHUNK_SIZE - W_SPAN!N)
                {
                    for (size_t w = 0; w < 2 ^^ N; w++, b++)
                    {
                        if (*b != BlockType.NONE)
                        {
                            all_empty = false;
                            break outer;
                        }
                    }
                }
            }
        }

        if (all_empty)
        {
            tree.visibility = HDTreeVisibility.EMPTY;
        }
        else
        {
            static if (N > HDTREE_RES)
            {
                foreach (i; 0..16)
                {
                    initialize_hdtree(c, tree[i], idx + get_hdtree_index!N(i));
                }
            }
        }
    }
    else
    {
        bool all_empty = true;
        foreach (i; 0..16)
        {
            initialize_hdtree(c, tree[i], idx + get_hdtree_index!N(i));

            if (tree[i].visibility != HDTreeVisibility.EMPTY)
            {
                all_empty = false;
            }
        }

        if (all_empty)
        {
            tree.visibility = HDTreeVisibility.EMPTY;
        }
    }
}

T initialize_empty_hdtree(T : HDTree!N, int N)()
{
    T tree;
    static if (N <= HDTREE_RES)
    {
        tree.visibility = HDTreeVisibility.EMPTY;
    }
    else
    {
        tree.visibility = HDTreeVisibility.EMPTY;
        foreach (i; 0..16)
        {
            tree[i] = initialize_empty_hdtree!(HDTree!(N - 1))();
        }
    }
    return tree;
}

enum HDTree!HDTREE_N EMPTY_HDTREE = initialize_empty_hdtree!(HDTree!HDTREE_N)();

Chunk gen_fixed_chunk()
{
    Chunk c;
    BlockType* b = &c.data[0];
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
                    if ((b - &c.data[0]) % 37 == 8)
                    //if (w == x && w == y && w == z && w == 0)
                    //if (x < 5 && x % 2 == 0 && w == y && w == z && w == 0)
                    //if ((x != 0) + (y != 0) + (z != 0) + (w != 0) <= 1)
                    {
                        *b = BlockType.TEST;
                    }
                }
            }
        }
    }

    initialize_hdtree(c, c.tree);
    return c;
}

Chunk fetch_chunk(ChunkPos loc)
{
    static Chunk* fixed_chunk = null;

    Chunk c;

    if (//true ||
        loc == ChunkPos(-1, -1, -1, 0) &&
        loc.y < 0
        )
    {
        if (!fixed_chunk)
        {
            fixed_chunk = new Chunk();
            *fixed_chunk = gen_fixed_chunk();
        }

        c = *fixed_chunk;
    }
    else
    {
        c.tree = EMPTY_HDTREE;
    }

    c.update_gl_data(loc);

    return c;
}



void load_chunks(Vec4 center, int l1_radius, ref Chunk[ChunkPos] loaded_chunks)
{
    static ChunkPos[] load_stack;
    load_stack.length = 0;
    load_stack.assumeSafeAppend();

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

    while (!load_stack.empty())
    {
        ChunkPos cp = load_stack.back();
        load_stack.popBack();

        if (cp in loaded_chunks)
        {
            continue;
        }

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
}
