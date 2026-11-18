-- ==================================================================
-- CRMSEED - Sample data for the CRM demo
--   3 demo users, code values, 50 customers, ~115 contacts,
--   ~250 activities/tasks and ~70 opportunities.
-- Dates are relative to CURRENT DATE so the demo always looks fresh.
-- Run:  RUNSQLSTM SRCFILE(CRMDEMO/QSQLSRC) SRCMBR(CRMSEED)
--                 COMMIT(*NONE) NAMING(*SQL)
-- All email domains end in .example so nothing can be delivered to
-- a real company by accident.
-- ==================================================================
SET SCHEMA CRMDEMO;

-- ------------------------------------------------------------------
-- Demo users. Create matching user profiles CRMUSR1-3 for the
-- multi-user part of the demo (see README).
-- ------------------------------------------------------------------
INSERT INTO CRMUSER (USERID, FULLNAME, EMAIL) VALUES
  ('CRMUSR1', 'Jordan Lee',   'jordan.lee@crmdemo.example'),
  ('CRMUSR2', 'Sam Patel',    'sam.patel@crmdemo.example'),
  ('CRMUSR3', 'Casey Morgan', 'casey.morgan@crmdemo.example');

-- ------------------------------------------------------------------
-- Code values for F4 prompts
-- ------------------------------------------------------------------
INSERT INTO CRMCODE (CODETYPE, CODE, DESCR, SEQ) VALUES
  ('STATUS',   'P',      'Prospect',             1),
  ('STATUS',   'A',      'Active',               2),
  ('STATUS',   'I',      'Inactive',             3),
  ('ACTTYPE',  'CALL',   'Phone call',           1),
  ('ACTTYPE',  'MEET',   'Meeting',              2),
  ('ACTTYPE',  'EMAIL',  'Email',                3),
  ('ACTTYPE',  'NOTE',   'Note',                 4),
  ('ACTTYPE',  'TASK',   'Task / to-do',         5),
  ('STAGE',    '1',      'Lead',                 1),
  ('STAGE',    '2',      'Qualified',            2),
  ('STAGE',    '3',      'Proposal',             3),
  ('STAGE',    '4',      'Negotiation',          4),
  ('STAGE',    '5',      'Won',                  5),
  ('STAGE',    '6',      'Lost',                 6),
  ('PRIORITY', 'H',      'High',                 1),
  ('PRIORITY', 'M',      'Medium',               2),
  ('PRIORITY', 'L',      'Low',                  3),
  ('INDUSTRY', 'CONSTR', 'Construction',         1),
  ('INDUSTRY', 'EDU',    'Education',            2),
  ('INDUSTRY', 'ENERGY', 'Energy and utilities', 3),
  ('INDUSTRY', 'FINANCE','Banking and finance',  4),
  ('INDUSTRY', 'FOOD',   'Food and beverage',    5),
  ('INDUSTRY', 'HEALTH', 'Healthcare',           6),
  ('INDUSTRY', 'LOGISTIC','Transport/logistics', 7),
  ('INDUSTRY', 'MFG',    'Manufacturing',        8),
  ('INDUSTRY', 'RETAIL', 'Retail',               9),
  ('INDUSTRY', 'TECH',   'Technology',          10);

-- ------------------------------------------------------------------
-- 50 fictional customers (IDs 1001-1050), owners round-robin
-- ------------------------------------------------------------------
INSERT INTO CUSTOMER (CUSTID, NAME, STATUS, INDUSTRY, ADDR1, CITY,
                      STATE, ZIP, PHONE, WEBSITE, OWNER,
                      CRTUSER, CHGUSER)
SELECT 1000 + T.RN, T.NAME, T.STS, T.IND,
       RTRIM(CHAR(100 + MOD(T.RN * 137, 8800))) CONCAT ' '
         CONCAT S.STREET,
       T.CITY, T.ST,
       RIGHT(DIGITS(10000 + MOD(T.RN * 7919, 89999)), 5),
       '(' CONCAT T.AREA CONCAT ') 555-01'
         CONCAT RIGHT(DIGITS(MOD(T.RN * 7, 100)), 2),
       'www.' CONCAT LOWER(REPLACE(RTRIM(T.NAME), ' ', ''))
         CONCAT '.example',
       'CRMUSR' CONCAT RTRIM(CHAR(MOD(T.RN, 3) + 1)),
       'CRMSEED', 'CRMSEED'
