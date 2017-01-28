#!/bin/bash
#
# Author: Mark Gottscho
# mgottscho@ucla.edu

################## SYSTEM-SPECIFIC VARIABLES: MODIFY ACCORDINGLY #######
SPEC_DIR=$MWG_GIT_PATH/spec_cpu2006_install
SPIKE_DIR=$MWG_GIT_PATH/eccgrp-riscv-isa-sim/build
OUTPUT_DIR=$MWG_DATA_PATH/swd_ecc_data/rv64g/spike_fpunit_test
##################################################################

mkdir -p $OUTPUT_DIR

ARGC=$# # Get number of arguments excluding arg0 (the script itself). Check for help message condition.
if [[ "$ARGC" < 2 ]]; then # Bad number of arguments. 
	echo "Author: Mark Gottscho"
	echo "mgottscho@ucla.edu"
	echo ""
	echo "This script runs a single RISC-V Spike simulation of a single program (compiled for embedded Newlib, not Linux)."
	echo ""
	echo "USAGE: run_spike_benchmark.sh <MODE> <BENCHMARK> <OPTIONAL_BENCHMARK_ARGS>"
	echo "EXAMPLE: ./run_spike_speccpu2006_benchmark.sh memdatatrace 401.bzip2"
	echo ""
	echo "A single --help help or -h argument will bring this message back."
	exit
fi

# Get command line input. We will need to check these.
MODE=$1                         # Spike mode, i.e. memdatatrace or faultinj
BENCHMARK=$2					# Benchmark name, e.g. bzip2
OPTIONAL_BENCHMARK_ARGS="${@:3}" # Remaining args, if any

SPEC_BENCH=1
RUN_DIR=$PWD

####################SPEC CPU2006 BENCHMARK CODENAMES ####################
PERLBENCH=400.perlbench
BZIP2=401.bzip2
GCC=403.gcc
BWAVES=410.bwaves
GAMESS=416.gamess
MCF=429.mcf
MILC=433.milc
ZEUSMP=434.zeusmp
GROMACS=435.gromacs
CACTUSADM=436.cactusADM
LESLIE3D=437.leslie3d
NAMD=444.namd
GOBMK=445.gobmk
DEALII=447.dealII
SOPLEX=450.soplex
POVRAY=453.povray
CALCULIX=454.calculix
HMMER=456.hmmer
SJENG=458.sjeng
GEMSFDTD=459.GemsFDTD
LIBQUANTUM=462.libquantum
H264REF=464.h264ref
TONTO=465.tonto
LBM=470.lbm
OMNETPP=471.omnetpp
ASTAR=473.astar
WRF=481.wrf
SPHINX3=482.sphinx3
XALANCBMK=483.xalancbmk
SPECRAND_INT=998.specrand
SPECRAND_FLOAT=999.specrand
##################################################################

######################### BENCHMARK INPUTS ## ####################
PERLBENCH_ARGS="-I./lib checkspam.pl 2500 5 25 11 150 1 1 1 1"
BZIP2_ARGS="input.source 280"
GCC_ARGS="166.i -o 166.s"
BWAVES_ARGS=""
GAMESS_ARGS="-i cytosine.2.config"
MCF_ARGS="inp.in"
MILC_ARGS="-i su3imp.in"
ZEUSMP_ARGS=""
GROMACS_ARGS="-silent -deffnm gromacs -nice 0"
CACTUSADM_ARGS="benchADM.par"
LESLIE3D_ARGS="<leslie3d.in"
NAMD_ARGS="--input namd.input --output namd.out --iterations 38"
GOBMK_ARGS="-i 13x13.tst --mode gtp"
DEALII_ARGS="8"
SOPLEX_ARGS="-m45000 pds-50.mps"
POVRAY_ARGS="SPEC-benchmark-ref.ini"
CALCULIX_ARGS="-i hyperviscoplastic"
HMMER_ARGS="nph3.hmm swiss41"
SJENG_ARGS="ref.txt"
GEMSFDTD_ARGS=""
LIBQUANTUM_ARGS="1397 8"
H264REF_ARGS="-d foreman_ref_encoder_baseline.cfg"
TONTO_ARGS=""
LBM_ARGS="3000 reference.dat 0 0 100_100_130_ldc.of"
OMNETPP_ARGS="omnetpp.ini"
ASTAR_ARGS="rivers.cfg"
WRF_ARGS=""
SPHINX3_ARGS="ctlfile . args.an4"
XALANCBMK_ARGS="-v test.xml xalanc.xsl"
SPECRAND_INT_ARGS="1255432124 234923"
SPECRAND_FLOAT_ARGS="1255432124 234923"
##################################################################

