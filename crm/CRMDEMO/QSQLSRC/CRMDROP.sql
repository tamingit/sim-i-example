-- ==================================================================
-- CRMDROP - Drop all CRM demo tables (used by CRMBUILD *YES)
-- Run with ERRLVL(40) so missing tables are ignored.
-- ==================================================================
SET SCHEMA CRMDEMO;

DROP TABLE CRMEVENT;
DROP TABLE OPPTY;
DROP TABLE ACTIVITY;
DROP TABLE CONTACT;
DROP TABLE CUSTOMER;
DROP TABLE CRMCODE;
DROP TABLE CRMUSER;
