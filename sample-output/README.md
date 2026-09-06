# Sample output

Running either binary, with the matching `mobcal_He.in` / `mobcal_N2.in`
template copied to `mobcal.in`, reproduces every number in the corresponding
file here. Two lines still differ from a plain `diff` — the echoed input file
name, and the line terminator on Windows — neither of them physics; see *Run
the compiled code* in `README.md`, and use `sh test/regression.sh`, which
accounts for both.

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
one normalization it applies.

The `mass of ion` line here reads `1.0417E+02` because that is what `g77`
printed. Through v1.1 `gfortran` printed `1.0417D+02` — format 604 was the one
edit descriptor in either source that asked for a `D` exponent — and the
comparison normalized the two to each other. v1.2 corrected the descriptor
instead, which cost these files nothing: they were already committed with the
`E`, so the program was changed to agree with them rather than the other way
round.
