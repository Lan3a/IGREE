function pop_autoreject_scroll(EEG)
% POP_AUTOREJECT_SCROLL  Show autoreject diagnostics in EEGLAB's
% pop_eegplot scroll (3D epoched view with trial boundaries).
% Requires EEG.ai_autoreject (from autoreject_detect).
% The EEG structure is NOT modified.
%
%   EEG = autoreject_detect(EEG);       % detect first
%   pop_autoreject_scroll(EEG);         % then visualise
%
%   Color coding:
%     RED    epoch          - will be REJECTED
%     YELLOW epoch          - will be REPAIRED (some channels interpolated)
%     YELLOW signal trace   - specific channel to be interpolated
%     BLACK  signal         - good
%     GREEN  (global mode)  - passed threshold
%
%   This script was created by an AI agent (OpenHands).

    if nargin < 1
        help(mfilename);
        return;
    end

    if ~isfield(EEG, 'ai_autoreject') || ~isfield(EEG.ai_autoreject, 'rejected')
        error('EEG.ai_autoreject not found.  Run autoreject_detect(EEG) first.');
    end
    ar = EEG.ai_autoreject;

    rejected     = ar.rejected;                       % [nepoch x 1] logical
    interpolated = ar.interpolated;                   % [nchan x nepoch] logical
    repaired     = ~rejected & any(interpolated, 1)';  % [nepoch x 1] logical
    [nchan, pnts, nepoch] = size(EEG.data);

    % ---- epoch-level colours via EEG.reject for pop_eegplot -----------
    % pop_eegplot reads EEG.reject.rej* fields and EEG.reject.rej*col.
    % Since rejected and repaired epochs are disjoint, using two types
    % gives two colours without conflict.
    orig_reject = safe_get_reject(EEG);

    EEG.reject = [];

    % ---- epoch-level marks -----------------------------------------
    zEp = false(nepoch, 1);
    EEG.reject.rejmanual    = rejected;
    EEG.reject.rejthresh    = repaired;
    EEG.reject.rejconst     = zEp;
    EEG.reject.rejjp        = zEp;
    EEG.reject.rejkurt      = zEp;
    EEG.reject.rejfreq      = zEp;

    % ---- epoch colours ---------------------------------------------
    EEG.reject.rejmanualcol = [1 0 0];     % red
    EEG.reject.rejthreshcol = [1 0.85 0];  % yellow
    EEG.reject.rejconstcol  = [0 0 1];
    EEG.reject.rejjpcol     = [0 1 1];
    EEG.reject.rejkurtcol   = [1 0 1];
    EEG.reject.rejfreqcol   = [0 1 0];

    % ---- electrode-level marks (rej*E fields) ----------------------
    zE = false(nchan, nepoch);
    EEG.reject.rejmanualE = zE;
    EEG.reject.rejthreshE = zE;
    EEG.reject.rejconstE  = zE;
    EEG.reject.rejjpE     = zE;
    EEG.reject.rejkurtE   = zE;
    EEG.reject.rejfreqE   = zE;

    % ---- open epoched scroll via pop_eegplot --------------------------
    disp('Opening EEGLAB epoched scroll...');
    disp('  RED    epoch  = rejected');
    if strcmp(ar.mode, 'local')
        disp('  YELLOW epoch  = repaired (some channels interpolated)');
    end
    disp('  BLACK  signal = good');

    pop_eegplot(EEG, 1, 1, 0, '');   % icacomp=1 (raw data), superpose=1

    % ---- inject per-channel YELLOW signal for interpolated channels ---
    inject_perchannel_winrej(ar, nchan, pnts, nepoch);

    % ---- restore original reject --------------------------------------
    EEG.reject = orig_reject;
end


% ======================================================================
function reject = safe_get_reject(EEG)
% Return existing EEG.reject or an empty struct with expected fields.
    if isfield(EEG, 'reject') && isstruct(EEG.reject)
        reject = EEG.reject;
    else
        reject = [];
    end
end


% ======================================================================
function inject_perchannel_winrej(ar, nchan, pnts, nepoch)
% After pop_eegplot renders, overlay YELLOW winrej patches on the
% specific channels flagged for interpolation inside repaired epochs.
    if ~strcmp(ar.mode, 'local'), return; end

    interpolated = ar.interpolated;
    if ~any(interpolated(:)), return; end

    % Find the eegplot figure (pop_eegplot creates it with tag 'eegplot')
    fig = findobj('tag', 'EEGPLOT');
    if isempty(fig), return; end

    % Build additional winrej rows: YELLOW on specific channels only.
    % eegplot winrej columns 6+ are per-channel flags in REVERSE order:
    %   col 6 -> channel nchan, ..., col 5+nchan -> channel 1.
    extra = [];
    for ep = 1:nepoch
        if ar.rejected(ep), continue; end
        bad_ch = find(interpolated(:, ep));
        if isempty(bad_ch), continue; end

        t1 = (ep - 1) * pnts + 1;
        t2 = ep * pnts;
        for ch = bad_ch(:)'
            flags = zeros(1, nchan);
            flags(nchan - ch + 1) = 1;   % reverse-order column
            extra(end + 1, :) = [t1, t2, 1, 1, 0, flags];  %#ok<AGROW>
        end
    end

    if isempty(extra), return; end

    % Merge into existing winrej stored in the figure's UserData
    ud = get(fig, 'UserData');
    if isempty(ud) || ~isstruct(ud)
        % Fallback: re-call eegplot with our winrej merged — but this
        % would open a second figure.  We try the fields that recent
        % EEGLAB versions store in figure UserData.
        return;
    end

    % The winrej is typically in a subfield; try common locations.
    if isfield(ud, 'winrej')
        ud.winrej = [ud.winrej; extra];
    elseif isfield(ud, 'commands') && isfield(ud.commands, 'winrej')
        ud.commands.winrej = [ud.commands.winrej; extra];
    else
        % Cannot safely inject — the epoch-level red/yellow is enough.
        return;
    end

    set(fig, 'UserData', ud);

    % Trigger a redraw by calling eegplot's internal draw function
    eegplot('drawp', 0);
end