% 
% STEPS:
%   1. manually load .dap (neuroscan Curry files) EEG data and save them as 
%      .set files, keep it like "P2G_1" in the incorrect_raw_eeg folder
% 
%   2. select only 1 incorrect raw eeg file
% 
%   3. in editEegEvent:
%       - mark "keep" to 0 for useless markers
%       - add more rows for missing markers, fill in "latency"
% 
%   4. in checkEegEvent, just double check if everything is good, then
%      proceed
% 
% 
% NOTES:
%   - inside 'incorrect_raw_eeg' folder -> data with incorrect markers and
%     useless time data
%   - inside 'correct_raw_eeg' folder -> raw data ready to be preprocessed
% 

clc; clear; close all;
project = initIGREE;
% ------- NOTE: initIGREE should recursively add all paths inside its main folder,
% no need below
% addpath(fullfile(project.dir.scripts,'eeg_shared_functions'));

inDir = fullfile(project.dir.data, "incorrect_raw_eeg");
outDir = fullfile(project.dir.data, "correct_raw_eeg");
inExt = "set"; outExt = "set";

% !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
% ------- TEMP: just select 1 per time
dataFile = findFilesToProcess({inDir, inExt}, {outDir, outExt});
if length(dataFile) > 1, error('>>>> only select 1 file at a time!'); end

fname = dataFile(1).fname;
bname = dataFile(1).bname;
filedir = dataFile(1).dir;

[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;
EEG = pop_loadset('filename',fname,'filepath',filedir);
eeglab redraw
[ALLEEG, EEG, CURRENTSET] = eeg_store( ALLEEG, EEG, 0 );

tempEEG = EEG; 
disp('>>>> ready to edit events')

%% ======= EDIT KEEP MARKERS =======

% auto select pv video legnth file
% ------- FIX: previously readmatrix fails
bname_lower = lower(bname);
pv_length_file = fullfile(project.dir.data, 'case_by_case', bname, [bname_lower, '_vid_duration.csv']);
L = readmatrix(pv_length_file, 'outputType', 'string');

% name = split(tempEEG.filename, '.');
% sub_name = name(1); 
% sub_folder = project.dir.data + "\case_by_case\" + sub_name;
% search_pattern = fullfile(sub_folder, '**', '*.csv');
% fileList = dir(search_pattern);
% select and load pv file
% disp('>>>> select the personalized video duration csv')
% [file, dir] = uigetfile('*.csv'); %only show csv
% L = readmatrix(fullfile(dir,file), 'outputType', 'string'); %NOTE outputype


% check pv video legnth file is in the latest format (only 2 cols)
if size(L, 2) ~= 2, error('>>>> pv video legnth file is not in the latest format!!!'); end
pv = L; %remove 1st row


% sort v1 v10 v11 v2 -> v1 v2 ... v10 v11
pv_idx = str2double(erase(pv(:, 1), 'v'));
[sorted_pv_idx, sort_mask] = sort(pv_idx);
pv = pv(sort_mask, :); 
pv(:, 1) = "p" + sorted_pv_idx;

% load gv
load(fullfile(project.dir.scripts, 'gv.mat'));

gb1 = ["gb1", "180000"];
gb2 = ["gb2", "180000"];
pb1 = ["pb1", "180000"];
pb2 = ["pb2", "180000"];

% classify G2P / P2G 
group = upper(bname(1:3));
if strcmp(group,'G2P')
    sessionDurations = [gb1;gv;gb2; pb1;pv;pb2];
elseif strcmp(group,'P2G')
    sessionDurations = [pb1;pv;pb2; gb1;gv;gb2];
end
% round the durations, weirdly some aren't integers (we used integer-long vids for e-studio3)
sessionDurations(:,2) = round(str2double(sessionDurations(:,2))); %originally str, turn to double, round and put it back. It will become str again

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

% ------- NOTE: sometimes the last marker is needed
% editEegEvent = editEegEvent(1:end-1);

open editEegEvent
open sessionDurations


disp('>>>> Checking:');
disp('>>>> set keep to 0 if that marker is fake');
disp('>>>> add rows for more markers');
disp(">>>> No need to edit 'type'");



%% ======= CHECK AGAIN =======
checkEegEvent = editEegEvent;

% check no. markers
nRealMarkers = size(sessionDurations,1);
nKeepMarkers = sum([checkEegEvent.keep]==1);

if nKeepMarkers ~= nRealMarkers
    fprintf("nRealMarkers = %d\n", nRealMarkers)
    fprintf("nKeepMarkers = %d\n", nKeepMarkers)
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
latencies = cell2mat({checkEegEvent.latency});
finDurations = cell2mat({checkEegEvent.finDuration});
overlapsAreNegative = latencies(2:end) - latencies(1:end-1) - finDurations(1:end-1);

if any(overlapsAreNegative<0), error('>>>> Sessions are overlapping!!!'); end

open checkEegEvent
disp('>>>> Ready to save');

%% ======= SAVE =======
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
newSetName = sprintf('%s_corrected_raw', bname);
newSetName = char(newSetName); % add this change to Char
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 0, 'setname', newSetName, 'gui','off');

% save set
EEG = pop_saveset( EEG, 'filename',bname,'filepath',char(outDir));
beep; cpbGreen('Done!');

% ------- NOTE: findFilesToProcess will automatically mkdir for outDir
% and we save the file as e.g. G2P_1.set and we use the folder to determine
% which step it is, currently config to be like this, hard to change
% everything now
% no need to update ALLEEG as it it just to track progress, we have the
% save in the disk so no need it

% ==========================================================
% NEW STEP: SAVE THE CORRECTED EEG DATASET TO YOUR HARD DRIVE
% ==========================================================

% % 3. Define your export directory (Change this path to wherever you want the files saved)
% if ~exist(outDir, 'dir')
%     mkdir(outDir);
% end
% 
% % 4. Create the final filename (e.g., "subject01_corrected_raw.set")
% exportFileName = sprintf('%s_corrected_raw.set', char(dataFile(fidx).bname));
% outDir = char(outDir); 
% exportFileName = char(exportFileName);
% EEG = pop_saveset(EEG, 'filename', exportFileName, 'filepath', outDir);
% 
% % 6. Update the master ALLEEG array with the newly saved file details
% ALLEEG(CURRENTSET) = EEG;
% 

%% Others below - just for convenience
%% (others) rid keep = 0 rows in editEegEvent
editEegEvent = editEegEvent([editEegEvent.keep] == 1); 

%% (others) rid calDuration = 1 rows in editEegEvent
editEegEvent = editEegEvent([editEegEvent.calDuration] ~= 1); 

%% dev fixing
% l = length(EEG.event)
% EEG.event(l-1).latency - (EEG.event(l-2).latency + EEG.event(l-2).finDuration)