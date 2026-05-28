% 
% NOTES:
%   - inside 'incorrect_raw_eeg' folder -> data with incorrect markers and
%     useless time data
%   - inside 'correct_raw_eeg' folder -> raw data ready to be preprocessed
% 
% IMPORTANT:
%   - First manually load all .dap (neuroscan Curry files) EEG data,
%     and save them as .set with filename: e.g. "P2G_1"
%     in 'incorrect_raw_eeg' folder
% 


clc; clear; close all;
project = initIGREE;
addpath(fullfile(project.dir.scripts,'eeg_shared_functions'));
addpath(fullfile(project.dir.scripts,'zx_local_archive'));


inDir = fullfile(project.dir.data, "incorrect_raw_eeg");
outDir = fullfile(project.dir.data, "correct_raw_eeg");
inExt = "set"; outExt = "set";
dataFiles = findFilesToProcess({inDir, inExt}, {outDir, outExt});

%TEMP
fidx = 1;
[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;
EEG = pop_loadset('filename',dataFiles(fidx).fname,'filepath',dataFiles(fidx).dir);
eeglab redraw
[ALLEEG, EEG, CURRENTSET] = eeg_store( ALLEEG, EEG, 0 );

tempEEG = EEG;

%% EDIT KEEP MARKERS

% auto select pv video legnth file
name = split(tempEEG.filename, '.');
sub_name = name(1); 
sub_folder = project.dir.data + "\case_by_case\" + sub_name;
search_pattern = fullfile(sub_folder, '**', '*.csv');
fileList = dir(search_pattern);
% select and load pv file
% disp('>>>> select the personalized video duration csv')
% [file, dir] = uigetfile('*.csv'); %only show csv
% L = readmatrix(fullfile(dir,file), 'outputType', 'string'); %NOTE outputype
L = readmatrix(fullfile(fileList.folder, fileList.name), 'outputType', 'string'); %NOTE outputype

% based on previous Ice's past script for personalized video duration data
% remove 1st row and 1st col
%pv = L(2:end, 2:end);
pv = L;

% sort v1 v10 v11 v2 -> v1 v2 ... v10 v11
pv_idx = str2double(erase(pv(:, 1), 'v'));
[sorted_pv_idx, sort_mask] = sort(pv_idx);
pv = pv(sort_mask, :); %NOTE pv() = pv is diff from pv = pv() operations bro matlab pls
pv(:, 1) = "p" + sorted_pv_idx;


%%
% load gv
load(fullfile(project.dir.scripts, 'gv.mat'));

gb1 = ["gb1", "180000"];
gb2 = ["gb2", "180000"];
pb1 = ["pb1", "180000"];
pb2 = ["pb2", "180000"];

group = upper(fileList.name(1:3));
if strcmp(group,'G2P')
    sessionDurations = [gb1;gv;gb2; pb1;pv;pb2];
elseif strcmp(group,'P2G')
    sessionDurations = [pb1;pv;pb2; gb1;gv;gb2];
end

%%
editEegEvent = EEG.event;

editEegEvent = rmfield(editEegEvent, 'urevent');

for i = 1:numel(editEegEvent)
    editEegEvent(i).keep = 1;
end

% add 'calDurations' field
calDurations = diff([editEegEvent.latency]);
calDurations = [calDurations 0]; % no next one for last label
calDurations = num2cell(calDurations);
[editEegEvent.calDuration] = calDurations{:};

editEegEvent = editEegEvent(1:end-1);

% % add 'refDurations' field
% refDurations = str2double(sessionDurations(:,2));
% for i = 1:size(sessionDurations,1)
%     editEegEvent(i).refDuration = refDurations(i);
% end

open editEegEvent
open sessionDurations



%%
checkEegEvent = editEegEvent;

% check no. markers
nRealMarkers = size(sessionDurations,1);
nKeepMarkers = sum([checkEegEvent.keep]==1);

if nKeepMarkers ~= nRealMarkers
    error('>>>> Incorrect number of markers!!!')
end


% reorder markers based on 'latency' (in case it's not sorted manually)
latencies = [checkEegEvent.latency];
[~, order] = sort(latencies, 'ascend');
checkEegEvent = checkEegEvent(order);

% keep only (keep == 1) markers
checkEegEvent = checkEegEvent([checkEegEvent.keep] == 1); 
checkEegEvent = rmfield(checkEegEvent, 'keep');

% refill 'calDurations' field
calDurations = diff([checkEegEvent.latency]);
calDurations = [calDurations 0]; % no next one for last label
calDurations = num2cell(calDurations);
[checkEegEvent.calDuration] = calDurations{:};

% fill 'type' and refill 'refDurations' fields
markerNames = cellstr(sessionDurations(:,1)); %cellstr becomes char not string
refDurations = str2double(sessionDurations(:,2));
for i = 1:length(checkEegEvent)
    checkEegEvent(i).type = markerNames(i);
    checkEegEvent(i).refDuration = refDurations(i);
end

% add 'continue' field
nMarkers = length(checkEegEvent);
continueCol = num2cell(ones(nMarkers,1));
[checkEegEvent.continue] = continueCol{:};

markerNames = {checkEegEvent.type};
markerNames = string(markerNames);
gb1_idx = find(strcmp(markerNames,'gb1'));
gb2_idx = find(strcmp(markerNames,'gb2'));
pb1_idx = find(strcmp(markerNames,'pb1'));
pb2_idx = find(strcmp(markerNames,'pb2'));

checkEegEvent(gb1_idx).continue = 0;
checkEegEvent(gb2_idx-1).continue = 0;
checkEegEvent(gb2_idx).continue = 0;
checkEegEvent(pb1_idx).continue = 0;
checkEegEvent(pb2_idx-1).continue = 0;
checkEegEvent(pb2_idx).continue = 0;

for i = 1:length(checkEegEvent)
    if checkEegEvent(i).continue == 1
        checkEegEvent(i).finDuration = checkEegEvent(i).calDuration;
    else
        checkEegEvent(i).finDuration = checkEegEvent(i).refDuration;
    end
end

latencies = cell2mat({checkEegEvent.latency});
finDurations = cell2mat({checkEegEvent.finDuration});
overlapsAreNegative = latencies(2:end) - latencies(1:end-1) - finDurations(1:end-1);

for i = 1:length(checkEegEvent)
    t = char(checkEegEvent(i).type);
    switch t
        case 'gb1'
            idx = 1;
        case 'gb2'
            idx = 2;
        case 'pb1'
            idx = 3;
        case 'pb2'
            idx = 4;
        otherwise
            if startsWith(t,'g')
                n = str2double(t(2:end));
                
                idx = 10 + n;
                
            elseif startsWith(t,'p')
                n = str2double(t(2:end));
                idx = 30 + n;
            else
                error('Unknown type: %s',t);
            end
    end
    checkEegEvent(i).sessionIdx = idx;
end

% Handle accidental session overlaps
if any(overlapsAreNegative<0), error('>>>> Sessions are overlapping!!!'); end

open checkEegEvent

%% Save
finalEegEvent = checkEegEvent;
finalEegEvent = rmfield(finalEegEvent, {'calDuration', 'refDuration', 'continue'});

EEG = tempEEG;

% Add back to EEG.event
EEG.event = finalEegEvent;
EEG.urevent = finalEegEvent;

for i = 1:length(EEG.event)
    EEG.event(i).urevent = i;
end
% added this. the type is cell change to Char
if isfield(EEG, 'event') && ~isempty(EEG.event)
    for i = 1:length(EEG.event)
        if iscell(EEG.event(i).type)
            if ~isempty(EEG.event(i).type)
                EEG.event(i).type = EEG.event(i).type{1};
            else
                EEG.event(i).type = 'unknown'; % Safe fallback for empty cells
            end
        end
    end
end

% remove unused channels
EEG = pop_select( EEG, 'channel', project.useChannels); %BUG the rejection suddenly didn't work

% trim start-end
startMarkerIdx = 1;
endMarkerIdx = length(EEG.event);
startTimePt = EEG.event(startMarkerIdx).latency;
endTimePt = EEG.event(endMarkerIdx).latency + EEG.event(endMarkerIdx).finDuration;
% keepDataPeriod = [startTimePt, endTimePt];

% --- FIX: Bound and round the sample points safely ---
keepDataPeriod = [startTimePt, endTimePt];
keepDataPeriod = round(keepDataPeriod); % Convert 0.5000 to 1, or round any fractions
if keepDataPeriod(1) < 1
    keepDataPeriod(1) = 1; % Force the start to be sample 1 if it falls below 1
end
if keepDataPeriod(2) > EEG.pnts
    keepDataPeriod(2) = EEG.pnts; % Protect against overshoot past the last sample
end

EEG = pop_select( EEG, 'point',keepDataPeriod );
newSetName = sprintf('%s_corrected_raw', dataFiles(fidx).bname);
newSetName = char(newSetName); % add this change to Char
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 0, 'setname', newSetName, 'gui','off');
           

% ==========================================================
% NEW STEP: SAVE THE CORRECTED EEG DATASET TO YOUR HARD DRIVE
% ==========================================================

% 3. Define your export directory (Change this path to wherever you want the files saved)
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

% 4. Create the final filename (e.g., "subject01_corrected_raw.set")
exportFileName = sprintf('%s_corrected_raw.set', char(dataFiles(fidx).bname));
outDir = char(outDir); 
exportFileName = char(exportFileName);
EEG = pop_saveset(EEG, 'filename', exportFileName, 'filepath', outDir);

% 6. Update the master ALLEEG array with the newly saved file details
ALLEEG(CURRENTSET) = EEG;

