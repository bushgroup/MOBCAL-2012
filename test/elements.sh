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
# - The three He halogens are PROVISIONAL -- UFF x_I and D_I scaled by 0.80 and
#   inserted directly as He-X pair parameters, skipping both the combining rule
#   with the gas and the r_min-to-sigma factor that mobcal_N2.f applies as
#   convr, on a factor no published source attests -- and LJPARM prints a
#   warning naming the atom whenever one is actually used. (Through chunk 4
#   this comment said the factor was 0.8602 against mobcal_N2.f's literals.
#   Those literals are themselves 0.93-scaled UFF; 0.80/0.93 = 0.8602. The
#   assertions below never depended on the number, only on the warning firing
#   the right number of times, which is why correcting it moved no test.)
#   All six new elements across
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
#
# V1.3 -- THE TABLE IS A FILE
#
# Since v1.3 there is no element table in either source file. LJPARM looks
# each mass key up in the table LJREAD (mobcal_ljread.inc) loaded at start-up
# from mobcal_He.params or mobcal_N2.params, and the rows in those files are
# the literals the Fortran carried through v1.2, spelled exactly as it spelled
# them: a token without a d exponent is read as a REAL(4), as the compiler read
# it, which is what keeps every value bit for bit what it was. Every assertion
# above still holds and still means what it meant -- it is the same probe
# calling the same FCOORD and NCOORD -- with two additions.
#
# The source check changes shape: instead of counting `itest=1' lines against
# the number of rows, it requires that NO `imass(iatom).eq.<key>' comparison
# survives in the source (a second table) and that the reader is included
# exactly once.
#
# And the gate can now read the table, so it no longer has to settle for the
# rows the committed fixtures happen to contain. A last block generates a
# fixture with one atom per row of the file and checks the probe's values for
# every row against the file's, the mass of that ion against the sum of the
# file's masses, the two warning counts against the file's own flag columns,
# and the key list the `type not defined' refusal prints -- written from the
# loaded table since v1.3 -- against the file's keys in order.
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
# Both the stripping and the driver live in test/probe-driver.sh since v1.2,
# because test/refusals.sh needs the same thing to reach NCOORD's `masses do
# not add up' refusal without paying for the previous conformer's complete
# calculation. Two copies of a driver is how a driver drifts, which is the
# argument that put the build recipe in test/build-flags.sh.
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
. "$ROOT/test/probe-driver.sh"
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
nonzero() { if [ "$1" -ne 0 ];    then echo y; else echo n; fi; }

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

# --- reading the parameter file ----------------------------------------------
#
# The rows of a parameter file: eight columns each, comment (#...) and
# provenance (|...) stripped, a trailing CR tolerated, in file order. Header
# lines are two tokens with the first ending in a colon and are excluded.
# A literal CR from printf rather than the escape '\r', for the reason
# test/regression.sh gives: BSD sed on macOS reads '\r' as a literal 'r' and
# would turn `form: pair' into `form: pai'.
CR=$(printf '\r')
param_lines() {
    sed -e "s/${CR}\$//" -e 's/#.*//' -e 's/|.*//' "$1"
}
param_rows() {
    param_lines "$1" | awk 'NF == 8 && $1 !~ /:$/'
}

# The value of one header key.
param_header() {
    param_lines "$1" | awk -v k="$2:" '$1 == k { print $2; exit }'
}

# The value of one Fortran literal, or two joined by one / or *, in awk's
# double precision. The d exponent becomes e for awk's strtod; the kind
# distinction the program preserves is below this gate's tolerance.
AWK_LIT='function lit(t,   n, a, b) {
             gsub(/[dD]/, "e", t)
             if ((n = index(t, "*")) > 0) { a = substr(t, 1, n - 1) + 0; b = substr(t, n + 1) + 0; return a * b }
             if ((n = index(t, "/")) > 0) { a = substr(t, 1, n - 1) + 0; b = substr(t, n + 1) + 0; return a / b }
             return t + 0
         }'

