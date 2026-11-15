**FREE
// ===================================================================
// CRMACT - Activities and tasks (24 x 80)
//   custId > 0 : all activities for one customer
//   custId = 0 : "My open tasks" across all customers
//   Options: 2=Change 4=Delete 5=Display 6=Complete    F6=Add
//   F10 toggles open/all, F11 toggles mine/everyone (task mode)
//   Assigning a task to someone else alerts them on the dashboard.
// ===================================================================
ctl-opt dftactgrp(*no) actgrp('CRMDEMO') bnddir('CRMBND')
        option(*srcstmt : *nodebugio) datfmt(*iso) timfmt(*iso);

dcl-f CRMACTD workstn indds(ind) infds(wsds) sfile(ACTSFL : rrn);

/include CRMDEMO/QRPGLESRC,CRMSRVH

dcl-pi *n;
  custId int(10) const;
end-pi;

dcl-ds ind len(99) qualified;
  sflDsp    ind pos(30);
  sflDspCtl ind pos(31);
  sflClr    ind pos(32);
  sflEnd    ind pos(33);
  protect   ind pos(40);
  custProt  ind pos(41);
  optErr    ind pos(50);
  typeErr   ind pos(51);
  subjErr   ind pos(52);
  dueErr    ind pos(53);
  priErr    ind pos(54);
  asgErr    ind pos(55);
  doneErr   ind pos(56);
  custErr   ind pos(57);
  overdue   ind pos(61);
  dueToday  ind pos(62);
  isMine    ind pos(63);
end-ds;

dcl-ds wsds;
  wsAid char(1) pos(369);
end-ds;

// Notes are 180 characters in the table and 3 x 60 on the screen
dcl-ds notesDs;
  WNOTE1 char(60);
  WNOTE2 char(60);
  WNOTE3 char(60);
end-ds;

dcl-ds act qualified;
  custId   int(10);
  actType  char(5);
  subject  char(50);
  notes    char(180);
  dueDate  date;
  priority char(1);
  assignTo char(10);
  done     char(1);
  crtUser  char(10);
end-ds;

dcl-s rrn      packed(5 : 0);
dcl-s me       char(10);
dcl-s id       int(10);
dcl-s showAll  char(1) inz('N');
dcl-s everyone char(1) inz('N');
dcl-s hadError ind;

exec sql set option commit = *none, closqlcsr = *endmod,
                    datfmt = *iso, naming = *sys;

me = crmPsds.curUser;
crm_registerUser();
id = custId;

if id > 0;
  CTITLE = 'Activities';
  CINFO  = 'Customer: ' + %char(id) + ' ' + crm_custName(id);
else;
  CTITLE = 'Open Tasks';
endif;
loadSubfile();

