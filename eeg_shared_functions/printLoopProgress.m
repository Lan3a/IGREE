function printLoopProgress(cLoop,nLoop)
progress = round((cLoop/nLoop)*100,1);

% msg = char(sprintf(">>>> %.1f%%", progress));
% cpbYellow(msg);
%Notes - cprintf cannot accept % as literal string if passed in by string / char

cprintf('*darkYellow', '>>>> %.1f%%\n', progress);
end