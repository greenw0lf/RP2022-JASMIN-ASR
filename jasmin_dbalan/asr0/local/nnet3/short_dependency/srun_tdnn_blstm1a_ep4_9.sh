#!/bin/sh
#you can control the resources and scheduling with '#SBATCH' settings
# (see 'man sbatch' for more information on setting these parameters)
# The default partition is the 'general' partition
#SBATCH --partition=general
# The default Quality of Service is the 'short' QoS (maximum run time: 4 hours)
#SBATCH --qos=short
# The default run (wall-clock) time is 1 minute
#SBATCH --time=04:00:00
# The default number of parallel tasks per job is 1
#SBATCH --ntasks=1
# Request 1 CPU per active thread of your program (assume 1 unless you specifically set this)
# The default number of CPUs per task is 1 (note: CPUs are always allocated per 2)
#SBATCH --cpus-per-task=10
# The default memory per node is 1024 megabytes (1GB) (for multiple tasks, specify --mem-per-cpu instead)
#SBATCH --mem=25G
# Set mail type to 'END' to receive a mail when the job finishes
# Do not enable mails when submitting large numbers (>20) of jobs at once
#SBATCH --gres=gpu:4
#SBATCH --mail-type=ALL
##SBATCH --dependency=afterok:4835952
train_stage=896
train_exit_stage=930
srun bash local/chain/tuning/run_tdnn_blstm_1a.sh --stage 18 --train-stage $train_stage --train-exit-stage $train_exit_stage   --num-threads-decode 2 --decode-nj 6  --num-chunks-per-minibatch "64" --num-jobs-initial 4 --num-jobs-final 4 --num-epochs 4  #train-stage -3:from get_egs.sh 




