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

## The four gates

```sh
sh test/regression.sh              # both gases -- minutes for he, ~1 h for n2
sh test/bounds.sh                  # both gases -- seconds
sh test/elements.sh                # both gases -- seconds
sh test/refusals.sh                # both gases -- seconds
```

`test/regression.sh` is the physics gate: one valid input, compared against
committed reference outputs. `test/bounds.sh` is the safety gate: three inputs
whose expected result is a refusal, so there is nothing to compare against and
nothing that runs long. `test/elements.sh` is the parameter gate: it links a
probe against the real `fcoord` and `ncoord` and reads out what the element
table actually set, which is the one thing no amount of comparing output files
can show. `test/refusals.sh` is the exit-status gate: it drives every
termination a small input can reach and requires each to exit nonzero, and it
reads the source itself to require that the normal end of the main program is
the only bare `stop` left.

They are separate scripts because those are four different shapes, and they
share one build recipe — `test/build-flags.sh`, described under *Building*
below. Two of them also share one test driver, `test/probe-driver.sh`. CI runs
the three fast ones first, since a broken build or a broken guard should not
cost an hour of n2 to discover.

## The regression gate

```sh
sh test/regression.sh              # both gases
sh test/regression.sh --gas he     # one gas
sh test/regression.sh --keep       # keep test/_work to inspect the diffs
```

It builds both sources, runs `Choline.mfj` at the seed recorded in the reference
outputs, and reports three tiers. `.github/workflows/ci.yml` runs this script,
`test/bounds.sh`, `test/elements.sh` and `test/refusals.sh` on ubuntu, macos and
windows, one job per (platform, gas) pair.

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
| **boundary** exactly `lcoord` and `len` | both counts accepted; no `ERROR`; execution reaches the pre-existing charge-distribution refusal, and exits nonzero |

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

**The boundary case asserted exit status 0 until v1.2, and that was not a
typo.** A bare Fortran `stop` exits 0, and every refusal this code shipped with
was one — eight terminations in `mobcal_He.f`, including `units not specified`,
`charge distribution not specified` and `type not defined for atom number`, all
of them reporting success to their caller. The two bound refusals added in v1.1
used `call exit(1)` instead, because a refusal a script cannot detect is not
much of a refusal, and the older ones were deliberately left alone: making them
consistent was worth doing on its own terms rather than as a side effect of the
bound check.

v1.2 did it. The boundary case now asserts nonzero, because the
charge-distribution refusal it lands on is one of the converted ones. Nothing
else about the case changed — it is still evidence that neither bound guard
fired one early, and the refusal it lands on is still the same refusal printing
the same message. *The exit-status gate*, below, is where that conversion is
actually gated.

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