FROM (VALUES
  ( 1, 'Acme Widget Works',       'A', 'MFG',     'Cleveland',   'OH','216'),
  ( 2, 'Blue Harbor Logistics',   'A', 'LOGISTIC','Baltimore',   'MD','410'),
  ( 3, 'Copperline Foods',        'A', 'FOOD',    'Omaha',       'NE','402'),
  ( 4, 'Driftwood Medical Group', 'P', 'HEALTH',  'Tampa',       'FL','813'),
  ( 5, 'Evergreen Credit Union',  'A', 'FINANCE', 'Spokane',     'WA','509'),
  ( 6, 'Falcon Ridge Energy',     'A', 'ENERGY',  'Tulsa',       'OK','918'),
  ( 7, 'Granite State Builders',  'P', 'CONSTR',  'Concord',     'NH','603'),
  ( 8, 'Harborview Academy',      'I', 'EDU',     'Portland',    'ME','207'),
  ( 9, 'Ironclad Fasteners',      'A', 'MFG',     'Toledo',      'OH','419'),
  (10, 'Juniper Retail Co',       'A', 'RETAIL',  'Boise',       'ID','208'),
  (11, 'Keystone Data Systems',   'A', 'TECH',    'Harrisburg',  'PA','717'),
  (12, 'Lakeshore Freight',       'P', 'LOGISTIC','Milwaukee',   'WI','414'),
  (13, 'Maple Leaf Bakeries',     'A', 'FOOD',    'Burlington',  'VT','802'),
  (14, 'Northgale Turbines',      'P', 'ENERGY',  'Fargo',       'ND','701'),
  (15, 'Oakridge Pharmacy',       'A', 'HEALTH',  'Knoxville',   'TN','865'),
  (16, 'Pioneer Valley Bank',     'A', 'FINANCE', 'Springfield', 'MA','413'),
  (17, 'Quarry Hill Concrete',    'A', 'CONSTR',  'Rockford',    'IL','815'),
  (18, 'Redwood Learning Center', 'P', 'EDU',     'Eureka',      'CA','707'),
  (19, 'Silverline Electronics',  'A', 'TECH',    'San Jose',    'CA','408'),
  (20, 'Timberline Outfitters',   'A', 'RETAIL',  'Bozeman',     'MT','406'),
  (21, 'Union Square Textiles',   'I', 'MFG',     'Charlotte',   'NC','704'),
  (22, 'Vista Cold Storage',      'A', 'LOGISTIC','Fresno',      'CA','559'),
  (23, 'Westbrook Dairy',         'P', 'FOOD',    'Madison',     'WI','608'),
  (24, 'Yellowstone Solar',       'A', 'ENERGY',  'Billings',    'MT','406'),
  (25, 'Zenith Orthopedics',      'A', 'HEALTH',  'Phoenix',     'AZ','602'),
  (26, 'Anchor Point Insurance',  'P', 'FINANCE', 'Hartford',    'CT','860'),
  (27, 'Bridgewater Steel',       'A', 'MFG',     'Gary',        'IN','219'),
  (28, 'Canyon Creek Homes',      'A', 'CONSTR',  'Boulder',     'CO','303'),
  (29, 'Delta Tech Institute',    'A', 'EDU',     'Memphis',     'TN','901'),
  (30, 'Echo Valley Software',    'P', 'TECH',    'Provo',       'UT','801'),
  (31, 'Fairway Sporting Goods',  'A', 'RETAIL',  'Scottsdale',  'AZ','480'),
  (32, 'Gulf Coast Shipping',     'A', 'LOGISTIC','Mobile',      'AL','251'),
  (33, 'Heritage Farms Market',   'A', 'FOOD',    'Lancaster',   'PA','717'),
  (34, 'Ironwood Pipeline',       'I', 'ENERGY',  'Midland',     'TX','432'),
  (35, 'Jasper Family Clinic',    'P', 'HEALTH',  'Jasper',      'IN','812'),
  (36, 'Kingsley Capital',        'A', 'FINANCE', 'Richmond',    'VA','804'),
  (37, 'Lone Pine Lumber',        'A', 'CONSTR',  'Eugene',      'OR','541'),
  (38, 'Meadowbrook College',     'A', 'EDU',     'Ames',        'IA','515'),
  (39, 'Nimbus Cloud Services',   'A', 'TECH',    'Austin',      'TX','512'),
  (40, 'Orchard Lane Grocers',    'P', 'RETAIL',  'Yakima',      'WA','509'),
  (41, 'Prairie Wind Packaging',  'A', 'MFG',     'Wichita',     'KS','316'),
  (42, 'Riverbend Trucking',      'A', 'LOGISTIC','Dubuque',     'IA','563'),
  (43, 'Summit Coffee Roasters',  'A', 'FOOD',    'Denver',      'CO','720'),
  (44, 'Tidewater Power',         'A', 'ENERGY',  'Norfolk',     'VA','757'),
  (45, 'Unity Senior Care',       'A', 'HEALTH',  'Dayton',      'OH','937'),
  (46, 'Valor Mutual Trust',      'P', 'FINANCE', 'Wilmington',  'DE','302'),
  (47, 'Whitestone Masonry',      'P', 'CONSTR',  'Albany',      'NY','518'),
  (48, 'Brightpath Tutoring',     'A', 'EDU',     'Raleigh',     'NC','919'),
  (49, 'Quantum Peak Labs',       'A', 'TECH',    'Durham',      'NC','984'),
  (50, 'Cornerstone Hardware',    'A', 'RETAIL',  'Des Moines',  'IA','515')
) AS T (RN, NAME, STS, IND, CITY, ST, AREA)
JOIN (VALUES (0, 'Main Street'),   (1, 'Oak Avenue'),
             (2, 'Industrial Pkwy'),(3, 'Commerce Drive'),
             (4, 'Lake Road'),     (5, 'Market Street'),
             (6, 'River Road'),    (7, 'Maple Avenue'),
             (8, 'Enterprise Way'),(9, 'Center Street')
     ) AS S (I, STREET)
  ON S.I = MOD(T.RN, 10);

