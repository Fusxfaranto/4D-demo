
import std.range : back, popBack;
import std.array : empty;
import std.conv : to;
import std.math : sqrt, floor;

import matrix;


enum uint CHUNK_SIZE = 8;
enum uint BLOCKS_IN_CHUNK = CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE;

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

    ChunkPos dup() pure const
    {
        return ChunkPos(x, y, z, w);
    }
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


float chunkpos_dist(ChunkPos a, ChunkPos b)
{
    return sqrt(to!real((a.x - b.x) ^^ 2 + (a.y - b.y) ^^ 2 + (a.z - b.z) ^^ 2 + (a.w - b.w) ^^ 2));
}

Chunk get_chunk(ChunkPos loc)
{
    Chunk c;

    if (loc == ChunkPos(0, 0, 0, 0))
    {
        c.grid[1][0][0][0] = BlockType.TEST;
        // for (int i = 16; i < BLOCKS_IN_CHUNK; i += 10001 * 101)
        // {
        //     c.data[i] = BlockType.TEST;
        // }
    }

    return c;
}


// TODO this doesn't presently "work", i.e. it doesn't actually move the loaded area along with the player
void load_chunks(Vec4 center, float radius, ref Chunk[ChunkPos] loaded_chunks)
{
    static ChunkPos[] load_stack;

    // TODO something that allocates less
    ChunkPos center_cp = coords_to_chunkpos(center);
    if (center_cp in loaded_chunks)
    {
        return;
    }

    load_stack.length = 1;
    load_stack[0] = center_cp;

    while (!load_stack.empty())
    {
        ChunkPos cp = load_stack.back();
        load_stack.popBack();
        loaded_chunks[cp] = get_chunk(cp);
        //writeln("loaded ", cp);

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
            if (chunkpos_dist(center_cp, new_cp) <= radius && new_cp !in loaded_chunks)
            {
                load_stack ~= new_cp;
            }
        }
    }
}
