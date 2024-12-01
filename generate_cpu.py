#!/usr/bin/env python3

import argparse
import csv
import os
import math
from itertools import product



count = 1 #this multiplies the combinations created below

uniform = True

# Define parameters
NX = (64,)  
NY = (64,)  
NZ = (64,)
TT = (30,)    


def parse_arguments():
    parser = argparse.ArgumentParser(description="Generate parameter CSV for HPL testing")
    parser.add_argument("--nodes", type=int, required=True, help="Number of nodes")
    parser.add_argument("--output", type=str, required=True, help="Output CSV file name")
    return parser.parse_args()


def generate_csv(params, output_filename):
    # Define the path to the /tmp directory
    tmp_dir = "./tmp"
    
    # Create the /tmp directory if it doesn't exist
    os.makedirs(tmp_dir, exist_ok=True)
    
    # Set the full output path
    output_file = os.path.join(tmp_dir, output_filename)
    
    with open(output_file, "w", newline="") as csvfile:
        csv_writer = csv.writer(csvfile)
        for row in params:
            csv_writer.writerow(row)



def main():
    args = parse_arguments()
    

    # Generate parameter rows based on P, Q, and calculated N_DIM values
    params = []
    for counter in range(count):
        if uniform:
            for num_var in NX:
                params.append((num_var, num_var, num_var, TT[0]))
        else:# Generate all other fixed combinations and append with calculated values
            for args_comb in product(NX, NY, NZ, TT):
                params.append(args_comb)

    # Write all generated combinations to the CSV file
    generate_csv(params, args.output)

if __name__ == "__main__":
    main()

