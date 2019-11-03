import core.atomic : atomicLoad, atomicStore, cas;

import chunk;
import util;


// bool atomic_inc_mod(T)(shared(T)* loc, const shared(T)* end, T modulus) {
//     bool cas_succeed;
//     T old;
//     do {
//         old = atomicLoad(*loc);
//         T n = (old + 1) % modulus;
//         if (n == atomicLoad(*end)) {
//             return false;
//         }

//         cas_succeed = cas(&stop, old_stop, new_stop);
//     } while (!cas_succeed);
// }

// TODO i think something linked list-based would avoid most of the jank here

version(none) {
    shared struct LockFreeQueue(T) {
        private T[] storage;
        private bool[] busy;
        private size_t start = 0;
        private size_t stop = 0;

        bool push(T e) {
            bool cas_succeed;
            size_t old_stop;
            for (;;) {
                old_stop = atomicLoad(stop);
                if (!cas(&busy[old_stop], false, true)) {
                    return false;
                }
                size_t new_stop = (old_stop + 1) % storage.length;
                if (new_stop == atomicLoad(start)) {
                    return false;
                }

                cas_succeed = cas(&stop, old_stop, new_stop);

                if (cas_succeed) {
                    break;
                }

                cas_succeed = cas(&busy[old_stop], true, false);
                assert(cas_succeed);
            }

            storage[old_stop] = e;

            cas_succeed = cas(&busy[old_stop], true, false);
            assert(cas_succeed);

            return true;
        }

        bool pop(ref T e) {
            bool cas_succeed;
            size_t old_start;
            for (;;) {
                old_start = atomicLoad(start);
                if (!cas(&busy[old_start], false, true)) {
                    return false;
                }
                if (old_start == atomicLoad(stop)) {
                    return false;
                }
                size_t new_start = (old_start + 1) % storage.length;

                cas_succeed = cas(&start, old_start, new_start);
                if (cas_succeed) {
                    break;
                }

                cas_succeed = cas(&busy[old_start], true, false);
                assert(cas_succeed);
            }

            e = storage[old_start];

            cas_succeed = cas(&busy[old_start], true, false);
            assert(cas_succeed);

            return true;
        }
    }
} else {
    shared struct LockFreeStack(T) {
        struct S {
            T t;
            int next = -1;
        }

        private S[] storage;
        private int first = -1;

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
                if (old_first == -1) {
                    return false;
                }
                int next = atomicLoad(storage[old_first].next);
                cas_succeed = cas(&first, old_first, next);
            } while (!cas_succeed);

            t = storage[old_first].t;
            atomicStore(storage[old_first].next, -1);

            return true;
        }
    }

}

//alias ChunkPosQueue = LockFreeQueue!ChunkPos;
alias ChunkPosStack = LockFreeStack!ChunkPos;
ChunkPosStack cps_to_load = ChunkPosStack(4096);
