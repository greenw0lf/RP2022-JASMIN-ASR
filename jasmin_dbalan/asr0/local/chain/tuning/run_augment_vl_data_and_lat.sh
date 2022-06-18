#!/bin/bash

# First augment $low_resolution_data and $hires_data
. ./path.sh
stage=1
nj=30
align_fmllr_lats_stage=2
train_set=train
. ./cmd.sh
. ./utils/parse_options.sh
nl_dir=/tudelft.net/staff-bulk/ewi/insy/SpeechLab/siyuanfeng/software/kaldi/egs/cgn/s5
vl_dir=/tudelft.net/staff-bulk/ewi/insy/SpeechLab/siyuanfeng/software/kaldi/egs/cgn/s5_vl_only/
# if [ $stage -le 1 ]; then

# 	lores_train_data_dir_nl=$nl_dir/data/${train_set}_sp_comb
# 	lores_train_data_dir_vl=$vl_dir/data/${train_set}_sp_comb
# 	bash utils/combine_data.sh $nl_dir/data_aug_nl_vl/${train_set}_sp_comb $lores_train_data_dir_nl $lores_train_data_dir_vl || exit 1;
# 	hires_train_data_dir_nl=$nl_dir/data/${train_set}_sp_hires_comb
# 	hires_train_data_dir_vl=$vl_dir/data/${train_set}_sp_hires_comb
# 	bash utils/combine_data.sh $nl_dir/data_aug_nl_vl/${train_set}_sp_hires_comb $hires_train_data_dir_nl $hires_train_data_dir_vl || exit 1;
# fi
# Then generate $lat_dir with NL exp/train/tri4 model and augmented $low_resolution data.
lores_train_data_dir=$nl_dir/data_aug_nl_vl/${train_set}_sp_comb
gmm=tri4  # the gmm for the target data

gmm_dir=exp/$train_set/$gmm
lat_dir=exp/chain${nnet3_affix}/${gmm}_aug_nl_vl_${train_set}_sp_comb_lats

if [ $stage -le 2 ]; then
  # Get the alignments as lattices (gives the chain training more freedom).
  # use the same num-jobs as the alignments
  steps/align_fmllr_lats.sh --stage $align_fmllr_lats_stage  --nj $nj --cmd "$train_cmd" ${lores_train_data_dir} \
    data/lang_s $gmm_dir $lat_dir
  #rm $lat_dir/fsts.*.gz # save space
fi


echo "$0: succeeded"
