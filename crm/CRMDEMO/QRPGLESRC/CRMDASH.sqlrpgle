**FREE
// ===================================================================
// CRMDASH - Live dashboard (27 x 132)
//
// How the auto-refresh works:
//   CRMDASHD is created with WAITRCD(2) and record DASH has INVITE.
//   The program WRITEs DASH, then READs the *file*. If nobody presses
//   a key within 2 seconds the READ ends with status 1331 (timeout).
//   On each timeout the program checks MAX(EVTID) in CRMEVENT; if any
//   session changed something, the whole dashboard is reloaded.
//   Events addressed to this user (FORUSER) sound the alarm and show
//   a yellow alert line.
//
//   Bars, task lines and feed lines contain 5250 attribute bytes
//   (x'20'-x'3F') to color parts of a single output field.
// ===================================================================
ctl-opt dftactgrp(*no) actgrp('CRMDEMO') bnddir('CRMBND')
        option(*srcstmt : *nodebugio) datfmt(*iso) timfmt(*iso);

dcl-f CRMDASHD workstn indds(ind) infds(wsds) maxdev(*file) usropn;

/include CRMDEMO/QRPGLESRC,CRMSRVH

dcl-ds ind len(99) qualified;
  overdue  ind pos(61);
  dueToday ind pos(62);
  alertOn  ind pos(70);
  alarm    ind pos(71);
  putOvr   ind pos(80);
end-ds;

dcl-ds wsds;
  wsAid char(1) pos(369);
end-ds;

// Screen lines mapped onto arrays (same names as the display fields)
dcl-ds barLines;
  BAR1 char(128);
  BAR2 char(128);
  BAR3 char(128);
  BAR4 char(128);
  BAR5 char(128);
  BAR6 char(128);
  barLine char(128) dim(6) pos(1);
end-ds;

dcl-ds taskLines;
  TSK1 char(64);
  TSK2 char(64);
  TSK3 char(64);
  TSK4 char(64);
  TSK5 char(64);
  TSK6 char(64);
  TSK7 char(64);
  TSK8 char(64);
  TSK9 char(64);
  tskLine char(64) dim(9) pos(1);
end-ds;

dcl-ds feedLines;
  FEED1 char(63);
  FEED2 char(63);
  FEED3 char(63);
  FEED4 char(63);
  FEED5 char(63);
  FEED6 char(63);
  FEED7 char(63);
  FEED8 char(63);
  FEED9 char(63);
  feedLine char(63) dim(9) pos(1);
end-ds;

// 5250 attribute bytes
dcl-c ATR_GREEN   x'20';
dcl-c ATR_WHITE   x'22';
dcl-c ATR_RED     x'28';
dcl-c ATR_YELLOW  x'32';
dcl-c ATR_PINK    x'38';
dcl-c ATR_GRN_RI  x'21';
dcl-c ATR_RED_RI  x'29';
dcl-c ATR_TRQ_RI  x'35';

dcl-c TIMEOUT     1331;
dcl-c BAR_MAX     60;

dcl-s me         char(10);
dcl-s lastEvt    int(20);
dcl-s newEvt     int(20);
dcl-s ticks      int(10);
dcl-s alertTicks int(10);

exec sql set option commit = *none, closqlcsr = *endmod,
                    datfmt = *iso, naming = *sys;

// The dashboard needs a 27 x 132 capable session
monitor;
  open CRMDASHD;
on-error;
  dsply 'CRMDASH needs a 27x132 session (e.g. 3477-FC).';
  *inlr = *on;
  return;
endmon;

me = crmPsds.curUser;
crm_registerUser();
DUSER   = me;
DUSERNM = crm_codeDesc('USER' : me);

lastEvt = maxEvent();
loadAll();
ind.putOvr = *off;

