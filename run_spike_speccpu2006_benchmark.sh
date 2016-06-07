#!/bin/bash
#
# Author: Mark Gottscho
# mgottscho@ucla.edu

################## DIRECTORY VARIABLES: MODIFY ACCORDINGLY #######
SPEC_DIR=~/Git/spec-cpu2006-nanocad-prep		# Install location of your SPEC2006 benchmarks
##################################################################

ARGC=$# # Get number of arguments excluding arg0 (the script itself). Check for help message condition.
if [[ "$ARGC" != 1 ]]; then # Bad number of arguments. 
	echo "Author: Mark Gottscho"
	echo "mgottscho@ucla.edu"
	echo ""
	echo "This script runs a single gem5 simulation of a single SPEC CPU2006 benchmark on Spike for RISC-V."
	echo ""
	echo "USAGE: run_spike_speccpu2006_benchmark.sh <BENCHMARK>"
	echo "EXAMPLE: ./run_spike_speccpu2006_benchmark.sh bzip2"
	echo ""
	echo "A single --help help or -h argument will bring this message back."
	exit
fi

# Get command line input. We will need to check these.
BENCHMARK=$1					# Benchmark name, e.g. bzip2
OUTPUT_DIR=~

######################### BENCHMARK CODENAMES ####################
PERLBENCH_CODE=400.perlbench
BZIP2_CODE=401.bzip2
GCC_CODE=403.gcc
BWAVES_CODE=410.bwaves
GAMESS_CODE=416.gamess
MCF_CODE=429.mcf
MILC_CODE=433.milc
ZEUSMP_CODE=434.zeusmp
GROMACS_CODE=435.gromacs
CACTUSADM_CODE=436.cactusADM
LESLIE3D_CODE=437.leslie3d
NAMD_CODE=444.namd
GOBMK_CODE=445.gobmk
DEALII_CODE=447.dealII
SOPLEX_CODE=450.soplex
POVRAY_CODE=453.povray
CALCULIX_CODE=454.calculix
HMMER_CODE=456.hmmer
SJENG_CODE=458.sjeng
GEMSFDTD_CODE=459.GemsFDTD
LIBQUANTUM_CODE=462.libquantum
H264REF_CODE=464.h264ref
TONTO_CODE=465.tonto
LBM_CODE=470.lbm
OMNETPP_CODE=471.omnetpp
ASTAR_CODE=473.astar
WRF_CODE=481.wrf
SPHINX3_CODE=482.sphinx3
XALANCBMK_CODE=483.xalancbmk
SPECRAND_INT_CODE=998.specrand
SPECRAND_FLOAT_CODE=999.specrand
##################################################################

######################### BENCHMARK INPUTS ## ####################
PERLBENCH_ARGS="-I./lib checkspam.pl 2500 5 25 11 150 1 1 1 1"
BZIP2_ARGS="input.source 280"
GCC_ARGS=
BWAVES_ARGS=
GAMESS_ARGS=
MCF_ARGS="inp.in"
MILC_ARGS=
ZEUSMP_ARGS=
GROMACS_ARGS=
CACTUSADM_ARGS=
LESLIE3D_ARGS=
NAMD_ARGS=
GOBMK_ARGS=
DEALII_ARGS=
SOPLEX_ARGS=
POVRAY_ARGS="SPEC-benchmark-ref.ini"
CALCULIX_ARGS=
HMMER_ARGS=
SJENG_ARGS=
GEMSFDTD_ARGS=
LIBQUANTUM_ARGS=
H264REF_ARGS="-d foreman_ref_encoder_baseline.cfg"
TONTO_ARGS=
LBM_ARGS=
OMNETPP_ARGS=
ASTAR_ARGS=
WRF_ARGS=
SPHINX3_ARGS=
XALANCBMK_ARGS=
SPECRAND_INT_ARGS=
SPECRAND_FLOAT_ARGS=
##################################################################

###############

# Check BENCHMARK input
#################### BENCHMARK CODE MAPPING ######################
BENCHMARK_CODE="none"

if [[ "$BENCHMARK" == "perlbench" ]]; then
	BENCHMARK_CODE=$PERLBENCH_CODE
	BENCHMARK_ARGS=$PERLBENCH_ARGS
