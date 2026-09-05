# Changelog

All notable changes to MOBCAL-2012. Versions are two-component, matching the
repository's tags; `v2.0` is reserved for the first breaking change.

## [1.2] — Unreleased

### Added

+ **`test/refusals.sh`**, a fourth gate, seconds on both gases. It drives every
  termination a small input can reach — five cases on helium, four on nitrogen,
  one of them through a probe that calls the coordinate-reading subroutines
  directly — and requires each to exit nonzero with its message in the output
  file and on the console. It also reads each source and requires that exactly
  one bare `stop` survives and that it is the one in the main program, which is
  what covers the two terminations no input can reach. Run against the v1.1
  sources it fails 23 of its 50 assertions.
+ **`test/probe-driver.sh`**, the generated test driver that stands in for the
  main program, moved out of `test/elements.sh` so that both gates that need it
  share one copy rather than each carrying its own.

### Changed

+ **Every termination except the normal end of the program now exits 1**, and
  writes its reason to the console as well as to the output file. Through v1.1
  all but the two array-bound refusals ended in a bare Fortran `stop`, which
  exits 0, so a run that refused its input and a run that produced a cross
  section were indistinguishable to whatever launched them. Seven sites changed
  in `mobcal_He.f` and six in `mobcal_N2.f`: the `units`, charge-mode,
  undefined-element and conformer-composition refusals, the cap on trajectories
  that fail to conserve energy, and the two internal consistency checks in
  `MOBIL2`. No message text changed, and no line of `sample-output/` moved.

  **The case this matters most for is not a refusal.** The energy-conservation
  cap is reached inside the trajectory calculation, after the
  projection-approximation and exact-hard-sphere cross sections have already
  been written to the output file. A helium run that hit it left two cross
  sections behind, formatted exactly as a real result, and reported success.
  Nothing in the output file said otherwise, and nothing still does — the exit
  status is what says it.

  A run that produces a cross section still exits 0, so a script that ignored
  the status and read a number out of the output file is unaffected. A script
  that treated a nonzero status as a crash will now see the refusals it was
  previously blind to.

### Fixed

+ **The shipped run no longer overwrites itself between gases.** `mobcal.in`
  named a fixed input file, `Choline.mfj`, and a fixed output file,
  `temp.choline.n2.out` — one name written by both `mHe` and `mN2`, so a helium
  run and a nitrogen run in the same directory silently overwrote each other's
  output. There is no longer one shipped `mobcal.in`; instead `mobcal_He.in`
  and `mobcal_N2.in` each name `Choline.mfj` at the same seed and write to
  `Choline_He.out` / `Choline_N2.out` respectively, so both can be run in one
  directory without collision. The program still reads a fixed `mobcal.in`, so
  running either gas means copying the matching template over that name first
  — `README.md`, `docs/getting-started.md`, `sample-output/README.md` and
  `CLAUDE.md` all now say so. No gate reads the shipped file, so no gate's
  behaviour changes.

+ **The CI line-ending check named a file that no longer exists.** It listed
  `mobcal.in`, which this release replaced with one template per gas, so that
  one entry checked nothing. It now names `mobcal_He.in` and `mobcal_N2.in`.

### Documentation

+ **The six chunk-4 elements' integer masses are now stated as a decision, not
  left silent.** `docs/parameters.md` *Atomic masses* and one `README.md`
  sentence say that chlorine, bromine, iodine, lithium, potassium and caesium
  carry the integer mass key itself rather than a four-figure atomic weight,
  that this matches the contributor's own distributed files, and the size of
  what it costs: a worst-case shift in the reduced mass μ of +0.0024 %/+0.014 %
  (He/N2) for iodine and +0.0020 %/+0.012 % for caesium, for a light ion whose
  mass is essentially the one heavy atom. No code changed and nothing
  regenerated.
