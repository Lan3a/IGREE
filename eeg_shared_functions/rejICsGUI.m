function rejICsGUI(EEG)
% Simple EEG component selector with numbered buttons and a plot button

if ~isfield(EEG, 'moreInfo') || ~isstruct(EEG.moreInfo)
    EEG.moreInfo = struct();
end
if ~isfield(EEG.moreInfo, 'rejICsPng')
    EEG.moreInfo.rejICsPng = struct('png', {});
end
assignin('base', 'EEG', EEG);

% Parameters
nButtons      = size(EEG.icaweights, 1);
buttonWidth   = 60;
buttonHeight  = 30;
gap           = 10;
topMargin     = 20;
hintHeight    = 22;   % one-line hint above plot ICs
numberGridYOffset = topMargin + gap / 2;   % center number buttons between top and bottom controls
pad           = 200;

% Figure size (hint + top bar + number grid + bottom: two stacked full-width buttons)
topReserve    = hintHeight + 2 * buttonHeight + 2 * gap;   % hint + top control row + gap to number grid
bottomReserve = 2 * buttonHeight + 3 * gap;   % stacked plot-time + REJECT + margins
nonGridHeight = topMargin + topReserve + bottomReserve;
gridLayout    = rejSelectorGridLayout(nButtons, buttonWidth, buttonHeight, gap, nonGridHeight, pad);
nCols         = gridLayout.nCols;
figWidth      = gridLayout.figWidth;
figHeight     = gridLayout.figHeight;

hFig = figure( ...
    'Name', 'EEG Component Selector', ...
    'MenuBar', 'none', ...
    'ToolBar', 'none', ...
    'NumberTitle', 'off', ...
    'Position', gridLayout.position, ...
    'Resize', 'off');

% Store selection state and button handles in appdata
selection = false(1, nButtons);
setappdata(hFig, 'selection', selection);

buttonHandles = gobjects(1, nButtons);
setappdata(hFig, 'buttonHandles', buttonHandles);

% Colors
defaultColor      = get(hFig, 'Color');   % figure background (used for number buttons)
activeColor       = [1 0.4 0.4];          % red-ish for marked
controlGray       = [0.8 0.8 0.8];        % gray for control buttons

% --- Top: hint, then plot ICs (full width) ---
uicontrol( ...
    'Parent',  hFig, ...
    'Style',   'text', ...
    'String',  'right click to plot time without only that IC', ...
    'FontSize', 8, ...
    'HorizontalAlignment', 'center', ...
    'BackgroundColor', defaultColor, ...
    'Position', [gap, figHeight - hintHeight, figWidth - 2 * gap, hintHeight]);

uicontrol( ...
    'Parent',  hFig, ...
    'Style',   'pushbutton', ...
    'String',  'plot ICs', ...
    'FontSize', 11, ...
    'FontWeight', 'bold', ...
    'BackgroundColor', controlGray, ...
    'Position', [gap, figHeight - hintHeight - gap - buttonHeight, figWidth - 2 * gap, buttonHeight], ...
    'Callback', @(src, evt)plotICsButtonCallback());

% --- Bottom: plot marked time series, then reject marked (full width, stacked) ---
plotTimeY = gap + buttonHeight + gap;
rejectY = gap;

uicontrol( ...
    'Parent',  hFig, ...
    'Style',   'pushbutton', ...
    'String',  'plot time without marked', ...
    'FontSize', 9, ...
    'FontWeight', 'bold', ...
    'BackgroundColor', controlGray, ...
    'Position', [gap, plotTimeY, figWidth - 2 * gap, buttonHeight], ...
    'Callback', @(src, evt)plotCallback(hFig));

uicontrol( ...
    'Parent',  hFig, ...
    'Style',   'pushbutton', ...
    'String',  'REJECT MARKED', ...
    'FontSize', 11, ...
    'FontWeight', 'bold', ...
    'BackgroundColor', controlGray, ...
    'Position', [gap, rejectY, figWidth - 2 * gap, buttonHeight], ...
    'Callback', @(src, evt)rejectButtonCallback());

