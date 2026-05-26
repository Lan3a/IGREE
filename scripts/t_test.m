
% init
project = addPaeegPath;
project = chooseProject(project);

%%
selectedProject = uigetdir();

%%

projConfigDir = fullfile(selectedProject, 'projConfig.m');

% temp add path
addpath(projConfigDir);
project = projectConfig(project);
rmpath(projConfigDir);




%%
clear age
age          = getPatientInfo().age;

function patient = getPatientInfo()
    % This function returns a struct
    
    patient = struct();
    patient.name       = 'John Doe';
    patient.age        = 28;
    patient.sessionIdx = 5;
    
    patient.vitals = struct();
    patient.vitals.heartRate = 72;
    patient.vitals.bloodPressure = '120/80';
    patient.vitals.temperature = 36.8;
    
    patient.data = rand(1000, 64);   % large data (imagine EEG)
    patient.events = {'gb1', 'pb2', 'g15', 'p3'};
    
    % You can add more fields...
end