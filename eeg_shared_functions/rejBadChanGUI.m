function rejBadChanGUI(EEG, plotSpectraFunc)
% Channel selector GUI with numbered buttons for channel names
% Style reference: rejICsButtons
% Top: Plot time (eegplot), Plot Spectra (input spectra function)
% Bottom: Save eegplot view PNG, REJECT MARKED (full width)
% Channel buttons: click to select (red), used for reject

if nargin < 2 || isempty(plotSpectraFunc)
    plotSpectraFunc = @custom_pop_spectopo;
elseif ~isa(plotSpectraFunc, 'function_handle')
    error('plotSpectraFunc must be a function handle, e.g. str2func(''custom_pop_spectopo'').');
end

if ~isfield(EEG, 'chanlocs') || isempty(EEG.chanlocs)
    errordlg('EEG.chanlocs required.', 'Error', 'modal');
    return;
end

assignin('base', 'EEG', EEG);

chanLabels = {EEG.chanlocs.labels};
nButtons   = numel(chanLabels);

% Parameters (rejICsButtons style)
buttonWidth   = 70;   % wider for channel names (e.g. FCz, T7)
buttonHeight  = 30;
gap           = 10;
topMargin     = 20;
pad           = 200;

% Figure size: top row (Plot time + Plot Spectra), channel grid, two full-width bottom rows
reservedTop    = buttonHeight + 2 * gap;
reservedBottom = 2 * buttonHeight + 3 * gap;
nonGridHeight  = topMargin + reservedTop + 2 * gap + reservedBottom;
gridLayout     = rejSelectorGridLayout(nButtons, buttonWidth, buttonHeight, gap, nonGridHeight, pad);
nCols          = gridLayout.nCols;
figWidth       = gridLayout.figWidth;
figHeight      = gridLayout.figHeight;

hFig = figure( ...
    'Name', 'EEG Channel Selector', ...
    'MenuBar', 'none', ...
    'ToolBar', 'none', ...
    'NumberTitle', 'off', ...
    'Position', gridLayout.position, ...
    'Resize', 'off');

% Store selection state and button handles
selection = false(1, nButtons);
setappdata(hFig, 'selection', selection);

buttonHandles = gobjects(1, nButtons);
setappdata(hFig, 'buttonHandles', buttonHandles);

% Colors
defaultColor = get(hFig, 'Color');
activeColor  = [1 0.4 0.4];  % red-ish for selected
controlGray  = [0.8 0.8 0.8];

% --- Top: Plot time (left), Plot Spectra (right) ---
topRowY        = figHeight - gap - buttonHeight;
topHalfWidth   = (figWidth - 3 * gap) / 2;
fullCtrlWidth  = figWidth - 2 * gap;

uicontrol( ...
    'Parent',  hFig, ...
    'Style',   'pushbutton', ...
    'String',  'Plot time', ...
    'FontSize', 11, ...
    'FontWeight', 'bold', ...
    'BackgroundColor', controlGray, ...
    'Position', [gap, topRowY, topHalfWidth, buttonHeight], ...
    'Callback', @(src, evt) plotTimeSeriesCallback());

uicontrol( ...
    'Parent',  hFig, ...
    'Style',   'pushbutton', ...
    'String',  'Plot Spectra', ...
    'FontSize', 11, ...
    'FontWeight', 'bold', ...
    'BackgroundColor', controlGray, ...
    'Position', [2 * gap + topHalfWidth, topRowY, topHalfWidth, buttonHeight], ...
    'Callback', @(src, evt) plotSpectraCallback(plotSpectraFunc));

% --- Bottom: Save PNG (full width), REJECT MARKED (full width) ---
rejectY = gap;
saveY   = gap + buttonHeight + gap;

uicontrol( ...
    'Parent',  hFig, ...
    'Style',   'pushbutton', ...
    'String',  'Save eegplot view PNG', ...
    'FontSize', 10, ...
    'FontWeight', 'bold', ...
    'BackgroundColor', controlGray, ...
    'Position', [gap, saveY, fullCtrlWidth, buttonHeight], ...
    'Callback', @(src, evt) saveEegplotSnapshotCallback());

uicontrol( ...
    'Parent',  hFig, ...
    'Style',   'pushbutton', ...
    'String',  'REJECT MARKED', ...
    'FontSize', 11, ...
    'FontWeight', 'bold', ...
    'BackgroundColor', controlGray, ...
    'Position', [gap, rejectY, fullCtrlWidth, buttonHeight], ...
    'Callback', @(src, evt) rejectCallback(hFig, plotSpectraFunc));

% --- Channel buttons (3+ columns when needed to fit screen) ---
for k = 1:nButtons
    row = floor((k - 1) / nCols);
    col = mod((k - 1), nCols);

    xpos = gap + col * (buttonWidth + gap);
    ypos = figHeight - reservedTop - (buttonHeight + gap) - row * (buttonHeight + gap);

    btn = uicontrol( ...
        'Parent',  hFig, ...
        'Style',   'pushbutton', ...
        'String',  chanLabels{k}, ...
        'Tag',     'channelButton', ...
        'FontSize', 9, ...
        'BackgroundColor', defaultColor, ...
        'Position', [xpos, ypos, buttonWidth, buttonHeight], ...
        'Callback', @(src, evt) channelButtonCallback(hFig, src, k, defaultColor, activeColor));

    buttonHandles(k) = btn;
