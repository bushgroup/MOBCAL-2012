c
c     mobcal_ljread.inc -- the reader for the per-gas parameter file,
c     in the one place it is written down.
c
c     Included by mobcal_He.f and mobcal_N2.f after their last program
c     unit, so each binary carries one copy of one reader.  Through
c     v1.2 the element table was a subroutine in each source file;
c     since v1.3 it is mobcal_He.params / mobcal_N2.params, and LJPARM
c     in each source only applies what LJREAD loaded.
c
c     THE ONE RULE THAT MATTERS.  A numeric token is read with the kind
c     Fortran gives the literal: with a d exponent it is read as a
c     REAL(8), without one as a REAL(4) and promoted afterwards.  That
c     is not fussiness.  mobcal_N2.f's table multiplied a double by
c     single-precision literals such as 0.4020, and the published
c     output carries the eighth-digit consequence of that; mobcal_He.f's
c     table used double literals throughout.  Read the right way, every
c     one of the 58 literals reproduces the compiled value bit for bit;
c     read the other way, none of the 32 nitrogen ones does.  So the
c     files carry the literals exactly as the source did, and the
c     spelling is the precision declaration.  One / or one * is allowed
c     inside a token, for the sodium row and the conve header value that
c     were expressions in the source.
c
c     Tokens are split by hand, not by a list-directed read: a / ends a
c     list-directed record and a , splits one, and a row's provenance
c     text can contain anything.
c
c     Every refusal here names the file, the line and the reason, to the
c     output file and to the console, and exits 1, like every other
c     refusal in the program (test/refusals.sh).  There is no compiled-in
c     fallback table: a missing file is a refusal, never a silent
c     divergence.
c
c     ***************************************************************
c
      subroutine ljread(pfile,gasid)
c
c     Loads the parameter file pfile into COMMON /ljtable/ and
c     /ljtablc/: itab rows of (ikey, tmass, teps, tsig, trhs, iprov,
c     iborr) and the parameter-set string tset(1:lset).  gasid is the
c     gas this binary is built for ('He' or 'N2'); a file whose gas:
c     header says otherwise is refused, because a helium binary handed
c     the nitrogen self parameters would apply pair semantics to them
c     and nothing in the output would say so.
c
c     teps and tsig hold each row short of its final factor.  For the
c     pair form that is the literal itself; for the combining form it
c     is dsqrt(eogas*e)*conve and dsqrt(rogas*s)*convr.  LJPARM then
c     multiplies by xe and by 1.0d-10 per atom, in the order the
c     compiled expressions did -- ((dsqrt(...)*conve)*xe) -- so the
c     value is the one the Fortran table produced.
c
      implicit double precision (a-h,m-z)
      include 'mobcal_limits.inc'
      character*(*) pfile,gasid
      character*16 tset
      common/ljtable/tmass(ltab),teps(ltab),tsig(ltab),trhs(ltab),
     ?ikey(ltab),iprov(ltab),iborr(ltab),itab,lset
      common/ljtablc/tset
      character*256 line,msg
      character*64 tok(9)
      character*16 gas,form,key
      logical lgas,lform,lsetv,leog,lrog,lcve,lcvr
c
      itab=0
      lgas=.false.
      lform=.false.
      lsetv=.false.
      leog=.false.
      lrog=.false.
      lcve=.false.
      lcvr=.false.
      iline=0
      open(21,file=pfile,status='old',err=800)
c
  100 read(21,'(a)',end=200) line
      iline=iline+1
c
c     A trailing carriage return (a CRLF file read on Linux or macOS),
c     then everything from the first # (comment) and from the first |
c     (provenance) to end of line, are not part of the columns.
c
      lc=index(line,char(13))
      if(lc.gt.0) line(lc:)=' '
      lc=index(line,'#')
      if(lc.gt.0) line(lc:)=' '
      lc=index(line,'|')
      if(lc.gt.0) line(lc:)=' '
      if(line.eq.' ') goto 100
      call ljtok(line,tok,itok)
      if(itok.gt.8) then
      msg='more than 8 columns before the |'
      goto 900
      endif
      ll=len_trim(tok(1))
      if(tok(1)(ll:ll).eq.':') then
