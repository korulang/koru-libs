# The final ladder — nine operations, seven builds, twin-certified

Twenty-five iterations, one window, one quieted machine, under the reference's
own driver. Read it with:

    node ../ladder.mjs --results . --twin vanillajstwin

**Koru finishes all nine operations here.** The previous run did not: the app's
label column was `char[40]` and four cumulative " !!!" marks overflowed it, so
the reference aborted partial update on roughly a quarter of runs and rendered
wrong text on ~12 rows per 1000 on the ones it survived. Fixed at
koru-libs@5fd6b2f (`char[48]`), verified in both directions with
`dom/closer/truncation-check.mjs`.

The window is certified by a twin rather than by assertion: `vanillajstwin` is
the reference's own vanilla implementation byte-for-byte at a second URL,
measured in the same run. The two agree to 0.0-1.1% on eight of nine operations
and 5.6% on selecting a row — which is a 3.6 ms operation, and that number is
the honest floor for how finely anything here can be read.

Geometric means over all nine: vanilla 1.000, twin 0.995, Koru 1.051,
Solid 1.101, Svelte 1.152, Vue 1.253, React 1.812.

Koru, Solid and Svelte are separated by less than the spread a single machine
produces across a night. Treat the ordering among those three as a property of
this run; the distance to Vue and React is large enough to mean something.
