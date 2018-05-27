
import std.range : back, popBack;
import std.array : empty;
import std.conv : to;
import std.math : sqrt, floor;

import matrix;


enum size_t HDTREE_N = 4;
enum size_t CHUNK_SIZE = 2 ^^ HDTREE_N;
enum size_t BLOCKS_IN_CHUNK = CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE;

enum BlockType
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


enum HDTreeVisibility
{
    VISIBLE,
    EMPTY,
}

struct HDTree(int N)
{
    static if (N == 0)
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

    ChunkStatus status;
    HDTree!HDTREE_N tree;
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
    static if (N <= 3)
    {
        const(BlockType)* b = &c.data[idx.to_index()];
        bool all_empty = true;

    outer:
        foreach (x; 0..(2 ^^ N))
        {
            foreach (y; 0..(2 ^^ N))
            {
                foreach (z; 0..(2 ^^ N))
                {
                    for (size_t w = 0; w < 2 ^^ N; w++, b++)
                    {
                        if (*b == BlockType.NONE)
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

Chunk get_chunk(ChunkPos loc)
{
    Chunk c;

    if (loc == ChunkPos(0, 0, 0, 0)
        )
    {
        // c.grid[1][0][0][0] = BlockType.TEST;
        for (int i = 0; i < BLOCKS_IN_CHUNK; i += 33)
        {
            c.data[i] = BlockType.TEST;
        }
    }

    initialize_hdtree(c, c.tree);

    return c;
}



void load_chunks(Vec4 center, int l1_radius, ref Chunk[ChunkPos] loaded_chunks)
{
    static ChunkPos[] load_stack;

    ChunkPos center_cp = coords_to_chunkpos(center);
    //if (center_cp in loaded_chunks)
    if (true)
    {
        load_stack.length = 0;
        foreach (i, start_cp; [
                     center_cp.shift!"x"(l1_radius),
                     center_cp.shift!"y"(l1_radius),
                     center_cp.shift!"z"(l1_radius),
                     center_cp.shift!"w"(l1_radius),
                     center_cp.shift!"x"(-l1_radius),
                     center_cp.shift!"y"(-l1_radius),
                     center_cp.shift!"z"(-l1_radius),
                     center_cp.shift!"w"(-l1_radius),
                     ])
        {
            if (start_cp !in loaded_chunks)
            {
                load_stack ~= start_cp;
                break;
            }
        }
    }
    else
    {
        load_stack.length = 1;
        load_stack[0] = center_cp;
    }

    while (!load_stack.empty())
    {
        ChunkPos cp = load_stack.back();
        load_stack.popBack();
        loaded_chunks[cp] = get_chunk(cp);
        writeln("loaded ", cp);

        foreach (new_cp; [
                     cp.shift!"x"(1),
                     cp.shift!"y"(1),
                     cp.shift!"z"(1),
                     cp.shift!"w"(1),
                     cp.shift!"x"(-1),
                     cp.shift!"y"(-1),
                     cp.shift!"z"(-1),
                     cp.shift!"w"(-1),
                     ])
        {
            //writeln("try to queue ", new_cp);
            if (chunkpos_l1_dist(center_cp, new_cp) <= l1_radius && new_cp !in loaded_chunks)
            {
                load_stack ~= new_cp;
            }
        }
    }
}