c
c     A header line: one key ending in a colon, one value, and all of
c     them before the first element row, so the combining constants are
c     known when the first row that needs them is read.
c
      if(itab.gt.0) then
      msg='header line after the first element row'
      goto 900
      endif
      if(itok.ne.2) then
      msg='a header line is one key: and one value'
      goto 900
      endif
      if(ll.lt.2) then
      msg='empty header key'
      goto 900
      endif
      key=tok(1)(1:ll-1)
      iok=1
      if(key.eq.'gas') then
      gas=tok(2)
      lgas=.true.
      else if(key.eq.'form') then
      form=tok(2)
      if(form.ne.'pair'.and.form.ne.'combining') then
      msg='form must be pair or combining'
      goto 900
      endif
      lform=.true.
      else if(key.eq.'set') then
      lset=len_trim(tok(2))
      if(lset.gt.16) then
      msg='set string longer than 16 characters'
      goto 900
      endif
      tset=tok(2)
      lsetv=.true.
      else if(key.eq.'eogas') then
      call ljlit(tok(2),eogas,iok)
      leog=.true.
      else if(key.eq.'rogas') then
      call ljlit(tok(2),rogas,iok)
      lrog=.true.
      else if(key.eq.'conve') then
      call ljlit(tok(2),conve,iok)
      lcve=.true.
      else if(key.eq.'convr') then
      call ljlit(tok(2),convr,iok)
      lcvr=.true.
      else
      msg='unknown header key '//key
      goto 900
      endif
      if(iok.eq.0) then
      msg='the value of '//key(1:ll-1)//' is not a Fortran literal'
      goto 900
      endif
      goto 100
      endif
c
c     An element row.
c
      if(.not.lform) then
      msg='element row before the form: header'
      goto 900
      endif
      if(itok.ne.8) then
      msg='an element row is 8 columns before the |'
      goto 900
      endif
      if(itab.ge.ltab) then
      msg='more element rows than ltab in mobcal_limits.inc allows'
      goto 900
      endif
      call ljint(tok(1),ik,iok)
      if(iok.eq.0) then
      msg='column 1 (the mass key) is not an integer'
      goto 900
      endif
      do 110 k=1,itab
      if(ikey(k).eq.ik) then
      msg='duplicate mass key'
      goto 900
      endif
  110 continue
      call ljlit(tok(3),xm,iok)
      if(iok.eq.0) then
      msg='column 3 (mass) is not a Fortran literal'
      goto 900
      endif
      call ljlit(tok(4),e,iok)
      if(iok.eq.0) then
      msg='column 4 (the well depth) is not a Fortran literal'
      goto 900
      endif
      call ljlit(tok(5),s,iok)
      if(iok.eq.0) then
      msg='column 5 (the radius) is not a Fortran literal'
      goto 900
      endif
      call ljlit(tok(6),r,iok)
      if(iok.eq.0) then
      msg='column 6 (the hard-sphere radius) is not a Fortran literal'
      goto 900
      endif
      if(tok(7).eq.'fitted') then
      ip=0
      else if(tok(7).eq.'provisional') then
      ip=1
      else
      msg='column 7 must be fitted or provisional'
      goto 900
      endif
      if(tok(8).eq.'own') then
      ib=0
      else if(tok(8).eq.'borrowed') then
      ib=1
      else
      msg='column 8 must be own or borrowed'
      goto 900
      endif
      if(form.eq.'combining') then
      if(.not.(leog.and.lrog.and.lcve.and.lcvr)) then
      msg='the combining form needs eogas, rogas, conve and convr'//
     ?' in the header'
      goto 900
      endif
      endif
c
      itab=itab+1
      ikey(itab)=ik
      tmass(itab)=xm
      trhs(itab)=r
      iprov(itab)=ip
      iborr(itab)=ib
      if(form.eq.'pair') then
      teps(itab)=e
      tsig(itab)=s
      else
      teps(itab)=dsqrt(eogas*e)*conve
      tsig(itab)=dsqrt(rogas*s)*convr
      endif
      goto 100
c
c     End of file: the whole-file checks.
c
  200 close (21)
      iline=0
      if(.not.lgas) then
      msg='no gas: header'
      goto 900
      endif
      if(gas.ne.gasid) then
      msg='this file is for gas '//gas(1:len_trim(gas))//
     ?', this program is built for '//gasid
      goto 900
      endif
      if(.not.lsetv) then
      msg='no set: header'
      goto 900
      endif
      if(itab.eq.0) then
      msg='no element rows'
      goto 900
      endif
      return
c
c     Refusals.  801 is the missing file; 901 and 902 name the line when
c     there is one.  Written before the version banner, necessarily: the
c     banner's second half is the set: string this file was to supply.
c
  800 write(8,801) pfile(1:len_trim(pfile)),gasid
      write(6,801) pfile(1:len_trim(pfile)),gasid
  801 format(1x,'ERROR: cannot open parameter file ',a,/1x,
     ?'name it on line 4 of mobcal.in, or place mobcal_',a,
     ?'.params in the current directory.')
      close (8)
      call exit(1)
