#!/bin/sh
#
# test/regression.sh -- the MOBCAL-2012 regression gate.
#
# Builds mobcal_He.f and mobcal_N2.f, runs Choline.mfj through both at the seed
# recorded in the reference outputs, and compares the result against the
# reference outputs committed under sample-output/. Those references are the
# files published with Campuzano et al., Anal. Chem. 2012, 84, 1026-1033,
# regenerated once in v1.1 for the two output changes that release makes -- the
# version banner and the q1st column. Every other line of both files, including
# all four cross sections and every stochastic diagnostic, still carries the
# published g77 numbers, reproduced by the regenerating gfortran run.
#
# Usage:
#   test/regression.sh                 both gases, all tiers
#   test/regression.sh --gas he        one gas
#   test/regression.sh --tol 0.002     override the T2 tolerance
#   test/regression.sh --keep          keep test/_work for inspection
#
# Environment: FC and FFLAGS override the compiler and flags.
#
#
# WHAT IS COMPARED, AND WHY IT IS SPLIT
#
# The program's output mixes lines that are a pure function of the input with
# lines accumulated over 400,000 stochastic trajectories. Those two kinds of
# line cannot be held to the same standard across three platforms, so the gate
# reports three tiers:
#
#   T1  DETERMINISTIC -- every line not listed in test/stochastic-lines.txt,
#       compared character for character after normalization. This is the
#       masses, the charges, the centre of mass, the geometry echo, the
#       structural asymmetry parameter, the velocity-grid integration table and
#       the trajectory parameters. Gating on every platform.
#
#   T2  CROSS SECTIONS -- the four reported cross sections, parsed and compared
#       within a relative tolerance. Gating on every platform.
#
#   T3  WHOLE FILE -- byte identity after normalization, including every
#       stochastic line. Gating only on the platforms listed in
#       test/strict-platforms; reported everywhere.
#
# T3 is not decoration. The element table sets four things per atom -- mass,
# Lennard-Jones epsilon, Lennard-Jones sigma, and hard-sphere radius -- and only
# the mass reaches a T1 line. The Lennard-Jones scaling constants printed in the
# header are hardcoded (mobcal_He.f, "eo=1.34d-03*xe"), not derived from the
# table. So a wrong epsilon or sigma is INVISIBLE to T1 and would have to be
# gross to trip T2. T3 is the only check that sees it, which is why the release
# plan states the element-table chunks' own gate as "byte-identical on the
# committed fixtures".
#
#
# NORMALIZATION, AND WHY THE SCRIPT DOES IT ITSELF
#
# .gitattributes pins line endings to LF in the repository and the working tree.
# That is necessary but not sufficient, because the PROGRAM writes CRLF on
# Windows and LF elsewhere -- gfortran's Windows runtime opens the output unit in
# text mode. No checkout setting can fix a difference introduced after checkout,
# so the comparison strips end-of-line CR itself and does not rely on git.
#
# One further normalization is needed and is narrow. Format 604, the "mass of
# ion" line, is the only edit descriptor in either source file that uses 1pd
# rather than 1pe:
#
#     $ grep 'pd[0-9]' mobcal_He.f mobcal_N2.f
#     mobcal_He.f:  604 format(1x,'mass of ion =',1pd11.4)
#     mobcal_N2.f:  604 format(1x,'mass of ion =',1pd11.4)
#
# g77 printed that as 1.0417E+02; gfortran prints 1.0417D+02. Same value, same
# digits, different exponent letter -- a Fortran runtime formatting difference,
# not physics. Without this rule no gfortran build can match the published 2012
# reference byte for byte, on any platform.
#
# The v1.1 regeneration did not take the chance to drop this rule, though it
# could have: the regenerated references were passed through this same
# normalization before being committed, so they keep the published E spelling and
# the rule is still what makes a live gfortran run match them. Correcting the
# descriptor to 1pe would remove the need for it, but that is one more line of
# output moving in the release that regenerates the fixtures, and the value of
# that release is that its diff is exactly the two changes it claims.

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK="$ROOT/test/_work"
PATTERNS="$ROOT/test/stochastic-lines.txt"
STRICT_LIST="$ROOT/test/strict-platforms"

TOL=${MOBCAL_CCS_TOL:-0.001}
GASES="he n2"
KEEP=0

while [ $# -gt 0 ]; do
    case "$1" in
        --gas)  GASES=$2; shift 2 ;;
        --tol)  TOL=$2; shift 2 ;;
        --keep) KEEP=1; shift ;;
        -h|--help)
            # Reprint the usage block from this file's own header, so the help
            # text cannot drift out of step with the comment above it.
            sed -n '/^# Usage:/,/^# Environment:/p' "$0" | sed 's/^#\{1,\} \{0,1\}//'
            exit 0 ;;
        *) echo "regression.sh: unknown argument '$1'" >&2; exit 2 ;;
    esac
