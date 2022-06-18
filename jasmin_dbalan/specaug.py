########## ALL 3 below are needed for it to run properly ##########
# This does the actual augmentations
from audiomentations import SpecFrequencyMask, TimeMask
# This converts from audio to spectrogram and vice versa
import librosa as ros
# This reads and writes the audio files
import soundfile as sf
# To measure how much time it takes to compute (took me around 3 hours to augment my training data)
import time
# To get all files needed to process and augment
from os import listdir
from os.path import isfile, join
import numpy as np

# Make sure to modify the paths depending on where you saved the audio files
comp_p = [f for f in listdir('../wav_transitional') if isfile(join('../wav_transitional', f))]
comp_q = [f for f in listdir('../wav_transitional/comp-q') if isfile(join('../wav_transitional/comp-q', f))]

start = time.time()
for file in comp_p:
    wav, sr = sf.read('../wav_transitional/' + comp_p[0])
    # comp-p is conversational, so it has 2 channels. We only want to augment the speaker part,
    # not the machine one
    spec = ros.feature.melspectrogram(y=wav[:,0], sr=sr)
    freq_t = SpecFrequencyMask(p=1, min_mask_fraction=0.1, max_mask_fraction=0.2)
    new_spec = freq_t(spec)
    new_wav = ros.feature.inverse.mel_to_audio(M=new_spec, sr=sr)
    print(np.where(new_wav == 0)[0])
    parts = file.split(".")
    sf.write(parts[0] + "sa." + parts[1], list(zip(new_wav, wav[:len(new_wav), 1])), sr)
    print("file " + parts[0] + "sa." + parts[1] + " has been created") #
print('time spent for augmenting comp_p is:' + str((time.time() - start) / 60) + ' minutes')

start = time.time()
for file in comp_q:
    wav, sr = sf.read('../wav_transitional/comp-q/' + file)
    spec = ros.feature.melspectrogram(y=wav, sr=sr)
    freq_t = SpecFrequencyMask(p=1, min_mask_fraction=0.1, max_mask_fraction=0.2)
    new_spec = freq_t(spec)
    new_wav = ros.feature.inverse.mel_to_audio(M=new_spec, sr=sr)
    parts = file.split(".")
    sf.write(parts[0] + "sa." + parts[1], new_wav, sr)
    print("file " + parts[0] + "sa." + parts[1] + " has been created")
print('time spent for augmenting comp_q is:' + str((time.time() - start) / 60) + ' minutes')
