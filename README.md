# db2audit

https://www.ibm.com/support/knowledgecenter/SSEPGG_11.5.0/com.ibm.db2.luw.admin.sec.doc/doc/c0005483.html

Practical step on how to enable DB2 auditing: https://github.com/stanislawbartkowski/wikis/wiki/DB2-auditing<br>

DB2 auditing by itself is a DB2 feature to collect audit data only. Next step is to develop a solution to analyze audit data, detect and escalate suspicious behaviour. Several topics under consideration.<br>

* Collect audit data and make them ready for further analysis.
* Configurable method to signal security violations.
* Flexible security rules, easy to define and expand according to a particular use case.
* More then one database in a single instance, a different set of rules for every database.

The solution can be deployed in two different configuration. 

* Every instance keeps its own copy of audit database. 
* There is one collective audit database for a group of instances.

## DB2 audit user

Create a separate DB2 user, for instance: *db2audit*. This user will have *SECADM* authority on monitored database and will run all audit related activities.<br>
Source DB2 related environment variables:<br>

> vi .bashrc
```
source /home/db2inst1/sqllib/db2profile
```

## Download

As *db2audit* user.<br>

> git clone https://github.com/stanislawbartkowski/db2audit.git<br>
> cd db2audit<br>
> mkdir config<br>
> cp -r config.template/* config<br>

## Configuration

* config/env.rc

| Variable name | Description | Sample value
| ---- | ----- | ----- |
| AUDITDATABASE | The name of the audit database | dbaudit
| AUDITUSER | The audit user having *SECADM* authority in the database being monitored | db2audit
| LOGFILE | The log file created by the tool | $LOGDIR/histfile.log
| DELIMDIR | Temporary directory used to extract CVS text files | DELIMDIR=/tmp/dir
| ALREADYFILE | Text file containing the list of already loaded audit file | $LOGDIR/alreadyfile.txt
| MAXTIMESTAMPFILE | Text file containing the last timestamp for every audit table | $LOGDIR/maxtimestampfile.txt
| DATABASES | List of monitored databases separated by space | "sample mdm"
<br>

* config/queries

List of investigative queries. Every query is stored in a separate *rc* file. More detailed description: look below

* config/db_{database}.rc

Every database included in *DATABASES* variable should have corresponding *config/db_{database}.rc* file. More detailed description: look below.

## Alerting

Every security incident is reported by calling *alert.sh* script. The script is called using two parameters:

| Parameter | Description |
| ---- | ---- |
| $1 | Value of *HEADER* environment variable corresponding to the investigative query. Allows to make more a descriptive error message 
| $2 | The name of temporary file containing a not empty query result

Example, stores alerts in the designed text file.

```
#!/bin/bash

source $(dirname $0)/common.sh

TOPIC="$1"
CONTENTFILE="$2"

echo "ALERT: $TOPIC" >>$ALERTFILE
cat $CONTENTFILE >>$ALERTFILE
echo "=============================" >>$ALERTFILE
```

## Execution

The tool contains two main script files.<br>
* *load.sh* Extracts and loads audit recored in *dbaudit* database.
* *audit.sh* Runs investigative queries to detect security incidents

The *load.sh* script should be executed on the host where DB2 instance is installed as *audituser*. It is using a local connection to databases.<br>
The *audit.sh* script is executed on the host where audit database exists.<br>

# Prerequisities

## Create user and database

Create a separate database to keep audit data, *dbaudit*.<br>

> db2 create database dbaudit<br>

Create a separate user to manage audit activities, *audituser*. Make *audituser* the administrator of *dbaudit* database and assign *SECADM* authority in the database under surveillance. Authority *SECADM* allows the user to run audit-related activity but does not give access to the data.

> db2 grant DBADM on database dbaudit to user audituser<br>
> db2 grant SECADM on database /database/ to user audituser<br>

Create audit tables in *dbaudit* database.<br>
> db2 connect to dbaudit user audituser<br>
> db2 -tvf /home/db2inst1/sqllib/misc/db2audit.ddl<br>
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
## Preparing directories to keep DB2 audit data

Example:<br>

> mkdir audit
> mkdir archaudit
> db2audit configure datapath /home/db2inst1/audit archivepath /home/db2inst1/archaudit

Current audit data records are stored in */home/db2inst1/audit*. After running *AUDIT_ARCHIVE* stored procedure, the audit records are moved to */home/db2inst1/archaudit* directory and */home/db2inst1/audit* is reset.

## Enable audit policy

Next step is to enable auditing in DB2 database and decide which audit events are going to be collected. Collecting too much data will cause the audit database growing very fast and being filled with unused data, being scanty here brings the risk that some security violations will pass unnoticed. The audit rules defined in the solution assumes that related data are collected. The rules will not signal security breaches if there is no appropriate data. <br>

