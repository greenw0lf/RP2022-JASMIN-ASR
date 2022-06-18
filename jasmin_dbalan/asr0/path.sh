#export KALDI_ROOT=`pwd`/../../..
#export KALDI_ROOT=/tudelft.net/staff-bulk/ewi/insy/SpeechLab/siyuanfeng/software/kaldi/

#export KALDI_ROOT=/scratch/siyuanfeng/software/kaldi/
#export FST_ROOT=/scratch/siyuanfeng/software/kaldi

export KALDI_ROOT=/tudelft.net/staff-bulk/ewi/insy/SpeechLab/Software/kaldi
export FST_ROOT=/tudelft.net/staff-bulk/ewi/insy/SpeechLab/Software/kaldi

export LD_LIBRARY_PATH=$KALDI_ROOT/tools/portaudio/lib:$KALDI_ROOT/tools/openfst-1.7.2/lib:$KALDI_ROOT/src/lib:$LD_LIBRARY_PATH

#[ -f $KALDI_ROOT/tools/env.sh ] && . $KALDI_ROOT/tools/env.sh
[ -f $FST_ROOT/tools/env.sh ] && . $FST_ROOT/tools/env.sh
export PATH=$PWD/utils/:$FST_ROOT/tools/openfst/bin:$PWD:$PATH
[ ! -f $KALDI_ROOT/tools/config/common_path.sh ] && echo >&2 "The standard file $KALDI_ROOT/tools/config/common_path.sh is not present -> Exit!" && exit 1
. $KALDI_ROOT/tools/config/common_path.sh
export LC_ALL=C

# SRILM is needed for LM model building
SRILM_ROOT=$KALDI_ROOT/tools/srilm
SRILM_PATH=$SRILM_ROOT/bin:$SRILM_ROOT/bin/i686-m64
export PATH=$PATH:$SRILM_PATH

