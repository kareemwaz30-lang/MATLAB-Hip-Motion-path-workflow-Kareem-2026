%% c3d_excel_hip_extraction
% Extracts left- and right-hip rotation angles from a single-subject C3D
% file. Run the script and select a C3D file when prompted. The required
% waist, thigh, knee and ankle markers must be present, and ezc3dRead must
% be available on the MATLAB path. The script plots the three hip rotations
% and exports separate hip-angle workbooks and a marker-quality report.
clear all
close all
clc

%% Load C3D file
[c3dFile,c3dPath] = uigetfile('*.c3d','Choose a C3D file');
if isequal(c3dFile,0)
    disp('No C3D file selected.');
    return
end

c3dFullPath = fullfile(c3dPath,c3dFile);
c3d = ezc3dRead(c3dFullPath);
[~,baseName] = fileparts(c3dFile);

labels = c3d.parameters.POINT.LABELS.DATA;
points = c3d.data.points;

% Accepted aliases are matched after subject prefixes and punctuation are
% removed. For example, Dance:L_FWT and Subject01:LFWT both match LFWT.
% Numbered duplicates such as RFWT-1 normalise to RFWT1 and therefore do
% not silently replace the unnumbered measured marker.
markerDefs.LFWT = {'LFWT','L_FWT','LEFTFWT','LEFT_FRONT_WAIST'};
markerDefs.RFWT = {'RFWT','R_FWT','RIGHTFWT','RIGHT_FRONT_WAIST'};
markerDefs.LBWT = {'LBWT','L_BWT','LEFTBWT','LEFT_BACK_WAIST'};
markerDefs.RBWT = {'RBWT','R_BWT','RIGHTBWT','RIGHT_BACK_WAIST'};
markerDefs.RTHI = {'RTHI','R_THI','RIGHTTHI','RIGHT_THIGH'};
markerDefs.RKNE = {'RKNE','R_KNE','RIGHTKNE','RIGHT_KNEE'};
markerDefs.RANK = {'RANK','R_ANK','RANKLE','RIGHTANK','RIGHT_ANKLE'};
markerDefs.LTHI = {'LTHI','L_THI','LEFTTHI','LEFT_THIGH'};
markerDefs.LKNE = {'LKNE','L_KNE','LEFTKNE','LEFT_KNEE'};
markerDefs.LANK = {'LANK','L_ANK','LANKLE','LEFTANK','LEFT_ANKLE'};

fields = fieldnames(markerDefs);
markerIdx = struct();
selectedLabels = cell(numel(fields),1);

for i = 1:numel(fields)
    [markerIdx.(fields{i}),selectedLabels{i}] = findMarkerControlled( ...
        labels,markerDefs.(fields{i}),fields{i});
end

missing = fields(cellfun(@(f) isnan(markerIdx.(f)),fields));
if ~isempty(missing)
    error('Required markers could not be identified: %s',strjoin(missing,', '));
end

selectionLines = cell(numel(fields)+1,1);
selectionLines{1} = sprintf('Selected C3D: %s\n',c3dFile);
for i = 1:numel(fields)
    selectionLines{i+1} = sprintf('%-5s -> marker %d: %s', ...
        fields{i},markerIdx.(fields{i}),selectedLabels{i});
end

selectionMessage = strjoin(selectionLines,newline);
selectionChoice = questdlg(selectionMessage,'Confirm selected markers', ...
    'Continue','Cancel','Continue');
if ~strcmp(selectionChoice,'Continue')
    disp('Marker selection cancelled by user.');
    return
end

% ezc3d point data can contain a fourth residual component. Only XYZ are
% used for trajectory calculations.
getTraj = @(idx) squeeze(points(1:3,idx,:))';

LFWT = getTraj(markerIdx.LFWT);
RFWT = getTraj(markerIdx.RFWT);
LBWT = getTraj(markerIdx.LBWT);
RBWT = getTraj(markerIdx.RBWT);

