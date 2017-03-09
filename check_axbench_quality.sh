#!/bin/bash
#
# Author: Mark Gottscho
# mgottscho@ucla.edu

ARGC=$# # Get number of arguments excluding arg0 (the script itself). Check for help message condition.
if [[ "$ARGC" != 4 ]]; then # Bad number of arguments. 
	echo "Author: Mark Gottscho"
	echo "mgottscho@ucla.edu"
	echo ""
	echo "USAGE: ./check_axbench_quality.sh <AXBENCH_EN> <BENCHMARK> <GOLDEN> <TEST_DIR>"
	exit
fi

AXBENCH_EN=$1
BENCHMARK=$2
GOLDEN=$3
TEST_DIR=$4

################## SYSTEM-SPECIFIC VARIABLES: MODIFY ACCORDINGLY #######
AXBENCH_DIR=$MWG_GIT_PATH/eccgrp-axbench
########################################################################

if [[ "$AXBENCH_EN" == "yes" ]]; then
    QOS_SCRIPT=$AXBENCH_DIR/applications/$BENCHMARK/scripts/qos.py
    SAMPLES_DATA=`ls $TEST_DIR | grep -e "${BENCHMARK}\\.[0-9]*\\.data"`
fi
ORIG_DIR=$PWD
cd $TEST_DIR
SEQNUMS=`ls *stdout | sed -r 's/[a-z0-9]*\\.([0-9]*)\\.stdout/\1/'`
cd $ORIG_DIR

for SEQNUM in $SEQNUMS
do
    echo "Sample $SEQNUM..."
    SAMPLE_DATA=${BENCHMARK}.$SEQNUM.data
    SAMPLE_STDOUT=${BENCHMARK}.$SEQNUM.stdout
    SAMPLE_QOS=${BENCHMARK}.$SEQNUM.qos
    PANICKED=`grep -l "FAILED DUE RECOVERY" $TEST_DIR/$SAMPLE_STDOUT`
    if [[ "$PANICKED" == "$TEST_DIR/$SAMPLE_STDOUT" ]]; then
        echo "$SEQNUM PANICKED" > $TEST_DIR/$SAMPLE_QOS
    else
        MCE=`grep -l "MCE" $TEST_DIR/$SAMPLE_STDOUT`
        if [[ "$MCE" == "$TEST_DIR/$SAMPLE_STDOUT" ]]; then
            CRASHED=`grep -l "PANIC" $TEST_DIR/$SAMPLE_STDOUT`
            if [[ "$CRASHED" == "$TEST_DIR/$SAMPLE_STDOUT" ]]; then
                echo "$SEQNUM CRASHED (MCE)" > $TEST_DIR/$SAMPLE_QOS
            else 
                RECOVERED=`grep -l "SUCCESS" $TEST_DIR/$SAMPLE_STDOUT`
                if [[ "$RECOVERED" == "$TEST_DIR/$SAMPLE_STDOUT" ]]; then
                    if [[ "$AXBENCH_EN" == "yes" ]]; then
                        ERROR_RAW=`python $QOS_SCRIPT $GOLDEN ${TEST_DIR}/${SAMPLE_DATA}`
                    else
                        ERROR_RAW="N/A"
                    fi
                    ERROR=`echo "$ERROR_RAW" | sed -r 's/\*\*\* Error: (-?[0-9]\\.[0-9]*)/\1/'`
                    ERROR="$SEQNUM $ERROR (MCE)"
                    echo $ERROR > $TEST_DIR/$SAMPLE_QOS
                else
                    echo "$SEQNUM HANG (MCE)" > $TEST_DIR/$SAMPLE_QOS
                    echo "$SEQNUM seems to have hung after MCE"
                fi
            fi
        else
            CRASHED=`grep -l "PANIC" $TEST_DIR/$SAMPLE_STDOUT`
            if [[ "$CRASHED" == "$TEST_DIR/$SAMPLE_STDOUT" ]]; then
                echo "$SEQNUM RECOVERY BUG A" > $TEST_DIR/$SAMPLE_QOS
                echo "$SEQNUM had recovery bug A: crash without MCE"
            else 
                CORRECT=`grep -l "CORRECT" $TEST_DIR/$SAMPLE_STDOUT`
                if [[ "$CORRECT" == "$TEST_DIR/$SAMPLE_STDOUT" ]]; then
                    RECOVERED=`grep -l "SUCCESS" $TEST_DIR/$SAMPLE_STDOUT`
                    if [[ "$RECOVERED" == "$TEST_DIR/$SAMPLE_STDOUT" ]]; then
                        if [[ "$AXBENCH_EN" == "yes" ]]; then
                            ERROR_RAW=`python $QOS_SCRIPT $GOLDEN ${TEST_DIR}/${SAMPLE_DATA}`
                        else
                            ERROR_RAW="N/A"
                        fi
                        ERROR=`echo "$ERROR_RAW" | sed -r 's/\*\*\* Error: (-?[0-9]\\.[0-9]*)/\1/'`
                        ERROR="$SEQNUM $ERROR (CORRECT)"
                        echo $ERROR > $TEST_DIR/$SAMPLE_QOS
                    else
                        echo "$SEQNUM RECOVERY BUG B" > $TEST_DIR/$SAMPLE_QOS
                        echo "$SEQNUM had recovery bug B: seems to have hung even though no MCE, no crash, and CORRECT"
                    fi
                else
                    echo "$SEQNUM HANG (mystery)" > $TEST_DIR/$SAMPLE_QOS
                    echo "$SEQNUM seems to have hung but no MCE observed"
                fi
            fi
        fi
    fi
