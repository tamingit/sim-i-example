**FREE
// ===================================================================
// CRMCUSTM - Customer maintenance: add / change / display (24 x 80)
//
// Optimistic locking: the row change timestamp (CHGTS) read with the
// customer must still match when saving. If another session saved
// first, a window shows who changed it and offers:
//   F5=Load their version   F10=Save mine anyway   F12=Keep editing
// ===================================================================
ctl-opt dftactgrp(*no) actgrp('CRMDEMO') bnddir('CRMBND')
        option(*srcstmt : *nodebugio) datfmt(*iso) timfmt(*iso);

dcl-f CRMCUSTMD workstn indds(ind) infds(wsds);

/include CRMDEMO/QRPGLESRC,CRMSRVH

dcl-pi *n;
  mode   char(1) const;
  custId int(10) const;
end-pi;

dcl-ds ind len(99) qualified;
  protect  ind pos(40);
  nameErr  ind pos(51);
  stsErr   ind pos(52);
  indErr   ind pos(53);
  ownErr   ind pos(54);
  overdue  ind pos(60);
end-ds;

dcl-ds wsds;
  wsAid char(1) pos(369);
end-ds;

// Working copy of the customer row (used as SQL host variables)
dcl-ds cust qualified;
  name     char(40);
  status   char(1);
  industry char(10);
  addr1    char(40);
  city     char(25);
  state    char(2);
  zip      char(10);
  phone    char(15);
  website  char(40);
  owner    char(10);
end-ds;

dcl-s me      char(10);
dcl-s curMode char(1);
dcl-s id      int(10);
dcl-s origTs  timestamp;
dcl-s rtnMsg  char(78);

exec sql set option commit = *none, closqlcsr = *endmod,
                    datfmt = *iso, naming = *sys;

me = crmPsds.curUser;
curMode = mode;
id = custId;
DUSER = me;

if curMode = 'A';
  clearFields();
elseif not loadCustomer();
  *inlr = *on;
  return;
endif;

dow *on;
  setTitle();
  ind.protect = curMode = 'D';
  exfmt DETAIL;
  DMSG = '';
  clearErrors();

  select;
    when wsAid = KEY_F03 or wsAid = KEY_F12;
      leave;

    when wsAid = KEY_F05;
      if curMode <> 'A';
        loadCustomer();
        DMSG = 'Reloaded from the database.';
      endif;

    when wsAid = KEY_F04;
      if curMode <> 'D';
        promptField();
      endif;

    when wsAid = KEY_F07 or wsAid = KEY_F08 or wsAid = KEY_F09;
      if curMode = 'A';
        DMSG = 'Save the new customer first.';
      elseif wsAid = KEY_F07;
        CRMACT(id);
        loadSummary();
      elseif wsAid = KEY_F08;
        CRMCONT(id);
        loadSummary();
      else;
        emailPrimary();
      endif;

    when wsAid = KEY_ENTER;
      if curMode = 'D';
        leave;
      endif;
      screenToCust();
      refreshDescs();
      if validate();
        if save();
          leave;
        endif;
      endif;
  endsl;
enddo;

*inlr = *on;
return;

// -------------------------------------------------------------------
// setTitle
// -------------------------------------------------------------------
dcl-proc setTitle;
  select;
    when curMode = 'A';
      DTITLE = 'Customer - Add';
    when curMode = 'C';
      DTITLE = 'Customer - Change';
    other;
      DTITLE = 'Customer - Display';
  endsl;
end-proc;

// -------------------------------------------------------------------
// clearErrors
// -------------------------------------------------------------------
dcl-proc clearErrors;
  ind.nameErr = *off;
  ind.stsErr  = *off;
  ind.indErr  = *off;
  ind.ownErr  = *off;
end-proc;

// -------------------------------------------------------------------
// clearFields - defaults for a new customer
// -------------------------------------------------------------------
dcl-proc clearFields;
  clear cust;
  cust.status = 'P';
  cust.owner  = me;
  custToScreen();
  DCUSTID  = 0;
  DCRTINFO = '(new)';
  DCHGINFO = '';
  refreshDescs();
  DCONTCNT = 0;
  DPRIMARY = '';
  DOPPCNT  = 0;
  DOPPAMT  = 0;
  DTASKCNT = 0;
  DTASKOVR = 0;
  DLASTACT = '';
  ind.overdue = *off;
end-proc;

// -------------------------------------------------------------------
// loadCustomer - read the row and remember its change timestamp
// -------------------------------------------------------------------
dcl-proc loadCustomer;
  dcl-pi *n ind;
  end-pi;

  dcl-s crtUser char(10);
  dcl-s crtTs   timestamp;
  dcl-s chgUser char(10);

  exec sql
    select NAME, STATUS, INDUSTRY, ADDR1, CITY, STATE, ZIP, PHONE,
           WEBSITE, OWNER, CRTUSER, CRTTS, CHGUSER, CHGTS
      into :cust, :crtUser, :crtTs, :chgUser, :origTs
      from CUSTOMER
     where CUSTID = :id;

  if sqlcode <> 0;
    return *off;
  endif;

  custToScreen();
  DCUSTID  = id;
  DCRTINFO = %char(%date(crtTs) : *usa) + ' by ' + %trim(crtUser);
  DCHGINFO = fmtTs(origTs) + ' by ' + %trim(chgUser);
  refreshDescs();
  loadSummary();
  return *on;
