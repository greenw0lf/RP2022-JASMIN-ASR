#!/bin/bash

# This script was modified from the Tedlium egs.
# It assumes you first completed the run.sh from the main egs/CGN directory

## how you run this (note: this assumes that the run_tdnn.sh soft link points here;
## otherwise call it directly in its location).
# 
# local/chain/run_tdnn.sh

# This script is uses an xconfig-based mechanism
# to get the configuration.

# set -e -o pipefail

# First the options that are passed through to run_ivector_common.sh
# (some of which are also used in this script directly).

# repurposed from egs/Tedlium for CGN by LvdW
remove_egs=false
stage=18
align_fmllr_lats_stage=-10
nj=1
decode_nj=4
min_seg_len=1.55
xent_regularize=0.1
train_set=train
gmm=tri4  # the gmm for the target data
num_threads_ubm=32
nnet3_affix=  # cleanup affix for nnet3 and chain dirs, e.g. _cleaned

# The rest are configs specific to this script.  Most of the parameters
# are just hardcoded at this level, in the commands below.
train_stage=-10
tree_affix=  # affix for tree directory, e.g. "a" or "b", in case we change the configuration.
tdnn_affix=1a  #affix for TDNN directory, e.g. "a" or "b", in case we change the configuration.
common_egs_dir=/tudelft.net/staff-bulk/ewi/insy/SpeechLab/siyuanfeng/software/kaldi/egs/cgn/s5/exp/chain/tdnn1a_sp_bi/egs  # you can set this to use previously dumped egs.


# some settings dependent on the GPU, for a single GTX980Ti these settings seem to work ok.
#
# increase these if you have multiple GPUs
num_jobs_initial=1
num_jobs_final=1
num_epochs=3
# change these for different amounts of memory
#num_chunks_per_minibatch="256,128,64"
num_chunks_per_minibatch="128,64"
frames_per_iter=1500000
# resulting in around 2500 iters
# End configuration section.
echo "$0 $@"  # Print the command line for logging

. cmd.sh
. ./path.sh
. ./utils/parse_options.sh


if ! cuda-compiled; then
  cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
fi

# local/nnet3/run_ivector_common.sh --stage $stage \
#                                   --nj $nj \
#                                   --min-seg-len $min_seg_len \
#                                   --train-set $train_set \
#                                   --gmm $gmm \
#                                   --num-threads-ubm $num_threads_ubm \
#                                   --nnet3-affix "$nnet3_affix"


gmm_dir=exp/$train_set/$gmm
ali_dir=exp/$train_set/${gmm}_ali_${train_set}_sp_comb
tree_dir=exp/chain${nnet3_affix}/tree_bi${tree_affix}
lat_dir=exp/chain${nnet3_affix}/${gmm}_${train_set}_sp_comb_lats
#dir=exp/chain${nnet3_affix}/tdnn${tdnn_affix}_sp_bi
input_feat_affix=mfcc_hires_only
dir=exp/chain${nnet3_affix}/tdnn${tdnn_affix}_sp_bi_epoch${num_epochs}_input${input_feat_affix}
train_data_dir=data/${train_set}_sp_hires_comb
lores_train_data_dir=data/${train_set}_sp_comb
train_ivector_dir=exp/nnet3${nnet3_affix}/ivectors_${train_set}_sp_hires_comb


for f in $gmm_dir/final.mdl $train_data_dir/feats.scp $train_ivector_dir/ivector_online.scp \
    $lores_train_data_dir/feats.scp $ali_dir/ali.1.gz $gmm_dir/final.mdl; do
  [ ! -f $f ] && echo "$0: expected file $f to exist" && exit 1
done

if [ $stage -le 14 ]; then
  echo "$0: creating lang directory with one state per phone."
  # Create a version of the lang/ directory that has one state per phone in the
  # topo file. [note, it really has two states.. the first one is only repeated
  # once, the second one has zero or more repeats.]
  if [ -d data/lang_chain ]; then
    if [ data/lang_chain/L.fst -nt data/lang/L.fst ]; then
      echo "$0: data/lang_chain already exists, not overwriting it; continuing"
    else
      echo "$0: data/lang_chain already exists and seems to be older than data/lang..."
      echo " ... not sure what to do.  Exiting."
      exit 1;
    fi
  else
    cp -r data/lang_s data/lang_chain
    silphonelist=$(cat data/lang_chain/phones/silence.csl) || exit 1;
    nonsilphonelist=$(cat data/lang_chain/phones/nonsilence.csl) || exit 1;
    # Use our special topology... note that later on may have to tune this
    # topology.
    steps/nnet3/chain/gen_topo.py $nonsilphonelist $silphonelist >data/lang_chain/topo
  fi
fi

if [ $stage -le 15 ]; then
  # Get the alignments as lattices (gives the chain training more freedom).
  # use the same num-jobs as the alignments
  steps/align_fmllr_lats.sh --stage $align_fmllr_lats_stage --nj $nj --cmd "$train_cmd" ${lores_train_data_dir} \
    data/lang_s $gmm_dir $lat_dir
  #rm $lat_dir/fsts.*.gz # save space
fi
echo "This is debug point"
if [ $stage -le 16 ]; then
  # Build a tree using our new topology.  We know we have alignments for the
  # speed-perturbed data (local/nnet3/run_ivector_common.sh made them), so use
  # those.
  if [ -f $tree_dir/final.mdl ]; then
    echo "$0: $tree_dir/final.mdl already exists, refusing to overwrite it."
    exit 1;
  fi
  steps/nnet3/chain/build_tree.sh --frame-subsampling-factor 3 \
      --context-opts "--context-width=2 --central-position=1" \
      --leftmost-questions-truncate -1 \
      --cmd "$train_cmd" 4000 ${lores_train_data_dir} data/lang_chain $ali_dir $tree_dir
