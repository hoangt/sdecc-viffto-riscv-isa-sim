#!/bin/bash
#
# Author: Mark Gottscho
# mgottscho@ucla.edu

ARGC=$# # Get number of arguments excluding arg0 (the script itself). Check for help message condition.
if [[ "$ARGC" < 8 ]]; then # Bad number of arguments. 
	echo "Author: Mark Gottscho"
	echo "mgottscho@ucla.edu"
	echo ""
	echo "This script runs a single RISC-V Spike simulation of a single program (compiled for embedded Newlib, not Linux)."
	echo ""
	echo "USAGE: run_spike_benchmark.sh <MODE> <N> <K> <CODE_TYPE> <CACHELINE_SIZE> <SEQNUM> <OUTPUT_DIR> <BENCHMARK> <OPTIONAL_BENCHMARK_ARGS>"
	echo "EXAMPLE: ./run_spike_benchmark.sh faultinj_sim 72 64 hsiao1970 64 401.bzip2"
	echo ""
	echo "A single --help help or -h argument will bring this message back."
	exit
fi

# Get command line input. We will need to check these.
MODE=$1                         # Spike mode, i.e. memdatatrace or faultinj_[user|sim] or default
N=$2
K=$3
CODE_TYPE=$4
CACHELINE_SIZE=$5
SEQNUM=$6
OUTPUT_DIR=$7
BENCHMARK=$8					# Benchmark name, e.g. bzip2
OPTIONAL_BENCHMARK_ARGS="${@:9}" # Remaining args, if any

################## SYSTEM-SPECIFIC VARIABLES: MODIFY ACCORDINGLY #######
SPEC_DIR=$MWG_GIT_PATH/spec_cpu2006_install
AXBENCH_DIR=$MWG_GIT_PATH/eccgrp-axbench
SPIKE_DIR=$MWG_GIT_PATH/eccgrp-riscv-isa-sim/build
##################################################################

mkdir -p $OUTPUT_DIR

# Defaults
SPEC_BENCH=0
AX_BENCH=0
RUN_DIR=$PWD
if [[ "$MODE" == "faultinj_sim" ]]; then
    FAULT_INJECTION_STEP_START=1000000
    FAULT_INJECTION_STEP_STOP=99999999999
fi

################### SPEC CPU2006 BENCHMARK CODENAMES ####################
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

############### SPEC CPU2006 BENCHMARK INPUTS ####################
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

################### AXBENCH BENCHMARK CODENAMES ##################
BLACKSCHOLES=blackscholes
FFT=fft
INVERSEK2J=inversek2j
JMEINT=jmeint
JPEG=jpeg
KMEANS=kmeans
SOBEL=sobel
##################################################################


################# AXBENCH BENCHMARK INPUTS #######################
BLACKSCHOLES_ARGS="$AXBENCH_DIR/applications/blackscholes/test.data/input/blackscholesTest_200K.data $OUTPUT_DIR/blackscholes.$SEQNUM.data"
FFT_ARGS="2048 $OUTPUT_DIR/fft.$SEQNUM.data"
INVERSEK2J_ARGS="$AXBENCH_DIR/applications/inversek2j/test.data/input/theta_1000K.data $OUTPUT_DIR/inversek2j.$SEQNUM.data"
JMEINT_ARGS="$AXBENCH_DIR/applications/jmeint/test.data/input/jmeint_1000K.data $OUTPUT_DIR/jmeint.$SEQNUM.data"
JPEG_ARGS="$AXBENCH_DIR/applications/jpeg/test.data/input/10.rgb $OUTPUT_DIR/jpeg.$SEQNUM.10.jpg" # FIXME: need to run all inputs, not just first. See run_observation.sh for jpeg
KMEANS_ARGS="$AXBENCH_DIR/applications/kmeans/test.data/input/10.rgb $OUTPUT_DIR/kmeans.$SEQNUM.10.rgb" # FIXME: need to run all inputs, not just first. Also need to run a conversion script to png. see run_observation.sh for kmeans
SOBEL_ARGS="$AXBENCH_DIR/applications/sobel/test.data/input/10.rgb $OUTPUT_DIR/sobel.$SEQNUM.10.rgb" # FIXME: need to run all inputs, not just first. Also need to run a conversion script to png. see run_observation.sh for sobel
##################################################################

