#!/bin/bash

source $(dirname $0)/common.sh

DB=sample
TMPFILE=`mktemp`
REPLACE=insert

REPLACE=insert

touch $ALREADYFILE

loadfiles() {

   rundb2 "connect to $AUDITDATABASE"

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
   [ $RES -le 4 ] || logfatal "Cannot load audit data into $AUDITDATABASE"
   rundb2 terminate
}

refreshdir() {
   rm -rf $DELIMDIR
   mkdir -p $DELIMDIR
   chmod 777 $DELIMDIR
}

processarch() {
   local -r SOURCEDB=$1
   # output in $TMPFILE
   while read line
   do  
      if ! grep $line $ALREADYFILE; then
         refreshdir
   
         rundb2 "connect to $SOURCEDB"
         rundb2 "CALL SYSPROC.AUDIT_DELIM_EXTRACT(NULL, '$DELIMDIR', NULL, '$line', NULL)"
         rundb2 terminate
         loadfiles
         echo $line >>$ALREADYFILE
      else log "$line ignored, processed already"; fi

   done < <(cat $TMPFILE | tr -d "[:blank:]")
}

archiveaudit() {
   local -r SOURCEDB=$1
   rundb2 "connect to $SOURCEDB"
   rundb2 "CALL SYSPROC.AUDIT_ARCHIVE(NULL, NULL)"
   rundb2 "SELECT FILE FROM TABLE(SYSPROC.AUDIT_LIST_LOGS(''))" -x
   processarch $SOURCEDB
   rundb2 terminate
}

archiveaudit $DB

rm $TMPFILE
#loadfiles
