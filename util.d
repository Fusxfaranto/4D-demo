
public import std.conv : to;
public import std.stdio : write, writeln, writef, writefln;
public import std.typecons : Tuple, tuple;

import core.atomic : atomicStore, cas;
//import std.algorithm : move;
import std.traits : OriginalType, isIntegral;
import std.datetime.stopwatch : StopWatch;
import std.datetime : to, TickDuration;


enum float LARGE_FLOAT = 1e20;


void handle_errors(alias F, Args...)(Args a) if (is(typeof(F(a)) : int))
{
    int res = F(a);
    if (res != 0)
    {
        throw new Error("error code " ~ res.to!string);
    }
}


// http://www.microhowto.info/howto/round_towards_minus_infinity_when_dividing_integers_in_c_or_c++.html
T div_floor(T)(T x, T y) if (isIntegral!T) {
    int q = x / y;
    int r = x % y;
    if ((r != 0) && ((r < 0) != (y < 0))) q--;
    return q;
}



T inc_enum(T)(T x) if (is(T == enum) && is(typeof(cast(OriginalType!T)x + 1) : int))
{
    auto v = cast(OriginalType!T)x + 1;
    if (v > T.max)
    {
        v = T.min;
    }
    return v.to!T;
}



string format(A...)(string fmt, A args)
{
    import std.array : appender;
    import std.format : formattedWrite;

    auto writer = appender!string();
    writer.formattedWrite(fmt, args);

    return writer.data;
}



debug(prof) StopWatch sw;
void profile_checkpoint(string file = __FILE__, size_t line = __LINE__)()
{
    debug(prof)
    {
        writeln(file, ':', line, '\t', to!("usecs", long)(to!TickDuration(sw.peek())));
        sw.reset();
    }
}


void swap(T)(ref T a, ref T b)
{
    T t = a;
    a = b;
    b = t;
}


void unsafe_reset(T)(ref T[] a) {
    auto c = a.capacity;
    a.length = 0;
    a.assumeSafeAppend();
    assert(a.capacity == c, c.to!string() ~ " " ~ a.capacity.to!string());
}

void unsafe_popback(T)(ref T[] a) {
    auto c = a.capacity;
    a.length = a.length - 1;
    a.assumeSafeAppend();
    assert(a.capacity == c, c.to!string() ~ " " ~ a.capacity.to!string());
}

void unsafe_assign(alias init, T)(ref T[] a) {
    a.unsafe_reset();
    static foreach (i, e; init) {
        a[i] = init[i];
    }
}


T reinterpret(T, U)(auto ref U u) if (T.sizeof) {
    return *cast(T*)(&u);
}



shared struct SpinLock {
    private struct Locker {
        SpinLock* l;
        ~this() {
            //writefln("unlock: %s", &l.is_locked);
            if (l) {
                l.assert_locked();
                atomicStore(l.is_locked, false);
            }
        }

        Locker move() {
            Locker n = Locker(l);
            l = null;
            return n;
        }

        @disable this(this);
    }

    private bool is_locked;

    Locker opCall() {
        //writefln("lock: %s", &is_locked);
        assert_unlocked(); // TODO only true with one thread
        bool v = false;
        do {} while (cas(&is_locked, &v, true));
        assert(v);
        return Locker(&this);
    }

    // TODO i'd prefer to not have this
    void claim() {
        //writefln("claim: %s", &is_locked);
        assert_unlocked();
        atomicStore(is_locked, true);
    }

    void assert_locked() const {
        assert(is_locked);
    }

    void assert_unlocked() const {
        assert(!is_locked);
    }

    struct LockedP(T, string field = "lock") {
        T* p;
        alias p this;

        Locker locker;

        this(T* p_) {
            assert(p is null);
        }

        this(T* p_, ref Locker l) {
            p = p_;
            assert(p);
            locker = l.move();
        }

        @disable this(this);
    }
}
