
% M = txt2mat('EEGEmotions-27.txt');

opts = detectImportOptions('EEGEmotions-27.txt', 'Delimiter', '\t');
M = readmatrix('EEGEmotions-27.txt', setvartype(opts, 'double'));
M = M'

[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;

%%

% EEG.data = M;
% eeglab redraw
[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;
EEG = pop_importdata('setname','temp1', 'data', M, 'dataformat','array', 'srate', 1000, 'pnts', 1000);
    % ^ Simply use pop_importdata() to put the epoched data in, everything
    % else will be adjusted. It's better than forcibly subbing the
    % epoched_data to EEG.data, use their own functions for it to adjust
    % workspace vars manually.
EEG = eeg_checkset(EEG);

eeglab redraw
EEG = pop_eegfiltnew(EEG, 'locutoff',1,'hicutoff',48,'plotfreqz',1);
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 1,'gui','off'); 
pop_eegplot( EEG, 1, 1, 1);


%%

