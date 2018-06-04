/* REXX */
/**********************************************************************/
/* List FD usage for processes                                        */
/*                                                                    */
/* PROPERTY OF IBM                                                    */
/* COPYRIGHT IBM CORP. 1999                                           */
/*                                                                    */
/* Syntax: fduse           to list all processes                      */
/*     or: fduse pid...    to list one or more processes              */
/*                                                                    */
/* Bill Schoen (wjs at ibmusm10,  wjs@us.ibm.com)    8/4/99           */
/* History:                                                           */
/*    8/10/99  replaced userid with jobname and command on output     */
/**********************************************************************/
numeric digits 12
pctcmd=-2147483647
pfs='KERNEL'
parse source . how . . . . . omvs .
if omvs<>"OMVS" then
   call syscalls 'ON'
address syscall
catd=-1

z1='00'x
z2='0000'x
z4='00000000'x
laddr=0
lalet=0
llen=0
cvtecvt=140
ecvtocvt=240
ocvtocve=8
ocvtfds='58'
ocvtkds='48'
ocveppra='8'
ppralast='c'
ppraltok='10'
ppraelement='30'
pprapprp=4
ppraelementlen=8
pprpfupt='58'
pprpascb='24'
ascbjbni='ac'
ascbjbns='b0'
fuptcwd='8'
fuptcrd='c'
fuptffdt='10'
fuptsab='70'
fuptfdlim='94'
ffdtinuse=4
ffdtofte=12
ffdtnext='8'
ffdtlen='414'
ffdtents=64
ffdtentlen=16
ffdthdrlen=20
sabvdecount='40'
sabvdehead='44'
vdevnodeptr='8'
vdeforwardchain='18'
vdefreestate='14'
vdefreestatef='80'x
oftevnode='8'
vnodvfs='18'
vnodino='48'
ofsb='1000'
ofsbgfs='08'
ofsblen='200'
vfsnext='08'
vfsflags='34'
vfsfilesysname='38'
vfsavailable='0080'x
vfsstdev='6c'
vfslen='190'
gfsnext='08'
gfsvfs='0c'
gfspfs='10'
gfsname='18'
gfsflags='2c'
gfsdead='80'x
gfslen='80'

cvt=c2x(storage(10,4))
ecvt=c2x(storage(d2x(x2d(cvt)+cvtecvt),4))
ocvt=c2x(storage(d2x(x2d(ecvt)+ecvtocvt),4))
ocve=c2x(storage(d2x(x2d(ocvt)+ocvtocve),4))

fds=storage(d2x(x2d(ocvt)+x2d(ocvtfds)),4)
kds=storage(d2x(x2d(ocvt)+x2d(ocvtkds)),4)

if fetch(fds,'00001000'x,'10') then
   do
   call say 00,'Kernel is unavailable or at the wrong level',
                  'for this function or you are not a superuser'
   exit 1
   end

arg pids
ix=0
call fetch z4,x2c(ocve),10
ppra=ofs(ocveppra,4)
call fetch z4,ppra,10
pprpnum=c2d(ofs(ppralast,4))
pprafirst=c2d(ppra)+x2d(ppraelement)
pprplen=pprpnum*ppraelementlen
ppraents=''
do while pprplen>0
   i=min(4000,pprplen)
   call fetch z4,d2c(pprafirst),d2x(i)
   pprafirst=pprafirst+i
   pprplen=pprplen-i
   ppraents=ppraents || buf
end

do i=1 to pprpnum
   pprp=substr(ppraents,(i-1)*ppraelementlen+pprapprp+1,4)
   if substr(pprp,1,1)='F' |,
      substr(pprp,1,1)='V' then
      iterate
   if fetch(z4,pprp,'b8','PPRP') then
     iterate
   ascb=c2d(ofs(pprpascb,4))
   call fetch fds,ofs(pprpfupt,4),'A0'
   ffdt=ofs(fuptffdt,4)
   fdlim=c2d(ofs(fuptfdlim,4))
   fdcnt=0
   do while ffdt<>z4
      call fetch fds,ffdt,ffdtlen
      ffdt=ofs(ffdtnext,4)
      fdtbuf=buf
      do j=1 to ffdtents
         if getofs(fdtbuf,d2x(ffdthdrlen+(j-1)*ffdtentlen+ffdtinuse),1),
               <>'I' then iterate
         fdcnt=fdcnt+1
      end
   end
   ix=ix+1
   p.ix=i
   p.ix.1=fdcnt
   p.ix.2=fdlim
   jbna=storage(d2x(ascb+x2d(ascbjbni)),4)
   if jbna=z4 then
      jbna=storage(d2x(ascb+x2d(ascbjbns)),4)
   if jbna<>z4 then
      p.ix.3=storage(c2x(jbna),8)
    else
      p.ix.3='?'
