# Where the Lennard-Jones parameters come from

Every number in either source file's element table, and how to re-derive it.
`CLAUDE.md`'s *The one element table* has the file-and-line detail and the
editing hazards; this page is the provenance.

The short version: **`mobcal_N2.f`'s table is UFF throughout**, and
**`mobcal_He.f`'s is not** — its nine original rows are direct fits to helium
mobility data, and the four added in v1.1 are UFF put through a different,
undocumented transformation. That asymmetry is why the two tables are separate
subroutines, separately versioned, and why only one of them prints a warning.

## The two tables hold different quantities

| | `mobcal_He.f` | `mobcal_N2.f` |
|---|---|---|
| what a row is | a He–X **pair** parameter, used as-is | an X–X **self** parameter, combined with the gas at run time |
| `eolj` | ε in eV, written as `<mev>d-3*xe` | `sqrt(eogas · D) · conve · xe` |
| `rolj` | σ in m, written as `<angstrom>d0*1.0d-10` | `sqrt(rogas · x) · convr · 1.0d-10` |
| combining rule | none | geometric mean with the gas |

`rolj` is σ in both files: the potential is
`4ε(σ¹²/r¹² − σ⁶/r⁶)` (`mobcal_He.f:1058`). Merging the two tables would mean
inventing a conversion that exists in neither source.

## `mobcal_N2.f`: UFF times one factor per element

Each row is Rappé's universal force field [4] natural bond distance `x_I` and
well depth `D_I`, multiplied by one scaling factor, fitted to reproduce
experimental nitrogen collision cross sections [1, 5, 6].

| key | element | factor | UFF `D_I` | in source | UFF `x_I` | in source |
|---|---|---|---|---|---|---|
| 1 | hydrogen | 0.43 | 0.044 | `0.0189` | 2.886 | `1.2409` |
| 7 | lithium | 1.00 | 0.025 | `0.0250` | 2.451 | `2.4510` |
| 12 | carbon | 0.93 | 0.105 | `0.0977` | 3.851 | `3.5814` |
| 14 | nitrogen | 1.20 | 0.069 | `0.0828` | 3.660 | `4.3920` |
| 16 | oxygen | 0.93 | 0.060 | `0.0558` | 3.500 | `3.2550` |
| 19 | fluorine | 0.93 | 0.050 | `0.0465` | 3.364 | `3.1285` |
| 23 | sodium | 1.00 | 0.030 | `0.0300` | 2.983 | `2.9830` |
| 28 | silicon | 1.00 | 0.402 | `0.4020` | 4.295 | `4.2950` |
| 31 | phosphorus | 1.00 | 0.305 | `0.3050` | 4.147 | `4.1470` |
| 32 | sulfur | 1.00 | 0.274 | `0.2740` | 4.035 | `4.0350` |
| 35 | chlorine | 0.93 | 0.227 | `0.2111` | 3.947 | `3.6707` |
| 39 | potassium | 0.93 | 0.035 | `0.0326` | 3.812 | `3.5456` |
| 56 | iron | 1.00 | 0.013 | `0.0130` | 2.912 | `2.9120` |
| 80 | bromine | 0.93 | 0.251 | `0.2334` | 4.189 | `3.8957` |
| 127 | iodine | 0.93 | 0.339 | `0.3153` | 4.500 | `4.1850` |
| 133 | caesium | 0.93 | 0.045 | `0.0419` | 4.517 | `4.2008` |

All 32 literals reproduce `f · D_I` and `f · x_I`. The residual is the rounding
of these four-decimal literals and nothing else:

| factor | literal ÷ UFF, across every ε and σ that uses it |
|---|---|
| 0.43 | 0.42955 – 0.42997 |
| 0.93 | 0.92988 – 0.93143 |
| 1.00 | 1.00000 |
| 1.20 | 1.20000 |

The widest miss is potassium: 0.035 × 0.93 = 0.03255, written `0.0326`.

Three consequences worth stating.

