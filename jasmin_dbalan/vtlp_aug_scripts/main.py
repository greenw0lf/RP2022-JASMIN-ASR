import sys
import librosa
import soundfile
from vtlp import VtlpAug
from os import listdir
from os.path import isfile, join

sourceDir = "../wav_transitional"
qsDir = "../wav_transitional/comp-q"
outputDir = "./"
onlyFiles = [f for f in listdir(sourceDir) if isfile(join(sourceDir, f))]
qFiles = [f for f in listdir(qsDir) if isfile(join(qsDir, f))]

print("Filenames retrieved")

warpFactors = {}

for fileName in onlyFiles:
    filePath = join(sourceDir, fileName)
    data, samplerate = librosa.load(filePath, sr=16000)

    aug = VtlpAug(samplerate, factor_range=(0.9, 1.1), zone=(0, 1), coverage=1)
    augmented, warpFactor = aug.augment(data)
    warpFactors[fileName] = warpFactor

    outputName = fileName.replace(".wav", "vtlp.wav")
    outputPath = join(outputDir, outputName)
    soundfile.write(outputPath, augmented, samplerate)
    print(outputName + " warped by " + str(warpFactor))

for fileName in qFiles:
    filePath = join(qsDir, fileName)
    data, samplerate = librosa.load(filePath, sr=16000)

    aug = VtlpAug(samplerate, factor_range=(0.9, 1.1), zone=(0, 1), coverage=1)
    augmented, warpFactor = aug.augment(data)
    warpFactors[fileName] = warpFactor

    outputName = fileName.replace(".wav", "vtlp.wav")
    outputPath = join(outputDir, outputName)
    soundfile.write(outputPath, augmented, samplerate)
    print(outputName + " warped by " + str(warpFactor))

print("Finalized warps, creating wav2warp")
wav2warpArray = [spk + " " + str(warp) for spk, warp in warpFactors.items()]
wav2warpContent = "\n".join(wav2warpArray)
wav2warpFile = open(join(outputDir, "wav2warp"), "w")
wav2warpFile.write(wav2warpContent)
wav2warpFile.close()

print("Completed successfully")
sys.exit()
