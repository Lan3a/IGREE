
clc; clear; close all;
project = initIGREE;

[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;


%% interpolate bad channel, final re-reference, and rejecting bad epochs

inDir = fullfile(project.dir.data, "preprocess_eeg", "ICA_done");
outDir = fullfile(project.dir.data, "preprocess_eeg", "Epoch_rejection_done");
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
    %FUTURE add more if need overlapping regions for more data

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

    EEG.moreInfo = tempMoreInfo;
    EEG.moreInfo.epochedTimeMsChannel = cat(3, timeMsChunks{:});
    EEG.moreInfo.epochedSessionIdxChannel = cat(3, sessionIdxChunks{:});

    % newSetName = sprintf()
    [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 0,'setname','custom chans added','gui','off');
    

    % -------------------------------------------------------------------------
    % rejecting bad epochs
    allChanData = cat(1, EEG.data, EEG.moreInfo.epochedTimeMsChannel, EEG.moreInfo.epochedSessionIdxChannel);
    tempEEG = EEG;
end

%%

EEG = tempEEG;
% Step 1 — DETECT (no data modification)
EEG = autoreject_detect(EEG);

%%

% Step 2 — SCROLL (review diagnostics)
pop_autoreject_scroll(EEG);





