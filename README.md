# MOBCAL-2012
A program for calculating collision cross sections that was reported in https://doi.org/10.1021/ac202625t

## Calculating the Mobilities of Drug-Like Molecular Ions in Helium and Nitrogen
We reported versions of MOBCAL optimized for calculating the mobilities of drug-like molecular ions in helium and in nitrogen gasses [1], based on the original trajectory method [2] and an extension of the method to nitrogen gas [3]. Based on the interest from the community, we have prepared a short getting-started guide.

### Any research that uses this code or the included Lennard-Jones parameters should reference [1].  

### References
1. Campuzano, I. D. G.;* Bush, M. F.;* Robinson, C. V.; Beaumont, C.; Richardson, K.; Kim, H.; Kim, H. I. “Structural Characterization of Drug-like Compounds by Ion Mobility Mass Spectrometry: Comparison of Theoretical and Experimentally Derived Nitrogen Collision Cross-sections.” <i>Anal. Chem.</i> <b>2012</b>, <i>84</i>, 1026-1033.
2. Mesleh, M. F.; Hunter, J. M.; Shvartsburg, A. A.; Schatz, G. C.; Jarrold, M. F. “Structural Information from Ion Mobility Measurements: Effects of the Long Range Potential." <i>J. Phys. Chem.</i> <b>1996</b>, <i>100</i>, 16082-16086.
3. Kim, H; Kim, H. I.; Johnson, P. V.; Beegle, L. W.; Beauchamp J.L.; Goddard, W.A.; Kanik, I. “Experimental and theoretical investigation into the correlation between mass and ion mobility for choline and other ammonium cations in N2.” <i>Anal. Chem.</i> <b>2008</b>, <i>80</i>, 1928-1936.

## Files

### Program, input, and reference output
+ `mobcal_He.f` Fortran 77 source code
+ `mobcal_N2.f` Fortran 77 source code
+ `mobcal_limits.inc` The compiled-in array bounds, included by both sources. **Required to compile**, and the one file to edit if you need larger limits
+ `mobcal_version.inc` The release version of the code, included by both sources. **Required to compile**
+ `mobcal.in` Parameter file. Sets input file name, output file name, and random number seed
+ `Choline.mfj` Input file used for choline in [1]
+ `sample-output/Choline_He.out` Output file for choline in He gas
+ `sample-output/Choline_N2.out` Output file for choline in N2 gas

### Documentation
+ `docs/getting-started.md` An in-repository refresh of the original emailed guide, `N2_Mobcal_Getting_Started.pdf`
+ `docs/mfj-format.md` The `.mfj` input format precisely: every line, the element-key convention, and the charge-mode differences between the two gases
+ `tools/xyz2mfj.py` Optional, dependency-free converter from plain XYZ coordinates to a `.mfj` file. Not part of the build and not covered by the three gates

The two files under `sample-output/` are also the fixtures the regression gate
compares against, so they are reference data and not just examples. They are the
files published with [1], regenerated in v1.1 for the two output changes that
release makes — the version banner and the `q1st` column, listed in
`CHANGELOG.md`. Every other line, including all four cross sections and every
stochastic diagnostic, is unchanged from the published files.

