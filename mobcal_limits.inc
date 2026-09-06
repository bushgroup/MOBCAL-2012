c
c     mobcal_limits.inc -- the compiled-in array bounds, in one place.
c
c     Included by every program unit of mobcal_He.f and mobcal_N2.f that
c     dimensions a per-atom or per-conformer array. Before this file existed
c     the atom bound was written out fifteen times per source file, so raising
c     it meant thirty consistent edits; now it is one.
c
c       len     maximum atoms in one conformer
c       lcoord  maximum coordinate sets (conformers) in one input file
c       ltab    maximum element rows in one parameter file (v1.3)
c
c     Both are checked against the input by FCOORD, which refuses and exits
c     nonzero rather than indexing past the end of an array. That check is not
c     a nicety. The per-atom arrays live in named COMMON blocks:
c
c       common/coordinates/fx(len),fy(len),fz(len),ox(len),oy(len),oz(len)
c
c     and Fortran storage association makes COMMON members contiguous, so with
c     one atom too many, atom len+1's x coordinate is written onto atom 1's y
c     coordinate -- the same molecule, silently rewritten mid-calculation.
c     -fno-automatic, which this code requires, puts all of it in static
c     storage, so that is deterministic overwriting of live data rather than a
c     stack accident that might trap. Crashing is the lucky outcome; the
c     unlucky one is a completed run printing a meaningless cross section
c     formatted exactly like a real one.
c
c     VALIDATED TO 1,000 ATOMS. Raising the bound is supported and meant to be
c     easy, but nobody has run this code above 1,000 atoms -- above that you
c     are the first, and no published result, including the reference outputs
c     under sample-output/, is anywhere near it. The bound is deliberately not
c     raised by default: a larger default would ship an untested regime to
c     everybody in order to serve nobody who has asked for it.
c
c     Two notes for anyone editing this file.
c
c     `len' shadows the Fortran intrinsic LEN. That is pre-existing and is
c     accepted under -std=legacy. It is not worth renaming: the name appears in
c     every dimension expression in both sources.
c
c     ltab bounds the table LJREAD loads from mobcal_He.params or
c     mobcal_N2.params; the files ship with 13 and 16 rows. It is checked by
c     LJREAD, which refuses a file with more rows rather than overrunning the
c     table.
c
c     All three names must begin with i, j, k or l. Every unit that includes this
c     file declares `implicit double precision (a-h,m-z)', so a name beginning
c     with m..z would be typed REAL and become a non-integer array bound.
c
      parameter (len=1000)
      parameter (lcoord=100)
      parameter (ltab=64)