% Create number buttons (1..nButtons); 3+ columns when needed to fit screen
for k = 1:nButtons
    row = floor((k - 1) / nCols);   % 0-based row index
    col = mod((k - 1), nCols);      % 0-based col index

    xpos = gap + col * (buttonWidth + gap);
    ypos = figHeight - topReserve ... % below top bar + gap to first number row
        - numberGridYOffset ...
        - row * (buttonHeight + gap);

    btn = uicontrol( ...
        'Parent',  hFig, ...
        'Style',   'pushbutton', ...
        'String',  num2str(k), ...
        'Tag',     'numberButton', ...
        'FontSize', 11, ...
        'BackgroundColor', defaultColor, ...
        'Position', [xpos, ypos, buttonWidth, buttonHeight], ...
        'Callback', @(src, evt)numberButtonToggleMark(hFig, src, k, defaultColor, activeColor), ...
        'ButtonDownFcn', @(src, evt)numberButtonRightClickPlot(hFig, k));

    buttonHandles(k) = btn;
end

% Update stored handles
setappdata(hFig, 'buttonHandles', buttonHandles);
end

function numberButtonRightClickPlot(hFig, idx)
% Right-click: single-plot. Left-click down clears stale suppress flag (see toggle fn).
st = get(hFig, 'SelectionType');
if strcmpi(st, 'alt')
    setappdata(hFig, 'rejICsSuppressNumberToggle', true);
    plotCallback(hFig, idx);
else
    if isappdata(hFig, 'rejICsSuppressNumberToggle')
        rmappdata(hFig, 'rejICsSuppressNumberToggle');
    end
end
end

function numberButtonToggleMark(hFig, hButton, idx, defaultColor, activeColor)
% Left-click release (pushbutton Callback): toggle mark / unmark.
% Skip when this release follows a right-click (ButtonDownFcn set suppress flag).
if isappdata(hFig, 'rejICsSuppressNumberToggle') && getappdata(hFig, 'rejICsSuppressNumberToggle')
    rmappdata(hFig, 'rejICsSuppressNumberToggle');
    return;
end

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

function plotCallback(hFig, varargin)
% Apply selection to EEG.reject.gcompreject and plot.
% With varargin{1} = idx: single-plot mode (plot that component only).
% Without varargin: use marked indices from selection.
selection = getappdata(hFig, 'selection');

% Access EEG from base workspace
EEG = evalin('base', 'EEG');

if ~isfield(EEG, 'reject') || ~isfield(EEG.reject, 'gcompreject')
    errordlg('EEG.reject.gcompreject does not exist.', 'Error', 'modal');
    return;
end

gcompreject = EEG.reject.gcompreject;

if ~isvector(gcompreject)
    errordlg('EEG.reject.gcompreject must be a 1D vector.', 'Error', 'modal');
    return;
end

% Ensure column vector
gcompreject = gcompreject(:);
n = numel(gcompreject);

% Set all to 0
gcompreject(:) = 0;

% Decide which indices to plot
if ~isempty(varargin)
    idx = varargin{1};
    selectedIdx = idx(idx >= 1 & idx <= n);
else
    maxIdx = min(n, numel(selection));
    selectedIdx = find(selection(1:maxIdx));
end

gcompreject(selectedIdx) = 1;

% Write back into EEG and base workspace
EEG.reject.gcompreject = gcompreject;
assignin('base', 'EEG', EEG);

closeWindows('eegplot');
plotAfterRejICs(EEG);

fprintf('Updated EEG.reject.gcompreject for components: %s\n', mat2str(selectedIdx));
end


function plotAfterRejICs(EEG)
components = find(EEG.reject.gcompreject == 1);
components = components(:)';
component_keep = setdiff_bc(1:size(EEG.icaweights,1), components);
compproj = EEG.icawinv(:, component_keep)*eeg_getdatact(EEG, 'component', component_keep, 'reshape', '2d');
compproj = reshape(compproj, size(compproj,1), EEG.pnts, EEG.trials);
eegplot( EEG.data(EEG.icachansind,:,:), 'srate', EEG.srate, 'title', 'Black = channel before rejection; red = after rejection -- eegplot()', ...
    'limits', [EEG.xmin EEG.xmax]*1000, 'data2', compproj);
end

% -------------------------------------------------------------------------

function plotICs(EEG)
closeWindows('pop_selectcomps');
n_ICs = size(EEG.icawinv,2);
pop_selectcomps(EEG, [1:n_ICs] );
end

function plotICsButtonCallback()
% Fetch EEG from base workspace and call plotICs
EEG = evalin('base', 'EEG');
plotICs(EEG);
end

% -------------------------------------------------------------------------

function confirmRejICs()
closeWindows('eegplot'); closeWindows('pop_selectcomps');

% Get marked indices from GUI and set gcompreject before rejection
hFig = gcf;
selection = getappdata(hFig, 'selection');

EEG     = evalin('base', 'EEG');
ALLEEG  = evalin('base', 'ALLEEG');
CURRENTSET = evalin('base', 'CURRENTSET');