**Since v1.2 the stripping and the driver live in `test/probe-driver.sh`**,
because `test/refusals.sh` needs the same thing to reach `ncoord`'s `masses do
not add up` without paying for the previous conformer's whole calculation. Two
copies of a driver is how a driver drifts — the argument that put the build
recipe in `test/build-flags.sh`. The one line of the driver that differs
between the gases, the `common/constants/` continuation, is still lifted from
the source under test rather than written down.

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

**Chunk 4 added a second pair of fixtures**, `test/new-elements-he.mfj` and
`test/new-elements-n2.mfj`, rather than growing `test/silicon-2conf.mfj`.
Helium does not define lithium, potassium or caesium at all, so a fixture
shared between both gases would refuse on helium before reaching any
assertion. Each new fixture carries the legacy carbon/nitrogen/oxygen/fluorine
rows alongside the new elements specifically so the two chunk-4 warnings can
be asserted by *count* rather than by presence: nitrogen, oxygen and fluorine
already borrow carbon's 2.7 Å hard-sphere radius, so a warning that fired on
that value rather than on element identity would still pass a check that only
asked "did it fire" — see *Chunk 4* below for the full reasoning.

**Since v1.3 the gate reads the table, so a row no fixture contains is no
longer a row no gate reads.** The three fixtures above reach four of thirteen
helium rows and ten of sixteen nitrogen rows. The gate now also generates a
fixture with one atom per row of `mobcal_<gas>.params`, in file order, probes
it, and compares every row's well depth, radius and hard-sphere radius as the
program holds them against the file's values evaluated by the form the file
declares, in awk, within the same 1e-4. It compares the printed `mass of ion`
with the sum of the file's masses (the one per-atom quantity the probe cannot
dump, `xmass` being `fcoord`-local), the two warning counts with the file's own
flag columns, and the key list in the undefined-element refusal — written from
the loaded table since v1.3 — with the file's keys in order, which is the claim
v1.2 withdrew as ungated when the list was a string. The source check changed
shape with it: no `imass(iatom).eq.<key>` comparison may survive in either
source, and the reader must be included exactly once. And silicon's well depth
is pinned to 16 digits in both gases, which is what sees the reader's kind rule
(*The element tables are files*). Verified by mutation, eight cases, each
failing where it should and nowhere else.

## The exit-status gate

```sh
sh test/refusals.sh                # both gases -- seconds
sh test/refusals.sh --gas n2       # one gas
sh test/refusals.sh --keep         # keep test/_refusals to read the outputs
```

A bare Fortran `stop` exits 0. Until v1.2 every termination in both sources was
one, except the two array-bound refusals v1.1 added, so a run that refused its
input and a run that computed a cross section were indistinguishable to the
caller. v1.2 converted the rest; this gate is what keeps them converted. Run
against the v1.1 sources it fails 23 of its 50 assertions.

**The classification was the work, not the conversion.** `mobcal_He.f` has
eight terminations and `mobcal_N2.f` seven, and they are three different kinds
of thing:

| Where | What | Kind |
|---|---|---|
| main program | the normal end | exits 0, and must keep doing so |
| `fcoord` | `units not specified` | refusal, before any arithmetic |
| `fcoord` | `charge distribution not specified` | refusal, before any arithmetic |
| `ljparm` | `type not defined for atom number` | refusal, before any arithmetic |
| `ncoord` | `masses do not add up` | refusal, but reached late — see below |
| `gsang` | the `ifail` cap | failure, mid-calculation; He only |
| `mobil2` | `Problem orientating along x axis` | failure, mid-calculation |
| `mobil2` | `ibst greater than 500` | failure, mid-calculation |

`mobcal_N2.f`'s energy-conservation block is commented out in the source as it
shipped, which is why that file has seven and not eight. The gate asserts that
it is *still* commented out rather than quietly running one case fewer there.

v1.3 added a family in `ljread` (`mobcal_ljread.inc`): the parameter file
missing, for the other gas, or malformed. All `call exit(1)`, all echoed to
unit 6, all before the banner. The gate drives three of them through the real
binary plus a control that gets past `ljread` by a relative 4th-line path, and
its static check also reads the include, where no bare `stop` may appear.

Five things about this that are easy to get wrong:

**The `ifail` cap is the case that justifies the change.** It sits in `gsang`,
reached from `mobil2`'s impact-parameter search — and `mobil2` runs after
`mobil4` has already written a PA and an EHS cross section to the output file.
Measured on a water-sized fixture, pre-change: 0.87 s, 100 non-conserving
trajectories, `average PA cross section = 2.4573E+01` and `average EHS cross
section = 2.4582E+01` in the format a real run prints them, zero bytes on the
console, exit 0. That is the hazard *The array-bound gate* describes for the
unguarded bound, still live in a guarded build. The only thing in the output
file that marks those numbers as belonging to an abandoned run is the *absence*
of a SUMMARY block, which is what `README.md` *Exit status* tells anyone
auditing pre-v1.2 files to look for, and which the gate asserts.

**Two of the eight are not drivable, and the static check is what covers
them.** `Problem orientating along x axis` fires only if a rotation fails to
put the longest axis on x, and `ibst greater than 500` only if the
impact-parameter search has not converged after 500 steps; neither is reachable
by any small input. They were converted with the rest — a failure reporting
success is the defect, and whose fault the failure is does not change that —
and the gate covers them by reading the source instead: exactly one bare `stop`
may survive per file, and its line number must be below the first `subroutine`,
which is to say inside the main program. Verified by mutation: reverting the
orientation site alone fails exactly those two assertions and nothing else.

**`masses do not add up` costs a whole conformer through the real binary, so it
goes through the probe.** `ncoord` is called from the main loop only after
`mobil4` and `mobil2` have both finished on the conformer before it, and there
is no cheap conformer: the trajectory counts are hardcoded, and an ion small
enough to be quick is an ion whose trajectories stop conserving energy — which
lands on the `ifail` cap instead. Measured, the smallest fixture that gets
through conformer 1 at all is methane, at 61 s on He and 14 minutes on N2. So
that one case calls the real `fcoord` and the real `ncoord` through
`test/probe-driver.sh` in milliseconds, and it carries a control: the same
fixture with the composition left alone must get through and dump both sets,
because a guard that refused *every* multi-conformer file would satisfy the
refusal assertions perfectly.

**Every converted site also echoes to unit 6, and that is asserted
separately.** A refusal that reaches only the output file is invisible to
anyone running a batch and watching a terminal. The message texts are otherwise
untouched — in particular no `ERROR:` prefix was added to the older ones, which
is what keeps the boundary case's `absent 'ERROR'` assertion meaning what it
meant. Verified by mutation: dropping one `write(6,...)` fails exactly one
assertion, and no exit-status assertion moves.

**The `ifail` case depends on trajectory arithmetic, which is admissible here
for the same reason T3 is.** This code is byte-reproducible across the
platforms in `test/strict-platforms`, so "the hundredth trajectory fails" is as
portable a fact as any number it prints. If a platform ever disagrees this
fails loudly, which is the right outcome: it would mean T3's premise had
changed.

## The element tables are files

Since v1.3 there is no element table in either source. `mobcal_He.params` and
`mobcal_N2.params` hold the rows; `mobcal_ljread.inc` holds the one reader,
included by both sources after their last program unit; `ljparm` in each source
looks a mass key up in the loaded table and applies the row. `docs/parameters.md`
documents the format for users. What follows is what a contributor must not get
wrong.

**The spelling of a literal is its precision, and the reader honours it.**
`mobcal_N2.f` multiplied a double by single-precision literals
(`dsqrt(eogas*0.4020)`) and `mobcal_He.f` used double literals throughout
(`1.3266d-3*xe`), so the two tables need two kinds of read. Measured before the
format was chosen, with every literal compiled under the gate flags and read
back from text: the 32 nitrogen literals reproduce the compiled bit pattern
32/32 when read into a REAL(4) and promoted, 0/32 when read into a REAL(8); the
26 helium literals 26/26 as REAL(8), 4/26 as REAL(4). So `ljnum` reads a token
with a `d` as a REAL(8) and a token without one as a REAL(4), the files carry
every literal exactly as the Fortran did, and nothing in either file has been
"tidied" to `d0`. `test/elements.sh` pins silicon's well depth to 16 digits in
both gases for exactly this: read `0.4020` as a double and the nitrogen value
moves in the eighth digit; read `1.35d-3` as a single and the helium value does.
Verified by mutation: reading everything as a double fails nitrogen's pin and
nothing else (`7.249792566886474E-03` for `7.249792657180476E-03`); reading
everything as a single fails helium's (`1.350000035017729E-03`) and nitrogen's
as well, through the `d0` header constants its combining rule uses.

**The reader stops one factor short, and `ljparm` finishes the expression.** The
compiled expressions were `dsqrt(eogas*0.4020)*conve*xe` and `3.0126d0*1.0d-10`,
evaluated left to right. `ljread` stores `dsqrt(eogas*e)*conve` (or the bare
literal, for the pair form) in `teps`, and `ljparm` multiplies by `xe` per atom;
likewise `tsig` and `1.0d-10`. Same operations in the same order, so the same
double. Do not fold the final factor into the table.

**Two files with different forms, one reader.** The helium file is `form: pair`
(He–X pair parameters used as they stand), the nitrogen file `form: combining`
(X–X self parameters through the geometric-mean rule, with `eogas`, `rogas`,
`conve` and `convr` in its header — `conve: 4.2d0*0.01036427d0`, still 0.382 %
high, still not to be corrected). The reader applies the form the file declares
and refuses a file whose `gas:` is not the binary's. Chunk 3's argument against
one subroutine — that merging the tables would invent a conversion — does not
apply to a reader that does what the file says: a helium binary handed the
nitrogen file is refused, not converted.

**Tokens are split by hand.** A `/` ends a list-directed record and a `,` splits
one, and a row's provenance text can contain anything, so `ljtok` finds
blank-delimited tokens and `ljnum` converts each with an internal read of that
token alone, after rejecting any character a literal cannot contain — a
list-directed read would take `1.0x` as `1.0`. One `/` or `*` is allowed inside
a token, for sodium's `3.97d0/1.12246d0` and for `conve`.

**The two warnings are flags in the file, not element identities in the code.**
`lj` is `fitted` or `provisional` (format 603), `rhs` is `own` or `borrowed`
(format 604). The legacy nitrogen, oxygen and fluorine rows are `own` although
their 2.7 Å is carbon's, because they never warned and choline must not start
to; the history is in their provenance text. `test/elements.sh` still pins the
counts v1.1 decided (He 8/6, N2 0/12) *and* now checks the program's counts
against the file's own flag columns, so editing a flag moves one of the two.

**Loader refusals precede the banner, and that is the one place the banner does
not come first.** The banner's second half is the file's `set:` string. So a
missing, wrong-gas or malformed file produces an output file that starts with
the refusal. Every other refusal still has the banner above it, and
`test/refusals.sh` asserts both.

**The gates copy the file into their run directories and use the default
lookup.** A POSIX `$ROOT` path in the 4th line of `mobcal.in` is not one a
native Windows binary can open — measured, on the first attempt to write the
wrong-gas case with an absolute path. `test/refusals.sh` exercises the 4th line
with a relative path instead.

**Byte identity was established row by row, not only on choline.** Before the
Fortran table was deleted, a probe built from the v1.2 sources and one built
from the file-backed sources dumped `eolj`, `rolj` and `rhs` as IEEE hex for
every row of both files, on the three committed fixtures and on a generated
one-atom-per-row fixture: identical, all 58 parameters, both gases. Then the
regression gate, both gases, T3 byte-identical.

## The one element table (v1.1 to v1.2)

Chunk 3 made the table `ljparm` — one per source file, called by `fcoord` and by
`ncoord` — so that adding, removing or editing an element row meant editing
exactly one place per gas. v1.3 moved the rows out of the Fortran altogether;
the reasoning below is kept because the merge history and the hazards it
records are still the history of the numbers now in the two files.

**It was one subroutine per file, not one shared between the two files, and that
was not an oversight.** The two tables hold different quantities. `mobcal_He.f`
held He–X *pair* parameters directly (`eolj(iatom)=1.3266d-3*xe`).
`mobcal_N2.f` held X–X *self* parameters that pass through a combining rule
with the gas (`dsqrt(eogas*0.0977)*conve*xe`). Merging them would have required
inventing a conversion that does not exist in either source.

`docs/parameters.md` derives every parameter in both tables and is the place to
look before changing a number. The load-bearing result, established after Iain
Campuzano supplied the provenance in August 2026: **`mobcal_N2.f`'s table is
Rappé's UFF throughout.** All 32 literals are `x_I` and `D_I` times one factor
per element — 0.43 hydrogen, 1.20 nitrogen, 0.93 carbon/oxygen/fluorine/the
halogens/potassium/caesium, 1.00 for lithium, sodium, silicon, phosphorus,
sulfur and iron — to five significant figures, the residual being the rounding
of the four-decimal literals. `mobcal_He.f`'s nine legacy rows are *not* UFF;
they are direct helium mobility fits, and the three added in v1.1 are UFF
scaled by 0.80. Two facts follow that are worth knowing here rather than
there:

+ **The per-row provenance comments in `mobcal_N2.f` were about the wrong
  file.** "from fitting C60 mobility", the Viehland note on sodium, "from
  fitting mobilities of small silicon clusters", every "(same as carbon)" and
  "(same as silicon)" — all copied from `mobcal_He.f` when the nitrogen table
  was written, where they are correct, and describing nothing once the row
  became a scaled UFF value. Each now names the factor applied; the Viehland
  paragraph is kept verbatim and attributed to the helium file. `mobcal_He.f`
  keeps its originals except fluorine's, which claimed carbon and is a
  verbatim copy of oxygen.
+ **`conve` is 0.382 % high and must stay so.** `conve=(4.2d0*0.01036427)`
  writes 4.2 kJ per kcal where the figure is 4.184; 0.01036427 eV per kJ/mol is
  exact. So every well depth in that table is uniformly high by 4.2/4.184 =
  1.0038241. It is inside every published nitrogen result *and* inside the
  scaling factors above, which were fitted with it in place. Same class of
  hazard as the single-precision literals below: a correct-looking correction
  that moves published output.

Four things to know before editing it:

**The single-precision literals are load-bearing.** `dsqrt(eogas*0.4020)`
multiplies a double by a REAL(4) literal, so `0.4020` is rounded to single
precision before the multiply. Writing it `0.4020d0` is a different number in
the eighth digit and moves published output. Rows are copied verbatim. The rule
survives the move to `mobcal_N2.params` unchanged, because the reader reads
`0.4020` as a REAL(4) — see *The element tables are files* above.

**`eogas`, `rogas`, `conve` and `convr` belong to the subroutine now.** In
`mobcal_N2.f` they were four plain locals assigned *inside* the per-atom loop,
once per atom, in both copies of the table — eight lines of duplication on top
of the table's own. They are in no COMMON block, so the shared subroutine had to
either own them or receive them; it owns them, hoisted out of the loop, stated
once. Since v1.3 they are four header lines of `mobcal_N2.params`, still stated
once.

**The `type not defined for atom number` refusal moved with the rows.** It is
the `itest.eq.0` arm and it is inseparable from the `itest` mechanism, so there
is now one copy of it per file rather than two. It is otherwise untouched —
format 602 still uses `i3` and still truncates above 999 atoms, and it is still
one of the eight bare `stop`s that exit 0. (Chunk 4 then widened it to `i4`,
v1.2 made it exit 1, and v1.3 made its key list a write from the loaded table
rather than a hardcoded string.)

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

**And the UFF derivation settles it independently.** `fcoord`'s 0.4020 / 4.2950
is UFF silicon exactly (0.402 / 4.295, factor 1.00). `ncoord`'s 0.0130 / 2.9120
is UFF **iron** exactly. The row chosen was right on its own terms, not merely
right because published runs had used it — which is a stronger position than
the one chunk 3 could argue from.

**The four commented-out alternate parameter pairs were kept.** `fcoord` in
`mobcal_N2.f` carried eight commented-out lines — an alternate `eolj`/`rolj`
pair for carbon, nitrogen, oxygen and sulfur, e.g.

```
c      eolj(iatom)=0.139373598*xe
c      rolj(iatom)=3.85949064*0.890898718*1.0d-10
```

— that `ncoord` did not. They are dead code, but they are the only surviving
record of a different, non-combining parameterization, and a merge is the wrong
moment to lose provenance. They lived in `ljparm` through v1.2, still commented
out, and are `#` lines under their rows in `mobcal_N2.params` now.

