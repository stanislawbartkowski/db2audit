# db2audit

https://www.ibm.com/support/knowledgecenter/SSEPGG_11.5.0/com.ibm.db2.luw.admin.sec.doc/doc/c0005483.html

Practical step on how to enable DB2 auditing: https://github.com/stanislawbartkowski/wikis/wiki/DB2-auditing<br>

DB2 auditing by itself is a tool to collect audit data only. Next step is to develop a solution to analyze audit data, detect and escalate suspicious behaviour. Several topics under consideration.<br>

* Collect audit data and make them ready for further analysis.
* Configurable method to signal security violations.
* Flexible security rules, easy to define and expand according to particular use case.
* More then one database in a single instance, different set of rules for every database.

# Prerequisities

## Create user and database

Create a separate database to keep audit data, *dbaudit*.<br>

> db2 create database dbaudit<br>

Create a separate user to manage audit activities, *audituser*. Make *audituser* the administrator of *dbaudit* database and assign *SECADM* authority in yhr database under surveillance. Authority *SECADM* allows the user to run audit related activity but does not give access to the data.<br>

> db2 grant DBADM on database dbaudit to user audituser<br>
> db2 grant SECADM on database /database/ to user audituser<br>

Create audit tables in *dbaudit* database.<br>
> db2 connect to dbaudit user audituser<br>
> db2 -tvf /home/db2inst1/sqllib/misc/db2audit.ddl<br>\
> db2 list tables<br>
```
Table/View                      Schema          Type  Creation time             
------------------------------- --------------- ----- --------------------------
AUDIT                           AUDITUSER       T     2020-12-30-23.03.44.834161
CHECKING                        AUDITUSER       T     2020-12-30-23.03.45.400757
CONTEXT                         AUDITUSER       T     2020-12-30-23.03.48.494646
EXECUTE                         AUDITUSER       T     2020-12-30-23.03.49.061434
OBJMAINT                        AUDITUSER       T     2020-12-30-23.03.45.969018
SECMAINT                        AUDITUSER       T     2020-12-30-23.03.46.536462
SYSADMIN                        AUDITUSER       T     2020-12-30-23.03.47.360971
VALIDATE                        AUDITUSER       T     2020-12-30-23.03.47.927895
```
## Enable audit policy

Next step is to enable auditing in DB2 datababase and decide which audit events are going to be collected. Collecting too much data will cause audit database growing very fast and beging filled with unused data, being scanty here brings the risk that some security violations will pass unnoticed. The audit rules defined in the solution assumes that related data are collected. The rules will not signal security breaches if there is no approproate data. <br>

Assume all data is collected.<br>
> db2 connect to /database/ user audituser<br>
> db2 "CREATE AUDIT POLICY ALL_AUDIT CATEGORIES ALL STATUS BOTH ERROR TYPE NORMAL"<br>
> db2 "AUDIT database USING POLICY ALL_AUDIT"<br>