% Keep prior pop_prop captures across multiple REJECT clicks (append, do not replace)
prevRejICs = loadPrevRejICsForAppend(EEG);

% Ensure gcompreject exists and is proper size
if ~isfield(EEG, 'reject')
    EEG.reject = struct();
end
if ~isfield(EEG.reject, 'gcompreject')
    EEG.reject.gcompreject = false(size(EEG.icawinv, 2), 1);
end

gcompreject = EEG.reject.gcompreject(:);
n = numel(gcompreject);
maxIdx = min(n, numel(selection));
selectedIdx = find(selection(1:maxIdx));

% Set marked components to 1 in gcompreject
gcompreject(:) = 0;
gcompreject(selectedIdx) = 1;
EEG.reject.gcompreject = gcompreject;

% pop_prop figure for each IC marked for rejection; store RGB in EEG.moreInfo.rejICsPng(k).png
rejICsData = captureRejICsPropImages(EEG, hFig);

% Perform rejection
EEG = pop_subcomp(EEG, [], 0);
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 0, 'gui', 'off');

if ~isfield(EEG, 'moreInfo') || ~isstruct(EEG.moreInfo)
    EEG.moreInfo = struct();
end
if isempty(prevRejICs)
    EEG.moreInfo.rejICsPng = rejICsData(:);
else
    EEG.moreInfo.rejICsPng = [prevRejICs(:); rejICsData(:)];
end
EEG.moreInfo.nRejICs = numel(EEG.moreInfo.rejICsPng);

assignin('base', 'EEG', EEG);
assignin('base', 'ALLEEG', ALLEEG);
assignin('base', 'CURRENTSET', CURRENTSET);

% Close this GUI figure and reopen with fresh state (all buttons unmarked)
close(hFig);
rejICsGUI(EEG);
end

function rejectButtonCallback()
% Wrapper for the REJECT button
confirmRejICs();
end

function prev = loadPrevRejICsForAppend(EEG)
% Return existing rejICsPng struct column for concatenation, or empty if none / wrong shape
prev = [];
if ~isfield(EEG, 'moreInfo') || ~isstruct(EEG.moreInfo) || ~isfield(EEG.moreInfo, 'rejICsPng')
    return;
end
r = EEG.moreInfo.rejICsPng;
if isempty(r) || ~isa(r, 'struct') || ~isfield(r, 'png')
    return;
end
prev = r(:);
end

function rejICsPng = captureRejICsPropImages(EEG, hGuiFig)
% One pop_prop per rejected IC; capture getframe(...).cdata into rejICsPng(ii).png
idx = find(EEG.reject.gcompreject(:) == 1);
nrej = numel(idx);
rejICsPng = repmat(struct('png', []), nrej, 1);
if nrej == 0
    return;
end

for ii = 1:nrej
    ri = idx(ii);
    figsBefore = findall(0, 'Type', 'figure');
    try
        pop_prop(EEG, 0, ri, [], { 'freqrange', [1 50] });
    catch ME
        warning('captureRejICsPropImages:pop_prop', 'IC %d: %s', ri, ME.message);
        rejICsPng(ii).png = [];
        continue;
    end
    drawnow;
    hProp = findNewPopPropFigure(figsBefore, hGuiFig);
    if isempty(hProp) || ~isgraphics(hProp)
        warning('captureRejICsPropImages:figure', 'No pop_prop figure for IC %d', ri);
        rejICsPng(ii).png = [];
        continue;
    end
    figure(hProp);
    drawnow;
    try
        rejICsPng(ii).png = getframe(hProp).cdata;
    catch ME
        warning('captureRejICsPropImages:getframe', 'IC %d: %s', ri, ME.message);
        rejICsPng(ii).png = [];
    end
    if isgraphics(hProp)
        close(hProp);
    end
end
end

function hProp = findNewPopPropFigure(figsBefore, hGuiFig)
% Prefer figure whose Name contains 'pop_prop' among handles not in figsBefore.
figsAfter = findall(0, 'Type', 'figure');
newF = figsAfter(~ismember(figsAfter, figsBefore));
hProp = gobjects(0);
for jj = 1:numel(newF)
    if newF(jj) == hGuiFig
        continue;
    end
    nm = get(newF(jj), 'Name');
    if ~isempty(nm) && contains(lower(nm), 'pop_prop')
        hProp = newF(jj);
        return;
    end
end
if ~isempty(newF)
    pick = newF(newF ~= hGuiFig);
    if ~isempty(pick)
        hProp = pick(end);
    end
end
end
