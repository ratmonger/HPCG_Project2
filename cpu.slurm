#!/bin/bash



# Load the required packages (gcc 11 and HPL)
module load intel/20.0.4 hpcg


#export OMP_PROC_BIND=TRUE
#export OMP_PLACES=cores

#export OMP_NUM_THREADS=$THREAD_COUNT

# Set a place to record the results
RESULTS_FILE=$SLURM_SUBMIT_DIR/results/${RESULTS_FILENAME}

# Make the results directory if does not exist
mkdir -p "$(dirname "$RESULTS_FILE")"

# Define the parameter file name using Slurm variables
PARAMS_FILE=$SLURM_SUBMIT_DIR/tmp/task_${ID_TASK}_CPU.csv

# Check for errors
if test -f $PARAMS_FILE; then
    echo Using parameter file $PARAMS_FILE
else
    echo Error $PARAMS_FILE not found
    exit 1
fi


# Get the Nth line from our parameter file - where N is the array ID
# Replace all commas with spaces for easier reading.
PARAMS=$(head -n $SLURM_ARRAY_TASK_ID $PARAMS_FILE | tail -n 1 | tr ',' ' ')
echo Read param line $SLURM_ARRAY_TASK_ID: $PARAMS


read -r NX NY NZ TT <<<$(echo $PARAMS)


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


# Write to HPCG.dat
echo "HPCG benchmark input file
Sandia National Laboratories; University of Tennessee, Knoxville
$NX $NY $NZ
$TT" > hpcg.dat


#bind $(pwd):/my-dat-files $(pwd)/hpc-benchmarks:24.03.sif $(pwd)/hpcg.sh \
#           --dat /my-dat-files/hpcg.dat \
#           2>&1 | tee HPCG.out


#srun --mpi=pmi2 --cpu-bind=cores xhpcg

srun --mpi=pmi2   --cpu-bind=cores  xhpcg
##########################################################################################################################

mv HPCG-Benchmark_*.txt  HPCG.out

cat HPCG.out

# Ensure HPL.out exists
if [ ! -f HPCG.out ]; then
    echo "Error: HPCG.out not found!"
    exit 1
fi


# Extract the GFLOP/s rating
GFLOPS=$(grep "Final Summary::HPCG result is VALID with a GFLOP/s rating of=" HPCG.out | awk -F"=" '{print $2}')

# Check if the value was successfully extracted
if [ -z "$GFLOPS" ]; then
    echo "Error: Could not extract GFLOP/s rating from HPCG.out"
    exit 1
fi


# Extract the benchmark time (Total time)
TIME=$(grep "Benchmark Time Summary::Total=" HPCG.out | awk -F"=" '{print $2}')

# Check if the value was successfully extracted
if [ -z "$TIME" ]; then
    echo "Error: Could not extract benchmark time from HPCG.out"
    exit 1
fi



# Check if the value was successfully extracted
if [ -z "$GFLOPS" ]; then
    echo "Error: Could not extract GFLOP/s rating from HPCG.out"
    exit 1
fi

# Log the results
echo "Results Time: $TIME"
echo "Results Gflops: $GFLOPS"


# Check GFlops is TRUE, then write to RESULTS
if [ ! -z "${GFLOPS}" ]; then

    echo Writing Params and Gflops to $RESULTS_FILE



    python3 -c "import csv
import os

STRING_NODELIST='$SLURM_JOB_NODELIST'

# Replace commas with spaces
STRING_NODELIST = STRING_NODELIST.replace(',', ' ')



# Check if the file exists
file_exists = os.path.exists('$RESULTS_FILE')

# Open the file in append mode
with open('$RESULTS_FILE', 'a') as f:
    writer = csv.writer(f)

    # Write the header row only if the file does not exist
    if not file_exists:
        writer.writerow(['NX','NY','NZ','TT','SLURM_NNODES','GPUS','TASKS_PER_NODE','OMP_NUM_THREADS','SLURM_JOB_NODELIST','TIME','GFLOPS'])

    # Write the data row
    writer.writerow([$NX, $NY, $NZ, $TT, $SLURM_NNODES, 0,$SLURM_NTASKS_PER_NODE, $OMP_NUM_THREADS,STRING_NODELIST, $TIME, $GFLOPS])"

fi
sed -i 's/\r//' $RESULTS_FILE

# Clean up the temporary working directory
rm -r $TMP_DIR
echo Deleted $TMP_DIR



