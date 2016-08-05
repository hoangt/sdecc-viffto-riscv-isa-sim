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
ISA=rv64g    # Set the target ISA; benchmarks must be disassembled for this as well
SPEC_BENCHMARKS="bzip2 gobmk h264ref hmmer lbm libquantum mcf milc namd omnetpp perlbench povray sjeng soplex specrand998 specrand999"		# String of SPEC CPU2006 benchmark names to run, delimited by spaces.

# qsub options used:
# -V: export environment variables from this calling script to each job
# -N: name the job. I made these so that each job will be uniquely identified by its benchmark running as well as the output file string ID
# -l: resource allocation flags for maximum time requested as well as maximum memory requested.
# -M: cluster username(s) to email with updates on job status
# -m: mailing rules for job status. b = begin, e = end, a = abort
MAX_TIME_PER_RUN=335:00:00 	# Maximum time of each script that will be invoked, HH:MM:SS. If this is exceeded, job will be killed.
MAX_MEM_PER_RUN=1G 		# Maximum memory needed per script that will be invoked. If this is exceeded, job will be killed.
MAILING_LIST=mgottsch 		# List of users to email with status updates, separated by commas
###############################################################################################


# Submit all the SPEC CPU2006 benchmarks
echo "Submitting jobs..."
echo ""
for SPEC_BENCHMARK in $SPEC_BENCHMARKS; do
	echo "$SPEC_BENCHMARK..."
	JOB_NAME="spike_memdatatrace_${ISA}_${SPEC_BENCHMARK}"
    INPUT_FILE="$INPUT_DIRECTORY/${ISA}-${SPEC_BENCHMARK}-disassembly-text-section-inst.txt"
    OUTPUT_FILE="$OUTPUT_DIRECTORY/${ISA}-${SPEC_BENCHMARK}-inst-heuristic-recovery.mat"
	qsub -V -N $JOB_NAME -l h_data=$MAX_MEM_PER_RUN,time=$MAX_TIME_PER_RUN,highp -M $MAILING_LIST run_spike_speccpu2006_benchmark.sh $SPEC_BENCHMARK
done

echo "Done submitting jobs."
echo "Use qstat to track job status and qdel to kill jobs."
