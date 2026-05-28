function custom_pop_spectopo(EEG)
screenSize = get(0, 'ScreenSize');
maxFigWidth = 0.9 * screenSize(3);
initWidth = min(1200, maxFigWidth);
figure('Name', 'custom_pop_spectopo', 'NumberTitle', 'off', 'Position', [100 100 initWidth 700]);
pop_spectopo(EEG, 1, [], 'EEG', ...
    'chanlocs', EEG.chanlocs, ...
    'freqrange', [1 60], ...
    'electrodes', 'on');

fig = gcf;
ax = gca;
% Add horizontal red line at y = 0
yline(ax, 0, 'r--', 'LineWidth', 1.5);
% Clear EEGLAB/spectopo callbacks that may open duplicate plots
set(fig, 'WindowButtonDownFcn', '');
set(findall(fig, 'Type', 'axes'), 'ButtonDownFcn', '');
chanLabels = {EEG.chanlocs.labels};
lines = findobj(ax, 'Type', 'line');
lines = flipud(lines);
lines = lines(1:min(numel(lines), numel(chanLabels)));
chanLabels = chanLabels(1:numel(lines));
% Give every channel a unique color before dimming
nLines = numel(lines);
colors = turbo(nLines);   % good for many channels
for k = 1:nLines
    lines(k).Color = colors(k, :);
end
% Store original colors and dim everything initially
for k = 1:numel(lines)
    lines(k).UserData = struct( ...
        'dimmed', true, ...
        'originalColor', lines(k).Color, ...
        'originalLineWidth', lines(k).LineWidth);
    lines(k).Color = [0.8 0.8 0.8];
    lines(k).LineWidth = 0.5;
    lines(k).ButtonDownFcn = @spectopoCurveClick;
    lines(k).PickableParts = 'all';
    lines(k).HitTest = 'on';
end

% Multi-column legend so many channels wrap across columns instead of one
% tall stack; widen figure (up to 90% screen width) if the legend still
% clips vertically.
maxRowsPerColumn = 22;
nCols = max(1, ceil(nLines / maxRowsPerColumn));
pos = fig.Position;
pos(3) = min(max(1200, 780 + 52 * nCols), maxFigWidth);
fig.Position = pos;

lgd = legend(lines, chanLabels, ...
    'Location', 'eastoutside', ...
    'Interpreter', 'none');
if isprop(lgd, 'NumColumns')
    lgd.NumColumns = nCols;
end
drawnow;
widenFigureUntilLegendFits(fig, lgd, maxFigWidth);

lgd.ItemHitFcn = @spectopoLegendClick;

% Disable right-click context menu on legend and its children
disableContextMenus(lgd);
end 

%%
function spectopoLegendClick(~, event)
    fig = ancestor(event.Peer, 'figure');
    clickType = get(fig, 'SelectionType');

    applyClickDimState(event.Peer, clickType);
end

function spectopoCurveClick(lineObj, ~)
    fig = ancestor(lineObj, 'figure');
    clickType = get(fig, 'SelectionType');

    applyClickDimState(lineObj, clickType);
end

function applyClickDimState(lineObj, clickType)
    switch clickType
        case 'normal'  % left click
            undimLine(lineObj);

        case 'alt'     % right click
            dimLine(lineObj);

        otherwise
            % Middle/double click: ignore
    end
end

function undimLine(lineObj)
    if isstruct(lineObj.UserData) && isfield(lineObj.UserData, 'originalColor')
        lineObj.Color = lineObj.UserData.originalColor;
        lineObj.LineWidth = max(lineObj.UserData.originalLineWidth, 1.2);
        lineObj.UserData.dimmed = false;
    end
end

function dimLine(lineObj)
    if isstruct(lineObj.UserData) && isfield(lineObj.UserData, 'originalColor')
        lineObj.Color = [0.8 0.8 0.8];
        lineObj.LineWidth = 0.5;
        lineObj.UserData.dimmed = true;
    end
end

function disableContextMenus(obj)
    allObjs = findall(obj);
    for k = 1:numel(allObjs)
        if isprop(allObjs(k), 'UIContextMenu')
            allObjs(k).UIContextMenu = [];
        end
        if isprop(allObjs(k), 'ContextMenu')
            allObjs(k).ContextMenu = [];
        end
    end
end

function widenFigureUntilLegendFits(fig, lgd, maxFigWidth)
    fig.Units = 'pixels';
    lgd.Units = 'pixels';
    widthStep = 80;
    maxIters = 40;
    for iter = 1:maxIters
        if legendContainedInFigure(fig, lgd)
            return;
        end
        p = fig.Position;
        if p(3) < maxFigWidth - 0.5
            p(3) = min(p(3) + widthStep, maxFigWidth);
            fig.Position = p;
            drawnow;
        elseif isprop(lgd, 'NumColumns') && lgd.NumColumns < numel(lgd.String)
            lgd.NumColumns = lgd.NumColumns + 1;
            drawnow;
            if legendContainedInFigure(fig, lgd)
                return;
            end
            break;
        else
            break;
        end
    end
end

function ok = legendContainedInFigure(fig, lgd)
    % Legend position is in the figure drawable; compare to InnerPosition.
    if isprop(fig, 'InnerPosition')
        ip = fig.InnerPosition;
    else
        ip = fig.Position;
    end
    fw = ip(3);
    fh = ip(4);
    % Older Legend has no OuterPosition; Position is [left bottom width height].
    if isprop(lgd, 'OuterPosition')
        lo = lgd.OuterPosition;
    else
        lo = lgd.Position;
    end
    legendLeft = lo(1);
    legendBottom = lo(2);
    legendRight = lo(1) + lo(3);
    legendTop = lo(2) + lo(4);
    pad = 6;
    ok = legendBottom >= -pad && legendTop <= fh + pad && ...
        legendLeft >= -pad && legendRight <= fw + pad;
end