dow *on;
  DTIME = %char(%time() : *hms);
  DDATE = %char(%date() : *usa);
  DSTAT = 'Auto-refresh every 2 seconds.  Last event #'
        + %char(lastEvt);

  write DASH;
  ind.putOvr = *on;
  ind.alarm  = *off;

  read(e) CRMDASHD;

  if %error;
    if %status(CRMDASHD) <> TIMEOUT;
      leave;
    endif;

    // Timeout: nobody pressed a key. Anything new?
    ticks += 1;
    newEvt = maxEvent();
    if newEvt <> lastEvt;
      checkAlert(lastEvt);
      lastEvt = newEvt;
      loadAll();
      ticks = 0;
    elseif ticks >= 15;
      loadAll();
      ticks = 0;
    endif;

    if ind.alertOn;
      alertTicks += 1;
      if alertTicks > 15;
        clearAlert();
      endif;
    endif;
    iter;
  endif;

  // A key was pressed
  clearAlert();
  select;
    when wsAid = KEY_F03;
      leave;
    when wsAid = KEY_F07;
      CRMACT(0);
      ind.putOvr = *off;
    when wsAid = KEY_F08;
      CRMPIPE(0);
      ind.putOvr = *off;
    when wsAid = KEY_F09;
      CRMCUSTL();
      ind.putOvr = *off;
  endsl;
  lastEvt = maxEvent();
  loadAll();
enddo;

*inlr = *on;
return;

// -------------------------------------------------------------------
// maxEvent - newest event id
// -------------------------------------------------------------------
dcl-proc maxEvent;
  dcl-pi *n int(20);
  end-pi;

  dcl-s n int(20);

  exec sql select coalesce(max(EVTID), 0) into :n from CRMEVENT;
  return n;
end-proc;

// -------------------------------------------------------------------
// checkAlert - new events addressed to me from someone else?
// -------------------------------------------------------------------
dcl-proc checkAlert;
  dcl-pi *n;
    sinceEvt int(20) const;
  end-pi;

  dcl-s since int(20);
  dcl-s who   char(10);
  dcl-s evText char(80);

  since = sinceEvt;
  exec sql
    select EVTUSER, EVTTEXT into :who, :evText
      from CRMEVENT
     where EVTID > :since and FORUSER = :me and EVTUSER <> :me
     order by EVTID desc
     fetch first 1 row only;

  if sqlcode = 0;
    DALERT = ' >>> For you from ' + %trim(who) + ': ' + %trim(evText)
           + '  <<<';
    ind.alertOn = *on;
    ind.alarm   = *on;
    alertTicks  = 0;
  endif;
end-proc;

// -------------------------------------------------------------------
// clearAlert
// -------------------------------------------------------------------
dcl-proc clearAlert;
  DALERT = '';
  ind.alertOn = *off;
  alertTicks = 0;
end-proc;

// -------------------------------------------------------------------
// loadAll - KPIs, stage bars, my tasks and the activity feed
// -------------------------------------------------------------------
dcl-proc loadAll;
  loadKpis();
  loadBars();
  loadTasks();
  loadFeed();
end-proc;

