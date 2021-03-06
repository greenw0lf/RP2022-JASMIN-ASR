# Files inside `data/local/data`
- `seg_p.txt` and `seg_q.txt` contain the audio codes and their durations respectively that I used for calculating total time spoken for each speaker code.
- `segments` is the file that contains the Transitional speakers extracted and their audio codes and duration.
- `segments_comp_p_nl` and `segments_comp_q_nl` contain the segments of the entire JASMIN corpus for HMI and read speech respectively.
- `speech_conv` and `speech_read` contain the audio codes for each Transitional speaker for HMI and read speech respectively.
- `speech_t` contains the information of both `speech_conv` and `speech_read`, in a single file.
- `spk2CEF_nl` has information about non-natives' level of proficiency in Dutch. If there is only a speaker code mentioned, but no level, then it means the speaker is a native.
- `spk2age_nl`, as the name suggests, has info about the age of each speaker/
- `spk2dialectregion_nl` associates the speakers with the dialect they have.
- `spk2gender_nl` has information about speakers' gender.
- `spk2group_nl` has information about the age group they belong to.
  - 1: native children between 7-11 years old
  - 2: native teenagers between 12-16 years old
  - 3: non-native children between 7-16 years old
  - 4: non-native adults
  - 5: native adults above 65
- `spk_t` has the speaker codes for the Transitional region speakers.
- `text` is the file that contains the text spoken by the Transitional speakers that was used for training/testing.
- `text_comp_p_nl` and `test_comp_q_nl` contain the text spoken in the entire corpus for HMI and read respectively.
- `utt2spk` -> Transitional speakers file.
- `utt2spk_comp_p_nl` and `utt2spk_comp_q_nl` -> All speakers file.
- `wav.scp` -> Transitional audio files locations.
- `wav_jas_all.scp` -> same, but for the entire corpus.