dow *on;
  write FKEYS;
  exfmt ACTCTL;
  FMSG = '';

  select;
    when wsAid = KEY_F03 or wsAid = KEY_F12;
      leave;
    when wsAid = KEY_F05;
      loadSubfile();
    when wsAid = KEY_F06;
      if editActivity(0 : 'A');
        FMSG = 'Activity added.';
      endif;
      loadSubfile();
    when wsAid = KEY_F10;
      if showAll = 'Y';
        showAll = 'N';
      else;
        showAll = 'Y';
      endif;
      loadSubfile();
    when wsAid = KEY_F11;
      if id > 0;
        FMSG = 'F11 is used on the My open tasks list.';
      else;
        if everyone = 'Y';
          everyone = 'N';
        else;
          everyone = 'Y';
        endif;
        loadSubfile();
      endif;
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
    actId    int(10);
    actType  char(5);
    subject  char(50);
    actDate  date;
    dueDate  date;
    assignTo char(10);
    done     char(1);
    custName char(40);
  end-ds;
  dcl-s today date;

  today = %date();

  if id = 0;
    if everyone = 'Y';
      CINFO = 'Assigned to: everyone';
    else;
      CINFO = 'Assigned to: ' + %trim(me) + ' '
            + crm_codeDesc('USER' : me);
    endif;
  endif;
  if showAll = 'Y';
    CSHOW = 'All items, including completed  (F10 = open only)';
  else;
    CSHOW = 'Open items only  (F10 = include completed)';
  endif;

  ind.sflDsp = *off;
  ind.sflDspCtl = *off;
  ind.sflClr = *on;
  write ACTCTL;
  ind.sflClr = *off;
  rrn = 0;

  exec sql declare actCur cursor for
    select A.ACTID, A.ACTTYPE, A.SUBJECT, A.ACTDATE, A.DUEDATE,
           A.ASSIGNTO, A.DONE, coalesce(C.NAME, '')
      from ACTIVITY A
      left join CUSTOMER C on C.CUSTID = A.CUSTID
     where (:id = 0 or A.CUSTID = :id)
       and (:showAll = 'Y' or A.DONE = 'N')
       and (:id <> 0 or :everyone = 'Y' or A.ASSIGNTO = :me)
     order by A.DONE,
              case when A.DONE = 'N' and A.DUEDATE <> '0001-01-01'
                   then A.DUEDATE else date('9999-12-31') end,
              A.ACTDATE desc, A.ACTID desc
     for read only;

  exec sql open actCur;
  dow rrn < 9999;
    exec sql fetch next from actCur into :row;
    if sqlcode <> 0;
      leave;
    endif;
    rrn += 1;
    SOPT    = '';
    SACTID  = row.actId;
    STYPE   = row.actType;
    SSUBJ   = row.subject;
    SASSIGN = row.assignTo;
    SCUST   = row.custName;
    SDONE   = row.done;
    ind.overdue  = *off;
    ind.dueToday = *off;
    if row.done = 'N' and row.dueDate <> NO_DATE;
      SDATE = crm_fmtDate(row.dueDate);
      ind.overdue  = row.dueDate < today;
      ind.dueToday = row.dueDate = today;
    else;
      SDATE = crm_fmtDate(row.actDate);
    endif;
    ind.isMine = row.assignTo = me;
    ind.optErr = *off;
    write ACTSFL;
  enddo;
  exec sql close actCur;

  ind.sflDsp = rrn > 0;
  ind.sflDspCtl = *on;
  ind.sflEnd = *on;
  if rrn = 0;
    FMSG = 'Nothing to show. Press F6 to add an activity.';
  endif;
end-proc;

// -------------------------------------------------------------------
// processOptions
// -------------------------------------------------------------------
dcl-proc processOptions;
  hadError = *off;

  readc ACTSFL;
  dow not %eof(CRMACTD);
    ind.optErr = *off;

    select;
      when SOPT = ' ';
      when SOPT = '2';
        if editActivity(SACTID : 'C');
          FMSG = 'Activity changed.';
        endif;
      when SOPT = '4';
        deleteActivity(SACTID);
      when SOPT = '5';
        editActivity(SACTID : 'D');
      when SOPT = '6';
        completeActivity(SACTID);
      other;
        ind.optErr = *on;
        hadError = *on;
        FMSG = 'Option ' + SOPT + ' is not valid.';
    endsl;

    if not ind.optErr;
      SOPT = '';
    endif;
    update ACTSFL;
    readc ACTSFL;
  enddo;
end-proc;

