#!/bin/sh
#
# test/elements.sh -- the per-element parameter gate.
#
# Usage:
#   test/elements.sh                 both gases
#   test/elements.sh --gas he        one gas
#   test/elements.sh --keep          keep test/_elements to inspect the probe
#
# Environment: FC and FFLAGS override the compiler and flags, as for the other
# two gates. The recipe itself lives in test/build-flags.sh.
#
#
# WHY THIS GATE EXISTS AT ALL
#
# The per-element table sets four things per atom: xmass, the Lennard-Jones
# well depth eolj, the Lennard-Jones radius rolj, and the hard-sphere radius
# rhs. Only xmass reaches a line of the deterministic output, via `mass of ion'
# and the centre of mass. The `Lennard-Jones scaling parameters' line in the
# header is hardcoded (eo=1.34d-03*xe), not derived from the table. So a wrong
# epsilon or sigma moves nothing test/regression.sh's first tier can see, and
# would have to be gross to move its second.
#
# Worse, the parameters cannot be printed at all for any coordinate set after
# the first. The per-atom LJ print is gated on iu1, which is hardcoded to 0 in
# the main program, and the print block exists only in FCOORD -- NCOORD has no
# such block. So no print switch, however set, can show conformer 2's
# parameters.
#
# That is precisely why chunk 3's shared table is a subroutine and not an
# include: a subroutine sits behind a callable interface, so a test driver can
# reach it and read out what it did. This script is the payment on that choice.
#
#
# WHAT IS BEING TESTED
#
# Before v1.1 each source file wrote the element table out twice -- once in
# FCOORD, which serves coordinate set 1, and once in NCOORD, which serves sets
# 2...icoord. The two copies had already diverged. In mobcal_N2.f, NCOORD's
# silicon row held iron's epsilon and sigma verbatim (0.0130 / 2.9120 against
# FCOORD's 0.4020 / 4.2950), under a comment still reading "silicon (from
# fitting mobilities of small silicon clusters)". Any multi-conformer nitrogen
# run containing silicon therefore used iron's parameters for every conformer
# after the first, and nothing in the output said so.
#
# The input is two identical coordinate sets. Identical on purpose: it holds
# the geometry fixed so that the only thing that can differ between the sets is
# the table that was consulted. Every atom must come out of set 2 with exactly
# the parameters it came out of set 1 with.
#
# The value assertions are the other half. Identity alone would also be
# satisfied by a merge that adopted the wrong silicon row in both places, so
# the gate also pins silicon to the row the release adopted. FCOORD's
# 0.4020/4.2950 is the correct one, and that is settled: NCOORD's numbers are
# iron's exactly in both parameters; silicon's neighbours corroborate FCOORD
# (sulfur, commented "same as silicon", is 0.2740/4.0350, and phosphorus is
# 0.305/4.1470 -- nothing like 0.0130/2.9120); that block already carries
# copy-paste damage, with phosphorus and fluorine both sitting under the
# comment "iron (same as silicon)"; and FCOORD's is the value every
# single-conformer nitrogen silicon run ever published used.
#
#
# CHUNK 4 -- Cl/Br/I (both gases) and Li/K/Cs (N2 only)
#
# One row per new element, added to the same LJPARM subroutine chunk 3 built,
# so the identity assertion above already covers them: an atom carrying one of
# the new mass keys must come out of set 2 with the same parameters it came out
# of set 1 with. test/new-elements-he.mfj and test/new-elements-n2.mfj add a
# second, disjoint fixture for this rather than growing the silicon one,
# because He does not define Li/K/Cs at all -- a shared fixture would refuse on
# He before reaching the assertions.
#
# Two further things chunk 4 introduced are not observable from parameter
# identity, so they get their own checks:
#
# - The three He halogens are PROVISIONAL (transformed from mobcal_N2.f's self
#   parameters by one factor, 0.8602 in both epsilon and sigma, rather than
#   independently fitted to He mobility data), and LJPARM prints a warning
#   naming the atom whenever one is actually used. All six new elements across
#   both files borrow carbon's 2.7 Angstrom hard-sphere radius rather than a
#   fitted one, which prints a second warning. Both warnings are counted
#   exactly (3 provisional atoms x 2 coordinate sets = 6 for He, and so on) --
#   not merely "present" -- because three *legacy* elements (nitrogen, oxygen,
#   fluorine) already carry the same borrowed 2.7 Angstrom value under their
#   own "(same as carbon)" comments, and the choline fixture regression.sh
#   checks contains nitrogen and oxygen. A warning keyed on the value 2.7
#   rather than on element identity would fire on every regression.sh run and
#   force an unplanned reference regeneration; counting it here on a fixture
#   that also carries legacy elements is what would catch that mistake.
#
# - The `type not defined for atom number' refusal (format 602) was rewritten
#   to name the mass key, state the nint(atomic weight) convention, list the
#   defined keys, and use i4 instead of i3 so a refusal past atom 999 (this
#   build's own array bound) prints the real number instead of an overflowed
#   or truncated one. test/elements.sh generates a throwaway 1,000-atom fixture
#   for exactly this, the same way test/bounds.sh generates its over-bound
#   fixtures rather than committing them.
#
#
# HOW THE PROBE IS BUILT
#
# The two sources each open with an unnamed main program, so they cannot be
# linked against a test driver as they stand. The script takes everything from
# the first `subroutine' statement onward -- which is FCOORD, the first
# subprogram in both files -- and compiles that against a driver of its own.
# The driver is the main program the real code would otherwise be: it sets the
# handful of constants FCOORD and NCOORD read out of COMMON, calls FCOORD for
# set 1 and NCOORD for each set after it, and writes out eolj, rolj and rhs as
# they stand after each call.
#
# It therefore exercises the real subroutines from the real source file. There
# is no second copy of the table anywhere in this script, which is the property
# chunk 3 exists to establish.
#
# The cost is milliseconds, because none of this runs a trajectory. That is
# what lets the gate run on every platform in CI. The expensive end-to-end
# confirmation -- a full two-conformer nitrogen run whose two cross sections
# must agree -- was run by hand for the commit that introduced this file and
# recorded there; it is not repeated per push.
#
# One driver binary serves every probe run in a gas's block: LJPROBE reads its
# input filename from mobcal.in (unit 20) at start-up, so re-writing mobcal.in
# and re-running the same executable switches fixtures without rebuilding. Unit
# 7 (ljprobe.dat) and unit 8 (ljprobe.out) are fixed filenames the driver opens
# itself, so each run's outputs must be read before the next run overwrites
# them -- the script does so in fixture order.

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK="$ROOT/test/_elements"
MFJ="$ROOT/test/silicon-2conf.mfj"

