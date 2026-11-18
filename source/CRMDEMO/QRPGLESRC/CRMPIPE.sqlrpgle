**FREE
// ===================================================================
// CRMPIPE - Sales pipeline board (27 x 132)
//   Stage summary across the top, deals in a subfile below.
//   Options: 2=Change 3=Advance stage 4=Delete 5=Customer
//            7=Activities
//   F6=Add  F11=Show/hide closed  F21=Print pipeline report
// ===================================================================
ctl-opt dftactgrp(*no) actgrp('CRMDEMO') bnddir('CRMBND')
        option(*srcstmt : *nodebugio) datfmt(*iso) timfmt(*iso);

dcl-f CRMPIPED workstn indds(ind) infds(wsds) sfile(OPPSFL : rrn)
               usropn;

/include CRMDEMO/QRPGLESRC,CRMSRVH

dcl-pi *n;
  custId int(10) const;
end-pi;

dcl-ds ind len(99) qualified;
  sflDsp    ind pos(30);
  sflDspCtl ind pos(31);
  sflClr    ind pos(32);
  sflEnd    ind pos(33);
  custProt  ind pos(41);
  optErr    ind pos(50);
  err51     ind pos(51);
  err52     ind pos(52);
  err53     ind pos(53);
  err54     ind pos(54);
  err55     ind pos(55);
  err56     ind pos(56);
  err57     ind pos(57);
  late      ind pos(61);
  mine      ind pos(62);
  won       ind pos(63);
  lost      ind pos(64);
end-ds;

dcl-ds wsds;
  wsAid char(1) pos(369);
end-ds;

dcl-ds opp qualified;
  custId    int(10);
  oppName   char(40);
  stage     char(1);
  amount    packed(11 : 2);
  prob      int(5);
  closeDate date;
  owner     char(10);
end-ds;

dcl-s stageName char(12) dim(6);
dcl-s stageProb int(5)   dim(6);

dcl-s rrn      packed(5 : 0);
dcl-s me       char(10);
dcl-s hadError ind;
dcl-s rtnMsg   char(78);

exec sql set option commit = *none, closqlcsr = *endmod,
                    datfmt = *iso, naming = *sys;

stageName(1) = 'Lead';
stageName(2) = 'Qualified';
stageName(3) = 'Proposal';
stageName(4) = 'Negotiation';
stageName(5) = 'Won';
stageName(6) = 'Lost';
stageProb(1) = 10;
stageProb(2) = 25;
stageProb(3) = 50;
stageProb(4) = 75;
stageProb(5) = 100;
stageProb(6) = 0;

// The pipeline board needs a 27 x 132 capable session
monitor;
  open CRMPIPED;
on-error;
  dsply 'CRMPIPE needs a 27x132 session (e.g. 3477-FC).';
  *inlr = *on;
  return;
endmon;

me = crmPsds.curUser;
crm_registerUser();
CUSER   = me;
COWNER  = '';
CCUSTID = custId;
CCLOSED = 'N';
CCUSTNM = crm_custName(custId);
loadAll();

dow *on;
  write FKEYS;
  exfmt OPPCTL;
  FMSG = '';
  ind.err51 = *off;
  ind.err52 = *off;
  ind.err53 = *off;

  select;
    when wsAid = KEY_F03 or wsAid = KEY_F12;
      leave;
    when wsAid = KEY_F05;
      if validFilters();
        loadAll();
      endif;
    when wsAid = KEY_F06;
      if editOpp(0);
        FMSG = 'Opportunity added.';
      endif;
      loadAll();
    when wsAid = KEY_F11;
      if CCLOSED = 'Y';
        CCLOSED = 'N';
      else;
        CCLOSED = 'Y';
      endif;
      loadAll();
    when wsAid = KEY_F21;
      CRMPRT('2' : 'N' : rtnMsg);
      FMSG = rtnMsg;
    other;
      if validFilters();
        processOptions();
        if not hadError;
          loadAll();
        endif;
      endif;
  endsl;
enddo;

*inlr = *on;
return;

// -------------------------------------------------------------------
// validFilters
// -------------------------------------------------------------------
dcl-proc validFilters;
  dcl-pi *n ind;
  end-pi;

  if COWNER <> '' and crm_codeDesc('USER' : COWNER) = '';
    ind.err51 = *on;
    FMSG = 'Owner must be blank or a CRM user.';
    return *off;
  endif;
  CCUSTNM = '';
  if CCUSTID <> 0;
    CCUSTNM = crm_custName(CCUSTID);
    if CCUSTNM = '';
      ind.err52 = *on;
      FMSG = 'Customer number not found. Use 0 for all customers.';
      return *off;
    endif;
  endif;
  if CCLOSED <> 'Y' and CCLOSED <> 'N';
    ind.err53 = *on;
    FMSG = 'Show closed must be Y or N.';
    return *off;
  endif;
  return *on;
