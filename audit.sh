source $(dirname $0)/common.sh

audit() {
    rundb2 "connect to $AUDITDATABASE"



    rundb2 terminate
}