// -------------------------------------------------------------------
// editActivity - add / change / display in a window
// -------------------------------------------------------------------
dcl-proc editActivity;
  dcl-pi *n ind;
    actId int(10) const;
    mode  char(1) const;
  end-pi;

  dcl-s aid       int(10);
  dcl-s oldAssign char(10);
  dcl-s code      char(10);
  dcl-s custNm    char(40);
  dcl-s evtText   varchar(80);

  aid = actId;
  clear act;
  WMSG = '';

  if mode = 'A';
    WTITLE = 'Add activity';
    act.custId   = id;
    act.dueDate  = NO_DATE;
    act.priority = 'M';
    act.assignTo = me;
    act.done     = 'N';
    if id = 0;
      act.actType = 'TASK';
    else;
      act.actType = 'CALL';
    endif;
    ind.custProt = id > 0;
  else;
    exec sql
      select CUSTID, ACTTYPE, SUBJECT, NOTES, DUEDATE, PRIORITY,
             ASSIGNTO, DONE, CRTUSER
        into :act
        from ACTIVITY where ACTID = :aid;
    if sqlcode <> 0;
      FMSG = 'Activity no longer exists.';
      return *off;
    endif;
    ind.custProt = *on;
    if mode = 'D';
      WTITLE = 'Activity detail (display only)';
    else;
      WTITLE = 'Change activity';
    endif;
  endif;
  oldAssign = act.assignTo;
  ind.protect = mode = 'D';
  if mode = 'D';
    ind.custProt = *on;
  endif;

  WCUST   = act.custId;
  WTYPE   = act.actType;
  WSUBJ   = act.subject;
  notesDs = act.notes;
  WDUE    = crm_fmtDate(act.dueDate);
  WPRI    = act.priority;
  WASSIGN = act.assignTo;
  WDONE   = act.done;

  dow *on;
    WCUSTNM = crm_custName(WCUST);
    WTYPED  = crm_codeDesc('ACTTYPE' : WTYPE);
    WASSNM  = crm_codeDesc('USER' : WASSIGN);

    exfmt ACTWDW;
    WMSG = '';
    ind.typeErr = *off;
    ind.subjErr = *off;
    ind.dueErr  = *off;
    ind.priErr  = *off;
    ind.asgErr  = *off;
    ind.doneErr = *off;
    ind.custErr = *off;

    if wsAid = KEY_F12 or wsAid = KEY_F03 or mode = 'D';
      ind.protect = *off;
      return *off;
    endif;

    if wsAid = KEY_F04;
      select;
        when CSRFLD = 'WTYPE';
          code = WTYPE;
          CRMPRMPT('ACTTYPE' : code);
          WTYPE = code;
        when CSRFLD = 'WASSIGN';
          code = WASSIGN;
          CRMPRMPT('USER' : code);
          WASSIGN = code;
        when CSRFLD = 'WPRI';
          code = WPRI;
          CRMPRMPT('PRIORITY' : code);
          WPRI = code;
        when CSRFLD = 'WCUST' and not ind.custProt;
          code = '';
          CRMPRMPT('CUST' : code);
          monitor;
            WCUST = %int(%trim(code));
          on-error;
          endmon;
        other;
          WMSG = 'F4 works on Customer, Type, Priority and Assign to.';
      endsl;
      iter;
    endif;

    // Validate (last error found wins the message line)
    if WDONE <> 'Y' and WDONE <> 'N';
      ind.doneErr = *on;
      WMSG = 'Done must be Y or N.';
    endif;
    if crm_codeDesc('USER' : WASSIGN) = '';
      ind.asgErr = *on;
      WMSG = 'Assign to must be a CRM user. Press F4 for a list.';
    endif;
    if crm_codeDesc('PRIORITY' : WPRI) = '';
      ind.priErr = *on;
      WMSG = 'Priority must be H, M or L.';
    endif;
    if not crm_parseDate(WDUE : act.dueDate);
      ind.dueErr = *on;
      WMSG = 'Due date is not valid. Use MM/DD/YYYY.';
    endif;
    if WSUBJ = '';
      ind.subjErr = *on;
      WMSG = 'Subject is required.';
    endif;
    if crm_codeDesc('ACTTYPE' : WTYPE) = '';
      ind.typeErr = *on;
      WMSG = 'Type is not valid. Press F4 for a list.';
    endif;
    if crm_custName(WCUST) = '';
      ind.custErr = *on;
      WMSG = 'Enter a valid customer number. Press F4 for a list.';
    endif;
    if WMSG = '';
      leave;
    endif;
  enddo;

  act.custId   = WCUST;
  act.actType  = WTYPE;
  act.subject  = WSUBJ;
  act.notes    = notesDs;
  act.priority = WPRI;
  act.assignTo = WASSIGN;
  act.done     = WDONE;
  custNm = crm_custName(act.custId);

  if mode = 'A';
    exec sql
      insert into ACTIVITY
             (CUSTID, ACTTYPE, SUBJECT, NOTES, ACTDATE, DUEDATE,
              PRIORITY, ASSIGNTO, DONE, DONEDATE, CRTUSER, CHGUSER)
      values (:act.custId, :act.actType, :act.subject, :act.notes,
              current date, :act.dueDate, :act.priority,
              :act.assignTo, :act.done,
              case when :act.done = 'Y' then current date
                   else date('0001-01-01') end,
              :me, :me);
  else;
    exec sql
      update ACTIVITY
         set ACTTYPE = :act.actType, SUBJECT = :act.subject,
             NOTES = :act.notes, DUEDATE = :act.dueDate,
             PRIORITY = :act.priority, ASSIGNTO = :act.assignTo,
             DONE = :act.done,
             DONEDATE = case when :act.done = 'N'
                               then date('0001-01-01')
                             when DONEDATE = '0001-01-01'
                               then current date
                             else DONEDATE end,
             CHGUSER = :me
       where ACTID = :aid;
  endif;

  if sqlcode < 0;
    FMSG = 'Save failed, SQLCODE ' + %char(sqlcode) + '.';
    return *off;
  endif;

  // Events: a newly assigned task pops up on the assignee's dashboard
  if act.assignTo <> me and (mode = 'A' or act.assignTo <> oldAssign);
    evtText = %trim(me) + ' assigned you: ' + %trim(act.subject)
         + ' (' + %trim(custNm) + ')';
    crm_logEvent('TASKASGN' : act.custId : act.assignTo : evtText);
  elseif mode = 'A';
    evtText = 'Logged ' + %trim(act.actType) + ': ' + %trim(act.subject)
         + ' (' + %trim(custNm) + ')';
    crm_logEvent('ACTADD' : act.custId : '' : evtText);
  else;
    evtText = 'Updated ' + %trim(act.actType) + ': ' + %trim(act.subject)
         + ' (' + %trim(custNm) + ')';
    crm_logEvent('ACTCHG' : act.custId : '' : evtText);
  endif;
  return *on;
