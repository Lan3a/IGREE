
clc; clear; close all;
project = initIGREE;

[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;


inDir = fullfile(project.dir.data, "preprocess_eeg", "temp_epoch_rejection_done");
inExt = "set";
dataFiles = findFilesToProcess({inDir, inExt});
EEG = pop_loadset('filename',dataFiles(1).fname,'filepath',dataFiles(1).dir);
[ALLEEG, EEG, CURRENTSET] = eeg_store( ALLEEG, EEG, 0 );
tempEEG = EEG;

EEG = tempEEG;
EEG.data = EEG.data(1:end-4, :); %remove the custom channels and HEO, VEO from data
EEG = eeg_checkset(EEG);

%%
EEG = autoreject_detect_repair(EEG);

%%
EEG = detect_badchan_app(EEG);

%%
EEG = detect_badchan_artist(EEG);

%%
EEG = detect_badchan_infant_erp(EEG);

%%
EEG = detect_badchan_irpf(EEG);

%%
EEG = detect_badchan_mcevoy(EEG);

%%
EEG = detect_badchan_relax1(EEG);

%%
EEG = detect_badchan_relax2(EEG);

%%
EEG = detect_badchan_scads(EEG);

%%
EEG = detect_badchan_sleeptrip(EEG);

%%
% Step 2 — SCROLL (review diagnostics)
pop_autoreject_scroll(EEG);





