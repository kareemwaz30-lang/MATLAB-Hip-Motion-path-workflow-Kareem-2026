%% c3d_excel_two_subjects
% Extracts left- and right-hip rotation angles for two participants in one
% C3D file. Run the script and select a two-subject C3D file when prompted.
% Distinct subject prefixes and the required lower-limb markers must be
% present, and ezc3dRead must be available on the MATLAB path. The script
% plots both participants and exports four hip-angle workbooks and a
% combined marker-quality report.
clear all
close all
clc

%% Select and load C3D file
[c3dFile,c3dPath] = uigetfile('*.c3d','Choose a two-subject C3D file');
if isequal(c3dFile,0)
    disp('No C3D file selected.');
    return
end

c3dFullPath = fullfile(c3dPath,c3dFile);
c3d = ezc3dRead(c3dFullPath);
[~,baseName] = fileparts(c3dFile);
labels = c3d.parameters.POINT.LABELS.DATA;
points = c3d.data.points;

%% Marker definitions
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

%% Detect the two subjects from marker prefixes
prefixes = detectSubjectPrefixes(labels,markerDefs);
if numel(prefixes) < 2
    error(['Fewer than two subject prefixes were detected. Each subject must ' ...
        'have a distinct marker prefix such as dancerfemale: or dancermale:.']);
elseif numel(prefixes) > 2
    [choice,ok] = listdlg('PromptString', ...
        'Select the two subjects to process:','SelectionMode','multiple', ...
        'ListString',prefixes,'ListSize',[420 260]);
    if ~ok || numel(choice) ~= 2
        error('Exactly two subjects must be selected.');
    end
    prefixes = prefixes(choice);
end

subjects = struct([]);
for s = 1:2
    subjects(s).prefix = prefixes{s};
    subjects(s).displayName = makeSubjectDisplayName(prefixes{s},s);
    subjects(s).fileTag = makeFileTag(subjects(s).displayName,s);
    subjects(s).markerIdx = struct();
    subjects(s).selectedLabels = cell(numel(fields),1);

    for k = 1:numel(fields)
        [subjects(s).markerIdx.(fields{k}), ...
            subjects(s).selectedLabels{k}] = findMarkerForSubject( ...
            labels,markerDefs.(fields{k}),fields{k},prefixes{s});
    end

    missing = fields(cellfun(@(f) ...
        isnan(subjects(s).markerIdx.(f)),fields));
    if ~isempty(missing)
        error('%s is missing required markers: %s', ...
            subjects(s).displayName,strjoin(missing,', '));
    end

    selectionMessage = formatSelectionMessage(c3dFile,subjects(s),fields);
    selectionChoice = questdlg(selectionMessage, ...
        ['Confirm markers - ',subjects(s).displayName], ...
        'Continue','Cancel','Continue');
    if ~strcmp(selectionChoice,'Continue')
        disp('Marker selection cancelled by user.');
        return
    end
end

%% Trajectory completeness reports
allReports = cell(2,1);
for s = 1:2
    [subjects(s).trajectoryReport,subjects(s).markerValid] = ...
        assessTrajectories(points,labels,subjects(s).markerIdx,fields, ...
        subjects(s).displayName);
    allReports{s} = subjects(s).trajectoryReport;

    disp(' ')
    disp(['--- ',subjects(s).displayName,' Marker Trajectory Report ---'])
    disp(subjects(s).trajectoryReport)

    reportChoice = questdlg( ...
        formatTrajectoryReport(subjects(s).trajectoryReport), ...
        ['Trajectory completeness - ',subjects(s).displayName], ...
        'Continue','Cancel','Continue');
    if ~strcmp(reportChoice,'Continue')
        disp('Processing cancelled after trajectory review.');
        return
    end
end

combinedReport = [allReports{1};allReports{2}];
writetable(combinedReport,fullfile(c3dPath, ...
    [baseName '_two_subject_marker_quality.xlsx']), ...
    'Sheet','MarkerQuality');

