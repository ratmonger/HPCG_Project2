#!/bin/bash



# Load the required packages (gcc 11 and HPL)
module load cuda/12.6.1-pbna
module load singularity


# Set a place to record the results
RESULTS_FILE=$SLURM_SUBMIT_DIR/results/${RESULTS_FILENAME}

# Make the results directory if does not exist
mkdir -p "$(dirname "$RESULTS_FILE")"

# Define the parameter file name using Slurm variables
PARAMS_FILE=$SLURM_SUBMIT_DIR/tmp/task_${ID_TASK}_GPU.csv

# Check for errors
if test -f $PARAMS_FILE; then
    echo Using parameter file $PARAMS_FILE
else
    echo Error $PARAMS_FILE not found
    exit 1
fi


HPL_CONTAINER=$SLURM_SUBMIT_DIR/hpc-benchmarks:24.03.sif
HPL_SCRIPT=$SLURM_SUBMIT_DIR/hpl.sh


# Get the Nth line from our parameter file - where N is the array ID
# Replace all commas with spaces for easier reading.
PARAMS=$(head -n $SLURM_ARRAY_TASK_ID $PARAMS_FILE | tail -n 1 | tr ',' ' ')
echo Read param line $SLURM_ARRAY_TASK_ID: $PARAMS


read -r N_PROB N_DIM NUM_NB NB PMAP NUM_PQ P Q THRESHOLD NUM_PFACT PFACT NUM_REC_STOP NBMIN NUM_REC_PANEL NDIV NUM_RFACT RFACT NUM_BCAST BCAST NUM_DEPTH DEPTH SWAP SWAP_THRESHOLD L1_VAR U_VAR EQUIL MEM_ALIGN OMP_THREADS <<<$(echo $PARAMS)


export OMP_NUM_THREADS=OMP_THREADS


# Create a new working directory for each instance of xhpl since it needs it expects it's own HPL.dat
#SCRATCH_DIR=/carc/scratch/users/$USER
SCRATCH_DIR=$HOME/.tmp


# Make a temporary directory for our work - we will delete this at the end
TMP_DIR=$(mktemp --directory -p $SCRATCH_DIR)
echo Temp directory: $TMP_DIR

# Make a subdirectory with the SLURM array task id to make debugging easier
TMP_WORKING_DIR=$TMP_DIR/$SLURM_ARRAY_TASK_ID
mkdir -p $TMP_WORKING_DIR
echo Created temporary working directory: $TMP_WORKING_DIR

# Make the new working directory the current directory so xhpl runs in there
cd $TMP_WORKING_DIR
echo Now running in $PWD


# Write to HPL.dat
echo "HPLinpack benchmark input file
Innovative Computing Laboratory, University of Tennessee
HPL.out             # output file name (if any)
1                   # device out (6=stdout,7=stderr,file)
$N_PROB             # of problems sizes (N)
$N_DIM              # MATRIX DIMENSION
$NUM_NB             # of NBs
$NB                 # NBs
$PMAP               # PMAP process mapping (0=Row-,1=Column-major)
$NUM_PQ             # of process grids (P x Q)
$P                  # Ps
$Q                  # Qs
$THRESHOLD          # threshold
$NUM_PFACT          # of panel fact
$PFACT              # PFACTs (0=left, 1=Crout, 2=Right)
$NUM_REC_STOP       # of recursive stopping criterium
$NBMIN              # NBMINs (>= 1)
$NUM_REC_PANEL      # of panels in recursion
$NDIV               # NDIVs
$NUM_RFACT          # of recursive panel fact.
$RFACT              # RFACTs (0=left, 1=Crout, 2=Right)
$NUM_BCAST          # of broadcast
$BCAST              # BCASTs (0=1rg,1=1rM,2=2rg,3=2rM,4=Lng,5=LnM)
$NUM_DEPTH          # of lookahead depth
$DEPTH              # DEPTHs (>=0)
$SWAP               # SWAP (0=bin-exch,1=long,2=mix)
$SWAP_THRESHOLD     # swapping threshold
$L1_VAR             # L1 in (0=transposed,1=no-transposed) form
$U_VAR              # U in (0=transposed,1=no-transposed) form
$EQUIL              # Equilibration (0=no,1=yes)
$MEM_ALIGN          # memory alignment in double (> 0)" > HPL.dat


#nvidia-smi

srun --mpi=pmi2 \
    --partition=condo \
    --mem=16G --nodes=1 \
    --ntasks-per-node=2 \
    --gpus=2 \
    singularity run \
    --nv \
    --bind $TMP_WORKING_DIR:/tmpdir \
    $HPL_CONTAINER \
    $HPL_SCRIPT \
    --dat /tmpdir/HPL.dat \
    --cuda-compat \
    --no-multinode \
    2>&1 | tee HPL.out



##########################################################################################################################

# Ensure HPL.out exists
if [ ! -f HPL.out ]; then
    echo "Error: HPL.out not found!"
    exit 1
fi