## Chunk 4 -- new elements, and two warnings

`ljparm` gained twelve rows total across the two files: chlorine (35),
bromine (80) and iodine (127) in both `mobcal_He.f` and `mobcal_N2.f`, plus
lithium (7), potassium (39) and caesium (133) in `mobcal_N2.f` only. Rows
came from Iain Campuzano's `mobcal_He_moreatoms.f` and
`mobcal_n2_093COFClBrIKCs_1Li_12N_043H.f`, taken from the first of each
file's two (pre-chunk-3) table copies -- verified to agree with the second
copy on every one of these keys, so unlike silicon this merge carries no
latent divergence. `mobcal_He.f` now defines 12 keys, `mobcal_N2.f` 16.
Through v1.2 `grep -c '^ *itest=1$'` was the check that a stray second copy had
not crept back in; since v1.3, with no rows in the source, `test/elements.sh`
requires that no `imass(iatom).eq.<key>` comparison survives there at all.

Two things about the new rows are not visible in a normal run's output, so
each gets a warning `ljparm` prints (to unit 8, i.e. into the `.out` file)
whenever an atom actually uses one:

- **The three helium halogens are provisional.** They are not fits to helium
  mobility data. Each is UFF `x_I` and `D_I` scaled by 0.80 -- sigma exact to
  six digits, epsilon to the five figures written, at 43.360 meV per kcal/mol
  -- and inserted directly as a He-X *pair* parameter. Two steps
  `mobcal_N2.f` applies to the same UFF numbers are skipped: the
  geometric-mean combining rule with the gas, and the r_min-to-sigma factor
  2^(-1/6) it applies as `convr` (with it, iodine's sigma would be 3.207 rather
  than 3.600 Angstrom). And the 0.80 is attested in none of the three papers
  cited for these parameters, all of which are nitrogen studies. The nitrogen
  halogens, and nitrogen's three alkali metals, are fitted the same way as
  every other row in that table and carry no such warning.

  **This entry read "0.8602" through chunk 4, and that was wrong.** The
  comparison was against `mobcal_N2.f`'s literals, which are themselves
  already scaled by 0.93; 0.80/0.93 = 0.8602. The factor is 0.80 and it
  applies to UFF. Nothing about the *code* changed when this was corrected --
  the warning fires on exactly the same rows for exactly the same reason -- but
  a repository that states a derived quantity as if it were fundamental has
  mislabelled its own evidence, and every later argument that leaned on
  "no derivation in either source" inherited that.
