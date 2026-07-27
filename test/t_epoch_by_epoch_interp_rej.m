
%%
% EEG = autoreject_detect_repair(EEG);
EEG = autoreject_detect(EEG, 'thresh_lims', [10 95], 'verbose', false); % more conservative

EEG = detect_badchan_app(EEG);

EEG = detect_badchan_artist(EEG);

EEG = detect_badchan_infant_erp(EEG);

EEG = detect_badchan_irpf(EEG, 'knee_sensitivity', 1);

EEG = detect_badchan_mcevoy(EEG);

EEG = detect_badchan_relax1(EEG);

EEG = detect_badchan_relax2(EEG);

EEG = detect_badchan_scads(EEG);

EEG = detect_badchan_sleeptrip(EEG);

% Step 2 — SCROLL (review diagnostics)
pop_autoreject_scroll(EEG);




%% HERE
% pop_rejmenu(EEG, 1) 

clc; clear; close all;
project = initIGREE;

[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;
EEG = pop_loadset('filename','test_G2P_1.set','filepath','C:\Users\user\Desktop\Work\CUHK\IG_Reels_Emotion_EEG\data\preprocess_eeg\temp3-clean_epoch_rejection_done');

% inDir = fullfile(project.dir.data, "preprocess_eeg", "temp3-clean_epoch_rejection_done");
% inExt = "set";
% dataFiles = findFilesToProcess({inDir, inExt});
% EEG = pop_loadset('filename',dataFiles(1).fname,'filepath',dataFiles(1).dir);
[ALLEEG, EEG, CURRENTSET] = eeg_store( ALLEEG, EEG, 0 );
tempEEG = EEG;

EEG = tempEEG;
EEG.data = EEG.data(1:end-4, :); %remove the custom channels and HEO, VEO from data
EEG = eeg_checkset(EEG);
eeglab redraw
%%
% [sig, info] = extract_badchan_signals(EEG, 'locthresh', 5);    % Using improbable data method
% [sig, info, EEG] = extract_badchan_signals_faster(EEG);    % Using improbable data method

[sig, info, EEG] = extract_badchan_signals_faster(EEG, ...
    'features', {'devmean'}, 'zthresh', 3);

%% plot signals with some trick
y_stack = 20;
n_sig = size(sig, 1);
n_pnts = size(sig, 2);

empty_rows = y_stack - rem(n_sig, y_stack);
temp = [sig; zeros(empty_rows, n_pnts)];
% plot_sig = reshape(temp', n_pnts, y_stack, []);
% plot_sig = reshape(temp', y_stack, n_pnts, []);
% plot_sig = permute(plot_sig, [2, 1, 3])
plot_sig = permute(reshape(temp, y_stack, size(temp,1)/y_stack, n_pnts), [1 3 2]);

EEG.data = plot_sig; %remove the custom channels and HEO, VEO from data
EEG = eeg_checkset(EEG);
eeglab redraw

%%
pop_epochwise_chanrej_scroll(EEG);

% XX

% EEG.data = sig;
% EEG = eeg_checkset(EEG);
% eeglab redraw
% EEG.srate = 500
% 
% [spectra, freqs] = spectopo(EEG.data, 0, EEG.srate, 'plot', 'off');
% 
% y_stack = 20;
% n_spectra = size(spectra, 1);
% n_pnts = size(spectra, 2);
% 
% empty_rows = y_stack - rem(n_spectra, y_stack);
% temp = [spectra; zeros(empty_rows, n_pnts)];
% % plot_sig = reshape(temp', n_pnts, y_stack, []);
% % plot_sig = reshape(temp', y_stack, n_pnts, []);
% % plot_sig = permute(plot_sig, [2, 1, 3])
% plot_spectra = permute(reshape(temp, y_stack, size(temp,1)/y_stack, n_pnts), [1 3 2]);
% plot_spectra = plot_spectra(:,1:100,:);
% EEG.data = plot_spectra; %remove the custom channels and HEO, VEO from data
% EEG = eeg_checkset(EEG);
% eeglab redraw
% 
% %


%% clean and invalid ones
% 0 - bad
% 1 - good
% 2 - invalid (can ignore)
n_sig = size(sig, 1);
group = zeros(1, n_sig);
clean_ones = [4 6 9 10 13 14 15 21 26 27 34 60 63 81 92 118 119 120 124 140 144 150 160 198 199 200 204];
invalid_ones = [37 38 39 40 41 42 43 44 45 46 47 175 176 177 178 179];

group(clean_ones) = 1;
group(invalid_ones) = 2;

%% Define frequency bands
bands = {
    'delta',   [1 4];
    'theta',   [4 8];
    'alpha',   [8 13];
    'beta',    [13 30];
    'gamma',   [30 50];
    'alpha1',  [8 10];
    'alpha2',  [10 13];
    'beta1',   [13 18];
    'beta2',   [18 25];
    'beta3',   [25 30];
    };

% Compute spectra (linear power, not dB)
EEG.data = sig;
EEG = eeg_checkset(EEG);
EEG.srate = 500;

[spectra_dB, freqs] = spectopo(EEG.data, 0, EEG.srate, 'plot', 'off');
spectra_lin = 10.^(spectra_dB / 10);   % convert dB → linear power

n_signals = size(sig, 1);
n_bands   = size(bands, 1);

% Extract band power
band_power = zeros(n_signals, n_bands);
band_names = cell(1, n_bands);

for b = 1:n_bands
    band_names{b} = bands{b, 1};
    f_range       = bands{b, 2};
    idx           = freqs >= f_range(1) & freqs <= f_range(2);
    band_power(:, b) = mean(spectra_lin(:, idx), 2);
end

% Build table
T = array2table(band_power, 'VariableNames', band_names);
T = addvars(T, (1:n_signals)', 'Before', 1, 'NewVariableNames', {'Signal'});

disp(T);

%% Use existing table T and group vector
% T has columns: Signal, delta, theta, alpha, beta, gamma, alpha1, alpha2, beta1, beta2, beta3
% group is [n_signals × 1]: 0=bad, 1=good, 2=invalid

bands     = T.Properties.VariableNames(2:end);
grp_vals  = unique(group);
grp_names = {'Bad', 'Good', 'Invalid'};
n_bands   = length(bands);
n_groups  = length(grp_vals);

for b = 1:n_bands
    band_name = bands{b};
    band_pow  = T.(band_name);
    
    % Split into cell array {group1, group2, group3}
    data1 = cell(1, n_groups);
    for g = 1:n_groups
        data1{g} = band_pow(group == grp_vals(g));
    end
    
    figure('Name', band_name, 'NumberTitle', 'off');
    h = daboxplot(data1, 'scatter', 2, 'whiskers', 0, 'boxalpha', 0.7, ...
                  'xtlabels', grp_names);
    ylabel('Power (\muV^2/Hz)');
    title(band_name);
    set(gca, 'FontSize', 10);
end

