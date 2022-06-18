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
decode=false	# set to false to disable the decoding-related scripts.

. ./cmd.sh	## You'll want to change cmd.sh to something that will work on your system.
           	## This relates to the queue.
 
nj=20;
decode_nj=20;
[ ! -e steps ] && ln -s ../../wsj/s5/steps steps
[ ! -e utils ] && ln -s ../../wsj/s5/utils utils
          	
. utils/parse_options.sh  # e.g. this parses the --stage option if supplied.

cgn=/tudelft.net/staff-bulk/ewi/insy/SpeechLab/CGN/CGN_2.0.3			# point this to CGN
lang="nl"
comp="a;b;c;d;e;f;g;h;i;j;k;l;m;n;o"
nj=20;
decode_nj=20;

if [ $stage -le -1 ]; then
  echo "Data preparation-Lexicon and LM"

  # the script detects if a telephone comp is used and splits this into a separate set
  # later, studio and telephone speech can be combined for NNet training
  local/cgn_data_lex_prep.sh $cgn $lang $comp || exit 1;

  # the text in cleaned.gz is used to train the lm..
  cat data/train/text | cut -d' ' -f2- | gzip -c >data/local/dict_nosp/cleaned.gz
  # you are encouraged to use your own additional data for training and tune the pruning
  # in the following script accordingly
  local/jas_train_lms.sh --dict-suffix "_nosp"
  local/jas_format_local_lms.sh --lang-suffix "_nosp"
fi

if [ $stage -le 0 ]; then

  for x in train test; do
    steps/make_mfcc.sh --cmd "$train_cmd" --nj $nj data/$x || exit 1;
    steps/compute_cmvn_stats.sh data/$x || exit 1;
  done

  for x in train test; do
    steps/make_mfcc.sh --cmd "$train_cmd" --nj $nj --mfcc-config conf/mfcc.conf data/$x || exit 1;
    steps/compute_cmvn_stats.sh data/$x || exit 1;
  done
	
  # Make subsets with 5k random utterances from train.
  # using only the shortest ones doesn't work as these are too similar
  for x in train; do
    utils/subset_data_dir.sh data/$x 5000 data/${x}_5k || exit 1;
  done
		
  # do a final cleanup
  for x in train test; do
    utils/fix_data_dir.sh data/$x
  done
fi

if [ $stage -le 1 ]; then
  # monophone
  if $train; then
    for x in train; do
      steps/train_mono.sh --nj $nj --cmd "$train_cmd" \
        data/${x}_5k data/lang_nosp exp/mono0a || exit 1;
    done
  fi
	
  if $decode; then
    for x in test; do
      utils/mkgraph.sh data/lang_nosp_test_tgpr exp/mono0a exp/mono0a/graph_nosp_tgpr
      nspk=$(wc -l <data/test/spk2utt)
      [ "$nspk" -gt "$decode_nj" ] && nspk=$decode_nj
      steps/decode.sh --nj $nspk --cmd "$decode_cmd" \
        exp/mono0a/graph_nosp_tgpr data/test exp/mono0a/decode_nosp_tgpr
    done
  fi
fi

if [ $stage -le 2 ]; then
  # tri1
  if $train; then
    for x in train; do
      steps/align_si.sh --nj $nj --cmd "$train_cmd" \
        data/${x}_5k data/lang_nosp exp/mono0a exp/mono0a_ali || exit 1;
      steps/train_deltas.sh --cmd "$train_cmd" 2000 10000 \
        data/${x}_5k data/lang_nosp exp/mono0a_ali exp/tri1 || exit 1;
    done
  fi
	
  if $decode; then
    for x in test; do
      utils/mkgraph.sh data/lang_nosp_test_tgpr exp/tri1 exp/tri1/graph_nosp_tgpr || exit 1;
      nspk=$(wc -l <data/test/spk2utt)
      [ "$nspk" -gt "$decode_nj" ] && nspk=$decode_nj
      steps/decode.sh --nj $nspk --cmd "$decode_cmd" \
        exp/tri1/graph_nosp_tgpr data/test exp/tri1/decode_nosp_tgpr || exit 1;
      # due to the following command not accepting the scoring options, we made --combine false the default for local/score.sh
      steps/lmrescore.sh --mode 4 --cmd "$decode_cmd" \
        data/lang_nosp_test_{tgpr,tg} data/test \
        exp/tri1/decode_nosp_tgpr \
        exp/tri1/decode_nosp_tgpr_tg || exit 1;
    done
  fi
fi