- **All six new elements, in whichever file they appear, borrow carbon's
  2.7 Angstrom hard-sphere radius.** For iodine that radius is *smaller* than
  its own Lennard-Jones sigma (3.60 Angstrom in helium), so the hard sphere
  sits inside the LJ well -- harmless for the trajectory method, which never
  uses `rhs`, but a real hazard for EHSS/PA (which `mobcal_N2.f` does not
  compute at all, so it can only bite in helium).

Both warnings are scoped to element identity, not to the value 2.7 --
nitrogen, oxygen and fluorine already carry that same borrowed radius under
their own decades-old "(same as carbon)" comments, and choline contains
nitrogen and oxygen. A warning keyed on the value would have fired on the
committed `Choline.mfj` fixture and forced an unplanned reference
regeneration; `test/elements.sh` counts occurrences on a fixture that
deliberately contains both the legacy and the new elements, which is what
would catch that mistake if it were made.

The `type not defined for atom number` refusal (format 602, the `itest.eq.0`
arm) was rewritten in the same commit: it now names the mass key that was
given, states the `nint(atomic weight)` convention, and lists the keys the
build actually defines, using `i4` rather than `i3` so a refusal past atom
999 -- this build's own array bound -- prints the real number instead of an
overflowed one. `test/elements.sh` generates a throwaway 1,000-atom fixture
to exercise exactly that, the same way `test/bounds.sh` generates its
over-bound fixtures rather than committing them.

