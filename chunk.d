
import std.range : back;
import std.array : empty;
import std.conv : to;
import std.functional : unaryFun;
import std.math : abs, sqrt, floor;
import std.traits : EnumMembers;
import core.memory : GC;

import matrix;
import render_bindings;
import util;



enum CHUNK_SIZE = 2 ^^ 4;
enum BLOCKS_IN_CHUNK = CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE;


enum BlockType : ubyte {
    NONE,
        TEST,
        }

bool is_transparent(BlockType b) {
    return b == BlockType.NONE;
}


struct IPos(size_t N)
{
    int x;
    int y;
    int z;
    int w;

    enum INVALID = IPos!N(int.max, int.max, int.max, int.max);

    this(int x_, int y_, int z_, int w_) {
        x = x_;
        y = y_;
        z = z_;
        w = w_;
    }

    this(Vec4 v) {
        x = to!int(floor(v.x / N));
        y = to!int(floor(v.y / N));
        z = to!int(floor(v.z / N));
        w = to!int(floor(v.w / N));
    }

    IPos!N shift(string d)(int val) pure const
    {
        IPos!N c = this.dup();
        mixin("c." ~ d) += val;
        return c;
    }

    Vec4 to_vec4() pure const
    {
        return Vec4(x, y, z, w) * N;
    }

    Vec4 to_vec4_centered() pure const
    {
        return Vec4(x + 0.5, y + 0.5, z + 0.5, w + 0.5) * N;
    }

    IPos!N dup() pure const
    {
        return IPos!N(x, y, z, w);
    }

    bool all(alias Fp)() pure const {
        alias F = unaryFun!Fp;
        return F(x) && F(y) && F(z) && F(w);
    }

    // TODO is this correct? (at boundaries)
    auto divide(int F)() pure const {
        return IPos!(N * F)(
            div_floor(x, F),
            div_floor(y, F),
            div_floor(z, F),
            div_floor(w, F),
            );
    }

    auto opBinary(string op, T)(auto ref in T b) const if ((op == "-" || op == "+"))
    {
        static if (is(T : IPos!Np, size_t Np)) {
            static assert(N <= Np); // TODO
            enum int F = Np / N;
            static assert(F * N == Np);
            return mixin("IPos!N(x" ~ op ~ "(b.x * F), y" ~ op ~ "(b.y * F), z" ~ op ~ "(b.z * F), w" ~ op ~ "(b.w * F))");
        } else {
            static assert(0);
        }
    }

    // IPos!N opBinaryRight(string op)(int a) const if (op == "*" || op == "/")
    // {
    //     return mixin("IPos!N(a " ~ op ~ " x, a " ~ op ~ " y, a " ~ op ~ " z, a " ~ op ~ " w)");
    // }
}

float distance(T)(auto ref in T a, auto ref in T b) if (is(T : IPos!Np, size_t Np)) {
    return sqrt(to!real((a.x - b.x) ^^ 2 + (a.y - b.y) ^^ 2 + (a.z - b.z) ^^ 2 + (a.w - b.w) ^^ 2));
}



// TODO something better
T to_ipos(T : IPos!N, size_t N)(Vec4BasisSigned b) pure {
    return T(b.to_vec4());
}

alias ChunkPos = IPos!CHUNK_SIZE;


struct ChunkGrid(T) {
    alias Grid = T[CHUNK_SIZE][CHUNK_SIZE][CHUNK_SIZE][CHUNK_SIZE];

    union {
        Grid grid;
        T[BLOCKS_IN_CHUNK] data;
    }

    T* begin()
    {
        return &data[0];
    }

    T* end()
    {
        return &data[0] + BLOCKS_IN_CHUNK;
    }

    // TODO something better and also static
    IT offset(IT)(IT x, IT y, IT z, IT w) {
        return cast(IT)(&grid[x][y][z][w] - &data[0]);
    }

    static IT get_x(IT)(IT b) {
        return b / (CHUNK_SIZE ^^ 3);
    }

    static IT get_y(IT)(IT b) {
        return (b / (CHUNK_SIZE ^^ 2)) % CHUNK_SIZE;
    }

    static IT get_z(IT)(IT b) {
        return (b / CHUNK_SIZE) % CHUNK_SIZE;
    }

