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
max_jobs_run=100
base_eval=dev_s # or dev_t_16khz
gender_eval=female # or male
remove_egs=false
stage=17
stop_stage=19
align_fmllr_lats_stage=-10
nj=1
decode_nj=1
num_threads_decode=1
min_seg_len=1.55
xent_regularize=0.025
train_set=train
train_set_feat= #if specified, use that for train_data, can be useful when your feature set is a subset of ali / lat set 
comp_suffix=
get_egs_stage=-10
gmm=tri4  # the gmm for the target data
num_threads_ubm=32
nnet3_affix=  # cleanup affix for nnet3 and chain dirs, e.g. _cleaned
decode_iter=final #acoustic model used in decoding 
# The rest are configs specific to this script.  Most of the parameters
# are just hardcoded at this level, in the commands below.
use_gpu=false
train_stage=-10
train_exit_stage=10000
tree_affix=  # affix for tree directory, e.g. "a" or "b", in case we change the configuration.
tdnn_cnn_affix=cnn_1a  #affix for TDNN directory, e.g. "a" or "b", in case we change the configuration.

dropout_schedule='0,0@0.20,0.3@0.50,0'
# decode options

# some settings dependent on the GPU, for a single GTX980Ti these settings seem to work ok.
#
# increase these if you have multiple GPUs

# TDNN options
frames_per_eg=150,110,100
remove_egs=true
xent_regularize=0.1
dropout_schedule='0,0@0.20,0.5@0.50,0'
num_jobs_initial=1
num_jobs_final=1
num_epochs=1
# change these for different amounts of memory
#num_chunks_per_minibatc=h"256,128,64"
num_chunks_per_minibatch="128,64"
frames_per_iter=3000000 #1500000
# resulting in around 2500 iters
# End configuration section.
echo "$0 $@"  # Print the command line for logging

. cmd.sh
. ./path.sh
. ./utils/parse_options.sh

if [ "$decode_iter" = "final" ]; then
  decode_iter_suffix=""
else
  decode_iter_suffix="_iter${decode_iter}"
fi

common_egs_dir=
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
ali_dir=exp/$train_set/${gmm}_ali_${train_set}_aug_sp_comb
tree_dir=exp/chain${nnet3_affix}/tree_aug_sp_bi${tree_affix}
#dir=exp/chain${nnet3_affix}/tdnn${tdnn_cnn_affix}_sp_bi
if [ -n "$train_set_feat" ]; then
  train_set_suffix="_${train_set_feat}"
  train_set2=$train_set_feat
else
  train_set_suffix=""
  train_set2=$train_set
fi
dir=exp/chain${nnet3_affix}/tdnnf_related/aug_related/tdnn_${tdnn_cnn_affix}${train_set_suffix}${comp_suffix}_sp_bi_epoch${num_epochs}

train_data_dir=data/${train_set2}${comp_suffix}_aug_sp_hires_comb
echo "Use $train_data_dir to train the model"
lores_train_data_dir=data/${train_set2}${comp_suffix}_aug_sp_comb
train_ivector_dir=exp/nnet3${nnet3_affix}/ivectors_aug_sp_${train_set}${comp_suffix}_aug_sp_hires_comb
lat_dir=exp/chain${nnet3_affix}/tdnnf_related/aug_related/${gmm}_${train_set2}${comp_suffix}_aug_sp_comb_lats

echo "$gmm_dir"
for f in $gmm_dir/final.mdl $train_data_dir/feats.scp $train_ivector_dir/ivector_online.scp \
    $lores_train_data_dir/feats.scp $ali_dir/ali.1.gz ; do
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

if [ $stage -le 15 ]  && [ $stop_stage -gt 15 ] ; then
  # Get the alignments as lattices (gives the chain training more freedom).
  # use the same num-jobs as the alignments
  steps/align_fmllr_lats.sh --stage $align_fmllr_lats_stage --nj $nj --cmd "$train_cmd --max-jobs-run $max_jobs_run" ${lores_train_data_dir} \
    data/lang_s $gmm_dir $lat_dir
  #rm $lat_dir/fsts.*.gz # save space
fi
echo "This is debug point"
if [ $stage -le 16 ]  && [ $stop_stage -gt 16 ]  ; then
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

