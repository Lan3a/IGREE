
%TODO fix data still in another script, do these:
% - fix markers
% - trim out unnecesary regions
% - add custom event and time channels (better since epoching directly
% deletes marked ones, so just put the event and time channels in

clc; clear; close all;
project = initIGREE;

[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;

%TEMP load an eeg set
EEG = pop_loadset('filename','G2P_1_raw.set','filepath','C:\\Users\\user\\Desktop\\Work\\EEE-master\\ALL_DATA\\batch_raw\\');
[ALLEEG, EEG, CURRENTSET] = eeg_store( ALLEEG, EEG, 0 );

% resample to 500 Hz
EEG = pop_resample( EEG, 500);

% band filtering
EEG = pop_eegfiltnew(EEG, 'locutoff',48,'hicutoff',52,'revfilt',1); % notch 48-52 Hz
EEG = pop_eegfiltnew(EEG, 'locutoff',1,'hicutoff',98); % band pass 1-98 Hz 

[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 0,'setname','filtered','gui','off'); 
eeglab redraw


%% bad channel rejection 
% (doing manually here to ensure highest quality, as we don't have too much participant)

while true
    rejBadChanGUI(EEG);
    custom_pop_spectopo(EEG);
    break
end

%% CAR reference, bad channel interp, run ICA

% re-reference (with CAR)
EEG = pop_reref( EEG, []);

% removing Cz
EEG = pop_select( EEG, 'rmchannel',{'Cz'});

%TODO if chans are rejected, do ICA run a bit differently?

% run ICA
EEG = pop_runica(EEG, 'icatype', 'runica', 'extended',1,'interrupt','on');

%% ICA rejection

rejICsGUI(EEG);

%% %TEMP

EEG = pop_loadset('filename','test_G2P_1.set','filepath','C:\\Users\\user\\Desktop\\Work\\CUHK\\IG_Reels_Emotion_EEG\\data\\correct_raw\\');
[ALLEEG, EEG, CURRENTSET] = eeg_store( ALLEEG, EEG, 0 );

% resample to 500 Hz
EEG = pop_resample( EEG, 500);

% band filtering
EEG = pop_eegfiltnew(EEG, 'locutoff',48,'hicutoff',52,'revfilt',1); % notch 48-52 Hz
EEG = pop_eegfiltnew(EEG, 'locutoff',1,'hicutoff',98); % band pass 1-98 Hz 

backupEEG = EEG;
eeglab redraw

%% interpolate bad channel and final re-reference

%TODO interp bad chans
EEG = pop_interp(EEG, EEG.moreInfo.originalChanLocs);

% re-reference (with CAR)
EEG = pop_reref( EEG, []);


%% Add TIMEMS and SESSIONIDX channels (AI helped)

% DEV
EEG = backupEEG;

tempChanLocs = EEG.chanlocs;

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



% necessary so that creating new set won't break chanlocs
ALLEEG(end).chanlocs = EEG.chanlocs;
ALLEEG(end).nbchan = EEG.nbchan;

[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 0,'setname','custom channels added','gui','off'); 



%% Epoching and rejecting bad epochs (AI helped)

tempChanLocs = EEG.chanlocs;
tempMoreInfo = EEG.moreInfo;

epochLenSecond = 1;
% FUTURE add more if need overlapping regions for more data

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


%% del

% fix vars




%XX
% moreInfo = EEG.moreInfo;
% 
% [epochedData, samplesPerEpoch, epochSessionIdx] = t_epoch_1s_concat_by_session(EEG, epochLenSecond);
% 
% srate = EEG.srate;
% EEG = pop_importdata('setname', 'epoched data', 'data', epochedData, ...
%     'dataformat', 'array', 'chanlocs', moreInfo.originalChanLocs, ...
%     'srate', srate, 'pnts', samplesPerEpoch, 'xmin', 0);
% EEG = eeg_checkset(EEG);
% EEG.moreInfo = moreInfo;
% EEG.moreInfo.epochSessionIdx = epochSessionIdx;


% epochLenSecond = 1;
% %FUTURE add more if need overlapping regions for more data
% 
% % preserve moreInfo stuff
% moreInfo = EEG.moreInfo;
% 
% % Epoch data
% srate = EEG.srate;
% nPnts = EEG.pnts;
% nChans = EEG.nbchan;
% samplesPerEpoch = round(epochLenSecond * srate);   % 2 seconds in samples
% nEpochs = ceil(nPnts / samplesPerEpoch);
% 
% epochedData = EEG.data;
% nPntsAtEnd = (nEpochs * samplesPerEpoch) - nPnts;
% PntsAtEnd = zeros(nChans, nPntsAtEnd);
% epochedData = [epochedData, PntsAtEnd];
% epochedData = reshape(epochedData, nChans, samplesPerEpoch, nEpochs);
% 
% 
% 
% EEG = pop_importdata('setname','epoched data', 'data',epochedData, 'dataformat','array', 'chanlocs', EEG.moreInfo.originalChanLocs, 'srate', srate, 'pnts', srate);
% % ^ Simply use pop_importdata() to put the epoched data in, everything
% % else will be adjusted. It's better than forcibly subbing the
% % epoched_data to EEG.data, use their own functions for it to adjust
% % workspace vars manually.
% EEG = eeg_checkset(EEG);
% 
% % add back moreInfo to EEG
% EEG.moreInfo = moreInfo;
%%

allChanData = cat(1, EEG.data, EEG.moreInfo.epochedTimeMsChannel, EEG.moreInfo.epochedSessionIdxChannel);
IGREE_pop_rejmenu(EEG, 1, allChanData)

EEG.nbchan = EEG.nbchan + 2;
tempChanLocs(end+1).labels = 'TIMEMS';
tempChanLocs(end+1).labels = 'SESSIONIDX';

% necessary so that creating new set won't break chanlocs
ALLEEG(end).chanlocs = EEG.chanlocs;
ALLEEG(end).nbchan = EEG.nbchan;

[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 0,'setname','bad epoch rejected','gui','off'); 


%XX
% icacomp = 0;
% [EEG, LASTCOM] = eeg_rejsuperpose(EEG, icacomp, 1, 1, 1, 1, 1, 1, 1);
% [EEG, LASTCOM] = pop_rejepoch(EEG, EEG.reject.rejglobal, 1);
















%% XX Add TIMEMS and SESSIONIDX channels
% 
% EEG = tempEEG
% tempChanLocs = EEG.chanlocs;
% 
% % find boundary latency values
% % event_types = {EEG.event.type}
% % real_idx = find(not(strcmp(event_types, 'boundary')))
% 
% % init time channel
% nPts = size(EEG.data, 2); % Basically EEG.nbchan and EEG.pnts
% timeMsChannel = zeros(1, nPts);
% sessionIdxChannel = zeros(1,nPts);
% 
% for i = 1:length(EEG.event)
%     labels = EEG.event(i).type;
%     if ~strcmp(labels,'boundary')
%         latency = EEG.event(i).latency;
%         finalDuration = EEG.event(i).finDuration; % measured in ms (with 1000 Hz)
% 
%         % NOTE: used floor() instead of round() to prevent going off-bounds
%         % (exceeding EEG.data time size)
%         startPt = floor(latency);
%         stopPt = startPt + floor(finalDuration / 2); %... 1000 -> 500 Hz (divide by 2)
%         sessionPts = (stopPt - startPt) + 1;
% 
%         timeMsChannel(startPt:stopPt) = 1:2:(1+2*(sessionPts-1)); %... 1st_val + leap*(session_pts - 1)
%         sessionIdxChannel(startPt:stopPt) = EEG.event(i).sessionIdx;
%     else
%         disp("detected boundary type (shouldn't exist yet), skipping...")
%     end
% end
% 
% % Put it to EEG.data
% EEG.data = [EEG.data; timeMsChannel; sessionIdxChannel];
% 
% % fix EEG variables
% EEG.nbchan = EEG.nbchan + 2;
% EEG.chanlocs = tempChanLocs;
% EEG.chanlocs(end+1).labels = 'TIMEMS';
% EEG.chanlocs(end+1).labels = 'SESSIONIDX';
% 
% % necessary so that creating new set won't break chanlocs
% ALLEEG(end).chanlocs = EEG.chanlocs;
% ALLEEG(end).nbchan = EEG.nbchan;
% 
% [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 0,'setname','custom channels added','gui','off'); 



%%