GASES="he n2"
KEEP=0

while [ $# -gt 0 ]; do
    case "$1" in
        --gas)  GASES=$2; shift 2 ;;
        --keep) KEEP=1; shift ;;
        -h|--help)
            sed -n '/^# Usage:/,/^# Environment:/p' "$0" | sed 's/^#\{1,\} \{0,1\}//'
            exit 0 ;;
        *) echo "elements.sh: unknown argument '$1'" >&2; exit 2 ;;
    esac
done

. "$ROOT/test/build-flags.sh"
require_compiler

# The fixture's own header is the authority on its shape, so editing the fixture
# cannot quietly turn the count assertions into tests of nothing.
NCRD=$(sed -n '2p' "$MFJ" | tr -d ' \r')
NATOM=$(sed -n '3p' "$MFJ" | tr -d ' \r')
case "$NCRD$NATOM" in
    *[!0-9]*|"") echo "elements.sh: cannot read the counts from $MFJ" >&2; exit 2 ;;
esac
[ "$NCRD" -ge 2 ] || { echo "elements.sh: fixture must have 2 or more coordinate sets" >&2; exit 2; }

rm -rf "$WORK"
mkdir -p "$WORK"

echo "MOBCAL-2012 element-table gate"
echo "  platform     : $PLATFORM ($(uname -s -m))"
echo "  compiler     : $FC -- $("$FC" --version 2>/dev/null | head -1)"
echo "  flags        : $FFLAGS $LDFLAGS"
echo "  fixture      : test/$(basename "$MFJ") -- $NCRD coordinate sets, $NATOM atoms"
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

