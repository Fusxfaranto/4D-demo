


import util;
import matrix;
import shapes;
import chunk;
import cross_section;


enum ChunkEntryStatus {
    INVALID,
    LOADED,
    COPY,
    INVSIBLE,
}

struct ChunkEntry {
    ChunkEntryStatus status;
    Chunk* chunk;
}


struct World
{
    Vertex[4][] scene;
    Vertex[4][] character;

    Chunk[ChunkPos] loaded_chunks;
    //ChunkEntry[] chunk_pool;
}
