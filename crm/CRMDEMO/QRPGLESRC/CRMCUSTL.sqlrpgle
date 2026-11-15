**FREE
// ===================================================================
// CRMCUSTL - Customer list (24 x 80)
//   Search by name, filter by status / "mine only"
//   Options: 2=Change 4=Delete 5=Display 7=Activities 8=Contacts
//            9=Opportunities
//   F4=Prompt (status)  F6=Add  F21=Print customer directory
// ===================================================================
ctl-opt dftactgrp(*no) actgrp('CRMDEMO') bnddir('CRMBND')
        option(*srcstmt : *nodebugio) datfmt(*iso) timfmt(*iso);

dcl-f CRMCUSTLD workstn indds(ind) infds(wsds) sfile(CUSTSFL : rrn);

/include CRMDEMO/QRPGLESRC,CRMSRVH

dcl-ds ind len(99) qualified;
  sflDsp    ind pos(30);
  sflDspCtl ind pos(31);
  sflClr    ind pos(32);
  sflEnd    ind pos(33);
  optErr    ind pos(50);
  stsErr    ind pos(51);
  mineErr   ind pos(52);
  inactive  ind pos(61);
  mine      ind pos(62);
end-ds;

dcl-ds wsds;
  wsAid char(1) pos(369);
end-ds;

dcl-s rrn      packed(5 : 0);
dcl-s me       char(10);
dcl-s hadError ind;
dcl-s code     char(10);
dcl-s rtnMsg   char(78);

exec sql set option commit = *none, closqlcsr = *endmod,
                    datfmt = *iso, naming = *sys;

me = crmPsds.curUser;
crm_registerUser();
CUSER = me;
CMINE = 'N';
loadSubfile();

dow *on;
  write FKEYS;
  exfmt CUSTCTL;
  FMSG = '';
  ind.stsErr = *off;
  ind.mineErr = *off;

  select;
    when wsAid = KEY_F03 or wsAid = KEY_F12;
      leave;

    when wsAid = KEY_F05;
      loadSubfile();

    when wsAid = KEY_F04;
      if CSRFLD = 'CSTS';
        code = CSTS;
        CRMPRMPT('STATUS' : code);
        CSTS = code;
        loadSubfile();
      else;
        FMSG = 'Place the cursor on the Status field and press F4.';
      endif;

    when wsAid = KEY_F06;
      CRMCUSTM('A' : 0);
      loadSubfile();

    when wsAid = KEY_F21;
      CRMPRT('1' : 'Y' : rtnMsg);
      FMSG = rtnMsg;

    other;
      if validFilters();
        processOptions();
        if not hadError;
          loadSubfile();
        endif;
      endif;
  endsl;
enddo;

*inlr = *on;
return;

// -------------------------------------------------------------------
// validFilters - check the Status and Mine filter fields
// -------------------------------------------------------------------
dcl-proc validFilters;
  dcl-pi *n ind;
  end-pi;

  if CMINE = ' ';
    CMINE = 'N';
  endif;
  if CMINE <> 'Y' and CMINE <> 'N';
    ind.mineErr = *on;
    FMSG = 'Mine only must be Y or N.';
    return *off;
  endif;
  if CSTS <> ' ' and crm_codeDesc('STATUS' : CSTS) = '';
    ind.stsErr = *on;
    FMSG = 'Status must be P, A, I or blank. Press F4 for a list.';
    return *off;
  endif;
  return *on;
end-proc;