###############

# Check BENCHMARK input
#################### BENCHMARK CODE MAPPING ######################
if [[ "$BENCHMARK" == "$PERLBENCH" ]]; then
	BENCHMARK_ARGS=$PERLBENCH_ARGS
else
if [[ "$BENCHMARK" == "$BZIP2" ]]; then
	BENCHMARK_ARGS=$BZIP2_ARGS
else
if [[ "$BENCHMARK" == "$GCC" ]]; then
	BENCHMARK_ARGS=$GCC_ARGS
else
if [[ "$BENCHMARK" == "$BWAVES" ]]; then
	BENCHMARK_ARGS=$BWAVES_ARGS
else
if [[ "$BENCHMARK" == "$GAMESS" ]]; then
	BENCHMARK_ARGS=$GAMESS_ARGS
else
if [[ "$BENCHMARK" == "$MCF" ]]; then
	BENCHMARK_ARGS=$MCF_ARGS
else
if [[ "$BENCHMARK" == "$MILC" ]]; then
	BENCHMARK_ARGS=$MILC_ARGS
else
if [[ "$BENCHMARK" == "$ZEUSMP" ]]; then
	BENCHMARK_ARGS=$ZEUSMP_ARGS
else
if [[ "$BENCHMARK" == "$GROMACS" ]]; then
	BENCHMARK_ARGS=$GROMACS_ARGS
else
if [[ "$BENCHMARK" == "$CACTUSADM" ]]; then
	BENCHMARK_ARGS=$CACTUSADM_ARGS
else
if [[ "$BENCHMARK" == "$LESLIE3D" ]]; then
	BENCHMARK_ARGS=$LESLIE3D_ARGS
else
if [[ "$BENCHMARK" == "$NAMD" ]]; then
	BENCHMARK_ARGS=$NAMD_ARGS
else
if [[ "$BENCHMARK" == "$GOBMK" ]]; then
	BENCHMARK_ARGS=$GOBMK_ARGS
else
if [[ "$BENCHMARK" == "$DEALII" ]]; then
	BENCHMARK_ARGS=$DEALII_ARGS
else
if [[ "$BENCHMARK" == "$SOPLEX" ]]; then
	BENCHMARK_ARGS=$SOPLEX_ARGS
else
if [[ "$BENCHMARK" == "$POVRAY" ]]; then
	BENCHMARK_ARGS=$POVRAY_ARGS
else
if [[ "$BENCHMARK" == "$CALCULIX" ]]; then
	BENCHMARK_ARGS=$CALCULIX_ARGS
else
if [[ "$BENCHMARK" == "$HMMER" ]]; then
	BENCHMARK_ARGS=$HMMER_ARGS
else
if [[ "$BENCHMARK" == "$SJENG" ]]; then
	BENCHMARK_ARGS=$SJENG_ARGS
else
if [[ "$BENCHMARK" == "$GEMSFDTD" ]]; then
	BENCHMARK_ARGS=$GEMSFDTD_ARGS
else
if [[ "$BENCHMARK" == "$LIBQUANTUM" ]]; then
	BENCHMARK_ARGS=$LIBQUANTUM_ARGS
else
if [[ "$BENCHMARK" == "$H264REF" ]]; then
	BENCHMARK_ARGS=$H264REF_ARGS
else
if [[ "$BENCHMARK" == "$TONTO" ]]; then
	BENCHMARK_ARGS=$TONTO_ARGS
else
if [[ "$BENCHMARK" == "$LBM" ]]; then
	BENCHMARK_ARGS=$LBM_ARGS
else
if [[ "$BENCHMARK" == "$OMNETPP" ]]; then
	BENCHMARK_ARGS=$OMNETPP_ARGS
else
if [[ "$BENCHMARK" == "$ASTAR" ]]; then
	BENCHMARK_ARGS=$ASTAR_ARGS
else
if [[ "$BENCHMARK" == "$WRF" ]]; then
	BENCHMARK_ARGS=$WRF_ARGS