c
  900 if(iline.gt.0) then
      write(8,901) pfile(1:len_trim(pfile)),iline,msg(1:len_trim(msg))
      write(6,901) pfile(1:len_trim(pfile)),iline,msg(1:len_trim(msg))
      else
      write(8,902) pfile(1:len_trim(pfile)),msg(1:len_trim(msg))
      write(6,902) pfile(1:len_trim(pfile)),msg(1:len_trim(msg))
      endif
  901 format(1x,'ERROR: parameter file ',a,', line',i5,': ',a)
  902 format(1x,'ERROR: parameter file ',a,': ',a)
      close (8)
      call exit(1)
      end
c
c     ***************************************************************
c
      subroutine ljtok(line,tok,itok)
c
c     The blank- or tab-delimited tokens of line, at most nine: the
c     ninth exists only so the caller can tell "eight" from "too many".
c
      implicit double precision (a-h,m-z)
      character*(*) line
      character*64 tok(9)
      character*1 c
c
      itok=0
      ll=len_trim(line)
      i=1
   10 if(i.gt.ll) return
      c=line(i:i)
      if(c.eq.' '.or.c.eq.char(9)) then
      i=i+1
      goto 10
      endif
      j=i
   20 if(j.le.ll) then
      c=line(j:j)
      if(c.ne.' '.and.c.ne.char(9)) then
      j=j+1
      goto 20
      endif
      endif
      itok=itok+1
      if(itok.gt.9) then
      itok=9
      return
      endif
      tok(itok)=line(i:j-1)
      i=j
      goto 10
      end
c
c     ***************************************************************
c
      subroutine ljlit(tok,val,iok)
c
c     One Fortran literal, or two joined by one / or one *, evaluated
c     left to right in double precision after each part is read with
c     its own kind.  iok is 0 if the token is not that.
c
      implicit double precision (a-h,m-z)
      character*(*) tok
c
      iok=1
      lt=len_trim(tok)
      iop=0
      do 10 i=1,lt
      if(tok(i:i).eq.'/'.or.tok(i:i).eq.'*') then
      if(iop.ne.0) goto 90
      iop=i
      endif
   10 continue
      if(iop.eq.0) then
      call ljnum(tok(1:lt),val,iok)
      return
      endif
      if(iop.eq.1.or.iop.eq.lt) goto 90
      call ljnum(tok(1:iop-1),a,iok)
      if(iok.eq.0) return
      call ljnum(tok(iop+1:lt),b,iok)
      if(iok.eq.0) return
      if(tok(iop:iop).eq.'/') val=a/b
      if(tok(iop:iop).eq.'*') val=a*b
      return
   90 iok=0
      return
      end
c
c     ***************************************************************
c
      subroutine ljnum(part,val,iok)
c
c     One Fortran real literal.  With a d or D exponent it is read as a
c     REAL(8); otherwise as a REAL(4) and promoted -- the kind the
c     compiler gave the same spelling.  Only the characters a literal
c     can contain are accepted, because a list-directed read would
c     quietly take "1.0x" as 1.0.
c
      implicit double precision (a-h,m-z)
      character*(*) part
      character*1 c
      real*4 s4
      logical ldbl,ldig
c
      iok=0
      lp=len_trim(part)
      if(lp.lt.1) return
      ldbl=.false.
      ldig=.false.
      do 10 i=1,lp
      c=part(i:i)
      if(c.ge.'0'.and.c.le.'9') then
      ldig=.true.
      else if(c.eq.'d'.or.c.eq.'D') then
      ldbl=.true.
      else if(c.eq.'e'.or.c.eq.'E'.or.c.eq.'.'.or.c.eq.'+'
     ?.or.c.eq.'-') then
      continue
      else
      return
      endif
   10 continue
      if(.not.ldig) return
      if(ldbl) then
      read(part(1:lp),*,err=90,end=90) val
      else
      read(part(1:lp),*,err=90,end=90) s4
      val=dble(s4)
      endif
      iok=1
   90 return
      end
c
c     ***************************************************************
c
      subroutine ljint(tok,ival,iok)
c
c     One non-negative integer, digits only.
c
      implicit double precision (a-h,m-z)
      character*(*) tok
      character*1 c
c
      iok=0
      lt=len_trim(tok)
      if(lt.lt.1) return
      do 10 i=1,lt
      c=tok(i:i)
      if(c.lt.'0'.or.c.gt.'9') return
   10 continue
      read(tok(1:lt),*,err=90,end=90) ival
      iok=1
   90 return
      end