Left alone, deliberately: phosphorus is still absent from helium (present in
nitrogen since 2015) -- refused rather than guessed, on the same reasoning as
silicon's fluorine/sulfur neighbours in chunk 3. (Chunk 9 added it, once chunk
8 had identified the construction the helium halogens use. The reasoning that
kept it out here is still the reasoning that labels it provisional there.) The
integer masses
(chlorine 35.00 vs. 35.45, etc.), the `q1st` divisor, and the version strings
are chunk 5's, not this one's -- taking any of them here would have meant
regenerating `sample-output/` outside the one commit the plan reserves for
that.

## Chunk 5 -- the two output changes, and the one regeneration

Chunk 5 is the only commit in v1.1 that moves a line in `sample-output/`. It
carries exactly two output changes, done together so the fixtures are
regenerated once.

**The version banner.** Every run now opens with one line naming the build and
the table it used, and the SUMMARY repeats both:

```
 MOBCAL 1.1 (mobcal_He.f), He parameter set 2.0
```

`mobcal_version.inc` holds the code version and nothing else. The
**parameter-set version is deliberately not in it** -- it is a `parameter` in
each main program instead, next to the write that prints it. The two tables are
different quantities revised on different schedules (chunk 3 corrected silicon in
nitrogen only; chunk 4 added three elements to helium and six to nitrogen), and
one shared constant would force a bump in the table that did not change. The code
version is shared because the opposite hazard applies to it: two files claiming
different code versions is precisely the class of defect chunks 2 and 3 spent
their time removing.

Both are `character*(*)` named constants, so `a` prints them with no trailing
blanks and a longer string needs no declaration edit. They are printed from the
main program, immediately after `open (8,...)` -- before `fcoord` is called, so
the banner precedes even a refusal.

**The `q1st` divisor.** `q1st(ig)` is summed once per complete cycle, inside the
`ic` loop, so it holds `itn` terms; each term is already the mean over the `imp`
random points. It was printed divided by `inp`, the bound of the *printing*
loop. At the shipped `itn=10`/`inp=40` every value in that column was four times
too small. It is a print bug and nothing more -- `q1st` is never read back, and
`om11st`, the cross sections and the standard deviation accumulate separately.
The identity that settles it is in the file itself. `om11st` is
`sum(wgst(ig)*temp1(ig))` over the same terms, so the cycle-averaged column has
to satisfy `sum(wgst*q1st) = mean OMEGA*(1,1)`. On the regenerated helium
reference it does, to every printed digit — 1.904466 against a printed
`1.9045E+00`. On the v1.0 reference the same sum is 0.476116, exactly one
quarter of it. And the regenerated column is 4.0000x the old one in all 40 rows,
with `gst2` and `wgst` untouched.

The plan says the factor is 20. It is 4. `itn=10`, `inp=40`.

Three things about the regeneration that are easy to get wrong:

**The committed reference is `normalize()`d output, not raw output.** The
regenerating run was gfortran on Windows, so its raw output carries CRLF and
prints `1.0417D+02` for format 604. Committing that would have put a third kind
of change into a diff whose whole value is being exactly the two changes it
claims. So the new references are the fresh output passed through the gate's own
normalization -- the same function both sides of every comparison go through --
which keeps the published `E` spelling and, until v1.2 retired that rule, left
the D-to-E normalization doing the work it was written for.

**The diff is the deliverable, and it was counted.** Helium: 84 changed lines,
being 4 version lines (one added at the top, `program version` rewritten, one
`He parameter set` added) and 80 `q1st` lines, 40 out and 40 in. Nothing else.
Anything beyond that would have been a defect in chunks 1-4, which is what makes
this gate worth stating so narrowly.

**The harness had to change with it, in the same commit.** `test/regression.sh`
read the staged input file name from *line 1* of the reference. Line 1 is now the
banner. It reads the first matching line instead. A gate that reads its
parameters out of its own fixture is right -- it cannot desynchronize -- but it
has to be read as "the first occurrence", not "the top of the file".

Not taken here, deliberately: correcting format 604 from `1pd` to `1pe`, which
would retire a normalization rule but move a third line; and the integer masses
of the six chunk-4 elements (chlorine 35.00 against 35.45, and five more), which
are inconsistent with all ten legacy rows carrying real atomic weights to four
significant figures. Neither touches choline, so neither needs this commit's
regeneration and both can land on their own terms.

**That paragraph was wrong about the first item, and this file repeated it for
four chunks.** Correcting 604 moves no line at all. Committing `normalize()`d
output here is exactly what left the references reading `E`, so the corrected
program matches them unchanged; v1.2 did it in one line per source file and
regenerated nothing. *The one normalization the comparison applies*, below, has
the detail and the check that proves the rule was live.

## Chunk 8 -- where the parameters actually come from

Chunk 4 merged twelve rows it could not account for, and said so in two
warnings. In August 2026 Iain Campuzano supplied the provenance: a universal
force field scaling factor per element -- 0.93 for C, O, F, Cl, Br, I, K and Cs;
1.20 for N; 0.43 for H; none for Li -- with sodium pre-existing and not
re-optimized, and three papers (`README.md` refs 1, 5, 6). Chunk 8 is what
checking that against the source produced. It moves no number and regenerates
nothing; `docs/parameters.md` is the deliverable.

**The attached source file carried no new code.** Iain's
`mobcal_n2_093COFClBrIKCs_1Li_12N_043H.f` is byte-identical (md5 `ff0c6b41...`)
to the copy chunk 4 merged from, and every row already agreed. Anyone tempted to
re-merge it should check the hash first.

Four results, in descending order of how much they change what the repository
can claim.

**`mobcal_N2.f`'s table is UFF and nothing but UFF.** All 32 literals are
Rappe's `x_I` and `D_I` times the stated factor, to five significant figures,
the residual being the rounding of the four-decimal literals. Nothing was
fitted row by row; there is one force field and sixteen multiplications. That
is a much stronger statement than "these came from Iain", and it means a
future row can be checked rather than trusted.

**The helium halogens are UFF x 0.80, and the "0.8602" this repository stated
for four chunks was an artifact of its own comparison.** Chunk 4 compared those
rows against `mobcal_N2.f`'s literals, which are themselves 0.93-scaled;
0.80/0.93 = 0.8602. The correction changes no code -- the warning fires on the
same rows for the same reason -- but the reason is now stateable. Two steps of
the nitrogen recipe are skipped rather than one unexplained factor applied: no
combining rule with the gas, and no `convr`. That is a sharper argument for the
warning than the one it replaces, and it survives Iain's reply, which is about
nitrogen throughout and does not mention helium.

**Every per-row provenance comment in `mobcal_N2.f`'s table was about the other
file.** "from fitting C60 mobility", the six-line Viehland note on sodium, "from
fitting mobilities of small silicon clusters", every "(same as carbon)" and
"(same as silicon)" -- all correct in `mobcal_He.f`, all copied across when the
nitrogen table was written, all describing nothing once the row underneath was a
scaled UFF value. This is the same defect class as chunk 3's silicon: a comment
that outlived the number it described. Each now names the factor; the Viehland
paragraph is kept verbatim and attributed. In `mobcal_He.f` only fluorine's was
wrong -- it claims carbon and is a verbatim copy of oxygen.

**`conve` is 0.382 % high, deliberately.** `conve=(4.2d0*0.01036427)` writes
4.2 kJ per kcal for 4.184. Every nitrogen well depth is uniformly high by
4.2/4.184 = 1.0038241 as a result, and so were the fits that produced the
scaling factors. It belongs on the same list as the single-precision literals:
things that look like defects, are, and must not be repaired.

Two things chunk 8 deliberately did not do. It did not put `convr` on the helium
halogen radii -- that would invent a parameterization nobody published and move
published numbers. And it did not correct the four-significant-figure integer
masses, format 604's `1pd`, or `conve`; none is settled by this reply. Two of
the three still need their own regeneration. 604 turned out not to: v1.2
corrected it and `sample-output/` did not move.

One note for a future grep. `0.8602` still appears in six files, in every case
withdrawing the claim rather than making it. The check is not that the string is
absent; it is that nothing still asserts it as the factor.

