function closeWindows(name)
% closeWindows - Close figure windows whose title contains the given name
%
% Usage:
%   closeWindows('eegplot')    % closes all figures whose title contains 'eegplot'
%   closeWindows('Figure')     % closes all figures whose title contains 'Figure'

figs = findall(0, 'Type', 'figure');
if isempty(figs)
    return
end

names = get(figs, 'Name');
if ischar(names)
    names = {names};
end

idx = contains(names, name, 'IgnoreCase', true);
close(figs(idx));

end