fi
if [[ "$BENCHMARK" == "bzip2" ]]; then
	BENCHMARK_CODE=$BZIP2_CODE
	BENCHMARK_ARGS=$BZIP2_ARGS
fi
if [[ "$BENCHMARK" == "gcc" ]]; then
	BENCHMARK_CODE=$GCC_CODE
	BENCHMARK_ARGS=$GCC_ARGS
fi
if [[ "$BENCHMARK" == "bwaves" ]]; then
	BENCHMARK_CODE=$BWAVES_CODE
	BENCHMARK_ARGS=$BWAVES_ARGS
fi
if [[ "$BENCHMARK" == "gamess" ]]; then
	BENCHMARK_CODE=$GAMESS_CODE
	BENCHMARK_ARGS=$GAMESS_ARGS
fi
if [[ "$BENCHMARK" == "mcf" ]]; then
	BENCHMARK_CODE=$MCF_CODE
	BENCHMARK_ARGS=$MCF_ARGS
fi
if [[ "$BENCHMARK" == "milc" ]]; then
	BENCHMARK_CODE=$MILC_CODE
	BENCHMARK_ARGS=$MILC_ARGS
fi
if [[ "$BENCHMARK" == "zeusmp" ]]; then
	BENCHMARK_CODE=$ZEUSMP_CODE
	BENCHMARK_ARGS=$ZEUSMP_ARGS
fi
if [[ "$BENCHMARK" == "gromacs" ]]; then
	BENCHMARK_CODE=$GROMACS_CODE
	BENCHMARK_ARGS=$GROMACS_ARGS
fi
if [[ "$BENCHMARK" == "cactusADM" ]]; then
	BENCHMARK_CODE=$CACTUSADM_CODE
	BENCHMARK_ARGS=$CACTUSADM_ARGS
fi
if [[ "$BENCHMARK" == "leslie3d" ]]; then
	BENCHMARK_CODE=$LESLIE3D_CODE
	BENCHMARK_ARGS=$LESLIE3D_ARGS
fi
if [[ "$BENCHMARK" == "namd" ]]; then
	BENCHMARK_CODE=$NAMD_CODE
	BENCHMARK_ARGS=$NAMD_ARGS
fi
if [[ "$BENCHMARK" == "gobmk" ]]; then
	BENCHMARK_CODE=$GOBMK_CODE
	BENCHMARK_ARGS=$GOBMK_ARGS
fi
if [[ "$BENCHMARK" == "dealII" ]]; then # DOES NOT WORK
	BENCHMARK_CODE=$DEALII_CODE
	BENCHMARK_ARGS=$DEALII_ARGS
fi
if [[ "$BENCHMARK" == "soplex" ]]; then
	BENCHMARK_CODE=$SOPLEX_CODE
	BENCHMARK_ARGS=$SOPLEX_ARGS
fi
if [[ "$BENCHMARK" == "povray" ]]; then
	BENCHMARK_CODE=$POVRAY_CODE
	BENCHMARK_ARGS=$POVRAY_ARGS
fi
if [[ "$BENCHMARK" == "calculix" ]]; then
	BENCHMARK_CODE=$CALCULIX_CODE
	BENCHMARK_ARGS=$CALCULIX_ARGS
fi
if [[ "$BENCHMARK" == "hmmer" ]]; then
	BENCHMARK_CODE=$HMMER_CODE
	BENCHMARK_ARGS=$HMMER_ARGS
fi
if [[ "$BENCHMARK" == "sjeng" ]]; then
	BENCHMARK_CODE=$SJENG_CODE
	BENCHMARK_ARGS=$SJENG_ARGS
fi
if [[ "$BENCHMARK" == "GemsFDTD" ]]; then
	BENCHMARK_CODE=$GEMSFDTD_CODE
	BENCHMARK_ARGS=$GEMSFDTD_ARGS
fi
if [[ "$BENCHMARK" == "libquantum" ]]; then
	BENCHMARK_CODE=$LIBQUANTUM_CODE
	BENCHMARK_ARGS=$LIBQUANTUM_ARGS
