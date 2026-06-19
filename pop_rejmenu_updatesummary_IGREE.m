function pop_rejmenu_IGREE_updatesummary(EEG, icacomp, tagmenu)
% Update the epoch summary text in pop_rejmenu_IGREE.
%
% Shows "<remaining> remains (<rejected> / <total> rejected)" for the
% epochs currently marked in EEG, plus historical tracking info from
% EEG.moreInfo.rejEpochs when available.

fig = [];
try
    fig = findobj('type', 'figure', 'tag', tagmenu);
catch
    fig = [];
end
if isempty(fig) || ~ishandle(fig)
    try
        fig = gcf;
    catch
        fig = [];
    end
end
if isempty(fig) || ~ishandle(fig)
    return;
end

origtrials = [];
try
    origtrials = getappdata(fig, 'pop_rejmenu_IGREE_origtrials');
catch
    origtrials = [];
end
if isempty(origtrials)
    origtrials = EEG.trials;
end

try
    EEG = eeg_rejsuperpose(EEG, icacomp, 1,1,1,1,1,1,1);
catch
    % if eeg_rejsuperpose is unavailable or errors, do not crash the GUI
end

rejcount = 0;
if isfield(EEG, 'reject') && isfield(EEG.reject, 'rejglobal') && ~isempty(EEG.reject.rejglobal)
    rejcount = sum(EEG.reject.rejglobal);
end
remcount = origtrials - rejcount;

% historical tracking info from EEG.moreInfo
tracking_info = '';
try
    if isfield(EEG, 'moreInfo') && isfield(EEG.moreInfo, 'rejEpochs') && ~isempty(EEG.moreInfo.rejEpochs)
        nOrig = length(EEG.moreInfo.rejEpochs);
        nRejHist = sum(EEG.moreInfo.rejEpochs);
        if nOrig > origtrials || nRejHist > 0
            tracking_info = sprintf(' | History: %d/%d original epochs rejected', nRejHist, nOrig);
        end
    end
catch
    tracking_info = '';
end

hsum = findobj('parent', fig, 'tag', 'epochsummary');
if ~isempty(hsum)
    set(hsum, 'string', sprintf('%d remains (%d / %d rejected)%s', ...
                                remcount, rejcount, origtrials, tracking_info));
end

