**FREE
// ===================================================================
// CRMCONT - Contacts for one customer (24 x 80)
//   Options: 2=Change 4=Delete 9=Send email     F6=Add contact
//   Add/change happens in a popup window.
// ===================================================================
ctl-opt dftactgrp(*no) actgrp('CRMDEMO') bnddir('CRMBND')
        option(*srcstmt : *nodebugio) datfmt(*iso) timfmt(*iso);

dcl-f CRMCONTD workstn indds(ind) infds(wsds) sfile(CONTSFL : rrn);

/include CRMDEMO/QRPGLESRC,CRMSRVH

dcl-pi *n;
  custId int(10) const;
end-pi;

dcl-ds ind len(99) qualified;
  sflDsp    ind pos(30);
  sflDspCtl ind pos(31);
  sflClr    ind pos(32);
  sflEnd    ind pos(33);
  optErr    ind pos(50);
  firstErr  ind pos(51);
  lastErr   ind pos(52);
  emailErr  ind pos(53);
  primErr   ind pos(54);
end-ds;

dcl-ds wsds;
  wsAid char(1) pos(369);
end-ds;

dcl-ds cont qualified;
  first  char(20);
  last   char(25);
  title  char(30);
  phone  char(15);
  email  char(60);
  prim   char(1);
end-ds;

dcl-s rrn      packed(5 : 0);
dcl-s me       char(10);
dcl-s id       int(10);
dcl-s custNm   char(40);
dcl-s hadError ind;
dcl-s rtnMsg   char(78);

exec sql set option commit = *none, closqlcsr = *endmod,
                    datfmt = *iso, naming = *sys;

me = crmPsds.curUser;
id = custId;
custNm = crm_custName(id);
CCUSTID = id;
CCUSTNM = custNm;
loadSubfile();

dow *on;
  write FKEYS;
  exfmt CONTCTL;
  FMSG = '';

  select;
    when wsAid = KEY_F03 or wsAid = KEY_F12;
      leave;
    when wsAid = KEY_F05;
      loadSubfile();
    when wsAid = KEY_F06;
      if editContact(0);
        FMSG = 'Contact added.';
      endif;
      loadSubfile();
    other;
      processOptions();
      if not hadError;
        loadSubfile();
      endif;
  endsl;
enddo;

*inlr = *on;
return;

// -------------------------------------------------------------------
// loadSubfile
// -------------------------------------------------------------------
dcl-proc loadSubfile;
  dcl-ds row qualified;
    contId int(10);
    first  char(20);
    last   char(25);
    title  char(30);
    phone  char(15);
    email  char(60);
    prim   char(1);
  end-ds;

  ind.sflDsp = *off;
  ind.sflDspCtl = *off;
  ind.sflClr = *on;
  write CONTCTL;
  ind.sflClr = *off;
  rrn = 0;

  exec sql declare contCur cursor for
    select CONTID, FIRSTNAME, LASTNAME, TITLE, PHONE, EMAIL, ISPRIMARY
      from CONTACT
     where CUSTID = :id
     order by ISPRIMARY desc, LASTNAME, FIRSTNAME
     for read only;

  exec sql open contCur;
  dow rrn < 999;
    exec sql fetch next from contCur into :row;
    if sqlcode <> 0;
      leave;
    endif;
    rrn += 1;
    SOPT    = '';
    SCONTID = row.contId;
    SNAME   = %trim(row.first) + ' ' + %trim(row.last);
    SCTITLE = row.title;
    SPHONE  = row.phone;
    SEMAIL  = row.email;
    SPRIM   = row.prim;
    ind.optErr = *off;
    write CONTSFL;
  enddo;
  exec sql close contCur;

  ind.sflDsp = rrn > 0;
  ind.sflDspCtl = *on;
  ind.sflEnd = *on;
  if rrn = 0;
    FMSG = 'No contacts yet. Press F6 to add one.';
  endif;
end-proc;

// -------------------------------------------------------------------
// processOptions
// -------------------------------------------------------------------
dcl-proc processOptions;
  hadError = *off;

  readc CONTSFL;
  dow not %eof(CRMCONTD);
    ind.optErr = *off;

    select;
      when SOPT = ' ';
      when SOPT = '2';
        if editContact(SCONTID);
          FMSG = 'Contact changed.';
        endif;
      when SOPT = '4';
        deleteContact(SCONTID : SNAME);
      when SOPT = '9';
        if SEMAIL = '';
          FMSG = 'This contact has no email address.';
        else;
          CRMEMAIL(SEMAIL : SNAME : id : SCONTID : rtnMsg);
          FMSG = rtnMsg;
        endif;
      other;
        ind.optErr = *on;
        hadError = *on;
        FMSG = 'Option ' + SOPT + ' is not valid.';
    endsl;

    if not ind.optErr;
      SOPT = '';
    endif;
    update CONTSFL;
    readc CONTSFL;
  enddo;
