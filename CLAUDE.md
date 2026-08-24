# Contributor notes

Documentation for people — and coding assistants — working *on* this repository.
For using the program, see `README.md`.

## One-time setup in a fresh clone

```sh
git config core.hooksPath .githooks
```

`core.hooksPath` lives in `.git/config`, which is not tracked, so this cannot be
committed and every clone needs it once. It enables `.githooks/commit-msg`,
which normalizes AI-assistance attribution to `Assisted-by: <name>` — hyphenated
so git parses it as a real trailer, and with no email address. The hook rewrites
rather than rejects, so forgetting it costs nothing worse than a trailer in the
older `Co-Authored-By:` form.

## Line endings

`.gitattributes` pins everything to LF, in the repository *and* in the working
tree on every platform. Do not add a `text=auto`-only or `eol=crlf` rule.

This is not housekeeping. The regression gate byte-compares generated program
output against reference outputs committed under `sample-output/`, on Linux,
macOS and Windows. Before `.gitattributes` existed, a Windows clone checked
`mobcal_He.f` out at 90,793 bytes against an 88,015-byte blob.

Pinning the checkout is only half of it, because **the program itself writes
CRLF on Windows and LF elsewhere** — gfortran's Windows runtime opens the output
unit in text mode. No checkout setting can normalize a difference introduced
after checkout, so `test/regression.sh` strips end-of-line CR itself and does not
rely on git having done it.

## The three gates

```sh
sh test/regression.sh              # both gases -- minutes for he, ~1 h for n2
sh test/bounds.sh                  # both gases -- seconds
sh test/elements.sh                # both gases -- seconds
```

`test/regression.sh` is the physics gate: one valid input, compared against
committed reference outputs. `test/bounds.sh` is the safety gate: three inputs
whose expected result is a refusal, so there is nothing to compare against and
nothing that runs long. `test/elements.sh` is the parameter gate: it links a
probe against the real `fcoord` and `ncoord` and reads out what the element
table actually set, which is the one thing no amount of comparing output files
can show.

They are separate scripts because those are three different shapes, and they
share one build recipe — `test/build-flags.sh`, described under *Building*
below. CI runs the two fast ones first, since a broken build or a broken guard
should not cost an hour of n2 to discover.

## The regression gate

```sh
sh test/regression.sh              # both gases
sh test/regression.sh --gas he     # one gas
sh test/regression.sh --keep       # keep test/_work to inspect the diffs
```

It builds both sources, runs `Choline.mfj` at the seed recorded in the reference
outputs, and reports three tiers. `.github/workflows/ci.yml` runs this script,
`test/bounds.sh` and `test/elements.sh` on ubuntu, macos and windows, one job
per (platform, gas) pair.

| Tier | What it compares | Gating |
|---|---|---|
| **T1** deterministic | Every line not listed in `test/stochastic-lines.txt`, character for character | always |
| **T2** cross sections | The reported cross sections, within a relative tolerance | always |
| **T3** whole file | Byte identity including every stochastic line | on the platforms in `test/strict-platforms` |

Three things about this that are easy to get wrong:

**`test/stochastic-lines.txt` is an exclusion list, and that direction matters.**
A line not listed there must match exactly. So when a change adds a new output
line, the gate fails and somebody looks at it, instead of the new line landing
quietly in an ignored bucket. If a new line genuinely is stochastic, add it in
the same commit that introduces it and say so in the commit message.

**T3 is not decoration — it is the only tier that can see a wrong
Lennard-Jones parameter.** The per-element table sets four things per atom:
mass, ε, σ, and hard-sphere radius. Only the mass reaches a T1 line. The
`Lennard-Jones scaling parameters` printed in the header are hardcoded
constants (`eo=1.34d-03*xe`), not derived from the table. So a wrong ε or σ is
invisible to T1 and would have to be gross to trip T2. Any change to the
element table must be measured against T3.

**And T3 still is not enough on its own**, which is why `test/elements.sh`
exists. `Choline.mfj` declares one coordinate set and 21 atoms drawn from four
element rows, so this gate exercises `fcoord` and never `ncoord`, and four of
the nine (He) or ten (N2) rows. It cannot see a row it never reads or a copy of
the table it never calls.

**Weakening T3 is a commit, not a default.** Every platform starts listed in
`test/strict-platforms`. If one turns out not to be byte-reproducible — a
different compiler summing 400,000 trajectory contributions in a different order
will move the last printed digit — removing it means editing that file with a
written reason. A gate that gets quietly weakened is worse than no gate, because
everything measured afterwards inherits its reassurance.

