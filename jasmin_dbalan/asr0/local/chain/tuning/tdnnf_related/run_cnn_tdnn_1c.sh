#!/bin/bash

# 1g is like 1f but upgrading to a "resnet-style TDNN-F model", i.e.
#   with bypass resnet connections, and re-tuned.

# local/chain/compare_wer.sh exp/chain/tdnn1f_sp exp/chain/tdnn1g_sp
# System                tdnn1f_sp tdnn1g_sp
#WER dev93 (tgpr)                7.03      6.68
#WER dev93 (tg)                  6.83      6.57
#WER dev93 (big-dict,tgpr)       4.99      4.60
#WER dev93 (big-dict,fg)         4.52      4.26
#WER eval92 (tgpr)               5.19      4.54
#WER eval92 (tg)                 4.73      4.32
#WER eval92 (big-dict,tgpr)      2.94      2.62
#WER eval92 (big-dict,fg)        2.68      2.32
# Final train prob        -0.0461   -0.0417
# Final valid prob        -0.0588   -0.0487
# Final train prob (xent)   -0.9042   -0.6461
# Final valid prob (xent)   -0.9447   -0.6882
# Num-params                 6071244   8354636

# steps/info/chain_dir_info.pl exp/chain/tdnn1g_sp
# exp/chain/tdnn1g_sp: num-iters=108 nj=2..8 num-params=8.4M dim=40+100->2854 combine=-0.042->-0.042 (over 2) xent:train/valid[71,107,final]=(-0.975,-0.640,-0.646/-0.980,-0.678,-0.688) logprob:train/valid[71,107,final]=(-0.067,-0.043,-0.042/-0.069,-0.050,-0.049)

set -e -o pipefail

# First the options that are passed through to run_ivector_common.sh
# (some of which are also used in this script directly).
stage=15 # 14 and before are shared with other nnet3-chain experiments, do not re-run
stop_stage=16
nj=30
train_set=train
test_sets="dev_s dev_t_16khz"
gmm=tri4         # this is the source gmm-dir that we'll use for alignments; it
                 # should have alignments for the specified training data.

num_threads_ubm=8

nj_extractor=10
# It runs a JOB with '-pe smp N', where N=$[threads*processes]
num_threads_extractor=4
num_processes_extractor=2
num_jobs_initial=1
num_jobs_final=1
num_epochs=10
nnet3_affix=       # affix for exp dirs, e.g. it was _cleaned in tedlium.

# Options which are not passed through to run_ivector_common.sh
affix=1g   #affix for TDNN+LSTM directory e.g. "1a" or "1b", in case we change the configuration.
common_egs_dir= #exp/chain/tdnnf_related/tdnn1g_sp_bi_epoch3/egs/
reporting_email=

# LSTM/chain options
train_stage=-10
train_exit_stage=10000
egs_stage=-10
tree_affix=
xent_regularize=0.1
dropout_schedule='0,0@0.20,0.5@0.50,0'
num_chunks_per_minibatch="128,64"
# training chunk-options
chunk_width=140,100,160
# we don't need extra left/right context for TDNN systems.
chunk_left_context=0
chunk_right_context=0

# training options
srand=0
remove_egs=false

#decode options
test_online_decoding=false  # if true, it will run the last decoding stage.
num_threads_decode=1
decode_nj=1

# End configuration section.
echo "$0 $@"  # Print the command line for logging


. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh


if ! cuda-compiled; then
  cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
fi

#local/nnet3/run_ivector_common.sh \
#  --stage $stage --nj $nj \
#  --train-set $train_set --gmm $gmm \
#  --num-threads-ubm $num_threads_ubm \
#  --nj-extractor $nj_extractor \
#  --num-processes-extractor $num_processes_extractor \
#  --num-threads-extractor $num_threads_extractor \
#  --nnet3-affix "$nnet3_affix"



gmm_dir=exp/$train_set/${gmm}
ali_dir=exp/$train_set/${gmm}_ali_${train_set}_sp_comb
lat_dir=exp/chain${nnet3_affix}/${gmm}_${train_set}_sp_comb_lats
dir=exp/chain${nnet3_affix}/tdnnf_related/cnn_tdnn${affix}_sp_bi_epoch${num_epochs}
train_data_dir=data/${train_set}_sp_hires_comb
train_ivector_dir=exp/nnet3${nnet3_affix}/ivectors_${train_set}_sp_hires_comb
lores_train_data_dir=data/${train_set}_sp_comb

# note: you don't necessarily have to change the treedir name
# each time you do a new experiment-- only if you change the
# configuration in a way that affects the tree.
tree_dir=exp/chain${nnet3_affix}/tree_bi${tree_affix} #same as in chain non-tdnnf models
# the 'lang' directory is created by this script.
# If you create such a directory with a non-standard topology
# you should probably name it differently.
lang=data/lang_chain

