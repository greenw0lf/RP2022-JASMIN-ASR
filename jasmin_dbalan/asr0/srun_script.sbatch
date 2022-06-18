#!/bin/sh
#
#SBATCH --job-name="jas_balan"
#SBATCH --partition=compute
##SBATCH --qos=medium
#SBATCH --time=04:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=10
##SBATCH --gres=gpu:turing
#SBATCH --mem-per-cpu=10G
#SBATCH --mail-type=END

module use /opt/insy/modulefiles
module load devtoolset/8
module load cuda/11.2
module load cudnn/11.2-8.1.1.33

srun ./jasmin_run.sh 
#srun ./local/chain/run_tdnn.sh
