#!/bin/bash

source $(dirname $0)/common.sh

#=== FUNCTION ================================================================
#        NAME: maxtimestamp
# DESCRIPTION: Get maximum TIMESTAMP for audit table: EXECUTE, VALIDATE etc
# PARAMETER 1: The table name
#     RETURNS: as variable MTIMESTAMP, the max TIMESTAMP or - if does not exist
#===============================================================================
maxtimestamp() {
    local -r ATABLE=$1
    rundb2 "SELECT MAX(TIMESTAMP) FROM $ATABLE" -x
    # the result of SELECT commanmd is saved in $TMPFILE
    # sed - remove space and cut, get first and the only value
    MTIMESTAMP=$(cat $TMPFILE | xargs | cut -d ' ' -f 1)
}

#=== FUNCTION ================================================================
#        NAME: calcall
# DESCRIPTION: Calculate the max timestamp for all tables in ALLTABLES variable
#  PARAMETERS: no parameters
#      RESULT: The result is stored in $MAXTIMESTAMPFILE file as list of lines:
#              /table name/ /timestamp/
#              If the max TIMESTAMP for a given table does not exist, is not added $MAXTIMESTAMPFILE
#===============================================================================
calcall() {
    TMPFILE=`mktemp`
    rm -f $MAXTIMESTAMPFILE
    touch $MAXTIMESTAMPFILE
    conntoaudit
    for table in $ALLTABLES ; do
      maxtimestamp $table
      [ $MTIMESTAMP != '-' ] && echo "$table $MTIMESTAMP" >>$MAXTIMESTAMPFILE
    done
    rundb2 terminate   
}

#=== FUNCTION ======================================================================================
#        NAME: getmaxtimestamp
# DESCRIPTION: Get the stored max timestamp for a given table
# PARAMETER 1: the table name
#     RETURNS: Is returned as echo. If max timestamp does not exist, "1970-00-00" value is returned
#===================================================================================================
getmaxtimestamp() {
  local -r ATABLE=$1
  # select second value from line
  local -r tstamp=$(grep $ATABLE $MAXTIMESTAMPFILE | xargs | cut -d ' ' -f 2)
  [ -z $tstamp ] && echo "1970-00-00"
  [ ! -z $tstamp ] && echo $tstamp
}

setmaxvariables() {
    for var in $ALLTABLES ; do
      local varname=${var}_MAXTM
      local TM=$(getmaxtimestamp $var)
      log "$varname=$TM"
      eval "$varname=$TM"
    done
}


# === Used for testing only ==========
testcalc() {
  TMPFILE=`mktemp`
  conntoaudit
  maxtimestamp EXECUTE
  rundb2 terminate   
  echo $MTIMESTAMP
}

test() {
#  testcalc
  calcall
#  TM=$(getmaxtimestamp OBJMAINT)
#  echo $TM

#  setmaxvariables
#  echo $VALIDATE_MAXTM
}

# test