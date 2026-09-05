# Sample output

Running either binary, with the matching `mobcal_He.in` / `mobcal_N2.in`
template copied to `mobcal.in`, reproduces every number in the corresponding
file here. Three lines still differ from a plain `diff` — the
echoed input file name, the `D`-versus-`E` exponent letter, and the line
terminator on Windows — none of them physics; see *Run the compiled code* in
`README.md`, and use `sh test/regression.sh`, which accounts for all three.

These two files are also the fixtures `test/regression.sh` compares against, so
they are reference data rather than examples. Two things follow from that.

**They record their own harness.** The regression gate reads the input file name
and the RANLUX seed out of the reference itself rather than hardcoding either, so
a regeneration cannot silently desynchronize the two.

**They keep the published numbers.** They are the output files published with
Campuzano et al., *Anal. Chem.* **2012**, *84*, 1026-1033, produced with `g77`.
The v1.1 regeneration reproduced every value in them with `gfortran` and changed
only the lines that v1.1 deliberately changed — the version banner, and the
`q1st` column, which through v1.0 was divided by the wrong count. `CHANGELOG.md`
names the lines; `CLAUDE.md` explains the tiers the comparison reports and the
two normalizations it applies.

One of those normalizations is why the `mass of ion` line here reads `1.0417E+02`
rather than `1.0417D+02`: `gfortran` prints a `D` exponent for that one edit
descriptor and `g77` printed `E`. The files keep the published spelling, and the
comparison treats the two as equal.
