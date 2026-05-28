function paths = addPaths(pathConfig)

if nargin < 1, pathConfig = struct(); end

paths = struct();

scriptsPath = fileparts(mfilename('fullpath'));
[rootPath, ~] = fileparts(scriptsPath);

% -------------------------------------------------------------------------
% projects folder path
if isfield(pathConfig, 'projects')
    projectsPath = pathConfig.projects;
else
    projectsPath = fullfile(rootPath, 'projects');
end



% Add all paths
if exist(scriptsPath, 'dir')
    paths.scripts = scriptsPath;
    addpath(scriptsPath)
    disp('>> added scripts path')
else
    error(">>>> (WEIRD ERROR) Scripts path doesn't exist")
end

if exist(projectsPath, 'dir')
    paths.projects = projectsPath;
    addpath(projectsPath)
    disp('>> added projects path')
else
    error(">>>> Projects path doesn't exist")
end