for f in $train_data_dir/feats.scp $train_ivector_dir/ivector_online.scp \
    $lores_train_data_dir/feats.scp $gmm_dir/final.mdl \
    $ali_dir/ali.1.gz $gmm_dir/final.mdl; do
  [ ! -f $f ] && echo "$0: expected file $f to exist" && exit 1
done


if [ $stage -le 12 ] && [ $stop_stage -gt 12 ]  ; then
  echo "$0: creating lang directory $lang with chain-type topology"
  # Create a version of the lang/ directory that has one state per phone in the
  # topo file. [note, it really has two states.. the first one is only repeated
  # once, the second one has zero or more repeats.]
  if [ -d $lang ]; then
    if [ $lang/L.fst -nt data/lang/L.fst ]; then
      echo "$0: $lang already exists, not overwriting it; continuing"
    else
      echo "$0: $lang already exists and seems to be older than data/lang..."
      echo " ... not sure what to do.  Exiting."
      exit 1;
    fi
  else
    cp -r data/lang_s $lang
    silphonelist=$(cat $lang/phones/silence.csl) || exit 1;
    nonsilphonelist=$(cat $lang/phones/nonsilence.csl) || exit 1;
    # Use our special topology... note that later on may have to tune this
    # topology.
    steps/nnet3/chain/gen_topo.py $nonsilphonelist $silphonelist >$lang/topo
  fi
fi

if [ $stage -le 13 ] && [ $stop_stage -gt 13 ]  ; then
  # Get the alignments as lattices (gives the chain training more freedom).
  # use the same num-jobs as the alignments
  steps/align_fmllr_lats.sh --nj 100 --cmd "$train_cmd" ${lores_train_data_dir} \
    data/lang_s $gmm_dir $lat_dir
#  rm $lat_dir/fsts.*.gz # save space
fi

if [ $stage -le 14 ] && [ $stop_stage -gt 14 ]  ; then
  # Build a tree using our new topology.  We know we have alignments for the
  # speed-perturbed data (local/nnet3/run_ivector_common.sh made them), so use
  # those.  The num-leaves is always somewhat less than the num-leaves from
  # the GMM baseline.
   if [ -f $tree_dir/final.mdl ]; then
     echo "$0: $tree_dir/final.mdl already exists, refusing to overwrite it."
     exit 1;
  fi
  steps/nnet3/chain/build_tree.sh \
    --frame-subsampling-factor 3 \
    --context-opts "--context-width=2 --central-position=1" \
    --leftmost-questions-truncate -1 \
    --cmd "$train_cmd" 4000 ${lores_train_data_dir} \
    $lang $ali_dir $tree_dir
fi


if [ $stage -le 15 ] && [ $stop_stage -gt 15 ]  ; then
  mkdir -p $dir
  echo "$0: creating neural net configs using the xconfig parser";

  num_targets=$(tree-info $tree_dir/tree |grep num-pdfs|awk '{print $2}')
  learning_rate_factor=$(echo "print(0.5/$xent_regularize)" | python)