end-proc;

// -------------------------------------------------------------------
// loadAll - stage summary plus the subfile
// -------------------------------------------------------------------
dcl-proc loadAll;
  dcl-ds row qualified;
    oppId     int(10);
    custId    int(10);
    custName  char(40);
    oppName   char(40);
    stage     char(1);
    amount    packed(11 : 2);
    prob      int(5);
    closeDate date;
    owner     char(10);
  end-ds;
  dcl-ds stg qualified;
    stage  char(1);
    cnt    int(10);
    amount packed(15 : 2);
  end-ds;

  dcl-s fOwner  char(10);
  dcl-s fCust   int(10);
  dcl-s fClosed char(1);
  dcl-s cnt     int(10) dim(6);
  dcl-s amt     packed(15 : 2) dim(6);
  dcl-s openCnt int(10);
  dcl-s openAmt packed(15 : 2);
  dcl-s openWgt packed(15 : 2);
  dcl-s s       int(10);
  dcl-s today   date;

  today   = %date();
  fOwner  = COWNER;
  fCust   = CCUSTID;
  fClosed = CCLOSED;

  // --- Stage summary ---
  exec sql declare sumCur cursor for
    select STAGE, count(*), coalesce(sum(AMOUNT), 0)
      from OPPTY
     where (:fOwner = ' ' or OWNER = :fOwner)
       and (:fCust = 0 or CUSTID = :fCust)
     group by STAGE
     for read only;

  exec sql open sumCur;
  dow *on;
    exec sql fetch next from sumCur into :stg;
    if sqlcode <> 0;
      leave;
    endif;
    s = %int(stg.stage);
    if s >= 1 and s <= 6;
      cnt(s) = stg.cnt;
      amt(s) = stg.amount;
    endif;
  enddo;
  exec sql close sumCur;

  exec sql
    select count(*), coalesce(sum(AMOUNT), 0),
           coalesce(sum(AMOUNT * PROB / 100), 0)
      into :openCnt, :openAmt, :openWgt
      from OPPTY
     where STAGE < '5'
       and (:fOwner = ' ' or OWNER = :fOwner)
       and (:fCust = 0 or CUSTID = :fCust);

  CSUM1 = '';
  CSUM2 = '';
  for s = 1 to 6;
    %subst(CSUM1 : (s - 1) * 21 + 1 : 20)
      = %char(s) + '-' + stageName(s);
    %subst(CSUM2 : (s - 1) * 21 + 1 : 20)
      = %char(cnt(s)) + ' / ' + money(amt(s));
  endfor;
  CSUM3 = 'Open deals: ' + %char(openCnt)
        + '    Pipeline value: ' + money(openAmt)
        + '    Weighted forecast: ' + money(openWgt);
  if COWNER <> '';
    CSUM3 = %trimr(CSUM3) + '    Owner: ' + %trim(COWNER);
  endif;

  // --- Deals subfile ---
  ind.sflDsp = *off;
  ind.sflDspCtl = *off;
  ind.sflClr = *on;
  write OPPCTL;
  ind.sflClr = *off;
  rrn = 0;

  exec sql declare oppCur cursor for
    select O.OPPID, O.CUSTID, coalesce(C.NAME, ''), O.OPPNAME,
           O.STAGE, O.AMOUNT, O.PROB, O.CLOSEDATE, O.OWNER
      from OPPTY O
      left join CUSTOMER C on C.CUSTID = O.CUSTID
     where (:fOwner = ' ' or O.OWNER = :fOwner)
       and (:fCust = 0 or O.CUSTID = :fCust)
       and (:fClosed = 'Y' or O.STAGE < '5')
     order by O.STAGE, O.CLOSEDATE, O.OPPID
     for read only;

  exec sql open oppCur;
  dow rrn < 9999;
    exec sql fetch next from oppCur into :row;
    if sqlcode <> 0;
      leave;
    endif;
    rrn += 1;
    SOPT    = '';
    SOPPID  = row.oppId;
    SCUSTID = row.custId;
    SCUST   = row.custName;
    SOPP    = row.oppName;
    s = %int(row.stage);
    SSTAGE  = stageName(s);
    eval(h) SAMT = row.amount;
    SPROB   = row.prob;
    eval(h) SWGT = row.amount * row.prob / 100;
    SCLOSE  = crm_fmtDate(row.closeDate);
    SOWNER  = row.owner;
    ind.late  = row.stage < '5' and row.closeDate < today;
    ind.mine  = row.owner = me;
    ind.won   = row.stage = '5';
    ind.lost  = row.stage = '6';
    ind.optErr = *off;
    write OPPSFL;
  enddo;
  exec sql close oppCur;

  ind.sflDsp = rrn > 0;
  ind.sflDspCtl = *on;
  ind.sflEnd = *on;
  if rrn = 0;
    FMSG = 'No deals match the filters. Press F6 to add one.';
  endif;