done

CR=$(printf '\r')

# The build recipe -- PLATFORM, FC, FFLAGS, LDFLAGS -- lives in one file, shared
# with test/bounds.sh. Do not restate the flags here.
. "$ROOT/test/build-flags.sh"

# --- helpers ---------------------------------------------------------------

normalize() {
    # End-of-line CR only, then the D-exponent rule. A literal CR from printf
    # rather than the escape '\r', because BSD sed on macOS reads '\r' in a
    # pattern as a literal 'r' and would strip trailing letters instead.
    sed -e "s/${CR}\$//" -e 's/\([0-9]\)D\([+-][0-9]\)/\1E\2/g' "$1"
}

deterministic() {
    normalize "$1" | grep -E -v -f "$PATFILE"
}

scalar() {
    # Last occurrence of a labelled value. Most are printed twice, in the body
    # and again in SUMMARY; the last one is the SUMMARY copy.
    normalize "$1" | grep -F "$2" | tail -1 | sed 's/.*= *//' | tr -d "$CR "
}

strict_here() {
    grep -v '^[[:space:]]*#' "$STRICT_LIST" \
        | grep -v '^[[:space:]]*$' \
        | grep -qx "$PLATFORM"
}

# --- setup -----------------------------------------------------------------

require_compiler

rm -rf "$WORK"
mkdir -p "$WORK"

PATFILE="$WORK/patterns"
grep -v '^[[:space:]]*#' "$PATTERNS" | grep -v '^[[:space:]]*$' > "$PATFILE"

echo "MOBCAL-2012 regression gate"
echo "  platform     : $PLATFORM ($(uname -s -m))"
echo "  compiler     : $FC -- $("$FC" --version 2>/dev/null | head -1)"
echo "  flags        : $FFLAGS $LDFLAGS"
echo "  T2 tolerance : $TOL relative"
if strict_here; then
    echo "  T3           : GATING on $PLATFORM (listed in test/strict-platforms)"
else
    echo "  T3           : reported only on $PLATFORM (not in test/strict-platforms)"
fi
echo

FAILED=0