end-proc;

// -------------------------------------------------------------------
// completeActivity - option 6
// -------------------------------------------------------------------
dcl-proc completeActivity;
  dcl-pi *n;
    actId int(10) const;
  end-pi;

  dcl-s aid     int(10);
  dcl-s cust    int(10);
  dcl-s subject char(50);
  dcl-s crtUser char(10);
  dcl-s notify  char(10);

  aid = actId;
  exec sql select CUSTID, SUBJECT, CRTUSER into :cust, :subject, :crtUser
             from ACTIVITY where ACTID = :aid and DONE = 'N';
  if sqlcode <> 0;
    FMSG = 'That item is already complete.';
    return;
  endif;

  exec sql update ACTIVITY
              set DONE = 'Y', DONEDATE = current date, CHGUSER = :me
            where ACTID = :aid;

  notify = '';
  if crtUser <> me;
    notify = crtUser;
  endif;
  crm_logEvent('TASKDONE' : cust : notify
               : %trim(me) + ' completed: ' + %trim(subject) + ' ('
               + %trim(crm_custName(cust)) + ')');
  FMSG = 'Marked complete: ' + subject;
end-proc;

// -------------------------------------------------------------------
// deleteActivity
// -------------------------------------------------------------------
dcl-proc deleteActivity;
  dcl-pi *n;
    actId int(10) const;
  end-pi;

  dcl-s aid     int(10);
  dcl-s cust    int(10);
  dcl-s subject char(50);

  aid = actId;
  exec sql select CUSTID, SUBJECT into :cust, :subject
             from ACTIVITY where ACTID = :aid;
  if sqlcode <> 0;
    return;
  endif;

  WTEXT1 = 'Delete: ' + subject;
  WTEXT2 = 'Customer: ' + crm_custName(cust);
  exfmt CONFWDW;
  if wsAid <> KEY_F10;
    FMSG = 'Delete cancelled.';
    return;
  endif;

  exec sql delete from ACTIVITY where ACTID = :aid;
  crm_logEvent('ACTDLT' : cust : '' : 'Deleted activity: '
               + %trim(subject));
  FMSG = 'Activity deleted.';
end-proc;