// -------------------------------------------------------------------
// loadSubfile - (re)load the customer list from SQL
// -------------------------------------------------------------------
dcl-proc loadSubfile;
  dcl-ds row qualified;
    custId  int(10);
    name    char(40);
    city    char(25);
    state   char(2);
    status  char(1);
    stsDesc char(30);
    owner   char(10);
  end-ds;
  dcl-s srch varchar(27);
  dcl-s sts  char(1);
  dcl-s mine char(1);

  ind.sflDsp = *off;
  ind.sflDspCtl = *off;
  ind.sflClr = *on;
  write CUSTCTL;
  ind.sflClr = *off;
  rrn = 0;

  srch = '%' + %trim(CSRCH) + '%';
  sts  = CSTS;
  mine = CMINE;

  exec sql declare custCur cursor for
    select C.CUSTID, C.NAME, C.CITY, C.STATE, C.STATUS,
           coalesce(S.DESCR, ''), C.OWNER
      from CUSTOMER C
      left join CRMCODE S
        on S.CODETYPE = 'STATUS' and S.CODE = C.STATUS
     where upper(C.NAME) like upper(:srch)
       and (:sts = ' ' or C.STATUS = :sts)
       and (:mine <> 'Y' or C.OWNER = :me)
     order by C.NAME
     for read only;

  exec sql open custCur;

  dow rrn < 9999;
    exec sql fetch next from custCur into :row;
    if sqlcode <> 0;
      leave;
    endif;
    rrn += 1;
    SOPT    = '';
    SCUSTID = row.custId;
    SNAME   = row.name;
    SCITY   = row.city;
    SSTATE  = row.state;
    SSTSD   = row.stsDesc;
    SOWNER  = row.owner;
    ind.optErr   = *off;
    ind.inactive = row.status = 'I';
    ind.mine     = row.owner = me;
    write CUSTSFL;
  enddo;

  exec sql close custCur;

  CCOUNT = rrn;
  ind.sflDsp = rrn > 0;
  ind.sflDspCtl = *on;
  ind.sflEnd = *on;
  if rrn = 0;
    FMSG = 'No customers match the filters. Press F6 to add one.';
  endif;
end-proc;

// -------------------------------------------------------------------
// processOptions - act on the options typed in the subfile
// -------------------------------------------------------------------
dcl-proc processOptions;
  hadError = *off;

  readc CUSTSFL;
  dow not %eof(CRMCUSTLD);
    ind.optErr = *off;

    select;
      when SOPT = ' ';
      when SOPT = '2';
        CRMCUSTM('C' : SCUSTID);
      when SOPT = '4';
        deleteCustomer(SCUSTID);
      when SOPT = '5';
        CRMCUSTM('D' : SCUSTID);
      when SOPT = '7';
        CRMACT(SCUSTID);
      when SOPT = '8';
        CRMCONT(SCUSTID);
      when SOPT = '9';
        CRMPIPE(SCUSTID);
      other;
        ind.optErr = *on;
        hadError = *on;
        FMSG = 'Option ' + SOPT + ' is not valid.';
    endsl;

    if not ind.optErr;
      SOPT = '';
    endif;
    update CUSTSFL;
    readc CUSTSFL;
  enddo;
end-proc;

// -------------------------------------------------------------------
// deleteCustomer - confirm in a window, then delete with children
// -------------------------------------------------------------------
dcl-proc deleteCustomer;
  dcl-pi *n;
    custId int(10) const;
  end-pi;

  dcl-s id   int(10);
  dcl-s name char(40);

  id = custId;
  name = crm_custName(id);
  WTEXT1 = 'Delete ' + %char(id) + ' ' + name;
  WTEXT2 = 'Its contacts, activities and deals are deleted too.';
  exfmt CONFWDW;

  if wsAid <> KEY_F10;
    FMSG = 'Delete cancelled.';
    return;
  endif;

  exec sql delete from ACTIVITY where CUSTID = :id;
  exec sql delete from CONTACT  where CUSTID = :id;
  exec sql delete from OPPTY    where CUSTID = :id;
  exec sql delete from CUSTOMER where CUSTID = :id;

  crm_logEvent('CUSTDLT' : id : '' : 'Deleted customer ' + %trim(name));
  FMSG = 'Customer ' + %trim(name) + ' deleted.';
end-proc;
