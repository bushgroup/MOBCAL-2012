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

## The regression gate

```sh
sh test/regression.sh              # both gases
sh test/regression.sh --gas he     # one gas
sh test/regression.sh --keep       # keep test/_work to inspect the diffs
```

It builds both sources, runs `Choline.mfj` at the seed recorded in the reference
outputs, and reports three tiers. `.github/workflows/ci.yml` runs the same
script on ubuntu, macos and windows, one job per (platform, gas) pair.

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
lives in exactly one place — `FFLAGS` in `test/regression.sh` — because the CI
workflow does not set `FFLAGS` and therefore cannot drift from it. `README.md`
documents the same flags for users; that copy is prose and has to be updated by
hand, so change both.

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
