#!/bin/bash

#
# This script was adapted from the WSJ/s5 example by LvdW and modified by Siyuan Feng.
# This version of the script, uses only Jamin corpus to train and test the system.

# You need Corpus Gesproken Nederlands to use this.
# This is available from TST-centrale: http://tst-centrale.org/nl/tst-materialen/corpora/corpus-gesproken-nederlands-detail
#
# The script can train both studio and telephone models (automatically detected from comp)
# We keep these separate as that works best for GMM/HMM. Before follow-up training
# with nnet models, the two training sets get combined again.
#
# By default a fully functioning set of models is created using only CGN. Better performance may be had by
# using more material for the language model and by extending your lexicon.
#
# This version uses lexicon from the CGN corpus and LM from the Jasmin training data

stage=-1 # note that stage 7 is incomplete due to code bug in tri3_cleaned_work
train=true	# set to false to disable the training-related scripts
				# note: you probably only want to set --train false if you
				# are using at least --stage 1.
decode=true	# set to false to disable the decoding-related scripts.

. ./cmd.sh	## You'll want to change cmd.sh to something that will work on your system.
           	## This relates to the queue.
 
nj=10;
decode_nj=20;
[ ! -e steps ] && ln -s ../../wsj/s5/steps steps
[ ! -e utils ] && ln -s ../../wsj/s5/utils utils
          	
. utils/parse_options.sh  # e.g. this parses the --stage option if supplied.

nj=10;
decode_nj=20;

test_folders="test_copy test_male test_female test_age_1 test_age_2 test_age_5 test_read test_conv"
if [ $stage -le 0 ]; then

  for x in ${test_folders}; do
    steps/make_mfcc.sh --cmd "$train_cmd" --nj $nj --mfcc-config conf/mfcc.conf data/$x || exit 1;
    steps/compute_cmvn_stats.sh data/$x || exit 1;
  done
	
  # do a final cleanup
  for x in ${test_folders}; do
    utils/fix_data_dir.sh data/$x
  done
fi

if [ $stage -le 1 ]; then	
    if $decode; then
      #utils/mkgraph.sh data/lang_test_tgpr exp/tri4 exp/tri4/graph_tgpr || exit 1;
      for x in ${test_folders}; do
        nspk=$(wc -l <data/$x/spk2utt)
        [ "$nspk" -gt "$decode_nj" ] && nspk=$decode_nj
        steps/decode_fmllr.sh --nj $nspk --cmd "$decode_cmd" \
          exp/tri4/graph_tgpr data/$x \
          exp/tri4/decode_${x}_tgpr || exit 1;
        steps/lmrescore_const_arpa.sh \
          --cmd "$decode_cmd" data/lang_test_{tgpr,fgconst} \
          data/$x exp/tri4/decode_${x}_tgpr{,_fg} || exit 1;
      done
    fi
 fi
 
echo "-----------------------"
echo "succeeded Decoding"
echo "Make changes in in the test.sh files as per your testing folders to check WER"
echo "-----------------------"
