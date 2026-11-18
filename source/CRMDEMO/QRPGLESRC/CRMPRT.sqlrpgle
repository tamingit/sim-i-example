**FREE
// ===================================================================
// CRMPRT - Print reports to a spooled file (printer file CRMRPTP)
//   report   1 = Customer directory (customers with contacts)
//            2 = Pipeline by stage with subtotals
//   interact Y = show the options window (report, outq, hold)
//            N = print straight away to the job's default outq
// ===================================================================
ctl-opt dftactgrp(*no) actgrp('CRMDEMO') bnddir('CRMBND')
        option(*srcstmt : *nodebugio) datfmt(*iso) timfmt(*iso);

dcl-f CRMPRTD workstn indds(ind) infds(wsds) usropn;
dcl-f CRMRPTP printer oflind(overflow) usropn;

/include CRMDEMO/QRPGLESRC,CRMSRVH

dcl-pi *n;
  report   char(1) const;
  interact char(1) const;
  rtnMsg   char(78);
end-pi;

dcl-ds ind len(99) qualified;
  rptErr  ind pos(51);
  outqErr ind pos(52);
  holdErr ind pos(53);
end-ds;

dcl-ds wsds;
  wsAid char(1) pos(369);
end-ds;

dcl-s overflow ind;
dcl-s me       char(10);
dcl-s rpt      char(1);
dcl-s outq     char(10);
dcl-s hold     char(1);
dcl-s splf     char(10);
dcl-s msgId    char(7);

exec sql set option commit = *none, closqlcsr = *endmod,
                    datfmt = *iso, naming = *sys;

me   = crmPsds.curUser;
rpt  = report;
outq = '*JOB';
hold = 'N';
rtnMsg = '';

if interact = 'Y';
  if not askOptions();
    rtnMsg = 'Print cancelled.';
    *inlr = *on;
    return;
  endif;
endif;

if rpt = '2';
  splf = 'CRMPIPE';
else;
  splf = 'CRMCUST';
endif;

msgId = crm_runCmd('OVRPRTF FILE(CRMRPTP) OUTQ(' + %trim(outq) + ')'
                 + ' HOLD(' + %trim(yesNo(hold)) + ')'
                 + ' SPLFNAME(' + %trim(splf) + ')'
                 + ' USRDTA(''CRM Demo'') OVRSCOPE(*ACTGRPDFN)');
if msgId <> '';
  rtnMsg = 'Could not set up the printer file (' + msgId + ').';
  *inlr = *on;
  return;
endif;

monitor;
  open CRMRPTP;
on-error;
  rtnMsg = 'Could not open the printer file. Check the output queue.';
  crm_runCmd('DLTOVR FILE(CRMRPTP) LVL(*ACTGRPDFN)');
  *inlr = *on;
  return;
endmon;

RUSER = me;
if rpt = '2';
  printPipeline();
else;
  printCustomers();
endif;
write ENDRPT;
close CRMRPTP;
crm_runCmd('DLTOVR FILE(CRMRPTP) LVL(*ACTGRPDFN)');

crm_logEvent('PRINT' : 0 : ''
             : 'Printed ' + %trim(RTITLE) + ' (' + %trim(splf) + ')');
rtnMsg = 'Report ' + %trim(splf) + ' sent to output queue '
       + %trim(outq) + '. Use WRKSPLF to view it.';

*inlr = *on;
return;