done

cat $TEST_DIR/*qos | grep "PANICKED" > $TEST_DIR/panics.txt
cat $TEST_DIR/*qos | grep -e "([A-Z]*)" > $TEST_DIR/recovered.txt

cat $TEST_DIR/*qos | grep -e "[0-9]\\.[0-9]* (CORRECT)" > $TEST_DIR/correct.txt
cat $TEST_DIR/correct.txt | grep -e "0\\.00000000 (CORRECT)" > $TEST_DIR/recovered_correct.txt
cat $TEST_DIR/correct.txt | grep -v -e "0\\.00000000 (CORRECT)" > $TEST_DIR/recovered_correct_but_error.txt

cat $TEST_DIR/*qos | grep -e "(MCE)" > $TEST_DIR/mce.txt
cat $TEST_DIR/mce.txt | grep -e "0\\.00000000 (MCE)" > $TEST_DIR/recovered_benign.txt
cat $TEST_DIR/mce.txt | grep "CRASHED" > $TEST_DIR/recovered_crashes.txt
cat $TEST_DIR/mce.txt | grep -v -e "CRASHED" | grep -v -e "0\\.00000000 (MCE)" > $TEST_DIR/recovered_sdc.txt
cat $TEST_DIR/mce.txt | grep -e "HANG (MCE)" > $TEST_DIR/recovered_hangs.txt

cat $TEST_DIR/*qos | grep "RECOVERY BUG A" > $TEST_DIR/recovered_bug_A.txt
cat $TEST_DIR/*qos | grep "RECOVERY BUG B" > $TEST_DIR/recovered_bug_B.txt
cat $TEST_DIR/*qos | grep "HANG (mystery)" > $TEST_DIR/mystery_hangs.txt
cat $TEST_DIR/*qos | grep "QOSFAIL" > $TEST_DIR/qos_fail.txt

echo "Panics (opt-out crash):        `cat $TEST_DIR/panics.txt | wc -l `"
echo "Recover (total):               `cat $TEST_DIR/recovered.txt | wc -l`"
echo "---> Recover (correct):        `cat $TEST_DIR/correct.txt | wc -l`"
echo "-------> Recover:              `cat $TEST_DIR/recovered_correct.txt | wc -l`"
echo "-------> Recover (FIXME error):`cat $TEST_DIR/recovered_correct_but_error.txt | wc -l`"
echo "---> Recover (MCE):            `cat $TEST_DIR/mce.txt | wc -l`"
echo "-------> Recover (benign):     `cat $TEST_DIR/recovered_benign.txt | wc -l`"
echo "-------> Recover (crashed):    `cat $TEST_DIR/recovered_crashes.txt | wc -l `"
echo "-------> Recover (SDC):        `cat $TEST_DIR/recovered_sdc.txt | wc -l`"
echo "-------> Recover (hang):       `cat $TEST_DIR/recovered_hangs.txt | wc -l`"
echo "Recovery bug A (FIXME):        `cat $TEST_DIR/recovered_bug_A.txt | wc -l`"
echo "Recovery bug B (FIXME):        `cat $TEST_DIR/recovered_bug_B.txt | wc -l`"
echo "Mystery hang:                  `cat $TEST_DIR/mystery_hangs.txt | wc -l`"
echo "QOS fail (FIXME):              `cat $TEST_DIR/qos_fail.txt | wc -l`"

