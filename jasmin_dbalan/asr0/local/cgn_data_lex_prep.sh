#!/bin/bash

# Preparation for CGN data by LvdW

if [ $# -le 2 ]; then
   echo "Arguments should be <CGN root> <language> <comps>, see ../run.sh for example."
   exit 1;
fi

cgn=$1
lang=$2
comps=$3

base=`pwd`
dir=`pwd`/data/local/data
lmdir=`pwd`/data/local/cgn_lm
dictdir=`pwd`/data/local/dict_nosp
#mkdir -p $dir $lmdir
local=`pwd`/local
utils=`pwd`/utils

. ./path.sh 	# Needed for KALDI_ROOT

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

# create train & dev set
## Create .flist files (containing a list of all .wav files in the corpus)

# prepare lexicon
# cgnlex_2.0.lex  : single word lexicon
# lex_2.0.dtd     : DTD describing the single word lexico
# cgnmlex_2.0.lex : multi-word lexicon
# mlex_2.0.dtd    : DTD describing the multi-word lexicon
# If you have a lexicon prepared, you can simply place it in $dictdir and it will be used instead of the default CGN one
if [ ! -f $dictdir/lexicon.txt ]; then
        echo "Inside Lexicon Prep"
	mkdir -p $dictdir
	#[ -e $cgn/data/lexicon/xml/cgnlex.lex ] && cat $cgn/data/lexicon/xml/cgnlex.lex | recode -d h..u8 | perl -CSD $local/format_lexicon.pl $lang | sort >$dictdir/lexicon.txt
	[ -e $cgn/data/lexicon/xml/cgnlex.lex ] && cat $cgn/data/lexicon/xml/cgnlex.lex |  perl -CSD $local/format_lexicon.pl $lang | sort >$dictdir/lexicon.txt
	#[ -e $cgn/data/lexicon/xml/cgnlex_2.0.lex ] && cat $cgn/data/lexicon/xml/cgnlex_2.0.lex | recode -d h..u8 | perl -CSD $local/format_lexicon.pl $lang | sort >$dictdir/lexicon.txt
	[ -e $cgn/data/lexicon/xml/cgnlex_2.0.lex ] && cat $cgn/data/lexicon/xml/cgnlex_2.0.lex |  perl -CSD $local/format_lexicon.pl $lang | sort >$dictdir/lexicon.txt
	## uncomment lines below to convert to UTwente phonetic lexicon	
	# cp $dictdir/lexicon.txt $dictdir/lexicon.orig.txt	
	# cat $dictdir/lexicon.orig.txt | perl $local/cgn2nbest_phon.pl >$dictdir/lexicon.txt
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

# move everything to the right place

echo "Data preparation succeeded"