#  tdnn_opts="l2-regularize=0.01 dropout-proportion=0.0 dropout-per-dim-continuous=true"
  tdnnf_opts="l2-regularize=0.01 dropout-proportion=0.0 bypass-scale=0.66"
  linear_opts="l2-regularize=0.01 orthonormal-constraint=-1.0"
  prefinal_opts="l2-regularize=0.01"
  output_opts="l2-regularize=0.005"
  tdnnf_first_opts="l2-regularize=0.01 dropout-proportion=0.0 bypass-scale=0.0"

  mkdir -p $dir/configs
  cat <<EOF > $dir/configs/network.xconfig
  input dim=100 name=ivector
  input dim=40 name=input

  # this takes the MFCCs and generates filterbank coefficients.  The MFCCs
  # are more compressible so we prefer to dump the MFCCs to disk rather
  # than filterbanks.
  idct-layer name=idct input=input dim=40 cepstral-lifter=22 affine-transform-file=$dir/configs/idct.mat

  linear-component name=ivector-linear $ivector_affine_opts dim=200 input=ReplaceIndex(ivector, t, 0)
  batchnorm-component name=ivector-batchnorm target-rms=0.025

  batchnorm-component name=idct-batchnorm input=idct
  combine-feature-maps-layer name=combine_inputs input=Append(idct-batchnorm, ivector-batchnorm) num-filters1=1 num-filters2=5 height=40

  conv-relu-batchnorm-layer name=cnn1 $cnn_opts height-in=40 height-out=40 time-offsets=-1,0,1 height-offsets=-1,0,1 num-filters-out=48 learning-rate-factor=0.333 max-change=0.25
  conv-relu-batchnorm-layer name=cnn2 $cnn_opts height-in=40 height-out=40 time-offsets=-1,0,1 height-offsets=-1,0,1 num-filters-out=48
  conv-relu-batchnorm-layer name=cnn3 $cnn_opts height-in=40 height-out=20 height-subsample-out=2 time-offsets=-1,0,1 height-offsets=-1,0,1 num-filters-out=64
  conv-relu-batchnorm-layer name=cnn4 $cnn_opts height-in=20 height-out=20 time-offsets=-1,0,1 height-offsets=-1,0,1 num-filters-out=64
  conv-relu-batchnorm-layer name=cnn5 $cnn_opts height-in=20 height-out=10 height-subsample-out=2 time-offsets=-1,0,1 height-offsets=-1,0,1 num-filters-out=64
  conv-relu-batchnorm-layer name=cnn6 $cnn_opts height-in=10 height-out=5 height-subsample-out=2 time-offsets=-1,0,1 height-offsets=-1,0,1 num-filters-out=128

  # the first TDNN-F layer has no bypa
  tdnnf-layer name=tdnnf0 $tdnnf_first_opts dim=1024 bottleneck-dim=256 time-stride=0
  tdnnf-layer name=tdnnf1 $tdnnf_opts dim=1024 bottleneck-dim=128 time-stride=3
  tdnnf-layer name=tdnnf2 $tdnnf_opts dim=1024 bottleneck-dim=128 time-stride=1
  tdnnf-layer name=tdnnf3 $tdnnf_opts dim=1024 bottleneck-dim=128 time-stride=1
  tdnnf-layer name=tdnnf4 $tdnnf_opts dim=1024 bottleneck-dim=128 time-stride=1
  tdnnf-layer name=tdnnf5 $tdnnf_opts dim=1024 bottleneck-dim=128 time-stride=0
  tdnnf-layer name=tdnnf6 $tdnnf_opts dim=1024 bottleneck-dim=128 time-stride=3
  tdnnf-layer name=tdnnf7 $tdnnf_opts dim=1024 bottleneck-dim=128 time-stride=3
  tdnnf-layer name=tdnnf8 $tdnnf_opts dim=1024 bottleneck-dim=128 time-stride=3
  tdnnf-layer name=tdnnf9 $tdnnf_opts dim=1024 bottleneck-dim=128 time-stride=3
  tdnnf-layer name=tdnnf10 $tdnnf_opts dim=1024 bottleneck-dim=128 time-stride=3
  tdnnf-layer name=tdnnf11 $tdnnf_opts dim=1024 bottleneck-dim=128 time-stride=3
  tdnnf-layer name=tdnnf12 $tdnnf_opts dim=1024 bottleneck-dim=128 time-stride=3
  tdnnf-layer name=tdnnf13 $tdnnf_opts dim=1024 bottleneck-dim=128 time-stride=3
  linear-component name=prefinal-l dim=192 $linear_opts


  prefinal-layer name=prefinal-chain input=prefinal-l $prefinal_opts big-dim=1024 small-dim=192
  output-layer name=output include-log-softmax=false dim=$num_targets $output_opts

  prefinal-layer name=prefinal-xent input=prefinal-l $prefinal_opts big-dim=1024 small-dim=192
  output-layer name=output-xent dim=$num_targets learning-rate-factor=$learning_rate_factor $output_opts
EOF
  steps/nnet3/xconfig_to_configs.py --xconfig-file $dir/configs/network.xconfig --config-dir $dir/configs/
fi


if [ $stage -le 16 ] && [ $stop_stage -gt 16 ] ; then
  if [[ $(hostname -f) == *.clsp.jhu.edu ]] && [ ! -d $dir/egs/storage ]; then
    utils/create_split_dir.pl \
     /export/b0{3,4,5,6}/$USER/kaldi-data/egs/wsj-$(date +'%m_%d_%H_%M')/s5/$dir/egs/storage $dir/egs/storage
  fi

  steps/nnet3/chain/train.py --stage=$train_stage --exit-stage $train_exit_stage \
    --cmd="$decode_cmd" \
    --feat.online-ivector-dir=$train_ivector_dir \
    --feat.cmvn-opts="--norm-means=false --norm-vars=false" \
    --chain.xent-regularize $xent_regularize \
    --chain.leaky-hmm-coefficient=0.1 \
    --chain.l2-regularize=0.0 \
    --chain.apply-deriv-weights=false \
    --chain.lm-opts="--num-extra-lm-states=2000" \
    --trainer.dropout-schedule $dropout_schedule \
    --trainer.add-option="--optimization.memory-compression-level=2" \
    --trainer.srand=$srand \
    --trainer.max-param-change=2.0 \
    --trainer.num-epochs=$num_epochs \
    --trainer.frames-per-iter=5000000 \
    --trainer.optimization.num-jobs-initial=$num_jobs_initial \
    --trainer.optimization.num-jobs-final=$num_jobs_final \
    --trainer.optimization.initial-effective-lrate=0.0005 \
    --trainer.optimization.final-effective-lrate=0.00005 \
    --trainer.num-chunk-per-minibatch=$num_chunks_per_minibatch \
    --trainer.optimization.momentum=0.0 \
    --egs.chunk-width=$chunk_width \
    --egs.chunk-left-context=0 \
    --egs.chunk-right-context=0 \
    --egs.dir="$common_egs_dir" \
    --egs.opts="--frames-overlap-per-eg 0" \
    --egs.stage=$egs_stage \
    --cleanup.remove-egs=$remove_egs \
    --use-gpu=true \
    --reporting.email="$reporting_email" \
    --feat-dir=$train_data_dir \
    --tree-dir=$tree_dir \
    --lat-dir=$lat_dir \
    --dir=$dir  || exit 1;