else
if [[ "$BENCHMARK" == "$SPHINX3" ]]; then
	BENCHMARK_ARGS=$SPHINX3_ARGS
else
if [[ "$BENCHMARK" == "$XALANCBMK" ]]; then 
	BENCHMARK_ARGS=$XALANCBMK_ARGS
else
if [[ "$BENCHMARK" == "$SPECRAND_INT" ]]; then
	BENCHMARK_ARGS=$SPECRAND_INT_ARGS
else
if [[ "$BENCHMARK" == "$SPECRAND_FLOAT" ]]; then
	BENCHMARK_ARGS=$SPECRAND_FLOAT_ARGS
else # Not a SPEC CPU2006 benchmark
    BENCHMARK_ARGS=$OPTIONAL_BENCHMARK_ARGS
    SPEC_BENCH=0
fi
fi
fi
fi
fi
fi
fi
fi
fi
fi
fi
fi
fi
fi
fi
fi
fi
fi
fi
fi
fi
fi
fi
fi
fi
fi
fi
fi
fi
fi
fi

# Extract just the part after the numeric code in the beginning of the benchmark name, e.g. 401.bzip2 --> bzip2
BENCHMARK_NAME=$BENCHMARK
if [[ "$SPEC_BENCH" == 1 ]]; then
    BENCHMARK_NAME=`echo $BENCHMARK | sed 's/[0-9]*\.\([a-z0-9]*\)/\1/'`
    # Special case for 482.sphinx3
    if [[ "$BENCHMARK" == "482.sphinx3" ]]; then
        BENCHMARK_NAME=sphinx_livepretend
    fi

    # Special case for 483.xalancbmk
    if [[ "$BENCHMARK" == "483.xalancbmk" ]]; then
        BENCHMARK_NAME=Xalan
    fi
    SPEC_CONFIG_SUFFIX=$MWG_MACHINE_NAME-rv64g-priv-1.7-stable
    RUN_DIR=$SPEC_DIR/benchspec/CPU2006/$BENCHMARK/run/run_base_ref_${SPEC_CONFIG_SUFFIX}.0000		# Run directory for the selected SPEC benchmark
    BENCHMARK_NAME=${BENCHMARK_NAME}_base.${SPEC_CONFIG_SUFFIX}
fi

#################### LAUNCH SIMULATION ######################
echo ""
echo "Changing to benchmark runtime directory:	$RUN_DIR"
cd $RUN_DIR

echo ""
echo ""
echo "--------- Here goes nothing! Starting spike! ------------"
echo ""
echo ""

# Actually launch spike.
CMD=""

if [[ "$MODE" == "memdatatrace" ]]; then
    MEMDATATRACE_EXPECTED_INTERVAL=1000000
    MEMDATATRACE_OUTPUT_FILE=$OUTPUT_DIR/spike_mem_data_trace_${BENCHMARK}.txt
    PK=$RISCV/riscv64-unknown-elf/bin/pk
    CMD="$SPIKE_DIR/spike --randmemdatatrace=${MEMDATATRACE_EXPECTED_INTERVAL}:${MEMDATATRACE_OUTPUT_FILE} --memwordsize=8 --ic=1:1:64 --dc=1:1:64 --isa=RV64G -m1024 -p1 $PK $BENCHMARK_NAME $BENCHMARK_ARGS"
fi

if [[ "$MODE" == "faultinj" ]]; then
    FAULT_INJECTION_STEP=10000000
    FAULT_INJECTION_TARGET=data
    FAULT_RECOVERY_SCRIPT=$MWG_GIT_PATH/eccgrp-ecc-ctrl/data_recovery_spike_wrapper.sh
    PK=$MWG_GIT_PATH/eccgrp-riscv-pk/build/riscv64-unknown-elf/bin/pk
    CMD="$SPIKE_DIR/spike -d --faultinj=${FAULT_INJECTION_STEP}:${FAULT_INJECTION_TARGET}:${FAULT_RECOVERY_SCRIPT} --memwordsize=8 --ic=1:1:64 --dc=1:1:64 --isa=RV64G -m1024 -p1 $PK $BENCHMARK_NAME $BENCHMARK_ARGS"
fi

echo $CMD
$CMD

echo "Done!"