if [ $stage -le 3 ]; then
  # tri2
  if $train; then
    for x in train; do
      steps/align_si.sh --nj $nj --cmd "$train_cmd" \
        data/$x data/lang_nosp exp/tri1 exp/tri1_ali || exit 1;

      steps/train_lda_mllt.sh --cmd "$train_cmd" \
        --splice-opts "--left-context=3 --right-context=3" 2500 15000 \
        data/$x data/lang_nosp exp/tri1_ali exp/tri2 || exit 1;
    done
  fi

  if $decode; then
    for x in test; do
      utils/mkgraph.sh data/lang_nosp_test_tgpr exp/tri2 exp/tri2/graph_nosp_tgpr || exit 1;
      nspk=$(wc -l <data/test/spk2utt)
      [ "$nspk" -gt "$decode_nj" ] && nspk=$decode_nj
      steps/decode.sh --nj $nspk --cmd "$decode_cmd" exp/tri2/graph_nosp_tgpr \
        data/test exp/tri2/decode_nosp_tgpr || exit 1;
      # compare lattice rescoring with biglm decoding, going from tgpr to tg.
      steps/decode_biglm.sh --nj $nspk --cmd "$decode_cmd" \
        exp/tri2/graph_nosp_tgpr data/lang_nosp_test_{tgpr,tg}/G.fst \
        data/test exp/tri2/decode_nosp_tgpr_tg_biglm
      # baseline via LM rescoring of lattices.
      steps/lmrescore.sh --cmd "$decode_cmd" \
        data/lang_nosp_test_tgpr/ data/lang_nosp_test_tg/ \
        data/test exp/tri2/decode_nosp_tgpr \
        exp/tri2/decode_nosp_tgpr_tg || exit 1;
      # Demonstrating Minimum Bayes Risk decoding (like Confusion Network decoding):
      mkdir exp/tri2/decode_nosp_tgpr_tg_mbr
      cp exp/tri2/decode_nosp_tgpr_tg/lat.*.gz exp/tri2/decode_nosp_tgpr_tg_mbr;
      local/score_mbr.sh --cmd "$decode_cmd"  \
        data/test data/lang_nosp_test_tgpr/ \
        exp/tri2/decode_nosp_tgpr_tg_mbr
    done
  fi
fi

if [ $stage -le 4 ]; then
  # Estimate pronunciation and silence probabilities.
  model=tri2

  # Silprob for normal lexicon.
  for x in train; do
    steps/get_prons.sh --cmd "$train_cmd" data/train data/lang_nosp exp/$model || exit 1;
    utils/dict_dir_add_pronprobs.sh --max-normalize true \
      data/local/dict_nosp \
      exp/$model/pron_counts_nowb.txt exp/$model/sil_counts_nowb.txt \
      exp/$model/pron_bigram_counts_nowb.txt data/local/dict || exit 1

    utils/prepare_lang.sh data/local/dict \
      "<unk>" data/local/lang_tmp data/lang_test || exit 1;

    for lm_suffix in tg tgpr fgconst; do
      mkdir -p data/lang_test_${lm_suffix}
      cp -r data/lang_test/* data/lang_test_${lm_suffix}/ || exit 1;
      rm -rf data/lang_test_${lm_suffix}/tmp
      cp data/lang_nosp_test_${lm_suffix}/G.* data/lang_test_${lm_suffix}/
    done
  done
fi

if [ $stage -le 5 ]; then
  # From tri2 system, train tri3 which is LDA + MLLT + SAT.
  # now using data/lang as the lang directory (we have now added
  # pronunciation and silence probabilities)

  if $train; then
    for x in test; do
      steps/align_si.sh --nj $nj --cmd "$train_cmd" \
        data/train data/lang_${x} exp/tri2 exp/tri2_ali  || exit 1;
      steps/train_sat.sh --cmd "$train_cmd" 5000 80000 \
        data/train data/lang_${x} exp/tri2_ali exp/tri3 || exit 1;
    done
  fi

  if $decode; then
    for x in test; do
      utils/mkgraph.sh data/lang_test_tgpr exp/tri3 exp/tri3/graph_tgpr || exit 1;
      nspk=$(wc -l <data/test/spk2utt)
      [ "$nspk" -gt "$decode_nj" ] && nspk=$decode_nj
      steps/decode_fmllr.sh --nj $nspk --cmd "$decode_cmd" \
        exp/tri3/graph_tgpr data/test \
        exp/tri3/decode_tgpr || exit 1;
      steps/lmrescore_const_arpa.sh \
        --cmd "$decode_cmd" data/lang_test_{tgpr,fgconst} \
        data/test exp/tri3/decode_tgpr{,_fg} || exit 1;
    done
  fi
fi

# # It is time to clean up our data a bit
# # this takes quite a while.. and is actually only really helpful for the NNet models,
# # so if you're not going to make those, you may as well stop here.

 if [ $stage -le 7 ]; then  
   for x in train; do
     steps/cleanup/clean_and_segment_data.sh --nj $nj --cmd "$train_cmd" --segmentation-opts "--min-segment-length 0.3 --min-new-segment-length 0.6" \
       data/train data/lang_test exp/tri3 exp/tri3_cleaned_work data/train_cleaned
   done
 fi

 if [ $stage -le 9 ]; then
   # Do one more pass of sat training.
   if $train; then
     # use studio models for this alignment pass
     steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" \
       data/train data/lang_test exp/tri3 exp/tri3_ali
     steps/train_sat.sh  --cmd "$train_cmd" 5000 80000 \
       data/train data/lang_test exp/tri3_ali exp/tri4 || exit 1;
   fi

    decode=true
    if $decode; then
      utils/mkgraph.sh data/lang_test_tgpr exp/tri4 exp/tri4/graph_tgpr || exit 1;
      for x in test; do
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
 
if [ $stage -le 10 ]; then
  steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" \
    data/train data/lang_test exp/tri4 exp/tri4_ali || exit 1 
fi
 # To train nnet models, please run local/chain/run_tdnn.sh

# exit 0;
echo "succeeded"