end-proc;

// -------------------------------------------------------------------
// editContact - add (contId = 0) or change in a window
// -------------------------------------------------------------------
dcl-proc editContact;
  dcl-pi *n ind;
    contId int(10) const;
  end-pi;

  dcl-s cid   int(10);
  dcl-s cnt   int(10);
  dcl-s evt   char(8);

  cid = contId;
  clear cont;

  if cid = 0;
    WTITLE = 'Add contact for ' + custNm;
    exec sql select count(*) into :cnt from CONTACT where CUSTID = :id;
    cont.prim = 'N';
    if cnt = 0;
      cont.prim = 'Y';
    endif;
  else;
    WTITLE = 'Change contact';
    exec sql
      select FIRSTNAME, LASTNAME, TITLE, PHONE, EMAIL, ISPRIMARY
        into :cont
        from CONTACT where CONTID = :cid;
    if sqlcode <> 0;
      FMSG = 'Contact no longer exists.';
      return *off;
    endif;
  endif;

  WFIRST  = cont.first;
  WLAST   = cont.last;
  WCTITLE = cont.title;
  WPHONE  = cont.phone;
  WEMAIL  = cont.email;
  WPRIM   = cont.prim;
  WMSG    = '';

  dow *on;
    exfmt CONTWDW;
    WMSG = '';
    ind.firstErr = *off;
    ind.lastErr  = *off;
    ind.emailErr = *off;
    ind.primErr  = *off;

    if wsAid = KEY_F12 or wsAid = KEY_F03;
      return *off;
    endif;

    if WPRIM <> 'Y' and WPRIM <> 'N';
      ind.primErr = *on;
      WMSG = 'Primary must be Y or N.';
    endif;
    if WEMAIL <> '' and %scan('@' : WEMAIL) < 2;
      ind.emailErr = *on;
      WMSG = 'Email address is not valid.';
    endif;
    if WLAST = '';
      ind.lastErr = *on;
      WMSG = 'Last name is required.';
    endif;
    if WFIRST = '';
      ind.firstErr = *on;
      WMSG = 'First name is required.';
    endif;
    if WMSG = '';
      leave;
    endif;
  enddo;

  cont.first = WFIRST;
  cont.last  = WLAST;
  cont.title = WCTITLE;
  cont.phone = WPHONE;
  cont.email = WEMAIL;
  cont.prim  = WPRIM;

  if cid = 0;
    exec sql
      insert into CONTACT (CUSTID, FIRSTNAME, LASTNAME, TITLE, PHONE,
                           EMAIL, ISPRIMARY, CRTUSER, CHGUSER)
      values (:id, :cont.first, :cont.last, :cont.title, :cont.phone,
              :cont.email, :cont.prim, :me, :me);
    exec sql values identity_val_local() into :cid;
    evt = 'CONTADD';
  else;
    exec sql
      update CONTACT
         set FIRSTNAME = :cont.first, LASTNAME = :cont.last,
             TITLE = :cont.title, PHONE = :cont.phone,
             EMAIL = :cont.email, ISPRIMARY = :cont.prim,
             CHGUSER = :me
       where CONTID = :cid;
    evt = 'CONTCHG';
  endif;

  if sqlcode < 0;
    FMSG = 'Save failed, SQLCODE ' + %char(sqlcode) + '.';
    return *off;
  endif;

  // Only one primary contact per customer
  if cont.prim = 'Y';
    exec sql update CONTACT set ISPRIMARY = 'N', CHGUSER = :me
              where CUSTID = :id and CONTID <> :cid and ISPRIMARY = 'Y';
  endif;

  crm_logEvent(evt : id : ''
               : %trim(cont.first) + ' ' + %trim(cont.last)
               + ' saved as contact at ' + %trim(custNm));
  return *on;
end-proc;

// -------------------------------------------------------------------
// deleteContact
// -------------------------------------------------------------------
dcl-proc deleteContact;
  dcl-pi *n;
    contId int(10)  const;
    name   char(30) const;
  end-pi;

  dcl-s cid int(10);

  cid = contId;
  WTEXT1 = 'Delete contact ' + name;
  WTEXT2 = 'from ' + custNm;
  exfmt CONFWDW;
  if wsAid <> KEY_F10;
    FMSG = 'Delete cancelled.';
    return;
  endif;

  exec sql delete from CONTACT where CONTID = :cid;
  crm_logEvent('CONTDLT' : id : ''
               : 'Deleted contact ' + %trim(name) + ' at '
               + %trim(custNm));
  FMSG = 'Contact deleted.';
end-proc;
