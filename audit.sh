#!/bin/bash

source $(dirname $0)/common.sh
source $(dirname $0)/calctimestamp.sh

audit() {
    local -r DATABASE=$1
    local -r db_rc=$(dirname $0)/config/db_${DATABASE}.rc
    log "Reading $db_rc"

    # queries should be set in db_rc
    unset QUERIES
    source ${db_rc}
    [ $? -eq 0 ] || logfatal "${db_rc} not read successfully"

    [ -n "$QUERIES" ] || logfatal "QUERIES variable not set in ${db_rc}"
    rundb2 "connect to $AUDITDATABASE"
    for q in $QUERIES; do 
        local q_rc=$(dirname $0)/config/queries/${q}.rc
        log "Reading $q_rc"

        # HEADER and QUERY should be set in q_rc
        unset HEADER
        unset QUERY
        source ${q_rc}
        [ $? -eq 0 ] || logfatal "${q_rc} not read successfully"

        [ -n "$HEADER" ] || logfatal "HEADER variable not set in ${q_rc}"
        [ -n "$QUERY" ] || logfatal "QUERY variable not set in ${q_rc}"

        # execute query
        rundb2 "$QUERY" -x
        NO=$(numberoflines $TMPFILE)
        if [ $NO -ne 0 ]; then 
            log "$HEADER"
            log "$NO audit violations detected. Raise a signal"
            $(dirname $0)/alert.sh "$HEADER" $TMPFILE
            [ $? -eq 0 ] || logfatal "$(dirname $0)/alert.sh exited with non zero code. Signal not raised"
        fi

    done  

    rundb2 terminate
}


runaudit() {
    setmaxvariables
    audit $1
}

run() {
   for DB in $DATABASES; do 
      runaudit $DB
   done
   calcall
}   

TMPFILE=`mktemp`
run
rm $TMPFILE