## The array-bound gate

```sh
sh test/bounds.sh                  # both gases
sh test/bounds.sh --gas he         # one gas
sh test/bounds.sh --keep           # keep test/_bounds to read the outputs
```

Three cases per gas, all generated rather than committed — the two over-bound
fixtures are ~120 KB of repetitive filler between them, and the generator is the
more useful artifact.

| Case | Asserts |
|---|---|
| **over-atoms** `inatom` = `len`+1 | nonzero exit; the message names both numbers, in the output file *and* on the console; no cross section anywhere |
| **over-coords** `icoord` = `lcoord`+1 | the same, plus that it refused before even reading the atom count |
| **boundary** exactly `lcoord` and `len` | both counts accepted; no `ERROR`; execution reaches the pre-existing charge-distribution refusal |

Three things about this that are easy to get wrong:

**The boundary case is the only one that can see an off-by-one.** Neither
over-bound input can distinguish `.gt.` from `.ge.`, and an off-by-one is the
likeliest defect in a bound check. Verified by mutation: changing
`if(inatom.gt.len)` to `.ge.` fails three of the boundary case's five assertions
and nothing else in the suite. Verified in the other direction too — a message
naming the count but not the limit fails two over-atoms assertions.

**The boundary case cannot be a real run, and does not pretend to be.** A valid
1,000-atom input is a trajectory calculation some fifty times the cost of
choline's hour, and `itn`/`inp`/`imp` are hardcoded in the source, so there is no
cheap configuration of it. So the boundary input declares both counts at the
limit and then names a charge mode that does not exist. Passing both guards and
landing on `charge distribution not specified` is the evidence that neither guard
fired one early. It tests the guards and explicitly nothing past them.

**The boundary case asserts exit status 0, and that is not a typo.** A bare
Fortran `stop` exits 0, and every refusal this code shipped with is a bare stop —
eight in `mobcal_He.f`, including `units not specified`, `charge distribution not
specified` and `type not defined for atom number`. All eight report success to
their caller. The two bound refusals added in v1.1 use `call exit(1)` instead,
because a refusal a script cannot detect is not much of a refusal. The eight
older ones were deliberately left alone, so the repository currently has refusals
of both kinds; making them consistent is a change worth making on its own terms,
not as a side effect of this one.

## The element-table gate

```sh
sh test/elements.sh                # both gases -- seconds
sh test/elements.sh --gas n2       # one gas
sh test/elements.sh --keep         # keep test/_elements to read the probe
```

Before v1.1 each source file wrote the per-element table out **twice** — once in
`fcoord`, which serves coordinate set 1, and once in `ncoord`, which serves sets
2…`icoord`. Chunk 3 replaced both with one `ljparm` subroutine per file. This
gate is what keeps it that way, and it is also the reason chunk 3 chose a
subroutine over an include.

Four things about this that are easy to get wrong:

**The parameters are not observable in the program's output at all, for any
coordinate set after the first.** The per-atom LJ print is gated on `iu1`, which
is hardcoded `iu1=0` in the main program — and the print block exists *only in
`fcoord`*. `ncoord` has no such block. So there is no print switch, however set,
that can show conformer 2's ε and σ. Comparing output files was never going to
reach this; something has to call the code and read the arrays.

**Hence the probe.** `test/elements.sh` takes everything in the source from the
first `subroutine` statement onward — which drops exactly the main program,
`fcoord` being the second program unit in both files — and compiles it against a
generated driver that sets the handful of COMMON constants `fcoord` and `ncoord`
read, calls them, and writes out `eolj`, `rolj` and `rhs`. It exercises the real
subroutines from the real source file, and there is no second copy of the table
anywhere in the test. It runs in milliseconds because nothing integrates a
trajectory, which is what lets it run on all three CI platforms.

**The fixture's two coordinate sets are identical on purpose.** That holds the
geometry fixed, so the only thing that can differ between the sets is which
table was consulted. Every atom must come out of set 2 with exactly the values
it came out of set 1 with — as text, since the same table evaluated twice cannot
round differently.

