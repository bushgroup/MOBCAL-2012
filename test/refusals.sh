#!/bin/sh
#
# test/refusals.sh -- the exit-status gate.
#
# Usage:
#   test/refusals.sh                 both gases
#   test/refusals.sh --gas he        one gas
#   test/refusals.sh --keep          keep test/_refusals to read the outputs
#
# Environment: FC and FFLAGS override the compiler and flags, as for the other
# three gates. The recipe itself lives in test/build-flags.sh.
#
#
# WHAT IS BEING TESTED
#
# A bare Fortran `stop' exits 0. Until v1.2 every termination in both sources
# was one, except the two array-bound refusals v1.1 added, so a run that
# refused its input and a run that computed a cross section were
# indistinguishable to the caller. Worse than indistinguishable in one case:
# the cap on energy-non-conserving trajectories is reached inside MOBIL2, which
# runs after MOBIL4 has already printed a PA and an EHS cross section, so a
# failed helium run ended with two cross sections in the output file, in the
# format a real run prints them, and status 0.
#
# v1.2 converted every one of them. The one bare stop left in each file is the
# normal end of the main program, and it is the only path that exits 0. Each
# converted site also echoes its message to unit 6, because a refusal that
# reaches only the output file is invisible to anyone running a batch and
# watching a terminal.
#
# This gate drives every one of those sites that a small input can reach, and
# asserts three things about each: a nonzero exit status, the message in both
# the output file and on the console, and -- where it applies -- that no cross
# section was printed.
#
#
# THE CLASSIFICATION, WHICH IS THE THING TO GET RIGHT
#
# mobcal_He.f has eight terminations and mobcal_N2.f seven. They are not all
# the same kind of thing, and the gate is shaped by the difference.
#
#   MAIN     normal end                          exits 0, and must keep doing so
#   FCOORD   units not specified                 refusal, before any arithmetic
#   FCOORD   charge distribution not specified   refusal, before any arithmetic
#   LJPARM   type not defined for atom number    refusal, before any arithmetic
#   NCOORD   masses do not add up                refusal, but see below
#   GSANG    the ifail cap                       failure, mid-calculation (He)
#   MOBIL2   Problem orientating along x axis    failure, mid-calculation
#   MOBIL2   ibst greater than 500               failure, mid-calculation
#
# mobcal_N2.f's energy-conservation block, the GSANG one, is commented out in
# the source as it shipped, which is why that file has seven and not eight. The
# gate asserts that it is still commented out rather than silently running one
# case fewer there: re-enabling it should be noticed here.
#
# The last two are numerical-consistency assertions rather than input errors.
# Neither is reachable by any small input -- the first fires only if a rotation
# fails to put the longest axis on x, the second only if the collision integral
# has not converged after 500 steps of the impact-parameter search. They were
# converted with the rest, on the grounds that a failure reporting success is
# the defect being repaired and it does not matter whose fault the failure is,
# but nothing below drives them. The static check at the end of each gas block
# is what covers them: exactly one bare stop may survive in each file, and it
# must be the one in the main program. A future termination written as a bare
# stop fails that check wherever it is added.
#
#
# WHY ONE CASE USES A PROBE AND THE OTHERS DO NOT
#
# NCOORD's `masses do not add up' guards the conformers after the first, and
# NCOORD is called from the main loop only after MOBIL4 and MOBIL2 have both
# run to completion on the conformer before it. So driving it through the real
# binary costs a whole trajectory calculation, and there is no cheap one: the
# trajectory counts are hardcoded, and an ion small enough to be quick is an
# ion whose trajectories stop conserving energy, which lands on the ifail cap
# instead. Measured: the smallest fixture that gets through conformer 1 at all
# is methane, at 61 s on helium and 14 minutes on nitrogen.
#
# So that one case is driven through the same probe test/elements.sh uses --
# the real FCOORD and the real NCOORD from the real source file, called
# directly by a generated main program, with no trajectory anywhere. It costs
# milliseconds. The driver lives in test/probe-driver.sh, shared between the
# two gates rather than copied into both.
#
# The ifail case, by contrast, is driven through the real binary and is quick
# precisely because the ion is too small: a water-sized ion reaches the cap of
# 100 failed trajectories in well under a second. That case depends on
# trajectory arithmetic, which is admissible here for the same reason
# test/regression.sh's whole-file tier is: this code is byte-reproducible
# across the platforms in test/strict-platforms, so "the hundredth trajectory
# fails" is as portable a fact as any other number it prints.

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK="$ROOT/test/_refusals"

