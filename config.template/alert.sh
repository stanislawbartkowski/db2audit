#!/bin/bash

source $(dirname $0)/common.sh


TOPIC="$1"
CONTENTFILE="$2"

echo "ALERT: $TOPIC" >>$ALERTFILE
cat $CONTENTFILE >>$ALERTFILE
echo "=============================" >>$ALERTFILE

