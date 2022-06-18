#!/bin/bash
# Copyright 2022 Tanvina Patel (TU Delft)
# Based on egs/jas/s5/local/jas_data_prep.sh by Laurens van der Werff and Siyuang Feng 
# Preparation for Jasmin Lexicon


# Preparation for CGN data by LvdW

if [ $# -le 1 ]; then
   echo "Arguments should be <jasmin root> <language>, see ../run.sh for example."
   exit 1;
fi

jas=$1
lang=$2

base=`pwd`
dir=`pwd`/data/local/data
lmdir=`pwd`/data/local/jas_lm
dictdir=`pwd`/data/local/dict_nosp
mkdir -p $dir $lmdir
local=`pwd`/local
utils=`pwd`/utils

. ./path.sh     # Needed for KALDI_ROOT

if [ -z $SRILM ] ; then
  export SRILM=$KALDI_ROOT/tools/srilm
fi
export PATH=${PATH}:$SRILM/bin/i686-m64
if ! command -v ngram-count >/dev/null 2>&1 ; then
  echo "$0: Error: SRILM is not available or compiled" >&2
  echo "$0: Error: To install it, go to $KALDI_ROOT/tools" >&2
  echo "$0: Error: and run extras/install_srilm.sh" >&2
  exit 1
fi

cd $dir

# prepare lexicon
# jaslex_2.0.lex  : single word lexicon
# lex_2.0.dtd     : DTD describing the single word lexico
# jasmlex_2.0.lex : multi-word lexicon
# mlex_2.0.dtd    : DTD describing the multi-word lexicon
# If you have a lexicon prepared, you can simply place it in $dictdir and it will be used instead of the default CGN one
if [ ! -f $dictdir/lexicon.txt ]; then
        mkdir -p $dictdir
        #[ -e $jas/data/lexicon/xml/jaslex.lex ] && cat $jas/data/lexicon/xml/jaslex.lex | recode -d h..u8 | perl -CSD $local/format_lexicon.pl $lang | sort >$dictdir/lexicon.txt
        [ -e $jas/data/lexicon/text/$lang/lexicon_iso.txt ] && cat $jas/data/lexicon/text/$lang/lexicon_sgml.txt |  perl -CSD $local/format_lexicon.pl $lang | sort >$dictdir/lexicon.txt
        #[ -e $jas/data/lexicon/xml/jaslex_2.0.lex ] && cat $jas/data/lexicon/xml/jaslex_2.0.lex | recode -d h..u8 | perl -CSD $local/format_lexicon.pl $lang | sort >$dictdir/lexicon.txt
        #[ -e $jas/data/lexicon/xml/jaslex_2.0.lex ] && cat $jas/data/lexicon/xml/jaslex_2.0.lex |  perl -CSD $local/format_lexicon.pl $lang | sort >$dictdir/lexicon.txt
        ## uncomment lines below to convert to UTwente phonetic lexicon 
        # cp $dictdir/lexicon.txt $dictdir/lexicon.orig.txt     
        # cat $dictdir/lexicon.orig.txt | perl $local/jas2nbest_phon.pl >$dictdir/lexicon.txt
fi
if ! grep -q "^<unk>" $dictdir/lexicon.txt; then
        echo -e "<unk>\t[SPN]" >>$dictdir/lexicon.txt
fi
if ! grep -q "^ggg" $dictdir/lexicon.txt; then
        echo -e "ggg\t[SPN]" >>$dictdir/lexicon.txt
fi
if ! grep -q "^xxx" $dictdir/lexicon.txt; then
        echo -e "xxx\t[SPN]" >>$dictdir/lexicon.txt
fi
# the rest
echo SIL > $dictdir/silence_phones.txt
echo SIL > $dictdir/optional_silence.txt
cat $dictdir/lexicon.txt | awk -F'\t' '{print $2}' | sed 's/ /\n/g' | sort | uniq >$dictdir/nonsilence_phones.txt
touch $dictdir/extra_questions.txt
rm -f $dictdir/lexiconp.txt

cd $base
$utils/prepare_lang.sh $dictdir "<unk>" data/local/lang_tmp_nosp data/lang_nosp || exit 1;

echo "Dictionary preparation succeeded"