**The buffer gas is unscaled UFF nitrogen.** `eogas=0.06900` and `rogas=3.6600`
are UFF's nitrogen row exactly, factor 1.00 — while the *ion's* own nitrogen
atoms take 1.20. That asymmetry is in the fitted parameterization, not a slip in
the code.

**Silicon settles chunk 3's merge for good.** `fcoord`'s silicon row is UFF
silicon exactly; `ncoord`'s 0.0130 / 2.9120, which the merge discarded, is UFF
**iron** exactly. The value adopted is the right one on independent grounds, not
merely on the grounds that published runs had used it.

**`conve` is approximate, and must stay that way.**

```
conve = 4.2d0 * 0.01036427
```

0.01036427 eV per kJ/mol is exact, but 4.2 kJ per kcal should be 4.184, so every
well depth in this table is uniformly high by a factor of
4.2 / 4.184 = 1.0038241 — 0.382 %. **Do not correct it.** It is inside every
nitrogen cross section this code has ever published, and inside the fitted
scaling factors above, which were obtained with it in place. `convr` alongside
it is 2⁻¹ᐟ⁶ = 0.890898718, converting UFF's `x_I` (a minimum-energy distance) to
a Lennard-Jones σ.

The single-precision literals are also load-bearing — see `CLAUDE.md`.

## `mobcal_He.f`: nine helium fits, and four that are not

The nine original rows are what their own comments say: hydrogen and carbon from
mobility fits, sodium from Viehland's Na⁺–He potential, and so on. Nothing in
this section applies to them. (Those same comments were copied into
`mobcal_N2.f` when its table was written, where they describe nothing; v1.1
replaced them there with the factors above.)

Chlorine, bromine, iodine and phosphorus, added in v1.1, are different. Each is
UFF `x_I` and `D_I` scaled by **0.80** and inserted directly as a He–X pair
parameter:

| key | element | ε in source | `0.80 · D_I · 43.360` | σ in source | `0.80 · x_I` |
|---|---|---|---|---|---|
| 35 | chlorine | `7.8742d-3` | 7.874176 | `3.1576` | 3.157600 |
| 80 | bromine | `8.7067d-3` | 8.706688 | `3.3512` | 3.351200 |
| 127 | iodine | `11.759d-3` | 11.759232 | `3.6000` | 3.600000 |
| 31 | phosphorus | `10.580d-3` | 10.579840 | `3.3176` | 3.317600 |

σ is exact to six digits in all four. ε matches to the five figures written,
using one conversion constant — the factor the three shipped halogen rows imply
is 43.36013, 43.36006 and 43.35914 meV per kcal/mol, against an exact 43.36410,
so the constant used was 43.360. Phosphorus was then built with that same
43.360, which is why its row appears in this table rather than deriving it.

**These four print a `PROVISIONAL` warning when used, for three reasons.**

1. They are X–X **self** parameters used as He–X **pair** parameters. The
   geometric-mean combining rule with the gas that `mobcal_N2.f` applies to the
   same UFF numbers is simply absent.
2. UFF's `x_I` goes into `rolj` — which the potential treats as σ — without the
   2⁻¹ᐟ⁶ conversion that `mobcal_N2.f` applies as `convr`, and that this file's
   own sodium row applies as `3.97d0/1.12246d0`. With it, iodine's σ would be
   3.207 Å rather than 3.600 Å.
3. The 0.80 factor is attested nowhere. References [1], [5] and [6] are all
   nitrogen studies; the reply that supplied the 0.93 / 1.20 / 0.43 / 1.00
   factors above describes the nitrogen table only and does not mention helium.

None of that makes them wrong — it makes them unverified in the gas they are
used in. The warning says so in the output file, once per atom that uses one.

### Phosphorus, added on that recipe

Phosphorus (31) has been in `mobcal_N2.f` since 2015 and was refused by
`mobcal_He.f` — there was no helium value and none was going to be guessed.
Once the construction above was identified it stopped being a guess and became
an application of the recipe the table's three newest rows already used, so
v1.1 added it:

```
eolj = 0.305 × 0.80 × 43.360 = 10.57984  ->  10.580d-3*xe
rolj = 4.147 × 0.80          =  3.3176   ->  3.3176d0*1.0d-10
rhs  =                          4.2      ->  4.2d0*1.0d-10
```

It carries the `PROVISIONAL` warning for the same three reasons as the
halogens, and the same caveat: **0.80 is undocumented, so this row is a
construction, not a measurement.** It is offered because refusing an element
the recipe covers serves nobody, not because it has been validated in helium —
none of these four has been, unlike the nine rows above them.

It does **not** carry the borrowed-hard-sphere-radius warning. Its 4.2 Å is
phosphorus's own value from `mobcal_N2.f`, which is sound because `rhs` is
gas-independent here — see below. That makes it the one row that trips one
warning and not the other, which is what lets `test/elements.sh` tell the two
apart by count rather than by presence.

Adding it bumped the helium parameter set from 2.0 to 2.1. Nitrogen's stayed at
2.0, which is the whole reason the two are versioned separately.

### An earlier claim, withdrawn

Through v1.1 chunk 4 this repository described these rows as `mobcal_N2.f`'s self
parameters "multiplied by one factor (0.8602 … ) that has no derivation in
either source". The comparison was against `mobcal_N2.f`'s literals, which are
themselves already scaled by 0.93. **0.80 / 0.93 = 0.8602.** The factor is 0.80,
it applies to UFF and not to the nitrogen table, and 0.8602 appears nowhere in
the parameterization.

## Hard-sphere radii

`rhs` is used only by the EHSS/PA calculation, which `mobcal_N2.f` does not
perform at all. It is **gas-independent in this code**: every element defined in
both files carries the same value in both.

| key | element | He | N2 |
|---|---|---|---|
| 1 | hydrogen | 2.2 | 2.2 |
| 7 | lithium | — | 2.7 |
| 12 | carbon | 2.7 | 2.7 |
| 14 | nitrogen | 2.7 | 2.7 |
| 16 | oxygen | 2.7 | 2.7 |
| 19 | fluorine | 2.7 | 2.7 |
| 23 | sodium | 2.853 | 2.853 |
| 28 | silicon | 2.95 | 2.95 |
| 31 | phosphorus | 4.2 | 4.2 |
| 32 | sulfur | 3.5 | 3.5 |
| 35 | chlorine | 2.7 | 2.7 |
| 39 | potassium | 2.7 | 2.7 |
| 56 | iron | 3.5 | 3.5 |
| 80 | bromine | 2.7 | 2.7 |
| 127 | iodine | 2.7 | 2.7 |
| 133 | caesium | 2.7 | 2.7 |

Nine of these are 2.7 Å, carbon's value. Three of the nine are legacy rows
(nitrogen, oxygen, fluorine) whose own comments have said "same as carbon" since
2012. The other six are the elements v1.1 added, which borrow it rather than
carrying a fitted value — and those six print a warning saying so.

The warning is keyed on **element identity, not on the value 2.7**. Keyed on the
value it would fire on nitrogen and oxygen, which `Choline.mfj` contains, and
force a reference regeneration for no reason. `test/elements.sh` counts both
warnings on a fixture holding legacy and new elements together, which is what
would catch that mistake.

It matters most for iodine, whose helium σ (3.60 Å) is *larger* than the
borrowed hard-sphere radius, so the hard sphere sits inside the Lennard-Jones
well. Harmless for the trajectory method, which never reads `rhs`; a real hazard
for EHSS/PA, which only helium computes.

## Atomic masses

The mass key (`nint` of atomic weight, looked up as `xmass(iatom)`) is a
four-figure atomic weight for every legacy row and for phosphorus. The six
elements v1.1 merged from Iain Campuzano's files carry the integer key itself
as the mass instead: chlorine 35.00 (35.45), bromine 80.00 (79.90), iodine
127.00 (126.90), lithium 7.00 (6.94), potassium 39.00 (39.10), caesium 133.00
(132.91). **This is deliberate.** Iain's distributed files carry the same
integers, and correcting them here would make this repository's numbers
disagree with his builds for exactly the ions these six rows were added to
describe.