%% Hip-angle calculation settings
flexionCorrectionDeg = 45;
useFlexionCorrection = true;
zeroToFirstFrame = true;

%% Calculate both subjects
for s = 1:2
    [subjects(s).HipAngles_R,subjects(s).HipAngles_L] = ...
        computeHipAngles(points,subjects(s).markerIdx, ...
        subjects(s).markerValid,flexionCorrectionDeg, ...
        useFlexionCorrection,zeroToFirstFrame);
end

%% Plot right and left hips together for each subject
for s = 1:2
    plotHipAngles(subjects(s).HipAngles_R,subjects(s).HipAngles_L, ...
        subjects(s).displayName);
end

%% Export four hip-angle workbooks
for s = 1:2
    rightFile = fullfile(c3dPath,sprintf('%s_%s_HipAngles_Right.xlsx', ...
        baseName,subjects(s).fileTag));
    leftFile = fullfile(c3dPath,sprintf('%s_%s_HipAngles_Left.xlsx', ...
        baseName,subjects(s).fileTag));

    writeHipWorkbook(rightFile,subjects(s).HipAngles_R);
    writeHipWorkbook(leftFile,subjects(s).HipAngles_L);

    disp([subjects(s).displayName,' right hip output: ',rightFile])
    disp([subjects(s).displayName,' left hip output: ',leftFile])
end

disp('Export complete: four Layton-compatible Excel files generated.')

%% Local functions
function prefixes = detectSubjectPrefixes(labels,markerDefs)
fields = fieldnames(markerDefs);
allAliases = {};
for k = 1:numel(fields)
    aliases = markerDefs.(fields{k});
    allAliases = [allAliases,cellfun(@normaliseBaseLabel,aliases, ...
        'UniformOutput',false)]; %#ok<AGROW>
end
allAliases = unique(allAliases);

prefixes = {};
for k = 1:numel(labels)
    [prefix,base] = splitMarkerLabel(labels{k});
    if ~isempty(prefix) && ismember(normaliseBaseLabel(base),allAliases)
        prefixes{end+1} = prefix; %#ok<AGROW>
    end
end
prefixes = unique(prefixes,'stable');
end

function [idx,selectedLabel] = findMarkerForSubject( ...
    labels,aliases,markerName,subjectPrefix)
subjectCandidates = [];
normalisedAliases = cellfun(@normaliseBaseLabel,aliases, ...
    'UniformOutput',false);

for k = 1:numel(labels)
    [prefix,base] = splitMarkerLabel(labels{k});
    if strcmpi(prefix,subjectPrefix) && ...
            ismember(normaliseBaseLabel(base),normalisedAliases)
        subjectCandidates(end+1) = k; %#ok<AGROW>
    end
end

if isempty(subjectCandidates)
    sameSubject = find(cellfun(@(label) ...
        strcmpi(getMarkerPrefix(label),subjectPrefix),labels));
    candidateLabels = labels(sameSubject);
    prompt = sprintf(['No automatic match was found for %s (%s).\n' ...
        'Select the correct marker manually, or press Cancel.'], ...
        markerName,subjectPrefix);
    [choice,ok] = listdlg('PromptString',prompt,'SelectionMode','single', ...
        'ListString',candidateLabels,'ListSize',[440 320]);
    if ok
        idx = sameSubject(choice);
        selectedLabel = labels{idx};
    else
        idx = NaN;
        selectedLabel = '';
    end
elseif numel(subjectCandidates) == 1
    idx = subjectCandidates(1);
    selectedLabel = labels{idx};
else
    candidateLabels = labels(subjectCandidates);
    prompt = sprintf(['Multiple matches were found for %s (%s).\n' ...
        'Select the measured marker to use.'],markerName,subjectPrefix);
    [choice,ok] = listdlg('PromptString',prompt,'SelectionMode','single', ...
        'ListString',candidateLabels,'ListSize',[440 220]);
    if ok
        idx = subjectCandidates(choice);
        selectedLabel = labels{idx};
    else
        idx = NaN;
        selectedLabel = '';
    end
