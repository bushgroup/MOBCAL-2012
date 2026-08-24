#!/bin/sh
#
# test/bounds.sh -- the array-bound refusal gate.
#
# Usage:
#   test/bounds.sh                 both gases
#   test/bounds.sh --gas he        one gas
#   test/bounds.sh --keep          keep test/_bounds to inspect the outputs
#
# Environment: FC and FFLAGS override the compiler and flags, as for
# test/regression.sh. The recipe itself lives in test/build-flags.sh.
#
#
# WHY THIS IS A SEPARATE SCRIPT
#
# test/regression.sh runs one valid input and compares the result against the
# reference outputs committed under sample-output/. That is the wrong shape for
# a test whose expected result is a refusal: there is no reference output to
# compare against, the run must terminate in milliseconds rather than an hour,
# and the assertion is about the exit status and one message rather than about
# 295 lines. So the two gates are separate scripts sharing one build recipe.
#
#
# WHAT IS BEING TESTED, AND WHY IT MATTERS MORE THAN IT LOOKS
#
# inatom and icoord are read straight from the input. Before v1.1 neither was
# tested against the array bound, and the per-atom arrays live in named COMMON
# blocks, so storage association makes them contiguous: atom 1001's x coordinate
# is written onto atom 1's y coordinate, in the same molecule, mid-calculation.
# -fno-automatic guarantees static storage, so that is deterministic overwriting
# of live data rather than a stack accident that might trap.
#
# Measured on the pre-v1.1 unguarded code, gfortran 16.2.0, the 1,001-atom input
# this script generates:
#
#   mobcal_He.f   exit 0, and it printed
#                   average PA  cross section = 4.3469E+02
#                   average EHS cross section = 2.6526E+02
#                 before dying in the orientation step -- still exit 0.
#   mobcal_N2.f   exit 0, no cross section reached.
#
# Two cross sections, in the format a real run prints them, from a molecule the
# program had rewritten, reported as success. The v1.1 build work established
# that the bare -O2 failure is loud, so no bad number could be published
# quietly. This was the one place where that reassurance did not hold, and
# these cases are what keep it holding.
#
#
# THE EXIT STATUS, WHICH IS A DELIBERATE INCONSISTENCY
#
# A bare Fortran `stop' exits 0. Every refusal this code shipped with -- eight
# bare stops in mobcal_He.f, including "units not specified", "charge
# distribution not specified" and "type not defined for atom number" -- reports
# success to its caller. The two new bound refusals use `call exit(1)' instead,
# because a refusal a script cannot detect is not much of a refusal.
#
# The older eight are deliberately left alone, so this repository currently has
# refusals of both kinds. The boundary case below is the one that shows it: it
# ends in the pre-existing charge-distribution refusal and therefore asserts an
# exit status of 0, which is not a mistake in the test.

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK="$ROOT/test/_bounds"

GASES="he n2"
KEEP=0

while [ $# -gt 0 ]; do
    case "$1" in
        --gas)  GASES=$2; shift 2 ;;
        --keep) KEEP=1; shift ;;
        -h|--help)
            sed -n '/^# Usage:/,/^# Environment:/p' "$0" | sed 's/^#\{1,\} \{0,1\}//'
            exit 0 ;;
        *) echo "bounds.sh: unknown argument '$1'" >&2; exit 2 ;;
    esac
done

. "$ROOT/test/build-flags.sh"

# The two limits under test. Read out of mobcal_limits.inc rather than repeated
# here, so that raising a bound does not silently turn these into tests of
# nothing. The whole point of the include file is that the bounds have exactly
# one definition.
limit_of() {
    sed -n "s/^ *parameter *( *$1 *= *\([0-9]*\) *).*/\1/p" \
        "$ROOT/mobcal_limits.inc" | head -1
}
MAXATOM=$(limit_of len)
MAXCRD=$(limit_of lcoord)
case "$MAXATOM$MAXCRD" in
    *[!0-9]*|"") echo "bounds.sh: cannot read the limits from mobcal_limits.inc" >&2; exit 2 ;;
esac

require_compiler

rm -rf "$WORK"
mkdir -p "$WORK"