fi

if [ $stage -le 17 ]  && [ $stop_stage -gt 17 ] ; then
  # The reason we are using data/lang here, instead of $lang, is just to
  # emphasize that it's not actually important to give mkgraph.sh the
  # lang directory with the matched topology (since it gets the
  # topology file from the model).  So you could give it a different
  # lang directory, one that contained a wordlist and LM of your choice,
  # as long as phones.txt was compatible.

  utils/lang/check_phones_compatible.sh \
    data/lang_s_test_tgpr/phones.txt $lang/phones.txt
  utils/mkgraph.sh \
    --self-loop-scale 1.0 data/lang_s_test_tgpr \
    $dir $dir/graph || exit 1;

fi

if [ $stage -le 18 ] && [ $stop_stage -gt 18 ]  ; then
  frames_per_chunk=$(echo $chunk_width | cut -d, -f1)
  rm $dir/.error 2>/dev/null || true

  for data in $test_sets; do
      nspk=$(wc -l <data/${data}_hires/spk2utt)
      [ "$nspk" -gt "$decode_nj" ] && nspk=$decode_nj
      steps/nnet3/decode.sh \
        --acwt 1.0 --post-decode-acwt 10.0 \
        --extra-left-context 0 --extra-right-context 0 \
        --extra-left-context-initial 0 \
        --extra-right-context-final 0 \
        --frames-per-chunk $frames_per_chunk \
        --nj $nspk --cmd "$decode_cmd"  --num-threads $num_threads_decode \
        --online-ivector-dir exp/nnet3${nnet3_affix}/ivectors_${data}_hires \
        $dir/graph data/${data}_hires ${dir}/decode_${data} || exit 1
      steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" \
        data/lang_s_test_{tgpr,fgconst} \
       data/${data}_hires ${dir}/decode_${data}{,_rescore} || exit 1
  done
  wait
  [ -f $dir/.error ] && echo "$0: there was a problem while decoding" && exit 1
fi

# Not testing the 'looped' decoding separately, because for
# TDNN systems it would give exactly the same results as the
# normal decoding.

#if $test_online_decoding && [ $stage -le 19 ]; then
#  # note: if the features change (e.g. you add pitch features), you will have to
#  # change the options of the following command line.
#  steps/online/nnet3/prepare_online_decoding.sh \
#    --mfcc-config conf/mfcc_hires.conf \
#    $lang exp/nnet3${nnet3_affix}/extractor ${dir} ${dir}_online
#
#  rm $dir/.error 2>/dev/null || true
#
#  for data in $test_sets; do
#    (
#      data_affix=$(echo $data | sed s/test_//)
#      nspk=$(wc -l <data/${data}_hires/spk2utt)
#      # note: we just give it "data/${data}" as it only uses the wav.scp, the
#      # feature type does not matter.
#      for lmtype in tgpr bd_tgpr; do
#        steps/online/nnet3/decode.sh \
#          --acwt 1.0 --post-decode-acwt 10.0 \
#          --nj $nspk --cmd "$decode_cmd" \
#          $tree_dir/graph data/${data} ${dir}_online/decode_${lmtype}_${data_affix} || exit 1
#      done
#      steps/lmrescore.sh \
#        --self-loop-scale 1.0 \
#        --cmd "$decode_cmd" data/lang_test_{tgpr,tg} \
#        data/${data}_hires ${dir}_online/decode_{tgpr,tg}_${data_affix} || exit 1
#      steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" \
#        data/lang_test_bd_{tgpr,fgconst} \
#       data/${data}_hires ${dir}_online/decode_${lmtype}_${data_affix}{,_fg} || exit 1
#    ) || touch $dir/.error &
#  done
#  wait
#  [ -f $dir/.error ] && echo "$0: there was a problem while decoding" && exit 1
#fi

echo "finished chain model..."
exit 0;