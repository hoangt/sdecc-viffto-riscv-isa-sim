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
SAMPLES_DATA=`ls $TEST_DIR | grep -e "${AXBENCH_BENCHMARK}\\.[0-9]*\\.data"`
SEQNUMS=`echo "$SAMPLES_DATA" | sed -r 's/[a-z0-9]*\\.([0-9]*)\\.data/\1/'`

for SEQNUM in $SEQNUMS
do
    echo "Sample $SEQNUM..."
    SAMPLE_DATA=${AXBENCH_BENCHMARK}.$SEQNUM.data
    SAMPLE_STDOUT=${AXBENCH_BENCHMARK}.$SEQNUM.stdout
    SAMPLE_QOS=${AXBENCH_BENCHMARK}.$SEQNUM.qos
    PANICKED=`grep -l "FAILED DUE RECOVERY" $TEST_DIR/$SAMPLE_STDOUT`
    if [[ "$PANICKED" == "$TEST_DIR/$SAMPLE_STDOUT" ]]; then
        echo "PANICKED" > $TEST_DIR/$SAMPLE_QOS
    else
        CRASHED=`grep -l "PANIC" $TEST_DIR/$SAMPLE_STDOUT`
        if [[ "$CRASHED" == "$TEST_DIR/$SAMPLE_STDOUT" ]]; then
            echo "CRASHED" > $TEST_DIR/$SAMPLE_QOS
        else 
            SUCCESS=`grep -l "SUCCESS" $TEST_DIR/$SAMPLE_STDOUT`
            if [[ "$SUCCESS" == "$TEST_DIR/$SAMPLE_STDOUT" ]]; then
                ERROR_RAW=`python $QOS_SCRIPT $GOLDEN ${TEST_DIR}/${SAMPLE_DATA}`
                ERROR=`echo "$ERROR_RAW" | sed -r 's/\*\*\* Error: (-?[0-9]\\.[0-9]*)/\1/'`
                echo $ERROR > $TEST_DIR/$SAMPLE_QOS
            else
                echo "QOSFAIL" > $TEST_DIR/$SAMPLE_QOS
                echo "$SEQNUM had QoS fail"
            fi
        fi
    fi
done

cat $TEST_DIR/*qos | grep "PANICKED" | wc -l > $TEST_DIR/panics.txt
cat $TEST_DIR/*qos | grep "CRASHED" | wc -l > $TEST_DIR/crashes.txt
cat $TEST_DIR/*qos | grep -e "[0-9]\\.[0-9]*" > $TEST_DIR/success.txt
cat $TEST_DIR/*qos | grep -e "0\\.00000000" | wc -l > $TEST_DIR/success_no_error.txt
cat $TEST_DIR/*qos | grep "QOSFAIL" > $TEST_DIR/qos_fail.txt
echo "Panics:   `cat $TEST_DIR/panics.txt`"
echo "Crashes:  `cat $TEST_DIR/crashes.txt`"
echo "Success:  `cat $TEST_DIR/success.txt | wc -l`"
echo "No error: `cat $TEST_DIR/success_no_error.txt`"
echo "QOS fail: `cat $TEST_DIR/qos_fail.txt | wc -l`"

