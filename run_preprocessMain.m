%% Init
% STEPS: -> refer to the google slide
% 
% TODO: -> moved to README.md
% 

clc; clear; close all;
project = initIGREE;

[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;

%% Load EEG, resample, band filter, reject bad channel
inDir = fullfile(project.dir.data, "correct_raw_eeg");
outDir = fullfile(project.dir.data, "preprocess_eeg", "bad_channels_rejected");
inExt = "set"; outExt = "set";
dataFiles = findFilesToProcess({inDir, inExt}, {outDir, outExt});

for fidx = 1:length(dataFiles)
    
    % Load EEG
    EEG = pop_loadset('filename',dataFiles(fidx).fname,'filepath',dataFiles(fidx).dir);
    [ALLEEG, EEG, CURRENTSET] = eeg_store( ALLEEG, EEG, 0 );

    % resample to 500 Hz
    EEG = pop_resample( EEG, 500);

    % band filtering
    EEG = pop_eegfiltnew(EEG, 'locutoff',48,'hicutoff',52,'revfilt',1); %notch 48-52 Hz
    EEG = pop_eegfiltnew(EEG, 'locutoff',1,'hicutoff',98); %band pass 1-98 Hz 
    
    EEG.moreInfo.chanLocsRefForInterp = EEG.chanlocs; %eeglab compares the chanlocs later to this full chanlocs to see which chan is missing, then interp

    newSetName = sprintf('(%s) rejecting bad channels manually...', dataFiles(fidx).bname);
    [~, EEG, ~] = pop_newset([], EEG, 0, 'setname', newSetName, 'gui','off');

    % reject bad channels
    tempEEG = EEG;
    while true
        EEG = tempEEG;
        eeglab redraw

        rejBadChanGUI(EEG);
        custom_pop_spectopo(EEG);
        
        % =========================================================================
        % USER DIALOG
        choice = askAction();
        % if save
        if contains(choice, 'Save')
            newSetName = sprintf('(%s) bad channels rejected', dataFiles(fidx).bname);
            saveDir = outDir;
            saveFileName = dataFiles(fidx).fname;
            saveNewEegSet(EEG, newSetName, saveDir, saveFileName);
            
            % Save Pngs
            try
                if isfield('EEG.moreInfo', 'badTimeDataPng') || ~isempty([EEG.moreInfo.badTimeDataPng.png])
                    pngStruct = EEG.moreInfo.badTimeDataPng;
                    savePngDir = fullfile(outDir, 'bad_time_data_pngs', dataFiles(fidx).bname);
                    saveStructStoredPng(pngStruct, savePngDir);
                else
                    disp('No Pngs to save');
                end
            catch 
                warning("Unexpected: Pngs are not saved, please check"); beep;
            end
            
            disp('saving...');
        end

        % execute other actions
        switch choice
            case 'Save this and Continue'
            case 'Save this and Exit', close all; error('>>>> Saved this one and exited');
            case 'Skip this'
            case 'Reset this', close all; continue;
            case 'Cancel', close all; error('>>>> Cancelled');
            otherwise, close all; error('>>>> Cancelled');
        end

        % to next data
        close all;
        printLoopProgress(fidx, numel(dataFiles));
        break
        % =========================================================================
    end
end
close all; beep; cpbGreen('All done!');

%% CAR reference, bad channel interp, run ICA

inDir = fullfile(project.dir.data, "preprocess_eeg", "bad_channels_rejected");
outDir = fullfile(project.dir.data, "preprocess_eeg", "ICA_ready");
inExt = "set"; outExt = "set";
dataFiles = findFilesToProcess({inDir, inExt}, {outDir, outExt});

for fidx = 1:length(dataFiles)
    % re-reference (with CAR)
    EEG = pop_reref( EEG, []);

    % run ICA
    EEG = pop_runica(EEG, 'icatype', 'runica', 'extended',1,'interrupt','on');
    
    % Save set
    newSetName = sprintf('(%s) ICA ready', dataFiles(fidx).bname);
    saveDir = outDir;
    saveFileName = dataFiles(fidx).fname;
    saveNewEegSet(EEG, newSetName, saveDir, saveFileName);
end
close all; beep; cpbGreen('All done!');

%% ICA rejection

inDir = fullfile(project.dir.data, "preprocess_eeg", "ICA_ready");
outDir = fullfile(project.dir.data, "preprocess_eeg", "ICA_done");
inExt = "set"; outExt = "set";
dataFiles = findFilesToProcess({inDir, inExt}, {outDir, outExt});

for fidx = 1:length(dataFiles)
    % Load EEG
    EEG = pop_loadset('filename',dataFiles(fidx).fname,'filepath',dataFiles(fidx).dir);
    [ALLEEG, EEG, CURRENTSET] = eeg_store( ALLEEG, EEG, 0 );
    
    tempEEG = EEG;
    while true
        EEG = tempEEG;
        eeglab redraw
        
        % reject ICs
        rejICsGUI(EEG);
        
        % =========================================================================
        % USER DIALOG
        choice = askAction();
        % if save
        if contains(choice, 'Save')
            newSetName = sprintf('(%s) ICA done', dataFiles(fidx).bname);
            saveDir = outDir;
            saveFileName = dataFiles(fidx).fname;
            saveNewEegSet(EEG, newSetName, saveDir, saveFileName);
            
            % Save Pngs
            try
                if isfield('EEG.moreInfo', 'rejICsPng') || ~isempty([EEG.moreInfo.rejICsPng.png])
                    pngStruct = EEG.moreInfo.rejICsPng;
                    savePngDir = fullfile(outDir, 'rejected_IC_pngs', dataFiles(fidx).bname);
                    saveStructStoredPng(pngStruct, savePngDir);
                else
                    disp('No Pngs to save');
                end
            catch 
                warning("Unexpected: Pngs are not saved, please check"); beep;
            end

            disp('saving...');
        end

        % execute other actions
        switch choice
            case 'Save this and Continue'
            case 'Save this and Exit', close all; error('>>>> Saved this one and exited');
            case 'Skip this'
            case 'Reset this', close all; continue;
            case 'Cancel', close all; error('>>>> Cancelled');
            otherwise, close all; error('>>>> Cancelled');
        end

        % to next data
        close all;
        printLoopProgress(fidx, numel(dataFiles));
        break
        % =========================================================================

    end
end
close all; beep; cpbGreen('All done!');


%% interpolate bad channel, final re-reference, and rejecting bad epochs

inDir = fullfile(project.dir.data, "preprocess_eeg", "ICA_done");
outDir = fullfile(project.dir.data, "preprocess_eeg", "epoch_rejection_done");
inExt = "set"; outExt = "set";
dataFiles = findFilesToProcess({inDir, inExt}, {outDir, outExt});

for fidx = 1:length(dataFiles)
    
    % Load EEG
    EEG = pop_loadset('filename',dataFiles(fidx).fname,'filepath',dataFiles(fidx).dir);
    [ALLEEG, EEG, CURRENTSET] = eeg_store( ALLEEG, EEG, 0 );

    % interp bad chans
    EEG = pop_interp(EEG, EEG.moreInfo.chanLocsRefForInterp);
    
    % final re-reference (with CAR)
    EEG = pop_reref( EEG, []);
    
    % -------------------------------------------------------------------------
    % adding TIMEMS and SESSIONIDX channels (AI helped)
    nPts = size(EEG.data, 2);
    timeMsChannel = zeros(1, nPts);
    sessionIdxChannel = zeros(1, nPts);
    for i = 1:length(EEG.event)
        if strcmp(EEG.event(i).type, 'boundary')
            disp("detected boundary type, skipping...")
            continue
        end
        latency = EEG.event(i).latency;
        finalDurationMs = EEG.event(i).finDuration; %TEMP
        startPt = round(latency);
        % Convert ms to samples using actual EEG sampling rate
        nSessionSamples = round(finalDurationMs / 1000 * EEG.srate);
        % Inclusive endpoint
        stopPt = startPt + nSessionSamples - 1;
        % Clamp to valid range
        startPt = max(1, startPt);
        stopPt = min(nPts, stopPt);
        sessionPts = stopPt - startPt + 1;
        timeMsChannel(startPt:stopPt) = ...
            (0:(sessionPts-1)) * (1000 / EEG.srate);
        sessionIdxChannel(startPt:stopPt) = EEG.event(i).sessionIdx; %TEMP
    end

    EEG.moreInfo.timeMsChannel = timeMsChannel;
    EEG.moreInfo.sessionIdxChannel = sessionIdxChannel;
    
    % -------------------------------------------------------------------------
    % Epoching (AI helped)

    tempChanLocs = EEG.chanlocs;
    tempMoreInfo = EEG.moreInfo;

    epochLenSecond = 1;

    srate = EEG.srate;
    data = EEG.data;
    nChans = size(data, 1);
    nPts = size(data, 2);
    samplesPerEpoch = round(epochLenSecond * srate);

    tm = double(EEG.moreInfo.timeMsChannel(:)');
    sid = double(EEG.moreInfo.sessionIdxChannel(:)');
    changeIdx = [1, find(diff(sid) ~= 0) + 1, nPts + 1];
    chunks = {};
    timeMsChunks = {};
    sessionIdxChunks = {};
    epochSessionIdxParts = {};
    for k = 1:numel(changeIdx) - 1
        a = changeIdx(k);
        b = changeIdx(k + 1) - 1;
        thisSid = sid(a);
        if thisSid == 0
            continue;
        end
        seg = data(:, a:b);
        nSeg = size(seg, 2);
        nEp = ceil(nSeg / samplesPerEpoch);
        padN = nEp * samplesPerEpoch - nSeg;
        if padN > 0
            seg = [seg, zeros(nChans, padN)];
        end
        chunks{end + 1} = reshape(seg, nChans, samplesPerEpoch, nEp);
        epochSessionIdxParts{end + 1} = repmat(thisSid, 1, nEp);
        tmSeg = tm(a:b);
        if padN > 0
            tmSeg = [tmSeg, nan(1, padN)];
        end
        timeMsChunks{end + 1} = reshape(tmSeg, 1, samplesPerEpoch, nEp);
        sidSeg = sid(a:b);
        if padN > 0
            sidSeg = [sidSeg, repmat(thisSid, 1, padN)];
        end
        sessionIdxChunks{end + 1} = reshape(sidSeg, 1, samplesPerEpoch, nEp);
    end
    epochedData = cat(3, chunks{:});
    epochSessionIdx = [epochSessionIdxParts{:}];

    EEG = pop_importdata('setname','epoched data', 'data',epochedData, 'dataformat','array', 'chanlocs', tempChanLocs, 'srate', srate, 'pnts', srate);
    % ^ Simply use pop_importdata() to put the epoched data in, everything
    % else will be adjusted. It's better than forcibly subbing the
    % epoched_data to EEG.data, use their own functions for it to adjust
    % workspace vars manually.
    EEG = eeg_checkset(EEG);
    
    % plug values back
    EEG.moreInfo = tempMoreInfo;
    EEG.moreInfo.epochedTimeMsChannel = cat(3, timeMsChunks{:});
    EEG.moreInfo.epochedSessionIdxChannel = cat(3, sessionIdxChunks{:});
    EEG.chanlocs = tempChanLocs;
    
    % -------------------------------------------------------------------------
    % rejecting bad epochs
    % allChanData = cat(1, EEG.data, EEG.moreInfo.epochedTimeMsChannel, EEG.moreInfo.epochedSessionIdxChannel);
    tempEEG = EEG;

    newSetName = sprintf('(%s) custom channels added', dataFiles(fidx).bname);
    [~, EEG, ~] = pop_newset([], EEG, 0, 'setname', newSetName, 'gui','off');
    
    while true
        EEG = tempEEG;
        eeglab redraw

        pop_rejmenu_IGREE(EEG, 1) %output EEG.data will contain all channels
        
        % =========================================================================
        % USER DIALOG
        choice = askAction();
        % if save
        if contains(choice, 'Save')
            
            newSetName = sprintf('(%s) Epoch rejection done', dataFiles(fidx).bname);
            saveDir = outDir;
            saveFileName = dataFiles(fidx).fname;
            saveNewEegSet(EEG, newSetName, saveDir, saveFileName);
            
            disp('saving...');
        end

        % execute other actions
        switch choice
            case 'Save this and Continue'
            case 'Save this and Exit', close all; error('>>>> Saved this one and exited');
            case 'Skip this'
            case 'Reset this', close all; continue;
            case 'Cancel', close all; error('>>>> Cancelled');
            otherwise, close all; error('>>>> Cancelled');
        end

        % to next data
        close all;
        printLoopProgress(fidx, numel(dataFiles));
        break
        % =========================================================================
    end
end
close all; beep; cpbGreen('All done!');

%% (UNFINISHED) epoch-wise channel interpolation (automatic)

%TODO - make the whole structure good
inDir = fullfile(project.dir.data, "preprocess_eeg", "temp3-clean_epoch_rejection_done");
inExt = "set";
dataFiles = findFilesToProcess({inDir, inExt});
EEG = pop_loadset('filename',dataFiles(1).fname,'filepath',dataFiles(1).dir);
[ALLEEG, EEG, CURRENTSET] = eeg_store( ALLEEG, EEG, 0 );
tempEEG = EEG;

EEG = tempEEG;

window_ms = 1000;
overlap_ms = 500;

window_pts = window_ms/1000 * EEG.srate;
overlap_pts = overlap_ms/1000 * EEG.srate;

time_data = EEG.data(end-1,:);
sampling_interval = 1000/EEG.srate;
all_cont_ranges = extractContRanges(time_data, sampling_interval);
subepoched_eeg_data = outputSubepochEeg(all_cont_ranges, window_pts, overlap_pts, EEG.data);

EEG.data = subepoched_eeg_data;
EEG = eeg_checkset(EEG);

eeglab redraw



function all_cont_ranges = extractContRanges(time_data, sampling_interval)
    % Only consider non-NaN entries for break detection
    valid_idx = find(~isnan(time_data));

    if isempty(valid_idx)
        all_cont_ranges = [];
        return;
    end

    valid_time = time_data(valid_idx);

    temp1 = diff(valid_time);
    temp2 = temp1 ~= sampling_interval;
    break_pos = find(temp2);

    temp3a = valid_idx(break_pos);
    temp3b = valid_idx(break_pos + 1);

    temp4 = [valid_idx(1), temp3b; temp3a, length(time_data)];
    all_cont_ranges = permute(temp4, [2,1]);
end

function subepoched_eeg_data = outputSubepochEeg(all_cont_ranges, window_pts, overlap_pts, epoched_eeg_data)
    all_moving_epoch_ranges = [];
    
    for i = 1:size(all_cont_ranges, 1)
        seg_start = all_cont_ranges(i, 1);
        seg_end = all_cont_ranges(i, 2);

        for w_start = seg_start : overlap_pts : seg_end
            w_end = w_start + window_pts - 1;
            if w_end > seg_end
                break;
            end
            % if valid subepoch
            all_moving_epoch_ranges(end+1, :) = [w_start, w_end];
        end
    end

    % -------------------------------------------------------------------------
    ranges = all_moving_epoch_ranges; %MEM - refactor for each section
    cont_data = reshape(epoched_eeg_data, size(epoched_eeg_data, 1), []);

    n_chans = size(cont_data,1);
    n_epochs = size(ranges, 1);
    epoch_len = ranges(1, 2) - ranges(1, 1) + 1; %all ranges equal size
    subepoched_eeg_data = zeros(n_chans, epoch_len, n_epochs);

    for i = 1:n_epochs
        range_pts = ranges(i, 1):ranges(i, 2);
        subepoched_eeg_data(:, :, i) = cont_data(:,range_pts);
    end
end

     




% =========================================================================


% function all_moving_epoch_ranges = extractSubepochRanges(all_cont_ranges, window_pts, overlap_pts)
%     all_moving_epoch_ranges = [];
% 
%     for i = 1:size(all_cont_ranges, 1)
%         seg_start = all_cont_ranges(i, 1);
%         seg_end = all_cont_ranges(i, 2);
% 
%         for w_start = seg_start : overlap_pts : seg_end
%             w_end = w_start + window_pts - 1;
%             if w_end > seg_end
%                 break;
%             end
%             all_moving_epoch_ranges(end+1, :) = [w_start, w_end];
%         end
%     end
% end
% 
% function subepoched_eeg_data = extractEegSubepochs(all_moving_epoch_ranges, epoched_eeg_data)
%     ranges = all_moving_epoch_ranges;
%     data = eeg_data;
% 
%     n_chans = size(eeg_data,1)
%     n_ranges = size(ranges, 1);
%     epoch_len  = ranges(1, 2) - ranges(1, 1) + 1;   % all ranges equal size
%     subepoched_data   = zeros(n_chans, epoch_len, n_ranges);
% 
%     for i = 1:n_ranges
%         range_pts = ranges(i, 1):ranges(i, 2);
%         subepoched_data(:, :, i) = data(:,);
%     end
% end


% % --- Test with sample data ---
% points = [1, 4; 5, 8; 9, 15];
% window = 4;
% step   = 2;
% out = sliding_windows(points, window, step);
% disp(out);

% function all_cont_ranges = extractContRange(time_data, sampling_interval)
%     temp1 = diff(time_data);
%     temp2 = temp1 ~= sampling_interval;
%     temp3a = find(temp2);
%     temp3b = temp3a+1;
% 
%     temp4 = [1, temp3b; temp3a, length(time_data)];
%     all_cont_ranges = permute(temp4, [2,1]);
% end






%% (ARCHIVE)

    % removing Cpz
    % EEG.moreInfo.chanLocsRefForInterp = EEG.chanlocs; %for later interp ref
    % 
    % rejChansNoInterp = {'Cpz'};
    % EEG = pop_select( EEG, 'rmchannel',rejChansNoInterp); %remove
    % EEG.moreInfo.noInterpCh = rejChansNoInterp;
    % 
    % idx = find(ismember({EEG.chanlocs.labels},rejChansNoInterp)); %update the later interp ref
    % EEG.moreInfo.chanLocsRefForInterp(idx) = [];

