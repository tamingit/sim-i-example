**FREE
// ===================================================================
// CRMEMAIL - Send an email from a popup window (24 x 80)
//   Sends with SNDSMTPEMM (HTML body) and logs an EMAIL activity
//   for the customer, plus an event for the live dashboard.
//   Requires SMTP to be configured on the system (see README).
// ===================================================================
ctl-opt dftactgrp(*no) actgrp('CRMDEMO') bnddir('CRMBND')
        option(*srcstmt : *nodebugio) datfmt(*iso) timfmt(*iso);

dcl-f CRMEMAILD workstn indds(ind) infds(wsds);

/include CRMDEMO/QRPGLESRC,CRMSRVH

dcl-pi *n;
  toAddr char(60) const;
  toName char(40) const;
  custId int(10)  const;
  contId int(10)  const;
  rtnMsg char(78);
end-pi;

dcl-ds ind len(99) qualified;
  toErr   ind pos(51);
  subjErr ind pos(52);
end-ds;

dcl-ds wsds;
  wsAid char(1) pos(369);
end-ds;

dcl-ds bodyDs;
  EBODY1 char(70);
  EBODY2 char(70);
  EBODY3 char(70);
  EBODY4 char(70);
  EBODY5 char(70);
  EBODY6 char(70);
  bodyLine char(70) dim(6) pos(1);
end-ds;

dcl-s me     char(10);
dcl-s msgId  char(7);
dcl-s first  varchar(40);
dcl-s p      int(10);

exec sql set option commit = *none, closqlcsr = *endmod,
                    datfmt = *iso, naming = *sys;

me = crmPsds.curUser;
rtnMsg = '';

ETO   = toAddr;
ENAME = toName;
ESUBJ = '';
clear bodyDs;

if toName <> '';
  first = %trim(toName);
  p = %scan(' ' : first);
  if p > 1;
    first = %subst(first : 1 : p - 1);
  endif;
  EBODY1 = 'Hello ' + first + ',';
  EBODY5 = 'Best regards,';
  EBODY6 = crm_codeDesc('USER' : me);
endif;
if custId > 0;
  ESUBJ = 'Following up - ' + %trim(crm_custName(custId));
endif;

dow *on;
  exfmt EMLWDW;
  EMSG = '';
  ind.toErr = *off;
  ind.subjErr = *off;

  if wsAid = KEY_F12;
    rtnMsg = 'Email cancelled.';
    leave;
  endif;

  if wsAid <> KEY_F10;
    EMSG = 'Press F10 to send the email.';
    iter;
  endif;

  if ESUBJ = '';
    ind.subjErr = *on;
    EMSG = 'Subject is required.';
  endif;
  if %scan('@' : ETO) < 2 or %scan('.' : ETO) = 0
     or %scan(' ' : %trim(ETO)) > 0;
    ind.toErr = *on;
    EMSG = 'Enter a valid email address.';
  endif;
  if EMSG <> '';
    iter;
  endif;

  msgId = sendMail();
  if msgId <> '';
    EMSG = 'Send failed (' + msgId + '). Is SMTP set up? See README.';
    iter;
  endif;

  logIt();
  rtnMsg = 'Email sent to ' + %trim(ETO) + '.';
  leave;
enddo;

*inlr = *on;
return;

// -------------------------------------------------------------------
// sendMail - build and run SNDSMTPEMM, return blank or message id
// -------------------------------------------------------------------
dcl-proc sendMail;
  dcl-pi *n char(7);
  end-pi;

  dcl-s body varchar(1000);
  dcl-s cmd  varchar(3000);
  dcl-s i    int(10);

  body = '';
  for i = 1 to %elem(bodyLine);
    body += htmlEscape(%trimr(bodyLine(i))) + '<br>';
  endfor;

  cmd = 'SNDSMTPEMM RCP((''' + %trim(ETO) + ''' *PRI))'
      + ' SUBJECT(''' + crm_quote(%trim(ESUBJ)) + ''')'
      + ' NOTE(''' + crm_quote(body) + ''')'
      + ' CONTENT(*HTML)';

  return crm_runCmd(cmd);
end-proc;

// -------------------------------------------------------------------
// htmlEscape - make user text safe inside the HTML body
// -------------------------------------------------------------------
dcl-proc htmlEscape;
  dcl-pi *n varchar(400);
    inText varchar(100) const;
  end-pi;

  dcl-s out varchar(400);

  out = %scanrpl('&' : '&amp;' : inText);
  out = %scanrpl('<' : '&lt;' : out);
  out = %scanrpl('>' : '&gt;' : out);
  return out;
end-proc;

// -------------------------------------------------------------------
// logIt - record the email as an activity and a dashboard event
// -------------------------------------------------------------------
dcl-proc logIt;
  dcl-s cust    int(10);
  dcl-s cont    int(10);
  dcl-s subject char(50);
  dcl-s notes   char(180);
  dcl-s who     varchar(60);

  cust = custId;
  cont = contId;
  subject = ESUBJ;
  notes = 'To ' + %trim(ETO) + ': ' + %trim(EBODY1) + ' '
        + %trim(EBODY2) + ' ' + %trim(EBODY3) + ' ' + %trim(EBODY4);

  if cust > 0;
    exec sql
      insert into ACTIVITY
             (CUSTID, CONTID, ACTTYPE, SUBJECT, NOTES, ACTDATE,
              ASSIGNTO, DONE, DONEDATE, CRTUSER, CHGUSER)
      values (:cust, :cont, 'EMAIL', :subject, :notes, current date,
              :me, 'Y', current date, :me, :me);
  endif;

  who = %trim(ENAME);
  if who = '';
    who = %trim(ETO);
  endif;
  crm_logEvent('EMAIL' : cust : ''
               : 'Emailed ' + who + ': ' + %trim(ESUBJ));
end-proc;