Assume all data is collected.<br>

> db2 connect to /database/ user audituser<br>
> db2 "CREATE AUDIT POLICY ALL_AUDIT CATEGORIES ALL STATUS BOTH ERROR TYPE NORMAL"<br>
> db2 "AUDIT database USING POLICY ALL_AUDIT"<br>

# Loading audit data

https://github.com/stanislawbartkowski/db2audit/blob/main/load.sh

>./load.sh<br>

*load.sh* scripts reads the list of all databases in *DATABASES* environment variable and for every database move audit data records info *dbaudit* database.<br>
<br>
Loading audit data into the audit database involves three steps:<br>
* Run *AUDIT_ARCHIVE* command to move audit records to */home/db2inst1/archaudit* and reset */home/db2inst1/audit*
* Run *SYSPROC.AUDIT_DELIM_EXTRACT* command to transform archived data to CSV text files
* Load extracted CSV files into *dbaudit* database

After loading data into *dbaudit* database, the */home/db2inst1/archaudit* is not cleared and stores the results of all previous *AUDIT_ARCHIVE* calls. To avoid data duplication, a separate text file *$LOGDIR/alreadyfile.txt* keeps the list of the archived file already loaded. After every successful data loading, a new line is added to this file.<br>

The script *load.sh* can be launched manually or be executed as a crontab job in some time intervals.<br>

# Detecting security breaches

## Method description

https://github.com/stanislawbartkowski/db2audit/blob/main/audit.sh

>./audit.sh<br>

The script can be launched manually on-demand or be executed as a cronjob tab.<br>
<br>
The *

* script is performing the following steps:<br>

* Read all databases in *DATABASES* environment variable.
* For every database, source *config/db_{database}.rc* file
* *rc* file should contain at least *QUERIES* environment variable. The variable specifies the list of investigative queries to be executed.
* For every audit table, an environment variable is set equals to the timestamp of the last auditing to avoid duplication of alerts.
* Runs every investigative query specified in *QUERIES*. If the query returns not empty result, the *alert.sh* script is called.
* After scanning all databases, *MAXTIMESTAMPFILE* file is updated.

## MAXTIMESTAMPFILE

The *dbaudit* databases is storing all audit records. To avoid alert duplication, the tool is maintaining *MAXTIMESTAMPFILE* (specified in *config/env.rc*). It is the text file and every line consists the name of the audit table and the timestamp of the last scan. Example:

```
AUDIT 2021-01-05-16.11.03.707483
SECMAINT 2020-12-31-11.11.28.486892
VALIDATE 2021-01-18-17.21.42.916749
```
CHECKING_MAXTM

Before running the investigative query, the tool automatically sets the *{table}_MAXTM* environment variable to be used in the query. For instance, for *CHECKING* table the *CHECKING_MAXTM* variable is used and investigative query on this table should use the variable in the *WHERE* clause.

```
SELECT ... FROM CHEKING WHERE ... AND TIMESTAMP > '${CHEKING_MAXTM}'
```
Important: Every security incident is reported only once. It the alert is missed, it will not appear again although the relevant data are still stored in *dbaudit* database.

## Investigate queries

To detect security violations, investigative queries on *dbaudit* database are executed. Every not empty result means security incident and is signalled.<br>
Investigate queries are stored in *config/queries* directory.

> ls config/queries/
```
unauthconnect.rc  
unauthop.rc
```

Every query is stored as a separate *rc* bash file. The file defines two environment variables:
* HEADER : The header text included in the alert message making the incident report more human-readable.
* QUERY: The text of the query. It is bash environment variable and can be customized by another environment variable specific to the database.

Example:
```
HEADER="Not authorized command on database $DATABASE detected"

QUERY="SELECT VARCHAR_FORMAT(TIMESTAMP,'YYYY-MM-DD HH24:MI:SS') AS TIME,DATABASE,AUTHID,HOSTNAME,APPID,APPNAME, INSTNAME FROM CHECKING WHERE STATUS=-551 AND TIMESTAMP>'$CHECKING_MAXTM'"
```

The query detects all *-551* incidents meaning that the user does not have privileges to perform the operation. The *CHECKING_MAXTM* is environment variable set automatically by the tool and allow to limit the audit time range to the latest incidents only.

# Error handling, logging

In case of any error coming from *db2* command line or any scripts, the tool is exiting returning 4 exit code and no action is performed. The error should be fixed immediately because it means that security guard is disarmed.<br>

All activities including full SQL statements executed, are logged in $LOGFILE file defined in *config/env.rc* file.<br>

# Test

## Security

Assume database *SAMPLE* and the following security policy:<br>
* *user* : can read and write tables
* *vuser* : read only user
* *nuser* : any access forbidden

