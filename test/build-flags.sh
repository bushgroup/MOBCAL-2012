#!/bin/sh
#
# test/build-flags.sh -- the build recipe, and the only place it is written down.
#
# Sourced, not executed. Sets PLATFORM, FC, FFLAGS and LDFLAGS, each honouring an
# existing environment value so a caller can override one without restating the
# rest.
#
# This file exists so that there is exactly one definition of the recipe no
# matter how many test scripts there are. It started as the FFLAGS default
# inside test/regression.sh; test/bounds.sh needs the same build, and two copies
# of a build recipe is how a recipe drifts. The CI workflow still sets no FFLAGS
# of its own, so CI cannot drift from this file either.
# README.md documents the same flags in prose for users; that copy has to be
# updated by hand, so a change here is a change in two places.

# -fno-automatic is MANDATORY, not an optimization choice. The code relies on
# static storage for locals, which was g77's default. Without this flag an
# optimizing gfortran build gives every local automatic storage and the
# trajectory integrator fails outright -- a measured 39,998 lost trajectories
# and zero completed, against zero lost in every -fno-automatic build. The
# failure is loud, but it is a failure, so the flag is not negotiable here.
#
# -std=legacy silences 64 "Fortran 2018 deleted feature" diagnostics per source
# file -- all 128 of them in that one class, so nothing else is hiding in the
# noise. It is codegen-neutral, and that is checkable rather than asserted: with
# and without the flag, gfortran -S differs by exactly one word in 17,691 lines
# of assembly for He and 20,056 for N2, and the word is not an instruction. It
# is options[0] in the array handed to _gfortran_set_options -- the mask of
# standards the runtime warns about -- while options[1], the mask of language
# features the compiler accepts, is 16383 in both. The gate's whole-file tier is
# the empirical confirmation.
FC=${FC:-gfortran}
FFLAGS=${FFLAGS:--O3 -fno-automatic -std=legacy}

platform_key() {
    case "$(uname -s)" in
        Linux*)               echo linux ;;
        Darwin*)              echo macos ;;
        MINGW*|MSYS*|CYGWIN*) echo windows ;;
        *)                    echo "unknown" ;;
    esac
}
PLATFORM=$(platform_key)

# -static only on Windows: dynamic MSYS2 builds die silently when launched from
# PowerShell. Apple's linker has no fully-static mode, so it must not be passed
# on macOS, and it buys nothing on a Linux CI runner.
case "$PLATFORM" in
    windows) LDFLAGS=${LDFLAGS:--static} ;;
    *)       LDFLAGS=${LDFLAGS:-} ;;
esac

# Both sources carry `include 'mobcal_limits.inc'` and, since v1.1,
# `include 'mobcal_version.inc'`. gfortran resolves both relative to the
# directory of the including source file. Verified rather than assumed, on
# Windows as well: building from the repository root and building the same source
# by absolute path from an unrelated working directory produce byte-identical
# binaries. So the includes add required source files but do not change the build
# command, and README.md's "one command per gas" still holds.

require_compiler() {
    command -v "$FC" >/dev/null 2>&1 || {
        echo "compiler '$FC' not found on PATH" >&2
        echo "  On MSYS2, C:\\msys64\\mingw64\\bin must be on PATH or the" >&2
        echo "  compiler is not merely absent -- invocations fail with no output." >&2
        exit 2
    }
}