# One line per row: position in file order, then the well depth in eV, the
# radius in Angstrom and the hard-sphere radius in Angstrom that the program
# should hold for it -- the probe dumps exactly those three, in those units.
file_expected() {
    f=$1
    form=$(param_header "$f" form)
    param_rows "$f" | awk -v form="$form" \
        -v eog="$(param_header "$f" eogas)" -v rog="$(param_header "$f" rogas)" \
        -v cve="$(param_header "$f" conve)" -v cvr="$(param_header "$f" convr)" "$AWK_LIT"'
        BEGIN { if (form == "combining") { EOG = lit(eog); ROG = lit(rog); CVE = lit(cve); CVR = lit(cvr) } }
        {
            e = lit($4); s = lit($5); r = lit($6)
            if (form == "combining") { e = sqrt(EOG * e) * CVE; s = sqrt(ROG * s) * CVR }
            printf "%d %.10e %.10e %.10e\n", NR, e, s, r
        }'
}

# Every set-1 record of the probe dump against the expected values, by
# position, within 1e-4 relative; and every expected row must have a record.
rows_match() {
    awk 'function dev(a, b) { d = (a - b) / b; return d < 0 ? -d : d }
         NR == FNR { E[$1] = $2; S[$1] = $3; R[$1] = $4; n++; next }
         $1 == 1 { seen++
                   if (!($2 in E)) { bad++; next }
                   if (dev($3, E[$2]) > 1e-4 || dev($4, S[$2]) > 1e-4 || dev($5, R[$2]) > 1e-4) bad++ }
         END { print ((bad || seen != n) ? "n" : "y") }' "$1" "$2"
}

file_mass_sum() {
    param_rows "$1" | awk "$AWK_LIT"'{ m += lit($3) } END { printf "%.6e", m }'
}

rel_ok() {
    awk -v a="$1" -v b="$2" 'BEGIN { d = (a - b) / b; if (d < 0) d = -d; print (d <= 1e-4 ? "y" : "n") }'
}

# How many rows carry value $3 in column $2.
flag_count() {
    param_rows "$1" | awk -v c="$2" -v v="$3" '$c == v { n++ } END { print n + 0 }'
}