end-proc;

// -------------------------------------------------------------------
// custToScreen / screenToCust
// -------------------------------------------------------------------
dcl-proc custToScreen;
  DNAME    = cust.name;
  DSTATUS  = cust.status;
  DINDUS   = cust.industry;
  DADDR1   = cust.addr1;
  DCITY    = cust.city;
  DSTATE   = cust.state;
  DZIP     = cust.zip;
  DPHONE   = cust.phone;
  DWEBSITE = cust.website;
  DOWNER   = cust.owner;
end-proc;

dcl-proc screenToCust;
  cust.name     = DNAME;
  cust.status   = DSTATUS;
  cust.industry = DINDUS;
  cust.addr1    = DADDR1;
  cust.city     = DCITY;
  cust.state    = DSTATE;
  cust.zip      = DZIP;
  cust.phone    = DPHONE;
  cust.website  = DWEBSITE;
  cust.owner    = DOWNER;
end-proc;

// -------------------------------------------------------------------
// refreshDescs - descriptions next to the code fields
// -------------------------------------------------------------------
dcl-proc refreshDescs;
  DSTSDESC = crm_codeDesc('STATUS' : DSTATUS);
  DINDDESC = crm_codeDesc('INDUSTRY' : DINDUS);
  DOWNNAME = crm_codeDesc('USER' : DOWNER);
end-proc;

// -------------------------------------------------------------------
// loadSummary - contacts, open deals, tasks, last activity
// -------------------------------------------------------------------
dcl-proc loadSummary;
  dcl-s cnt     int(10);
  dcl-s cnt2    int(10);
  dcl-s amt     packed(15 : 2);
  dcl-s first   char(20);
  dcl-s last    char(25);
  dcl-s phone   char(15);
  dcl-s actDate date;
  dcl-s actType char(5);
  dcl-s subject char(50);

  exec sql select count(*) into :cnt from CONTACT where CUSTID = :id;
  DCONTCNT = cnt;

  DPRIMARY = '';
  exec sql
    select FIRSTNAME, LASTNAME, PHONE into :first, :last, :phone
      from CONTACT
     where CUSTID = :id
     order by ISPRIMARY desc, CONTID
     fetch first 1 row only;
  if sqlcode = 0;
    DPRIMARY = %trim(first) + ' ' + %trim(last) + '  ' + %trim(phone);
  endif;

  exec sql
    select count(*), coalesce(sum(AMOUNT), 0) into :cnt, :amt
      from OPPTY
     where CUSTID = :id and STAGE < '5';
  DOPPCNT = cnt;
  DOPPAMT = amt;

  exec sql
    select count(*),
           coalesce(sum(case when DUEDATE <> '0001-01-01'
                              and DUEDATE < current date
                             then 1 else 0 end), 0)
      into :cnt, :cnt2
      from ACTIVITY
     where CUSTID = :id and DONE = 'N';
  DTASKCNT = cnt;
  DTASKOVR = cnt2;
  ind.overdue = cnt2 > 0;

  DLASTACT = '';
  exec sql
    select ACTDATE, ACTTYPE, SUBJECT into :actDate, :actType, :subject
      from ACTIVITY
     where CUSTID = :id
     order by ACTDATE desc, ACTID desc
     fetch first 1 row only;
  if sqlcode = 0;
    DLASTACT = %char(actDate : *usa) + ' ' + %trim(actType) + ' - '
             + %trim(subject);
  endif;
end-proc;

// -------------------------------------------------------------------
// promptField - F4 on Status, Industry or Owner
// -------------------------------------------------------------------
dcl-proc promptField;
  dcl-s code char(10);

  select;
    when CSRFLD = 'DSTATUS';
      code = DSTATUS;
      CRMPRMPT('STATUS' : code);
      DSTATUS = code;
    when CSRFLD = 'DINDUS';
      code = DINDUS;
      CRMPRMPT('INDUSTRY' : code);
      DINDUS = code;
    when CSRFLD = 'DOWNER';
      code = DOWNER;
      CRMPRMPT('USER' : code);
      DOWNER = code;
    other;
      DMSG = 'F4 works on the Status, Industry and Owner fields.';
  endsl;
  refreshDescs();
end-proc;