+ **`docs/` no longer cites the source by line number.** Of the 30 `file:line`
  citations `docs/mfj-format.md` and `docs/parameters.md` carried, 22 pointed
  at the wrong line, and two commits did all of it without changing the
  behaviour of anything cited: one rewrote provenance *comments only* inside
  the element tables, pushing everything below them down 22 lines in
  `mobcal_He.f` and 46 in `mobcal_N2.f` — it edited `docs/mfj-format.md` in the
  same breath, to add a *See also* bullet, without noticing that it had just
  falsified nine of that file's references — and the other added one element
  row. Every citation now names a subprogram plus a format label or a verbatim
  statement (`ljparm`'s `itest.eq.0` arm, format 602), which no insertion can
  move and which a reader can grep. The exit-status work above then tested that
  in passing: it changed 55 lines in `mobcal_He.f` and 38 in `mobcal_N2.f`, and
  all 45 anchors still resolved unedited. `CLAUDE.md` *How the documentation
  cites the source* records the decision and the count behind it. One stale
  `grep -n` transcript in `test/regression.sh` went the same way, to a `grep`
  without `-n`.
+ **One ungated no-drift claim withdrawn.** `docs/mfj-format.md` said the list
  of defined mass keys printed by format 602 "is generated from the build's
  actual table, so it can't drift out of sync with what the code accepts". It
  is a hardcoded string sitting below the rows; `test/elements.sh` checks that
  the refusal fires and names the key, and `test/refusals.sh` checks that it
  exits nonzero, but nothing compares the list against the rows. Both files'
  lists are correct today, and *Adding an element* in `docs/parameters.md` now
  carries the one command that shows it — labelled as the hand check it is.

## [1.1] — 2026-08-25

The physics is untouched. Every cross section this release computes for an input
that v1.0 accepted is the value v1.0 computed, bit for bit — that is what
`test/regression.sh` checks on Linux, macOS and Windows on every change.

### Added

+ **Six elements**, from Iain Campuzano's parameterizations: chlorine (35),
  bromine (80) and iodine (127) in both gases, plus lithium (7), potassium (39)
  and caesium (133) in nitrogen.
+ **Phosphorus (31) in helium**, which previously only nitrogen defined. It is
  built by the same construction as helium's three halogens — the universal
  force field scaled by 0.80 — so it applies a construction already in that
  table rather than inventing a value, which is what had kept it out. It is
  still an extrapolation. It carries the same *provisional* warning, and
  the same caveat: the 0.80 factor is attested in no published source, so the
  row is a construction rather than a measurement. Its hard-sphere radius is
  phosphorus's own 4.2 Å from the nitrogen table, not carbon's borrowed 2.7 Å,
  so it is the one row that prints one of the two warnings and not the other.
  This took the **helium parameter set to 2.1**; nitrogen's stayed at 2.0.
  `mobcal_He.f` now defines 13 mass keys, `mobcal_N2.f` 16.
+ **Two warnings**, printed into the output file whenever an atom actually uses
  the parameter in question. One names a *provisional* Lennard-Jones parameter:
  helium's four newest rows — chlorine, bromine, iodine and phosphorus — are the
  universal force field scaled by 0.80 and used directly as helium-X pair
  parameters, without the combining rule or the r_min-to-σ conversion the
  nitrogen table applies to the same numbers, and on a factor no published
  source attests. The other names a *borrowed* hard-sphere radius: chlorine,
  bromine, iodine, lithium, potassium and caesium carry carbon's 2.7 Å, which
  for iodine is smaller than its own Lennard-Jones σ.
+ **`docs/parameters.md`**, which derives every parameter in both element tables.
  `mobcal_N2.f`'s table turns out to be Rappé's UFF throughout — all 32 literals
  reproduce `x_I` and `D_I` times one factor per element (0.93 / 1.20 / 0.43 /
  1.00) to five significant figures. That independently confirms which silicon
  row was the right one to keep, corrects the "0.8602" this repository gave for
  the helium halogens (the factor is 0.80 against UFF; 0.80/0.93 = 0.8602), and
  records that `conve` writes 4.2 kJ/kcal for 4.184 — 0.382 % high, baked into
  every published nitrogen result, and not to be corrected.
+ **A version banner.** Every output file now opens with the build that wrote it
  and the version of the element table it used, and the SUMMARY repeats both —
  `MOBCAL 1.1 (mobcal_He.f), He parameter set 2.1`. Code version and parameter-set
  version are separate because the helium and nitrogen tables are revised
  independently — which this release demonstrates: helium ends at 2.1 and
  nitrogen at 2.0.
+ **Array-bound refusals.** An input declaring more than 1,000 atoms per
  conformer or more than 100 coordinate sets is refused with a message naming
  both the limit and the count given, and the program exits nonzero. Previously
  it overran its `COMMON` blocks and could print a plausible-looking cross section
  and exit successfully.
+ **Three test gates and a CI matrix** — `test/regression.sh` (physics),
  `test/bounds.sh` (the refusals), `test/elements.sh` (the parameter table) — run
  on Linux, macOS and Windows, one job per platform and gas.
+ **`mobcal_limits.inc`** and **`mobcal_version.inc`**, both required to compile.
+ **`docs/mfj-format.md`**, a precise description of the `.mfj` input format,
  including that the mass column is a lookup key rather than the mass
  actually used (so a specific isotope can't be represented), and that
  `mobcal_N2.f`'s `equal` charge mode sums the (otherwise unused-by-helium)
  charge column into the total charge, while `mobcal_He.f`'s ignores it —
  a 5-column file with zero in that column silently zeroes the ion's charge
  in nitrogen only.
+ **`docs/getting-started.md`**, an in-repository refresh of the guide
  originally circulated as `N2_Mobcal_Getting_Started.pdf`, with the `g77`
  compiling advice replaced by a pointer to the current build instructions.
+ **`tools/xyz2mfj.py`**, an optional, dependency-free converter from plain
  XYZ coordinates (including multi-frame XYZ, for a conformer ensemble) to a
  `.mfj` file. Not part of the build and not covered by the three gates.

### Changed

+ **`README.md`'s build instructions.** `g77` is gone; the recommended build is
  `gfortran -O3 -fno-automatic -std=legacy` (plus `-static` on Windows), which
  reproduces the published output exactly and is about 2.3× faster than `-O0`.
  `-fno-automatic` is mandatory at every optimization level: without it an
  optimized build loses every trajectory and completes no cycles at all.
+ **The refusal for an unknown element** now names the mass key it was given,
  states the `nint(atomic weight)` key convention, and lists the keys the build
  defines. Its format was `i3`, which printed a wrong atom number above atom 999
  — inside this build's own 1,000-atom bound.
+ **What the documentation promises a fresh run will reproduce.** Three pages
  said an unmodified `mobcal.in` gives output "exactly the same" as the
  committed reference — `README.md`'s *Run the compiled code*, which also named
  a binary (`./mn`) no build command in the file produces and an output file
  (`temp.out`) the shipped `mobcal.in` does not write, plus
  `docs/getting-started.md` and `sample-output/README.md`. Measured from a clean
  clone, a fresh run reproduces every *number*, and three lines still differ
  from a plain `diff`: the echoed input file name, which the references took
  from a file called `Choline_pop.mfj`; the `D`-versus-`E` exponent letter; and
  the line terminator on Windows. None is physics, and `test/regression.sh`
  accounts for all three — which is why all three pages now name them and point
  at that script rather than at `diff`.
+ **One element table per source file.** Each of `fcoord` and `ncoord` carried
  its own copy; both now call one `ljparm` subroutine.
+ **Every per-row provenance comment in `mobcal_N2.f`'s element table.** "from
  fitting C60 mobility", the Viehland note on sodium, "from fitting mobilities of
  small silicon clusters" and each "(same as carbon)" / "(same as silicon)" were
  copied from `mobcal_He.f` when the nitrogen table was written, and describe
  helium pair parameters rather than the UFF rows they sat above. Each now names
  the scaling factor actually applied; the wording worth keeping, including
  Viehland, is kept and attributed to the file it belongs to. `mobcal_He.f` keeps
  its originals, where they are correct — except fluorine, whose "(same as
  carbon)" row is a verbatim copy of oxygen.
+ **The reference outputs under `sample-output/`.** `Choline_He.out` was
  regenerated twice and `Choline_N2.out` once, each time for a named output
  change and nothing else. Every other line of both files still carries the
  numbers published with the 2012 paper.

### Fixed

+ **Silicon in nitrogen.** `ncoord`'s copy of the table held iron's well depth
  and radius (0.0130 / 2.9120) under silicon's comment, against `fcoord`'s
  0.4020 / 4.2950. Any multi-conformer nitrogen run containing silicon therefore
  used iron's parameters for every conformer after the first, and nothing in the
  output said so. `fcoord`'s row is the one every single-conformer silicon run
  ever published used, and it is the one now kept.
+ **The `q1st` column** in the *average values for q1st* table was divided by
  `inp`, the number of velocity points, rather than by `itn`, the number of
  cycles actually summed. At the shipped settings every value in that column was
  four times too small. The corrected column satisfies the identity it always
  should have — `sum(wgst * q1st)` now reproduces the printed
  `mean OMEGA*(1,1)`, 1.904466 against 1.9045E+00, where before it gave exactly
  a quarter of it. Nothing reads `q1st` back, so no cross section, standard
  deviation or mobility was ever affected.

### The regenerated reference diffs

`sample-output/` moved in exactly two commits, and both diffs were counted line
by line. The first, in `Choline_He.out`, 84 lines:

| lines | change |
|---|---|
| +1 | the banner, above `input file name` |
| −1 / +1 | `program version = junkn.f` → `program version = MOBCAL 1.1 (mobcal_He.f)` |
| +1 | `He parameter set = 2.0`, in the SUMMARY |
| −40 / +40 | the `q1st` column, every value 4.0000× its old one; `gst2` and `wgst` unchanged |

`Choline_N2.out` is the same four changes. No cross section, no standard
deviation, no stochastic diagnostic and no geometry line moved in either file.

The second, when phosphorus took the helium table to parameter set 2.1, is two
lines and touches `Choline_He.out` only:

| lines | change |
|---|---|
| −1 / +1 | the banner, `He parameter set 2.0` → `2.1` |
| −1 / +1 | `He parameter set = 2.0` → `= 2.1`, in the SUMMARY |

`Choline_N2.out` does not move: nitrogen's table did not change. Choline
contains no phosphorus and no halogen, so neither element warning appears in
either reference.

## [1.0] — 2012

The code as published with Campuzano, I. D. G.; Bush, M. F.; Robinson, C. V.;
Beaumont, C.; Richardson, K.; Kim, H.; Kim, H. I. "Structural Characterization of
Drug-like Compounds by Ion Mobility Mass Spectrometry: Comparison of Theoretical
and Experimentally Derived Nitrogen Collision Cross-sections." *Anal. Chem.*
**2012**, *84*, 1026-1033.
