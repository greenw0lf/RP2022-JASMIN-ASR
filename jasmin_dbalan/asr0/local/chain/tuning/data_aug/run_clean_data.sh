# This script is created to filter out CGN training sentences that contains only <ggg> or <xxx> data

data_old=data/train_aug_sp_hires_comb/
data_new=data/train_cleaned_aug_sp_hires_comb/
utils/copy_data_dir.sh $data_old $data_new
cp $data_new/text $data_new/text_old.bkp
sed -i -e "/[0-9] ggg$/d" -e "/[0-9] ggg ggg$/d" -e "/[0-9] xxx$/d" -e "/[0-9] xxx xxx$/d" $data_new/text
utils/fix_data_dir.sh $data_new 

data_old=data/train_aug_sp_comb/
data_new=data/train_cleaned_aug_sp_comb/
utils/copy_data_dir.sh $data_old $data_new
cp $data_new/text $data_new/text_old.bkp
sed -i -e "/[0-9] ggg$/d" -e "/[0-9] ggg ggg$/d" -e "/[0-9] xxx$/d" -e "/[0-9] xxx xxx$/d" $data_new/text
utils/fix_data_dir.sh $data_new

# Below won't work as ali dir and ali_lats dir incompatible
## Get a subset of the lat dir:
#lats_old=exp/chain/tdnnf_related/aug_related/tri4_train_aug_sp_comb_lats/
#lats_new=exp/chain/tdnnf_related/aug_related/tri4_train_cleaned_aug_sp_comb_lats/
#steps/subset_ali_dir.sh $data_old $data_new $lats_old $lats_new # <full-data-dir> <subset-data-dir> <ali-dir> <subset-ali-dir> 
