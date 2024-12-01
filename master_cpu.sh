#!/bin/bash


# Create a new unique results file name if you want to write to seperate file

# Adjust memory per node, max-min nodes, max-min procs

# To hardcode p and q values, set fixed_pq=1 and then modify generate .py values of p and q
# Think carefully what p and q you want (p x q  = nodes x procs per node)

# Increment ID_TASK for safety (prevent reading from the same parameter files)

# Maybe adjust the slurm job time limit in the sbatch command

################# MODIFY HERE  ###############################################
###############################################################################
RESULTS_FILENAME="HOPPER_THREAD2_CPU.csv" ## CHECK FIXED VALS? what are P and Q? check!

MIN_NODES=1         # Maximum number of nodes available
MAX_NODES=2
MIN_PROCS_PER_NODE=1   # Processors per node
MAX_PROCS_PER_NODE=8

MIN_THREADS=1
MAX_THREADS=32

ID_TASK=66496 #increment this!  ensures unique jobs when reading parameter files
###############################################################################


CHICKEN=$ID_TASK # do not need to change this


# Define a list of chicken-like names
CHICKEN_NAMES=("SILKIE" "LEGHORN" "FRIESAN"  "WELBAR" "HOUDAN" "SUSSEX" "REDCAP" "ORLOFF" "COCHIN" "IXWORTH" "KULANG" "RHODEBAR" "MINORCA" "FRIZZLE" "HAMBURGH" "POLISH" "DORKING" "BRAKEL" "LAFLECHE" "BRAHMA" "CAMPINE" "DONGTAO" "SULTAN" "SHAMO" "BURMESE" "BUCKEYE" "DELAWARE" "SEBRIGHT")
module load  gcc/14.1.0-hw53
module load python/3.12.5-p5m5
# Loop over possible combinations of nodes and processors per node
for NODES in $(seq $MIN_NODES $MAX_NODES); do
  for PROCS in $(seq $MIN_PROCS_PER_NODE $MAX_PROCS_PER_NODE); do
    for THREADS in $(seq $MIN_THREADS $MAX_THREADS); do

        # Check if threads per process fit within the CPUs per node
        if (( THREADS * PROCS > 32 )); then
          continue
        fi

        # Increment CHICKEN and select a name from the list
        CHICKEN=$((CHICKEN + 1))
        NAME="${CHICKEN_NAMES[CHICKEN % ${#CHICKEN_NAMES[@]}]}      ${ID_TASK}"

        # Call the Python script to generate the parameter CSV file
        PARAM_FILE="task_${ID_TASK}_CPU.csv"
        python3 generate_cpu.py --nodes $NODES  \
        --output $PARAM_FILE
        
        echo "Job Name: $NAME"
    
        # Submit the Slurm job using the generated parameter file --nodelist=hopper[054-063] \ 49 is good, but not top
        # 50-51 seg fault   --exclude=hopper[049-051] \
        export OMP_NUM_THREADS=$THREADS

        sbatch \
        --job-name "$NAME" \
        --partition general \
        --time 00:15:00 \
        --cpus-per-task=$THREADS \
        --nodes $NODES \
        --ntasks-per-node $PROCS \
        --mem 0  \
        --export=ALL,ID_TASK=$ID_TASK,NODES=$NODES,RESULTS_FILENAME=$RESULTS_FILENAME,THREAD_COUNT=$THREADS \
        --array "1-$(wc -l < tmp/$PARAM_FILE)" \
        cpu.slurm
    done
  done
done