**Identity alone would not be enough**, so the gate also pins silicon's actual
values. A merge that adopted the *wrong* silicon row in both places would
satisfy identity perfectly. The tolerance is 1e-4 relative, which is loose on
purpose: it only has to separate two candidate rows that differ by a factor of
5.6 in ε and 21 % in σ, and the N2 table multiplies a double by
single-precision literals such as `0.4020`, so the last few digits belong to the
literal's rounding rather than to the parameter.

## The one element table

`ljparm` — one per source file, called by `fcoord` and by `ncoord`. Adding,
removing or editing an element row means editing exactly one place per gas.

**It is one subroutine per file, not one shared between the two files, and that
is not an oversight.** The two tables hold different quantities. `mobcal_He.f`
holds He–X *pair* parameters directly (`eolj(iatom)=1.3266d-3*xe`).
`mobcal_N2.f` holds X–X *self* parameters that pass through a combining rule
with the gas (`dsqrt(eogas*0.0977)*conve*xe`). Merging them would require
inventing a conversion that does not exist in either source.

Four things to know before editing it:

**The single-precision literals are load-bearing.** `dsqrt(eogas*0.4020)`
multiplies a double by a REAL(4) literal, so `0.4020` is rounded to single
precision before the multiply. Writing it `0.4020d0` is a different number in
the eighth digit and moves published output. Rows are copied verbatim.

**`eogas`, `rogas`, `conve` and `convr` belong to the subroutine now.** In
`mobcal_N2.f` they were four plain locals assigned *inside* the per-atom loop,
once per atom, in both copies of the table — eight lines of duplication on top
of the table's own. They are in no COMMON block, so the shared subroutine had to
either own them or receive them; it owns them, hoisted out of the loop, stated
once.

**The `type not defined for atom number` refusal moved with the rows.** It is
the `itest.eq.0` arm and it is inseparable from the `itest` mechanism, so there
is now one copy of it per file rather than two. It is otherwise untouched —
format 602 still uses `i3` and still truncates above 999 atoms, and it is still
one of the eight bare `stop`s that exit 0.

**Silicon in N2 was a real bug and the merge fixed it.** `ncoord`'s silicon row
held **iron's ε and σ verbatim** — 0.0130 / 2.9120 against `fcoord`'s 0.4020 /
4.2950 — under a comment still reading "silicon (from fitting mobilities of
small silicon clusters)". Every element other than silicon was identical between
the two tables. So any multi-conformer N2 run containing silicon used iron's
parameters for every conformer after the first, and nothing in the output said
so. Measured on the pre-merge code: conformer 2's silicon came out at 0.180× the
well depth and 0.823× the radius of conformer 1's.

`fcoord`'s 0.4020 / 4.2950 is the one the merge adopted. Silicon's neighbours
corroborate it — sulfur, commented "same as silicon", is 0.2740 / 4.0350 and
phosphorus is 0.305 / 4.1470, the same family, nothing like 0.0130 / 2.9120 —
that block already carries copy-paste damage, with phosphorus and fluorine both
sitting under the comment "iron (same as silicon)", and decisively, `fcoord`'s
is the value every *single*-conformer N2 silicon run ever published used.
Adopting `ncoord`'s would have silently changed results that were right in order
to preserve ones that were wrong.

**The four commented-out alternate parameter pairs were kept.** `fcoord` in
`mobcal_N2.f` carried eight commented-out lines — an alternate `eolj`/`rolj`
pair for carbon, nitrogen, oxygen and sulfur, e.g.

```
c      eolj(iatom)=0.139373598*xe
c      rolj(iatom)=3.85949064*0.890898718*1.0d-10
```

— that `ncoord` did not. They are dead code, but they are the only surviving
record of a different, non-combining parameterization, and a merge is the wrong
moment to lose provenance. They live in `ljparm` now, still commented out.

## The two array bounds

`mobcal_limits.inc` holds both, and holds them once:

```
parameter (len=1000)      ! atoms per conformer
parameter (lcoord=100)    ! coordinate sets per input file
```

Before v1.1, `parameter (len=1000)` was written out fifteen times per source
file. Two of those thirty lines carried a trailing space, so an exact-match
replace-all silently skipped them — which is the fifteen-edit-points problem
demonstrating itself.

Four things to know before editing it:

**`len` shadows the intrinsic `LEN`.** Pre-existing, accepted under
`-std=legacy`, and not worth renaming: the name appears in every dimension
expression in both files.