### Repository
+ `LICENSE` GNU General Public License, version 3
+ `CHANGELOG.md` What changed in each release, and for the one release that regenerated the reference outputs, exactly which lines moved
+ `CLAUDE.md` Contributor notes: the three gates, line endings, and build flags
+ `test/regression.sh` Regression gate. Builds both sources, runs `Choline.mfj` at the seed recorded in the reference outputs, and compares the result against `sample-output/`
+ `test/bounds.sh` Array-bound gate. Checks that an input exceeding either compiled-in limit is refused with a message naming the limit and the actual count, and exits nonzero
+ `test/elements.sh` Element-table gate. Builds a probe against the real coordinate-reading subroutines and checks that every atom gets the same Lennard-Jones and hard-sphere parameters in every coordinate set
+ `test/silicon-2conf.mfj` The element gate's input: two identical coordinate sets containing silicon
+ `test/new-elements-he.mfj`, `test/new-elements-n2.mfj` The element gate's inputs for the elements added in v1.1 -- see *Supported elements* below
+ `test/build-flags.sh` The build recipe, in the one place it is written down. Sourced by all three gates
+ `test/stochastic-lines.txt` Output lines excluded from the exact comparison because they depend on the pseudo-random number stream
+ `test/strict-platforms` Platforms on which whole-file byte identity is a gating check rather than a reported one
+ `.github/workflows/ci.yml` Runs all three gates on Linux, macOS, and Windows, one job per platform and gas
+ `.githooks/commit-msg` Normalizes the AI-assistance attribution trailer. Enable it once per clone with `git config core.hooksPath .githooks`
+ `.gitattributes` Pins line endings to LF, in the repository and in the working tree, so the byte comparison means the same thing on every platform
+ `.gitignore` Build products and the scratch directories the three gates run in

## Environment
All results in [1] were calculated by Iain Campuzano in a Linux environment. The code
is now built and tested on Linux, macOS and Windows on every change; see
*Compiling source code* below for the platforms and compiler versions.

## Compiling source code

There are no external dependencies, no configure step and no build system. One
command per gas, run from the top of the repository:

```sh
gfortran -O3 -fno-automatic -std=legacy -o mHe mobcal_He.f
gfortran -O3 -fno-automatic -std=legacy -o mN2 mobcal_N2.f
```

On Windows, add `-static`:

```sh
gfortran -O3 -fno-automatic -std=legacy -static -o mHe.exe mobcal_He.f
```

`gfortran` is part of GCC: available from every Linux package manager, from
Homebrew on macOS, and from MSYS2 on Windows.

Each source `include`s `mobcal_limits.inc` and `mobcal_version.inc`, so both
files have to be present alongside it — but they do not change the command.
`gfortran` resolves an `include` relative to the directory of the source file, so
building either source by absolute path from an unrelated working directory
produces a byte-identical binary. The build is still one compiler invocation with
nothing to install.

**These are the flags the continuous-integration matrix uses** — three platforms,
both gases, compared against the reference outputs under `sample-output/`.
`test/build-flags.sh` holds the authoritative copy, and all three gates source it; if
you change the flags in one place, change them in the other.

Earlier versions of this file recommended `g77` and advised against optimization
flags. `g77` has not shipped in about fifteen years and is not packaged for
current Linux or macOS, and it is no longer needed: plain `gfortran` reproduces
the published choline results exactly, to every digit, including the stochastic
diagnostic lines. The advice against optimization was a correct response to a
real failure whose cause was not `-O2`; see immediately below.

### `-fno-automatic` is mandatory, not an optimization preference

This code keeps values in local variables that have to survive between calls to
the routine that owns them. That was the default in `g77`, the compiler it was
written for. `gfortran` gives locals automatic storage instead, and
`-fno-automatic` is what restores the old behaviour. Pass it at every
optimization level, including `-O0`.

Without it, an optimizing build does not shift a digit — it breaks the trajectory
integrator outright:

| build | trajectories lost | cycles completed | cross section |
|---|---|---|---|
| `-O2` alone | 39,998 | **0** | none produced |
| `-O2 -fno-automatic` | 0 | all | published value |
| `-O3 -fno-automatic` | 0 | all | published value |

The failure is **loud**. A build without the flag writes `trajectory lost` on
essentially every encounter, completes no cycles at all, and so never reaches the
point of printing a cross section. There is no quiet wrong answer here and nobody
can have unknowingly published a bad `-O2` number — which is worth stating
plainly, because the older warning against `-O2` left open the worse possibility
that optimized builds were subtly biased.

### `-std=legacy` silences 64 warnings per file and changes nothing else

