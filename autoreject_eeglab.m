function EEG = autoreject_eeglab(EEG, varargin)
% AUTOREJECT_EEGLAB  Automated artifact rejection for epoched EEG data.
%
%   EEG = autoreject_eeglab(EEG) runs local autoreject (per-channel
%   thresholds + repair-or-reject decision) on the epoched EEG structure.
%
%   EEG = autoreject_eeglab(EEG, 'mode', 'global') uses a single global
%   threshold for all channels (faster but coarser).
%
%   OPTIONAL PARAMETERS (name-value pairs):
%   ------------------------------------------------------------
%   'mode'          : 'local' (default) or 'global'
%   'n_folds'       : number of CV folds          (default: 5)
%   'n_thresh'      : number of threshold candidates (default: 50)
%   'thresh_lims'   : [low high] percentile range for threshold
%                     search (default: [5 99])
%   'verbose'       : true/false show progress    (default: true)
%
%   OUTPUT:
%   ------------------------------------------------------------
%   EEG structure with:
%     EEG.data          - cleaned data [nchan x nsamples x nepochs_kept]
%     EEG.epoch         - trimmed epoch structure
%     EEG.autoreject    - diagnostics struct with fields:
%         .mode            'global' or 'local'
%         .thresh_global   global threshold (global mode)
%         .thresh_per_chan per-channel thresholds (local mode)
%         .k_reject        max bad chans before rejecting (local mode)
%         .rejected        logical vector of rejected epochs
%         .interpolated    logical matrix [nchan x nepochs] of interpolated
%                          data points (local mode)
%         .cv_scores       cross-validation scores
%
%   ALGORITHM (local mode):
%   ------------------------------------------------------------
%   1. For each sensor, find the optimal peak-to-peak threshold
%      that minimizes the cross-validation RMSE between the mean of
%      the training set (after removing bad trials) and the median
%      of the validation set.
%   2. For each trial, count how many sensors exceed their threshold.
%   3. Use cross-validation to find the optimal cutoff k: trials with
%      > k bad sensors are rejected; trials with <= k bad sensors are
%      repaired by spatial interpolation from neighboring sensors.
%
%   REFERENCES:
%   Jas, Engemann, Bekhti, Raimondo & Gramfort (2017).
%   Autoreject: Automated artifact rejection for MEG and EEG data.
%   NeuroImage, 159, 417-429.
%
%   This script was created by an AI agent (OpenHands).

    % ==================================================================
    % PARSE INPUTS
    % ==================================================================
    p = inputParser;
    p.addParameter('mode',          'local',   @(x) ismember(x, {'global', 'local'}));
    p.addParameter('n_folds',       5,         @(x) isscalar(x) && x > 1 && x == round(x));
    p.addParameter('n_thresh',      50,        @(x) isscalar(x) && x > 1 && x == round(x));
    p.addParameter('thresh_lims',   [5 99],   @(x) isnumeric(x) && numel(x) == 2);
    p.addParameter('verbose',       true,      @islogical);
    parse(p, varargin{:});
    opts = p.Results;

    % Basic checks
    if ndims(EEG.data) ~= 3
        error('EEG.data must be 3D: [channels x samples x epochs].');
    end

    [nchan, nsamp, nepoch] = size(EEG.data);
    if opts.verbose
        fprintf('Autoreject: %d channels, %d samples, %d epochs (mode=''%s'')\n', ...
                nchan, nsamp, nepoch, opts.mode);
    end

    % ==================================================================
    % COMPUTE PEAK-TO-PEAK MATRIX  [nchan x nepoch]
    % ==================================================================
    pp = reshape(max(EEG.data, [], 2) - min(EEG.data, [], 2), nchan, nepoch);

    if strcmp(opts.mode, 'global')
        EEG = autoreject_global(EEG, pp, opts);
    else
        EEG = autoreject_local(EEG, pp, opts);
    end
end


