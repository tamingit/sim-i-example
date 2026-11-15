**FREE
// ===================================================================
// CRMPRMPT - F4 prompt window for code values (24 x 80)
//   codeType: any CRMCODE type, 'USER' (CRM users) or 'CUST'
//   code:     in = current value, out = selected value
// ===================================================================
ctl-opt dftactgrp(*no) actgrp('CRMDEMO') bnddir('CRMBND')
        option(*srcstmt : *nodebugio) datfmt(*iso) timfmt(*iso);

dcl-f CRMPRMPTD workstn indds(ind) infds(wsds) sfile(PRMSFL : rrn);

/include CRMDEMO/QRPGLESRC,CRMSRVH

dcl-pi *n;
  codeType char(10) const;
  code     char(10);
end-pi;

dcl-ds ind len(99) qualified;
  sflDsp    ind pos(30);
  sflDspCtl ind pos(31);
  sflClr    ind pos(32);
  sflEnd    ind pos(33);
end-ds;

dcl-ds wsds;
  wsAid char(1) pos(369);
end-ds;

dcl-ds row qualified;
  code  char(10);
  descr char(30);
  seq   int(10);
end-ds;

dcl-s rrn   packed(5 : 0);
dcl-s pType char(10);

exec sql set option commit = *none, closqlcsr = *endmod,
                    datfmt = *iso, naming = *sys;

pType = codeType;

select;
  when pType = 'STATUS';
    PTITLE = 'Select a customer status';
  when pType = 'INDUSTRY';
    PTITLE = 'Select an industry';
  when pType = 'USER';
    PTITLE = 'Select a CRM user';
  when pType = 'ACTTYPE';
    PTITLE = 'Select an activity type';
  when pType = 'PRIORITY';
    PTITLE = 'Select a priority';
  when pType = 'STAGE';
    PTITLE = 'Select a pipeline stage';
  when pType = 'CUST';
    PTITLE = 'Select a customer';
  other;
    PTITLE = 'Select a value';
endsl;

ind.sflClr = *on;
write PRMCTL;
ind.sflClr = *off;
rrn = 0;

exec sql declare prmCur cursor for
  select CODE, DESCR, SEQ from (
      select CODE, DESCR, integer(SEQ) as SEQ
        from CRMCODE where CODETYPE = :pType
      union all
      select USERID, FULLNAME, 0
        from CRMUSER where :pType = 'USER'
      union all
      select cast(trim(char(CUSTID)) as char(10)),
             substr(NAME, 1, 30), 0
        from CUSTOMER where :pType = 'CUST'
    ) as X (CODE, DESCR, SEQ)
   order by SEQ, CODE
   for read only;

exec sql open prmCur;
dow rrn < 9999;
  exec sql fetch next from prmCur into :row;
  if sqlcode <> 0;
    leave;
  endif;
  rrn += 1;
  SOPT  = '';
  SCODE = row.code;
  SDESC = row.descr;
  write PRMSFL;
enddo;
exec sql close prmCur;

ind.sflDsp = rrn > 0;
ind.sflDspCtl = *on;
ind.sflEnd = *on;

exfmt PRMCTL;

if wsAid <> KEY_F12 and rrn > 0;
  readc PRMSFL;
  dow not %eof(CRMPRMPTD);
    if SOPT = '1';
      code = SCODE;
      leave;
    endif;
    readc PRMSFL;
  enddo;
endif;

*inlr = *on;
return;