# Every atom must come out of every coordinate set with the parameters it came
# out of set 1 with -- text comparison, since the same table evaluated twice
# cannot round differently.
identical_across_sets() {
    awk '{ key = $2
           if ($1 == 1) { ref[key] = $3 " " $4 " " $5; next }
           if (!(key in ref)) { bad++; next }
           if (ref[key] != $3 " " $4 " " $5) bad++ }
        END { print (bad ? "n" : "y") }' "$1"
}

# Pins one atom's set-1 record to expected (eps, sigma, rhs) within 1e-4
# relative -- loose on purpose, see the silicon comment below for why.
pin_atom() {
    dat=$1; pos=$2; e=$3; s=$4; h=$5
    awk -v pos="$pos" -v e="$e" -v s="$s" -v h="$h" \
        '$1 == 1 && $2 == pos {
             ok = 1
             if (($3 - e) / e >  1e-4 || ($3 - e) / e < -1e-4) ok = 0
             if (($4 - s) / s >  1e-4 || ($4 - s) / s < -1e-4) ok = 0
             if (($5 - h) / h >  1e-4 || ($5 - h) / h < -1e-4) ok = 0
             print (ok ? "y" : "n"); seen = 1
         }
         END { if (!seen) print "n" }' "$dat"
}

# --- the driver ------------------------------------------------------------
#
# Generated rather than committed because one line of it differs between the
# two gases: mobcal_N2.f carries xeo in common/constants/ and mobcal_He.f does
# not, and a COMMON block declared with the wrong layout would silently shift
# every variable after the mismatch. Taking that line from the source file
# being probed means it cannot drift.

write_driver() {
    src=$1
    out=$2
    # The continuation line of common/constants/, lifted from the source under
    # test rather than restated here.
    constants=$(sed -n '/^      common\/constants\/mu,ro,eo,pi,cang/{
                            n
                            p
                            q
                        }' "$src")
    [ -n "$constants" ] || { echo "elements.sh: cannot read common/constants/ from $src" >&2; exit 2; }
    {
        cat <<'PROLOGUE'
c
c     ljprobe -- generated by test/elements.sh; not part of the program.
c
c     Stands in for the main program so that FCOORD and NCOORD can be called
c     directly, and writes out the per-element parameters each call left in
c     COMMON. Unit 7 is the probe's data file, unit 8 is the output file the
c     two subroutines expect to be open.
c
      implicit double precision (a-h,m-z)
      include 'mobcal_limits.inc'
      character*30 filen1,unit,dchar,xlabel
      common/printswitch/ip,it,iu1,iu2,iu3,iv,im2,im4,igs
      common/constants/mu,ro,eo,pi,cang,ro2,dipol,emax,m1,m2,
PROLOGUE
        echo "$constants"
        cat <<'BODY'
      common/xrandom/i1,i2,i3,i4,i5,i6
c
      open(20,file='mobcal.in')
      read(20,'(a30)') filen1
      close (20)
c
      ip=0
      it=0
      iu1=0
      iu2=0
      iu3=0
      iv=0
      im2=0
      im4=0
      igs=0
c
      pi=3.14159265358979323846d0
      cang=180.d0/pi
      xe=1.60217733d-19
      xk=1.380658d-23
      xn=6.0221367d23
c
      open (8,file='ljprobe.out')
      open (7,file='ljprobe.dat')
c
      call fcoord(filen1,unit,dchar,xlabel,asymp)
      iic=1
      call ljdump(1)
      do 1000 ic=2,icoord
      iic=ic
      call ncoord(unit,dchar,asymp)
      call ljdump(ic)
 1000 continue
c
      close (7)
      close (8)
      stop
      end
c
c     ***************************************************************
c
      subroutine ljdump(ic)
c
c     One record per atom: coordinate set, atom index, then the three
c     quantities the element table sets that live in COMMON -- the LJ well
c     depth in eV, the LJ radius in angstroms, and the hard-sphere radius in
c     angstroms.
c
      implicit double precision (a-h,m-z)
      include 'mobcal_limits.inc'
      common/constants/mu,ro,eo,pi,cang,ro2,dipol,emax,m1,m2,
BODY
        echo "$constants"
        cat <<'EPILOGUE'
      common/ljparameters/eolj(len),rolj(len),eox4(len),
     ?ro6lj(len),ro12lj(len),dro6(len),dro12(len)
      common/hsparameters/rhs(len),rhs2(len)
c
      do 1000 iatom=1,inatom
 1000 write(7,600) ic,iatom,eolj(iatom)/xe,rolj(iatom)*1.0d10,
     ?rhs(iatom)*1.0d10
  600 format(i5,i5,3(1x,1pe22.15))
c
      return
      end
EPILOGUE
    } > "$out"
}

