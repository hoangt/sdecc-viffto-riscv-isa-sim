#!/bin/bash
#
# Author: Mark Gottscho
# mgottscho@ucla.edu

ARGC=$# # Get number of arguments excluding arg0 (the script itself). Check for help message condition.
if [[ "$ARGC" != 0 ]]; then # Bad number of arguments. 
	echo "Author: Mark Gottscho"
	echo "mgottscho@ucla.edu"
	echo ""
	echo "USAGE: ./submit_jobs.sh"
	exit
fi

########################## FEEL FREE TO CHANGE THESE OPTIONS ##################################
#SPEC_BENCHMARKS="400.perlbench 401.bzip2 403.gcc 410.bwaves 416.gamess 429.mcf 433.milc 434.zeusmp 435.gromacs 436.cactusADM 437.leslie3d 444.namd 445.gobmk 447.dealII 450.soplex 453.povray 454.calculix 456.hmmer 458.sjeng 459.GemsFDTD 462.libquantum 464.h264ref 465.tonto 470.lbm 471.omnetpp 473.astar 481.wrf 482.sphinx3 483.xalancbmk 998.specrand 999.specrand" # All benchmarks
SPEC_BENCHMARKS="416.gamess 429.mcf 433.milc 434.zeusmp 435.gromacs 436.cactusADM 437.leslie3d 445.gobmk 447.dealII 454.cactusADM 458.sjeng 465.tonto 481.wrf 482.sphinx3 483.xalancbmk" # Benchmarks with runtime problems as of 8/22/2016

# qsub options used:
# -V: export environment variables from this calling script to each job
# -N: name the job. I made these so that each job will be uniquely identified by its benchmark running as well as the output file string ID
# -l: resource allocation flags for maximum time requested as well as maximum memory requested.
# -M: cluster username(s) to email with updates on job status
# -m: mailing rules for job status. b = begin, e = end, a = abort, s = suspended, n = never
MAX_TIME_PER_RUN=335:00:00 	# Maximum time of each script that will be invoked, HH:MM:SS. If this is exceeded, job will be killed.
MAX_MEM_PER_RUN=1536M 		# Maximum memory needed per script that will be invoked. If this is exceeded, job will be killed.
MAILING_LIST=mgottsch 		# List of users to email with status updates, separated by commas
OUTPUT_DIR=/u/home/m/mgottsch/project-eedept/swd_ecc_output/rv64g/spike # Hoffman2
###############################################################################################


# Submit all the SPEC CPU2006 benchmarks
echo "Submitting jobs..."
echo ""
for SPEC_BENCHMARK in $SPEC_BENCHMARKS; do
	echo "$SPEC_BENCHMARK..."
	JOB_NAME="spike_${SPEC_BENCHMARK}"
    JOB_STDOUT=$OUTPUT_DIR/${SPEC_BENCHMARK}.stdout
    JOB_STDERR=$OUTPUT_DIR/${SPEC_BENCHMARK}.stderr
	qsub -V -N $JOB_NAME -l h_data=$MAX_MEM_PER_RUN,time=$MAX_TIME_PER_RUN,highp -M $MAILING_LIST -o $JOB_STDOUT -e $JOB_STDERR -m as run_spike_speccpu2006_benchmark.sh $SPEC_BENCHMARK
done

echo "Done submitting jobs."
echo "Use qstat to track job status and qdel to kill jobs."
