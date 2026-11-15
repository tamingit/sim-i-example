# CRM Demo for IBM i (RPG free-form + SQL + 5250)

A small, working CRM built for demonstrating a web-based 5250 terminal.
Several screens are meant to run **at the same time in different
sessions**, and the sessions affect each other:

- A **live dashboard** (27 x 132) that redraws itself every 2 seconds
  when anyone changes data, and beeps when a task is assigned to you.
- **Conflict detection**: open the same customer in two sessions, save
  in both, and the second one gets a red popup window.
- **Popup windows** for F4 prompts, edits, confirmations, email and
  printing.
- A **27 x 132 pipeline board** with stage summaries.
- **Email** through `SNDSMTPEMM` and **printed reports** in spooled files.

Target: IBM i 7.5, library `CRMDEMO`, traditional source physical files.

## Source members

Each folder here is a source physical file. File name = member name,
extension = member type.

| Source file | Member | Type | What it is |
|---|---|---|---|
| QSQLSRC | CRMTABLES | SQL | Creates the 7 tables and indexes |
| QSQLSRC | CRMSEED | SQL | Sample data: 3 users, 50 customers, ~115 contacts, ~250 activities, ~70 deals |
| QSQLSRC | CRMDROP | SQL | Drops the tables (used by a rebuild) |
| QDDSSRC | CRMMENUD | DSPF | Main menu (24x80) |
| QDDSSRC | CRMCUSTLD | DSPF | Customer list (24x80) |
| QDDSSRC | CRMCUSTMD | DSPF | Customer detail + conflict window (24x80) |
| QDDSSRC | CRMCONTD | DSPF | Contacts + edit window (24x80) |
| QDDSSRC | CRMACTD | DSPF | Activities / tasks + edit window (24x80) |
| QDDSSRC | CRMPRMPTD | DSPF | F4 prompt window (24x80) |
| QDDSSRC | CRMEMAILD | DSPF | Send email window (24x80) |
| QDDSSRC | CRMPRTD | DSPF | Print options window (24x80) |
| QDDSSRC | CRMPIPED | DSPF | **Pipeline board (27x132)** |
| QDDSSRC | CRMDASHD | DSPF | **Live dashboard (27x132)** |
| QDDSSRC | CRMRPTP | PRTF | Reports, 132 columns |
| QRPGLESRC | CRMSRVH | RPGLEINC | Shared prototypes and constants (copybook) |
| QRPGLESRC | CRMSRV | SQLRPGLE | Service program procedures |
| QRPGLESRC | CRMMENU | SQLRPGLE | Main menu |
| QRPGLESRC | CRMCUSTL | SQLRPGLE | Customer list |
| QRPGLESRC | CRMCUSTM | SQLRPGLE | Customer add/change/display with optimistic locking |
| QRPGLESRC | CRMCONT | SQLRPGLE | Contacts |
| QRPGLESRC | CRMACT | SQLRPGLE | Activities and "my open tasks" |
| QRPGLESRC | CRMPIPE | SQLRPGLE | Pipeline board |
| QRPGLESRC | CRMDASH | SQLRPGLE | Live dashboard |
| QRPGLESRC | CRMPRMPT | SQLRPGLE | F4 prompt |
| QRPGLESRC | CRMEMAIL | SQLRPGLE | Send email |
| QRPGLESRC | CRMPRT | SQLRPGLE | Print reports |
| QCLLESRC | CRMC | CLLE | Command processing program for `CRM` |
| QCLLESRC | CRMBUILD | CLLE | Builds everything |
| QCMDSRC | CRM | CMD | `CRM` command |

## Setup

### 1. Library and source files

The RPG and SQL sources use lines up to 100 characters, so create those
two source files with `RCDLEN(112)`:

