function saveStructStoredPng(var, savePngDir)

if ~isfield(var, 'png') || isempty(var)
    disp('>>>> Cannot find rejected ICs images')
    return;
end

if ~exist(savePngDir, 'dir'); mkdir(savePngDir); end
for ipng = 1:numel(var)
    png = var(ipng).png;
    outFile = fullfile(savePngDir, sprintf('%d.png', ipng));
    imwrite(png, outFile);
end

end