// -------------------------------------------------------------------
// loadKpis
// -------------------------------------------------------------------
dcl-proc loadKpis;
  dcl-s nAct   int(10);
  dcl-s nPros  int(10);
  dcl-s nInact int(10);
  dcl-s nDeals int(10);
  dcl-s value  packed(15 : 2);
  dcl-s wgt    packed(15 : 2);
  dcl-s won    packed(15 : 2);
  dcl-s lost   packed(15 : 2);
  dcl-s nOpen  int(10);
  dcl-s nOver  int(10);
  dcl-s nToday int(10);

  exec sql
    select coalesce(sum(case when STATUS = 'A' then 1 else 0 end), 0),
           coalesce(sum(case when STATUS = 'P' then 1 else 0 end), 0),
           coalesce(sum(case when STATUS = 'I' then 1 else 0 end), 0)
      into :nAct, :nPros, :nInact
      from CUSTOMER;

  exec sql
    select count(*), coalesce(sum(AMOUNT), 0),
           coalesce(sum(AMOUNT * PROB / 100), 0)
      into :nDeals, :value, :wgt
      from OPPTY
     where STAGE < '5';

  exec sql
    select coalesce(sum(case when STAGE = '5' then AMOUNT else 0 end), 0),
           coalesce(sum(case when STAGE = '6' then AMOUNT else 0 end), 0)
      into :won, :lost
      from OPPTY
     where STAGE in ('5', '6')
       and CLOSEDATE >= current date - 30 days;

  exec sql
    select count(*),
           coalesce(sum(case when DUEDATE <> '0001-01-01'
                              and DUEDATE < current date
                             then 1 else 0 end), 0),
           coalesce(sum(case when DUEDATE = current date
                             then 1 else 0 end), 0)
      into :nOpen, :nOver, :nToday
      from ACTIVITY
     where ASSIGNTO = :me and DONE = 'N';

  KACT   = nAct;
  KPROS  = nPros;
  KINACT = nInact;
  KDEALS = nDeals;
  eval(h) KVALUE = value;
  eval(h) KWGT   = wgt;
  eval(h) KWON   = won;
  eval(h) KLOST  = lost;
  KAVG = 0;
  if nDeals > 0;
    eval(h) KAVG = value / nDeals;
  endif;
  KTASKS = nOpen;
  KOVER  = nOver;
  KTODAY = nToday;
  ind.overdue  = nOver > 0;
  ind.dueToday = nToday > 0;
end-proc;

// -------------------------------------------------------------------
// loadBars - one colored bar per stage
// -------------------------------------------------------------------
dcl-proc loadBars;
  dcl-ds stg qualified;
    stage  char(1);
    cnt    int(10);
    amount packed(15 : 2);
  end-ds;

  dcl-s cnt    int(10) dim(6);
  dcl-s amt    packed(15 : 2) dim(6);
  dcl-s maxAmt packed(15 : 2);
  dcl-s names  char(12) dim(6);
  dcl-s s      int(10);
  dcl-s len    int(10);
  dcl-s color  char(1);
  dcl-s bar    varchar(128);

  names(1) = 'Lead';
  names(2) = 'Qualified';
  names(3) = 'Proposal';
  names(4) = 'Negotiation';
  names(5) = 'Won (30d)';
  names(6) = 'Lost (30d)';

  exec sql declare barCur cursor for
    select STAGE, count(*), coalesce(sum(AMOUNT), 0)
      from OPPTY
     where STAGE < '5' or CLOSEDATE >= current date - 30 days
     group by STAGE
     for read only;

  exec sql open barCur;
  dow *on;
    exec sql fetch next from barCur into :stg;
    if sqlcode <> 0;
      leave;
    endif;
    s = %int(stg.stage);
    if s >= 1 and s <= 6;
      cnt(s) = stg.cnt;
      amt(s) = stg.amount;
      if stg.amount > maxAmt;
        maxAmt = stg.amount;
      endif;
    endif;
  enddo;
  exec sql close barCur;

  for s = 1 to 6;
    len = 0;
    if maxAmt > 0;
      eval(h) len = amt(s) * BAR_MAX / maxAmt;
    endif;
    if len = 0 and amt(s) > 0;
      len = 1;
    endif;

    bar = '';
    if len > 0;
      bar = %subst(blanks() : 1 : len);
    endif;

    select;
      when s = 5;
        color = ATR_GRN_RI;
      when s = 6;
        color = ATR_RED_RI;
      other;
        color = ATR_TRQ_RI;
    endsl;

    barLine(s) = %char(s) + ' ' + names(s)
               + rjust(%char(cnt(s)) : 4) + ' deals '
               + color + bar + ATR_GREEN + ' ' + money(amt(s));
  endfor;
end-proc;