end-proc;

// -------------------------------------------------------------------
// processOptions
// -------------------------------------------------------------------
dcl-proc processOptions;
  hadError = *off;

  readc OPPSFL;
  dow not %eof(CRMPIPED);
    ind.optErr = *off;

    select;
      when SOPT = ' ';
      when SOPT = '2';
        if editOpp(SOPPID);
          FMSG = 'Opportunity changed.';
        endif;
      when SOPT = '3';
        advanceStage(SOPPID);
      when SOPT = '4';
        deleteOpp(SOPPID);
      when SOPT = '5';
        CRMCUSTM('D' : SCUSTID);
      when SOPT = '7';
        CRMACT(SCUSTID);
      other;
        ind.optErr = *on;
        hadError = *on;
        FMSG = 'Option ' + SOPT + ' is not valid.';
    endsl;

    if not ind.optErr;
      SOPT = '';
    endif;
    update OPPSFL;
    readc OPPSFL;
  enddo;
end-proc;

// -------------------------------------------------------------------
// editOpp - add (oppId = 0) or change in a window
// -------------------------------------------------------------------
dcl-proc editOpp;
  dcl-pi *n ind;
    oppId int(10) const;
  end-pi;

  dcl-s oid      int(10);
  dcl-s oldStage char(1);
  dcl-s s        int(10);
  dcl-s notify   char(10);
  dcl-s evt      char(8);
  dcl-s evtText  varchar(80);

  oid = oppId;
  clear opp;

  if oid = 0;
    WTITLE = 'Add opportunity';
    opp.custId    = CCUSTID;
    opp.stage     = '1';
    opp.prob      = 0;
    opp.closeDate = %date() + %days(30);
    opp.owner     = me;
    ind.custProt  = CCUSTID <> 0;
  else;
    WTITLE = 'Change opportunity';
    exec sql
      select CUSTID, OPPNAME, STAGE, AMOUNT, PROB, CLOSEDATE, OWNER
        into :opp
        from OPPTY where OPPID = :oid;
    if sqlcode <> 0;
      FMSG = 'Opportunity no longer exists.';
      return *off;
    endif;
    ind.custProt = *on;
  endif;
  oldStage = opp.stage;

  WCUST   = opp.custId;
  WOPP    = opp.oppName;
  WSTAGE  = opp.stage;
  WAMT    = opp.amount;
  WPROB   = opp.prob;
  WCLOSE  = crm_fmtDate(opp.closeDate);
  WOWNER  = opp.owner;
  WMSG    = '';

  dow *on;
    WCUSTNM = crm_custName(WCUST);
    WOWNNM  = crm_codeDesc('USER' : WOWNER);
    exfmt OPPWDW;
    WMSG = '';
    ind.err51 = *off;
    ind.err52 = *off;
    ind.err53 = *off;
    ind.err54 = *off;
    ind.err55 = *off;
    ind.err56 = *off;
    ind.err57 = *off;

    if wsAid = KEY_F12 or wsAid = KEY_F03;
      return *off;
    endif;

    if crm_codeDesc('USER' : WOWNER) = '';
      ind.err57 = *on;
      WMSG = 'Owner must be a CRM user.';
    endif;
    if not crm_parseDate(WCLOSE : opp.closeDate)
       or opp.closeDate = NO_DATE;
      ind.err56 = *on;
      WMSG = 'Close date is required (MM/DD/YYYY).';
    endif;
    if WPROB > 100;
      ind.err55 = *on;
      WMSG = 'Probability must be 0 to 100.';
    endif;
    if WAMT < 0;
      ind.err54 = *on;
      WMSG = 'Amount cannot be negative.';
    endif;
    if WSTAGE < '1' or WSTAGE > '6';
      ind.err53 = *on;
      WMSG = 'Stage must be 1 to 6.';
    endif;
    if WOPP = '';
      ind.err52 = *on;
      WMSG = 'Opportunity name is required.';
    endif;
    if crm_custName(WCUST) = '';
      ind.err51 = *on;
      WMSG = 'Enter a valid customer number.';
    endif;
    if WMSG = '';
      leave;
    endif;
  enddo;

  opp.custId  = WCUST;
  opp.oppName = WOPP;
  opp.stage   = WSTAGE;
  opp.amount  = WAMT;
  opp.owner   = WOWNER;
  s = %int(opp.stage);
  if WPROB = 0 or opp.stage <> oldStage and WPROB = stageProbOf(oldStage);
    opp.prob = stageProb(s);
  else;
    opp.prob = WPROB;
  endif;

  if oid = 0;
    exec sql
      insert into OPPTY (CUSTID, OPPNAME, STAGE, AMOUNT, PROB, CLOSEDATE,
                         OWNER, CRTUSER, CHGUSER)
      values (:opp.custId, :opp.oppName, :opp.stage, :opp.amount,
              :opp.prob, :opp.closeDate, :opp.owner, :me, :me);
    evt = 'OPPADD';
  else;
    exec sql
      update OPPTY
         set OPPNAME = :opp.oppName, STAGE = :opp.stage,
             AMOUNT = :opp.amount, PROB = :opp.prob,
             CLOSEDATE = :opp.closeDate, OWNER = :opp.owner,
             CHGUSER = :me
       where OPPID = :oid;
    evt = 'OPPCHG';
  endif;

  if sqlcode < 0;
    FMSG = 'Save failed, SQLCODE ' + %char(sqlcode) + '.';
    return *off;
  endif;

  notify = '';
  if opp.owner <> me;
    notify = opp.owner;
  endif;
  evtText = %trim(crm_custName(opp.custId)) + ' - '
          + %trim(opp.oppName) + ': ' + %trim(stageName(s)) + ' '
          + money(opp.amount);
  if opp.stage = '5' and oldStage <> '5';
    evt = 'OPPWON';
    evtText = 'WON! ' + evtText;
  endif;
  crm_logEvent(evt : opp.custId : notify : evtText);
  return *on;
