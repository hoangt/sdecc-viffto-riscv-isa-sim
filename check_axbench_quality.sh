#!/bin/bash
#
# Author: Mark Gottscho
# mgottscho@ucla.edu

ARGC=$# # Get number of arguments excluding arg0 (the script itself). Check for help message condition.
if [[ "$ARGC" != 3 ]]; then # Bad number of arguments. 
	echo "Author: Mark Gottscho"
	echo "mgottscho@ucla.edu"
	echo ""
	echo "USAGE: ./check_axbench_quality.sh <AXBENCH_BENCHMARK> <GOLDEN> <TEST_DIR>"
	exit
fi

AXBENCH_BENCHMARK=$1
GOLDEN=$2
TEST_DIR=$3

################## SYSTEM-SPECIFIC VARIABLES: MODIFY ACCORDINGLY #######
AXBENCH_DIR=$MWG_GIT_PATH/eccgrp-axbench
########################################################################

QOS_SCRIPT=$AXBENCH_DIR/applications/$AXBENCH_BENCHMARK/scripts/qos.py
SAMPLES_DATA=`ls $TEST_DIR | grep -E "${AXBENCH_BENCHMARK}\.[0-9]*\.data"`
SEQNUMS=`echo "$TEST_DIR/$SAMPLES_DATA" | sed -r 's/[a-z0-9]*\.([0-9]*)\.data/\1/'`

for SEQNUM in $SEQNUMS
do
    echo "Sample $SEQNUM..."
    SAMPLE_DATA=${AXBENCH_BENCHMARK}.$SEQNUM.data
    SAMPLE_STDOUT=${AXBENCH_BENCHMARK}.$SEQNUM.stdout
    SAMPLE_QOS=${AXBENCH_BENCHMARK}.$SEQNUM.qos
    #grep -q "------ Success ------" $TEST_DIR/$SAMPLE_STDOUT > /dev/null
    grep -q "Done" $TEST_DIR/$SAMPLE_STDOUT > /dev/null
    if [[ $? -eq 0 ]]; then
        python $QOS_SCRIPT $GOLDEN $TEST_DIR/$SAMPLE_DATA > $TEST_DIR/$SAMPLE_QOS
    else
        echo "RUN FAILED" > $TEST_DIR/$SAMPLE_QOS
    fi
done