The mass feeds the reduced mass μ = m1·m2/(m1+m2) (`mu` in COMMON
`constants`), which the trajectory integration and the cross-section-to-mobility
conversion both use directly, so the discrepancy reaches every reported value
for an ion carrying one of these six atoms. The cost is small. Worst case is a
light ion whose mass is essentially the one heavy atom — a bare iodine or
caesium cation, the small end of the CsI cluster series used as an ESI
calibrant is exactly this case for caesium. There, the integer key shifts μ by
+0.0024 % in helium / +0.014 % in nitrogen for iodine, and +0.0020 % / +0.012 %
for caesium; any additional atoms in a real molecule only dilute the fraction
further, since only the one atom's mass is wrong. That is well under the
uncertainty already carried by these same rows' provisional 0.80 scaling
factor (`mobcal_He.f`'s three halogens and phosphorus), and not worth breaking
agreement with the contributor's own files to correct.

## Adding an element

One row in `ljparm` per gas — `mobcal_He.f:714`, `mobcal_N2.f:721` — and one
entry in the `format 602` key list beside it. Then `test/elements.sh`, which
reads the parameters back out of the real subroutines rather than out of the
program's output, because for any coordinate set after the first they do not
appear in the output at all.

For nitrogen the recipe is settled: take UFF `x_I` and `D_I`, apply the factor
for that element's class, write four decimals. For helium there is no settled
recipe. The nine original rows came from fits nobody is repeating, and the 0.80
factor the four newer rows use is undocumented. **A helium element this table
does not define is refused, not guessed** — and a row added by extrapolating
0.80, as phosphorus was, is provisional by construction, which is what the
warning is for.

## References

Numbering matches `README.md`.

1. Campuzano, I. D. G.; Bush, M. F.; Robinson, C. V.; Beaumont, C.;
   Richardson, K.; Kim, H.; Kim, H. I. "Structural Characterization of Drug-like
   Compounds by Ion Mobility Mass Spectrometry: Comparison of Theoretical and
   Experimentally Derived Nitrogen Collision Cross-sections." *Anal. Chem.*
   **2012**, *84*, 1026-1033.
2. Mesleh, M. F.; Hunter, J. M.; Shvartsburg, A. A.; Schatz, G. C.; Jarrold,
   M. F. "Structural Information from Ion Mobility Measurements: Effects of the
   Long Range Potential." *J. Phys. Chem.* **1996**, *100*, 16082-16086.
3. Kim, H.; Kim, H. I.; Johnson, P. V.; Beegle, L. W.; Beauchamp, J. L.;
   Goddard, W. A.; Kanik, I. "Experimental and theoretical investigation into
   the correlation between mass and ion mobility for choline and other ammonium
   cations in N2." *Anal. Chem.* **2008**, *80*, 1928-1936.
4. Rappé, A. K.; Casewit, C. J.; Colwell, K. S.; Goddard, W. A., III; Skiff,
   W. M. "UFF, a Full Periodic Table Force Field for Molecular Mechanics and
   Molecular Dynamics Simulations." *J. Am. Chem. Soc.* **1992**, *114*,
   10024-10035.
5. Lalli, P. M.; Corilo, Y. E.; Fasciotti, M.; Riccio, M. F.; de Sa, G. F.;
   Daroda, R. J.; Souza, G. H. M. F.; McCullagh, M.; Bartberger, M. D.;
   Eberlin, M. N.; Campuzano, I. D. G. "Baseline resolution of isomers by
   traveling wave ion mobility mass spectrometry: investigating the effects of
   polarizable drift gases and ionic charge distribution." *J. Mass Spectrom.*
   **2013**, *48*, 989-997.
6. Flick, T. G.; Campuzano, I. D. G.; Bartberger, M. D. "Structural Resolution
   of 4-Substituted Proline Diastereomers with Ion Mobility Spectrometry via
   Alkali Metal Ion Cationization." *Anal. Chem.* **2015**, *87*, 3300-3307.
