%% marker_names
% Lists the marker labels and indices stored in a selected C3D file. Run
% the script, choose a C3D file and review the marker list in the Command
% Window. Requires ezc3dRead on the MATLAB path.

%% Load C3D file
[fileName, folderName] = uigetfile({'*.c3d', 'C3D files (*.c3d)'}, ...
    'Select a C3D file');

if isequal(fileName, 0)
    error('No C3D file selected.');
end

c3dFile = fullfile(folderName, fileName);
c3d = ezc3dRead(c3dFile);

fprintf('Loaded C3D file:\n%s\n\n', c3dFile);

%% Get marker labels
labels = c3d.parameters.POINT.LABELS.DATA;

%% Get marker data
points = c3d.data.points;

%% Display marker list

disp('--- Marker List ---')

for i = 1:length(labels)
    disp([num2str(i), ' : ', labels{i}])
end

disp('-------------------')
