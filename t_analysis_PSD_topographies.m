% (temp) For Omio
% 
% PSD analysis with paired t-test
% 5 core frequency bands
% Plotting topographies and violinplots with separated brain regions

clc; clear; close all;
project = initIGREE;

[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;

%%

inDir = fullfile(project.dir.data, 'preprocess_eeg', 'epoch_rejection_done');
inExt = 'set';
dataFiles = findFilesToProcess({inDir, inExt});

outDir = fullfile(project.dir.data, 'analysis_eeg', 'PSD');
if ~exist(outDir, 'dir'), mkdir(outDir); end

for fidx = 1:length(dataFiles)

    % Load EEG
    EEG = pop_loadset('filename', dataFiles(fidx).fname, 'filepath', dataFiles(fidx).dir);
    [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, 0);

    % =========================================================================
    % Epoch extraction
    % =========================================================================
    ms = EEG.moreInfo.epochedTimeMsChannel;
    idx = EEG.moreInfo.epochedSessionIdxChannel;
    rej = EEG.moreInfo.rejEpochs;

    if length(rej) > size(EEG.data, 3)
        rej = rej(1:size(EEG.data, 3));
    end

    cleaned_idx = idx(:, :, ~rej);

    % NOTE: All time pts in same epoch has same session index -> only get 1st value
    first_cleaned_idx = squeeze(cleaned_idx(:, 1, :));  % (nCh x nCleanedEpochs)

    % Map original epoch index -> cleaned epoch index (0 for rejected)
    orig2clean = cumsum(~rej(:)');
    orig2clean(logical(rej)) = 0;

    % Find continuous runs of non-rejected epochs (original indices)
    non_rej = ~rej(:)';
    d = diff([0 non_rej 0]);
    run_starts = find(d == 1);
    run_ends = find(d == -1) - 1;

    % Convert runs to cleaned epoch indices
    clean_starts = orig2clean(run_starts);
    clean_ends = orig2clean(run_ends);
    continuous_runs = [clean_starts; clean_ends]';

    % Session mask per cleaned epoch
    sess_per_epoch = first_cleaned_idx(:)';
    unique_sessions = unique(sess_per_epoch);

    gv = struct();
    pv = struct();

    for s = unique_sessions
        if s == 0, continue; end

        sess_epochs = find(sess_per_epoch == s);

        % Find continuous runs that overlap with this session's epochs
        ep_range = zeros(0, 2);
        for r = 1:size(continuous_runs, 1)
            rng = continuous_runs(r, 1):continuous_runs(r, 2);
            overlap = intersect(rng, sess_epochs);
            if ~isempty(overlap)
                ep_range(end+1, :) = [overlap(1), overlap(end)];
            end
        end

        % Flatten ranges into 1D vector of all epoch indices
        all_ep = zeros(1, 0);
        for r = 1:size(ep_range, 1)
            all_ep = [all_ep, ep_range(r, 1):ep_range(r, 2)];
        end

        entry = struct('ep_range', ep_range, 'all_ep', all_ep);

        if s >= 11 && s <= 29
            gv.(sprintf('g%d', s - 10)) = entry;
        elseif s >= 31 && s <= 49
            pv.(sprintf('p%d', s - 30)) = entry;
        end
    end

    % Build gv.all / pv.all
    if ~isempty(fieldnames(gv))
        all_ep_range = zeros(0, 2);
        all_ep_all = zeros(1, 0);
        for fn = fieldnames(gv)'
            all_ep_range = [all_ep_range; gv.(fn{1}).ep_range];
            all_ep_all = [all_ep_all, gv.(fn{1}).all_ep];
        end
        gv.all = struct('ep_range', sortrows(all_ep_range), 'all_ep', sort(all_ep_all));
    end

    if ~isempty(fieldnames(pv))
        all_ep_range = zeros(0, 2);
        all_ep_all = zeros(1, 0);
        for fn = fieldnames(pv)'
            all_ep_range = [all_ep_range; pv.(fn{1}).ep_range];
            all_ep_all = [all_ep_all, pv.(fn{1}).all_ep];
        end
        pv.all = struct('ep_range', sortrows(all_ep_range), 'all_ep', sort(all_ep_all));
    end

    % =========================================================================
    % PSD analysis
    % =========================================================================

    % !!! TEMP: Strip EOG channels so all subjects have consistent channel count
    eog_idx = find(contains({EEG.chanlocs.labels}, 'EOG'));
    data_clean = EEG.data;
    data_clean(eog_idx, :, :) = [];

    % !!! TEMP: also strip from chanlocs for later topoplot compatibility
    chanlocs_clean = EEG.chanlocs;
    chanlocs_clean(eog_idx) = [];

    cleaned_data = data_clean(:, :, ~rej);
    srate = EEG.srate;

    % gv
    if ~isempty(gv.all.all_ep)
        gv_eps = cleaned_data(:, :, gv.all.all_ep);
        [nCh, nPts, nEps] = size(gv_eps);

        gv_psd_all = [];
        for ep = 1:nEps
            for ch = 1:nCh
                [pxx, f] = pwelch(squeeze(gv_eps(ch, :, ep)), [], [], [], srate);
                if ep == 1 && ch == 1
                    gv_psd_all = zeros(length(f), nCh, nEps);
                end
                gv_psd_all(:, ch, ep) = pxx;
            end
        end
        gv_psd_mean = mean(gv_psd_all, 3);
        gv_psd_freqs = f;
    else
        gv_psd_all = [];  gv_psd_mean = [];  gv_psd_freqs = [];
    end

    % pv
    if ~isempty(pv.all.all_ep)
        pv_eps = cleaned_data(:, :, pv.all.all_ep);
        [nCh, nPts, nEps] = size(pv_eps);

        pv_psd_all = [];
        for ep = 1:nEps
            for ch = 1:nCh
                [pxx, f] = pwelch(squeeze(pv_eps(ch, :, ep)), [], [], [], srate);
                if ep == 1 && ch == 1
                    pv_psd_all = zeros(length(f), nCh, nEps);
                end
                pv_psd_all(:, ch, ep) = pxx;
            end
        end
        pv_psd_mean = mean(pv_psd_all, 3);
        pv_psd_freqs = f;
    else
        pv_psd_all = [];  pv_psd_mean = [];  pv_psd_freqs = [];
    end

    % =========================================================================
    % Save
    % =========================================================================
    [~, subjID, ~] = fileparts(dataFiles(fidx).fname);
    save(fullfile(outDir, [subjID '_PSD.mat']), ...
        'gv', 'pv', ...
        'gv_psd_all', 'gv_psd_mean', 'gv_psd_freqs', ...
        'pv_psd_all', 'pv_psd_mean', 'pv_psd_freqs');
    fprintf('Saved: %s_PSD.mat\n', subjID);

end

close all; beep; cpbGreen('All done!');


%% Save plots and summary (AI-assisted)

% Grand-average PSD topographies across all participants
% Loads all *_PSD.mat files, averages gv/pv across subjects,
% and plots GV, PV, and PV−GV topographies for the 5 core bands.
% Asterisks (*) mark channels with p < 0.01 (paired t-test, GV vs PV).

inDir = fullfile(project.dir.data, 'analysis_eeg', 'PSD');
psdFiles = dir(fullfile(inDir, '*_PSD.mat'));

bands = { ...
    'Delta',  0.5,  4; ...
    'Theta',    4,  8; ...
    'Alpha',    8, 13; ...
    'Beta',    13, 30; ...
    'Gamma',   30, 45; ...
};
nBands = size(bands, 1);

% --- Accumulate across subjects ---
gv_sum = [];  pv_sum = [];
gv_count = 0;  pv_count = 0;

% Per-subject band power: gv_subj_band{b}(ch, subj), pv_subj_band{b}(ch, subj)
gv_subj_band = cell(1, nBands);
pv_subj_band = cell(1, nBands);
subj_list_gv = [];
subj_list_pv = [];

for fi = 1:length(psdFiles)
    dat = load(fullfile(psdFiles(fi).folder, psdFiles(fi).name));

    % Quick fix: strip last 2 channels (EOG) if nCh == 66
    if ~isempty(dat.gv_psd_mean) && size(dat.gv_psd_mean, 2) == 66
        dat.gv_psd_mean = dat.gv_psd_mean(:, 1:64);
    end
    if ~isempty(dat.pv_psd_mean) && size(dat.pv_psd_mean, 2) == 66
        dat.pv_psd_mean = dat.pv_psd_mean(:, 1:64);
    end

    f = dat.gv_psd_freqs;

    if isempty(gv_sum) && ~isempty(dat.gv_psd_mean)
        gv_sum = zeros(size(dat.gv_psd_mean));
    end
    if isempty(pv_sum) && ~isempty(dat.pv_psd_mean)
        pv_sum = zeros(size(dat.pv_psd_mean));
    end

    if ~isempty(dat.gv_psd_mean)
        gv_sum = gv_sum + dat.gv_psd_mean;
        gv_count = gv_count + 1;

        % Collect per-band power for this subject
        for b = 1:nBands
            band_idx = f >= bands{b, 2} & f <= bands{b, 3};
            bp = mean(dat.gv_psd_mean(band_idx, :), 1)';  % (nCh x 1)
            if isempty(gv_subj_band{b})
                gv_subj_band{b} = bp;
            else
                gv_subj_band{b}(:, end+1) = bp;
            end
        end
        subj_list_gv(end+1) = fi;
    end

    if ~isempty(dat.pv_psd_mean)
        pv_sum = pv_sum + dat.pv_psd_mean;
        pv_count = pv_count + 1;

        for b = 1:nBands
            band_idx = f >= bands{b, 2} & f <= bands{b, 3};
            bp = mean(dat.pv_psd_mean(band_idx, :), 1)';
            if isempty(pv_subj_band{b})
                pv_subj_band{b} = bp;
            else
                pv_subj_band{b}(:, end+1) = bp;
            end
        end
        subj_list_pv(end+1) = fi;
    end
end

gv_grand = gv_sum / gv_count;  % (nFreqs x nCh)
pv_grand = pv_sum / pv_count;

% --- Compute p-values per channel per band (paired where subjects match) ---
pval = cell(1, nBands);
for b = 1:nBands
    gv_bp = gv_subj_band{b};  % (nCh x nGvSubj)
    pv_bp = pv_subj_band{b};  % (nCh x nPvSubj)
    nCh = size(gv_bp, 1);
    pval{b} = ones(nCh, 1);

    % Only test subjects present in both GV and PV
    common_subj = intersect(subj_list_gv, subj_list_pv);
    if length(common_subj) < 3, continue; end

    gv_idx = ismember(subj_list_gv, common_subj);
    pv_idx = ismember(subj_list_pv, common_subj);

    for ch = 1:nCh
        [~, p] = ttest(gv_bp(ch, gv_idx)', pv_bp(ch, pv_idx)');
        pval{b}(ch) = p;
    end
end

% Grab freq axis from last loaded file; load one .set for chanlocs
f = dat.gv_psd_freqs;
dataFiles = findFilesToProcess({fullfile(project.dir.data, 'preprocess_eeg', 'epoch_rejection_done'), 'set'});
refEEG = pop_loadset('filename', dataFiles(1).fname, 'filepath', dataFiles(1).dir);
chanlocs = refEEG.chanlocs;
eog_idx = find(contains({chanlocs.labels}, 'EOG'));
chanlocs(eog_idx) = [];

% --- Print p-values per band ---
fprintf('\n========== PV vs GV: p-values (paired t-test) ==========\n');
for b = 1:nBands
    fprintf('\n--- %s (%.1f–%.0f Hz) ---\n', bands{b, 1}, bands{b, 2}, bands{b, 3});
    for ch = 1:length(pval{b})
        pv = pval{b}(ch);
        if pv < 0.001, marker = '  **';
        elseif pv < 0.01, marker = '  *';
        else, marker = '';
        end
        fprintf('  %-6s  p = %.4f%s\n', chanlocs(ch).labels, pv, marker);
    end
end
fprintf('==========================================================\n\n');

% =====================================================================
% Setup output directories
% =====================================================================
plotDir = fullfile(project.dir.data, 'analysis_eeg', 'PSD', 'plot');
if ~exist(plotDir, 'dir'), mkdir(plotDir); end

% Seed random generator for reproducible scatter jitter
rng(42);

% --- Plot: GV grand average ---
fig = figure('Position', [100 100 900 600], 'Visible', 'off');
for b = 1:size(bands, 1)
    subplot(2, 3, b);
    band_idx = f >= bands{b, 2} & f <= bands{b, 3};
    band_power = mean(gv_grand(band_idx, :), 1);
    topoplot(band_power, chanlocs, 'electrodes', 'on');
    title(sprintf('GV — %s (%.1f–%.0f Hz)', bands{b, 1}, bands{b, 2}, bands{b, 3}));
    colorbar;
end
saveas(fig, fullfile(plotDir, 'topo_gv_grandavg.png'));
close(fig);

% --- Plot: PV grand average ---
fig = figure('Position', [100 100 900 600], 'Visible', 'off');
for b = 1:size(bands, 1)
    subplot(2, 3, b);
    band_idx = f >= bands{b, 2} & f <= bands{b, 3};
    band_power = mean(pv_grand(band_idx, :), 1);
    topoplot(band_power, chanlocs, 'electrodes', 'on');
    title(sprintf('PV — %s (%.1f–%.0f Hz)', bands{b, 1}, bands{b, 2}, bands{b, 3}));
    colorbar;
end
saveas(fig, fullfile(plotDir, 'topo_pv_grandavg.png'));
close(fig);

% --- Plot: PV − GV difference ---
fig = figure('Position', [100 100 900 600], 'Visible', 'off');
for b = 1:size(bands, 1)
    subplot(2, 3, b);
    band_idx = f >= bands{b, 2} & f <= bands{b, 3};
    gv_power = mean(gv_grand(band_idx, :), 1);
    pv_power = mean(pv_grand(band_idx, :), 1);
    diff_power = pv_power - gv_power;

    sig_ch = find(pval{b} < 0.01);
    if ~isempty(sig_ch)
        topoplot(diff_power, chanlocs, 'electrodes', 'on', ...
            'emarker2', {sig_ch, '*', 'k', 6, 1});
    else
        topoplot(diff_power, chanlocs, 'electrodes', 'on');
    end
    title(sprintf('PV − GV — %s (%.1f–%.0f Hz)', bands{b, 1}, bands{b, 2}, bands{b, 3}));
    colorbar;
end
saveas(fig, fullfile(plotDir, 'topo_pv_minus_gv.png'));
close(fig);

% --- Per-band violinplots across brain regions ---
brainRegions = { ...
    'All',       {chanlocs.labels}; ...
    'Frontal',   {'Fp1','Fp2','AF3','AF4','AF7','AF8','F1','F2','F3','F4','F5','F6','F7','F8','FC1','FC2','FC3','FC4','FC5','FC6'}; ...
    'Central',   {'C1','C2','C3','C4','C5','C6','Cz'}; ...
    'Parietal',  {'P1','P2','P3','P4','P5','P6','P7','P8','Pz','CP1','CP2','CP3','CP4','CP5','CP6','CPz'}; ...
    'Temporal',  {'FT7','FT8','T7','T8','TP7','TP8'}; ...
    'Occipital', {'O1','O2','Oz','PO3','PO4','PO7','PO8','POz'} ...
};
nRegions = size(brainRegions, 1);

gv_color = [0.2 0.4 0.8];
pv_color = [0.8 0.2 0.2];
gv_x_reg = (1:nRegions) - 0.18;
pv_x_reg = (1:nRegions) + 0.18;

% Build paired-subject mapping (common subjects between GV and PV)
common_subj = intersect(subj_list_gv, subj_list_pv);

fprintf('\n========== Regional band-power p-values (GV vs PV, paired t-test) ==========\n');

% Pre-compute regional data and p-values for all bands
reg_data = cell(nBands, nRegions);  % {gv, pv, pval} per band/region
for b = 1:nBands
    gv_bp = gv_subj_band{b};
    pv_bp = pv_subj_band{b};
    for r = 1:nRegions
        [~, ch_idx] = ismember(brainRegions{r, 2}, {chanlocs.labels});
        ch_idx(ch_idx == 0) = [];
        ch_idx(ch_idx > size(gv_bp, 1)) = [];
        if isempty(ch_idx)
            reg_data{b, r} = [];
            continue;
        end
        gv_reg = mean(gv_bp(ch_idx, :), 1);
        pv_reg = mean(pv_bp(ch_idx, :), 1);
        gv_idx_c = ismember(subj_list_gv, common_subj);
        pv_idx_c = ismember(subj_list_pv, common_subj);
        [~, p_reg] = ttest(gv_reg(gv_idx_c)', pv_reg(pv_idx_c)');
        j_gv = (rand(size(gv_reg)) - 0.5) * 0.08;
        j_pv = (rand(size(pv_reg)) - 0.5) * 0.08;
        reg_data{b, r} = struct('gv', gv_reg, 'pv', pv_reg, 'p', p_reg, ...
            'j_gv', j_gv, 'j_pv', j_pv);
    end
end

% --- Draw and save both violinplot versions ---
for b = 1:nBands
    band_label = lower(bands{b, 1});
    fprintf('\n--- %s (%.1f–%.0f Hz) ---\n', bands{b, 1}, bands{b, 2}, bands{b, 3});

    % Version 1: with paired lines
    fig = figure('Position', [100 100 1000 500], 'Visible', 'off');
    hold on;
    for r = 1:nRegions
        d = reg_data{b, r};
        if isempty(d), continue; end
        gv_reg = d.gv; pv_reg = d.pv; p_reg = d.p;
        % Violins
        for side = 1:2
            if side == 1
                vals = gv_reg;  x0 = gv_x_reg(r);  clr = gv_color;
            else
                vals = pv_reg;  x0 = pv_x_reg(r);  clr = pv_color;
            end
            if length(vals) >= 3
                [f_den, xi] = ksdensity(vals);
                f_den = f_den / max(f_den) * 0.15;
                patch([x0 - f_den, x0 + fliplr(f_den)], [xi, fliplr(xi)], clr, ...
                    'FaceAlpha', 0.3, 'EdgeColor', 'none');
                plot([x0 x0], [min(xi) max(xi)], 'Color', clr, 'LineWidth', 0.5);
            end
        end
        % Paired lines
        gv_idx_c = ismember(subj_list_gv, common_subj);
        pv_idx_c = ismember(subj_list_pv, common_subj);
        gv_paired = gv_reg(gv_idx_c);
        pv_paired = pv_reg(pv_idx_c);
        for s = 1:length(gv_paired)
            plot([gv_x_reg(r) pv_x_reg(r)], [gv_paired(s) pv_paired(s)], ...
                '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5);
        end
        % Scatter
        j_gv = d.j_gv;
        j_pv = d.j_pv;
        scatter(gv_x_reg(r) + j_gv, gv_reg, 20, gv_color, 'filled', 'MarkerFaceAlpha', 0.5);
        scatter(pv_x_reg(r) + j_pv, pv_reg, 20, pv_color, 'filled', 'MarkerFaceAlpha', 0.5);
        % Significance bar
        if p_reg < 0.01
            y_max = max([gv_reg, pv_reg]);
            y_rng = range([gv_reg, pv_reg]);
            y_bar = y_max + y_rng * 0.15;
            plot([gv_x_reg(r) gv_x_reg(r) pv_x_reg(r) pv_x_reg(r)], ...
                 [y_bar - 0.02*y_rng, y_bar, y_bar, y_bar - 0.02*y_rng], ...
                 'k-', 'LineWidth', 1);
            if p_reg < 0.001
                text((gv_x_reg(r) + pv_x_reg(r))/2, y_bar + 0.03*y_rng, '**', ...
                    'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold');
            else
                text((gv_x_reg(r) + pv_x_reg(r))/2, y_bar + 0.03*y_rng, '*', ...
                    'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold');
            end
        end
        if d.p < 0.001, star = '  **';
        elseif d.p < 0.01, star = '  *';
        else, star = '';
        end
        fprintf('  %-12s  p = %.4f%s\n', brainRegions{r, 1}, d.p, star);
    end
    set(gca, 'XTick', 1:nRegions, 'XTickLabel', brainRegions(:, 1));
    xlim([0.4 nRegions + 0.6]);
    ylabel('Mean PSD (\muV^2/Hz)');
    title(sprintf('%s (%.1f–%.0f Hz): GV vs PV by region', bands{b, 1}, bands{b, 2}, bands{b, 3}));
    legend([scatter(nan, nan, 20, gv_color, 'filled'), ...
            scatter(nan, nan, 20, pv_color, 'filled')], {'GV', 'PV'}, 'Location', 'northeast');
    hold off;
    saveas(fig, fullfile(plotDir, sprintf('violin_%s_paired.png', band_label)));
    close(fig);

    % Version 2: without paired lines
    fig = figure('Position', [100 100 1000 500], 'Visible', 'off');
    hold on;
    for r = 1:nRegions
        d = reg_data{b, r};
        if isempty(d), continue; end
        gv_reg = d.gv; pv_reg = d.pv; p_reg = d.p;
        % Violins
        for side = 1:2
            if side == 1
                vals = gv_reg;  x0 = gv_x_reg(r);  clr = gv_color;
            else
                vals = pv_reg;  x0 = pv_x_reg(r);  clr = pv_color;
            end
            if length(vals) >= 3
                [f_den, xi] = ksdensity(vals);
                f_den = f_den / max(f_den) * 0.15;
                patch([x0 - f_den, x0 + fliplr(f_den)], [xi, fliplr(xi)], clr, ...
                    'FaceAlpha', 0.3, 'EdgeColor', 'none');
                plot([x0 x0], [min(xi) max(xi)], 'Color', clr, 'LineWidth', 0.5);
            end
        end
        % Scatter
        j_gv = d.j_gv;
        j_pv = d.j_pv;
        scatter(gv_x_reg(r) + j_gv, gv_reg, 20, gv_color, 'filled', 'MarkerFaceAlpha', 0.5);
        scatter(pv_x_reg(r) + j_pv, pv_reg, 20, pv_color, 'filled', 'MarkerFaceAlpha', 0.5);
        % Significance bar
        if p_reg < 0.01
            y_max = max([gv_reg, pv_reg]);
            y_rng = range([gv_reg, pv_reg]);
            y_bar = y_max + y_rng * 0.15;
            plot([gv_x_reg(r) gv_x_reg(r) pv_x_reg(r) pv_x_reg(r)], ...
                 [y_bar - 0.02*y_rng, y_bar, y_bar, y_bar - 0.02*y_rng], ...
                 'k-', 'LineWidth', 1);
            if p_reg < 0.001
                text((gv_x_reg(r) + pv_x_reg(r))/2, y_bar + 0.03*y_rng, '**', ...
                    'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold');
            else
                text((gv_x_reg(r) + pv_x_reg(r))/2, y_bar + 0.03*y_rng, '*', ...
                    'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold');
            end
        end
    end
    set(gca, 'XTick', 1:nRegions, 'XTickLabel', brainRegions(:, 1));
    xlim([0.4 nRegions + 0.6]);
    ylabel('Mean PSD (\muV^2/Hz)');
    title(sprintf('%s (%.1f–%.0f Hz): GV vs PV by region', bands{b, 1}, bands{b, 2}, bands{b, 3}));
    legend([scatter(nan, nan, 20, gv_color, 'filled'), ...
            scatter(nan, nan, 20, pv_color, 'filled')], {'GV', 'PV'}, 'Location', 'northeast');
    hold off;
    saveas(fig, fullfile(plotDir, sprintf('violin_%s.png', band_label)));
    close(fig);
end

fprintf('==========================================================================\n\n');

% --- Summary output directory ---
outDir = fullfile(project.dir.data, 'analysis_eeg', 'PSD', 'summary');
if ~exist(outDir, 'dir'), mkdir(outDir); end

% --- Extract participant IDs from filenames ---
all_ids = cell(length(psdFiles), 1);
for fi = 1:length(psdFiles)
    [~, fname, ~] = fileparts(psdFiles(fi).name);
    all_ids{fi} = strrep(fname, '_PSD', '');
end
gv_ids = all_ids(subj_list_gv);
pv_ids = all_ids(subj_list_pv);

% --- Build column headers ---
ch_labels = {chanlocs.labels};
ch_band_cols = {};
for b = 1:nBands
    for ch = 1:length(ch_labels)
        ch_band_cols{end+1} = sprintf('%s_%s', ch_labels{ch}, bands{b, 1});
    end
end

reg_labels = brainRegions(:, 1)';
reg_band_cols = {};
for b = 1:nBands
    for r = 1:nRegions
        reg_band_cols{end+1} = sprintf('%s_%s', reg_labels{r}, bands{b, 1});
    end
end

% --- Per-subject channel×band power (GV) ---
nSubjGv = length(subj_list_gv);
nChData = size(gv_subj_band{1}, 1);  % actual nCh in PSD data (64 after EOG)
ch_labels_trim = ch_labels(1:nChData);
ch_band_cols_trim = {};
for b = 1:nBands
    for ch = 1:nChData
        ch_band_cols_trim{end+1} = sprintf('%s_%s', ch_labels_trim{ch}, bands{b, 1});
    end
end
gv_ch_band = zeros(nSubjGv, nChData * nBands);
for b = 1:nBands
    cols = (b-1)*nChData + (1:nChData);
    gv_ch_band(:, cols) = gv_subj_band{b}';
end
T = array2table(gv_ch_band, 'VariableNames', matlab.lang.makeValidName(ch_band_cols_trim));
T = addvars(T, gv_ids, 'Before', 1, 'NewVariableNames', {'ParticipantID'});
writetable(T, fullfile(outDir, 'channel_bandpower_gv.csv'));

% --- Per-subject channel×band power (PV) ---
nSubjPv = length(subj_list_pv);
pv_ch_band = zeros(nSubjPv, nChData * nBands);
for b = 1:nBands
    cols = (b-1)*nChData + (1:nChData);
    pv_ch_band(:, cols) = pv_subj_band{b}';
end
T = array2table(pv_ch_band, 'VariableNames', matlab.lang.makeValidName(ch_band_cols_trim));
T = addvars(T, pv_ids, 'Before', 1, 'NewVariableNames', {'ParticipantID'});
writetable(T, fullfile(outDir, 'channel_bandpower_pv.csv'));

% --- Per-subject region×band power (GV + PV) ---
gv_reg_band = zeros(nSubjGv, nRegions * nBands);
pv_reg_band = zeros(nSubjPv, nRegions * nBands);
for b = 1:nBands
    gv_bp = gv_subj_band{b};
    pv_bp = pv_subj_band{b};
    for r = 1:nRegions
        [~, ch_idx] = ismember(brainRegions{r, 2}, {chanlocs.labels});
        ch_idx(ch_idx == 0) = [];
        ch_idx(ch_idx > size(gv_bp, 1)) = [];
        if isempty(ch_idx), continue; end
        col = (b-1)*nRegions + r;
        gv_reg_band(:, col) = mean(gv_bp(ch_idx, :), 1)';
        pv_reg_band(:, col) = mean(pv_bp(ch_idx, :), 1)';
    end
end
T = array2table(gv_reg_band, 'VariableNames', matlab.lang.makeValidName(reg_band_cols));
T = addvars(T, gv_ids, 'Before', 1, 'NewVariableNames', {'ParticipantID'});
writetable(T, fullfile(outDir, 'region_bandpower_gv.csv'));
T = array2table(pv_reg_band, 'VariableNames', matlab.lang.makeValidName(reg_band_cols));
T = addvars(T, pv_ids, 'Before', 1, 'NewVariableNames', {'ParticipantID'});
writetable(T, fullfile(outDir, 'region_bandpower_pv.csv'));

% --- Channel-level p-values (PV vs GV) ---
pval_ch = zeros(nChData, nBands);
for b = 1:nBands
    pval_ch(:, b) = pval{b};
end
T = array2table(pval_ch, 'VariableNames', matlab.lang.makeValidName(bands(:, 1)'), ...
    'RowNames', matlab.lang.makeValidName(ch_labels_trim));
writetable(T, fullfile(outDir, 'channel_pvalues.csv'), 'WriteRowNames', true);

% --- Region-level p-values (PV vs GV) ---
pval_reg = zeros(nRegions, nBands);
for b = 1:nBands
    gv_bp = gv_subj_band{b};
    pv_bp = pv_subj_band{b};
    common_subj = intersect(subj_list_gv, subj_list_pv);
    gv_idx = ismember(subj_list_gv, common_subj);
    pv_idx = ismember(subj_list_pv, common_subj);
    for r = 1:nRegions
        [~, ch_idx] = ismember(brainRegions{r, 2}, {chanlocs.labels});
        ch_idx(ch_idx == 0) = [];
        ch_idx(ch_idx > size(gv_bp, 1)) = [];
        if isempty(ch_idx), continue; end
        gv_reg = mean(gv_bp(ch_idx, gv_idx), 1);
        pv_reg = mean(pv_bp(ch_idx, pv_idx), 1);
        [~, pval_reg(r, b)] = ttest(gv_reg', pv_reg');
    end
end
T = array2table(pval_reg, 'VariableNames', matlab.lang.makeValidName(bands(:, 1)'), ...
    'RowNames', matlab.lang.makeValidName(reg_labels));
writetable(T, fullfile(outDir, 'region_pvalues.csv'), 'WriteRowNames', true);

% --- Grand-average channel×band power ---
gv_grand_ch_band = zeros(nChData, nBands);
pv_grand_ch_band = zeros(nChData, nBands);
for b = 1:nBands
    band_idx = f >= bands{b, 2} & f <= bands{b, 3};
    gv_grand_ch_band(:, b) = mean(gv_grand(band_idx, :), 1)';
    pv_grand_ch_band(:, b) = mean(pv_grand(band_idx, :), 1)';
end
T = array2table(gv_grand_ch_band, 'VariableNames', matlab.lang.makeValidName(bands(:, 1)'), ...
    'RowNames', matlab.lang.makeValidName(ch_labels_trim));
writetable(T, fullfile(outDir, 'grandavg_channel_bandpower_gv.csv'), 'WriteRowNames', true);
T = array2table(pv_grand_ch_band, 'VariableNames', matlab.lang.makeValidName(bands(:, 1)'), ...
    'RowNames', matlab.lang.makeValidName(ch_labels_trim));
writetable(T, fullfile(outDir, 'grandavg_channel_bandpower_pv.csv'), 'WriteRowNames', true);

fprintf('Summaries saved to %s\n', outDir);