# A throwaway 1,000-atom fixture (this build's own array bound, len=1000 in
# mobcal_limits.inc) whose last atom carries a mass key neither table defines.
# Generated rather than committed, the same reasoning as test/bounds.sh's
# over-bound fixtures: it is real filler, not hand-typed geometry, and
# regenerating it if the bound ever changes costs nothing.
write_undefined_1000() {
    out=$1
    { echo "elements gate: undefined key at atom number 1000 (i4 fix)"
      echo 1
      echo 1000
      echo ang
      echo calc
      echo 1.0000
      awk 'BEGIN{
          for (i = 1; i <= 999; i++)
              printf "%12.5f%13.5f%13.5f%4d%15.6f\n", i * 0.1, 0.0, 0.0, 1, 0.1
          printf "%12.5f%13.5f%13.5f%4d%15.6f\n", 100.0, 0.0, 0.0, 999, 0.1
      }'
    } > "$out"
}

# --- per gas ---------------------------------------------------------------
#
# Expected silicon values. The tolerance only has to separate the two candidate
# rows, which differ by a factor of 5.6 in epsilon and 21 % in sigma, so 1e-4
# relative is decisive with room to spare. It is not tighter than that on
# purpose: the nitrogen table multiplies a double by single-precision literals
# such as 0.4020, so the last few digits are a property of the literal's
# single-precision rounding rather than of the parameter. The same tolerance
# is used below for the new elements' pinned values, computed in double
# precision from Iain's per-element factors; the single-precision rounding
# those literals pick up in the real build is on the order of 1e-7 relative,
# well inside this margin.