end
end

function message = formatSelectionMessage(c3dFile,subject,fields)
lines = cell(numel(fields)+2,1);
lines{1} = sprintf('Selected C3D: %s',c3dFile);
lines{2} = sprintf('Subject prefix: %s\n',subject.prefix);
for k = 1:numel(fields)
    lines{k+2} = sprintf('%-5s -> marker %d: %s',fields{k}, ...
        subject.markerIdx.(fields{k}),subject.selectedLabels{k});
end
message = strjoin(lines,newline);
end

function [report,markerValid] = assessTrajectories( ...
    points,labels,markerIdx,fields,subjectName)
nFrames = size(points,3);
nMarkers = numel(fields);
subject = repmat(string(subjectName),nMarkers,1);
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

report = table(subject,markerNames,selectedLabels, ...
    repmat(nFrames,nMarkers,1),validFrames,missingFrames, ...
    completeness,longestGap,'VariableNames', ...
    {'Subject','Marker','SelectedLabel','TotalFrames','ValidFrames', ...
    'MissingFrames','CompletenessPercent','LongestMissingGapFrames'});
end

function [HipAngles_R,HipAngles_L] = computeHipAngles( ...
    points,markerIdx,markerValid,flexionCorrectionDeg, ...
    useFlexionCorrection,zeroToFirstFrame)
getTraj = @(idx) squeeze(points(1:3,idx,:))';
LFWT = getTraj(markerIdx.LFWT);
RFWT = getTraj(markerIdx.RFWT);
LBWT = getTraj(markerIdx.LBWT);
RBWT = getTraj(markerIdx.RBWT);
RTHI = getTraj(markerIdx.RTHI);
RKNE = getTraj(markerIdx.RKNE);
RANK = getTraj(markerIdx.RANK);
LTHI = getTraj(markerIdx.LTHI);
LKNE = getTraj(markerIdx.LKNE);
LANK = getTraj(markerIdx.LANK);

nFrames = size(LFWT,1);
HipAngles_R = NaN(nFrames,3);
HipAngles_L = NaN(nFrames,3);