# Check BENCHMARK input
#################### BENCHMARK CODE MAPPING ######################
if [[ "$BENCHMARK" == "$PERLBENCH" ]]; then
	BENCHMARK_ARGS=$PERLBENCH_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$BZIP2" ]]; then
	BENCHMARK_ARGS=$BZIP2_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$GCC" ]]; then
	BENCHMARK_ARGS=$GCC_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$BWAVES" ]]; then
	BENCHMARK_ARGS=$BWAVES_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$GAMESS" ]]; then
	BENCHMARK_ARGS=$GAMESS_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$MCF" ]]; then
	BENCHMARK_ARGS=$MCF_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$MILC" ]]; then
	BENCHMARK_ARGS=$MILC_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$ZEUSMP" ]]; then
	BENCHMARK_ARGS=$ZEUSMP_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$GROMACS" ]]; then
	BENCHMARK_ARGS=$GROMACS_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$CACTUSADM" ]]; then
	BENCHMARK_ARGS=$CACTUSADM_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$LESLIE3D" ]]; then
	BENCHMARK_ARGS=$LESLIE3D_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$NAMD" ]]; then
	BENCHMARK_ARGS=$NAMD_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$GOBMK" ]]; then
	BENCHMARK_ARGS=$GOBMK_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$DEALII" ]]; then
	BENCHMARK_ARGS=$DEALII_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$SOPLEX" ]]; then
	BENCHMARK_ARGS=$SOPLEX_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$POVRAY" ]]; then
	BENCHMARK_ARGS=$POVRAY_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$CALCULIX" ]]; then
	BENCHMARK_ARGS=$CALCULIX_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$HMMER" ]]; then
	BENCHMARK_ARGS=$HMMER_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$SJENG" ]]; then
	BENCHMARK_ARGS=$SJENG_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$GEMSFDTD" ]]; then
	BENCHMARK_ARGS=$GEMSFDTD_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$LIBQUANTUM" ]]; then
	BENCHMARK_ARGS=$LIBQUANTUM_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$H264REF" ]]; then
	BENCHMARK_ARGS=$H264REF_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$TONTO" ]]; then
	BENCHMARK_ARGS=$TONTO_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$LBM" ]]; then
	BENCHMARK_ARGS=$LBM_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$OMNETPP" ]]; then
	BENCHMARK_ARGS=$OMNETPP_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$ASTAR" ]]; then
	BENCHMARK_ARGS=$ASTAR_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$WRF" ]]; then
	BENCHMARK_ARGS=$WRF_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$SPHINX3" ]]; then
	BENCHMARK_ARGS=$SPHINX3_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$XALANCBMK" ]]; then 
	BENCHMARK_ARGS=$XALANCBMK_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$SPECRAND_INT" ]]; then
	BENCHMARK_ARGS=$SPECRAND_INT_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$SPECRAND_FLOAT" ]]; then
	BENCHMARK_ARGS=$SPECRAND_FLOAT_ARGS
    SPEC_BENCH=1
else
if [[ "$BENCHMARK" == "$BLACKSCHOLES" ]]; then
	BENCHMARK_ARGS=$BLACKSCHOLES_ARGS
    FAULT_INJECTION_STEP_START=442950
    FAULT_INJECTION_STEP_STOP=1876922900
    AX_BENCH=1
else
if [[ "$BENCHMARK" == "$FFT" ]]; then
	BENCHMARK_ARGS=$FFT_ARGS
    # Minimalist user-defined handler
    #FAULT_INJECTION_STEP_START=436700
    #FAULT_INJECTION_STEP_STOP=3124600
    # With user-defined handlers
    FAULT_INJECTION_STEP_START=454200
    FAULT_INJECTION_STEP_STOP=4828100
    AX_BENCH=1
else
if [[ "$BENCHMARK" == "$INVERSEK2J" ]]; then
	BENCHMARK_ARGS=$INVERSEK2J_ARGS
    FAULT_INJECTION_STEP_START=435350
    FAULT_INJECTION_STEP_STOP=5923069800
    AX_BENCH=1
else
if [[ "$BENCHMARK" == "$JMEINT" ]]; then
	BENCHMARK_ARGS=$JMEINT_ARGS
    FAULT_INJECTION_STEP_START=441950
    FAULT_INJECTION_STEP_STOP=38585071650
    AX_BENCH=1
else
if [[ "$BENCHMARK" == "$JPEG" ]]; then
	BENCHMARK_ARGS=$JPEG_ARGS
    FAULT_INJECTION_STEP_START=247450
    FAULT_INJECTION_STEP_STOP=227167600
    AX_BENCH=1
else
if [[ "$BENCHMARK" == "$KMEANS" ]]; then
	BENCHMARK_ARGS=$KMEANS_ARGS
    FAULT_INJECTION_STEP_START=1000000
    FAULT_INJECTION_STEP_STOP=0 # TODO
    AX_BENCH=1
else
if [[ "$BENCHMARK" == "$SOBEL" ]]; then
	BENCHMARK_ARGS=$SOBEL_ARGS
    FAULT_INJECTION_STEP_START=466950
    FAULT_INJECTION_STEP_STOP=2927653750
    AX_BENCH=1
else # Not a SPEC CPU2006 or axbench benchmark
    BENCHMARK_ARGS=$OPTIONAL_BENCHMARK_ARGS
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
fi
fi
fi
fi
fi
fi
fi

BENCHMARK_NAME=$BENCHMARK # Default

# SPEC CPU2006: Extract just the part after the numeric code in the beginning of the benchmark name, e.g. 401.bzip2 --> bzip2
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