if ~isnan(markerIdx.RTHI), RTHI = getTraj(markerIdx.RTHI); end
if ~isnan(markerIdx.RKNE), RKNE = getTraj(markerIdx.RKNE); end
if ~isnan(markerIdx.RANK), RANK = getTraj(markerIdx.RANK); end
if ~isnan(markerIdx.LTHI), LTHI = getTraj(markerIdx.LTHI); end
if ~isnan(markerIdx.LKNE), LKNE = getTraj(markerIdx.LKNE); end
if ~isnan(markerIdx.LANK), LANK = getTraj(markerIdx.LANK); end

N = size(LFWT,1);

%% Trajectory completeness report
[trajectoryReport,markerValid] = assessTrajectories(points,labels,markerIdx,fields);
disp(' ')
disp('--- Selected Marker Trajectory Report ---')
disp(trajectoryReport)
writetable(trajectoryReport,fullfile(c3dPath, ...
    [baseName '_marker_quality.xlsx']),'Sheet','MarkerQuality');

reportMessage = formatTrajectoryReport(trajectoryReport);
reportChoice = questdlg(reportMessage,'Trajectory completeness', ...
    'Continue','Cancel','Continue');
if ~strcmp(reportChoice,'Continue')
    disp('Processing cancelled after trajectory review.');
    return
end

HipAngles_R = NaN(N,3);
HipAngles_L = NaN(N,3);

%% Flexion-angle correction
flexionCorrectionDeg = 45;      % Flexion offset in degrees.
useFlexionCorrection = true;

