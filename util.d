
public import std.conv : to;
public import std.stdio : write, writeln, writef, writefln;
public import std.typecons : Tuple, tuple;

import core.atomic : atomicLoad, atomicStore, cas;
import core.sync.mutex : Mutex;
import std.datetime.stopwatch : StopWatch;
import std.datetime : to, TickDuration;
import std.process : thisThreadID;
import std.traits : OriginalType, isIntegral;


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

private shared int[ulong] readable_tid_map;
private shared Mutex readable_tid_m;
private static int readable_tid_tl = -1;
int readable_tid(ulong tid) {
    readable_tid_m.lock_nothrow();

    int r;
    if (auto p = tid in readable_tid_map) {
        r = *p;
    } else {
        r = cast(int)(readable_tid_map.length);
        readable_tid_map[tid] = r;
    }

    readable_tid_m.unlock_nothrow();

    return r;
}
int readable_tid() {
    if (readable_tid_tl == -1) {
        readable_tid_tl = readable_tid(thisThreadID());
    }
    return readable_tid_tl;
}

private shared Mutex dwrite_m;
void dwritef(string t = "always", A...)(auto ref string fmt, auto ref A args) {
    static if (
        //t != "lock" &&
        t != "cross" &&
        t != "chunk" &&
        true) {
        dwrite_m.lock_nothrow();
        writef("tid %s\t", readable_tid());
        writefln(fmt, args);
        dwrite_m.unlock_nothrow();
    }
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

enum MAX_NUM_THREADS = 6;
shared (SpinLock*)[MAX_NUM_THREADS] sl_tracker;

alias SpinLock = SpinLockBase!true;
alias SpinLockUntracked = SpinLockBase!false;
shared struct SpinLockBase(bool trackable) {
    alias ThisSpinLock = typeof(this);

    private struct Locker {
        ThisSpinLock* l;
        ~this() {
            if (l) {
                //dwritef!"lock"("unlock: %s", &l.is_locked);
                l.assert_locked();
                atomicStore(l.locking_thread_id, 0);
                static if (trackable) {
                    assert(atomicLoad(sl_tracker[readable_tid()]) == l);
                    atomicStore(sl_tracker[readable_tid()], null);
                }
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
    private ulong locking_thread_id;

    Locker opCall() {
        ulong tid = thisThreadID();
        {
            //writeln(&is_locked);
            bool nl = !atomicLoad(is_locked);
            bool diff_tid = atomicLoad(locking_thread_id) != tid;
            assert(nl || diff_tid);
        }
        bool spinning = false;

        while (!cas(&is_locked, false, true)) {
            if (!spinning) {
                //dwritef!"lock"("waiting on lock: %s", &is_locked);
            }
            spinning = true;
        }
        atomicStore(locking_thread_id, tid);
        static if (trackable) {
            assert(atomicLoad(sl_tracker[readable_tid()]) is null);
            atomicStore(sl_tracker[readable_tid()], &this);
        }
        //dwritef!"lock"("lock succeess: %s", &is_locked);
        return Locker(&this);
    }

    void assert_locked() const {
        assert(atomicLoad(is_locked), format("%s %s", readable_tid(), &is_locked));
    }

    void assert_unlocked() const {
        assert(!atomicLoad(is_locked), format("%s %s", readable_tid(), &is_locked));
    }

    struct LockedP(T, string field = "lock") {
        T* p;
        alias p this;

        Locker locker;

        this(T* p_) {
            p = p_;
            assert(p is null);
            locker = Locker(null);
        }

        this(T* p_, ref Locker l) {
            p = p_;
            assert(p !is null);
            assert(l.l !is null);
            locker = l.move();
        }

        @disable this(this);
    }
}

shared struct Locked(T) {
    SpinLock lock;
    T t;

    T get() {
        auto l = lock();
        return t;
    }

    void set(T t_) {
        auto l = lock();
        t = t_;
    }
}


// TODO workaround until i get a
// phobos version with atomicFetchAdd/Sub
T atomicFetchAdd(T)(shared ref T n, T a) {
    bool cas_succeed;
    T old_n;
    do {
        old_n = atomicLoad(n);
        T new_n = old_n + a;
        cas_succeed = cas(&n, old_n, new_n);
    } while (!cas_succeed);
    return old_n;
}
T atomicFetchSub(T)(shared ref T n, T a) {
    return atomicFetchAdd(n, -a);
}

shared static this() {
    dwrite_m = new shared Mutex();
    readable_tid_m = new shared Mutex();
}