# AX BENCH
if [[ "$AX_BENCH" == 1 ]]; then
    RUN_DIR=$AXBENCH_DIR/applications/$BENCHMARK/bin
    if [[ "$MODE" == "faultinj_sim" ]]; then
        BENCHMARK_NAME=${BENCHMARK}-rv64g-sdecc
    else
    if [[ "$MODE" == "faultinj_user" ]]; then
        BENCHMARK_NAME=${BENCHMARK}-rv64g-sdecc
    else
        BENCHMARK_NAME=${BENCHMARK}-rv64g
    fi
    fi
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
    CMD="$SPIKE_DIR/spike --randmemdatatrace=${MEMDATATRACE_EXPECTED_INTERVAL}:${MEMDATATRACE_OUTPUT_FILE} --memwordsizebits=$K --ncodewordbits=$N --code_type=$CODE_TYPE --ic=1:1:$CACHELINE_SIZE --dc=1:1:$CACHELINE_SIZE --isa=RV64G -m2048 -p1 $PK $BENCHMARK_NAME $BENCHMARK_ARGS"
fi

if [[ "$MODE" == "faultinj_sim" ]]; then
    FAULT_INJECTION_TARGET=data
    CANDIDATES_SCRIPT=$MWG_GIT_PATH/eccgrp-ecc-ctrl/candidate_messages_spike_wrapper.sh
    DATA_FAULT_RECOVERY_SCRIPT=$MWG_GIT_PATH/eccgrp-ecc-ctrl/data_recovery_spike_wrapper.sh
    INST_FAULT_RECOVERY_SCRIPT=$MWG_GIT_PATH/eccgrp-ecc-ctrl/inst_recovery_spike_wrapper.sh
    PK=$MWG_GIT_PATH/eccgrp-riscv-pk/build/riscv64-unknown-elf/bin/pk
    CMD="$SPIKE_DIR/spike --faultinj_sim=${FAULT_INJECTION_STEP_START}:${FAULT_INJECTION_STEP_STOP}:${FAULT_INJECTION_TARGET}:${CANDIDATES_SCRIPT}:${DATA_FAULT_RECOVERY_SCRIPT}:${INST_FAULT_RECOVERY_SCRIPT} --memwordsizebits=$K --ncodewordbits=$N --code_type=$CODE_TYPE --ic=1:1:$CACHELINE_SIZE --dc=1:1:$CACHELINE_SIZE --isa=RV64G -m2048 -p1 $PK $BENCHMARK_NAME $BENCHMARK_ARGS"
fi

if [[ "$MODE" == "faultinj_user" ]]; then
    CANDIDATES_SCRIPT=$MWG_GIT_PATH/eccgrp-ecc-ctrl/candidate_messages_spike_wrapper.sh
    DATA_FAULT_RECOVERY_SCRIPT=$MWG_GIT_PATH/eccgrp-ecc-ctrl/data_recovery_spike_wrapper.sh
    INST_FAULT_RECOVERY_SCRIPT=$MWG_GIT_PATH/eccgrp-ecc-ctrl/inst_recovery_spike_wrapper.sh
    PK=$MWG_GIT_PATH/eccgrp-riscv-pk/build/riscv64-unknown-elf/bin/pk
    CMD="$SPIKE_DIR/spike --faultinj_user=${CANDIDATES_SCRIPT}:${DATA_FAULT_RECOVERY_SCRIPT}:${INST_FAULT_RECOVERY_SCRIPT} --memwordsizebits=$K --ncodewordbits=$N --code_type=$CODE_TYPE --ic=1:1:$CACHELINE_SIZE --dc=1:1:$CACHELINE_SIZE --isa=RV64G -m2048 -p1 $PK $BENCHMARK_NAME $BENCHMARK_ARGS"
fi

if [[ "$MODE" == "default" ]]; then
    CANDIDATES_SCRIPT=$MWG_GIT_PATH/eccgrp-ecc-ctrl/candidate_messages_spike_wrapper.sh
    DATA_FAULT_RECOVERY_SCRIPT=$MWG_GIT_PATH/eccgrp-ecc-ctrl/data_recovery_spike_wrapper.sh
    INST_FAULT_RECOVERY_SCRIPT=$MWG_GIT_PATH/eccgrp-ecc-ctrl/inst_recovery_spike_wrapper.sh
    PK=$MWG_GIT_PATH/eccgrp-riscv-pk/build/riscv64-unknown-elf/bin/pk
    CMD="$SPIKE_DIR/spike --faultinj_user=${CANDIDATES_SCRIPT}:${DATA_FAULT_RECOVERY_SCRIPT}:${INST_FAULT_RECOVERY_SCRIPT} --memwordsizebits=$K --ncodewordbits=$N --code_type=$CODE_TYPE --ic=1:1:$CACHELINE_SIZE --dc=1:1:$CACHELINE_SIZE --isa=RV64G -m2048 -p1 $PK $BENCHMARK_NAME $BENCHMARK_ARGS"
fi

echo $CMD
$CMD

echo "Done!"