GASES="he n2"
KEEP=0

while [ $# -gt 0 ]; do
    case "$1" in
        --gas)  GASES=$2; shift 2 ;;
        --keep) KEEP=1; shift ;;
        -h|--help)
            sed -n '/^# Usage:/,/^# Environment:/p' "$0" | sed 's/^#\{1,\} \{0,1\}//'
            exit 0 ;;
        *) echo "refusals.sh: unknown argument '$1'" >&2; exit 2 ;;
    esac
done

. "$ROOT/test/build-flags.sh"
. "$ROOT/test/probe-driver.sh"
require_compiler

rm -rf "$WORK"
mkdir -p "$WORK"

echo "MOBCAL-2012 exit-status gate"
echo "  platform     : $PLATFORM ($(uname -s -m))"
echo "  compiler     : $FC -- $("$FC" --version 2>/dev/null | head -1)"
echo "  flags        : $FFLAGS $LDFLAGS"
echo

FAILED=0
pass=0
fail=0

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

# --- fixtures --------------------------------------------------------------
#
# Generated rather than committed, as in test/bounds.sh. All of them are five
# columns and `calc': mobcal_N2.f has its `if(dchar.eq.calc)' branch commented
# out and reads the charge column unconditionally, so a four-column file is an
# end-of-file error there rather than the refusal under test.

atom() { printf '%12.5f%13.5f%13.5f%4d%15.6f\n' "$1" "$2" "$3" "$4" "$5"; }

# Two atoms, and a header field the caller chooses. Everything the three FCOORD
# and LJPARM refusals need: the refusal fires on the header or on the mass key,
# never on the geometry.
write_header_case() {
    out=$1; units=$2; charge=$3; key2=$4; label=$5
    { echo "refusal gate: $label"
      echo 1
      echo 2
      echo "$units"
      echo "$charge"
      echo 1.0000
      atom 0.0 0.0 0.0 12 0.0
      atom 1.0 1.1 1.2 "$key2" 0.0
    } > "$out"
}

# Two coordinate sets whose compositions differ by one atom: carbon in set 1,
# nitrogen in set 2. Both keys are defined in both gases, so the only thing
# that can refuse this file is the mass comparison itself. The geometry is
# identical between the sets, for the same reason test/silicon-2conf.mfj's is:
# it leaves composition as the only variable.
masses_block() {
    atom 0.00000 0.00000 0.00000 12 0.0
    atom 1.20000 0.00000 0.00000 "$1" 0.0
    atom 0.00000 1.30000 0.00000 12 0.0
    atom 0.00000 0.00000 1.40000 12 0.0
}

write_masses_case() {
    { echo "refusal gate: conformer 2 has a different composition"
      echo 2
      echo 4
      echo ang
      echo calc
      echo 1.0000
      masses_block 12
      echo "conformer 2"
      masses_block "$2"
    } > "$1"
}

# A water-sized ion. Small enough that the impact-parameter search runs into
# trajectories that do not conserve energy to within 1%, which is the only
# cheap way to reach GSANG's cap. Nothing about the geometry is meant to be
# physical beyond that.
write_ifail_case() {
    { echo "refusal gate: an ion small enough that trajectories fail"
      echo 1
      echo 3
      echo ang
      echo calc
      echo 1.0000
      atom  0.00000  0.00000  0.11730 16 0.0
      atom  0.00000  0.75700 -0.46920  1 0.5
      atom  0.00000 -0.75700 -0.46920  1 0.5
    } > "$1"
}

