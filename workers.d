import core.atomic : /*atomicFetchAdd, atomicFetchSub,*/ atomicLoad, atomicStore, cas;
import core.stdc.stdlib : abort;
import core.thread : Thread;
import std.datetime.stopwatch : StopWatch;
import std.datetime : dur, to, TickDuration;
import std.process : thisThreadID;

public import std.parallelism : totalCPUs;

import util;

shared bool do_close = false;


// TODO use casWeak?
shared struct LockFreeStack(T) {
    struct S {
        T t;
        int next = -1;
    }

    private S[] storage;
    private int first = int.min;
    private int length_ = 0;

    this(int n) {
        storage = new S[n];
    }

    bool push(T t) {
        // TODO randomize? start from first + 1?
        int i;
        for (i = 0; i < storage.length; i++) {
            bool cas_succeed = cas(&storage[i].next, -1, 0);
            if (cas_succeed) {
                break;
            }
        }
        if (i == storage.length) {
            return false;
        }

        atomicFetchAdd(length_, 1);
        storage[i].t = t;

        bool cas_succeed;
        do {
            int old_first = atomicLoad(first);
            storage[i].next = old_first;
            cas_succeed = cas(&first, old_first, i);
        } while (!cas_succeed);

        return true;
    }

    bool pop(ref T t) {
        int old_first;
        bool cas_succeed;
        do {
            old_first = atomicLoad(first);
            if (old_first == int.min) {
                return false;
            }
            int next = atomicLoad(storage[old_first].next);
            cas_succeed = cas(&first, old_first, next);
        } while (!cas_succeed);

        atomicFetchSub(length_, 1);
        t = storage[old_first].t;

        atomicStore(storage[old_first].next, -1);

        return true;
    }

    int length() const pure {
        return atomicLoad(length_);
    }

    bool empty() const pure {
        return atomicLoad(first) == int.min;
    }
}



unittest {
    enum N = 4;
    LockFreeStack!int s = LockFreeStack!int(N);

    for (int iter = 0; iter < 2; iter++) {
        assert(s.storage.length == N);
        assert(s.first == int.min);
        assert(s.empty());
        int r = -1;
        for (int i = 0; i < N; i++) {
            //writefln("%s %s %s", s.length(), i, s.first);
            assert(s.length() == i);
            assert(s.push(i));
            assert(s.first == i);
            assert(!s.empty());
        }
        assert(!s.push(-1));
        for (int i = N - 1; i >= 0; i--) {
            assert(!s.empty());
            assert(s.pop(r));
            assert(r == i);
            assert(s.length() == i);
        }

        assert(!s.pop(r));
        assert(s.empty());
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
                        dwritef!"watchdog"("peek %s at %s", i, t);
                        if (t > dur!"msecs"(2000)) {
                            dwritef("watchdog bit %s, aborting", i);
                            //abort();
                        }
                    }
                    Thread.sleep(dur!"msecs"(400));

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
            for (int iter = 0;; iter++) {
                //dwritef!"worker"("iter %s", iter);
                watchdogs.pet(i);
                f();
                if (atomicLoad(do_close)) {
                    return;
                }
                //Thread.sleep(dur!"msecs"(10));
                Thread.yield();
            }
            assert(0);
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
