#!/bin/bash

source $(dirname $0)/common.sh

TMPFILE=`mktemp`
REPLACE=insert

touch $ALREADYFILE


#=== FUNCTION ======================================================================================
#        NAME: loadfiles
# DESCRIPTION: Load audit CSV file into DB2 audit database. Database can be local or remote
#              Database can be local or remote, implemented by conntoaudit
#              Is preceded by processarch which prepares CSV files
# PARAMETERS : No parameters
#     RETURNS: Fails application in case of any failure
#===================================================================================================

loadfiles() {

   conntoaudit

   cat <<EOF | db2 -vs >$TMPFILE
      import from $DELIMDIR/audit.del of del $REPLACE into audit
      import from $DELIMDIR/checking.del of del $REPLACE into checking
      import from $DELIMDIR/validate.del of del $REPLACE into validate
      import from $DELIMDIR/sysadmin.del of del $REPLACE into sysadmin
      import from $DELIMDIR/objmaint.del of del $REPLACE into objmaint
      import from $DELIMDIR/context.del of del $REPLACE into context
      import from $DELIMDIR/execute.del of del $REPLACE into execute
      import from $DELIMDIR/secmaint.del of del $REPLACE into secmaint
EOF
   local -r RES=$?
   logfile $TMPFILE
   # ignores warning here
   [ $RES -eq 0 ] || log "$RES - non zero exit code, ignored if warning only"
   [ $RES -lt 4 ] || logfatal "Cannot load audit data into $AUDITDATABASE"
   rundb2 terminate
}

refreshdir() {
   rm -rf $DELIMDIR
   mkdir -p $DELIMDIR
   # DELIMDIR is created by db2audit user but db2inst1 user should have write permission there
   chmod 777 $DELIMDIR
}

#=== FUNCTION ======================================================================================
#        NAME: processarch
# DESCRIPTION: Evaluates output of archivaudit. Enumerates all output audit file name ignoring 
#              alredy processed. For all new file extract them in CSV format reeady for 
#              audit database loading. Filenames are stored in $TMPFILE 
# PARAMETER  1: monitored database name
# PARAMETER  2: file name with output of SYSPROC.AUDIT_LIST_LOGS command
#     RETURNS: Fails application in case of any failure
#===================================================================================================

processarch() {
   local -r SOURCEDB=$1
   local -r INPUTTMP=$2
   # output in $TMPFILE

   while read line
   do  
      echo $line
      if ! grep $line $ALREADYFILE; then
         refreshdir
   
         rundb2 "connect to $SOURCEDB"
         rundb2 "CALL SYSPROC.AUDIT_DELIM_EXTRACT(NULL, '$DELIMDIR', NULL, '$line', NULL)"
         rundb2 terminate
         loadfiles
         # update $ALREADYFILE to avoid duplicates in the future
         echo $line >>$ALREADYFILE
      else log "$line ignored, processed already"; fi

   done < <(cat $INPUTTMP | tr -d "[:blank:]")
  
}

archiveaudit() {
   local -r SOURCEDB=$1
   local -r OUTTMP=`mktemp`
   rundb2 "connect to $SOURCEDB"
   rundb2 "CALL SYSPROC.AUDIT_ARCHIVE(NULL, NULL)"
   rundb2 "SELECT FILE FROM TABLE(SYSPROC.AUDIT_LIST_LOGS(''))" -x
   cp $TMPFILE $OUTTMP
   rundb2 terminate
   processarch $SOURCEDB $OUTTMP
   rm $OUTTMP

}

allarchiveaudit() {
   for DB in $DATABASES; do 
      archiveaudit $DB
   done
}

test() {
#  loadfiles
#  archiveaudit $DB
  conntoaudit
}


TMPFILE=`mktemp`
allarchiveaudit
#test
rm $TMPFILE