for gas in $GASES; do
    case "$gas" in
        he) src=mobcal_He.f
            si_eps=1.35e-3 ; si_sig=3.5        ; si_rhs=2.95
            itest_want=12 ; prov_want=6 ; borrow_want=6 ;;
        n2) src=mobcal_N2.f
            si_eps=7.249792567e-3 ; si_sig=3.532242086 ; si_rhs=2.95
            itest_want=16 ; prov_want=0 ; borrow_want=12 ;;
        *)  echo "elements.sh: unknown gas '$gas'" >&2; exit 2 ;;
    esac

    d="$WORK/$gas"
    mkdir -p "$d"
    echo "=== $gas ============================================================"

    # One element table per source file, not a reintroduced second copy: every
    # itest=1 line belongs to exactly one row of exactly one table.
    got_itest=$(grep -c '^ *itest=1$' "$ROOT/$src")
    check "exactly one element table ($got_itest itest=1 lines, want $itest_want)" \
          "$(status "$got_itest" "$itest_want")"

    # Everything from the first subroutine statement on. The main program is
    # the first program unit in both files and FCOORD is the second, so this
    # drops exactly the main program.
    sed -n '/^      subroutine /,$p' "$ROOT/$src" > "$d/subs.f"
    # FCOORD must be the first thing left, which is what says the main program
    # and nothing else was dropped. If the file is ever restructured so that
    # some other subprogram comes first, this fails loudly instead of quietly
    # compiling a probe with a stowaway main program in it.
    if ! head -1 "$d/subs.f" | grep -q '^      subroutine fcoord('; then
        echo "  FAILED to isolate the subprograms of $src:"
        echo "      expected the first remaining line to be subroutine fcoord,"
        echo "      got: $(head -1 "$d/subs.f")"
        FAILED=1
        continue
    fi
    # gfortran resolves an include relative to the directory of the source
    # file, so the include has to sit beside the stripped copy.
    cp "$ROOT/mobcal_limits.inc" "$d/"
    write_driver "$ROOT/$src" "$d/ljprobe.f"

    echo "  building     : $FC $FFLAGS $LDFLAGS -o ljprobe subs.f ljprobe.f"
    # shellcheck disable=SC2086
    if ! ( cd "$d" && "$FC" $FFLAGS $LDFLAGS -o ljprobe subs.f ljprobe.f ) \
            > "$d/build.log" 2>&1; then
        echo "  BUILD FAILED:"
        sed 's/^/      /' "$d/build.log"
        FAILED=1
        continue
    fi
    echo "  warnings     : $(grep -c '^Warning:' "$d/build.log" || true)"

    # --- silicon, two identical conformers (chunk 3's original fixture) ----

    cp "$MFJ" "$d/silicon.mfj"
    printf '%s\n%s\n%s\n' silicon.mfj ljprobe.out 96 > "$d/mobcal.in"
    if ( cd "$d" && ./ljprobe > probe.stdout 2>&1 ); then st=0; else st=$?; fi
    DAT="$d/ljprobe.dat"
    [ -f "$DAT" ] || : > "$DAT"

    echo "  --- probe: silicon (exit $st) ---"

    if [ "$st" -ne 0 ]; then
        check "the probe ran" n
        sed 's/^/      /' "$d/probe.stdout"
        echo
        continue
    fi
    check "the probe ran" y

    want=$((NCRD * NATOM))
    got=$(grep -c . "$DAT" || true)
    check "every coordinate set was reached ($got of $want records)" \
          "$(status "$got" "$want")"

    # The headline assertion. Set 1's record for each atom is the referent;
    # every later set must reproduce all three values exactly.
    check "every atom has identical parameters in every coordinate set" \
          "$(identical_across_sets "$DAT")"

    # Silicon is atom 1 of the fixture. Assert on it in set 1, which is the
    # set that was always right, so this pins the value the merge adopted
    # rather than merely agreeing with whatever set 2 produced.
    check "silicon carries the adopted well depth, radius and hard-sphere radius" \
          "$(pin_atom "$DAT" 1 "$si_eps" "$si_sig" "$si_rhs")"

    # Neither of chunk 4's warnings has any business firing here: this fixture
    # carries only hydrogen and silicon, neither provisional nor new. Nitrogen,
    # oxygen and fluorine -- which DO already carry the same borrowed 2.7
    # Angstrom hard-sphere radius under "(same as carbon)" -- aren't in this
    # fixture either, so this is only a first line of defence; the real test
    # of that distinction is the new-elements fixture below, which contains
    # them.
    check "no chunk-4 warning fires on legacy-only elements" \
          "$(absent 'WARNING' "$d/ljprobe.out")"

    # Refusals still work: the table's own `type not defined' stop moved into
    # the shared subroutine along with the rows, so it has to still fire, now
    # naming the mass key and the nint(atomic weight) convention rather than
    # just the atom number.
    sed 's/  28  /  99  /' "$MFJ" > "$d/undefined.mfj"
    printf '%s\n%s\n%s\n' undefined.mfj ljprobe.out 96 > "$d/mobcal.in"
    ( cd "$d" && ./ljprobe > undefined.stdout 2>&1 ) || true
    r=y
    [ "$(present 'type not defined for atom number' "$d/ljprobe.out")" = y ] || r=n
    [ "$(present 'nint\(atomic weight\)'             "$d/ljprobe.out")" = y ] || r=n
    [ "$(present '\(mass key *99\)'                  "$d/ljprobe.out")" = y ] || r=n
    check "an undefined element is refused, naming the mass key and the key convention" "$r"

    # --- the six new elements, plus the legacy elements that share their
    # --- borrowed hard-sphere radius ---------------------------------------

    cp "$ROOT/test/new-elements-$gas.mfj" "$d/new-elements.mfj"
    printf '%s\n%s\n%s\n' new-elements.mfj ljprobe.out 96 > "$d/mobcal.in"
    if ( cd "$d" && ./ljprobe > newelements.stdout 2>&1 ); then st2=0; else st2=$?; fi

    echo "  --- probe: new elements (exit $st2) ---"

    if [ "$st2" -ne 0 ]; then
        check "the new-elements probe ran" n
        sed 's/^/      /' "$d/newelements.stdout"
        echo
        continue
    fi
    check "the new-elements probe ran" y

    check "new elements: identical parameters in every coordinate set" \
          "$(identical_across_sets "$DAT")"

    # Atom positions in test/new-elements-$gas.mfj: 1-4 are the legacy
    # carbon/nitrogen/oxygen/fluorine rows (present so the warning-count
    # assertions below can prove the borrowed-rhs warning does NOT fire on
    # them); everything from position 5 on is new.
    case "$gas" in
        he)
            check "chlorine pinned to Iain's parameters" \
                  "$(pin_atom "$DAT" 5 7.8742e-3  3.1576 2.7)"
            check "bromine  pinned to Iain's parameters" \
                  "$(pin_atom "$DAT" 6 8.7067e-3  3.3512 2.7)"
            check "iodine   pinned to Iain's parameters" \
                  "$(pin_atom "$DAT" 7 11.759e-3  3.6000 2.7)"
            ;;
        n2)
            check "chlorine  pinned to Iain's parameters" \
                  "$(pin_atom "$DAT" 5  5.2535959769e-3 3.2654521375 2.7)"
            check "bromine   pinned to Iain's parameters" \
                  "$(pin_atom "$DAT" 6  5.5241184196e-3 3.3640437045 2.7)"
            check "iodine    pinned to Iain's parameters" \
                  "$(pin_atom "$DAT" 7  6.4205841070e-3 3.4867162664 2.7)"
            check "lithium   pinned to Iain's parameters" \
                  "$(pin_atom "$DAT" 8  1.8079339426e-3 2.6683361029 2.7)"
            check "potassium pinned to Iain's parameters" \
                  "$(pin_atom "$DAT" 9  2.0645307417e-3 3.2093253462 2.7)"
            check "caesium   pinned to Iain's parameters" \
                  "$(pin_atom "$DAT" 10 2.3405588512e-3 3.4932919198 2.7)"
            ;;
    esac

    # Counted, not merely detected -- see the header comment on why "fires at
    # all" would not distinguish the new elements from the legacy ones that
    # happen to share the same 2.7 Angstrom hard-sphere radius. Each of the
    # NCRD identical coordinate sets re-triggers every warning once.
    pc=$(grep -c 'WARNING: provisional'      "$d/ljprobe.out" || true)
    bc=$(grep -c 'borrowed from carbon'      "$d/ljprobe.out" || true)
    check "provisional-parameter warning fires exactly $prov_want time(s) (got $pc)" \
          "$(status "$pc" "$prov_want")"
    check "borrowed-hard-sphere-radius warning fires exactly $borrow_want time(s) (got $bc)" \
          "$(status "$bc" "$borrow_want")"

    # --- an undefined key past atom 999, to catch the i4/i3 truncation -----

    write_undefined_1000 "$d/undefined-1000.mfj"
    printf '%s\n%s\n%s\n' undefined-1000.mfj ljprobe.out 96 > "$d/mobcal.in"
    if ( cd "$d" && ./ljprobe > undefined1000.stdout 2>&1 ); then st4=0; else st4=$?; fi
    r=y
    [ "$(present '(^|[^0-9])1000([^0-9]|$)'          "$d/ljprobe.out")" = y ] || r=n
    [ "$(present 'type not defined for atom number'  "$d/ljprobe.out")" = y ] || r=n
    [ "$(absent  '\*\*\*\*'                          "$d/ljprobe.out")" = y ] || r=n
    check "atom number 1000 is named without truncation or overflow (i4 fix)" "$r"
    check "exit status is 0 (pre-existing bare stop)" "$(status "$st4" 0)"

    echo
done

echo "ELEMENT GATE: $pass passed, $fail failed"

if [ "$KEEP" -eq 0 ] && [ "$FAILED" -eq 0 ]; then
    rm -rf "$WORK"
else
    echo "Working directory kept: test/_elements"
fi

if [ "$FAILED" -eq 0 ]; then
    echo "GATE: PASS"
else
    echo "GATE: FAIL"
fi
exit "$FAILED"