% ======================================================================
function EEG = autoreject_global(EEG, pp, opts)
% ======================================================================
% Single global threshold: max pp across all channels per epoch.
    global_pp = max(pp, [], 1)';   % [nepoch x 1]

    % --- Candidate thresholds ---
    candidates = candidate_thresholds(global_pp, opts.n_thresh, opts.thresh_lims);
    if isempty(candidates)
        warning('Autoreject: too few epochs to search thresholds; skipping.');
        nepoch = EEG.trials;
        EEG.autoreject = struct('mode','global','thresh_global',Inf, ...
            'rejected',false(nepoch,1),'interpolated',false(EEG.nbchan,nepoch));
        return;
    end

    % --- K-fold cross-validation ---
    nepoch   = size(EEG.data, 3);
    fold_idx = cv_folds(nepoch, opts.n_folds);
    scores   = zeros(size(candidates));

    for i_th = 1:length(candidates)
        th = candidates(i_th);
        fold_errs = zeros(opts.n_folds, 1);
        for k = 1:opts.n_folds
            fold_errs(k) = cv_error_global(EEG.data, global_pp, fold_idx, k, th);
        end
        scores(i_th) = nanmean(fold_errs);
    end

    [~, best] = min(scores);
    opt_th    = candidates(best);

    % --- Apply ---
    bad = global_pp > opt_th;
    EEG  = drop_epochs(EEG, bad);

    if opts.verbose
        fprintf('  Global threshold = %.2f  |  rejected %d/%d epochs\n', ...
                opt_th, sum(bad), length(bad));
    end

    nchan_orig  = size(EEG.data, 1);
    nepoch_orig = length(bad);
    EEG.autoreject = struct('mode','global','thresh_global',opt_th, ...
                            'rejected',bad,'interpolated',false(nchan_orig, nepoch_orig), ...
                            'cv_scores',struct('candidates',candidates,'scores',scores));
end


