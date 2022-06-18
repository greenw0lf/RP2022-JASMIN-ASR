import re

##### These need to be in the same dir as the script #####
f = open('wav.scp', 'r')
f1 = open('utt2spk', 'r')
f2 = open('segments', 'r')
f3 = open('text', 'r')

##### These files will be ONLY for the augmentation. Make sure to #####
##### append them to the original ones. #####
wr = open('wavaug.scp', 'w')
wr1 = open('utt2spkaug', 'w')
wr2 = open('segmentsaug', 'w')
wr3 = open('textaug', 'w')

lines = f.readlines()
lines1 = f1.readlines()
lines2 = f2.readlines()
lines3 = f3.readlines()

for result in lines:
    # This substitutes the file extensions so that they match the augmented files and not the original
    new = re.sub(r'fn......', r'\g<0>sa', result)
    # Make sure to change the second path to where you will put your augmented audio files
    final = re.sub(r'/tudelft.net/staff-bulk/ewi/insy/SpeechLab/RP2022/JASMIN/Data/data/audio/wav/comp-p/nl/|/tudelft.net/staff-bulk/ewi/insy/SpeechLab/RP2022/JASMIN/Data/data/audio/wav/comp-q/nl/',
                 r'/tudelft.net/staff-bulk/ewi/insy/SpeechLab/RP2022/dbalan/kaldi/egs/jasmin_dbalan/wav_sa/', new)
    wr.write(final)

for result in lines1:
    new = re.sub(r'fn......', r'\g<0>sa', result)
    wr1.write(new)

for result in lines2:
    new = re.sub(r'fn......', r'\g<0>sa', result)
    wr2.write(new)
#
for result in lines3:
    new = re.sub(r'fn......', r'\g<0>sa', result)
    wr3.write(new)

f.close()
f1.close()
f2.close()
f3.close()

wr.close()
wr1.close()
wr2.close()
wr3.close()
