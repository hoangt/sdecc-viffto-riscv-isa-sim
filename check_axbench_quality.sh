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
    if [[ "$BENCHMARK" == "fft" || "$BENCHMARK" == "blackscholes" || "$BENCHMARK" == "jmeint" || "$BENCHMARK" == "inversek2j" ]]; then
        QOS_EXE=python
        QOS_SCRIPT_SUFFIX=py
        SAMPLES_SUFFIX=data
    else if [[ "$BENCHMARK" == "jpeg" ]]; then 
        QOS_EXE=bash
        QOS_SCRIPT_SUFFIX=sh
        SAMPLES_SUFFIX=jpg
    else if [[ "$BENCHMARK" == "kmeans" || "$BENCHMARK" == "sobel" ]]; then 
        QOS_EXE=bash
        QOS_SCRIPT_SUFFIX=sh
        SAMPLES_SUFFIX=rgb
    fi
    fi
    fi
fi
ORIG_DIR=$PWD
cd $TEST_DIR
SEQNUMS=`ls *stdout | sed -r 's/[a-z0-9]*\.([0-9]*)\.?[0-9]*?\.stdout/\1/'`
INPUTID=`ls *stdout | sed -r 's/[a-z0-9]*\.[0-9]*\.?([0-9]*)?\.stdout/\1/' | head -n1`
if [[ "$INPUTID" == "" ]]; then
    INPUTID_STR=""
else
    INPUTID_STR=".$INPUTID"
fi
cd $ORIG_DIR
QOS_SCRIPT="$QOS_EXE $AXBENCH_DIR/applications/$BENCHMARK/scripts/qos.${QOS_SCRIPT_SUFFIX}"
SAMPLES_DATA=`ls $TEST_DIR | grep -E "${BENCHMARK}\.[0-9]*\.?[0-9]*?\.${SAMPLES_SUFFIX}"`

for SEQNUM in $SEQNUMS
do
    echo "Sample $SEQNUM..."
    SAMPLE_DATA=${BENCHMARK}.${SEQNUM}${INPUTID_STR}.${SAMPLES_SUFFIX}
    SAMPLE_STDOUT=${BENCHMARK}.${SEQNUM}${INPUTID_STR}.stdout
    SAMPLE_QOS=${BENCHMARK}.${SEQNUM}${INPUTID_STR}.qos
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
                        ERROR_RAW=`$QOS_SCRIPT $GOLDEN ${TEST_DIR}/${SAMPLE_DATA}`
                    else
                        ERROR_RAW="N/A"
                    fi
                    ERROR=`echo "$ERROR_RAW" | sed -r 's/\*\*\* Error: (-?[0-9]*\\.[0-9]*)/\1/'`
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
                echo "$SEQNUM CRASH (mystery)" > $TEST_DIR/$SAMPLE_QOS
                echo "$SEQNUM seems to have crashed but no MCE observed"
            else 
                CORRECT=`grep -l "CORRECT" $TEST_DIR/$SAMPLE_STDOUT`
                if [[ "$CORRECT" == "$TEST_DIR/$SAMPLE_STDOUT" ]]; then
                    RECOVERED=`grep -l "SUCCESS" $TEST_DIR/$SAMPLE_STDOUT`
                    if [[ "$RECOVERED" == "$TEST_DIR/$SAMPLE_STDOUT" ]]; then
                        if [[ "$AXBENCH_EN" == "yes" ]]; then
                            ERROR_RAW=`$QOS_SCRIPT $GOLDEN ${TEST_DIR}/${SAMPLE_DATA}`
                        else
                            ERROR_RAW="N/A"
                        fi
                        ERROR=`echo "$ERROR_RAW" | sed -r 's/\*\*\* Error: (-?[0-9]*\\.[0-9]*)/\1/'`
                        ERROR="$SEQNUM $ERROR (CORRECT)"
                        echo $ERROR > $TEST_DIR/$SAMPLE_QOS
                    else
                        echo "$SEQNUM HANG (mystery)" > $TEST_DIR/$SAMPLE_QOS
                        echo "$SEQNUM seems to have hung but no MCE observed"
                    fi
                else
                    echo "$SEQNUM HANG (mystery)" > $TEST_DIR/$SAMPLE_QOS
                    echo "$SEQNUM seems to have hung but no MCE observed"
                fi
            fi
        fi
    fi
done

GOLDEN_ERROR_RAW=`$QOS_SCRIPT $GOLDEN $GOLDEN`
GOLDEN_ERROR=`echo "$GOLDEN_ERROR_RAW" | sed -r 's/\*\*\* Error: (-?[0-9]*\\.?[0-9]*)/\1/'`