%% Main loop
for i = 1:N

    %% Pelvis frame
    pelvisFrameValid = markerValid.LFWT(i) && markerValid.RFWT(i) && ...
        markerValid.LBWT(i) && markerValid.RBWT(i);
    if ~pelvisFrameValid
        continue
    end

    x_pelvis = RFWT(i,:) - LFWT(i,:);
    if norm(x_pelvis) <= eps
        continue
    end
    x_pelvis = x_pelvis / norm(x_pelvis);

    sacrum = (LBWT(i,:) + RBWT(i,:)) / 2;
    pelvis_origin = (LFWT(i,:) + RFWT(i,:)) / 2;

    y_temp = pelvis_origin - sacrum;
    if norm(y_temp) <= eps
        continue
    end
    y_temp = y_temp / norm(y_temp);

    z_pelvis = cross(x_pelvis, y_temp);
    if norm(z_pelvis) <= eps
        continue
    end
    z_pelvis = z_pelvis / norm(z_pelvis);

    y_pelvis = cross(z_pelvis, x_pelvis);
    y_pelvis = y_pelvis / norm(y_pelvis);

    R_pelvis = [x_pelvis' y_pelvis' z_pelvis'];

    %% Right femur frame
    rightFrameValid = markerValid.RTHI(i) && markerValid.RKNE(i) && ...
        markerValid.RANK(i);
    if rightFrameValid

        z_femur = RKNE(i,:) - RTHI(i,:);
        if norm(z_femur) > eps
            z_femur = z_femur / norm(z_femur);

            temp = RANK(i,:) - RKNE(i,:);
            x_femur = cross(temp, z_femur);
            if norm(x_femur) > eps
                x_femur = x_femur / norm(x_femur);

                y_femur = cross(z_femur, x_femur);
                y_femur = y_femur / norm(y_femur);

                R_femur = [x_femur' y_femur' z_femur'];

                R_hip = R_pelvis' * R_femur;

                flex = atan2(R_hip(3,2), R_hip(3,3));
                abd  = atan2(-R_hip(3,1), sqrt(R_hip(3,2)^2 + R_hip(3,3)^2));
                rot  = atan2(R_hip(2,1), R_hip(1,1));

                if useFlexionCorrection
                    flex = flex - deg2rad(flexionCorrectionDeg);
                end

                HipAngles_R(i,:) = rad2deg([flex abd rot]);
            end
        end
    end

    %% Left femur frame
    leftFrameValid = markerValid.LTHI(i) && markerValid.LKNE(i) && ...
        markerValid.LANK(i);
    if leftFrameValid

        z_femur = LKNE(i,:) - LTHI(i,:);
        if norm(z_femur) > eps
            z_femur = z_femur / norm(z_femur);

            temp = LANK(i,:) - LKNE(i,:);
            x_femur = cross(temp, z_femur);
            if norm(x_femur) > eps
                x_femur = x_femur / norm(x_femur);

                y_femur = cross(z_femur, x_femur);
                y_femur = y_femur / norm(y_femur);

                R_femur = [x_femur' y_femur' z_femur'];

                R_hip = R_pelvis' * R_femur;

                flex = atan2(R_hip(3,2), R_hip(3,3));
                abd  = atan2(-R_hip(3,1), sqrt(R_hip(3,2)^2 + R_hip(3,3)^2));
                rot  = atan2(R_hip(2,1), R_hip(1,1));

                if useFlexionCorrection
                    flex = flex - deg2rad(flexionCorrectionDeg);
                end

                HipAngles_L(i,:) = rad2deg([flex abd rot]);
            end
        end
    end
end

%% Unwrap to avoid 180 jumps
for c = 1:3
    HipAngles_R(:,c) = unwrapWithNaNs(HipAngles_R(:,c));
    HipAngles_L(:,c) = unwrapWithNaNs(HipAngles_L(:,c));
end

%% Optional zeroing to first frame
zeroToFirstFrame = true;
if zeroToFirstFrame
    firstValidR = find(all(~isnan(HipAngles_R),2),1);
    firstValidL = find(all(~isnan(HipAngles_L),2),1);
    if ~isempty(firstValidR)
        HipAngles_R = HipAngles_R - HipAngles_R(firstValidR,:);
    end
    if ~isempty(firstValidL)
        HipAngles_L = HipAngles_L - HipAngles_L(firstValidL,:);
    end
end

%% Plot
figure
plot(HipAngles_R(:,1),'b','LineWidth',1.2)
hold on
plot(HipAngles_L(:,1),'r','LineWidth',1.2)
legend('Right','Left')
xlabel('Frame')
ylabel('Angle (deg)')
title('Hip Flexion / Extension')
grid on

figure
plot(HipAngles_R(:,2),'b','LineWidth',1.2)
hold on
plot(HipAngles_L(:,2),'r','LineWidth',1.2)
legend('Right','Left')
xlabel('Frame')
ylabel('Angle (deg)')
title('Hip Abduction / Adduction')
grid on

figure
plot(HipAngles_R(:,3),'b','LineWidth',1.2)
hold on
plot(HipAngles_L(:,3),'r','LineWidth',1.2)
legend('Right','Left')
xlabel('Frame')
ylabel('Angle (deg)')
title('Hip Internal / External Rotation')
grid on

%% Export hip-angle workbooks
filename_R = fullfile(c3dPath,[baseName '_HipAngles_Right.xlsx']);
filename_L = fullfile(c3dPath,[baseName '_HipAngles_Left.xlsx']);

FlexExt_R = array2table(HipAngles_R(:,1));
AbdAdd_R  = array2table(HipAngles_R(:,2));
IntExt_R  = array2table(HipAngles_R(:,3));

FlexExt_L = array2table(HipAngles_L(:,1));
AbdAdd_L  = array2table(HipAngles_L(:,2));
IntExt_L  = array2table(HipAngles_L(:,3));

writetable(FlexExt_R, filename_R, 'Sheet', 'FlexExt');
writetable(AbdAdd_R,  filename_R, 'Sheet', 'AbdAdd');
writetable(IntExt_R,  filename_R, 'Sheet', 'IntExt');

writetable(FlexExt_L, filename_L, 'Sheet', 'FlexExt');
writetable(AbdAdd_L,  filename_L, 'Sheet', 'AbdAdd');
writetable(IntExt_L,  filename_L, 'Sheet', 'IntExt');

disp('Export complete')
disp(['Right hip output: ',filename_R])
disp(['Left hip output: ',filename_L])

%% Local functions
function [idx,selectedLabel] = findMarkerControlled(labels,aliases,markerName)
normalisedLabels = cellfun(@normaliseMarkerLabel,labels,'UniformOutput',false);
normalisedAliases = cellfun(@normaliseMarkerLabel,aliases,'UniformOutput',false);
matches = find(ismember(normalisedLabels,normalisedAliases));

if isempty(matches)
    prompt = sprintf(['No automatic match was found for %s.\n' ...
        'Select the correct marker manually, or press Cancel.'],markerName);
    [choice,ok] = listdlg('PromptString',prompt,'SelectionMode','single', ...
        'ListString',labels,'ListSize',[420 320]);
    if ok
        idx = choice;
        selectedLabel = labels{idx};
    else
        idx = NaN;
        selectedLabel = '';
    end
elseif numel(matches) == 1
    idx = matches(1);
    selectedLabel = labels{idx};
else
    candidateLabels = labels(matches);
    prompt = sprintf(['Multiple matches were found for %s.\n' ...
        'Select the measured marker to use.'],markerName);
    [choice,ok] = listdlg('PromptString',prompt,'SelectionMode','single', ...
        'ListString',candidateLabels,'ListSize',[420 220]);
    if ok
        idx = matches(choice);
        selectedLabel = labels{idx};
    else
        idx = NaN;
        selectedLabel = '';
    end
end
end

function name = normaliseMarkerLabel(label)
name = upper(strtrim(char(label)));
colonPosition = find(name == ':',1,'last');
if ~isempty(colonPosition)
    name = name(colonPosition+1:end);
end
name = regexprep(name,'[^A-Z0-9]','');
end

function [report,markerValid] = assessTrajectories(points,labels,markerIdx,fields)
nFrames = size(points,3);
nMarkers = numel(fields);
markerNames = strings(nMarkers,1);
selectedLabels = strings(nMarkers,1);
validFrames = zeros(nMarkers,1);
missingFrames = zeros(nMarkers,1);
completeness = zeros(nMarkers,1);
longestGap = zeros(nMarkers,1);
markerValid = struct();

for k = 1:nMarkers
    field = fields{k};
    idx = markerIdx.(field);
    xyz = squeeze(points(1:3,idx,:))';
    valid = all(isfinite(xyz),2) & ~all(abs(xyz) <= eps,2);

    % ezc3d commonly stores a negative residual for an invalid observation.
    if size(points,1) >= 4
        residual = squeeze(points(4,idx,:));
        valid = valid & residual(:) >= 0;
    end

    markerValid.(field) = valid;
    markerNames(k) = string(field);
    selectedLabels(k) = string(labels{idx});
    validFrames(k) = sum(valid);
    missingFrames(k) = nFrames-validFrames(k);
    completeness(k) = 100*validFrames(k)/nFrames;
    longestGap(k) = longestTrueRun(~valid);
end

report = table(markerNames,selectedLabels,repmat(nFrames,nMarkers,1), ...
    validFrames,missingFrames,completeness,longestGap, ...
    'VariableNames',{'Marker','SelectedLabel','TotalFrames','ValidFrames', ...
    'MissingFrames','CompletenessPercent','LongestMissingGapFrames'});
end

function longest = longestTrueRun(values)
values = logical(values(:));
edges = diff([false;values;false]);
starts = find(edges == 1);
stops = find(edges == -1)-1;
if isempty(starts)
    longest = 0;
else
    longest = max(stops-starts+1);
end
end

function message = formatTrajectoryReport(report)
lines = strings(height(report)+4,1);
lines(1) = "Trajectory completeness checks coordinate availability, not movement.";
lines(2) = "Standing still is valid and is not treated as missing data.";
lines(3) = "No marker or trial is rejected automatically.";
lines(4) = "";
for k = 1:height(report)
    lines(k+4) = sprintf('%-5s: %6.2f%% complete, %d missing, longest gap %d frames', ...
        report.Marker(k),report.CompletenessPercent(k), ...
        report.MissingFrames(k),report.LongestMissingGapFrames(k));
end
message = strjoin(cellstr(lines),newline);
end

function output = unwrapWithNaNs(input)
output = input;
valid = ~isnan(input);
edges = diff([false;valid;false]);
starts = find(edges == 1);
stops = find(edges == -1)-1;
for k = 1:numel(starts)
    range = starts(k):stops(k);
    output(range) = rad2deg(unwrap(deg2rad(input(range))));
end
end
