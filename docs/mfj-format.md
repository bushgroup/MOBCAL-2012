# The `.mfj` input format

This is a precise description of the file `mobcal.in` names as its input —
`Choline.mfj` is the shipped example. It is read by `fcoord`
(`mobcal_He.f:494`, `mobcal_N2.f:497`), which serves the first coordinate
set, and by `ncoord` (`mobcal_He.f:2723`, `mobcal_N2.f:2894`), which serves
every coordinate set after the first. The two subroutines mostly agree, but
one disagreement — in `mobcal_N2.f` only — will silently change your answer
if you don't know about it; see *Charge modes* below.

There is no format version number and no comment syntax. Every line means
something by position alone.

## Line-by-line grammar

```
line 1:  label                      (free text, up to 30 columns)
line 2:  icoord                     (number of coordinate sets)
line 3:  inatom                     (number of atoms, same for every set)
line 4:  ang | au                   (coordinate units)
line 5:  equal | calc | none        (charge distribution mode)
line 6:  correct                    (geometry scale factor, usually 1.0000)
line 7:  x y z mass [charge]        (one line per atom, inatom lines)
  ...
line 7+inatom:                      (last atom of coordinate set 1)
[if icoord > 1:]
  one throwaway line                (see Conformer blocks)
  x y z mass [charge]  x inatom     (coordinate set 2)
  ...                               (repeat for sets 3..icoord)
```

Lines 1, 4 and 5 are read with a fixed-width `a30` edit descriptor
(`mobcal_He.f:518,567-568`), not list-directed. That means:

- **Leading whitespace is significant.** `' ang'` is not equal to `'ang'` —
  Fortran character comparison blank-pads the *shorter* string, it does not
  trim the longer one. A stray leading space on line 4 or line 5 makes the
  unit or charge-mode check fail silently into the generic refusal (`units
  not specified` / `charge distribution not specified`,
  `mobcal_He.f:589-595,607-614`). Since v1.2 that refusal reaches the console
  and exits 1; through v1.1 it was a bare `stop`, printing nothing to the
  terminal and exiting 0. If an older run "does nothing" and the output file
  is only a few lines long, check for a leading space first.
- **Content past column 30 is discarded**, not an error. Keep the label
  short.

Lines 2, 3 and 6, and every atom line, are read list-directed (`read(9,*)
...`), so ordinary whitespace-separated numbers are fine and column
alignment doesn't matter — `Choline.mfj`'s right-justified columns are a
convention, not a requirement.

## The element key is a lookup, not a mass

The fourth field on each atom line is read into a real variable, then
immediately replaced: `imass(iatom)=nint(ximass)` (`mobcal_He.f:610`,
`mobcal_N2.f:613`/`2925`). That integer is looked up in the per-element table
(`ljparm`, `mobcal_He.f:714`, `mobcal_N2.f:721`), and it is the table's
value — not the number you wrote — that becomes the atom's actual mass for
every subsequent calculation, including the `mass of ion` line and the
reduced-mass constant `mu`. Two consequences:

- **The column is conventionally the integer atomic weight** (12 for carbon,
  35 for chlorine, ...), because `nint(atomic weight)` is the convention the
  table itself was built against — see the *Supported elements* table in
  `README.md` for the keys each gas defines. Writing anything else that
  happens to round to a defined key silently selects that element instead of
  refusing.
- **A specific isotope cannot be represented.** Writing `2.014` for a
  deuteron rounds to key `2`, which is not a defined key in either table, so
  the run is refused with `type not defined for atom number ... (mass key
  2)` rather than run with deuterium's mass. There is currently no way to
  give an atom a mass that isn't one of the table's own values.

An unrecognized key names the atom, the key, the `nint(atomic weight)`
convention, and the full list of keys the build defines (`mobcal_He.f:888-896`,
format 602) — that message is generated from the build's actual table, so it
can't drift out of sync with what the code accepts.

## Units

Line 4 must be exactly `ang` or `au`. `au` coordinates are converted to
angstroms by multiplying by `0.52917706` (`mobcal_He.f:612-614`,
`mobcal_N2.f:615-617`) — a Bohr radius in angstroms, hardcoded at the
precision the code shipped with rather than looked up from a current
constants table. Not the same last digit as the present CODATA value; that
is provenance, not a bug, and correcting it would be a physics-affecting
change out of scope for documentation. Conversion happens before centering
and before the correction factor is applied.

## The correction factor

Line 6 multiplies every centered coordinate: `fx=(fx-fxo)*1.d-10*correct`
(`mobcal_He.f:666-668`). It is applied after centering on the mass-weighted
center of mass and after the unit conversion, so it scales the whole
structure uniformly around its own center of mass. `1.0000` (no correction)
is what every shipped fixture uses.

## Charge modes

Line 5 selects one of three values. The charge column (5th field on each
atom line) is only ever *read* when the mode is `calc` — except that
`mobcal_N2.f`'s `fcoord` reads it unconditionally, described below.

| mode | what each atom's charge becomes |
|---|---|
| `calc` | exactly the 5th field you supply, per atom |
| `equal` | the same value for every atom (see below — the two gases disagree on *which* value) |
| `none` | `0.d0` for every atom; only the Lennard-Jones part of the potential is used |

