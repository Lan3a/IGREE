function printLoopProgress(cLoop,nLoop)
progress = round((cLoop/nLoop)*100,1);
fprintf('>>>> %.1f%%\n', progress);
end