```
CRTLIB     LIB(CRMDEMO) TEXT('CRM demo')
CRTSRCPF   FILE(CRMDEMO/QSQLSRC)   RCDLEN(112)
CRTSRCPF   FILE(CRMDEMO/QRPGLESRC) RCDLEN(112)
CRTSRCPF   FILE(CRMDEMO/QDDSSRC)   RCDLEN(92)
CRTSRCPF   FILE(CRMDEMO/QCLLESRC)  RCDLEN(92)
CRTSRCPF   FILE(CRMDEMO/QCMDSRC)   RCDLEN(92)
```

### 2. Upload the members

Upload each file to the matching member, for example
`QRPGLESRC/CRMMENU.sqlrpgle` to `CRMDEMO/QRPGLESRC(CRMMENU)`, type
`SQLRPGLE`. All files are plain ASCII.

If you copy the folder to the IFS first, `CPYFRMSTMF` works too:

```
CPYFRMSTMF FROMSTMF('/home/me/crm/QRPGLESRC/CRMMENU.sqlrpgle')
           TOMBR('/QSYS.LIB/CRMDEMO.LIB/QRPGLESRC.FILE/CRMMENU.MBR')
           MBROPT(*REPLACE)
```

The build calls every compiler with an explicit member name, so blank
member types still build. Setting the types (`CHGPFM ... SRCTYPE(...)`)
only matters for editors and PDM.

### 3. Build

```
CRTBNDCL PGM(CRMDEMO/CRMBUILD) SRCFILE(CRMDEMO/QCLLESRC)
CALL CRMDEMO/CRMBUILD PARM('*YES')
```

`*YES` drops and re-creates the tables and reloads the sample data, then
compiles everything. Use `PARM('*NO')` to recompile and keep the data.
If something fails, the final message lists the objects that failed.
Check the compile listings in your spooled files.

Build order: tables, then sample data, then display and printer files,
then the CRMSRV module, service program and binding directory CRMBND,
then the programs, then CRMC and the CRM command.

### 4. Demo users

The sample data assigns customers, deals and tasks round-robin to three
CRM users: `CRMUSR1` (Jordan Lee), `CRMUSR2` (Sam Patel) and `CRMUSR3`
(Casey Morgan). For the multi-user demo, create user profiles with these
names using your normal process. Any other profile also works: it is
added to `CRMUSER` the first time it runs a CRM screen. It starts with
no tasks or customers, but you can assign some to it.

The users need to be able to update the tables, for example:

```
GRTOBJAUT OBJ(CRMDEMO/*ALL) OBJTYPE(*ALL) USER(*PUBLIC) AUT(*CHANGE)
```

### 5. Terminal sessions

- The **dashboard** and **pipeline** need a session that supports
  **27 x 132** (device type 3477-FC or 3180-2 in most emulators). On a
  24 x 80 session they show a message and return.
- Every other screen is 24 x 80, so it fits in a small window.
- All display files use `RSTDSP(*YES)`. Moving between the 132-column
  screens and the 80-column ones switches the screen size and then
  restores it.

### 6. Email (optional)

`CRMEMAIL` sends with `SNDSMTPEMM ... CONTENT(*HTML)`. The system needs
SMTP set up to relay mail, and the sending user needs an SMTP address in
the system distribution directory (`WRKDIRE`). If the send fails, the
window shows the message ID (for example `CPF....`) and stays open. All
sample contact addresses end in `.example`, so they are never delivered.
Type your own address in the To field when you demo it.

## Starting it

```
CRMDEMO/CRM            main menu
CRMDEMO/CRM *DASH      live dashboard  (27x132)
CRMDEMO/CRM *PIPE      pipeline board  (27x132)
CRMDEMO/CRM *CUST      customer list
CRMDEMO/CRM *TASKS     my open tasks
CRMDEMO/CRM *PRINT     print a report
```

## Demo script (four windows)