for gas in $GASES; do
    case "$gas" in
        he) src=mobcal_He.f; ref=sample-output/Choline_He.out ;;
        n2) src=mobcal_N2.f; ref=sample-output/Choline_N2.out ;;
        *)  echo "regression.sh: unknown gas '$gas'" >&2; exit 2 ;;
    esac

    REF="$ROOT/$ref"
    d="$WORK/$gas"
    mkdir -p "$d"

    echo "=== $gas ============================================================"

    # The reference file records the two things a reproduction needs: the name
    # the input file had when it was generated, echoed on line 1, and the RANLUX
    # seed. Read both out of the reference rather than hardcoding them, so that
    # regenerating the references cannot silently desynchronize the harness.
    # First occurrence, not line 1: since v1.1 the file opens with the version
    # banner, and the name is echoed again in SUMMARY, so anchoring on either
    # end of the file would break on a later output change.
    staged=$(grep -F ' input file name = ' "$REF" | head -1 \
               | sed 's/^ input file name = *//' | tr -d "$CR" | sed 's/ *$//')
    seed=$(grep 'using RANLUX with seed integer =' "$REF" | head -1 \
             | sed 's/.*= *//' | tr -d "$CR ")
    [ -n "$staged" ] || staged=Choline.mfj
    [ -n "$seed" ] || { echo "  cannot read seed from $ref" >&2; exit 2; }
    echo "  reference    : $ref"
    echo "  input staged : Choline.mfj -> $staged (name the reference echoes)"
    echo "  seed         : $seed"

    cp "$ROOT/Choline.mfj" "$d/$staged"
    # mobcal.in is three records: input file, output file, seed. Both filename
    # fields are read with an a30 edit descriptor, so they must not exceed 30
    # characters. The program reads it from the current directory under that
    # fixed name and writes its output to a fixed unit, so each gas gets its own
    # directory rather than sharing one.
    printf '%s\n%s\n%s\n' "$staged" regression.out "$seed" > "$d/mobcal.in"

    echo "  building     : $FC $FFLAGS $LDFLAGS -o mobcal_$gas $src"
    # Compiler diagnostics still go to a file rather than the console. With
    # -std=legacy in FFLAGS there should be none at all, and the warning count
    # printed below is the check on that: anything nonzero is a diagnostic
    # outside the deleted-feature class and worth reading, which is exactly the
    # signal the old 64-warnings-per-build noise floor destroyed.
    # shellcheck disable=SC2086
    if ! ( cd "$ROOT" && "$FC" $FFLAGS $LDFLAGS -o "$d/mobcal_$gas" "$src" ) \
            > "$d/build.log" 2>&1; then
        echo "  BUILD FAILED:"
        sed 's/^/      /' "$d/build.log"
        FAILED=1
        continue
    fi
    echo "  warnings     : $(grep -c '^Warning:' "$d/build.log" || true) (see test/_work/$gas/build.log)"

    echo "  running      : 400,000 trajectories, minutes not seconds"
    ( cd "$d" && "./mobcal_$gas" >run.log 2>&1 )
    OUT="$d/regression.out"
    [ -s "$OUT" ] || { echo "  FAIL: no output produced" >&2; FAILED=1; continue; }

    # --- T1 ----------------------------------------------------------------
    deterministic "$REF" > "$d/ref.det"
    deterministic "$OUT" > "$d/new.det"
    if diff -u "$d/ref.det" "$d/new.det" > "$d/t1.diff"; then
        echo "  T1 DETERMINISTIC : PASS ($(wc -l < "$d/ref.det" | tr -d ' ') lines exact)"
    else
        echo "  T1 DETERMINISTIC : FAIL"
        sed -n '1,60p' "$d/t1.diff" | sed 's/^/      /'
        FAILED=1
    fi

    # --- T2 ----------------------------------------------------------------
    # A label is checked when the REFERENCE prints it. The two codes do not
    # print the same set: mobcal_N2.f has no MOBIL4 path, so a nitrogen run
    # reports no projection-approximation or hard-sphere cross section at all.
    # Deriving the set from the reference handles both gases with one list, and
    # means a label that stops being printed is a failure rather than a silent
    # skip.
    t2fail=0
    t2seen=0
    for label in \
        " average PA cross section =" \
        " average EHS cross section =" \
        " average TM cross section =" \
        " mean OMEGA*(1,1) ="
    do
        a=$(scalar "$REF" "$label")
        if [ -z "$a" ]; then
            printf '  T2 %-36s : n/a  (not printed for %s)\n' "$label" "$gas"
            continue
        fi
        t2seen=$((t2seen + 1))
        b=$(scalar "$OUT" "$label")
        if [ -z "$b" ]; then
            echo "  T2 $label : FAIL - reference prints it, this run does not"
            t2fail=1; continue
        fi
        verdict=$(awk -v a="$a" -v b="$b" -v tol="$TOL" 'BEGIN{
            d = (a == 0) ? (b == 0 ? 0 : 1) : (a - b) / a
            if (d < 0) d = -d
            printf "%s %.2e", (d <= tol ? "ok" : "BAD"), d
        }')
        state=${verdict%% *}; dev=${verdict##* }
        printf '  T2 %-36s : %-3s  ref=%s new=%s  reldev=%s\n' \
            "$label" "$state" "$a" "$b" "$dev"
        [ "$state" = ok ] || t2fail=1
    done
    if [ "$t2seen" -eq 0 ]; then
        echo "  T2 CROSS SECTIONS : FAIL - reference printed none of the"
        echo "      expected labels, so T2 checked nothing. Either the"
        echo "      reference is truncated or the label list is stale."
        FAILED=1
    elif [ "$t2fail" -eq 0 ]; then
        echo "  T2 CROSS SECTIONS : PASS ($t2seen checked)"
    else
        echo "  T2 CROSS SECTIONS : FAIL"
        FAILED=1
    fi

    # --- T3 ----------------------------------------------------------------
    normalize "$REF" > "$d/ref.norm"
    normalize "$OUT" > "$d/new.norm"
    if diff -u "$d/ref.norm" "$d/new.norm" > "$d/t3.diff"; then
        echo "  T3 WHOLE FILE : PASS (byte-identical after normalization)"
    else
        n=$(grep -c '^[+-][^+-]' "$d/t3.diff" || true)
        if strict_here; then
            echo "  T3 WHOLE FILE : FAIL ($n differing lines)"
            sed -n '1,60p' "$d/t3.diff" | sed 's/^/      /'
            echo "      Full diff: test/_work/$gas/t3.diff"
            echo "      If this is floating-point summation order on this"
            echo "      platform and not a physics change, remove '$PLATFORM'"
            echo "      from test/strict-platforms in a commit that says so."
            FAILED=1
        else
            echo "  T3 WHOLE FILE : differs ($n lines) - not gating on $PLATFORM"
            echo "      Full diff: test/_work/$gas/t3.diff"
        fi
    fi
    echo
done

if [ "$KEEP" -eq 0 ] && [ "$FAILED" -eq 0 ]; then
    rm -rf "$WORK"
else
    echo "Working directory kept: test/_work"
fi

if [ "$FAILED" -eq 0 ]; then
    echo "GATE: PASS"
else
    echo "GATE: FAIL"
fi
exit "$FAILED"
