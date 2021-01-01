
source $(dirname $0)/config/env.rc

mkdir -p $LOGDIR

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

rundb2() {
   local -r command="$1"
   local -r X=$2
   log "$command"
   eval db2 $X "\"$command\"" >$TMPFILE
   local -r RES=$?
   logfile $TMPFILE 
   [ $RES -ne 0 ] && log "$RES db2 exit code non-zero. Will continue if not fatal"
   [ $RES -le 4 ] || logfatal "Execution failed. db2 exit code $RES"
}