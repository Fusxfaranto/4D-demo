
import chunk;
import matrix;
import util;



struct ChunkIndex {
    Chunk[] data;
    uint span;

    this(uint s) {
        span = s;
        data = new Chunk[span ^^ 4];
    }

    private Chunk* index()(auto ref ChunkPos cp) {
        return &data[
            (cp.w % span) +
            (cp.z % span) * span +
            (cp.y % span) * (span ^^ 2) +
            (cp.x % span) * (span ^^ 3)
            ];
    }

    Chunk* opBinaryRight(string s : "in")(auto ref ChunkPos cp) {
        Chunk* c = index(cp);
        auto l = c.lock();
        return c.loc == cp ? c : null;
    }

    void set()(auto ref Chunk c) {
        c.lock.assert_unlocked();
        Chunk* old_c = index(c.loc);
        assert(old_c);
        auto l = old_c.lock();
        *old_c = c;
        old_c.lock.claim();
    }

    // ref Chunk opIndexAssign()(auto ref Chunk c, auto ref ChunkPos cp) {
    //     return (*index(cp) = c);
    // }
}