# One atom per row of the parameter file, in file order, along x, uncharged,
# and a second coordinate set identical to the first.
write_allkeys() {
    rows=$(param_rows "$1" | awk '{ print $1 }')
    n=$(echo "$rows" | wc -l | tr -d ' ')
    { echo "elements gate: one atom per row of $(basename "$1")"
      echo 2
      echo "$n"
      echo ang
      echo calc
      echo 1.0000
      echo "$rows" | awk '{ printf "%12.5f%13.5f%13.5f%4d%15.6f\n", NR * 0.5, 0.0, 0.0, $1, 0.0 }'
      echo "second coordinate set, identical to the first"
      echo "$rows" | awk '{ printf "%12.5f%13.5f%13.5f%4d%15.6f\n", NR * 0.5, 0.0, 0.0, $1, 0.0 }'
    } > "$2"
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
            si_eps16=1.350000000000000E-03
            prov_want=8 ; borrow_want=6 ;;
        n2) src=mobcal_N2.f
            si_eps=7.249792567e-3 ; si_sig=3.532242086 ; si_rhs=2.95
            si_eps16=7.249792657180476E-03
            prov_want=0 ; borrow_want=12 ;;
        *)  echo "elements.sh: unknown gas '$gas'" >&2; exit 2 ;;
    esac

    d="$WORK/$gas"
    mkdir -p "$d"
    # The element table itself (v1.3): what the probe reads at start-up, and
    # what the assertions below compare the probe against.
    params=$(params_for "$src")
    PARAMS="$ROOT/$params"
    cp "$PARAMS" "$d/"
    echo "=== $gas ============================================================"

    # No element table in the source at all since v1.3: the rows live in the
    # parameter file, and a `.eq.<key>' comparison against imass reappearing in
    # the Fortran would be a second table -- the thing chunk 3 removed. Through
    # v1.2 this counted `itest=1' lines against the number of rows instead.
    got_rows=$(grep -c 'imass(iatom)\.eq\.[0-9]' "$ROOT/$src" || true)
    check "no element row survives in $src ($got_rows imass(iatom).eq.<key> lines)" \
          "$(status "$got_rows" 0)"
    got_inc=$(grep -c "^      include 'mobcal_ljread.inc'" "$ROOT/$src" || true)
    check "$src includes the shared reader exactly once (got $got_inc)" \
          "$(status "$got_inc" 1)"

    if ! strip_subprograms "$ROOT/$src" "$d/subs.f"; then
        echo "  FAILED to isolate the subprograms of $src"
        FAILED=1
        continue
    fi
    # gfortran resolves an include relative to the directory of the source
    # file, so the includes have to sit beside the stripped copy.
    stage_probe_includes "$ROOT" "$d"
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

    # The kind rule, pinned to the digit. Since v1.3 the literal comes from a
    # text file and LJREAD must read it with the kind the compiler gave the
    # same spelling: 0.4020 (no d) as a REAL(4), 1.35d-3 as a REAL(8). The 1e-4
    # pin above cannot see that -- the two readings differ in the eighth
    # digit -- so silicon's well depth is also pinned as the 16-digit text the
    # probe prints, which is the value the compiled table produced (checked
    # bit for bit against the v1.2 build when the file was introduced). Read
    # 0.4020 as a double and the nitrogen value becomes 7.249792567...E-03;
    # read 1.35d-3 as a single and the helium value becomes 1.350000035...E-03.
    # Verified by mutation: reading everything as a double fails nitrogen's pin
    # and nothing else; reading everything as a single fails helium's, and
    # nitrogen's too, through the d0 header constants the combining rule uses.
    # As portable as T3's premise: the same double prints the same 16 digits.
    got16=$(awk '$1 == 1 && $2 == 1 { print $3 }' "$DAT")
    check "silicon's well depth is the single/double-kind value to 16 digits ($got16)" \
          "$(if [ "$got16" = "$si_eps16" ]; then echo y; else echo n; fi)"

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
    cp "$d/ljprobe.out" "$d/undefined.out"
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
            # Phosphorus is chunk 9's, built by the same UFF x 0.80 recipe
            # (0.305*0.80*43.360 = 10.57984 meV, 4.147*0.80 = 3.3176 A) but
            # carrying its own 4.2 A hard-sphere radius rather than carbon's
            # 2.7.  That is what makes the two warning counts below differ.
            check "phosphorus pinned to the UFF x 0.80 construction" \
                  "$(pin_atom "$DAT" 8 10.580e-3  3.3176 4.2)"
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
    #
    # Since chunk 9 the two He counts DIFFER, and that is the point. Four rows
    # are provisional (Cl, Br, I, P) but only three borrow carbon's radius --
    # phosphorus's 4.2 Angstrom is its own. So the two warnings no longer fire
    # on the same set of rows, and a mistake in either direction moves exactly
    # one count: a new row that borrowed 2.7 without saying so raises
    # borrow_want, and a row added on the 0.80 factor without the PROVISIONAL
    # warning lowers prov_want. While the two sets coincided, neither error was
    # visible here.
    #
    # Verified by mutation, both directions. Deleting phosphorus's write(8,603)
    # takes prov_want 8 -> 6 and leaves borrow_want at 6; giving phosphorus
    # carbon's 2.7 Angstrom and the matching write(8,604) takes borrow_want
    # 6 -> 8, leaves prov_want at 8, and also trips the pin above. One failure
    # each, on the count that should move.
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
    # Nonzero since v1.2. Through v1.1 this refusal was one of the bare stops
    # that exit 0, and this assertion read `exit status is 0'. It is the same
    # refusal on the same input; only the status changed. test/refusals.sh is
    # where that change is gated properly, on the real binary as well as here.
    check "exit status is nonzero (the refusal reaches the caller)" \
          "$(nonzero "$st4")"

    # --- the file against the probe, every row -----------------------------
    #
    # Everything above exercises only the rows the committed fixtures happen
    # to contain -- four of thirteen (He) or ten of sixteen (N2) in the first
    # two fixtures, none in the third. Since v1.3 the table is a file, so the
    # gate can read it: this block generates a fixture with one atom per row
    # of the file, in file order, two identical coordinate sets, and asserts
    # that what the probe reads back for each atom is what the file says,
    # evaluated here by the form the file declares (pair: the literal itself;
    # combining: sqrt(eogas*e)*conve and sqrt(rogas*s)*convr) in awk's double
    # precision, within the 1e-4 tolerance the pins above use. The file's
    # single-precision literals round at ~1e-7 relative, well inside it. A row
    # no fixture contains is therefore no longer a row no gate reads.
    #
    # The same block checks the three things the file now determines that the
    # pins above cannot: the mass (the one per-atom quantity the probe cannot
    # dump, so the output file's `mass of ion' is compared with the sum of the
    # file's masses), the warning counts against the file's own flag columns
    # (the hardcoded 8/6 and 0/12 above pin those flags to what v1.1 decided;
    # this pins the program to whatever the file says), and the key list in
    # the `type not defined' refusal, which is written from the loaded table
    # and must therefore be the file's keys in the file's order -- the claim
    # v1.2 withdrew as ungated when the list was a hardcoded string.
    write_allkeys "$PARAMS" "$d/allkeys.mfj"
    NKEYS=$(sed -n '3p' "$d/allkeys.mfj" | tr -d ' \r')
    printf '%s\n%s\n%s\n' allkeys.mfj ljprobe.out 96 > "$d/mobcal.in"
    if ( cd "$d" && ./ljprobe > allkeys.stdout 2>&1 ); then st5=0; else st5=$?; fi
    cp "$d/ljprobe.out" "$d/allkeys.out"

    echo "  --- probe: every row of $params ($NKEYS rows, exit $st5) ---"

    check "the all-keys probe ran" "$(status "$st5" 0)"
    want=$((2 * NKEYS))
    got=$(grep -c . "$DAT" || true)
    check "every row reached both coordinate sets ($got of $want records)" \
          "$(status "$got" "$want")"
    check "every row: identical parameters in both coordinate sets" \
          "$(identical_across_sets "$DAT")"
    file_expected "$PARAMS" > "$d/expected.dat"
    check "every row's well depth, radius and hard-sphere radius match the file (1e-4 relative)" \
          "$(rows_match "$d/expected.dat" "$DAT")"
    mfile=$(file_mass_sum "$PARAMS")
    mprog=$(grep -F 'mass of ion =' "$d/allkeys.out" | head -1 | sed 's/.*= *//' | tr -d ' \r')
    check "mass of ion equals the sum of the file's masses ($mprog vs $mfile)" \
          "$(rel_ok "$mprog" "$mfile")"
    pw=$(( 2 * $(flag_count "$PARAMS" 7 provisional) ))
    bw=$(( 2 * $(flag_count "$PARAMS" 8 borrowed) ))
    pc=$(grep -c 'WARNING: provisional' "$d/allkeys.out" || true)
    bc=$(grep -c 'borrowed from carbon' "$d/allkeys.out" || true)
    check "provisional warnings are 2 x the file's provisional rows (got $pc, want $pw)" \
          "$(status "$pc" "$pw")"
    check "borrowed-radius warnings are 2 x the file's borrowed rows (got $bc, want $bw)" \
          "$(status "$bc" "$bw")"
    listed=$(awk '/defined keys:/ { getline; print; exit }' "$d/undefined.out" | tr -d ' \r')
    filekeys=$(param_rows "$PARAMS" | awk '{ printf "%s%s", (NR > 1 ? "," : ""), $1 }')
    check "the refusal lists the file's keys in the file's order ($listed)" \
          "$(if [ "$listed" = "$filekeys" ]; then echo y; else echo n; fi)"
    fset=$(param_header "$PARAMS" set)
    check "the file declares a parameter-set version (set: $fset)" \
          "$(if [ -n "$fset" ]; then echo y; else echo n; fi)"

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
