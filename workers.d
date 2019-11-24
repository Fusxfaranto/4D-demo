import core.atomic : /*atomicFetchAdd, atomicFetchSub,*/ atomicLoad, atomicStore, cas;
import core.stdc.stdlib : abort;
import core.thread : Thread;
import std.datetime.stopwatch : StopWatch;
import std.datetime : dur, to, TickDuration;
import std.process : thisThreadID;

public import std.parallelism : totalCPUs;

import util;

shared bool do_close = false;


shared struct Queue(T) {
    private T[] storage;
    private int begin = 0;
    private int end = 0;

    private SpinLockUntracked sl;

    this(int n) {
        storage = new T[n];
    }

    private int incm(int i) {
        return cast(int)((i + 1) % storage.length);
    }

    bool push(T t) {
        auto l = sl();

        if (begin == incm(end)) {
            return false;
        }

        storage[end] = t;
        end = incm(end);

        return true;
    }

    bool pop(ref T t) {
        auto l = sl();

        if (begin == end) {
            return false;
        }

        t = storage[begin];
        begin = incm(begin);

        return true;
    }

    int length() {
        auto l = sl();
        int len = end - begin;
        if (len < 0) {
            len += storage.length;
        }
        return len;
    }

    bool empty() {
        auto l = sl();
        return begin == end;
    }
}



unittest {
    enum N = 4;
    Queue!int q = Queue!int(N + 1);

    for (int iter = 0; iter < 2; iter++) {
        assert(q.storage.length == N + 1);
        assert(q.empty());
        int r = -1;
        for (int i = 0; i < N; i++) {
            //writefln("%s %s", q.length(), i);
            assert(q.length() == i);
            assert(q.push(i));
            assert(!q.empty());
        }
        assert(!q.push(-1));
        for (int i = 0; i < N; i++) {
            assert(!q.empty());
            assert(q.pop(r));
            assert(r == i);
            assert(q.length() == N - 1 - i);
        }

        assert(!q.pop(r));
        assert(q.length() == 0);
        assert(q.empty());
    }
}


// TODO make "Watchdog", and just have the thread be globally shared
struct Watchdogs {
    Thread thread;
    StopWatch[] sws;
    shared(SpinLock)[] sls;

    this(size_t n) {
        sws.reserve(n);
        sls.reserve(n);
        for (size_t i = 0; i < n; i++) {
            sws ~= StopWatch();
            sws[i].start();
            sls ~= SpinLock.init;
        }

        thread = new Thread(delegate void() {
                for (;;) {
                    for (size_t i = 0; i < n; i++) {
                        auto l = sls[i]();
                        auto t = sws[i].peek();
                        //dwritef!"watchdog"("peek %s at %s", i, t);
                        if (t > dur!"msecs"(1000)) {
                            dwritef("watchdog bit %s, aborting", i);
                            abort();
                        }
                    }
                    Thread.sleep(dur!"msecs"(200));

                    if (atomicLoad(do_close)) {
                        return;
                    }
                }
            });
        thread.start();
    }

    void pet(size_t i) {
        auto l = sls[i]();
        sws[i].reset();
    }
}

struct WorkerGroup {
    Thread[] threads;
    Watchdogs watchdogs;

    private auto make_delegate(size_t i, void delegate() f) {
        return delegate void() {
            int iter = 0;
            try {
                for (;;) {
                    //if (iter < 10) dwritef!"worker"("iter %s", iter);
                    watchdogs.pet(i);
                    f();
                    if (atomicLoad(do_close)) {
                        dwritef!"worker"("closing");
                        return;
                    }
                    //Thread.sleep(dur!"msecs"(10));
                    Thread.yield();

                    iter++;
                }
            } catch (Throwable e) {
                dwritef!"worker"("exception in %s, iter %s:\n%s", i, iter, e);
                abort();
            }
        };
    }

    this(size_t n, void delegate() f) {
        watchdogs = Watchdogs(n);

        threads.reserve(n);
        for (size_t i = 0; i < n; i++) {
            threads ~= new Thread(make_delegate(i, f));
            //threads[i].isDaemon = true;
            threads[i].start();
            threads[i].priority = Thread.PRIORITY_MIN;
        }
    }

    void join() {
        foreach (ref t; threads) {
            t.join();
        }
    }
}
