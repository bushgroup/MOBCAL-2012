#!/usr/bin/env python3
"""Convert plain XYZ coordinates to a MOBCAL .mfj input file.

Optional. Not part of the build, not covered by test/regression.sh,
test/bounds.sh or test/elements.sh, and not required to compile or run
either mobcal_He.f or mobcal_N2.f -- the repository's no-external-
dependencies promise applies to the program, and this script keeps its own
promise the same way: standard library only, one file, nothing to install.

See docs/mfj-format.md for the format this writes and why it always emits
five columns per atom (mass key + charge) even in "equal" and "none" charge
modes -- that is the safe choice across both mobcal_He.f and mobcal_N2.f,
which disagree about how many columns "equal" mode reads.

Usage:
    python3 tools/xyz2mfj.py input.xyz output.mfj
    python3 tools/xyz2mfj.py input.xyz output.mfj --charge equal --net-charge 1.0
    python3 tools/xyz2mfj.py input.xyz output.mfj --label "my ion"

Input is standard XYZ: an atom-count line, a comment line, then one line per
atom of "symbol x y z" (angstroms) or "symbol x y z charge" for a per-atom
partial charge. Concatenate several such blocks in one file for a multi-
conformer ensemble -- each becomes one .mfj coordinate set, in order, and
every block must declare the same atom count (mobcal itself requires this;
see "Conformer blocks" in docs/mfj-format.md).
"""

import argparse
import sys

# nint(atomic weight) -- the key convention mobcal_He.f and mobcal_N2.f both
# use (see docs/mfj-format.md, "The element key is a lookup, not a mass").
# This is the union of keys either gas defines; a given gas may refuse a key
# the other one accepts -- that refusal comes from mobcal itself and names
# what it needs, so it is not duplicated here.
ELEMENT_KEYS = {
    "H": 1,
    "LI": 7,
    "C": 12,
    "N": 14,
    "O": 16,
    "F": 19,
    "NA": 23,
    "SI": 28,
    "P": 31,
    "S": 32,
    "CL": 35,
    "K": 39,
    "FE": 56,
    "BR": 80,
    "I": 127,
    "CS": 133,
}


def element_key(symbol):
    key = ELEMENT_KEYS.get(symbol.strip().upper())
    if key is None:
        known = ", ".join(sorted(ELEMENT_KEYS, key=ELEMENT_KEYS.get))
        raise SystemExit(
            "xyz2mfj: unrecognized element symbol '{}'.\n"
            "Symbols this converter knows: {}.\n"
            "See the 'Supported elements' table in README.md -- a symbol "
            "listed here may still be refused by a particular gas's build."
            .format(symbol, known)
        )
    return key


def parse_xyz(path):
    """Yield (comment, [(symbol, x, y, z, charge_or_None), ...]) per block."""
    with open(path) as f:
        lines = [line.rstrip("\n") for line in f]
    i = 0
    n_lines = len(lines)
    while i < n_lines:
        while i < n_lines and not lines[i].strip():
            i += 1
        if i >= n_lines:
            return
        try:
            count = int(lines[i].strip())
        except ValueError:
            raise SystemExit(
                "xyz2mfj: expected an atom count at line {}, got {!r}"
                .format(i + 1, lines[i])
            )
        comment = lines[i + 1] if i + 1 < n_lines else ""
        atoms = []
        base = i + 2
        for j in range(count):
            if base + j >= n_lines:
                raise SystemExit(
                    "xyz2mfj: block starting at line {} declares {} atoms "
                    "but the file ends after {}"
                    .format(i + 1, count, len(atoms))
                )
            fields = lines[base + j].split()
            if len(fields) not in (4, 5):
                raise SystemExit(
                    "xyz2mfj: line {}: expected 'symbol x y z [charge]', "
                    "got {!r}".format(base + j + 1, lines[base + j])
                )
            symbol = fields[0]
            x, y, z = (float(v) for v in fields[1:4])
            charge = float(fields[4]) if len(fields) == 5 else None
            atoms.append((symbol, x, y, z, charge))
        yield comment, atoms
        i = base + count


def write_mfj(out_path, label, correction, mode, net_charge, blocks):
    with open(out_path, "w", newline="\n") as out:
        out.write(label[:30] + "\n")
        out.write("{}\n".format(len(blocks)))
        out.write("{}\n".format(len(blocks[0][1])))
        out.write("ang\n")
        out.write("{}\n".format(mode))
        out.write("{:.4f}\n".format(correction))
        for block_index, (comment, atoms) in enumerate(blocks):
            if block_index > 0:
                out.write((comment or "conformer {}".format(block_index + 1))[:30] + "\n")
            n = len(atoms)
            for symbol, x, y, z, charge in atoms:
                key = element_key(symbol)
                if mode == "calc":
                    if charge is None:
                        raise SystemExit(
                            "xyz2mfj: --charge calc needs a 5th (charge) "
                            "column on every atom line; symbol {} at "
                            "({}, {}, {}) has none".format(symbol, x, y, z)
                        )
                    q = charge
                elif mode == "equal":
                    q = net_charge / n
                else:  # none
                    q = 0.0
                out.write(
                    "{:13.5f}{:13.5f}{:13.5f}{:4d}{:14.6f}\n"
                    .format(x, y, z, key, q)
                )


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("xyz_file")
    parser.add_argument("mfj_file")
    parser.add_argument(
        "--charge", choices=("calc", "equal", "none"), default=None,
        help="charge mode; default is 'calc' if the input has a 5th "
             "(charge) column, else 'equal'",
    )
    parser.add_argument(
        "--net-charge", type=float, default=1.0,
        help="total ionic charge for --charge equal, split evenly and "
             "written into the (otherwise unused-by-helium) 5th column "
             "on every atom; default 1.0",
    )
    parser.add_argument(
        "--label", default=None,
        help="line 1 of the .mfj file; defaults to the first XYZ block's "
             "comment line, truncated to 30 characters",
    )
    parser.add_argument(
        "--correction", type=float, default=1.0000,
        help="geometry correction factor, line 6 of the .mfj file; "
             "default 1.0000 (no correction)",
    )
    args = parser.parse_args(argv)

    blocks = list(parse_xyz(args.xyz_file))
    if not blocks:
        raise SystemExit("xyz2mfj: {} contains no atoms".format(args.xyz_file))

    n_atoms = len(blocks[0][1])
    for index, (_, atoms) in enumerate(blocks):
        if len(atoms) != n_atoms:
            raise SystemExit(
                "xyz2mfj: coordinate set {} has {} atoms, set 1 has {} -- "
                "mobcal requires every set in one .mfj file to declare the "
                "same atom count".format(index + 1, len(atoms), n_atoms)
            )

    has_charges = any(charge is not None for _, atoms in blocks for *_, charge in atoms)
    mode = args.charge or ("calc" if has_charges else "equal")

    label = args.label if args.label is not None else (blocks[0][0] or "converted from XYZ")

    write_mfj(args.mfj_file, label, args.correction, mode, args.net_charge, blocks)
    print(
        "wrote {}: {} atom(s), {} coordinate set(s), charge mode '{}'"
        .format(args.mfj_file, n_atoms, len(blocks), mode)
    )


if __name__ == "__main__":
    main()