ALTER TABLE CUSTOMER ALTER COLUMN CUSTID RESTART WITH 1051;

-- ------------------------------------------------------------------
-- Contacts: 2 per customer, 3 for every third customer
-- ------------------------------------------------------------------
INSERT INTO CONTACT (CUSTID, FIRSTNAME, LASTNAME, TITLE, PHONE, EMAIL,
                     ISPRIMARY, CRTUSER, CHGUSER)
SELECT C.CUSTID, F.FNAME, L.LNAME, T.TITLE,
       SUBSTR(C.PHONE, 1, 10) CONCAT '01'
         CONCAT RIGHT(DIGITS(MOD(C.CUSTID * N.N + 11, 100)), 2),
       LOWER(RTRIM(F.FNAME) CONCAT '.' CONCAT RTRIM(L.LNAME) CONCAT '@'
         CONCAT SUBSTR(RTRIM(C.WEBSITE), 5)),
       CASE WHEN N.N = 1 THEN 'Y' ELSE 'N' END,
       'CRMSEED', 'CRMSEED'
FROM CUSTOMER C
CROSS JOIN (VALUES 1, 2, 3) AS N (N)
JOIN (VALUES ( 0, 'Olivia'), ( 1, 'Liam'),   ( 2, 'Emma'),
             ( 3, 'Noah'),   ( 4, 'Ava'),    ( 5, 'Ethan'),
             ( 6, 'Mia'),    ( 7, 'Lucas'),  ( 8, 'Sofia'),
             ( 9, 'Mason'),  (10, 'Harper'), (11, 'Logan'),
             (12, 'Amelia'), (13, 'Elijah'), (14, 'Chloe'),
             (15, 'Aiden'),  (16, 'Grace'),  (17, 'Carter'),
             (18, 'Nora'),   (19, 'Wyatt')
     ) AS F (I, FNAME)
  ON F.I = MOD(C.CUSTID * 7 + N.N * 3, 20)