end

setappdata(hFig, 'buttonHandles', buttonHandles);

% Scroll viewer whenever GUI opens
openEegplotWithReset(EEG);
end

% -------------------------------------------------------------------------
function channelButtonCallback(hFig, hButton, idx, defaultColor, activeColor)
% Toggle selection and button color
selection = getappdata(hFig, 'selection');

if selection(idx)
    selection(idx) = false;
    set(hButton, 'BackgroundColor', defaultColor);
else
    selection(idx) = true;
    set(hButton, 'BackgroundColor', activeColor);
end

setappdata(hFig, 'selection', selection);
end

% -------------------------------------------------------------------------
function plotTimeSeriesCallback()
EEG = evalin('base', 'EEG');
openEegplotWithReset(EEG);
end

% -------------------------------------------------------------------------
function plotSpectraCallback(plotSpectraFunc)
EEG = evalin('base', 'EEG');
plotSpectraFunc(EEG);
end

% -------------------------------------------------------------------------
function rejectCallback(hFig, plotSpectraFunc)
EEG = evalin('base', 'EEG');
selection = getappdata(hFig, 'selection');
selectedIdx = find(selection);

if isempty(selectedIdx)
    % No channels selected: accept current state
    chansToRemove = {};
    EEG.moreInfo.toInterpCh = {};
else
    chanLabels = {EEG.chanlocs.labels};
    chansToRemove = chanLabels(selectedIdx);
    EEG = pop_select(EEG, 'rmchannel', chansToRemove);
    EEG.moreInfo.toInterpCh = chansToRemove;
end

assignin('base', 'EEG', EEG);

% Update ALLEEG, CURRENTSET if they exist
try
    ALLEEG  = evalin('base', 'ALLEEG');
    CURRENTSET = evalin('base', 'CURRENTSET');
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, 'gui', 'off');
    assignin('base', 'ALLEEG', ALLEEG);
    assignin('base', 'EEG', EEG);
    assignin('base', 'CURRENTSET', CURRENTSET);
catch %#ok<CTCH>
end

close(hFig);
if ~isempty(chansToRemove)
    fprintf('Rejected channels: %s\n', strjoin(chansToRemove, ', '));
end

% On REJECT: reopen the spectra plot, then reopen GUI for the updated EEG
openSpectopoWithReset(EEG, plotSpectraFunc);
rejBadChanGUI(EEG, plotSpectraFunc);
end

% -------------------------------------------------------------------------
function saveEegplotSnapshotCallback()
EEG = evalin('base', 'EEG');

hEeg = findEegplotFigureForSnapshot();
if isempty(hEeg)
    errordlg( ...
        'No figure with ''eegplot'' in its window title was found. Open eegplot first, then try again.', ...
        'Error', 'modal');
    return;
end

figure(hEeg);
drawnow;

try
    frm = getframe(hEeg);
catch ME
    errordlg(['Could not capture eegplot figure: ' ME.message], 'Error', 'modal');
    return;
end

if ~isfield(EEG, 'moreInfo') || ~isstruct(EEG.moreInfo)
    EEG.moreInfo = struct();
end
if ~isfield(EEG.moreInfo, 'badTimeDataPng') || isempty(EEG.moreInfo.badTimeDataPng) ...
        || ~isstruct(EEG.moreInfo.badTimeDataPng)
    EEG.moreInfo.badTimeDataPng = struct('png', {});
end

EEG.moreInfo.badTimeDataPng(end + 1).png = frm.cdata;
assignin('base', 'EEG', EEG);

fprintf('Stored eegplot image in EEG.moreInfo.badTimeDataPng(%d).png\n', numel(EEG.moreInfo.badTimeDataPng));
end

function hEeg = findEegplotFigureForSnapshot()
cand = findall(0, 'Type', 'figure');
if isempty(cand)
    hEeg = gobjects(0);
    return;
end
mask = arrayfun(@(f) ~isempty(f.Name) && contains(lower(f.Name), 'eegplot'), cand);
hits = cand(mask);
if isempty(hits)
    hEeg = gobjects(0);
    return;
end
if numel(hits) == 1
    hEeg = hits(1);
    return;
end
cf = get(groot, 'CurrentFigure');
if ~isempty(cf) && ismember(cf, hits)
    hEeg = cf;
else
    hEeg = hits(1);
end
end

function openEegplotWithReset(EEG)
closeWindows('eegplot');
pop_eegplot(EEG, 1, 1, 1);
end

function openSpectopoWithReset(EEG, plotSpectraFunc)
closeWindows(func2str(plotSpectraFunc));
plotSpectraFunc(EEG);
end