cat $TEST_DIR/*qos | grep "PANICKED" > $TEST_DIR/panics.txt
cat $TEST_DIR/*qos | grep -e "([A-Z]*)" > $TEST_DIR/recovered.txt

cat $TEST_DIR/*qos | grep -e "[0-9]*\.[0-9]* (CORRECT)" > $TEST_DIR/correct.txt
cat $TEST_DIR/correct.txt | grep -e "$GOLDEN_ERROR (CORRECT)" | sed -r "s/$GOLDEN_ERROR/0\.00000000/g" > $TEST_DIR/recovered_correct.txt
cat $TEST_DIR/recovered_correct.txt | sed -r 's/ \(CORRECT\)//g' > $TEST_DIR/recovered_correct.csv
cat $TEST_DIR/correct.txt | grep -v -e "$GOLDEN_ERROR (CORRECT)" > $TEST_DIR/recovered_correct_but_error.txt

cat $TEST_DIR/*qos | grep -e "(MCE)" > $TEST_DIR/mce.txt
cat $TEST_DIR/mce.txt | grep -e "$GOLDEN_ERROR (MCE)" | sed -r "s/$GOLDEN_ERROR/0\.00000000/g" > $TEST_DIR/recovered_benign.txt
cat $TEST_DIR/recovered_benign.txt | sed -r 's/ \(MCE\)//g' > $TEST_DIR/recovered_benign.csv
cat $TEST_DIR/mce.txt | grep "CRASHED" > $TEST_DIR/recovered_crashes.txt
cat $TEST_DIR/mce.txt | grep -v -e "CRASHED" | grep -v -e "HANG (MCE)" | grep -v -e "$GOLDEN_ERROR (MCE)" > $TEST_DIR/recovered_sdc.txt
cat $TEST_DIR/recovered_sdc.txt | sed -r 's/ \(MCE\)//g' > $TEST_DIR/recovered_sdc.csv
cat $TEST_DIR/mce.txt | grep -e "HANG (MCE)" > $TEST_DIR/recovered_hangs.txt

cat $TEST_DIR/*qos | grep "CRASH (mystery)" > $TEST_DIR/mystery_crashes.txt
cat $TEST_DIR/*qos | grep "HANG (mystery)" > $TEST_DIR/mystery_hangs.txt
cat $TEST_DIR/*qos | grep "QOSFAIL" > $TEST_DIR/qos_fail.txt

echo "Golden error:                  $GOLDEN_ERROR" | tee $TEST_DIR/summary.txt
echo "Panics (opt-out crash):        `cat $TEST_DIR/panics.txt | wc -l `" | tee -a $TEST_DIR/summary.txt
echo "Recover (total):               `cat $TEST_DIR/recovered.txt | wc -l`" | tee -a $TEST_DIR/summary.txt
echo "---> Recover (correct):        `cat $TEST_DIR/correct.txt | wc -l`" | tee -a $TEST_DIR/summary.txt
echo "-------> Recover:              `cat $TEST_DIR/recovered_correct.txt | wc -l`" | tee -a $TEST_DIR/summary.txt
echo "-------> Recover (FIXME error):`cat $TEST_DIR/recovered_correct_but_error.txt | wc -l`" | tee -a $TEST_DIR/summary.txt
echo "---> Recover (MCE):            `cat $TEST_DIR/mce.txt | wc -l`" | tee -a $TEST_DIR/summary.txt
echo "-------> Recover (benign):     `cat $TEST_DIR/recovered_benign.txt | wc -l`" | tee -a $TEST_DIR/summary.txt
echo "-------> Recover (crashed):    `cat $TEST_DIR/recovered_crashes.txt | wc -l `" | tee -a $TEST_DIR/summary.txt
echo "-------> Recover (SDC):        `cat $TEST_DIR/recovered_sdc.txt | wc -l`" | tee -a $TEST_DIR/summary.txt
echo "-------> Recover (hang):       `cat $TEST_DIR/recovered_hangs.txt | wc -l`" | tee -a $TEST_DIR/summary.txt
echo "Mystery hangs:                 `cat $TEST_DIR/mystery_hangs.txt | wc -l`" | tee -a $TEST_DIR/summary.txt
echo "Mystery crashes:               `cat $TEST_DIR/mystery_crashes.txt | wc -l`" | tee -a $TEST_DIR/summary.txt
echo "QOS fail (FIXME):              `cat $TEST_DIR/qos_fail.txt | wc -l`" | tee -a $TEST_DIR/summary.txt