JOIN (VALUES ( 0, 'Anderson'), ( 1, 'Brooks'),  ( 2, 'Carver'),
             ( 3, 'Diaz'),     ( 4, 'Evans'),   ( 5, 'Foster'),
             ( 6, 'Garcia'),   ( 7, 'Hughes'),  ( 8, 'Ingram'),
             ( 9, 'Jensen'),   (10, 'Kim'),     (11, 'Lopez'),
             (12, 'Mitchell'), (13, 'Nguyen'),  (14, 'Ortiz'),
             (15, 'Parker'),   (16, 'Quinn'),   (17, 'Reyes'),
             (18, 'Sullivan'), (19, 'Turner')
     ) AS L (I, LNAME)
  ON L.I = MOD(C.CUSTID * 11 + N.N * 5, 20)
JOIN (VALUES (0, 'Owner'),              (1, 'President'),
             (2, 'VP Operations'),      (3, 'Purchasing Manager'),
             (4, 'IT Director'),        (5, 'Controller'),
             (6, 'Office Manager'),     (7, 'Plant Manager')
     ) AS T (I, TITLE)
  ON T.I = MOD(C.CUSTID + N.N * 3, 8)
WHERE N.N < 3 OR MOD(C.CUSTID, 3) = 0;

-- ------------------------------------------------------------------
-- Completed history: calls, meetings, emails and notes
-- ------------------------------------------------------------------
INSERT INTO ACTIVITY (CUSTID, CONTID, ACTTYPE, SUBJECT, NOTES, ACTDATE,
                      DUEDATE, PRIORITY, ASSIGNTO, DONE, DONEDATE,
                      CRTUSER, CHGUSER)
SELECT C.CUSTID,
       COALESCE((SELECT MIN(K.CONTID) FROM CONTACT K
                  WHERE K.CUSTID = C.CUSTID), 0),
       S.TYP, S.SUBJ, S.NOTE,
       CURRENT DATE - (MOD(C.CUSTID * N.N * 13, 75) + N.N) DAYS,
       '0001-01-01', 'M', C.OWNER, 'Y',
       CURRENT DATE - (MOD(C.CUSTID * N.N * 13, 75) + N.N) DAYS,
       C.OWNER, C.OWNER
FROM CUSTOMER C
CROSS JOIN (VALUES 1, 2, 3, 4) AS N (N)
JOIN (VALUES
  (0, 'CALL',  'Intro call with buyer',
      'Walked through our offering. Buyer wants pricing for next quarter.'),
  (1, 'MEET',  'Quarterly business review',
      'Reviewed service levels and open issues. Customer happy overall.'),
  (2, 'EMAIL', 'Sent pricing sheet',
      'Emailed current price list and volume discount tiers.'),
  (3, 'NOTE',  'Budget approved for next year',
      'Finance confirmed budget. Decision expected within 60 days.'),
  (4, 'CALL',  'Follow-up on open quote',
      'Reached the buyer. They want revised delivery dates.'),
  (5, 'MEET',  'On-site product demo',
      'Demo went well. IT asked for security documentation.'),
  (6, 'EMAIL', 'Sent contract draft',
      'Contract draft sent to their legal team for review.'),
  (7, 'NOTE',  'Competitor evaluating account',
      'A competitor is pitching them. Keep in close contact.')
     ) AS S (I, TYP, SUBJ, NOTE)
  ON S.I = MOD(C.CUSTID + N.N * 3, 8)
WHERE N.N <= 2 OR MOD(C.CUSTID + N.N, 3) <> 0;

-- ------------------------------------------------------------------
-- Open tasks for the account owner (some overdue, some due soon)
-- ------------------------------------------------------------------
INSERT INTO ACTIVITY (CUSTID, CONTID, ACTTYPE, SUBJECT, NOTES, ACTDATE,
                      DUEDATE, PRIORITY, ASSIGNTO, DONE, DONEDATE,
                      CRTUSER, CHGUSER)
SELECT C.CUSTID,
       COALESCE((SELECT MIN(K.CONTID) FROM CONTACT K
                  WHERE K.CUSTID = C.CUSTID), 0),
       'TASK', S.SUBJ, S.NOTE,
       CURRENT DATE - MOD(C.CUSTID, 10) DAYS,
       CURRENT DATE + (MOD(C.CUSTID * 7, 24) - 8) DAYS,
       CASE MOD(C.CUSTID, 3) WHEN 0 THEN 'H' WHEN 1 THEN 'M' ELSE 'L' END,
       C.OWNER, 'N', '0001-01-01', C.OWNER, C.OWNER
