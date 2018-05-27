


import util;
import matrix;
import shapes;
import chunk;
import cross_section;


struct World
{
    Vertex[4][] scene;
    Vertex[4][] character;

    Chunk[ChunkPos] loaded_chunks;
}