**Both names must begin with `i`, `j`, `k` or `l`.** Every unit that includes the
file declares `implicit double precision (a-h,m-z)`, so a name beginning `m`–`z`
would be typed REAL and become a non-integer array bound. This is why the
conformer limit is `lcoord` and not `maxcrd`.

**In the main program the include must precede the `dimension` statement.**
`tmc`/`tmm`/`ehsc`/`ehsm`/`pac`/`pam`/`asympp` are dimensioned `lcoord`, so the
declaration block is reordered there rather than substituted in place. Everywhere
else the `parameter` line already came before its uses.

**The include does not change the build command.** `gfortran` resolves an
`include` relative to the directory of the *source* file, not the working
directory. Verified rather than assumed, on Windows: building from the repository
root and building the same source by absolute path from an unrelated working
directory produce byte-identical binaries. `README.md`'s "one command per gas"
still holds; what changed is that it now lists a required source file.

## Two normalizations the comparison applies

Both are narrow and both are needed to compare a gfortran build against the
references published in 2012, which were produced with g77.

1. **End-of-line CR**, for the reason above. Stripped only at end of line, never
   mid-line: the filename fields are blank-padded to 30 columns by an `a30` edit
   descriptor, and those trailing blanks are real content.

2. **Fortran `D` exponent → `E`.** Format 604, the `mass of ion` line, is the
   only edit descriptor in either source that uses `1pd` rather than `1pe`:

   ```sh
   grep -n 'pd[0-9]' mobcal_He.f mobcal_N2.f
   ```

   g77 printed `1.0417E+02`; gfortran prints `1.0417D+02`. Same value, same
   digits, different exponent letter — a runtime formatting difference, not
   physics. Without this rule no gfortran build can match the published
   references byte for byte on any platform. Correcting the descriptor to `1pe`
   would remove the need for the rule, but that changes output and would require
   regenerating the references, so it is not done here.

## Building

The recipe is `-O3 -fno-automatic -std=legacy`, plus `-static` on Windows. It
lives in exactly one place — `FFLAGS` in `test/build-flags.sh`, which all three gates
source — because the CI workflow does not set `FFLAGS` and therefore cannot drift
from it. `README.md` documents the same flags for users; that copy is prose and
has to be updated by hand, so change both.

Chunk 1 put the recipe in `test/regression.sh`. It moved to its own file in chunk
2, when `test/bounds.sh` needed the same build: two copies of a build recipe is
how a recipe drifts, and the single-definition property is the point, not the
filename.

`-fno-automatic` is **mandatory**, not an optimization preference. The code
relies on static storage for locals, which was g77's default. Without the flag
an optimizing gfortran build gives locals automatic storage and the trajectory
integrator fails outright — a measured 39,998 lost trajectories and zero
completed, against zero lost in every `-fno-automatic` build. The failure is
loud rather than subtle, which is worth knowing: it is not the kind of bug that
silently shifts a published number.

`-static` is passed on Windows only. Dynamically linked MSYS2 builds die
silently when launched from PowerShell, Apple's linker has no fully-static mode,
and it buys nothing on a Linux runner.

`-std=legacy` was adopted in v1.1 after being deliberately left open in chunk 0.
It silences 64 diagnostics per source file, and all 128 are in the *Fortran 2018
deleted feature* class — 52 non-`CONTINUE` `DO` terminations, 6 shared `DO`
labels, 3 arithmetic `IF`s, 3 non-integer `DO` bounds — so nothing else was
hiding in that noise.

It is codegen-neutral, and the proof is static rather than statistical. With and
without the flag, `gfortran -S` output differs by one word in 17,691 lines of
assembly for `mobcal_He.f` and 20,056 for `mobcal_N2.f`, and the word is not an
instruction: `options[0]` in the array passed to `_gfortran_set_options` goes
from 10308 to 0. That is the mask of standards the *runtime* warns about.
`options[1]`, the mask of language features the compiler *accepts*, is 16383 in
both. T3 is the empirical confirmation.

The practical consequence for the gate: the warning count it prints used to be a
constant 64 that everyone learned to ignore, and is now expected to be zero. A
nonzero count means a diagnostic outside the deleted-feature class, which is
worth reading. That is the actual argument for the flag — not tidiness, but that
a build printing 64 warnings has no room left to report the 65th.

On MSYS2, `C:\msys64\mingw64\bin` must be on `PATH`. Without it `gfortran`
invocations fail with exit 1 and no output at all, which reads like a source
error rather than a missing compiler.
