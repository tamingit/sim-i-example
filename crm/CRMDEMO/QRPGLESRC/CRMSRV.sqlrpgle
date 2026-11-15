**FREE
// ===================================================================
// CRMSRV - CRM demo service procedures (bound into *SRVPGM CRMSRV)
// Build:  CRTSQLRPGI OBJ(CRMDEMO/CRMSRV) OBJTYPE(*MODULE) ...
//         CRTSRVPGM SRVPGM(CRMDEMO/CRMSRV) EXPORT(*ALL)
// ===================================================================
ctl-opt nomain option(*srcstmt : *nodebugio) datfmt(*iso) timfmt(*iso);

/include CRMDEMO/QRPGLESRC,CRMSRVH

exec sql set option commit = *none, closqlcsr = *endmod,
                    datfmt = *iso, naming = *sys;

// -------------------------------------------------------------------
// crm_logEvent - add a row to the event log
// -------------------------------------------------------------------
dcl-proc crm_logEvent export;
  dcl-pi *n;
    evtType  char(8)     const;
    custId   int(10)     const;
    forUser  char(10)    const;
    evtText  varchar(80) const;
  end-pi;

  dcl-s me    char(10);
  dcl-s eType char(8);
  dcl-s eCust int(10);
  dcl-s eFor  char(10);
  dcl-s eText char(80);

  me    = crmPsds.curUser;
  eType = evtType;
  eCust = custId;
  eFor  = forUser;
  eText = evtText;

  exec sql insert into CRMEVENT
             (EVTUSER, EVTTYPE, CUSTID, FORUSER, EVTTEXT)
           values (:me, :eType, :eCust, :eFor, :eText);
end-proc;

// -------------------------------------------------------------------
// crm_registerUser - make sure the current user is in CRMUSER
// -------------------------------------------------------------------
dcl-proc crm_registerUser export;
  dcl-s me      char(10);
  dcl-s txt     char(30);
  dcl-s found   int(10);

  me = crmPsds.curUser;

  exec sql select count(*) into :found
             from CRMUSER where USERID = :me;

  if found > 0;
    exec sql update CRMUSER set LASTSEEN = current timestamp
              where USERID = :me;
    return;
  endif;

  // Use the user profile text as the full name when we can see it
  txt = '';
  exec sql select coalesce(substr(TEXT_DESCRIPTION, 1, 30), '')
             into :txt
             from QSYS2.USER_INFO_BASIC
            where AUTHORIZATION_NAME = :me;
  if sqlcode <> 0 or txt = '';
    txt = me;
  endif;

  exec sql insert into CRMUSER (USERID, FULLNAME)
           values (:me, :txt);
end-proc;

// -------------------------------------------------------------------
// crm_codeDesc - description for a code value or a user
// -------------------------------------------------------------------
dcl-proc crm_codeDesc export;
  dcl-pi *n char(30);
    codeType char(10) const;
    code     char(10) const;
  end-pi;

  dcl-s cType char(10);
  dcl-s cCode char(10);
  dcl-s descr char(30);

  cType = codeType;
  cCode = code;
  descr = '';

  if cCode = '';
    return '';
  endif;

  if cType = 'USER';
    exec sql select FULLNAME into :descr
               from CRMUSER where USERID = :cCode;
  else;
    exec sql select DESCR into :descr
               from CRMCODE
              where CODETYPE = :cType and CODE = :cCode;
  endif;

  if sqlcode <> 0;
    descr = '';
  endif;
  return descr;
end-proc;

// -------------------------------------------------------------------
// crm_custName - customer name for an ID
// -------------------------------------------------------------------
dcl-proc crm_custName export;
  dcl-pi *n char(40);
    custId int(10) const;
  end-pi;

  dcl-s id   int(10);
  dcl-s name char(40);

  id = custId;
  name = '';
  exec sql select NAME into :name from CUSTOMER where CUSTID = :id;
  if sqlcode <> 0;
    name = '';
  endif;
  return name;
end-proc;

// -------------------------------------------------------------------
// crm_runCmd - run a CL command, return blank or the message id
// -------------------------------------------------------------------
dcl-proc crm_runCmd export;
  dcl-pi *n char(7);
    cmd varchar(3000) const;
  end-pi;

  dcl-pr qcmdexc extpgm('QCMDEXC');
    command char(3000)     const;
    length  packed(15 : 5) const;
  end-pr;

  monitor;
    qcmdexc(cmd : %len(cmd));
  on-error;
    if crmPsds.excId = '';
      return 'CPF0000';
    endif;
    return crmPsds.excId;
  endmon;

  return '';
end-proc;

// -------------------------------------------------------------------
// crm_fmtDate - MM/DD/YYYY or blank
// -------------------------------------------------------------------
dcl-proc crm_fmtDate export;
  dcl-pi *n char(10);
    inDate date const;
  end-pi;

  if inDate = NO_DATE;
    return '';
  endif;
  return %char(inDate : *usa);
end-proc;

// -------------------------------------------------------------------
// crm_parseDate - accept MM/DD/YYYY, MMDDYYYY or YYYY-MM-DD
// -------------------------------------------------------------------
dcl-proc crm_parseDate export;
  dcl-pi *n ind;
    text    char(10) const;
    outDate date;
  end-pi;

  dcl-s t varchar(10);

  t = %trim(text);
  if t = '';
    outDate = NO_DATE;
    return *on;
  endif;

  monitor;
    if %len(t) = 8 and %check('0123456789' : t) = 0;
      outDate = %date(t : *usa0);
    elseif %subst(t : 5 : 1) = '-';
      outDate = %date(t : *iso);
    else;
      outDate = %date(t : *usa);
    endif;
  on-error;
    return *off;
  endmon;

  return *on;
end-proc;

// -------------------------------------------------------------------
// crm_quote - double apostrophes for a quoted CL string
// -------------------------------------------------------------------
dcl-proc crm_quote export;
  dcl-pi *n varchar(3000);
    text varchar(3000) const;
  end-pi;

  return %scanrpl('''' : '''''' : text);
end-proc;