end-proc;

// -------------------------------------------------------------------
// advanceStage - option 3: move a deal to the next stage
// -------------------------------------------------------------------
dcl-proc advanceStage;
  dcl-pi *n;
    oppId int(10) const;
  end-pi;

  dcl-s oid      int(10);
  dcl-s s        int(10);
  dcl-s newStage char(1);
  dcl-s newProb  int(5);
  dcl-s notify   char(10);
  dcl-s evtText  varchar(80);

  oid = oppId;
  exec sql
    select CUSTID, OPPNAME, STAGE, AMOUNT, PROB, CLOSEDATE, OWNER
      into :opp
      from OPPTY where OPPID = :oid;
  if sqlcode <> 0;
    return;
  endif;
  if opp.stage >= '5';
    FMSG = 'Deal ' + %char(oid) + ' is already closed.';
    return;
  endif;

  s = %int(opp.stage) + 1;
  newStage = %char(s);
  newProb  = stageProb(s);
  exec sql
    update OPPTY set STAGE = :newStage, PROB = :newProb, CHGUSER = :me
     where OPPID = :oid;

  notify = '';
  if opp.owner <> me;
    notify = opp.owner;
  endif;
  evtText = %trim(crm_custName(opp.custId)) + ' - '
          + %trim(opp.oppName) + ' moved to ' + %trim(stageName(s));
  if newStage = '5';
    evtText = 'WON! ' + evtText;
    crm_logEvent('OPPWON' : opp.custId : notify : evtText);
  else;
    crm_logEvent('OPPSTAGE' : opp.custId : notify : evtText);
  endif;
  FMSG = 'Deal ' + %char(oid) + ' moved to ' + %trim(stageName(s)) + '.';
end-proc;

// -------------------------------------------------------------------
// deleteOpp
// -------------------------------------------------------------------
dcl-proc deleteOpp;
  dcl-pi *n;
    oppId int(10) const;
  end-pi;

  dcl-s oid int(10);

  oid = oppId;
  exec sql
    select CUSTID, OPPNAME, STAGE, AMOUNT, PROB, CLOSEDATE, OWNER
      into :opp
      from OPPTY where OPPID = :oid;
  if sqlcode <> 0;
    return;
  endif;

  WTEXT1 = 'Delete deal ' + %char(oid) + ': ' + opp.oppName;
  WTEXT2 = 'Customer: ' + crm_custName(opp.custId);
  exfmt CONFWDW;
  if wsAid <> KEY_F10;
    FMSG = 'Delete cancelled.';
    return;
  endif;

  exec sql delete from OPPTY where OPPID = :oid;
  crm_logEvent('OPPDLT' : opp.custId : ''
               : 'Deleted deal ' + %trim(opp.oppName));
  FMSG = 'Deal deleted.';
end-proc;

// -------------------------------------------------------------------
// stageProbOf - default probability for a stage code
// -------------------------------------------------------------------
dcl-proc stageProbOf;
  dcl-pi *n int(5);
    stage char(1) const;
  end-pi;

  if stage < '1' or stage > '6';
    return 0;
  endif;
  return stageProb(%int(stage));
end-proc;

// -------------------------------------------------------------------
// money - $1,234,567 (rounded to whole dollars)
// -------------------------------------------------------------------
dcl-proc money;
  dcl-pi *n varchar(20);
    amount packed(15 : 2) const;
  end-pi;

  dcl-s whole packed(13 : 0);

  eval(h) whole = amount;
  return '$' + %trim(%editc(whole : '1'));
end-proc;

