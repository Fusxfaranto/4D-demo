
public import std.stdio : write, writeln, writef, writefln;

import std.traits : OriginalType;
import std.datetime.stopwatch : StopWatch;
import std.datetime : to, TickDuration;
import std.conv : to;


void handle_errors(alias F, Args...)(Args a) if (is(typeof(F(a)) : int))
{
    int res = F(a);
    if (res != 0)
    {
        throw new Error("error code " ~ res.to!string);
    }
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