| Window | Sign on as | Size | Run |
|---|---|---|---|
| A | CRMUSR1 | 27x132 | `CRMDEMO/CRM *DASH` |
| B | CRMUSR2 | 24x80 | `CRMDEMO/CRM *CUST` |
| C | CRMUSR3 | 24x80 | `CRMDEMO/CRM *CUST` |
| D | CRMUSR2 | 27x132 | `CRMDEMO/CRM *PIPE` |

1. **Live updates.** In **B**, type `2` next to *Acme Widget Works*,
   change the phone number and press Enter. Within about 2 seconds the
   activity feed in **A** shows the change at the top in white.
2. **Edit conflict.** In **B** and **C**, both type `2` on the same
   customer. Save in **C** first, then press Enter in **B**. **B** gets
   the red *Changed by another user* window: F5 loads C's version, F10
   overwrites it, F12 goes back to editing.
3. **Task assignment and alert.** In **B**, type `7` on a customer, press
   F6, enter a task, put the cursor on *Assign to*, press F4 and pick
   `CRMUSR1`. **A** beeps, shows a yellow alert line, and the task shows
   up under *My open tasks*.
4. **Pipeline.** In **D**, type `3` (advance stage) on a Negotiation deal.
   It becomes *Won*, the bars and the *Won (30 days)* figure in **A**
   update, and the feed shows `WON!`.
5. **Popups.** Any F4 prompt, the add/change windows, delete
   confirmations (F10 confirms), and the email window open over the
   current screen.
6. **Printing.** In **B** press F21 (customer directory) or in **D** press
   F21 (pipeline report), then `WRKSPLF` shows `CRMCUST` / `CRMPIPE`.
7. **Email.** From a customer, F8 contacts, then option `9` next to a
   contact. Change the To address to a real mailbox and press F10.

## How the pieces work

- **Tables** use SQL `CHAR` columns with 10-character names, identity
  keys and a `ROW CHANGE TIMESTAMP` (`CHGTS`) on each main table.
- **Optimistic locking** (`CRMCUSTM`): the update has
  `WHERE CUSTID = :id AND CHGTS = :timestampWhenRead`. Zero rows means
  someone else saved first.
- **Event log** (`CRMEVENT`): every change writes a row through
  `crm_logEvent`. `FORUSER` marks events meant for one user.
- **Dashboard refresh** (`CRMDASH`): `CRMDASHD` is created with
  `WAITRCD(2)`, the record has `INVITE`, and the program reads the file
  name with `READ(E)`. Status 1331 means the 2 seconds ran out, so the
  program checks `MAX(EVTID)` and reloads when it has changed. `PUTOVR`
  and `OVRDTA` send only the changed fields, which keeps the screen
  steady.
- **Colored bars** in the dashboard are single output fields with 5250
  attribute bytes (`x'20'`-`x'3F'`) inside the data. If your terminal
  shows these as odd characters, that is the part to look at.
- **Windows** use `WINDOW`, `WDWBORDER` and `WDWTITLE`. Prompt, email and
  print windows are separate display files with an `ASSUME` record, so
  the screen of the calling program stays visible behind them.
- **Shared code** is in service program `CRMSRV` (binding directory
  `CRMBND`); prototypes are in the `CRMSRVH` copybook.
- All programs run in activation group `CRMDEMO` with `COMMIT(*NONE)`.

## Function keys

| Key | Meaning |
|---|---|
| F3 | Exit |
| F4 | Prompt (cursor on a code field) |
| F5 | Refresh / reload |
| F6 | Add |
| F7 / F8 / F9 | Activities / Contacts / Email (customer detail); My tasks / Pipeline / Customers (dashboard) |
| F10 | Confirm delete, send email, toggle open/all activities |
| F11 | Show/hide closed deals; mine/everyone on the task list |
| F12 | Cancel |
| F21 | Print |

## Resetting the demo

```
CALL CRMDEMO/CRMBUILD PARM('*YES')
```

Activity and deal dates are relative to the current date, so a reset
always gives overdue tasks, tasks due today and deals closing this
month.