## Chunk 9 -- phosphorus in helium, and the He parameter set at 2.1

One row, and the second of only two commits in v1.1 that move a line in
`sample-output/`.

**What it rests on, stated plainly.** Phosphorus in helium is UFF `x_I` and
`D_I` scaled by 0.80, the construction chunk 8 recovered from the three helium
halogens: `0.305*0.80*43.360 = 10.57984` meV and `4.147*0.80 = 3.3176` Angstrom,
written to the same five figures those three use. **The 0.80 factor is attested
in no published source.** So this row is a construction, not a measurement, and
it prints the PROVISIONAL warning for exactly that reason. Chunk 4 refused
phosphorus in helium on the principle that a missing parameter should be refused
rather than guessed; that principle is not abandoned here, it is relocated into
the warning -- the row is offered, and labelled.

Anyone revisiting this should know it was a close call and that the contrary
case was made: Iain Campuzano's reply is about nitrogen throughout, all three
papers it cites are nitrogen studies, and it does not mention helium. Extending
a helium-only factor to a fourth element is extrapolation. It was taken as a
deliberate decision, on the grounds that refusing an element the recipe covers
serves nobody, with the caveat written into the source, `README.md`,
`docs/parameters.md` and the run's own output.

**The hard-sphere radius is phosphorus's own, and that is not a guess.** 4.2
Angstrom comes from `mobcal_N2.f`. It transfers because `rhs` is gas-independent
in this code: every element defined in both files carries the same value in
both -- all twelve that were shared before this commit, without exception. So
phosphorus does *not* print the borrowed-radius
warning, and it is the only row that prints one of the two warnings and not the
other.

**That divergence is the gate's gain.** Until chunk 9 the provisional and
borrowed-radius warnings fired on the same three rows, so a count could not tell
them apart -- either error was invisible. Now He expects 8 and 6. Verified by
mutation in both directions: deleting phosphorus's `write(8,603)` moves 8 to 6
and leaves 6 alone; giving phosphorus carbon's 2.7 Angstrom and the matching
`write(8,604)` moves 6 to 8, leaves 8 alone, and trips the pinned-value
assertion as well. One failure each, on the count that should move.

**The parameter set went to 2.1, not 3.0.** Helium's table gained an element and
no existing row's values changed, which is a pure addition. Nitrogen's stayed at
2.0 -- it did not change -- and that divergence is the entire argument for two
version strings rather than one, made concrete for the first time. The 1.0 ->
2.0 step, which chunk 5 was the first to print, moved both at once, so it could
not demonstrate the property it was designed for.

**The regeneration was two lines, and counted.** `sample-output/Choline_He.out`
line 1 and its SUMMARY `He parameter set` line, 2.0 -> 2.1. Nothing else in
either file: `Choline_N2.out` does not move at all, and choline contains no
phosphorus, so neither warning fires on the fixture. As in chunk 5, the new
reference is the fresh run passed through the gate's own normalization rather
than raw output.

## The two array bounds

`mobcal_limits.inc` holds both, and holds them once — and since v1.3 a third,
the number of rows a parameter file may carry:

```
parameter (len=1000)      ! atoms per conformer
parameter (lcoord=100)    ! coordinate sets per input file
parameter (ltab=64)       ! element rows per parameter file
```

Before v1.1, `parameter (len=1000)` was written out fifteen times per source
file. Two of those thirty lines carried a trailing space, so an exact-match
replace-all silently skipped them — which is the fifteen-edit-points problem
demonstrating itself.

Four things to know before editing it:

**`len` shadows the intrinsic `LEN`.** Pre-existing, accepted under
`-std=legacy`, and not worth renaming: the name appears in every dimension
expression in both files.

**All three names must begin with `i`, `j`, `k` or `l`.** Every unit that includes the
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
still holds; what changed is that it now lists required source files — three
includes since v1.3, `mobcal_ljread.inc` being a whole subroutine and its
helpers rather than declarations, included after the last program unit.

## The one normalization the comparison applies

**End-of-line CR**, for the reason above, and needed to compare a gfortran build
against the references published in 2012, which were produced with g77. Stripped
only at end of line, never mid-line: the filename fields are blank-padded to 30
columns by an `a30` edit descriptor, and those trailing blanks are real content.

**There were two until v1.2.** The second rewrote a Fortran `D` exponent to an
`E`. Format 604, the `mass of ion` line, was the only edit descriptor in either
source that asked for `1pd` rather than `1pe`, and neither source has one now.
g77 printed `1.0417E+02`; gfortran printed `1.0417D+02` — same value, same
digits, different exponent letter, a runtime formatting difference and not
physics. Until v1.2 no gfortran build could match the published references byte
for byte on any platform without the rule.

**Correcting the descriptor cost no regeneration**, which is not what this file
said for four chunks. `sample-output/` already read `E`: chunk 5 committed output
passed through `normalize()`, so the references hold g77's spelling, and the
corrected program prints exactly that. `1pd11.4` and `1pe11.4` produce the same
eleven characters but for the letter — verified on this compiler before the
change, not assumed from the descriptor. So v1.2 changed one line per source
file, deleted the rule, and moved nothing in `sample-output/`.