FROM CUSTOMER C
JOIN (VALUES
  (0, 'Prepare proposal',
      'Build the proposal from the latest requirements and pricing.'),
  (1, 'Schedule renewal meeting',
      'Contract renews soon. Book a meeting with the decision makers.'),
  (2, 'Send security documentation',
      'IT requested our security overview and audit report.'),
  (3, 'Call back about delivery dates',
      'Buyer needs confirmed ship dates before signing.'),
  (4, 'Update account plan',
      'Refresh contacts, goals and next steps for this account.'),
  (5, 'Follow up on unpaid invoice',
      'Accounting reports an invoice 30 days past due.')
     ) AS S (I, SUBJ, NOTE)
  ON S.I = MOD(C.CUSTID, 6)
WHERE C.STATUS <> 'I';

-- ------------------------------------------------------------------
-- Tasks delegated by the owner to a colleague
-- ------------------------------------------------------------------
INSERT INTO ACTIVITY (CUSTID, CONTID, ACTTYPE, SUBJECT, NOTES, ACTDATE,
                      DUEDATE, PRIORITY, ASSIGNTO, DONE, DONEDATE,
                      CRTUSER, CHGUSER)
SELECT C.CUSTID, 0, 'TASK',
       'Review pricing before renewal',
       'Please double-check the discount levels before we send terms.',
       CURRENT DATE - 2 DAYS,
       CURRENT DATE + MOD(C.CUSTID, 5) DAYS,
       'H',
       'CRMUSR' CONCAT RTRIM(CHAR(MOD(C.CUSTID + 1, 3) + 1)),
       'N', '0001-01-01', C.OWNER, C.OWNER
FROM CUSTOMER C
WHERE MOD(C.CUSTID, 5) = 0 AND C.STATUS = 'A';

-- ------------------------------------------------------------------
-- Opportunities: 1 per active/prospect customer, 2 for even IDs
-- ------------------------------------------------------------------
INSERT INTO OPPTY (CUSTID, OPPNAME, STAGE, AMOUNT, PROB, CLOSEDATE,
                   OWNER, CRTUSER, CHGUSER)
SELECT X.CUSTID, P.PNAME, X.STAGE,
       (MOD(X.CUSTID * X.N * 7919, 95) + 5) * 1000,
       CASE X.STAGE WHEN '1' THEN 10 WHEN '2' THEN 25
                    WHEN '3' THEN 50 WHEN '4' THEN 75
                    WHEN '5' THEN 100 ELSE 0 END,
       CASE WHEN X.STAGE IN ('5', '6')
            THEN CURRENT DATE - MOD(X.CUSTID * X.N, 40) DAYS
            ELSE CURRENT DATE + (MOD(X.CUSTID * X.N * 17, 120) - 20) DAYS
       END,
       X.OWNER, X.OWNER, X.OWNER
FROM (SELECT C.CUSTID, C.OWNER, N.N,
             SUBSTR('1123423456', MOD(C.CUSTID * 3 + N.N, 10) + 1, 1)
               AS STAGE
        FROM CUSTOMER C
       CROSS JOIN (VALUES 1, 2) AS N (N)
       WHERE C.STATUS <> 'I'
         AND (N.N = 1 OR MOD(C.CUSTID, 2) = 0)) AS X
JOIN (VALUES (0, 'ERP upgrade'),
             (1, 'Annual support renewal'),
             (2, 'Warehouse scanners'),
             (3, 'Cloud backup service'),
             (4, 'Training package'),
             (5, 'Hardware refresh'),
             (6, 'Managed security'),
             (7, 'Additional user licenses'),
             (8, 'Consulting block - 100 hours'),
             (9, 'Data analytics pilot')
     ) AS P (I, PNAME)
  ON P.I = MOD(X.CUSTID + X.N * 4, 10);

INSERT INTO CRMEVENT (EVTUSER, EVTTYPE, EVTTEXT)
  VALUES ('CRMSEED', 'SEED', 'Demo database loaded with 50 customers');
