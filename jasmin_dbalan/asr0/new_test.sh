echo "---------------------------"
echo "For combined test set"
grep WER exp/tri4/decode_test_tgpr/wer* | utils/best_wer.sh
grep WER exp/chain/tdnn1a_sp_bi/decode_test/wer* | utils/best_wer.sh
grep WER exp/chain/tdnn1a_sp_bi/decode_test_rescore/wer* | utils/best_wer.sh
echo "    "
echo "---------------------------"
echo "    "
echo "For individual tests: edit names to get the output"
grep WER exp/tri4/decode_test_copy_tgpr/wer* | utils/best_wer.sh
grep WER exp/tri4/decode_test_male_tgpr/wer* | utils/best_wer.sh
grep WER exp/tri4/decode_test_female_tgpr/wer* | utils/best_wer.sh
grep WER exp/tri4/decode_test_age_1_tgpr/wer* | utils/best_wer.sh
grep WER exp/tri4/decode_test_age_2_tgpr/wer* | utils/best_wer.sh
grep WER exp/tri4/decode_test_age_5_tgpr/wer* | utils/best_wer.sh
grep WER exp/tri4/decode_test_read_tgpr/wer* | utils/best_wer.sh
grep WER exp/tri4/decode_test_conv_tgpr/wer* | utils/best_wer.sh
echo "    "
echo "---------------------------"