// -------------------------------------------------------------------
// validate - returns *on when the screen is OK to save
// -------------------------------------------------------------------
dcl-proc validate;
  dcl-pi *n ind;
  end-pi;

  if DOWNNAME = '';
    ind.ownErr = *on;
    DMSG = 'Owner must be a CRM user. Press F4 for a list.';
  endif;
  if DINDUS <> '' and DINDDESC = '';
    ind.indErr = *on;
    DMSG = 'Industry code is not valid. Press F4 for a list.';
  endif;
  if DSTSDESC = '';
    ind.stsErr = *on;
    DMSG = 'Status must be P, A or I. Press F4 for a list.';
  endif;
  if DNAME = '';
    ind.nameErr = *on;
    DMSG = 'Customer name is required.';
  endif;

  return not (ind.nameErr or ind.stsErr or ind.indErr or ind.ownErr);
end-proc;

// -------------------------------------------------------------------
// save - insert or update; returns *on when saved
// -------------------------------------------------------------------
dcl-proc save;
  dcl-pi *n ind;
  end-pi;

  dcl-s newId   int(10);
  dcl-s notify  char(10);

  notify = '';
  if cust.owner <> me;
    notify = cust.owner;
  endif;

  if curMode = 'A';
    exec sql
      insert into CUSTOMER
             (NAME, STATUS, INDUSTRY, ADDR1, CITY, STATE, ZIP, PHONE,
              WEBSITE, OWNER, CRTUSER, CHGUSER)
      values (:cust.name, :cust.status, :cust.industry, :cust.addr1,
              :cust.city, :cust.state, :cust.zip, :cust.phone,
              :cust.website, :cust.owner, :me, :me);
    if sqlcode <> 0;
      DMSG = 'Add failed, SQLCODE ' + %char(sqlcode) + '.';
      return *off;
    endif;
    exec sql values identity_val_local() into :newId;
    crm_logEvent('CUSTADD' : newId : notify
                 : 'Added customer ' + %trim(cust.name));
    return *on;
  endif;

  // Change: only succeeds if nobody else saved since we read the row
  exec sql
    update CUSTOMER
       set NAME = :cust.name, STATUS = :cust.status,
           INDUSTRY = :cust.industry, ADDR1 = :cust.addr1,
           CITY = :cust.city, STATE = :cust.state, ZIP = :cust.zip,
           PHONE = :cust.phone, WEBSITE = :cust.website,
           OWNER = :cust.owner, CHGUSER = :me
     where CUSTID = :id and CHGTS = :origTs;

  if sqlcode = 100;
    return handleConflict();
  elseif sqlcode <> 0;
    DMSG = 'Update failed, SQLCODE ' + %char(sqlcode) + '.';
    return *off;
  endif;

  crm_logEvent('CUSTCHG' : id : notify
               : 'Updated customer ' + %trim(cust.name));
  return *on;
end-proc;

// -------------------------------------------------------------------
// handleConflict - someone else saved this customer first
// -------------------------------------------------------------------
dcl-proc handleConflict;
  dcl-pi *n ind;
  end-pi;

  dcl-s who  char(10);
  dcl-s chgTs timestamp;

  exec sql select CHGUSER, CHGTS into :who, :chgTs
             from CUSTOMER where CUSTID = :id;
  if sqlcode <> 0;
    DMSG = 'This customer was deleted by another user.';
    return *off;
  endif;

  CFINFO = %trim(who) + ' at ' + fmtTs(chgTs);
  exfmt CNFLWDW;

  select;
    when wsAid = KEY_F05;
      loadCustomer();
      DMSG = 'Loaded the latest version. Your changes were discarded.';
      return *off;
    when wsAid = KEY_F10;
      origTs = chgTs;
      return save();
    other;
      DMSG = 'Your changes are still on the screen. Enter saves them.';
      return *off;
  endsl;
end-proc;

// -------------------------------------------------------------------
// emailPrimary - F9: email the primary contact
// -------------------------------------------------------------------
dcl-proc emailPrimary;
  dcl-s email  char(60);
  dcl-s first  char(20);
  dcl-s last   char(25);
  dcl-s contId int(10);

  exec sql
    select CONTID, FIRSTNAME, LASTNAME, EMAIL
      into :contId, :first, :last, :email
      from CONTACT
     where CUSTID = :id
     order by ISPRIMARY desc, CONTID
     fetch first 1 row only;

  if sqlcode <> 0;
    DMSG = 'This customer has no contacts. Press F8 to add one.';
    return;
  endif;

  CRMEMAIL(email : %trim(first) + ' ' + %trim(last) : id : contId
           : rtnMsg);
  DMSG = rtnMsg;
  loadSummary();
end-proc;

// -------------------------------------------------------------------
// fmtTs - MM/DD/YYYY HH:MM:SS
// -------------------------------------------------------------------
dcl-proc fmtTs;
  dcl-pi *n varchar(20);
    ts timestamp const;
  end-pi;

  return %char(%date(ts) : *usa) + ' ' + %char(%time(ts) : *hms);
end-proc;
