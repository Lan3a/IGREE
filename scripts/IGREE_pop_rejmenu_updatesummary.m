function IGREE_pop_rejmenu_updatesummary(EEG, icacomp, tagmenu)
% Update the epoch summary text in IGREE_pop_rejmenu.
%
% Shows "<remaining> remains (<rejected> / <total> rejected)" for the
% epochs currently marked in EEG. When IGREE_pop_rejmenu was launched
% with a full-channel 3-D matrix (data_full), the channel count of that
% matrix is appended to the summary so the user can confirm the REJECT
% button will operate on the full set of channels.

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
    origtrials = getappdata(fig, 'IGREE_pop_rejmenu_origtrials');
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

full_info = '';
try
    data_full = getappdata(fig, 'IGREE_pop_rejmenu_data_full');
    if ~isempty(data_full) && isnumeric(data_full) && ndims(data_full) == 3
        full_info = sprintf(' | REJECT target: full data %d ch x %d pnts', ...
                            size(data_full, 1), size(data_full, 2));
    end
catch
    full_info = '';
end

hsum = findobj('parent', fig, 'tag', 'epochsummary');
if ~isempty(hsum)
    set(hsum, 'string', sprintf('%d remains (%d / %d rejected)%s', ...
                                remcount, rejcount, origtrials, full_info));
end