% ======================================================================
function EEG = autoreject_local(EEG, pp, opts)
% ======================================================================
% Per-channel thresholds + repair-vs-reject decision.
    [nchan, nsamp, nepoch] = size(EEG.data);
    fold_idx = cv_folds(nepoch, opts.n_folds);

    % ----------------------------------------------------------------
    % STEP 1: Find optimal threshold for each channel
    % ----------------------------------------------------------------
    thresh_per_chan = zeros(nchan, 1);
    for ch = 1:nchan
        thresh_per_chan(ch) = optimal_threshold_1d(pp(ch, :)', EEG.data, fold_idx, ch, opts);
    end

    if opts.verbose
        fprintf('  Per-channel thresholds: min=%.2f  median=%.2f  max=%.2f\n', ...
                min(thresh_per_chan), median(thresh_per_chan), max(thresh_per_chan));
    end

    % ----------------------------------------------------------------
    % STEP 2: Determine bad channels per epoch using thresholds
    % ----------------------------------------------------------------
    is_bad = pp > thresh_per_chan;          % [nchan x nepoch] logical
    n_bad  = sum(is_bad, 1)';               % [nepoch x 1]

    % ----------------------------------------------------------------
    % STEP 3: Find optimal rejection cutoff k via cross-validation
    % ----------------------------------------------------------------
    max_possible = nchan - 2;  % need at least 2 good channels for interpolation
    k_candidates = unique(round(linspace(0, max_possible, min(opts.n_thresh, max_possible + 1))));

    if length(k_candidates) <= 1
        % Fallback: reject epochs where all/most channels are bad
        opt_k = floor(nchan * 0.3);
    else
        k_scores = zeros(size(k_candidates));
        for i_k = 1:length(k_candidates)
            kk = k_candidates(i_k);
            fold_errs = zeros(opts.n_folds, 1);
            for k = 1:opts.n_folds
                fold_errs(k) = cv_error_local(EEG.data, pp, thresh_per_chan, ...
                                              fold_idx, k, kk, EEG.chanlocs);
            end
            k_scores(i_k) = nanmean(fold_errs);
        end
        [~, best_k] = min(k_scores);
        opt_k = k_candidates(best_k);
    end

    if opts.verbose
        fprintf('  Optimal k (max bad chans before reject) = %d / %d\n', opt_k, nchan);
    end

    % ----------------------------------------------------------------
    % STEP 4: Apply — reject or repair
    % ----------------------------------------------------------------
    reject      = n_bad > opt_k;
    interpolated = false(nchan, nepoch);   % for diagnostics

    % Keep only epochs that are NOT rejected
    keep_idx = find(~reject);
    n_keep   = length(keep_idx);

    data_clean = zeros(nchan, nsamp, n_keep);
    for i_out = 1:n_keep
        ep = keep_idx(i_out);
        if any(is_bad(:, ep))
            data_clean(:, :, i_out) = interpolate_bad_channels( ...
                EEG.data(:, :, ep), find(is_bad(:, ep)), EEG.chanlocs);
            interpolated(is_bad(:, ep), ep) = true;
        else
            data_clean(:, :, i_out) = EEG.data(:, :, ep);
        end
    end

    EEG.data = data_clean;

    % Trim epoch metadata
    if isfield(EEG, 'epoch') && ~isempty(EEG.epoch)
        EEG.epoch = EEG.epoch(keep_idx);
    end
    EEG.trials = n_keep;

    if opts.verbose
        n_repair = sum(~reject & n_bad > 0);
        fprintf('  Rejected %d epochs, repaired %d epochs, kept %d epochs\n', ...
                sum(reject), n_repair, n_keep);
    end

    EEG.autoreject = struct( ...
        'mode',            'local', ...
        'thresh_per_chan', thresh_per_chan, ...
        'k_reject',        opt_k, ...
        'rejected',        reject, ...
        'interpolated',    interpolated);
end


% ======================================================================
function th = optimal_threshold_1d(pp_vec, data, fold_idx, ch, opts)
% ======================================================================
% Find optimal threshold for a single channel via K-fold CV.
    candidates = candidate_thresholds(pp_vec, opts.n_thresh, opts.thresh_lims);
    if isempty(candidates)
        th = Inf;
        return;
    end

    scores = zeros(size(candidates));
    for i = 1:length(candidates)
        fold_errs = zeros(opts.n_folds, 1);
        for k = 1:opts.n_folds
            fold_errs(k) = cv_error_1chan(data, pp_vec, fold_idx, ch, k, candidates(i));
        end
        scores(i) = nanmean(fold_errs);
    end

    [~, best] = min(scores);
    th = candidates(best);
end


% ======================================================================
function err = cv_error_global(data, global_pp, fold_idx, fold_k, th)
% ======================================================================
% RMSE between mean(train_clean) and median(val) for a global threshold.
    val_mask   = fold_idx(:) == fold_k;
    train_mask = ~val_mask;
    global_pp  = global_pp(:);

    train_keep = train_mask & (global_pp <= th);
    if sum(train_keep) == 0
        err = Inf;
        return;
    end

    train_mean = mean(data(:, :, train_keep), 3);
    val_data   = data(:, :, val_mask);

    if isempty(val_data)
        err = Inf;
        return;
    end

    val_median = median(val_data, 3);
    diff_vals  = train_mean(:) - val_median(:);
    err        = sqrt(mean(diff_vals .^ 2));
end


% ======================================================================
function err = cv_error_1chan(data, pp_vec, fold_idx, ch, fold_k, th)
% ======================================================================
% RMSE for a single channel threshold (used during per-channel search).
    val_mask   = fold_idx(:) == fold_k;
    train_mask = ~val_mask;
    pp_vec     = pp_vec(:);

    train_keep = train_mask & (pp_vec <= th);
    if sum(train_keep) == 0
        err = Inf;
        return;
    end

    train_mean = mean(data(ch, :, train_keep), 3);
    val_data   = data(ch, :, val_mask);

    if isempty(val_data)
        err = Inf;
        return;
    end

    val_median = median(val_data, 3);
    diff_vals  = train_mean(:) - val_median(:);
    err        = sqrt(mean(diff_vals .^ 2));
end


% ======================================================================
function err = cv_error_local(data, pp, thresh_per_chan, fold_idx, fold_k, k_reject, chanlocs)
% ======================================================================
% RMSE for local autoreject with a given rejection cutoff k.
    [nchan, nsamp, nepoch] = size(data);
    val_mask   = fold_idx(:) == fold_k;
    train_mask = ~val_mask;

    train_epochs = find(train_mask);
    val_epochs   = find(val_mask);

    % --- Process training epochs ---
    train_clean_list = {};
    for i = 1:length(train_epochs)
        ep = train_epochs(i);
        bad_ch = find(pp(:, ep) > thresh_per_chan);
        if length(bad_ch) > k_reject
            continue;  % reject this epoch
        end
        if isempty(bad_ch)
            train_clean_list{end + 1} = data(:, :, ep);  %#ok<AGROW>
        else
            train_clean_list{end + 1} = interpolate_bad_channels( ...
                data(:, :, ep), bad_ch, chanlocs);  %#ok<AGROW>
        end
    end

    if isempty(train_clean_list)
        err = Inf;
        return;
    end

    train_mean = mean(cat(3, train_clean_list{:}), 3);
    val_data   = data(:, :, val_epochs);

    if isempty(val_data)
        err = Inf;
        return;
    end

    val_median = median(val_data, 3);
    diff_vals  = train_mean(:) - val_median(:);
    err        = sqrt(mean(diff_vals .^ 2));
end


% ======================================================================
function candidates = candidate_thresholds(pp_values, n_thresh, thresh_lims)
% ======================================================================
% Generate candidate thresholds from the percentile range of pp_values.
    pp_values = pp_values(:);
    pp_values = pp_values(~isnan(pp_values) & ~isinf(pp_values));

    if isempty(pp_values) || length(pp_values) < 2
        candidates = [];
        return;
    end

    lo = prctile(pp_values, thresh_lims(1));
    hi = prctile(pp_values, thresh_lims(2));

    if hi <= lo
        hi = lo * 1.01 + 1e-6;
    end

    candidates = linspace(lo, hi, n_thresh)';
end


% ======================================================================
function fold_idx = cv_folds(n, K)
% ======================================================================
% Assign each of n items to one of K folds (stratified-like shuffle).
    rng(42, 'twister');  % reproducibility
    fold_idx = mod(randperm(n), K)' + 1;  % column vector
end


% ======================================================================
function EEG = drop_epochs(EEG, bad)
% ======================================================================
% Remove rejected epochs from EEG structure.
    keep = ~bad;
    EEG.data   = EEG.data(:, :, keep);
    EEG.trials = sum(keep);
    if isfield(EEG, 'epoch') && ~isempty(EEG.epoch)
        EEG.epoch = EEG.epoch(keep);
    end
end


% ======================================================================
function data_out = interpolate_bad_channels(data, bad_ch_idx, chanlocs)
% ======================================================================
% Spatial interpolation of bad channels using inverse-distance weighting.
%
% data        : [nchan x nsamples] single epoch
% bad_ch_idx  : indices of channels to interpolate
% chanlocs    : EEGLAB channel-locations structure (must have .X .Y .Z)
%
    nchan = size(data, 1);
    good_ch = setdiff(1:nchan, bad_ch_idx);

    if isempty(good_ch) || length(good_ch) < 2
        % Cannot interpolate — return original
        data_out = data;
        return;
    end

    % Get 3-D electrode positions
    if ~isempty(chanlocs) && length(chanlocs) == nchan ...
            && all(isfield(chanlocs, {'X','Y','Z'}))
        x = [chanlocs.X]';
        y = [chanlocs.Y]';
        z = [chanlocs.Z]';
        if length(x) == nchan && all(isfinite(x)) && all(isfinite(y)) && all(isfinite(z))
            pos = [x y z];
        else
            pos = [(1:nchan)' zeros(nchan, 2)];
        end
    else
        % Fallback: use channel indices as pseudo-positions
        pos = [(1:nchan)' zeros(nchan, 2)];
    end

    data_out = data;
    for ch = bad_ch_idx(:)'
        d = sqrt(sum((pos(good_ch, :) - pos(ch, :)).^2, 2));
        w = 1 ./ (d + eps);
        w = w / sum(w);
        data_out(ch, :) = w' * data(good_ch, :);
    end
end