    static IT get_w(IT)(IT b) {
        return b % CHUNK_SIZE;
    }
}
alias ChunkData = ChunkGrid!BlockType;


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

    void allocate_data() {
        final switch (state) {
        case ChunkDataState.INVALID:
        case ChunkDataState.LOADED:
            assert(0);

        case ChunkDataState.OCCLUDED_UNLOADED:
        case ChunkDataState.EMPTY:
            break;
        }

        assert(data is null);

        // TODO sparse
        data = new ChunkData;
        state = ChunkDataState.LOADED;
    }

    void update_from_internal() {
        final switch (state) {
        case ChunkDataState.INVALID:
            assert(0);

        case ChunkDataState.EMPTY:
        case ChunkDataState.OCCLUDED_UNLOADED: // TODO
            return;

        case ChunkDataState.LOADED:
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
                            occludes_side &= ~(1 << 4);
                        }
                        if (y == 0 && is_transparent(data.grid[x][y][z][w])) {
                            occludes_side &= ~(1 << 5);
                        }
                        if (z == 0 && is_transparent(data.grid[x][y][z][w])) {
                            occludes_side &= ~(1 << 6);
                        }
                        if (w == 0 && is_transparent(data.grid[x][y][z][w])) {
                            occludes_side &= ~(1 << 7);
                        }
                        if (x == CHUNK_SIZE - 1 && is_transparent(data.grid[x][y][z][w])) {
                            occludes_side &= ~(1 << 0);
                        }
                        if (y == CHUNK_SIZE - 1 && is_transparent(data.grid[x][y][z][w])) {
                            occludes_side &= ~(1 << 1);
                        }
                        if (z == CHUNK_SIZE - 1 && is_transparent(data.grid[x][y][z][w])) {
                            occludes_side &= ~(1 << 2);
                        }
                        if (w == CHUNK_SIZE - 1 && is_transparent(data.grid[x][y][z][w])) {
                            occludes_side &= ~(1 << 3);
                        }
                    }
                }
            }
        }
    }

    /*
      enum W_SPAN(int N) = 2 ^^ N;
      enum Z_SPAN(int N) = (2 ^^ N) * CHUNK_SIZE;
      enum Y_SPAN(int N) = (2 ^^ N) * (CHUNK_SIZE ^^ 2);

      for (size_t x = 0; x < 2 ^^ N; x++, b += CHUNK_SIZE ^^ 3 - Y_SPAN!N)
      {
      for (size_t y = 0; y < 2 ^^ N; y++, b += CHUNK_SIZE ^^ 2 - Z_SPAN!N)
      {
      for (size_t z = 0; z < 2 ^^ N; z++, b += CHUNK_SIZE - W_SPAN!N)
      {
      for (size_t w = 0; w < 2 ^^ N; w++, b++)
      {

      }
      }
      }
      }
    */

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
            state = ChunkDataState.OCCLUDED_UNLOADED;
            if (gl_data !is null) {
                free_chunk_gl_data(gl_data);
                gl_data = null;
            }
            // TODO return to a pool
            data = null;
        } else {
            update_gl_data(loc);
        }
    }

    private void update_gl_data(ChunkPos loc) {
        assert(data, format("%s %s", loc, state));
        writeln("updating ", loc);

        enum BlockState : ubyte {
            EMPTY,
                UNFILLED,
                FILLED,
                }

        static float[] vert_data;
        vert_data.unsafe_reset();

        void process_blockoid(int x, int y, int z, int w, int x_len, int y_len, int z_len, int w_len) {
            Vec4 blockoid_pos = Vec4(x, y, z, w) + loc.to_vec4();

            void process_cuboid(Vec4 pos, Vec4BasisSigned dir) {
                vert_data ~= pos.x;
                vert_data ~= pos.y;
                vert_data ~= pos.z;
                vert_data ~= pos.w;

                Vec4 rel_corner;
                final switch (dir)
                {
                case Vec4BasisSigned.NX:
                    vert_data ~= cast(float)(0);
                    vert_data ~= cast(float)(y_len);
                    vert_data ~= cast(float)(z_len);
                    vert_data ~= cast(float)(w_len);
                    break;

                case Vec4BasisSigned.NY:
                    vert_data ~= cast(float)(x_len);
                    vert_data ~= cast(float)(0);
                    vert_data ~= cast(float)(z_len);
                    vert_data ~= cast(float)(w_len);
                    break;

                case Vec4BasisSigned.NZ:
                    vert_data ~= cast(float)(x_len);
                    vert_data ~= cast(float)(y_len);
                    vert_data ~= cast(float)(0);
                    vert_data ~= cast(float)(w_len);
                    break;

                case Vec4BasisSigned.NW:
                    vert_data ~= cast(float)(x_len);
                    vert_data ~= cast(float)(y_len);
                    vert_data ~= cast(float)(z_len);
                    vert_data ~= cast(float)(0);
                    break;

                case Vec4BasisSigned.X:
                    vert_data ~= cast(float)(0);
                    vert_data ~= cast(float)(-y_len);
                    vert_data ~= cast(float)(-z_len);
                    vert_data ~= cast(float)(-w_len);
                    break;

                case Vec4BasisSigned.Y:
                    vert_data ~= cast(float)(-x_len);
                    vert_data ~= cast(float)(0);
                    vert_data ~= cast(float)(-z_len);
                    vert_data ~= cast(float)(-w_len);
                    break;

                case Vec4BasisSigned.Z:
                    vert_data ~= cast(float)(-x_len);
                    vert_data ~= cast(float)(-y_len);
                    vert_data ~= cast(float)(0);
                    vert_data ~= cast(float)(-w_len);
                    break;

                case Vec4BasisSigned.W:
                    vert_data ~= cast(float)(-x_len);
                    vert_data ~= cast(float)(-y_len);
                    vert_data ~= cast(float)(-z_len);
                    vert_data ~= cast(float)(0);
                    break;
                }

                writeln(vert_data[$-8..$]);
            }

            process_cuboid(blockoid_pos, Vec4BasisSigned.NX);
            process_cuboid(blockoid_pos, Vec4BasisSigned.NY);
            process_cuboid(blockoid_pos, Vec4BasisSigned.NZ);
            process_cuboid(blockoid_pos, Vec4BasisSigned.NW);

            blockoid_pos += Vec4(x_len, y_len, z_len, w_len);

            process_cuboid(blockoid_pos, Vec4BasisSigned.X);
            process_cuboid(blockoid_pos, Vec4BasisSigned.Y);
            process_cuboid(blockoid_pos, Vec4BasisSigned.Z);
            process_cuboid(blockoid_pos, Vec4BasisSigned.W);
        }

        ChunkGrid!BlockState state_grid = void;
        for (int i; i < BLOCKS_IN_CHUNK; i++)
        {
            if (data.data[i].is_transparent()) {
                state_grid.data[i] = BlockState.EMPTY;
            } else {
                state_grid.data[i] = BlockState.UNFILLED;
            }
        }

        int next_maybe_unfilled = 0;
        for (;;)
        {
            int first_unfilled = -1;
            for (int i = next_maybe_unfilled; i < BLOCKS_IN_CHUNK; i++)
            {
                if (state_grid.data[i] == BlockState.UNFILLED)
                {
                    if (first_unfilled == -1) {
                        first_unfilled = i;
                        break;
                    }
                }
            }

            if (first_unfilled == -1) {
                break;
            }

            int x = ChunkData.get_x(first_unfilled);
            int y = ChunkData.get_y(first_unfilled);
            int z = ChunkData.get_z(first_unfilled);
            int w = ChunkData.get_w(first_unfilled);

            //writefln("%d %d %d %d", x, y, z, w);

            int i = void;
            int w_len = 1;
            int w_boundary = first_unfilled + (CHUNK_SIZE - w);
            for (i = first_unfilled + 1; true; i++)
            {
                if (i >= w_boundary) {
                    break;
                }

                // refilling is fine
                if (data.data[i] == data.data[first_unfilled])
                {
                    state_grid.data[i] = BlockState.FILLED;
                    w_len += 1;
                } else {
                    break;
                }
            }
            w_boundary = i;

            // TODO is it faster to write before checking or after checking?
            int z_len = 1;
            int z_boundary = first_unfilled + (CHUNK_SIZE - z) * CHUNK_SIZE;
            for (i = first_unfilled + CHUNK_SIZE; true; i += CHUNK_SIZE)
            {
                if (i >= z_boundary) {
                    break;
                }

                int cur_w_boundary = w_boundary + i - first_unfilled;
                assert(cur_w_boundary <= BLOCKS_IN_CHUNK);
                bool all_match = true;
                for (int j = i; j < cur_w_boundary; j++) {
                    if (data.data[j] != data.data[first_unfilled]) {
                        all_match = false;
                        break;
                    }
                }

                if (!all_match) {
                    break;
                }

                for (int j = i; j < cur_w_boundary; j++) {
                    state_grid.data[j] = BlockState.FILLED;
                }
                z_len += 1;
            }
            z_boundary = i;

            int y_len = 1;
            int y_boundary = first_unfilled + (CHUNK_SIZE - y) * (CHUNK_SIZE ^^ 2);
            for (i = first_unfilled + CHUNK_SIZE ^^ 2; true; i += CHUNK_SIZE ^^ 2)
            {
                //writefln("%d %d %d %d", first_unfilled, i, y_boundary, first_unfilled + (CHUNK_SIZE - y) * (CHUNK_SIZE ^^ 2));
                if (i >= y_boundary) {
                    break;
                }

                int cur_z_boundary = z_boundary + i - first_unfilled;
                //writefln("%d %d", i, cur_z_boundary);
                assert(cur_z_boundary <= BLOCKS_IN_CHUNK);
                bool all_match = true;
            y_outer:
                for (int j = i; j < cur_z_boundary; j += CHUNK_SIZE)
                {
                    int cur_w_boundary = w_boundary + j - first_unfilled;
                    assert(cur_w_boundary <= BLOCKS_IN_CHUNK);
                    for (int k = j; k < cur_w_boundary; k++) {
                        if (data.data[k] != data.data[first_unfilled]) {
                            all_match = false;
                            break y_outer;
                        }
                    }
                }

                if (!all_match) {
                    break;
                }

                for (int j = i; j < cur_z_boundary; j += CHUNK_SIZE)
                {
                    int cur_w_boundary = w_boundary + j - first_unfilled;
                    for (int k = j; k < cur_w_boundary; k++) {
                        state_grid.data[k] = BlockState.FILLED;
                    }
                }
                y_len += 1;
            }
            y_boundary = i;

            int x_len = 1;
            int x_boundary = CHUNK_SIZE ^^ 4;
            for (i = first_unfilled + CHUNK_SIZE ^^ 3; true; i += CHUNK_SIZE ^^ 3)
            {
                if (i >= x_boundary) {
                    break;
                }

                int cur_y_boundary = y_boundary + i - first_unfilled;
                bool all_match = true;
            x_outer:
                for (int j = i; j < cur_y_boundary; j += CHUNK_SIZE ^^ 2)
                {
                    int cur_z_boundary = z_boundary + j - first_unfilled;
                    for (int k = j; k < cur_z_boundary; k += CHUNK_SIZE)
                    {
                        int cur_w_boundary = w_boundary + k - first_unfilled;
                        for (int l = k; l < cur_w_boundary; l++) {
                            if (data.data[l] != data.data[first_unfilled]) {
                                all_match = false;
                                break x_outer;
                            }
                        }
                    }
                }

                if (!all_match) {
                    break;
                }

                for (int j = i; j < cur_y_boundary; j += CHUNK_SIZE ^^ 2)
                {
                    int cur_z_boundary = z_boundary + j - first_unfilled;
                    for (int k = j; k < cur_z_boundary; k += CHUNK_SIZE)
                    {
                        int cur_w_boundary = w_boundary + k - first_unfilled;
                        for (int l = k; l < cur_w_boundary; l++) {
                            state_grid.data[l] = BlockState.FILLED;
                        }
                    }
                }
                x_len += 1;
            }
            x_boundary = i;

            //writefln("%d %d %d %d", x_boundary, y_boundary, z_boundary, w_boundary);

            //writefln("%d %d %d %d   %d %d %d %d", x, y, z, w, x_len, y_len, z_len, w_len);
            process_blockoid(x, y, z, w, x_len, y_len, z_len, w_len);
            next_maybe_unfilled = w_boundary;
            assert(data.data[next_maybe_unfilled - 1] == data.data[first_unfilled]);
        }

        assign_chunk_gl_data(&gl_data, vert_data.ptr, cast(int)(vert_data.length));
/+

        // TODO uhh not this
        // lol dmd doesn't inline this
        void process_block(Vec4 CORNER)(size_t x, size_t y, size_t z, size_t w) {
            Vec4 block_pos = Vec4(x, y, z, w) + loc.to_vec4();

            void process_cube(Vec4 pos, Vec4BasisSigned dir) {
                vert_data ~= pos.x;
                vert_data ~= pos.y;
                vert_data ~= pos.z;
                vert_data ~= pos.w;

                Vec4 rel_corner;
                final switch (dir)
                {
                case Vec4BasisSigned.NX:
                    enum V = ewise_p(Vec4(0, 1, 1, 1), CORNER);
                    rel_corner = V;
                    break;

                case Vec4BasisSigned.NY:
                    rel_corner = ewise_p(Vec4(1, 0, 1, 1), CORNER);
                    break;

                case Vec4BasisSigned.NZ:
                    rel_corner = ewise_p(Vec4(1, 1, 0, 1), CORNER);
                    break;

                case Vec4BasisSigned.NW:
                    rel_corner = ewise_p(Vec4(1, 1, 1, 0), CORNER);
                    break;

                case Vec4BasisSigned.X:
                    rel_corner = ewise_p(Vec4(0, -1, -1, -1), CORNER);
                    break;

                case Vec4BasisSigned.Y:
                    rel_corner = ewise_p(Vec4(-1, 0, -1, -1), CORNER);
                    break;

                case Vec4BasisSigned.Z:
                    rel_corner = ewise_p(Vec4(-1, -1, 0, -1), CORNER);
                    break;

                case Vec4BasisSigned.W:
                    rel_corner = ewise_p(Vec4(-1, -1, -1, 0), CORNER);
                    break;
                }

                vert_data ~= rel_corner.x;
                vert_data ~= rel_corner.y;
                vert_data ~= rel_corner.z;
                vert_data ~= rel_corner.w;
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

            block_pos += CORNER;

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


        bool none_empty = true;

    outer:
        for (size_t x = 0; x < CHUNK_SIZE; x++)
        {
            for (size_t y = 0; y < CHUNK_SIZE; y++)
            {
                for (size_t z = 0; z < CHUNK_SIZE; z++)
                {
                    for (size_t w = 0; w < CHUNK_SIZE; w++)
                    {
                        if (data.grid[x][y][z][w] == BlockType.NONE)
                        {
                            none_empty = false;
                            break outer;
                        }
                    }
                }
            }
        }

        // lol
        if (none_empty) {
            process_block!(Vec4(CHUNK_SIZE, CHUNK_SIZE, CHUNK_SIZE, CHUNK_SIZE))(0, 0, 0, 0);
        } else {
            for (size_t x = 0; x < CHUNK_SIZE; x++)
            {
                for (size_t y = 0; y < CHUNK_SIZE; y++)
                {
                    for (size_t z = 0; z < CHUNK_SIZE; z++)
                    {
                        for (size_t w = 0; w < CHUNK_SIZE; w++, b++)
                        {
                            if (*b != BlockType.NONE)
                            {
                                process_block!(Vec4(1, 1, 1, 1))(x, y, z, w);
                            }
                        }
                    }
                }
            }
        }

        //assert(vert_data.length > 0);
        writeln(vert_data.ptr);
        writefln("%s\twriting %s", loc, vert_data.length);
        assign_chunk_gl_data(&gl_data, vert_data.ptr, cast(int)(vert_data.length));
        +/
    }
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
                    //if ((b - c.data.begin()) % 1755 == 0)
                    //if ((b - c.data.begin()) % 255 == 0)
                    //if ((b - c.data.begin()) % 49 == 0)
                    //if ((b - c.data.begin()) % 37 == 8)
                    //if (w == x && w == y && w == z && w == 0)
                    //if (x == 0 && y == 0 && z == 0 && w == 0)
                    //if (x < 5 && x % 2 == 0 && w == y && w == z && w == 0)
                    //if ((x != 0) + (y != 0) + (z != 0) + (w != 0) <= 1)
                    //if (y >= CHUNK_SIZE - 4)
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
        //loc.y == -1
        //loc == ChunkPos(0, 0, 0, 0)
        //loc == ChunkPos(1, 0, 1, 0)
        )
    {
        if (false){
            if (!fixed_chunk)
            {
                fixed_chunk = new Chunk();
                *fixed_chunk = gen_fixed_chunk();
            }

            c = *fixed_chunk;
        } else {
            c = gen_fixed_chunk();
        }
    } else {
        c.state = ChunkDataState.EMPTY;
    }

    //c.update_gl_data(loc);

    c.update_from_internal();

    return c;
}