# --- the static check ------------------------------------------------------
#
# Every line outside a comment that uses `stop' as a statement. One per file is
# the whole rule, and it has to be the one in the main program.
bare_stops() {
    awk 'substr($0,1,1) ~ /[cC*!]/ { next }
         $0 ~ /(^|[^a-zA-Z0-9_])stop([^a-zA-Z0-9_]|$)/ { print NR }' "$1"
}

# --- per gas ---------------------------------------------------------------

for gas in $GASES; do
    case "$gas" in
        he) src=mobcal_He.f ; has_ifail=y ;;
        n2) src=mobcal_N2.f ; has_ifail=n ;;
        *)  echo "refusals.sh: unknown gas '$gas'" >&2; exit 2 ;;
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

    # --- the source itself, before anything is run ------------------------

    n_stop=$(bare_stops "$ROOT/$src" | wc -l | tr -d ' ')
    ln_stop=$(bare_stops "$ROOT/$src" | head -1)
    first_sub=$(awk '/^      subroutine /{print NR; exit}' "$ROOT/$src")
    echo "  --- source ---"
    check "exactly one bare stop survives in $src (found $n_stop)" \
          "$(status "$n_stop" 1)"
    if [ "$n_stop" -eq 1 ]; then
        # The main program is the first program unit in both files, so a line
        # number below the first `subroutine' statement is inside it.
        check "and it is in the main program (line $ln_stop, FCOORD at $first_sub)" \
              "$(if [ "$ln_stop" -lt "$first_sub" ]; then echo y; else echo n; fi)"
    else
        bare_stops "$ROOT/$src" | sed 's/^/      bare stop at line /'
        check "and it is in the main program" n
    fi

    # The one termination that differs between the two files. Asserting it here
    # means re-enabling it in mobcal_N2.f fails this gate, rather than quietly
    # leaving that file with an untested exit path.
    c_ifail=$(grep -c '^c *if(ifailc\.eq\.ifail)' "$ROOT/$src" || true)
    if [ "$has_ifail" = y ]; then
        check "the energy-conservation cap is live (0 commented-out copies)" \
              "$(status "$c_ifail" 0)"
    else
        check "the energy-conservation cap is commented out, so no case for it" \
              "$(status "$c_ifail" 1)"
    fi

    # --- the refusals the real binary reaches directly --------------------

    write_header_case "$d/units.mfj"  nosuchunit calc       12 "units keyword misspelt"
    write_header_case "$d/charge.mfj" ang        nosuchmode 12 "charge keyword misspelt"
    write_header_case "$d/type.mfj"   ang        calc       99 "undefined mass key"
    write_ifail_case  "$d/ifail.mfj"

    cases="units charge type"
    if [ "$has_ifail" = y ]; then cases="$cases ifail"; fi

    for case_name in $cases; do
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
        units)   re='units not specified' ;;
        charge)  re='charge distribution not specified' ;;
        type)    re='type not defined for atom number +2 \(mass key +99\)' ;;
        ifail)   re='ERROR: +100 trajectories failed to conserve energy' ;;
        esac

        check "exit status is nonzero"              "$(nonzero "$st")"
        check "the message is in the output file"   "$(present "$re" "$O")"
        check "the message reaches the console too" "$(present "$re" "$S")"

        case "$case_name" in
        units|charge|type)
            check "no cross section was printed"    "$(absent 'cross section' "$O")"
            ;;
        ifail)
            # Not a mistake, and not a weaker assertion than the others: this
            # case exists because the run DID print cross sections and then
            # failed. Two of them, from MOBIL4, before MOBIL2 ever started.
            # Nothing in the file says they belong to an abandoned run, so the
            # exit status is the only thing that can.
            check "MOBIL4's cross sections were printed before the failure" \
                  "$(present 'average PA cross section' "$O")"
            check "no trajectory-method cross section was reached" \
                  "$(absent 'average TM cross section' "$O")"
            # The one thing left in the output file that distinguishes an
            # abandoned run from a finished one, and the reason README.md's
            # *Exit status* can tell anyone auditing pre-v1.2 output files to
            # look for it. Asserted here so that claim is gated rather than
            # merely written down.
            check "the run never reached its SUMMARY block" \
                  "$(absent 'SUMMARY' "$O")"
            ;;
        esac
    done

    # --- the refusal that needs the probe ---------------------------------

    if ! strip_subprograms "$ROOT/$src" "$d/subs.f"; then
        echo "  FAILED to isolate the subprograms of $src"
        FAILED=1
        continue
    fi
    cp "$ROOT/mobcal_limits.inc" "$d/"
    write_driver "$ROOT/$src" "$d/ljprobe.f"
    # shellcheck disable=SC2086
    if ! ( cd "$d" && "$FC" $FFLAGS $LDFLAGS -o ljprobe subs.f ljprobe.f ) \
            > "$d/probe-build.log" 2>&1; then
        echo "  PROBE BUILD FAILED:"
        sed 's/^/      /' "$d/probe-build.log"
        FAILED=1
        continue
    fi

    write_masses_case "$d/masses.mfj" 14
    printf '%s\n%s\n%s\n' masses.mfj ljprobe.out 96 > "$d/mobcal.in"
    if ( cd "$d" && ./ljprobe > masses.stdout 2>&1 ); then st=0; else st=$?; fi
    O="$d/ljprobe.out"
    S="$d/masses.stdout"
    [ -f "$O" ] || : > "$O"
    [ -f "$S" ] || : > "$S"
    echo "  --- masses, through the probe (exit $st) ---"
    check "exit status is nonzero"              "$(nonzero "$st")"
    check "the message is in the output file"   "$(present 'masses do not add up' "$O")"
    check "the message reaches the console too" "$(present 'masses do not add up' "$S")"
    # Four atoms in the fixture, one coordinate set dumped. Eight records would
    # mean NCOORD returned and the caller carried on with a conformer whose
    # composition is not the one the mass of the ion was computed from.
    got=$(grep -c . "$d/ljprobe.dat" || true)
    check "conformer 2 was refused, not used (4 records dumped, got $got)" \
          "$(status "$got" 4)"

    # The control: the same fixture with the composition left alone must get
    # through NCOORD and dump both sets. Without it, a guard that refused every
    # multi-conformer file would pass everything above.
    write_masses_case "$d/masses-ok.mfj" 12
    printf '%s\n%s\n%s\n' masses-ok.mfj ljprobe.out 96 > "$d/mobcal.in"
    if ( cd "$d" && ./ljprobe > masses-ok.stdout 2>&1 ); then st=0; else st=$?; fi
    echo "  --- masses control, same fixture unmodified (exit $st) ---"
    got=$(grep -c . "$d/ljprobe.dat" || true)
    check "exit status is 0"                    "$(status "$st" 0)"
    check "both coordinate sets were used (8 records dumped, got $got)" \
          "$(status "$got" 8)"
    check "no refusal fired" \
          "$(absent 'masses do not add up' "$d/ljprobe.out")"

    echo
done

echo "REFUSAL GATE: $pass passed, $fail failed"

if [ "$KEEP" -eq 0 ] && [ "$FAILED" -eq 0 ]; then
    rm -rf "$WORK"
else
    echo "Working directory kept: test/_refusals"
fi

if [ "$FAILED" -eq 0 ]; then
    echo "GATE: PASS"
else
    echo "GATE: FAIL"
fi
exit "$FAILED"