// -------------------------------------------------------------------
// askOptions - options window; returns *off on F12
// -------------------------------------------------------------------
dcl-proc askOptions;
  dcl-pi *n ind;
  end-pi;

  open CRMPRTD;
  PRPT  = rpt;
  POUTQ = outq;
  PHOLD = hold;
  PMSG  = '';

  dow *on;
    exfmt PRTWDW;
    PMSG = '';
    ind.rptErr  = *off;
    ind.outqErr = *off;
    ind.holdErr = *off;

    if wsAid = KEY_F12;
      close CRMPRTD;
      return *off;
    endif;

    if PHOLD <> 'Y' and PHOLD <> 'N';
      ind.holdErr = *on;
      PMSG = 'Hold must be Y or N.';
    endif;
    if POUTQ = '';
      POUTQ = '*JOB';
    endif;
    if POUTQ <> '*JOB'
       and crm_runCmd('CHKOBJ OBJ(' + %trim(POUTQ) + ') OBJTYPE(*OUTQ)')
           <> '';
      ind.outqErr = *on;
      PMSG = 'Output queue ' + %trim(POUTQ) + ' was not found.';
    endif;
    if PRPT <> '1' and PRPT <> '2';
      ind.rptErr = *on;
      PMSG = 'Report must be 1 or 2.';
    endif;
    if PMSG = '';
      leave;
    endif;
  enddo;

  rpt  = PRPT;
  outq = POUTQ;
  hold = PHOLD;
  close CRMPRTD;
  return *on;
end-proc;

// -------------------------------------------------------------------
// printCustomers - customer directory with contacts
// -------------------------------------------------------------------
dcl-proc printCustomers;
  dcl-ds cust qualified;
    custId   int(10);
    name     char(40);
    stsDesc  char(30);
    industry char(10);
    city     char(25);
    state    char(2);
    phone    char(15);
    owner    char(10);
  end-ds;
  dcl-ds cont qualified;
    first char(20);
    last  char(25);
    title char(30);
    phone char(15);
    email char(60);
    prim  char(1);
  end-ds;

  dcl-s cid int(10);

  RTITLE = 'Customer Directory';
  RSUBT  = 'All customers and their contacts (* = primary contact)';
  write HEADER;
  write CUSTCOLS;
  overflow = *off;

  exec sql declare rptCust cursor for
    select C.CUSTID, C.NAME, coalesce(S.DESCR, ''), C.INDUSTRY,
           C.CITY, C.STATE, C.PHONE, C.OWNER
      from CUSTOMER C
      left join CRMCODE S
        on S.CODETYPE = 'STATUS' and S.CODE = C.STATUS
     order by C.NAME
     for read only;

  exec sql declare rptCont cursor for
    select FIRSTNAME, LASTNAME, TITLE, PHONE, EMAIL, ISPRIMARY
      from CONTACT
     where CUSTID = :cid
     order by ISPRIMARY desc, LASTNAME, FIRSTNAME
     for read only;

  exec sql open rptCust;
  dow *on;
    exec sql fetch next from rptCust into :cust;
    if sqlcode <> 0;
      leave;
    endif;

    newPageIfNeeded('1');
    PCUSTID = cust.custId;
    PNAME   = cust.name;
    PSTSD   = cust.stsDesc;
    PIND    = cust.industry;
    PCITY   = cust.city;
    PST     = cust.state;
    PPHONE  = cust.phone;
    POWNER  = cust.owner;
    write CUSTDTL;

    cid = cust.custId;
    exec sql open rptCont;
    dow *on;
      exec sql fetch next from rptCont into :cont;
      if sqlcode <> 0;
        leave;
      endif;
      newPageIfNeeded('1');
      PCPRIM  = '';
      if cont.prim = 'Y';
        PCPRIM = '*';
      endif;
      PCNAME  = %trim(cont.first) + ' ' + %trim(cont.last);
      PCTITLE = cont.title;
      PCPHONE = cont.phone;
      PCEMAIL = cont.email;
      write CONTDTL;
    enddo;
    exec sql close rptCont;
  enddo;
  exec sql close rptCust;
end-proc;