Without it each source file draws 64 diagnostics, and every one of the 128 is in
the *Fortran 2018 deleted feature* class: 52 `DO` termination statements that are
not `END DO` or `CONTINUE`, 6 shared `DO` termination labels, 3 arithmetic `IF`
statements, 3 non-integer `DO` bounds. All are genuine and all are inherent to
Fortran of this vintage. None is actionable without rewriting code whose value
lies in *not* having been rewritten — this is the 1996/2012 physics, and being
comparable against thirty years of literature is the point.

`-std=legacy` is codegen-neutral here, and that is checked rather than asserted.
With and without the flag, `gfortran -S` output differs by exactly one word — in
17,691 lines of assembly for `mobcal_He.f` and 20,056 for `mobcal_N2.f` — and the
word is not an instruction:

```
 options.161.102:
-        .long   10308        # standards the runtime warns about
+        .long   0
         .long   16383        # features the compiler accepts -- unchanged
```

That array is the argument to `_gfortran_set_options`. The flag zeroes a
diagnostic mask; the set of accepted language features is identical. The whole-file
byte-identity tier of the regression gate confirms it empirically on all three
platforms.

The point is not quiet builds for their own sake. A build that prints 64 warnings
every time has no room left to tell you about the 65th.

### `-static` is for Windows only

Pass it on Windows and nowhere else.

+ **Windows / MSYS2** — required in practice. A dynamically linked MSYS2 binary
  exits silently, with no output and no error message, when launched from
  PowerShell rather than from the MSYS2 shell, because it cannot find its runtime
  DLLs. Also note that `C:\msys64\mingw64\bin` must be on `PATH`, or `gfortran`
  itself fails with exit status 1 and no output at all — which reads like a source
  error rather than a missing compiler.
+ **macOS** — Apple's linker has no fully-static mode; `-static` fails the link.
+ **Linux** — it works and buys nothing.

`test/regression.sh` encodes exactly this split, so a local run and a CI run agree
about it.

### The flag table

Choline in helium at the input and seed shipped in `mobcal.in`, on one x86_64
workstation running Windows with MSYS2 gfortran 16.2.0.

Measured by **interleaved repeats**: every variant is built once, then all of them
are run in rotation for ten rounds. That method is not fussiness. Contention from
unrelated work can only ever make a run slower, so under an unknown and varying
load a single timed pair produces a confidently wrong table — two runs of the
*same* binary differed by 1.99x across these rounds. Interleaving makes the load
common to all variants, and the minimum then estimates the uncontended cost. Both
minimum and median are quoted, since a minimum can rest on one lucky run; here the
two ratios agree to within 2% for every variant.

All builds also carry `-std=legacy`, and `-static` because this is Windows. To
keep ten full rounds affordable these runs use `itn=2` rather than the shipped
`itn=10` — one fifth of the trajectory work over the same code path.

| flags | min | median | speedup | output |
|---|---|---|---|---|
| `-O0` | 90.2 s | 96.5 s | 1.00x (baseline) | reference |
| `-O0 -fno-automatic` | 94.4 s | 100.0 s | 0.96x | byte-identical |
| `-O2 -fno-automatic` | 41.5 s | 43.7 s | 2.21x | byte-identical |
| **`-O3 -fno-automatic`** | **40.7 s** | **42.9 s** | **2.25x** | **byte-identical** |
| `-O3 -march=native -fno-automatic` | 35.9 s | 40.1 s | 2.41x | byte-identical |
| `-O2` *alone* | — | — | — | **no result: 0 cycles completed** |

Confirmed at the shipped settings rather than extrapolated from the reduced run:
four interleaved rounds of the full `itn=10` calculation — 400,000 trajectories —
gave 459.8 s for `-O0` against 194.3 s for `-O3 -fno-automatic`, a **2.36x**
speedup, with all eight runs byte-identical to each other and to
`sample-output/Choline_He.out`.

Byte-identical here means the entire output file — every stochastic diagnostic and
the standard deviation, not merely the cross section.

Three conclusions:

+ **`-O3 -fno-automatic -std=legacy` is the recommended default**: the fastest
  portable build, and it produces the published numbers exactly.
+ **`-fno-automatic` costs about 4% at `-O0`** and nothing at all where it
  matters. It is not an optimization trade-off to weigh — the recommended build is
  2.25x faster than either `-O0` column, and without the flag there is no result
  to compare against.
+ **`-march=native` stays out.** Its median is 4% below plain `-O3`, which is
  inside the run-to-run noise, and its faster times are not reproducible on demand
  — this machine's `native` timings are bimodal, clustering at 39.8–40.2 s and
  35.9–36.2 s with nothing between, so the apparent gain depends on where the
  process lands rather than on the flag. It also produces a binary that need not
  run on another machine — a poor trade for a program whose output is meant to be
  comparable across machines and across decades.

### Checking your build

With the provided `mobcal.in` and `Choline.mfj`, helium should report

```
 average TM cross section = 5.5402E+01
```

and nitrogen `1.1592E+02`. To check the whole file rather than one line:

```sh
sh test/regression.sh --gas he
```

That builds, runs and compares against the references in `sample-output/`.
`CLAUDE.md` explains the three tiers it reports and the two normalizations the
comparison applies.

A second, much faster gate checks that an input too large for the compiled
array bounds is refused rather than silently miscalculated:

```sh
sh test/bounds.sh --gas he
```

It finishes in seconds, because every case it runs is designed to terminate
before a single trajectory is integrated. See *Size limits* below.

A third gate, also seconds, checks the per-element parameter table:

```sh
sh test/elements.sh --gas he
```

Each atom's Lennard-Jones and hard-sphere parameters are looked up by integer
mass from a table in the source. Those parameters never appear in the output
file for any coordinate set after the first, so this gate calls the
coordinate-reading subroutines directly and reads the values back out. It runs
an input of two identical coordinate sets and requires every atom to come out of
both with identical parameters. Before v1.1 that was not true in nitrogen: the
table was written out twice and the second copy gave silicon iron's values, so a
multi-conformer run containing silicon silently changed parameters after the
first conformer.

### Tested compilers

| platform | compiler |
|---|---|
| Linux, x86_64 | gfortran 14.3.0 |
| macOS, arm64 | gfortran 14.4.0 (Homebrew) |
| Windows, x86_64 | gfortran 14.2.0 (MinGW-w64), 16.2.0 (MSYS2) |
| Linux, 2012 | `g77` — the compiler the published output in [1] was produced with |

All of these agree bit-for-bit on the 400,000-trajectory choline calculation,
after the two normalizations documented in `CLAUDE.md`. `g77` is listed as
provenance, not as a requirement: the `sample-output/` files still carry its
numbers line for line, and the v1.1 regeneration reproduced every one of them.

## Run the compiled code
+ example: `./mn`  
+ If you use the provided `mobcal.in` file, the resulting `temp.out` file should be <u>exactly</u> the same as the provided output file.  

### Which version produced an output file

Every output file opens with a banner naming the build that wrote it and the
version of the element table it used, and the SUMMARY at the end repeats both:

```
 MOBCAL 1.1 (mobcal_He.f), He parameter set 2.0
```

The two are versioned separately because the helium and nitrogen tables are
revised independently — v1.1 added three elements to helium and six to nitrogen,
and corrected silicon in nitrogen only — so a table that did not change does not
get a bump. Through v1.0 the SUMMARY instead read `program version = junkn.f`,
identical in both sources, which named a scratch file rather than a version and
could not distinguish a helium run from a nitrogen one.

## Preparing input files

`docs/mfj-format.md` documents the `.mfj` format precisely -- the label,
coordinate-set and atom counts, units, the three charge modes, and the
element-key convention -- including two things that are easy to get wrong: the
mass column is a lookup key rather than the mass actually used, and `equal`
charge mode does not mean quite the same total charge in `mobcal_N2.f` as it
does in `mobcal_He.f`. `docs/getting-started.md` is a short in-repository
refresh of the original emailed guide. `tools/xyz2mfj.py` converts plain XYZ
coordinates to a `.mfj` file, optionally.

