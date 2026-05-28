function [epochedData, samplesPerEpoch, epochSessionIdx] = t_epoch_1s_concat_by_session(EEG, epochLenSecond)
%EPOCH_1S_CONCAT_BY_SESSION  1 s epochs per session segment, tail-padded, cat in dim 3.
%
%   [epochedData, samplesPerEpoch, epochSessionIdx] = epoch_1s_concat_by_session(EEG)
%   [epochedData, samplesPerEpoch, epochSessionIdx] = epoch_1s_concat_by_session(EEG, epochLenSecond)
%
% Uses EEG.moreInfo.sessionIdxChannel (1 x nTime) aligned with EEG.data columns.
% Splits into contiguous runs of constant non-zero session index. For each run,
% forms non-overlapping epochs of length round(epochLenSecond * EEG.srate);
% zero-pads the last epoch of that run only if it is shorter than one epoch.
% Concatenates all epochs along the third dimension:
%   size(epochedData) == [nChans, samplesPerEpoch, nEpochs].
%
% epochSessionIdx is 1 x nEpochs with the session index for each epoch.
%
% If sessionIdxChannel is missing or empty, falls back to one segment over all
% columns of EEG.data (same as global ceil/reshape with end padding).

if nargin < 2 || isempty(epochLenSecond)
    epochLenSecond = 1;
end

srate = EEG.srate;
data = EEG.data;
nChans = size(data, 1);
nPts = size(data, 2);
samplesPerEpoch = round(epochLenSecond * srate);

useSessionChannel = isfield(EEG, 'moreInfo') ...
    && isfield(EEG.moreInfo, 'sessionIdxChannel') ...
    && ~isempty(EEG.moreInfo.sessionIdxChannel);

if useSessionChannel
    sid = double(EEG.moreInfo.sessionIdxChannel(:)');
    if numel(sid) ~= nPts
        error('t_epoch_1s_concat_by_session:badSessionIdxChannel', ...
            'sessionIdxChannel length (%d) must match EEG.data time points (%d).', ...
            numel(sid), nPts);
    end
    changeIdx = [1, find(diff(sid) ~= 0) + 1, nPts + 1];
    chunks = {};
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
        chunks{end + 1} = reshape(seg, nChans, samplesPerEpoch, nEp); %#ok<AGROW>
        epochSessionIdxParts{end + 1} = repmat(thisSid, 1, nEp); %#ok<AGROW>
    end
    if isempty(chunks)
        error('t_epoch_1s_concat_by_session:noSegments', ...
            'No non-zero sessionIdx segments found in sessionIdxChannel.');
    end
    epochedData = cat(3, chunks{:});
    epochSessionIdx = [epochSessionIdxParts{:}];
else
    nEp = ceil(nPts / samplesPerEpoch);
    padN = nEp * samplesPerEpoch - nPts;
    seg = data;
    if padN > 0
        seg = [seg, zeros(nChans, padN)];
    end
    epochedData = reshape(seg, nChans, samplesPerEpoch, nEp);
    epochSessionIdx = ones(1, nEp);
end
end
