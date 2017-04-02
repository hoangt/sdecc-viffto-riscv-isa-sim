#!/bin/bash
#
# Author: Mark Gottscho
# mgottscho@ucla.edu

ARGC=$# # Get number of arguments excluding arg0 (the script itself). Check for help message condition.
if [[ "$ARGC" != 3 ]]; then # Bad number of arguments. 
	echo "Author: Mark Gottscho"
	echo "mgottscho@ucla.edu"
	echo ""
	echo "USAGE: ./submit_jobs.sh <MODE> <FAULT_INJECTION_TARGET> <BENCHMARK_SUITE>"
	exit
fi

MODE=$1
FAULT_INJECTION_TARGET=$2
BENCHMARK_SUITE=$3
########################## FEEL FREE TO CHANGE THESE OPTIONS ##################################
SPEC_BENCHMARKS="400.perlbench 401.bzip2 403.gcc 410.bwaves 416.gamess 429.mcf 433.milc 434.zeusmp 435.gromacs 436.cactusADM 437.leslie3d 444.namd 445.gobmk 447.dealII 450.soplex 453.povray 454.calculix 456.hmmer 458.sjeng 459.GemsFDTD 462.libquantum 464.h264ref 465.tonto 470.lbm 471.omnetpp 473.astar 481.wrf 482.sphinx3 483.xalancbmk 998.specrand 999.specrand" # All benchmarks
#SPEC_BENCHMARKS="416.gamess 429.mcf 433.milc 434.zeusmp 437.leslie3d 445.gobmk 481.wrf 483.xalancbmk" # Benchmarks with runtime problems compiled for linux-gnu and running on top of pk as of 8/25/2016
AXBENCH_BENCHMARKS="blackscholes fft inversek2j jmeint jpeg kmeans sobel" # Complete suite
#AXBENCH_BENCHMARKS="blackscholes fft inversek2j jmeint jpeg sobel" # Complete suite
FAULTLINK_BENCHMARKS="blowfish dhrystone matmult_int sha whetstone" # Assorted mibench and other benchmarks


if [[ "$MWG_MACHINE_NAME" == "hoffman" ]]; then
    # qsub options used:
    # -V: export environment variables from this calling script to each job
    # -N: name the job. I made these so that each job will be uniquely identified by its benchmark running as well as the output file string ID
    # -l: resource allocation flags for maximum time requested as well as maximum memory requested.
    # -M: cluster username(s) to email with updates on job status
    # -m: mailing rules for job status. b = begin, e = end, a = abort, s = suspended, n = never
    MAX_TIME_PER_RUN=335:00:00 	# Maximum time of each script that will be invoked, HH:MM:SS. If this is exceeded, job will be killed.
    MAX_MEM_PER_RUN=1536M 		# Maximum memory needed per script that will be invoked. If this is exceeded, job will be killed.
    MAILING_LIST=mgottsch 		# List of users to email with status updates, separated by commas
fi

N=35
K=32
CODE_TYPE=ULEL_riscv
CACHELINE_SIZE=64
NUM_RUNS=1000
BATCH_SIZE=72
TIMEOUT=30 # in minutes

if [[ "$MODE" == "memdatatrace" ]]; then
    OUTPUT_DIR=$MWG_DATA_PATH/swd_ecc_data/rv64g/spike_output
else
if [[ "$MODE" == "faultinj_user" ]]; then
    OUTPUT_DIR=$MWG_DATA_PATH/swd_ecc_data/rv64g/${FAULT_INJECTION_TARGET}-recovery/online-dynamic-user/$CODE_TYPE/$N,$K/`date -I`
else
if [[ "$MODE" == "faultinj_sim" ]]; then
    OUTPUT_DIR=$MWG_DATA_PATH/swd_ecc_data/rv64g/${FAULT_INJECTION_TARGET}-recovery/online-dynamic-sim/$CODE_TYPE/$N,$K/`date -I`
else
if [[ "$MODE" == "default" ]]; then
    OUTPUT_DIR=$MWG_DATA_PATH/swd_ecc_data/rv64g/golden
fi
fi
fi
fi

###############################################################################################

if [[ "$BENCHMARK_SUITE" == "SPEC_CPU2006" ]]; then
    BENCHMARKS=$SPEC_BENCHMARKS
