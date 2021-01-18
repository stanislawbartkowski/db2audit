# db2audit

https://www.ibm.com/support/knowledgecenter/SSEPGG_11.5.0/com.ibm.db2.luw.admin.sec.doc/doc/c0005483.html

Practical step on how to enable DB2 auditing: https://github.com/stanislawbartkowski/wikis/wiki/DB2-auditing<br>

DB2 auditing by itself is a tool to collect audit data only. Next step is to develop a solution to analyze audit data, detect and escalate suspicious behaviour. Several topics under consideration.<br>

* Collect audit data and make them ready for further analysis.
* Configurable method to signal security violations.
* Flexible security rules, easy to define and expand according to particular use case.
* More then one database in a single instance, different set of rules for every database.

# Prerequisities

Create a separate database to keep audit data, *dbaudit*.<br>

> db2 create database dbaudit<br>

Create a separate user to manage audit activities, *audituser*. Make *audituser* the administrator of *dbaudit* database and assign *SECADM* authority in database being audited. Authority *SECADM* allows the user to run audit related activity but does not give access to the data.<br>

> db2 grant DBADM on database dbaudit to user audituser<br>
> db2 grant SECADM on database /database/ to user audituser<br>

Create audit tables in *dbaudit* database.<br>
> db2 connect to dbaudit<br>
> db2 -tvf /home/db2inst1/sqllib/misc/db2audit.ddl<br>\
> db2 list tables<br>
