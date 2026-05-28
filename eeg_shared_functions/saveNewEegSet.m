function EEG = saveNewEegSet(EEG, newSetName, saveDir, saveFileName)

if isstring(saveDir), saveDir = char(saveDir); end

[~, EEG, ~] = pop_newset([], EEG, 0, 'setname', newSetName, 'gui','off');
EEG = pop_saveset( EEG, 'filename',saveFileName,'filepath',saveDir);

end