end

if ix=0 then
   do
   call say 00,'no users found'
   return
   end

'getpsent ps.'
call say 00,right('FDs in use',12),
            right('Max FDs',12),
            right('PID',12),
            'Job Name',
            'Command'
do j=1 to ps.0
   do i=1 to ix
      pid=c2d(substr(ppraents,(p.i-1)*8+1,4))
      if pid=ps.j.ps_pid & (wordpos(pid,pids)>0 | pids='') then
         do
         call say 00,right(p.i.1,12),
                     right(p.i.2,12),
                     right(ps.j.ps_pid,12),
                     left(p.i.3,8),
                     ps.j.ps_cmd
         end
   end
end
return

/**********************************************************************/
vnodinuse:
   svbuf=buf
   arg vnod
   call fetch fds,vnod,50
   if vfs=ofs(vnodvfs,4) & ino=c2d(ofs(vnodino,4)) then
      do
      ix=ix+1
      p.ix=i
      added=1
      end
   buf=svbuf
   return added

/**********************************************************************/
ofs:
   arg ofsx,ln
   return substr(buf,x2d(ofsx)+1,ln)

/**********************************************************************/
getofs:
   parse arg zbuf,ofsx,ln
   return substr(zbuf,x2d(ofsx)+1,ln)

/**********************************************************************/
loadgfs:
   call fetch fds,x2c(right(ofsb,8,0)),ofsblen
   ofsb.1=buf
   gfsptr=ofs(ofsbgfs,4)
   gi=0
   do while gfsptr<>z4
      call fetch fds,gfsptr,gfslen
      gfsptr=ofs(gfsnext,4)
      if bitand(ofs(gfsflags,1),gfsdead)<>z1 then
         iterate
      gi=gi+1
      gfs.gi=buf
   end
   gfs.0=gi
   return

/**********************************************************************/
loadvfs:
   do i=1 to gfs.0
      j=0
      vfsptr=getofs(gfs.i,gfsvfs,4)
      do while vfsptr<>z4
         call fetch fds,vfsptr,vfslen
         vfslast=vfsptr
         vfsptr=ofs(vfsnext,4)
         if bitand(ofs(vfsflags,2),vfsavailable)<>z2 then
            iterate
         j=j+1
         vfs.i.j=buf
         vfs.i.j.0=vfslast
      end
      vfs.i.0=j
   end
   vfs.0=gfs.0
   return
/**********************************************************************/
fetch:
   parse arg alet,addr,len,eye  /* char: alet,addr  hex: len */
   len=x2c(right(len,8,0))
   dlen=c2d(len)
   buf=alet || addr || len
   'pfsctl' pfs pctcmd 'buf' max(dlen,12)
   if retval=-1 then
      return 1
   if rc<>0 then
      do
      say 'buf:' c2x(buf)
      say 'len:' max(dlen,12)
      signal halt
      end
   if eye<>'' then
      if substr(buf,1,length(eye))<>eye then
         return 1
   if dlen<12 then
      buf=substr(buf,1,dlen)
   return 0

/**********************************************************************/
/* All messages are issued by the say function.                       */
/* Parms:  1   message number                                         */
/*         2   message text                                           */
/*         3-n substitution text                                      */
/* Use %% as a place-holder for substitution text.                    */
/* The following global variables must be set                         */
/*    catd   catalog descriptor                                       */
/*    mset   message set number                                       */
/**********************************************************************/
say: procedure expose catd mset
   mtext=arg(2)
   if catd>=0 & arg(1)>0 then
      address syscall "catgets" catd mset arg(1) "mtext"
   do si=3 to arg()
      parse var mtext mtpref '%%' mtsuf
      mtext=mtpref || arg(si) || mtsuf
   end
   say mtext
   return