// -------------------------------------------------------------------
// loadTasks - my next 9 open tasks
// -------------------------------------------------------------------
dcl-proc loadTasks;
  dcl-ds row qualified;
    dueDate  date;
    actType  char(5);
    subject  char(50);
    priority char(1);
    custName char(40);
  end-ds;

  dcl-s i     int(10);
  dcl-s today date;
  dcl-s color char(1);
  dcl-s due   char(5);

  today = %date();
  clear taskLines;
  i = 0;

  exec sql declare tskCur cursor for
    select A.DUEDATE, A.ACTTYPE, A.SUBJECT, A.PRIORITY,
           coalesce(C.NAME, '')
      from ACTIVITY A
      left join CUSTOMER C on C.CUSTID = A.CUSTID
     where A.ASSIGNTO = :me and A.DONE = 'N'
     order by case when A.DUEDATE = '0001-01-01'
                   then date('9999-12-31') else A.DUEDATE end,
              A.PRIORITY, A.ACTID
     fetch first 9 rows only
     for read only;

  exec sql open tskCur;
  dow i < 9;
    exec sql fetch next from tskCur into :row;
    if sqlcode <> 0;
      leave;
    endif;
    i += 1;

    color = ATR_GREEN;
    due = '  -  ';
    if row.dueDate <> NO_DATE;
      due = %subst(%char(row.dueDate : *usa) : 1 : 5);
      if row.dueDate < today;
        color = ATR_RED;
      elseif row.dueDate = today;
        color = ATR_YELLOW;
      endif;
    endif;

    tskLine(i) = color + due + ' ' + row.priority + ' '
               + %subst(row.subject : 1 : 32) + ' '
               + %trim(row.custName);
  enddo;
  exec sql close tskCur;

  if i = 0;
    TSK1 = ATR_GREEN + 'No open tasks - nice work!';
  endif;
end-proc;

// -------------------------------------------------------------------
// loadFeed - newest 9 events from all users
// -------------------------------------------------------------------
dcl-proc loadFeed;
  dcl-ds row qualified;
    evtTs   timestamp;
    evtUser char(10);
    evtText char(80);
    forUser char(10);
  end-ds;

  dcl-s i      int(10);
  dcl-s recent timestamp;
  dcl-s color  char(1);

  recent = %timestamp() - %minutes(2);
  clear feedLines;
  i = 0;

  exec sql declare feedCur cursor for
    select EVTTS, EVTUSER, EVTTEXT, FORUSER
      from CRMEVENT
     order by EVTID desc
     fetch first 9 rows only
     for read only;

  exec sql open feedCur;
  dow i < 9;
    exec sql fetch next from feedCur into :row;
    if sqlcode <> 0;
      leave;
    endif;
    i += 1;

    if row.forUser = me;
      color = ATR_PINK;
    elseif row.evtTs > recent;
      color = ATR_WHITE;
    else;
      color = ATR_GREEN;
    endif;

    feedLine(i) = color + %char(%time(row.evtTs) : *hms) + ' '
                + row.evtUser + ' ' + %trim(row.evtText);
  enddo;
  exec sql close feedCur;
end-proc;

// -------------------------------------------------------------------
// Helpers
// -------------------------------------------------------------------
dcl-proc rjust;
  dcl-pi *n varchar(20);
    inText varchar(20) const;
    width int(10) const;
  end-pi;

  if %len(inText) >= width;
    return inText;
  endif;
  return %subst(blanks() : 1 : width - %len(inText)) + inText;
end-proc;

dcl-proc blanks;
  dcl-pi *n char(128);
  end-pi;

  return *blanks;
end-proc;

dcl-proc money;
  dcl-pi *n varchar(20);
    amount packed(15 : 2) const;
  end-pi;

  dcl-s whole packed(13 : 0);

  eval(h) whole = amount;
  return '$' + %trim(%editc(whole : '1'));
end-proc;