# Search for the header line and capture the next two lines
DATA=$(awk '/T\/V[[:space:]]+N[[:space:]]+NB[[:space:]]+P[[:space:]]+Q[[:space:]]+Time[[:space:]]+Gflops/ {getline; getline; print}' HPL.out)

echo "$DATA"

# Check if data was captured successfully
if [ -z "$DATA" ]; then
    echo "Error: Performance data not found in HPL.out"
    exit 1
fi

# Extract Time and Gflops from the captured data
TIME=$(echo "$DATA" | awk '{print $(NF-3)}')
GFLOPS=$(echo "$DATA" | awk '{print $(NF-2)}')

# Check if Time and Gflops were extracted successfully
if [ -z "$TIME" ] || [ -z "$GFLOPS" ]; then
    echo "Error: Failed to extract performance metrics"
    exit 1
fi

# Log the results
echo "Results Time: $TIME"
echo "Results Gflops: $GFLOPS"


# Check GFlops is TRUE, then write to RESULTS
if [ ! -z "${GFLOPS}" ]; then

    echo Writing Params and Gflops to $RESULTS_FILE


    echo "HPLinpack benchmark input file
    Innovative Computing Laboratory, University of Tennessee
    HPL.out             # output file name (if any)
    1                   # device out (6=stdout,7=stderr,file)
    $N_PROB             # of problems sizes (N)
    $N_DIM              # MATRIX DIMENSION
    $NUM_NB             # of NBs
    $NB                 # NBs
    $PMAP               # PMAP process mapping (0=Row-,1=Column-major)
    $NUM_PQ             # of process grids (P x Q)
    $P                  # Ps
    $Q                  # Qs
    $THRESHOLD          # threshold
    $NUM_PFACT          # of panel fact
    $PFACT              # PFACTs (0=left, 1=Crout, 2=Right)
    $NUM_REC_STOP       # of recursive stopping criterium
    $NBMIN              # NBMINs (>= 1)
    $NUM_REC_PANEL      # of panels in recursion
    $NDIV               # NDIVs
    $NUM_RFACT          # of recursive panel fact.
    $RFACT              # RFACTs (0=left, 1=Crout, 2=Right)
    $NUM_BCAST          # of broadcast
    $BCAST              # BCASTs (0=1rg,1=1rM,2=2rg,3=2rM,4=Lng,5=LnM)
    $NUM_DEPTH          # of lookahead depth
    $DEPTH              # DEPTHs (>=0)
    $SWAP               # SWAP (0=bin-exch,1=long,2=mix)
    $SWAP_THRESHOLD     # swapping threshold
    $L1_VAR             # L1 in (0=transposed,1=no-transposed) form
    $U_VAR              # U in (0=transposed,1=no-transposed) form
    $EQUIL              # Equilibration (0=no,1=yes)
    $MEM_ALIGN          # memory alignment in double (> 0)"



    python3 -c "import csv
import os

STRING_GFLOPS = '$GFLOPS'
bytes_per_node = $MEM_PER_NODE
gb_per_node = bytes_per_node / (1024 ** 3)
gb_per_node_rounded = round(gb_per_node, 2)

# Check if the file exists
file_exists = os.path.exists('$RESULTS_FILE')

# Open the file in append mode
with open('$RESULTS_FILE', 'a') as f:
    writer = csv.writer(f)

    # Write the header row only if the file does not exist
    if not file_exists:
        writer.writerow(['GB_per_node', 'N_PROB', 'N_DIM', 'NUM_NB', 'NB', 'PMAP', 'NUM_PQ', 'P', 'Q', 'THRESHOLD',
                         'NUM_PFACT', 'PFACT', 'NUM_REC_STOP', 'NBMIN', 'NUM_REC_PANEL', 'NDIV', 'NUM_RFACT',
                         'RFACT', 'NUM_BCAST', 'BCAST', 'NUM_DEPTH', 'DEPTH', 'SWAP', 'SWAP_THRESHOLD', 'L1_VAR',
                         'U_VAR', 'EQUIL', 'MEM_ALIGN', 'OMP_THREADS', 'SLURM_NNODES', 'SLURM_NTASKS_PER_NODE',
                         'TIME', 'SLURMD_NODENAME','STRING_GFLOPS'])

    # Write the data row
    writer.writerow([gb_per_node_rounded, $N_PROB, $N_DIM, $NUM_NB, $NB, $PMAP, $NUM_PQ, $P, $Q, $THRESHOLD,
                     $NUM_PFACT, $PFACT, $NUM_REC_STOP, $NBMIN, $NUM_REC_PANEL, $NDIV, $NUM_RFACT, $RFACT,
                     $NUM_BCAST, $BCAST, $NUM_DEPTH, $DEPTH, $SWAP, $SWAP_THRESHOLD, $L1_VAR, $U_VAR, $EQUIL,
                     $MEM_ALIGN, $OMP_THREADS, $SLURM_NNODES, $SLURM_NTASKS_PER_NODE, $TIME,'$SLURMD_NODENAME', STRING_GFLOPS])"

fi
sed -i 's/\r//' $RESULTS_FILE

# Clean up the temporary working directory
rm -r $TMP_DIR
echo Deleted $TMP_DIR



