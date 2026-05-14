function output = findFiles(inFileSpec, outFileSpec)

if nargin < 2
    outFileSpec = [];
end

% ----- INPUT FILES -----
[inDir, inExt] = parseSpec(inFileSpec);
if ~isfolder(inDir), mkdir(inDir); end
inStruct = listFiles(inDir, inExt);
if isempty(inStruct)
    error('findFilesToProcess:NoInput', 'No input files in folder: %s', inDir);
end

if isemptyOutSpec(outFileSpec)
    output = inStruct;
else
    % ----- OUTPUT FILES -----
    [outDir, outExt] = parseSpec(outFileSpec);
    if ~isfolder(outDir), mkdir(outDir); end
    outStruct = listFiles(outDir, outExt);

    if isempty(outStruct)
        outBase = {};
    else
        outBase = {outStruct.bname}.';
    end
    inBase = {inStruct.bname}.';

    choice = questdlg('View files', '', 'Remaining ones', 'All', 'Remaining ones');
    switch choice
        case 'Remaining ones'
            mask = ~ismember(inBase, outBase);
            output = inStruct(mask);
            if isempty(output)
                error('findFilesToProcess:NoUnprocessed', 'No unprocessed files.');
            end
        case 'All'
            output = inStruct;
        otherwise
            error('findFilesToProcess:Cancelled', 'Cancelled.');
    end
end

% ----- SELECTION GUI -----
listStr = {output.bname}.';
[idx, ok] = listdlg('PromptString', 'Select files:', 'ListString', listStr);
if ~ok, error('findFilesToProcess:Cancelled', 'Cancelled.'); end
output = output(idx);

end


function tf = isemptyOutSpec(spec)
if isempty(spec)
    tf = true;
    return
end

if iscell(spec)
    if numel(spec) < 1 || isempty(spec{1})
        tf = true;
        return
    end

    p = spec{1};
    if ischar(p) || isstring(p)
        tf = isempty(strtrim(char(p)));
        return
    end

    tf = false;
    return
end

tf = isempty(strtrim(char(spec)));
end


function [dirPath, ext] = parseSpec(spec)
if iscell(spec)
    dirPath = char(spec{1});
    ext = '';

    if numel(spec) >= 2 && ~isempty(spec{2})
        ext = char(spec{2});
        if ext(1) ~= '.', ext = ['.', ext]; end
    end
else
    dirPath = char(spec);
    ext = '';
end
end


function f = listFiles(dirPath, ext)
if ~isfolder(dirPath)
    f = struct([]);
    return;
end

d = dir(dirPath);
d = d(~[d.isdir]);

if ~isempty(ext)
    names = {d.name};
    keep = endsWith(names, ext);
    d = d(keep);
end

if isempty(d)
    f = struct([]);
    return;
end

f = struct('fname', {}, 'fpath', {}, 'bname', {}, 'dir', {});

for i = 1:numel(d)
    [~, base, ~] = fileparts(d(i).name);

    f(i).fname = d(i).name;
    f(i).fpath = fullfile(d(i).folder, d(i).name);
    f(i).bname = base;
    f(i).dir = d(i).folder;
end
end