**The evidence that the rule was live and was doing only this is the intermediate
state**, and it is the check to repeat before touching `normalize()` again. With
the rule removed and the descriptor still `1pd`, the helium gate fails T1 and T3
on the `mass of ion` line and on nothing else, and T2 does not move; with the
descriptor corrected it passes all three tiers against the untouched reference.
The three-platform, two-gas CI matrix is what carries that from helium on Windows
to the claim that the rule normalized that line and no other.

**The other difference is staged away rather than normalized.** Both references
echo the name of the file they were run on, twice, and that name is
`Choline_pop.mfj` — the 2012 run's. This repository ships the same coordinates
as `Choline.mfj`. So `test/regression.sh` copies the input to the name it reads
out of the reference before running, rather than editing either side of the
comparison. The consequence is worth stating in the contributor notes because it
surprises anyone checking a build by hand: a user who copies one of the shipped
`mobcal_He.in` / `mobcal_N2.in` templates to `mobcal.in`, runs it directly, and
diffs the result gets one differing field, twice, on top of the line terminator
on Windows — and it is the echoed filename, not a number.
Chunk 7 measured exactly that from a clean clone, and `README.md`'s *Run the
compiled code* names both differences instead of promising an exact match.

## How the documentation cites the source

`docs/` names **a subprogram plus a format label, or a subprogram plus a
verbatim statement** — "`ljparm`'s `itest.eq.0` arm, format 602";
"`read(9,'(a30)',end=100) dummy`, the first executable statement of `ncoord`".
It gives no line numbers. That is a decision taken in v1.2, and it was taken
after measuring what the alternative had already cost.

**The measurement.** `docs/mfj-format.md` and `docs/parameters.md` between them
carried 30 `file:line` citations. Two commits made 22 of them wrong, and
**neither changed the behaviour of anything cited**:

+ `59c737b` rewrote provenance *comments* inside the two element tables. No
  non-comment line of either source changed — verified mechanically, and said
  so in that commit's own message. It still pushed everything below the tables
  down 22 lines in `mobcal_He.f` and 46 in `mobcal_N2.f`, falsifying 10
  citations. Nine of them were in `docs/mfj-format.md`, which that same commit
  edited, to add one *See also* bullet, without noticing. The tenth was in
  `docs/parameters.md`, which that same commit *created*: its pointer at the
  Lennard-Jones potential line was read off the file before the rewrite moved
  it, and landed on `sum4=0.d0`. That citation was never correct, not for one
  commit.
+ `28a4bd0` added one element row — chunk 9's phosphorus in helium — and three
  lines in the main program for the 2.1 parameter-set string. That moved
  `fcoord` down 3 and `ljparm`'s contents down 26 further, falsifying the
  remaining 12: every helium citation the first commit had not already broken.

The 8 that survived are all in `mobcal_N2.f` and all at or above `ljparm`'s own
header — the one region neither commit inserted into. That is the whole
mechanism: these files gain element rows every release and gain comments
whenever somebody learns something about a row, and a citation's correctness
depends on nobody having done either above it.

No gate can fail when this happens. The four gates build and run the program,
and `test/refusals.sh` reads the sources themselves; none of them reads
`docs/`. An ungated claim that decays on a schedule
is what *Weakening T3 is a commit, not a default* exists to prevent, and a
stale citation is worse than no citation: it sends a reader to a real line that
is not the one meant, which reads as a misunderstanding of the code rather than
as a broken pointer.

**Half the address is the subprogram, and that is not decoration.** Format
labels are unique within a program unit and nowhere else. `602` occurs six
times in `mobcal_N2.f`; `624`, `616` and `651` occur twice each in both files.
So "format 602" alone is ambiguous and "`ljparm`, format 602" is exact. For
code carrying no label — `imass(iatom)=nint(ximass)`, the `if(unit.eq.'au')`
block — quote the statement instead. That is what a reader greps for anyway,
which is why most of these citations already carried the text *and* a number:
the number was redundant before it was wrong.

The rule covers pasted `grep -n` output too. `test/regression.sh` carried a
transcript of the `1pd` grep whose two line numbers had drifted by 46 and 73;
it was reduced to the same grep without `-n`, and v1.2 then retired the
descriptor and the transcript with it.

**The rule was tested before it was committed, by accident.** `cd45c29` landed
on `v1.2-dev` while this change was in review: it converted every refusal to
`call exit(1)`, changing 55 lines in `mobcal_He.f` and 38 in `mobcal_N2.f`.
All 45 anchors the rewritten docs use still resolved, unedited, at the same
multiplicity — checked, not assumed. The one thing in `docs/` that commit *did*
have to touch by hand was a line-number citation it had added itself, in the
same file, for a refusal whose line numbers its own change moved.

**One claim of the same class was corrected alongside them.**
`docs/mfj-format.md` said the list of defined keys in format 602 "is generated
from the build's actual table, so it can't drift out of sync with what the code
accepts". It is not generated from anything — it is a hardcoded string a few
lines below the rows, `test/elements.sh` asserts that the refusal fires and
names the key but never compares the list against the rows, and nothing else
compares them either. Both files' lists are in fact correct today. *Adding an
element* in `docs/parameters.md` now carries the one command that shows it, and
says plainly that it is a hand check.

## Building

The recipe is `-O3 -fno-automatic -std=legacy`, plus `-static` on Windows. It
lives in exactly one place — `FFLAGS` in `test/build-flags.sh`, which all four gates
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
