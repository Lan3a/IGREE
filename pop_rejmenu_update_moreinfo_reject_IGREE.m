function EEG = pop_rejmenu_update_moreinfo_reject_IGREE(EEG)
% Update EEG.moreInfo tracking fields before rejecting epochs.
% Called from pop_rejmenu_IGREE's REJECT callback.
%
% EEG.moreInfo.rejEpochs       - 1 x N_original boolean, 0=keep, 1=rejected
% EEG.moreInfo.currentEpochIdx - 1 x M double, indices of remaining original epochs
%
% On first call these fields are auto-initialised. On subsequent calls
% they are updated in place so that the original epoch numbering is
% preserved across multiple successive REJECT operations.

    % --- ensure moreInfo container exists ---
    if ~isfield(EEG, 'moreInfo')
        EEG.moreInfo = [];
    end

    % --- one-shot initialisation ---
    if ~isfield(EEG.moreInfo, 'rejEpochs') || isempty(EEG.moreInfo.rejEpochs)
        EEG.moreInfo.rejEpochs = zeros(1, EEG.trials);
    end
    if ~isfield(EEG.moreInfo, 'currentEpochIdx') || isempty(EEG.moreInfo.currentEpochIdx)
        EEG.moreInfo.currentEpochIdx = 1:EEG.trials;
    end

    % nothing to do if no rejection mask is present
    if ~isfield(EEG, 'reject') || ~isfield(EEG.reject, 'rejglobal') ...
       || isempty(EEG.reject.rejglobal)
        return;
    end

    rejMask = EEG.reject.rejglobal;

    % expand rejEpochs if original epoch count has grown (should not normally happen)
    maxOrig = max(EEG.moreInfo.currentEpochIdx);
    if length(EEG.moreInfo.rejEpochs) < maxOrig
        EEG.moreInfo.rejEpochs(maxOrig) = 0;
    end

    % --- map current-trial rejections back to original epoch indices ---
    for i = 1:length(rejMask)
        if rejMask(i)
            origIdx = EEG.moreInfo.currentEpochIdx(i);
            EEG.moreInfo.rejEpochs(origIdx) = 1;
        end
    end

    % --- drop rejected epochs from the remaining-index list ---
    EEG.moreInfo.currentEpochIdx = EEG.moreInfo.currentEpochIdx(~rejMask);
end