fi

if [ $stage -le 17 ]; then
  mkdir -p $dir

  echo "$0: creating neural net configs using the xconfig parser";

  num_targets=$(tree-info $tree_dir/tree |grep num-pdfs|awk '{print $2}')
  learning_rate_factor=$(echo "print 0.5/$xent_regularize" | python)

  mkdir -p $dir/configs
  cat <<EOF > $dir/configs/network.xconfig
  input dim=100 name=ivector
  input dim=40 name=input

  # please note that it is important to have input layer with the name=input
  # as the layer immediately preceding the fixed-affine-layer to enable
  # the use of short notation for the descriptor
  #fixed-affine-layer name=lda input=Append(-1,0,1,ReplaceIndex(ivector, t, 0)) affine-transform-file=$dir/configs/lda.mat
  fixed-affine-layer name=lda input=Append(-1,0,1) affine-transform-file=$dir/configs/lda.mat

  # the first splicing is moved before the lda layer, so no splicing here
  relu-batchnorm-layer name=tdnn1 dim=450 self-repair-scale=1.0e-04
  relu-batchnorm-layer name=tdnn2 input=Append(-1,0,1) dim=450
  relu-batchnorm-layer name=tdnn3 input=Append(-1,0,1,2) dim=450
  relu-batchnorm-layer name=tdnn4 input=Append(-3,0,3) dim=450
  relu-batchnorm-layer name=tdnn5 input=Append(-3,0,3) dim=450
  relu-batchnorm-layer name=tdnn6 input=Append(-6,-3,0) dim=450

  ## adding the layers for chain branch
  relu-batchnorm-layer name=prefinal-chain input=tdnn6 dim=450 target-rms=0.5
  output-layer name=output include-log-softmax=false dim=$num_targets max-change=1.5

  # adding the layers for xent branch
  # This block prints the configs for a separate output that will be
  # trained with a cross-entropy objective in the 'chain' models... this
  # has the effect of regularizing the hidden parts of the model.  we use
  # 0.5 / args.xent_regularize as the learning rate factor- the factor of
  # 0.5 / args.xent_regularize is suitable as it means the xent
  # final-layer learns at a rate independent of the regularization
  # constant; and the 0.5 was tuned so as to make the relative progress
  # similar in the xent and regular final layers.
  relu-batchnorm-layer name=prefinal-xent input=tdnn6 dim=450 target-rms=0.5
  output-layer name=output-xent dim=$num_targets learning-rate-factor=$learning_rate_factor max-change=1.5

EOF
  steps/nnet3/xconfig_to_configs.py --xconfig-file $dir/configs/network.xconfig --config-dir $dir/configs/

fi

 

if [ $stage -le 18 ]; then

 steps/nnet3/chain/train.py --stage $train_stage \
    --cmd "$decode_cmd" \
    --feat.online-ivector-dir $train_ivector_dir \
    --feat.cmvn-opts "--norm-means=false --norm-vars=false" \
    --chain.xent-regularize 0.1 \
    --chain.leaky-hmm-coefficient 0.1 \
    --chain.l2-regularize 0.00005 \
    --chain.apply-deriv-weights false \
    --chain.lm-opts="--num-extra-lm-states=2000" \
    --egs.dir "$common_egs_dir" \
    --egs.opts "--frames-overlap-per-eg 0" \
    --egs.chunk-width 150 \
    --trainer.num-chunk-per-minibatch $num_chunks_per_minibatch \
    --trainer.frames-per-iter $frames_per_iter \
    --trainer.num-epochs $num_epochs \
    --trainer.optimization.num-jobs-initial $num_jobs_initial \
    --trainer.optimization.num-jobs-final $num_jobs_final \
    --trainer.optimization.initial-effective-lrate 0.001 \
    --trainer.optimization.final-effective-lrate 0.0001 \
    --trainer.max-param-change 2.0 \
    --cleanup.remove-egs $remove_egs \
    --feat-dir $train_data_dir \
    --tree-dir $tree_dir \
    --lat-dir $lat_dir \
    --use-gpu "wait" \
    --dir $dir
fi


 if [ $stage -le 19 ]; then
   # Note: it might appear that this data/lang_chain directory is mismatched, and it is as
   # far as the 'topo' is concerned, but this script doesn't read the 'topo' from
   # the lang directory.
   utils/mkgraph.sh --self-loop-scale 1.0 data/lang_s_test_tgpr $dir $dir/graph
 fi

 if [ $stage -le 20 ]; then
   for x in dev_s dev_t_16khz; do
     nspk=$(wc -l <data/$x/spk2utt)
     [ "$nspk" -gt "$decode_nj" ] && nspk=$decode_nj
     steps/nnet3/decode.sh --nj $nspk --cmd "$decode_cmd" \
       --acwt 1.0 --post-decode-acwt 10.0 \
       --online-ivector-dir exp/nnet3${nnet3_affix}/ivectors_${x}_hires \
       --scoring-opts "--min-lmwt 5 " \
       $dir/graph data/${x}_hires $dir/decode_${x} || exit 1;
     steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" data/lang_s_test_{tgpr,fgconst} \
       data/${x}_hires ${dir}/decode_${x} ${dir}/decode_${x}_rescore || exit
   done
 fi
echo "finished chain model..."
exit 0
