# MOBCAL-2012

The two MOBCAL programs, helium and nitrogen, as they were used for the calculations reported
in https://doi.org/10.1021/ac202625t, with the choline input and the two outputs from that
work. This repository is the 2012 release exactly as published and is not developed further;
the program that is developed now is [bushgroup/MOBCAL](https://github.com/bushgroup/MOBCAL),
which keeps these sources at its core.

## Calculating the mobilities of drug-like molecular ions in helium and nitrogen

We reported versions of MOBCAL optimized for calculating the mobilities of drug-like molecular
ions in helium and in nitrogen [1], based on the original trajectory method [2] and an extension
of the method to nitrogen [3]. Based on interest from the community, we prepared this short
getting-started guide.

### Any research that uses this code or the included Lennard-Jones parameters should reference [1].

### References

1. Campuzano, I. D. G.;\* Bush, M. F.;\* Robinson, C. V.; Beaumont, C.; Richardson, K.; Kim, H.;
   Kim, H. I. Structural Characterization of Drug-like Compounds by Ion Mobility Mass
   Spectrometry: Comparison of Theoretical and Experimentally Derived Nitrogen Collision
   Cross-sections. *Anal. Chem.* 2012, 84, 1026-1033. https://doi.org/10.1021/ac202625t
2. Mesleh, M. F.; Hunter, J. M.; Shvartsburg, A. A.; Schatz, G. C.; Jarrold, M. F. Structural
   Information from Ion Mobility Measurements: Effects of the Long Range Potential. *J. Phys.
   Chem.* 1996, 100, 16082-16086. https://doi.org/10.1021/jp961623v
3. Kim, H.; Kim, H. I.; Johnson, P. V.; Beegle, L. W.; Beauchamp, J. L.; Goddard, W. A.; Kanik,
   I. Experimental and theoretical investigation into the correlation between mass and ion
   mobility for choline and other ammonium cations in N2. *Anal. Chem.* 2008, 80, 1928-1936.

## Files

- `mobcal_He.f`: Fortran 77 source, helium.
- `mobcal_N2.f`: Fortran 77 source, nitrogen.
- `mobcal.in`: the run file, which each program reads from the directory it runs in. Three
  lines: the input file name, the output file name, and the random number seed.
- `Choline.mfj`: the input used for choline in [1].
- `sample-output/Choline_He.out`: the output for choline in helium with `mobcal.in` as provided.
- `sample-output/Choline_N2.out`: the same for nitrogen.

## Where these programs come from

The helium program descends from the Jarrold group's 2000 release, which is kept as
distributed at [bushgroup/MOBCAL-2000](https://github.com/bushgroup/MOBCAL-2000). `mobcal_He.f`
is that release's `mobcal.f` with 13 changed regions and nothing else. The run file was renamed
from `mobcal.run` to `mobcal.in`. The temperature became 301 K from 298 K. The number of
trajectories per velocity point per cycle, `imp`, became 1,000 from 25, so that a 2012
calculation on one coordinate set integrates as many trajectories as a 2000 calculation
averaged over 40 of them. The Lennard-Jones well depths and radii of hydrogen, carbon, nitrogen
and oxygen were changed, in both of the routines that read coordinates: each 2012 pair is the
2000 pair multiplied by one factor per element, 0.95 for H, 0.99 for C, 1.10 for N and 0.80
for O, applied to the well depth and the radius alike. A row for fluorine was added. The
integrator, the random number generator (RANLUX), the sampling of the hard-sphere and
projection methods, the parameters of Na+, Si, S and Fe, the hard-sphere radii of every
element and the output formats are the same in both. The nitrogen program is the extension of
reference [3], as used for reference [1]. The parameters in both programs are the ones the
calculations of [1] were made with.

The current program in bushgroup/MOBCAL reads its element table, its temperature and its
sampling counts from files instead of the source. With the 2000 release's table as its element
file and the temperature and `imp` set to 298 K and 25, it reproduces the 2000 reference output
from the same seed, apart from three lines whose format changed after 2012; with the tables and
values compiled into these sources, it reproduces the two sample outputs here.

## Compiling

All results in [1] were calculated by Iain Campuzano on Linux with g77, and the two outputs
under `sample-output/` were written by g77 builds. The README that accompanied this release
reported that compiling with optimization, such as `-O2`, produced binaries that did not
execute correctly, and that gfortran had not worked. Both observations were correct and have
one cause: the code relies on local variables keeping their values between calls, which g77
gave it by default, whereas gfortran gives local variables automatic storage under optimization
unless told otherwise. With `-fno-automatic`, an optimized gfortran build reproduces both sample
outputs:

```
gfortran -O3 -fno-automatic -std=legacy -o mh mobcal_He.f
gfortran -O3 -fno-automatic -std=legacy -o mn mobcal_N2.f
```

Such a build, compared with the sample outputs, differs in two ways that are formatting rather
than physics. On Windows a gfortran build writes CRLF line endings, so a comparison strips the
end-of-line carriage return. And the `mass of ion` line is printed with a `D` exponent where
g77 printed `E`, because its format is `1pd11.4`; every other line is byte for byte the sample
output. This holds on Windows, macOS and Linux with the gfortran of 2026, and is tested on every
change of bushgroup/MOBCAL, which builds these sources with those flags.

## Running

Run the compiled program in a directory holding `mobcal.in` and `Choline.mfj`:

```
./mh
```

With `mobcal.in` as provided, the output is written to the file its second line names,
`temp.choline.n2.out`, for either gas, and should be exactly the sample output for that gas,
apart from the two formatting differences above. Choline takes a few minutes in helium and
about an hour in nitrogen on one core of a 2026 workstation.

## Limitations

- This method has been validated for drug-like small molecular ions in low-pressure, ambient
  temperature helium and nitrogen mobility experiments [1].
- This method has not been validated for other classes of ions or for experiments performed at
  high pressures or non-ambient temperatures.

## License

GNU General Public License v3.0; see [`LICENSE`](LICENSE).
