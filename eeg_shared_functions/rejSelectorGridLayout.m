function layout = rejSelectorGridLayout(nButtons, buttonWidth, buttonHeight, gap, nonGridHeight, pad)
%REJSELECTORGRIDLAYOUT Column count and figure size for rejICs / rejBadChan GUIs.
% Uses at least 3 columns; increases columns when the figure would exceed the
% screen (bottom-right placement with pad margin on all sides).

if nargin < 6 || isempty(pad)
    pad = 200;
end

minCols = 3;
if nButtons < 1
    nButtons = 1;
end

sc = get(groot, 'ScreenSize');
maxFigHeight = sc(4) - sc(2) - 2 * pad;
maxFigWidth  = sc(3) - sc(1) - 2 * pad;
maxColsWidth = max(minCols, floor((maxFigWidth - gap) / (buttonWidth + gap)));

nCols = min(minCols, nButtons);
nRows = ceil(nButtons / nCols);
figWidth  = gridFigWidth(nCols, buttonWidth, gap);
figHeight = gridFigHeight(nRows, buttonHeight, gap, nonGridHeight);

for tryCols = minCols:min(nButtons, maxColsWidth)
    tryRows = ceil(nButtons / tryCols);
    tryW = gridFigWidth(tryCols, buttonWidth, gap);
    tryH = gridFigHeight(tryRows, buttonHeight, gap, nonGridHeight);
    if tryH <= maxFigHeight && tryW <= maxFigWidth
        nCols = tryCols;
        nRows = tryRows;
        figWidth = tryW;
        figHeight = tryH;
        break;
    end
    % Keep last attempt if nothing fits (best effort at widest allowed grid)
    nCols = tryCols;
    nRows = tryRows;
    figWidth = tryW;
    figHeight = tryH;
end

figLeft = sc(3) - figWidth - pad;
figBottom = sc(2) + pad;

layout = struct( ...
    'nCols', nCols, ...
    'nRows', nRows, ...
    'figWidth', figWidth, ...
    'figHeight', figHeight, ...
    'position', [figLeft, figBottom, figWidth, figHeight]);
end

function w = gridFigWidth(nCols, buttonWidth, gap)
w = nCols * buttonWidth + (nCols + 1) * gap;
end

function h = gridFigHeight(nRows, buttonHeight, gap, nonGridHeight)
h = nonGridHeight + nRows * buttonHeight + max(0, nRows - 1) * gap;
end