**`equal` means a different total charge in the two gases.** In
`mobcal_He.f`, `equal` mode reads only 4 columns per atom line
(`mobcal_He.f:602-609`) and sets every atom to `1.d0/inatom`
(`mobcal_He.f:618-621`) — the 5th column, if present, is never touched.
In `mobcal_N2.f`, the `if(dchar.eq.'calc')` branch that would skip the
charge column is commented out (`mobcal_N2.f:605,610-612` — dead code, left
as found), so **`fcoord` always reads 5 columns, in every charge mode**, sums
them into `tcharge`, and `equal` mode sets every atom to
`tcharge/dfloat(inatom)` (`mobcal_N2.f:621-625`) — the *sum of whatever is in
your charge column*, divided evenly, not a hardcoded `1/inatom`. Two
consequences:

- A 4-column `equal`-mode file that works in `mobcal_He.f` will hit
  end-of-record trying to read a 5th field in `mobcal_N2.f`'s first
  coordinate set.
- A 5-column `equal`-mode file that puts `0` in every charge field — a
  reasonable guess if you think the column is ignored, since it is in
  helium — silently gives **every atom zero charge** in nitrogen, because
  `tcharge` sums to zero.

**The safe, portable choice: always write 5 columns, with charge values that
sum to the net ionic charge you intend** (`1.0000` split however you like
across the atoms is fine for `equal` mode; a real per-atom partial-charge
distribution for `calc`). Fortran list-directed reads discard any unread
values left on a record before starting the next `READ` at a new line, so a
5-column line is never wrong for a 4-column read: the extra field is simply
skipped, not misread onto the next atom. Writing 5 columns unconditionally is
therefore both correct for `mobcal_He.f` and required for `mobcal_N2.f`'s
first coordinate set, and it removes the silent total-charge trap above.

`ncoord`, unlike `fcoord`, honors the `dchar` branch correctly in **both**
gases (`mobcal_He.f:2748-2753`, `mobcal_N2.f:2918-2924`) — it is only
`mobcal_N2.f`'s `fcoord`, serving coordinate set 1, that is asymmetric with
its own `ncoord`. `equal`/`none` mode conformers 2..`icoord` therefore parse
correctly in nitrogen even with a 4-column line — but writing 5 columns on
every line, every conformer, sidesteps having to remember which routine
reads which set.

`none` mode never prints a total-charge line in `mobcal_N2.f`
(`mobcal_N2.f:633`, `dchar.ne.'none'`) but only `calc` does in
`mobcal_He.f` (`mobcal_He.f:628`) — a minor output difference, not a parsing
trap, listed here for completeness.

## Conformer blocks

If `icoord` > 1, each coordinate set after the first is preceded by exactly
**one throwaway line**, read and discarded (`read(9,'(a30)',end=100) dummy`,
`mobcal_He.f:2744`, `mobcal_N2.f:2915`). The main program's own header
comment calls this "a blank line", but the code doesn't check its content at
all — any single line works as the separator, including a non-blank label.
`test/silicon-2conf.mfj` uses `conformer 2 -- deliberately identical to
conformer 1` as that line, for exactly this reason: it documents the file
while proving the separator need not be blank.

Every coordinate set in a file must declare the same `inatom` — there is one
atom count on line 3, used for every set — and the atoms are matched by
position, not re-identified, so set 2's atom 5 must be the same physical atom
as set 1's atom 5 for the mass-conservation check (`masses do not add up`,
`mobcal_N2.f:2939-2944`) to pass.

## Worked example

`Choline.mfj`, annotated:

```
Choline_631G++dp_pop      label (free text)
1                         icoord: one coordinate set
21                        inatom: 21 atoms, every set
ang                       coordinates in angstroms
calc                      per-atom partial charges follow
1.0000                    no geometry correction
     -0.87800  0.02200  0.00000  14  -.021059   <- N, key 14, charge -0.021059
     -1.83400  1.19400 -0.00800  12  -.439073   <- C, key 12
      ...
      3.63300 -0.15400  0.00000   1   .463592   <- H, key 1, last of 21 atoms
```

The five leading columns are x, y, z (ångström), the integer mass key, and
the per-atom partial charge — read list-directed, so the wide fixed columns
here are cosmetic.

## The two array bounds

`inatom` and `icoord` are checked against the compiled-in limits before any
atom is read (`mobcal_He.f:536-547,555-566`) — 1,000 atoms, 100 coordinate
sets by default, both in `mobcal_limits.inc`. An input over either limit is
refused by name; see *Size limits* in `README.md`.

## See also

+ `README.md`'s *Supported elements* — the keys each gas's table defines,
  and which of the new v1.1 elements are provisional.
+ `docs/parameters.md` — where the Lennard-Jones and hard-sphere
  parameters behind each of those keys came from, and the arithmetic to
  re-derive them.
+ `docs/getting-started.md` — the short original guide this format
  description grew out of.
+ `tools/xyz2mfj.py` — an optional, dependency-free converter from plain XYZ
  coordinates to a `.mfj` file that follows the safe 5-column convention
  above.
