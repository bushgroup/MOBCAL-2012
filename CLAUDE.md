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

## The two gates

```sh
sh test/regression.sh              # both gases -- minutes for he, ~1 h for n2
sh test/bounds.sh                  # both gases -- seconds
```

`test/regression.sh` is the physics gate: one valid input, compared against
committed reference outputs. `test/bounds.sh` is the safety gate: three inputs
whose expected result is a refusal, so there is nothing to compare against and
nothing that runs long. They are separate scripts because those are different
shapes, and they share one build recipe — `test/build-flags.sh`, described under
*Building* below. CI runs `bounds.sh` first, since a broken build should not cost
an hour of n2 to discover.

## The regression gate

```sh
sh test/regression.sh              # both gases
sh test/regression.sh --gas he     # one gas
sh test/regression.sh --keep       # keep test/_work to inspect the diffs
```

It builds both sources, runs `Choline.mfj` at the seed recorded in the reference
outputs, and reports three tiers. `.github/workflows/ci.yml` runs this script
and `test/bounds.sh` on ubuntu, macos and windows, one job per (platform, gas)
pair.

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
lives in exactly one place — `FFLAGS` in `test/build-flags.sh`, which both gates
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