for i = 1:nFrames
    pelvisValid = markerValid.LFWT(i) && markerValid.RFWT(i) && ...
        markerValid.LBWT(i) && markerValid.RBWT(i);
    if ~pelvisValid
        continue
    end

    xPelvis = RFWT(i,:) - LFWT(i,:);
    sacrum = (LBWT(i,:) + RBWT(i,:))/2;
    pelvisOrigin = (LFWT(i,:) + RFWT(i,:))/2;
    yTemporary = pelvisOrigin-sacrum;
    if norm(xPelvis) <= eps || norm(yTemporary) <= eps
        continue
    end

    xPelvis = xPelvis/norm(xPelvis);
    yTemporary = yTemporary/norm(yTemporary);
    zPelvis = cross(xPelvis,yTemporary);
    if norm(zPelvis) <= eps
        continue
    end
    zPelvis = zPelvis/norm(zPelvis);
    yPelvis = cross(zPelvis,xPelvis);
    yPelvis = yPelvis/norm(yPelvis);
    pelvisRotation = [xPelvis' yPelvis' zPelvis'];

    if markerValid.RTHI(i) && markerValid.RKNE(i) && markerValid.RANK(i)
        HipAngles_R(i,:) = calculateFrameAngles(pelvisRotation, ...
            RTHI(i,:),RKNE(i,:),RANK(i,:),flexionCorrectionDeg, ...
            useFlexionCorrection);
    end

    if markerValid.LTHI(i) && markerValid.LKNE(i) && markerValid.LANK(i)
        HipAngles_L(i,:) = calculateFrameAngles(pelvisRotation, ...
            LTHI(i,:),LKNE(i,:),LANK(i,:),flexionCorrectionDeg, ...
            useFlexionCorrection);
    end
end

for column = 1:3
    HipAngles_R(:,column) = unwrapWithNaNs(HipAngles_R(:,column));
    HipAngles_L(:,column) = unwrapWithNaNs(HipAngles_L(:,column));
end

if zeroToFirstFrame
    firstValidR = find(all(~isnan(HipAngles_R),2),1);
    firstValidL = find(all(~isnan(HipAngles_L),2),1);
    if ~isempty(firstValidR)
        HipAngles_R = HipAngles_R-HipAngles_R(firstValidR,:);
    end
    if ~isempty(firstValidL)
        HipAngles_L = HipAngles_L-HipAngles_L(firstValidL,:);
    end
end
end

function angles = calculateFrameAngles(pelvisRotation, ...
    thigh,knee,ankle,flexionCorrectionDeg,useFlexionCorrection)
angles = [NaN NaN NaN];
zFemur = knee-thigh;
if norm(zFemur) <= eps
    return
end
zFemur = zFemur/norm(zFemur);

temporary = ankle-knee;
xFemur = cross(temporary,zFemur);
if norm(xFemur) <= eps
    return
end
xFemur = xFemur/norm(xFemur);
yFemur = cross(zFemur,xFemur);
yFemur = yFemur/norm(yFemur);
femurRotation = [xFemur' yFemur' zFemur'];
hipRotation = pelvisRotation'*femurRotation;

flexion = atan2(hipRotation(3,2),hipRotation(3,3));
abduction = atan2(-hipRotation(3,1), ...
    sqrt(hipRotation(3,2)^2+hipRotation(3,3)^2));
rotation = atan2(hipRotation(2,1),hipRotation(1,1));
if useFlexionCorrection
    flexion = flexion-deg2rad(flexionCorrectionDeg);
end
angles = rad2deg([flexion abduction rotation]);
end

function plotHipAngles(rightAngles,leftAngles,subjectName)
plotNames = {'Hip Flexion / Extension','Hip Abduction / Adduction', ...
    'Hip Internal / External Rotation'};
for column = 1:3
    figure
    plot(rightAngles(:,column),'b','LineWidth',1.2)
    hold on
    plot(leftAngles(:,column),'r','LineWidth',1.2)
    legend('Right','Left')
    xlabel('Frame')
    ylabel('Angle (deg)')
    title([subjectName,' - ',plotNames{column}])
    grid on
end
end

function writeHipWorkbook(filename,angles)
writetable(array2table(angles(:,1)),filename,'Sheet','FlexExt');
writetable(array2table(angles(:,2)),filename,'Sheet','AbdAdd');
writetable(array2table(angles(:,3)),filename,'Sheet','IntExt');
end

function [prefix,base] = splitMarkerLabel(label)
label = strtrim(char(label));
colonPosition = find(label == ':',1,'last');
if isempty(colonPosition)
    prefix = '';
    base = label;
else
    prefix = label(1:colonPosition-1);
    base = label(colonPosition+1:end);
end
end

function prefix = getMarkerPrefix(label)
[prefix,~] = splitMarkerLabel(label);
end

function name = normaliseBaseLabel(label)
[~,name] = splitMarkerLabel(label);
name = upper(strtrim(name));
name = regexprep(name,'[^A-Z0-9]','');
end

function displayName = makeSubjectDisplayName(prefix,index)
lowerPrefix = lower(prefix);
if contains(lowerPrefix,'female')
    displayName = 'Female dancer';
elseif contains(lowerPrefix,'male')
    displayName = 'Male dancer';
else
    displayName = sprintf('Subject %d (%s)',index,prefix);
end
end

function tag = makeFileTag(displayName,index)
tag = regexprep(lower(displayName),'[^a-z0-9]+','_');
tag = regexprep(tag,'^_|_$','');
if isempty(tag)
    tag = sprintf('subject_%d',index);
end
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
