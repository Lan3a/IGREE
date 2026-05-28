function EEG = do_epochDataDefault(epochLenSecond, EEG)

moreInfo = EEG.moreInfo;

% Epoch data
srate = EEG.srate;
nPnts = EEG.pnts;
nChans = EEG.nbchan;
samplesPerEpoch = round(epochLenSecond * srate);   % 2 seconds in samples
nEpochs = ceil(nPnts / samplesPerEpoch);

epochedData = EEG.data;
nPntsAtEnd = (nEpochs * samplesPerEpoch) - nPnts;
PntsAtEnd = zeros(nChans, nPntsAtEnd);
epochedData = [epochedData, PntsAtEnd];
epochedData = reshape(epochedData, nChans, samplesPerEpoch, nEpochs);

EEG = pop_importdata('setname','epoched data', 'data',epochedData, 'dataformat','array', 'chanlocs', EEG.moreInfo.originalChanLocs, 'srate', srate, 'pnts', srate);
% ^ Simply use pop_importdata() to put the epoched data in, everything
% else will be adjusted. It's better than forcibly subbing the
% epoched_data to EEG.data, use their own functions for it to adjust
% workspace vars manually.

EEG.moreInfo = moreInfo;

end