if [ $stage -le 17 ]  && [ $stop_stage -gt 17 ] ; then
  mkdir -p $dir

  echo "$0: creating neural net configs using the xconfig parser";

  num_targets=$(tree-info $tree_dir/tree | grep num-pdfs | awk '{print $2}')
  learning_rate_factor=$(echo "print (0.5/$xent_regularize)" | python)
  cnn_opts="l2-regularize=0.01"
  ivector_affine_opts="l2-regularize=0.0"
  affine_opts="l2-regularize=0.008 dropout-proportion=0.0 dropout-per-dim=true dropout-per-dim-continuous=true"
  tdnnf_first_opts="l2-regularize=0.008 dropout-proportion=0.0 bypass-scale=0.0"
  tdnnf_opts="l2-regularize=0.008 dropout-proportion=0.0 bypass-scale=0.75"
  linear_opts="l2-regularize=0.008 orthonormal-constraint=-1.0"
  prefinal_opts="l2-regularize=0.008"
  output_opts="l2-regularize=0.005"

  mkdir -p $dir/configs
  cat <<EOF > $dir/configs/network.xconfig
  input dim=100 name=ivector
  input dim=40 name=input

  # MFCC to filterbank
  idct-layer name=idct input=input dim=40 cepstral-lifter=22 affine-transform-file=$dir/configs/idct.mat

  linear-component name=ivector-linear $ivector_affine_opts dim=200 input=ReplaceIndex(ivector, t, 0)
  batchnorm-component name=ivector-batchnorm target-rms=0.025
  batchnorm-component name=idct-batchnorm input=idct

  combine-feature-maps-layer name=combine_inputs input=Append(idct-batchnorm, ivector-batchnorm) num-filters1=1 num-filters2=5 height=40
  conv-relu-batchnorm-layer name=cnn1 $cnn_opts height-in=40 height-out=40 time-offsets=-1,0,1 height-offsets=-1,0,1 num-filters-out=64
  conv-relu-batchnorm-layer name=cnn2 $cnn_opts height-in=40 height-out=40 time-offsets=-1,0,1 height-offsets=-1,0,1 num-filters-out=64
  conv-relu-batchnorm-layer name=cnn3 $cnn_opts height-in=40 height-out=20 height-subsample-out=2 time-offsets=-1,0,1 height-offsets=-1,0,1 num-filters-out=128
  conv-relu-batchnorm-layer name=cnn4 $cnn_opts height-in=20 height-out=20 time-offsets=-1,0,1 height-offsets=-1,0,1 num-filters-out=128
  conv-relu-batchnorm-layer name=cnn5 $cnn_opts height-in=20 height-out=10 height-subsample-out=2 time-offsets=-1,0,1 height-offsets=-1,0,1 num-filters-out=256
  conv-relu-batchnorm-layer name=cnn6 $cnn_opts height-in=10 height-out=10 time-offsets=-1,0,1 height-offsets=-1,0,1 num-filters-out=256

  # the first TDNN-F layer has no bypass
  tdnnf-layer name=tdnnf7 $tdnnf_first_opts dim=1536 bottleneck-dim=256 time-stride=0
  tdnnf-layer name=tdnnf8 $tdnnf_opts dim=1536 bottleneck-dim=160 time-stride=3
  tdnnf-layer name=tdnnf9 $tdnnf_opts dim=1536 bottleneck-dim=160 time-stride=3
  tdnnf-layer name=tdnnf10 $tdnnf_opts dim=1536 bottleneck-dim=160 time-stride=3
  tdnnf-layer name=tdnnf11 $tdnnf_opts dim=1536 bottleneck-dim=160 time-stride=3
  tdnnf-layer name=tdnnf12 $tdnnf_opts dim=1536 bottleneck-dim=160 time-stride=3
  tdnnf-layer name=tdnnf13 $tdnnf_opts dim=1536 bottleneck-dim=160 time-stride=3
  tdnnf-layer name=tdnnf14 $tdnnf_opts dim=1536 bottleneck-dim=160 time-stride=3
  tdnnf-layer name=tdnnf15 $tdnnf_opts dim=1536 bottleneck-dim=160 time-stride=3
  tdnnf-layer name=tdnnf16 $tdnnf_opts dim=1536 bottleneck-dim=160 time-stride=3
  tdnnf-layer name=tdnnf17 $tdnnf_opts dim=1536 bottleneck-dim=160 time-stride=3
  tdnnf-layer name=tdnnf18 $tdnnf_opts dim=1536 bottleneck-dim=160 time-stride=3
  linear-component name=prefinal-l dim=256 $linear_opts

  ## adding the layers for chain branch
  prefinal-layer name=prefinal-chain input=prefinal-l $prefinal_opts big-dim=1536 small-dim=256
  output-layer name=output include-log-softmax=false dim=$num_targets $output_opts

  # adding the layers for xent branch
  prefinal-layer name=prefinal-xent input=prefinal-l $prefinal_opts big-dim=1536 small-dim=256
  output-layer name=output-xent dim=$num_targets learning-rate-factor=$learning_rate_factor $output_opts

