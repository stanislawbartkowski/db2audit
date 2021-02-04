#!/bin/bash

source $(dirname $0)/config/env.rc

ALLTABLES="AUDIT CHECKING CONTEXT EXECUTE OBJMAINT SECMAINT SYSADMIN VALIDATE"

mkdir -p $LOGDIR
touch $MAXTIMESTAMPFILE
touch $ALREADYFILE

getdate() {
   echo $(date '+%y/%m/%d %H:%M:%S')
}

log() {
   local -r mess="$1"
   echo $mess
   echo $(getdate) $mess >>$LOGFILE
}

logfile() {
   cat $1
   cat $1 >>$LOGFILE
}

logfatal() {
   log "$1"
   log "FATAL ERROR: cannot continue"
   exit 4
}

#=== FUNCTION ======================================================================================
#        NAME: rundb2
# DESCRIPTION: Common function to run any db2 command. Every command executed is logged
# PARAMETER 1: Command to execute
# PARAMETER 2: (optional) additional parameter to db2
# PARAMETER 3: (optional) password, if set, do not log command
#     RETURNS: If db2 exit command greater or equal 4 meaning fatal error, exits the application
#              If db2 exit command not zero but less then 4, logs warning and continues
#              Non-fatal exit code could mean, for instance, empty result set
#===================================================================================================


rundb2() {
   local -r command="$1"
   local -r X=$2
   local -r PASSWORD=$3

   [ -z "$PASSWORD" ] && log "$command"
   eval db2 $X "\"$command\"" >$TMPFILE
   local -r RES=$?
   logfile $TMPFILE 
   [ $RES -ne 0 ] && log "$RES db2 exit code non-zero. Will continue if not fatal"
   [ $RES -lt 4 ] || logfatal "Execution failed. db2 exit code $RES"
}

#=== FUNCTION ======================================================================================
#        NAME: conntoaudit
# DESCRIPTION: Connects to audit database. Supports local or remote connection
# PARAMETERS : no parameters
#     RETURNS: If not successfull, exits the application
#===================================================================================================


conntoaudit() {
   local CREDENTIALS=""
   local PASSWORDPARAMETER=""
   [ -n "$AUDITPASSWORD" ] && CREDENTIALS=" USER $AUDITUSER USING $AUDITPASSWORD"
   [ -n "$AUDITPASSWORD" ] && PASSWORDPARAMETER="-x -x"
   rundb2 "connect to $AUDITDATABASE $CREDENTIALS" $PASSWORDPARAMETER
}

numberoflines() {
  wc --line $1 | cut -d ' ' -f 1
}
