# Getting started

This is an in-repository refresh of the short guide Iain Campuzano and Matt
Bush originally circulated by email as `N2_Mobcal_Getting_Started.pdf`. The
content is the same guide; the compiling instructions are not, because the
compiler it named is gone. Where this page would just repeat something
`README.md` or `docs/mfj-format.md` already says precisely, it links there
instead of drifting out of sync with them.

## What you need

+ `mobcal_He.f`, `mobcal_N2.f` — the two Fortran 77 sources (He and N2 gas)
+ `mobcal_limits.inc`, `mobcal_version.inc`, `mobcal_ljread.inc` — included
  by both, required to compile
+ `mobcal_He.params`, `mobcal_N2.params` — the element tables, one per gas,
  read by the matching binary when it runs; keep each beside the binary (or
  name its path on line 4 of `mobcal.in`)
+ `mobcal_He.in`, `mobcal_N2.in` — one template per gas, each naming the input
  file, the output file, the random-number seed and the element table for one
  run; copy the one you want to `mobcal.in`, the fixed name the program reads
+ `Choline.mfj` — the choline input used in the 2012 paper, and the shipped
  example of the `.mfj` format
+ `sample-output/Choline_He.out`, `sample-output/Choline_N2.out` — the
  published output, so you can check a build against a known-good answer

See *Files* in `README.md` for what every other file in the repository is
for.

## Environment

All results in the 2012 paper were calculated by Iain Campuzano on Linux.
Matt Bush ran the same code on Windows, originally under Cygwin. As of v1.1
the code is built and tested on Linux, macOS and Windows on every change —
see *Tested compilers* in `README.md` for the exact versions.

## Compiling

Superseded — do not follow the original guide's compiler advice. It named
`g77` and warned that `-O2` "resulted in binaries that did not execute
correctly." Both statements were true in 2012 and neither is the right
guidance now:

+ `g77` has not shipped in about fifteen years. Plain `gfortran` reproduces
  the published choline result exactly, to every digit.
+ The `-O2` failure was real but the diagnosis was incomplete: it isn't
  optimization that breaks the code, it's `gfortran` giving local variables
  automatic storage instead of the static storage `g77` used by default. The
  fix is one flag, and it makes optimization safe again.

Follow *Compiling source code* in `README.md` for the actual command,
platform notes, and the measurement behind it. Short version:

```sh
gfortran -O3 -fno-automatic -std=legacy -o mHe mobcal_He.f
gfortran -O3 -fno-automatic -std=legacy -o mN2 mobcal_N2.f
```

(add `-static` on Windows).

## Running

```sh
cp mobcal_He.in mobcal.in
./mHe
```

reads `mobcal.in` from the current directory under that fixed name, which in
turn names the `.mfj` input file, the output file, the random-number seed
and, on an optional fourth line, the element table to read — without that
line the program looks for `mobcal_He.params` or `mobcal_N2.params` in the
current directory, and refuses to run if it is not there.
There is one template per gas rather than one shared `mobcal.in`, since the
program's fixed filename would otherwise make a helium and a nitrogen run in
the same directory overwrite each other's output — copy `mobcal_He.in` or
`mobcal_N2.in` to `mobcal.in` first. With the copy and `Choline.mfj` shipped in
this repository, `mHe` reproduces every number in
`sample-output/Choline_He.out` and `mN2` (after copying `mobcal_N2.in`
instead) every number in `sample-output/Choline_N2.out`. Two lines still
differ from a plain `diff`
— the echoed input file name, which the 2012 references took from a file
called `Choline_pop.mfj`, and the line terminator on Windows — so check with
`sh test/regression.sh`, which accounts for both. *Run the compiled code*
and *Checking your build* in `README.md` have the detail and the one-line
cross-section values.

## Preparing your own input

The `.mfj` format — the label, the coordinate-set and atom counts, units,
charge modes, and the element-key convention — is documented precisely in
`docs/mfj-format.md`, including two things that are easy to get wrong and
are not in this guide's scope: the mass column is a lookup key, not the mass
that gets used, and the `equal` charge mode does not mean quite the same
thing in `mobcal_N2.f` as it does in `mobcal_He.f`. Read that page before
hand-writing a file from a new structure. `tools/xyz2mfj.py` automates the
common case.

## Limitations

+ Validated for drug-like small molecular ions in low-pressure, ambient-
  temperature He and N2 mobility experiments — the systems in the 2012 paper.
+ Not validated for other ion classes, or for experiments at high pressure or
  non-ambient temperature.
+ Validated to 1,000 atoms and 100 coordinate sets — see *Size limits* in
  `README.md`.
+ Supports the elements listed in *Supported elements* in `README.md` — the
  rows of the `.params` file the run reads — and
  refuses cleanly, naming what it needs, if your input uses one it doesn't
  know. Every refusal writes its reason to the console as well as to the
  output file and exits with status 1, so a batch script can tell a refused
  run from one that produced a number -- see *Exit status* in `README.md`.

## References

Any research that uses this code or the included Lennard-Jones parameters
should cite [1]. A run using one of the elements added in v1.1 additionally
rests on [4], the force field `mobcal_N2.f`'s table is derived from, and on
[5] for the halogens or [6] for the alkali metals -- see `docs/parameters.md`.

1. Campuzano, I. D. G.;\* Bush, M. F.;\* Robinson, C. V.; Beaumont, C.;
   Richardson, K.; Kim, H.; Kim, H. I. "Structural Characterization of
   Drug-like Compounds by Ion Mobility Mass Spectrometry: Comparison of
   Theoretical and Experimentally Derived Nitrogen Collision Cross-sections."
   *Anal. Chem.* **2012**, *84*, 1026-1033.
2. Mesleh, M. F.; Hunter, J. M.; Shvartsburg, A. A.; Schatz, G. C.; Jarrold,
   M. F. "Structural Information from Ion Mobility Measurements: Effects of
   the Long Range Potential." *J. Phys. Chem.* **1996**, *100*, 16082-16086.
3. Kim, H.; Kim, H. I.; Johnson, P. V.; Beegle, L. W.; Beauchamp, J. L.;
   Goddard, W. A.; Kanik, I. "Experimental and theoretical investigation into
   the correlation between mass and ion mobility for choline and other
   ammonium cations in N2." *Anal. Chem.* **2008**, *80*, 1928-1936.
4. Rappé, A. K.; Casewit, C. J.; Colwell, K. S.; Goddard, W. A., III;
   Skiff, W. M. "UFF, a Full Periodic Table Force Field for Molecular
   Mechanics and Molecular Dynamics Simulations." *J. Am. Chem. Soc.*
   **1992**, *114*, 10024-10035.
5. Lalli, P. M.; Corilo, Y. E.; Fasciotti, M.; Riccio, M. F.; de Sa, G. F.;
   Daroda, R. J.; Souza, G. H. M. F.; McCullagh, M.; Bartberger, M. D.;
   Eberlin, M. N.; Campuzano, I. D. G. "Baseline resolution of isomers by
   traveling wave ion mobility mass spectrometry: investigating the effects
   of polarizable drift gases and ionic charge distribution."
   *J. Mass Spectrom.* **2013**, *48*, 989-997.
6. Flick, T. G.; Campuzano, I. D. G.; Bartberger, M. D. "Structural
   Resolution of 4-Substituted Proline Diastereomers with Ion Mobility
   Spectrometry via Alkali Metal Ion Cationization." *Anal. Chem.*
   **2015**, *87*, 3300-3307.
