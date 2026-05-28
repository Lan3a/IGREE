function custom_pop_rejmenu_updatesummary(EEG, icacomp, tagmenu)
% Update the epoch summary text in custom_pop_rejmenu_PAEEG

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
    origtrials = getappdata(fig, 'custom_pop_rejmenu_PAEEG_origtrials');
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

hsum = findobj('parent', fig, 'tag', 'epochsummary');
if ~isempty(hsum)
    set(hsum, 'string', sprintf('%d remains (%d / %d rejected)', remcount, rejcount, origtrials));
end