*config/db_sample.rc* file
```
QUERIES="unauthconnect unauthop unauthupdate"

AUTHCONNECTUSERS=",'USER','VUSER'"
UNAUTHUPDATE="'VUSER'"
```
Security audit for *sample* database will run *config/quueries/unauthconnect.rc* and *config/quueries/unauthop.rc*

*AUTHCONNECTUSER* variable is used in *config/queries/unauthconnect.rc* WHERE clause. Format is very important, after evaluating the variable, proper SQL syntax is expected. Pay attention to comma at the beginning and capital letters in the user names.<br>

```
QUERY = SELEC ... FROM CHECKING WHERE ...  EVENT='CONNECT' AND AUTHID NOT IN ('DB2INST1',UPPER('$AUDITUSER')${AUTHCONNECTUSERS}) ...
```
In a similar way, *UNAUTHUPDATE* is used in *config/queries/unauthupdate.rc* WHERE clause. This query detects any update sql statement: UPDATE, INSERT, DELETE executed by unautorized users. Pay attention that *audituser* is not included in privileded group and will be reported trying to do something outside pute audit related work.<br>
```
QUERY="SELECT ... FROM EXECUTE WHERE .. AND AUTHID NOT IN ('DB2INST1') AND AUTHID IN (${UNAUTHUPDATE}) AND ACTIVITYTYPE='WRITE_DML'  ... "
```

> db2 connect to sample<br>

Make *user* read/wite user.<br>
> db2 grant DATAACCESS on database to user user<br>

Make *vuser* read only user.<br>
> db2 grant EXECUTE on package NULLID.SQLC2P30 to user vuser<br>
> db2 -x list tables | cut -d ' ' -f 1 | while read t; do echo "GRANT SELECT ON $t to user vuser; "; done | db2 -tv<br>

## Test1, nuser is trying to connect to sample

Log in as *user* (authorized) and *nuser* (not authorized).

> db2 connect to sample user user using secret<br>

On the server side.<br>

> ./load.sh<br>
> ./audit.sh<br>

> cat /tmp/alert.txt<br>
```
LERT: Unauthorized connect to database sample detected
2021-01-18 18:31:45                                                                                                                                               SAMPLE   NUSER  db1.sb.com 192.168.0.242.57628.210118173145 db2bp  db2inst1                   
```

Only *nuser* is reported and security incident.

# Test2, vuser tries to update data

> db2 connect to sample user vuser
> db2 "select * from db2inst1.staff"
```
.........
 310 Graham        66 Sales     13  71000,00    200,30
   320 Gonzales      66 Sales      4  76858,20    844,00
   330 Burke         66 Clerk      1  49988,00     55,50
   340 Edwards       84 Sales      7  67844,00   1285,00
   350 Gafney        84 Clerk      5  43030,50    188,00

  35 record(s) selected.
```

> db2 "delete from db2inst1.staff where DEPT=999"
```
DB21034E  The command was processed as an SQL statement because it was not a 
valid Command Line Processor command.  During SQL processing it returned:
SQL0551N  The statement failed because the authorization ID does not have the 
required authorization or privilege to perform the operation.  Authorization 
ID: "VUSER".  Operation: "DELETE". Object: "DB2INST1.STAFF".  SQLSTATE=42501

```

On the server side.<br>
> ./load.sh<br>
> ./audit.sh<br>

> cat /tmp/alert.txt<br>
```
ALERT: Not authorized command on database sample detected

2021-01-18 21:44:52 SAMPLE  VUSER db1.sb.com 192.168.0.242.60918.210118204146 db2bp db2inst1                                                                              
```
# Test3, overprivileged vuser updates data

Assume that because of the inside job, *vuser* is granted also *DATAACESS* authority.

> db2 grant DATAACCESS on database to user vuser<br>

> db2 connect to sample user vuser<br>
> db2 "delete from db2inst1.staff where DEPT=999"
```
SQL0100W  No row was found for FETCH, UPDATE or DELETE; or the result of a 
query is an empty table.  SQLSTATE=02000
```

The same for correctly authorized *user*.

> db2 connect to sample user user<br>
> db2 "delete from db2inst1.staff where DEPT=999"
```
SQL0100W  No row was found for FETCH, UPDATE or DELETE; or the result of a 
query is an empty table.  SQLSTATE=02000
```

On the server side.<br>
>./load.sh<br>
>./audit.sh<br>
> cat /tmp/alert.txt
```
ALERT: Unauthorized update on sample detected
2021-01-18 22:56:21 SAMPLE VUSER db1.sb.com 192.168.0.242.34176.210118215136 db2bp db2inst1 STATEMENT WRITE_DML                 
```

Unauthorized update statement by user *vuser* is signalled, the same statement by *user* is not.