// -------------------------------------------------------------------
// printPipeline - deals grouped by stage with totals
// -------------------------------------------------------------------
dcl-proc printPipeline;
  dcl-ds opp qualified;
    oppId     int(10);
    custName  char(40);
    oppName   char(40);
    stage     char(1);
    stageName char(30);
    amount    packed(11 : 2);
    prob      int(5);
    closeDate date;
    owner     char(10);
  end-ds;

  dcl-s curStage char(1);
  dcl-s wgt      packed(15 : 2);
  dcl-s sCnt     int(10);
  dcl-s sAmt     packed(15 : 2);
  dcl-s sWgt     packed(15 : 2);
  dcl-s gCnt     int(10);
  dcl-s gAmt     packed(15 : 2);
  dcl-s gWgt     packed(15 : 2);

  RTITLE = 'Sales Pipeline by Stage';
  RSUBT  = 'All opportunities. Open total excludes Won and Lost.';
  write HEADER;
  write PIPECOLS;
  overflow = *off;
  curStage = '';

  exec sql declare rptOpp cursor for
    select O.OPPID, coalesce(C.NAME, ''), O.OPPNAME, O.STAGE,
           coalesce(S.DESCR, ''), O.AMOUNT, O.PROB, O.CLOSEDATE,
           O.OWNER
      from OPPTY O
      left join CUSTOMER C on C.CUSTID = O.CUSTID
      left join CRMCODE S
        on S.CODETYPE = 'STAGE' and S.CODE = O.STAGE
     order by O.STAGE, O.CLOSEDATE, O.OPPID
     for read only;

  exec sql open rptOpp;
  dow *on;
    exec sql fetch next from rptOpp into :opp;
    if sqlcode <> 0;
      leave;
    endif;

    if opp.stage <> curStage;
      if curStage <> '';
        printStageTotal(sCnt : sAmt : sWgt);
      endif;
      curStage = opp.stage;
      sCnt = 0;
      sAmt = 0;
      sWgt = 0;
      newPageIfNeeded('2');
      PSTGNM = 'Stage ' + opp.stage + ' - ' + opp.stageName;
      write STGHDR;
    endif;

    eval(h) wgt = opp.amount * opp.prob / 100;
    newPageIfNeeded('2');
    POPPID  = opp.oppId;
    PPCUST  = opp.custName;
    POPP    = opp.oppName;
    PCLOSE  = crm_fmtDate(opp.closeDate);
    PPOWNER = opp.owner;
    PAMT    = opp.amount;
    PPROB   = opp.prob;
    eval(h) PWGT = wgt;
    write PIPEDTL;

    sCnt += 1;
    sAmt += opp.amount;
    sWgt += wgt;
    if opp.stage < '5';
      gCnt += 1;
      gAmt += opp.amount;
      gWgt += wgt;
    endif;
  enddo;
  exec sql close rptOpp;

  if curStage <> '';
    printStageTotal(sCnt : sAmt : sWgt);
  endif;

  newPageIfNeeded('2');
  PGCNT = gCnt;
  eval(h) PGAMT = gAmt;
  eval(h) PGWGT = gWgt;
  write GRDTOT;
end-proc;

// -------------------------------------------------------------------
// printStageTotal
// -------------------------------------------------------------------
dcl-proc printStageTotal;
  dcl-pi *n;
    cnt int(10)        const;
    amt packed(15 : 2) const;
    wgt packed(15 : 2) const;
  end-pi;

  newPageIfNeeded('2');
  PSCNT = cnt;
  eval(h) PSAMT = amt;
  eval(h) PSWGT = wgt;
  write STGTOT;
end-proc;

// -------------------------------------------------------------------
// newPageIfNeeded - page headings after overflow
// -------------------------------------------------------------------
dcl-proc newPageIfNeeded;
  dcl-pi *n;
    which char(1) const;
  end-pi;

  if not overflow;
    return;
  endif;
  write HEADER;
  if which = '2';
    write PIPECOLS;
  else;
    write CUSTCOLS;
  endif;
  overflow = *off;
end-proc;

// -------------------------------------------------------------------
// yesNo - Y/N to *YES/*NO
// -------------------------------------------------------------------
dcl-proc yesNo;
  dcl-pi *n char(4);
    flag char(1) const;
  end-pi;

  if flag = 'Y';
    return '*YES';
  endif;
  return '*NO';
end-proc;