fi
if [[ "$BENCHMARK" == "h264ref" ]]; then
	BENCHMARK_CODE=$H264REF_CODE
	BENCHMARK_ARGS=$H264REF_ARGS
fi
if [[ "$BENCHMARK" == "tonto" ]]; then
	BENCHMARK_CODE=$TONTO_CODE
	BENCHMARK_ARGS=$TONTO_ARGS
fi
if [[ "$BENCHMARK" == "lbm" ]]; then
	BENCHMARK_CODE=$LBM_CODE
	BENCHMARK_ARGS=$LBM_ARGS
fi
if [[ "$BENCHMARK" == "omnetpp" ]]; then
	BENCHMARK_CODE=$OMNETPP_CODE
	BENCHMARK_ARGS=$OMNETPP_ARGS
fi
if [[ "$BENCHMARK" == "astar" ]]; then
	BENCHMARK_CODE=$ASTAR_CODE
	BENCHMARK_ARGS=$ASTAR_ARGS
fi
if [[ "$BENCHMARK" == "wrf" ]]; then
	BENCHMARK_CODE=$WRF_CODE
	BENCHMARK_ARGS=$WRF_ARGS
fi
if [[ "$BENCHMARK" == "sphinx3" ]]; then
	BENCHMARK_CODE=$SPHINX3_CODE
	BENCHMARK_ARGS=$SPHINX3_ARGS
fi
if [[ "$BENCHMARK" == "xalancbmk" ]]; then # DOES NOT WORK
	BENCHMARK_CODE=$XALANCBMK_CODE
	BENCHMARK_ARGS=$XALANCBMK_ARGS
fi
if [[ "$BENCHMARK" == "specrand_i" ]]; then
	BENCHMARK_CODE=$SPECRAND_INT_CODE
	BENCHMARK_ARGS=$SPECRAND_INT_ARGS
fi
if [[ "$BENCHMARK" == "specrand_f" ]]; then
	BENCHMARK_CODE=$SPECRAND_FLOAT_CODE
	BENCHMARK_ARGS=$SPECRAND_FLOAT_ARGS
fi

# Sanity check
if [[ "$BENCHMARK_CODE" == "none" ]]; then
	echo "Input benchmark selection $BENCHMARK did not match any known SPEC CPU2006 benchmarks! Exiting."
	exit 1
fi
##################################################################

# Check OUTPUT_DIR existence
if [[ !(-d "$OUTPUT_DIR") ]]; then
	echo "Output directory $OUTPUT_DIR does not exist! Exiting."
	exit 1
fi

SPEC_CONFIG_SUFFIX=mwg-desktop-ubuntuvm-rv64g-priv-1.7-stable
RUN_DIR=$SPEC_DIR/benchspec/CPU2006/$BENCHMARK_CODE/run/run_base_ref_${SPEC_CONFIG_SUFFIX}.0000		# Run directory for the selected SPEC benchmark
SCRIPT_OUT=$OUTPUT_DIR/spike_runscript.log															# File log for this script's stdout henceforth

#################### LAUNCH SIMULATION ######################
echo ""
echo "Changing to SPEC benchmark runtime directory:	$RUN_DIR" | tee -a $SCRIPT_OUT
cd $RUN_DIR

echo "" | tee -a $SCRIPT_OUT
echo "" | tee -a $SCRIPT_OUT
echo "--------- Here goes nothing! Starting spike! ------------" | tee -a $SCRIPT_OUT
echo "" | tee -a $SCRIPT_OUT
echo "" | tee -a $SCRIPT_OUT

# Actually launch spike.
CMD="/home/markg/Git/eccgrp-riscv-isa-sim/build/spike -d --ic=1:1:64 --dc=1:1:64 --isa=RV64G -m1024 -p1 /opt/riscv-priv-1.7-stable/riscv64-unknown-elf/bin/pk ${BENCHMARK}_base.${SPEC_CONFIG_SUFFIX} $BENCHMARK_ARGS"
echo $CMD
$CMD

# Clean up
mv spike_mem_data_trace.txt $OUTPUT_DIR/spike_mem_data_trace_${BENCHMARK}.txt | tee -a $SCRIPT_OUT
echo "Done!" | tee -a $SCRIPT_OUT