EOF
  steps/nnet3/xconfig_to_configs.py --xconfig-file $dir/configs/network.xconfig --config-dir $dir/configs/

fi

 

if [ $stage -le 18 ] && [ $stop_stage -gt 18 ]; then

 steps/nnet3/chain/train.py --stage $train_stage --exit-stage $train_exit_stage  \
    --cmd "$decode_cmd" \
    --feat.online-ivector-dir $train_ivector_dir \
    --feat.cmvn-opts "--norm-means=false --norm-vars=false" \
    --chain.xent-regularize 0.1 \
    --chain.leaky-hmm-coefficient 0.1 \
    --chain.l2-regularize 0.0 \
    --chain.apply-deriv-weights false \
    --chain.lm-opts="--num-extra-lm-states=2000" \
    --egs.dir "$common_egs_dir" \
    --egs.stage $get_egs_stage \
    --egs.opts "--frames-overlap-per-eg 0 --constrained false" \
    --egs.chunk-width $frames_per_eg \
    --trainer.dropout-schedule $dropout_schedule \
    --trainer.num-chunk-per-minibatch $num_chunks_per_minibatch \
    --trainer.frames-per-iter $frames_per_iter \
    --trainer.num-epochs $num_epochs \
    --trainer.optimization.num-jobs-initial $num_jobs_initial \
    --trainer.optimization.num-jobs-final $num_jobs_final \
    --trainer.optimization.initial-effective-lrate 0.00015 \
    --trainer.max-param-change 2.0 \
    --cleanup.remove-egs $remove_egs \
    --feat-dir $train_data_dir \
    --tree-dir $tree_dir \
    --lat-dir $lat_dir \
    --use-gpu "wait" \
    --dir $dir
fi


if [ $stage -le 19 ] && [ $stop_stage -gt 19 ]  ; then
  # Note: it might appear that this data/lang_chain directory is mismatched, and it is as
  # far as the 'topo' is concerned, but this script doesn't read the 'topo' from
  # the lang directory.
  #utils/mkgraph.sh --self-loop-scale 1.0 data/lang_s_test_tgpr $dir $dir/graph
  utils/mkgraph.sh --self-loop-scale 1.0 data/lang_s_test_tgpr $tree_dir $dir/graph
fi

if [ $stage -le 20 ] && [ $stop_stage -gt 20  ]  ; then
  for x in dev_s dev_t_16khz; do
    nspk=$(wc -l <data/$x/spk2utt)
    [ "$nspk" -gt "$decode_nj" ] && nspk=$decode_nj
    steps/nnet3/decode.sh --num-threads $num_threads_decode --nj $nspk --cmd "$decode_cmd" \
      --use-gpu $use_gpu \
      --acwt 1.0 --post-decode-acwt 10.0 \
      --online-ivector-dir exp/nnet3${nnet3_affix}/ivectors_aug_sp_${x}_hires \
      --scoring-opts "--min-lmwt 5 " \
      --iter $decode_iter \
      $dir/graph data/${x}_hires $dir/decode_${x}${decode_iter_suffix} || exit 1;
    steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" data/lang_s_test_{tgpr,fgconst} \
      data/${x}_hires ${dir}/decode_${x}${decode_iter_suffix} ${dir}/decode_${x}${decode_iter_suffix}_rescore || exit
  done
fi

if [ $stage -le 21 ] && [ $stop_stage -gt 21 ]  ; then
  # evaluate gender-specific dev_s and dev_t
  #for x in dev_s dev_t_16khz; do
  for x in ${base_eval}_${gender_eval}  ; do
    nspk=$(wc -l <data/${x}_hires/spk2utt)
    [ "$nspk" -gt "$decode_nj" ] && nspk=$decode_nj
    steps/nnet3/decode.sh --num-threads $num_threads_decode --nj $nspk --cmd "$decode_cmd" \
      --use-gpu $use_gpu \
      --acwt 1.0 --post-decode-acwt 10.0 \
      --online-ivector-dir exp/nnet3${nnet3_affix}/ivectors_aug_sp_${base_eval}_hires \
      --scoring-opts "--min-lmwt 5 " \
      --iter $decode_iter \
      $dir/graph data/${x}_hires $dir/decode_${x}${decode_iter_suffix} || exit 1;
    steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" data/lang_s_test_{tgpr,fgconst} \
      data/${x}_hires ${dir}/decode_${x}${decode_iter_suffix} ${dir}/decode_${x}${decode_iter_suffix}_rescore || exit
  done
fi

echo "finished chain model..."
#exit 0