echo "MOBCAL-2012 array-bound gate"
echo "  platform     : $PLATFORM ($(uname -s -m))"
echo "  compiler     : $FC -- $("$FC" --version 2>/dev/null | head -1)"
echo "  flags        : $FFLAGS $LDFLAGS"
echo "  limits       : len=$MAXATOM atoms, lcoord=$MAXCRD coordinate sets"
echo

FAILED=0

# --- fixture generation ----------------------------------------------------
#
# Generated rather than committed. Each over-bound fixture is a file that would
# be valid if the bound were one higher -- a full complement of coordinate
# records, a full complement of conformer blocks -- which is what makes the
# refusal attributable to the bound rather than to a malformed file. Committing
# them would add ~120 KB of repetitive filler to a repository whose two sources
# are 180 KB, so the generator is the artifact instead. They are also derived
# from the limits, so raising a bound cannot turn these into tests of nothing.
#
# Five columns and `calc' throughout: mobcal_N2.f has its `if(dchar.eq.calc)'
# branch commented out and reads the charge column unconditionally, so a
# four-column file is an end-of-file error there rather than a bound test.

atom_records() {
    awk -v n="$1" 'BEGIN{
        for (i = 1; i <= n; i++)
            printf "%12.5f%13.5f%13.5f%4d%15.6f\n", i * 0.1, 0.0, 0.0, 12, 0.0
    }'
}

write_over_atoms() {
    { echo "bounds gate: one atom over the limit"
      echo 1
      echo $((MAXATOM + 1))
      echo ang
      echo calc
      echo 1.0000
      atom_records $((MAXATOM + 1))
    } > "$1"
}

write_over_coords() {
    # One conformer over the limit, built by repeating choline's own atom block
    # so the fixture is real data rather than invented geometry. Conformer 1's
    # block follows the six header records directly; every later block is
    # preceded by one separator record, which is what NCOORD reads and
    # discards. The atom count and the block extent are read out of
    # Choline.mfj rather than written here, so editing that file cannot
    # silently desynchronize this fixture.
    natoms=$(sed -n '3p' "$ROOT/Choline.mfj" | tr -d ' ')
    case "$natoms" in
        *[!0-9]*|"") echo "bounds.sh: cannot read the atom count from Choline.mfj" >&2; exit 2 ;;
    esac
    block=$(sed -n "7,$((6 + natoms))p" "$ROOT/Choline.mfj")
    { echo "bounds gate: one coordinate set over the limit"
      echo $((MAXCRD + 1))
      echo "$natoms"
      echo ang
      echo calc
      echo 1.0000
      echo "$block"
      i=2
      while [ "$i" -le $((MAXCRD + 1)) ]; do
          echo "conformer $i"
          echo "$block"
          i=$((i + 1))
      done
    } > "$1"
}

write_boundary() {
    # Exactly at both limits, which is the off-by-one neither over-bound fixture
    # can catch. A valid 1,000-atom input cannot be used: it would be a real
    # trajectory calculation some fifty times the cost of choline's hour, and
    # the trajectory counts are hardcoded in the source, so there is no cheap
    # configuration of it. So this tests the guards and nothing beyond them --
    # the header declares both counts at the limit and then names a charge mode
    # that does not exist, so the program must pass both guards and stop at the
    # pre-existing charge-distribution refusal. Reaching that message is the
    # evidence that neither guard fired one early. No coordinate records are
    # needed or read.
    { echo "bounds gate: exactly at both limits"
      echo "$MAXCRD"
      echo "$MAXATOM"
      echo ang
      echo nosuchmode
      echo 1.0000
    } > "$1"
}

# --- assertions ------------------------------------------------------------

pass=0
fail=0

# check takes a description and a verdict of "y" or "n". The three producers
# below are the only things that make a verdict, so an assertion cannot
# accidentally be written as a command whose failure set -e would swallow.
check() {
    if [ "$2" = y ]; then
        pass=$((pass + 1)); printf '    ok   %s\n' "$1"
    else
        fail=$((fail + 1)); FAILED=1; printf '    FAIL %s\n' "$1"
    fi
}

