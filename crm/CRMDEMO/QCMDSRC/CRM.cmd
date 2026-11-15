/* CRM - Start the CRM demo.  CPP: CRMDEMO/CRMC                    */
             CMD        PROMPT('CRM Demo')
             PARM       KWD(START) TYPE(*CHAR) LEN(6) RSTD(*YES) +
                          DFT(*MENU) VALUES(*MENU *DASH *PIPE +
                          *CUST *TASKS *PRINT) PROMPT('Start with')
