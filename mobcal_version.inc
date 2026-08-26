c
c     mobcal_version.inc -- the release version of the code, in the one
c     place it is written down.
c
c     Included by the main program of mobcal_He.f and of mobcal_N2.f.
c     Those are the only two program units that print it: once in the
c     output header, once in the SUMMARY.  Two components, matching the
c     repository's tags (v1.0, v1.1); v2.0 is reserved for the first
c     breaking change.
c
c     Before v1.1 the SUMMARY read 'program version = junkn.f', which
c     named a scratch file rather than a version and was identical in
c     both sources, so an output file could not be traced to the code
c     that produced it.
c
c     The PARAMETER-SET version is deliberately NOT here.  The two
c     source files hold different tables -- mobcal_He.f holds He-X pair
c     parameters, mobcal_N2.f holds X-X self parameters that pass
c     through a combining rule -- and the two have already been revised
c     independently: v1.1 added three elements to helium and six to
c     nitrogen, and fixed silicon in nitrogen only.  One shared constant
c     would force a bump in the table that did not change.  Each main
c     program declares its own verparm, next to the write that prints
c     it.
c
c     character*(*) rather than a fixed length, so that a longer string
c     does not need the declaration edited as well, and so that the 'a'
c     edit descriptor emits no trailing blanks.
c
      character*(*) vercode
      parameter (vercode='1.1')