present() { if grep -Eq -- "$1" "$2"; then echo y; else echo n; fi; }
absent()  { if grep -Eq -- "$1" "$2"; then echo n; else echo y; fi; }
status()  { if [ "$1" -eq "$2" ]; then echo y; else echo n; fi; }
nonzero() { if [ "$1" -ne 0 ];    then echo y; else echo n; fi; }

# --- per gas ---------------------------------------------------------------

for gas in $GASES; do
    case "$gas" in
        he) src=mobcal_He.f ;;
        n2) src=mobcal_N2.f ;;
        *)  echo "bounds.sh: unknown gas '$gas'" >&2; exit 2 ;;
    esac

    d="$WORK/$gas"
    mkdir -p "$d"
    echo "=== $gas ============================================================"
    echo "  building     : $FC $FFLAGS $LDFLAGS -o mobcal_$gas $src"
    # shellcheck disable=SC2086
    if ! ( cd "$ROOT" && "$FC" $FFLAGS $LDFLAGS -o "$d/mobcal_$gas" "$src" ) \
            > "$d/build.log" 2>&1; then
        echo "  BUILD FAILED:"
        sed 's/^/      /' "$d/build.log"
        FAILED=1
        continue
    fi
    echo "  warnings     : $(grep -c '^Warning:' "$d/build.log" || true)"

    write_over_atoms  "$d/over-atoms.mfj"
    write_over_coords "$d/over-coords.mfj"
    write_boundary    "$d/boundary.mfj"

    for case_name in over-atoms over-coords boundary; do
        out="$case_name.out"
        printf '%s\n%s\n%s\n' "$case_name.mfj" "$out" 96 > "$d/mobcal.in"
        if ( cd "$d" && "./mobcal_$gas" > "$case_name.stdout" 2>&1 ); then
            st=0
        else
            st=$?
        fi
        O="$d/$out"
        S="$d/$case_name.stdout"
        [ -f "$O" ] || : > "$O"
        [ -f "$S" ] || : > "$S"
        echo "  --- $case_name (exit $st) ---"

        case "$case_name" in
        over-atoms)
            # The message must name the actual count and the limit, both as
            # standalone numbers. That is the requirement; the wording around
            # them is not, beyond being recognisable as an error.
            re="ERROR.*[^0-9]$((MAXATOM + 1))[^0-9].*[^0-9]$MAXATOM([^0-9]|\$)"
            check "exit status is nonzero"                "$(nonzero "$st")"
            check "output names the count and the limit"  "$(present "$re" "$O")"
            check "the message reaches the console too"   "$(present "$re" "$S")"
            check "no cross section was printed"          "$(absent 'cross section' "$O")"
            ;;
        over-coords)
            re="ERROR.*[^0-9]$((MAXCRD + 1))[^0-9].*[^0-9]$MAXCRD([^0-9]|\$)"
            check "exit status is nonzero"                "$(nonzero "$st")"
            check "output names the count and the limit"  "$(present "$re" "$O")"
            check "the message reaches the console too"   "$(present "$re" "$S")"
            check "no cross section was printed"          "$(absent 'cross section' "$O")"
            check "refused before reading the atom count" "$(absent 'number of atoms' "$O")"
            ;;
        boundary)
            check "coordinate-set count at the limit accepted" \
                  "$(present "number of coordinate sets *= *$MAXCRD *\$" "$O")"
            check "atom count at the limit accepted" \
                  "$(present "number of atoms *= *$MAXATOM *\$" "$O")"
            check "neither guard fired at exactly the limit" \
                  "$(absent 'ERROR' "$O")"
            check "execution reached the charge-distribution refusal" \
                  "$(present 'charge distribution not specified' "$O")"
            # Exit 0 is correct here and is not a typo: see the header. The
            # pre-existing refusal this case lands on is a bare Fortran stop.
            check "exit status is 0 (pre-existing bare stop)" \
                  "$(status "$st" 0)"
            ;;
        esac
    done
    echo
done

echo "BOUNDS GATE: $pass passed, $fail failed"

if [ "$KEEP" -eq 0 ] && [ "$FAILED" -eq 0 ]; then
    rm -rf "$WORK"
else
    echo "Working directory kept: test/_bounds"
fi

if [ "$FAILED" -eq 0 ]; then
    echo "GATE: PASS"
else
    echo "GATE: FAIL"
fi
exit "$FAILED"
