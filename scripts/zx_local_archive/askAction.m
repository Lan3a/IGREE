function choice = askAction(title, options)
% askAction  Show action dialog and return user choice.
%
%   choice = askAction(title, options)
%   choice = askAction(title, options, closeFigures)
%
%   title:        dialog title (default 'Action')
%   options:      cell of option strings (default: Save and Continue Next, Skip, etc.)
%   closeFigures: if true, closes all figures after (default true)
%
%   Returns: selected option string, or '' if cancelled/closed.
if nargin < 1, title = 'Action'; end
if nargin < 2
    options = {'Save this and Continue', 'Save this and Exit', 'Skip this', 'Reset this', 'Cancel'};
end

choice = contDlg(title, options);

end


%%
function choice = contDlg(title, buttonNames)
choice = '';
n = numel(buttonNames);
h = 30; s = 10;
w = 260; H = 80 + n*(h + s);

fig = uifigure('Name', 'Select Option', 'Position', [300 300 w H]);
sc = get(groot, 'ScreenSize');
fig.Position = [sc(3)-w-200, sc(4)-H-200, w, H];

uilabel(fig, 'Text', title, 'Position', [20 H-50 w-40 40], 'WordWrap', 'on');

for k = 1:n
    uibutton(fig, 'Text', buttonNames{k}, ...
        'Position', [40 H-40-k*(h+s) w-80 h], ...
        'ButtonPushedFcn', @(src,evt) onPush(buttonNames{k}));
end

uiwait(fig);

    function onPush(val)
        choice = char(val);
        uiresume(fig);
        delete(fig);
    end
end