## Limitations
+ This method has been validated for drug-like small molecular ions in low pressure, ambient temperature He and N2 mobility experiment [1].  
+ This method has not been validated for other ions classes or experiments performed at high pressures or non-ambient temperatures.

### Supported elements

Each atom in an input file is identified by an integer mass key --
`nint` of its atomic weight -- looked up in a table in the source. An
unrecognized key is refused, naming the atom, the key you gave, the
`nint(atomic weight)` convention, and the keys the build actually knows.

| gas | parameter set | defined keys (`nint` of atomic weight) |
|---|---|---|
| He | 2.0 | 1, 12, 14, 16, 19, 23, 28, 32, 35, 56, 80, 127 |
| N2 | 2.0 | 1, 7, 12, 14, 16, 19, 23, 28, 31, 32, 35, 39, 56, 80, 127, 133 |

The parameter set is the version each output file's banner names. Set 1.0 is the
table published with [1]: nine elements in helium, ten in nitrogen. Set 2.0 is
this release's — the new elements below, and in nitrogen the silicon correction.

Chlorine (35), bromine (80) and iodine (127) in **helium** are
**provisional**: they were transformed from `mobcal_N2.f`'s X-X self
parameters by a single factor (0.8602, in both the Lennard-Jones well depth
and radius) rather than independently fitted to helium mobility data. A run
that uses one of them prints a warning naming the atom. The same three
elements in **nitrogen**, and lithium (7), potassium (39) and caesium (133)
in nitrogen, are fitted the same way as every other row in that table and
carry no such warning.

All six of these new elements -- in whichever gas they appear -- borrow
carbon's 2.7 Angstrom hard-sphere radius rather than a fitted one, which
also prints a warning naming the atom. The hard-sphere radius affects only
the EHSS/PA calculation (`mobcal_N2.f` does not compute one at all), never
the trajectory method that produces the published cross section. It matters
most for iodine, whose helium Lennard-Jones radius (3.60 Angstrom) is
already larger than the borrowed hard-sphere radius.

Phosphorus (31) is defined for nitrogen but not for helium. That is a gap in
the underlying parameterization rather than an oversight in the code, and an
input with phosphorus in helium is refused rather than given a guessed
value.

`CLAUDE.md`'s *The one element table* has the file-and-line detail, and
`test/new-elements-he.mfj` / `test/new-elements-n2.mfj` are what
`test/elements.sh` runs both warnings against.

### Size limits

| | limit |
|---|---|
| atoms per conformer | 1,000 |
| coordinate sets (conformers) per input file | 100 |

An input exceeding either limit is refused, with a message naming the limit and
the count you gave, and the program exits with a nonzero status. It does not
attempt a partial calculation.

**Validated to 1,000 atoms — above that you are the first.** Both limits are set
by one line each in `mobcal_limits.inc`, so raising one is a single edit and a
rebuild. But nothing has been run through this code above 1,000 atoms, and
neither the published results nor the reference outputs come anywhere close, so
a larger limit is an untested regime rather than a tested one. That is why the
default is not simply raised for everybody.

The refusal exists because the alternative is worse than a crash. The per-atom
arrays live in Fortran `COMMON` blocks, which storage association makes
contiguous, and the build requires `-fno-automatic`, which puts them in static
storage. One atom past the limit therefore writes atom 1,001's *x* coordinate
onto atom 1's *y* coordinate — the same molecule, deterministically rewritten
mid-calculation. Measured on the unguarded code, a 1,001-atom input made
`mobcal_He.f` print

```
 average PA  cross section = 4.3469E+02
 average EHS cross section = 2.6526E+02
```

formatted exactly as a real result, and exit with a success status. `test/bounds.sh`
is the check that keeps that from being possible.
