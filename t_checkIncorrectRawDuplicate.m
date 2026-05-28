a = dir("C:\Users\user\Desktop\Work\CUHK\IG_Reels_Emotion_EEG\data\incorrect_raw_eeg");

%%
b = {a.bytes};
file_mask = cell2mat({a.isdir}) == 0;
b = b(file_mask);
c = cell2mat(b);

length(unique(c))
length(c)
% same means good to go