else
    if [[ "$BENCHMARK_SUITE" == "AXBENCH" ]]; then
        BENCHMARKS=$AXBENCH_BENCHMARKS
    else 
        if [[ "$BENCHMARK_SUITE" == "FAULTLINK" ]]; then
            BENCHMARKS=$FAULTLINK_BENCHMARKS
        else
            BENCHMARKS=$BENCHMARK_SUITE # Command line list
        fi
    fi
fi

# Submit all the benchmarks in the specified suite
echo "Submitting jobs..."
echo ""
for BENCHMARK in $BENCHMARKS; do
	echo "$BENCHMARK..."
    OUTPUT_DIR_BENCHMARK=$OUTPUT_DIR/$BENCHMARK
    mkdir -p $OUTPUT_DIR_BENCHMARK

    for(( SEQNUM=1; SEQNUM<=$NUM_RUNS; SEQNUM++ )); do
        if [[ "$(($SEQNUM % 10))" -eq "0" ]]; then
            killall -9 --older-than ${TIMEOUT}m --user `whoami` run_spike_benchmark.sh > /dev/null 2>&1
            killall -9 --older-than ${TIMEOUT}m --user `whoami` spike > /dev/null 2>&1
            killall -9 --older-than ${TIMEOUT}m --user `whoami` candidate_messages_standalone > /dev/null 2>&1
            killall -9 --older-than ${TIMEOUT}m --user `whoami` data_recovery_standalone > /dev/null 2>&1
            killall -9 --older-than ${TIMEOUT}m --user `whoami` inst_recovery_standalone > /dev/null 2>&1
        fi

        let CURRENTLY_RUNNING=`ps aux | grep "run_spike_benchmark.sh" | wc -l`-1
        let SINCE=0
        while [[ "$CURRENTLY_RUNNING" -gt "$(expr $BATCH_SIZE-1)" ]]; do
            let CURRENTLY_RUNNING=`ps aux | grep "run_spike_benchmark.sh" | wc -l`-1
            echo "Sleeping... Have $CURRENTLY_RUNNING jobs, waiting until below $BATCH_SIZE jobs. $SINCE sec since last job started."
            sleep 2;
            let SINCE=$SINCE+2

            if [[ "$SINCE" -gt "$(expr 30)" ]]; then
                killall -9 --older-than ${TIMEOUT}m --user `whoami` run_spike_benchmark.sh > /dev/null 2>&1
                killall -9 --older-than ${TIMEOUT}m --user `whoami` spike > /dev/null 2>&1
                killall -9 --older-than ${TIMEOUT}m --user `whoami` candidate_messages_standalone > /dev/null 2>&1
                killall -9 --older-than ${TIMEOUT}m --user `whoami` data_recovery_standalone > /dev/null 2>&1
                killall -9 --older-than ${TIMEOUT}m --user `whoami` inst_recovery_standalone > /dev/null 2>&1
            fi
        done
        echo "Run #$SEQNUM..."
        JOB_STDOUT=$OUTPUT_DIR_BENCHMARK/${BENCHMARK}.$SEQNUM.stdout
        JOB_STDERR=$OUTPUT_DIR_BENCHMARK/${BENCHMARK}.$SEQNUM.stderr

        if [[ "$MWG_MACHINE_NAME" == "hoffman" ]]; then
            JOB_NAME="spike_${BENCHMARK}_${MODE}_${FAULT_INJECTION_TARGET}"
            qsub -V -N $JOB_NAME -l h_data=$MAX_MEM_PER_RUN,time=$MAX_TIME_PER_RUN,highp -M $MAILING_LIST -o $JOB_STDOUT -e $JOB_STDERR -m as run_spike_benchmark.sh $MODE $FAULT_INJECTION_TARGET $N $K $CODE_TYPE $CACHELINE_SIZE $SEQNUM $OUTPUT_DIR_BENCHMARK $BENCHMARK
        else
            ./run_spike_benchmark.sh $MODE $FAULT_INJECTION_TARGET $N $K $CODE_TYPE $CACHELINE_SIZE $SEQNUM $OUTPUT_DIR_BENCHMARK $BENCHMARK > $JOB_STDOUT 2> $JOB_STDERR &
        fi
    done
done

if [[ "$MWG_MACHINE_NAME" == "hoffman" ]]; then
    echo "Done submitting jobs."
    echo "Use qstat to track job status and qdel to kill jobs."
fi
