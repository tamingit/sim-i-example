**FREE
// ===================================================================
// CRMMENU - CRM demo main menu (24 x 80)
// ===================================================================
ctl-opt dftactgrp(*no) actgrp('CRMDEMO') bnddir('CRMBND')
        option(*srcstmt : *nodebugio) datfmt(*iso) timfmt(*iso);

dcl-f CRMMENUD workstn indds(ind) infds(wsds);

/include CRMDEMO/QRPGLESRC,CRMSRVH

dcl-ds ind len(99) qualified;
  optErr   ind pos(50);
  overdue  ind pos(60);
end-ds;

dcl-ds wsds;
  wsAid char(1) pos(369);
end-ds;

dcl-s me     char(10);
dcl-s opt    varchar(2);
dcl-s rtnMsg char(78);

exec sql set option commit = *none, closqlcsr = *endmod,
                    datfmt = *iso, naming = *sys;

me = crmPsds.curUser;
crm_registerUser();

dow *on;
  loadCounts();
  exfmt MENU;
  MMSG = '';
  ind.optErr = *off;

  if wsAid = KEY_F03;
    leave;
  elseif wsAid = KEY_F05;
    iter;
  endif;

  opt = %trim(MOPT);
  rtnMsg = '';
  select;
    when opt = '';
    when opt = '1';
      CRMCUSTL();
    when opt = '2';
      CRMACT(0);
    when opt = '3';
      CRMPIPE(0);
    when opt = '4';
      CRMDASH();
    when opt = '5';
      CRMPRT('1' : 'Y' : rtnMsg);
    when opt = '6';
      CRMEMAIL('' : '' : 0 : 0 : rtnMsg);
    other;
      MMSG = 'Option ' + opt + ' is not valid.';
      ind.optErr = *on;
      iter;
  endsl;
  MMSG = rtnMsg;
  MOPT = '';
enddo;

*inlr = *on;
return;

// -------------------------------------------------------------------
// loadCounts - user name and task counts for the menu header
// -------------------------------------------------------------------
dcl-proc loadCounts;
  dcl-s openCnt int(10);
  dcl-s overCnt int(10);

  MUSER = me;
  MNAME = crm_codeDesc('USER' : me);

  exec sql
    select count(*),
           coalesce(sum(case when DUEDATE <> '0001-01-01'
                              and DUEDATE < current date
                             then 1 else 0 end), 0)
      into :openCnt, :overCnt
      from ACTIVITY
     where ASSIGNTO = :me and DONE = 'N';

  MOPEN = openCnt;
  MOVER = overCnt;
  ind.overdue = overCnt > 0;
end-proc;
