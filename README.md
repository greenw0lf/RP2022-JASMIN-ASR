# RP2022-JASMIN-ASR
This page contains the base files used throughout the project for training and testing the ASR models.

## Explanation of files/folders
- `4files.py`: This is the code used to augment the 4 files needed for training/testing any model.
- `specaug.py`: The SpecAugment script used for generating perturbed audio files.

Both of the scripts above have comments inside of them explaining the steps.
- `asr0`: The baseline ASR model that was extended from and used throughout the project.
- `data`: Contains files about the data to be used, as well as the data extracted that was used for training/testing.
- `vtlp_aug_scripts`: The VTLP augmentation files (credits to Nikolay Zhlebinkov for creating them).

## Inside the `asr0` folder
- Folders `conf`, `local`, `steps` and `util` are part of the kaldi toolkit and will not be explained here
- `jasmin_run.sh`: Contains the main script used to train the model.
  - Inside the file, we have stage -1 that deals with training the language model, and everything after stage 0 deals with training of the acoustic model. More will be explained in the "Steps" section
- `jasmin_run_test.sh`: It was made for testing particular subgroups of the test set (such as children speech or male speech, etc.). It is mainly a modification of the `jasmin_run.sh`, which can be modified to contain the same logic. `test` will need to be replaced with a variable like `$test_folders` (like in `jasmin_run_test.sh`) that is a string that contains all the names of the individual test folders, separated with spaces.
- `new_test.sh`: A simple script that outputs the WER for each of the test sets. It can be easily modified to integrate more test folders if necessary.
- `run_data_prep.sh`: The first script that should be run in order to generate information about the JASMIN-CGN data available to use. Careful that wav.scp would not be generated and you will have to do it yourself, but an example of how it looks like will be explained later on.
- `srun` scripts are mainly made for running on a HPC cluster.

## Inside the `data` folder
- `train` contains the 4 files that were used for training, whereas `test` and its other variants contain the testing data. The variants are a subset of the test folder, with a focus on specific groups based on age, gender, or type of speech.
- `local/data` contains information about speakers, as well as some files generated throughout the project only for the Transitional Dutch region. 

A more detailed breakdown of these files is provided in `data.md`.

## Inside the `vtlp_aug_scripts` folder
- `aug_helpers.py`: Helper functions used for the main VTLP augmentation script.
- `main.py`: The main script that manages paths and the augmentation. This is the one that needs to be run and where the paths need to be changed.
- `vtlp.py`: The function that deals with the VTLP augmentation.
- `wav2warp`: A description of the warping factor used for each of the files I have augmented and trained on for this project. This file is automatically generated once the files were successfully augmented, after running `main.py`.

## Steps to reproduce experiment
1. Open a terminal in `asr0`
2. Run `./run_data_prep.sh`. It will generate the `data/local/data` folder with information about the speakers. CAREFUL! `jasmin_path` needs to point to the folder that contains the JASMIN corpus information
3. There will be a `data` folder generated now. Go to `data/local/data`.
4. Inside there, there are multiple files. The `spk2` files contain more specific information about each speaker's gender, age, regional accent, proficiency level (if they are non-natives), etc. Using these files, extract the `segments`, `utt2spk` and `text` files that you need, from each `comp_q` and `comp_p` available inside.
5. Merge the obtained files for each comp_p and comp_q into one, so you will have `segments`, `utt2spk` and `text` that each contain the data for all styles of speech (`comp_p` and `comp_q`. `comp_p` stands for conversational (HMI) speech, `comp_q` means speech read from a script).
6. For the `wav.scp` file, there is the one for the entire cluster included, `wav_jas_all.scp`, from which the necessary information can be extracted to generate your own `wav.scp`.
7. Going back to `asr0/data` (NOT `asr0/data/local/data`), make 2 directories: `train` and `test`.
8. (OPTIONAL) Make directories for any specific group of people from your `test` set that you want to evaluate separately.
9. Now you should have 4 files generated: `segments`, `text`, `utt2spk` and `wav.scp`. These are the files that will contain your extracted speakers and will be used for training/testing. For each of these files, extract the speakers you want to include in `train` and save in a new file inside `train` and the same for the rest of the speakers, to put inside `test`.
10. Go back to `asr0`
11. Run `./utils/fix_data_dir.sh data/train` to make sure the training data is in order for the kaldi script
12. Do the same for `data/test`
13. Run `jasmin_run.sh`
14. Wait until training is complete
15. Run `new_test.sh` to see the overall WER performance of your system. Ignore if you have errors about folders missing, as long as the first line displays the WER, then it is fine
16. (OPTIONAL) Run `jasmin_run_test.sh` to test the subgroups of `test` created inside `data`
17. (OPTIONAL) Run `new_test.sh` again to see the individual WERs obtained
