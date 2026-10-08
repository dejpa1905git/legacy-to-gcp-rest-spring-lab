**free
ctl-opt dftactgrp(*no) actgrp(*caller);

dcl-pi *n;
  inInvId    char(10) const;
  outCustNo  packed(6:0);
  outInvAmt  packed(11:2);
  outStatus  char(1);
  outDueDate packed(8:0);
  outFound   char(1);
end-pi;

exec sql
  set option commit = *none,
             closqlcsr = *endmod;

clear outCustNo;
clear outInvAmt;
clear outStatus;
clear outDueDate;
outFound = 'N';

exec sql
  select CUST_NO,
         INV_AMT,
         STATUS,
         DUE_DATE
    into :outCustNo,
         :outInvAmt,
         :outStatus,
         :outDueDate
    from INVMAST01
   where INV_ID = :inInvId;

select;
  when SQLCODE = 0;
    outFound = 'Y';

  when SQLCODE = 100;
    outFound = 'N';

  other;
    outFound = 'E';
endsl;
Dsply ('outStatus: ' + %Char(outStatus) );
*inlr = *on;
return;
