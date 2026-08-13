%% resampler
% Resamples three-direction hip-angle data to a user-selected number of
% points. Run the script, choose the trial folder and a hip-angle workbook
% containing FlexExt, AbdAdd and IntExt sheets, then define the timing and
% select continuous or repetitive processing. 

clear all; close all; clc

%% 1. Select trial folder and frame rate
folder = uigetdir('', 'Select trial/reference folder');
if isequal(folder, 0), return; end

[~, folderName] = fileparts(folder);
activityName = extractActivityName(folderName);

timingMode = questdlg('How should timing be defined for this dataset?', ...
    'Timing Input', ...
    'Frame rate (Hz)', 'Time step dt (sec)', 'Frame rate (Hz)');
if isempty(timingMode), return; end

if strcmpi(timingMode, 'Time step dt (sec)')
    answer = inputdlg('Enter time step dt between original samples (seconds):', ...
        'Time Step dt', 1, {'0.011089108911'});
    if isempty(answer), return; end
    dtOriginal = str2double(answer{1});
    if isnan(dtOriginal) || dtOriginal <= 0
        errordlg('Time step dt must be a positive number.', 'Invalid Time Step');
        return;
    end
    fs = 1 / dtOriginal;
else
    fs = detectFrameRate(folderName);
    if isnan(fs)
        answer = inputdlg('Frame rate not found in folder name. Enter frame rate (Hz):', ...
            'Frame Rate', 1, {'120'});
        if isempty(answer), return; end
        fs = str2double(answer{1});
    end

    if isnan(fs) || fs <= 0
        errordlg('Frame rate must be a positive number.', 'Invalid Frame Rate');
        return;
    end
    dtOriginal = 1 / fs;
end

%% 2. Select and load hip-angle Excel file
h = msgbox('Select the Excel file with hip angle data from c3d_excel.m.');
uiwait(h);
[file, pathname] = uigetfile(fullfile(folder, '*.xlsx'), 'Select hip angle Excel file');
if isequal(file, 0), return; end

filepath = fullfile(pathname, file);
[FlexExt, AbdAdd, IntExt] = readHipAngleSheets(filepath);
N = length(FlexExt);

if N < 2
    errordlg('The selected file needs at least two numeric samples.', 'Not Enough Data');
    return;
end

frames = (1:N)';
time = (frames - 1) * dtOriginal;
totalDuration = time(end);

%% 3. Choose motion type and output sample count
motionType = questdlg('What type of motion is this?', ...
    'Motion Type', ...
    'Continuous', 'Repetitive', 'Repetitive');
if isempty(motionType), return; end

defaultSamples = '100';
answer = inputdlg('How many resampled points do you want?', ...
    'Output Samples', 1, {defaultSamples});
if isempty(answer), return; end
targetSamples = round(str2double(answer{1}));

if isnan(targetSamples) || targetSamples < 2
    errordlg('Number of resampled points must be at least 2.', 'Invalid Sample Count');
    return;
end

%% 4. Select the source data range
if strcmpi(motionType, 'Continuous')
    startFrame = 1;
    endFrame = N;

    showOverviewPlot(frames, time, FlexExt, AbdAdd, IntExt, fs, file, ...
        startFrame, endFrame, 'Continuous motion: full file will be resampled');

    confirmMsg = sprintf([ ...
        'Continuous motion selected.\n\n' ...
        'The full file will be resampled:\n' ...
        'Time range: %.3f s to %.3f s\n' ...
        'Output points: %d\n\n' ...
        'Continue?'], ...
        time(startFrame), time(endFrame), targetSamples);
    choice = questdlg(confirmMsg, 'Confirm Continuous Resampling', ...
        'Continue', 'Cancel', 'Continue');
    if ~strcmp(choice, 'Continue'), return; end
else
    [startFrame, endFrame] = selectRepetitiveRange(frames, time, FlexExt, AbdAdd, IntExt, fs, file);
    if isempty(startFrame) || isempty(endFrame), return; end
end

%% 5. Resample selected data
FlexExt_selected = FlexExt(startFrame:endFrame);
AbdAdd_selected  = AbdAdd(startFrame:endFrame);
IntExt_selected  = IntExt(startFrame:endFrame);
nSelected = length(FlexExt_selected);

xin = linspace(0, 100, nSelected);
xq = linspace(0, 100, targetSamples)';

method = 'spline';
FlexExt_resampled = interp1(xin, FlexExt_selected, xq, method);
AbdAdd_resampled  = interp1(xin, AbdAdd_selected,  xq, method);
IntExt_resampled  = interp1(xin, IntExt_selected,  xq, method);

% Inclusive frame ranges have nSelected - 1 time intervals.
selectedDuration = (endFrame - startFrame) * dtOriginal;
dt_resampled = selectedDuration / (targetSamples - 1);

%% 6. Preview and export
figPreview = figure('Name', 'Resampled Hip Angles Preview', ...
    'NumberTitle', 'off', 'Position', [100 70 1100 650]);
previewX = linspace(0, 100, targetSamples)';

subplot(3,1,1);
plot(previewX, FlexExt_resampled, 'b', 'LineWidth', 1.3); grid on;
ylabel('Angle (deg)');
title('Flexion(+) / Extension(-)');

subplot(3,1,2);
plot(previewX, AbdAdd_resampled, 'r', 'LineWidth', 1.3); grid on;
ylabel('Angle (deg)');
title('Abduction(+) / Adduction(-)');

subplot(3,1,3);
plot(previewX, IntExt_resampled, 'g', 'LineWidth', 1.3); grid on;
ylabel('Angle (deg)');
xlabel('Motion cycle / selected motion (%)');
title('Internal(+) / External(-) Rotation');

sgtitle(sprintf('%s | %s | %.3f s to %.3f s | %d points', ...
    file, motionType, time(startFrame), time(endFrame), targetSamples), ...
    'Interpreter', 'none');

choice = questdlg('Export this resampled file?', 'Export', ...
    'Export', 'Cancel', 'Export');
if ~strcmp(choice, 'Export')
    if ishandle(figPreview), close(figPreview); end
    return;
end

[~, origName] = fileparts(file);
outputBaseName = buildOutputBaseName(origName, activityName);
outFile = fullfile(folder, sprintf('%s_sampled%d.xlsx', outputBaseName, targetSamples));

if isfile(outFile)
    overwrite = questdlg(sprintf('This file already exists:\n%s\n\nOverwrite it?', outFile), ...
        'Overwrite Existing File', 'Overwrite', 'Cancel', 'Cancel');
    if ~strcmp(overwrite, 'Overwrite'), return; end
    delete(outFile);
end

xlswrite(outFile, FlexExt_resampled, 'FlexExt', 'A1');
xlswrite(outFile, AbdAdd_resampled,  'AbdAdd',  'A1');
xlswrite(outFile, IntExt_resampled,  'IntExt',  'A1');

% Metadata!A1 remains numeric so the motion-path script can read it directly.
xlswrite(outFile, dt_resampled, 'Metadata', 'A1');
xlswrite(outFile, {'dt_seconds_between_resampled_points'}, 'Metadata', 'B1');
xlswrite(outFile, fs, 'Metadata', 'A2');
xlswrite(outFile, {'original_frame_rate_hz'}, 'Metadata', 'B2');
xlswrite(outFile, time(startFrame), 'Metadata', 'A3');
xlswrite(outFile, {'start_time_seconds'}, 'Metadata', 'B3');
xlswrite(outFile, time(endFrame), 'Metadata', 'A4');
xlswrite(outFile, {'end_time_seconds'}, 'Metadata', 'B4');
xlswrite(outFile, targetSamples, 'Metadata', 'A5');
xlswrite(outFile, {'resampled_points'}, 'Metadata', 'B5');
xlswrite(outFile, {motionType}, 'Metadata', 'A6');
xlswrite(outFile, {'motion_type'}, 'Metadata', 'B6');
xlswrite(outFile, {activityName}, 'Metadata', 'A7');
xlswrite(outFile, {'activity_name'}, 'Metadata', 'B7');
xlswrite(outFile, {timingMode}, 'Metadata', 'A8');
xlswrite(outFile, {'timing_input_mode'}, 'Metadata', 'B8');
xlswrite(outFile, dtOriginal, 'Metadata', 'A9');
xlswrite(outFile, {'original_dt_seconds'}, 'Metadata', 'B9');

removeDefaultExcelSheets(outFile);

msgbox(sprintf([ ...
    'Export complete.\n\n' ...
    'Motion type: %s\n' ...
    'Activity: %s\n' ...
    'Timing input: %s\n' ...
    'Time range: %.3f s to %.3f s\n' ...
    'Selected duration: %.3f s\n' ...
    'Output points: %d\n' ...
    'dt: %.6f s\n\n' ...
    'Saved to:\n%s'], ...
    motionType, activityName, timingMode, time(startFrame), time(endFrame), ...
    selectedDuration, targetSamples, dt_resampled, outFile), 'Done');

%% Local functions
function fs = detectFrameRate(folderName)
    tokens = regexp(folderName, '(\d+)\s*$', 'tokens');
    if isempty(tokens)
        fs = NaN;
    else
        fs = str2double(tokens{1}{1});
    end
end

function activityName = extractActivityName(folderName)
    activityName = regexprep(folderName, '[_\s]*\d+\s*$', '');
    activityName = regexprep(activityName, '^\d+[_\s]+\d+[_\s]*', '');
    activityName = strtrim(activityName);
    activityName = regexprep(activityName, '\s+', '_');
    activityName = regexprep(activityName, '[^\w-]', '_');
    activityName = regexprep(activityName, '_+', '_');
    activityName = regexprep(activityName, '^_|_$', '');
    if isempty(activityName)
        activityName = 'activity';
    end
end

function outputBaseName = buildOutputBaseName(origName, activityName)
    if contains(lower(origName), lower(activityName))
        outputBaseName = origName;
    else
        outputBaseName = sprintf('%s_%s', origName, activityName);
    end
end

function [FlexExt, AbdAdd, IntExt] = readHipAngleSheets(filepath)
    FlexExt = xlsread(filepath, 'FlexExt', 'A:A');
    AbdAdd  = xlsread(filepath, 'AbdAdd',  'A:A');
    IntExt  = xlsread(filepath, 'IntExt',  'A:A');

    FlexExt = FlexExt(:);
    AbdAdd = AbdAdd(:);
    IntExt = IntExt(:);

    minLength = min([length(FlexExt), length(AbdAdd), length(IntExt)]);
    FlexExt = FlexExt(1:minLength);
    AbdAdd = AbdAdd(1:minLength);
    IntExt = IntExt(1:minLength);

    validRows = ~(isnan(FlexExt) | isnan(AbdAdd) | isnan(IntExt));
    FlexExt = FlexExt(validRows);
    AbdAdd = AbdAdd(validRows);
    IntExt = IntExt(validRows);
end

function [startFrame, endFrame] = selectRepetitiveRange(frames, time, FlexExt, AbdAdd, IntExt, fs, file)
    N = length(frames);
    startFrame = [];
    endFrame = [];

    answer = inputdlg({ ...
        sprintf('Approximate start time in seconds (0 to %.3f):', time(end)), ...
        sprintf('Approximate end time in seconds (0 to %.3f):', time(end))}, ...
        'Approximate Repetitive Motion Range', 1, {'0', sprintf('%.3f', time(end))});
    if isempty(answer), return; end

    startFrame = secondsToFrame(str2double(answer{1}), fs, N);
    endFrame = secondsToFrame(str2double(answer{2}), fs, N);
    [startFrame, endFrame] = orderFrames(startFrame, endFrame);

    fig = showOverviewPlot(frames, time, FlexExt, AbdAdd, IntExt, fs, file, ...
        startFrame, endFrame, 'Repetitive motion: refine one full cycle');

    confirmed = false;
    while ~confirmed
        choice = questdlg([ ...
            'Use the yellow region as the selected cycle, click a new start/end time, ' ...
            'or type exact seconds?'], ...
            'Refine Selection', ...
            'Use Current', 'Click Start/End', 'Type Seconds', 'Use Current');

        if isempty(choice)
            startFrame = [];
            endFrame = [];
            return;
        elseif strcmp(choice, 'Click Start/End')
            figure(fig);
            [clickedX, ~] = ginput(2);
            if length(clickedX) < 2, continue; end
            startFrame = secondsToFrame(clickedX(1), fs, N);
            endFrame = secondsToFrame(clickedX(2), fs, N);
            [startFrame, endFrame] = orderFrames(startFrame, endFrame);
            updateSelectionPatch(fig, time(startFrame), time(endFrame));
        elseif strcmp(choice, 'Type Seconds')
            answer = inputdlg({ ...
                sprintf('Start time in seconds [current %.3f]:', time(startFrame)), ...
                sprintf('End time in seconds [current %.3f]:', time(endFrame))}, ...
                'Exact Cycle Timing', 1, ...
                {sprintf('%.3f', time(startFrame)), sprintf('%.3f', time(endFrame))});
            if isempty(answer), continue; end
            startFrame = secondsToFrame(str2double(answer{1}), fs, N);
            endFrame = secondsToFrame(str2double(answer{2}), fs, N);
            [startFrame, endFrame] = orderFrames(startFrame, endFrame);
            updateSelectionPatch(fig, time(startFrame), time(endFrame));
        end

        confirm = questdlg(sprintf([ ...
            'Selected cycle:\n' ...
            'Time: %.3f s to %.3f s\n' ...
            'Duration: %.3f s\n\n' ...
            'Confirm this range?'], ...
            time(startFrame), time(endFrame), ...
            (endFrame - startFrame) / fs), ...
            'Confirm Cycle', 'Confirm', 'Keep Editing', 'Confirm');
        confirmed = strcmp(confirm, 'Confirm');
    end
end

function frame = secondsToFrame(secondsValue, fs, N)
    if isnan(secondsValue), secondsValue = 0; end
    frame = round(secondsValue * fs) + 1;
    frame = max(1, min(N, frame));
end

function [startFrame, endFrame] = orderFrames(startFrame, endFrame)
    ordered = sort([startFrame, endFrame]);
    startFrame = ordered(1);
    endFrame = ordered(2);
end

function fig = showOverviewPlot(frames, time, FlexExt, AbdAdd, IntExt, fs, file, startFrame, endFrame, plotTitle)
    fig = figure('Name', 'Hip Angles - Select Motion Range', ...
        'NumberTitle', 'off', 'Position', [80 60 1200 720]);

    ax1 = subplot(3,1,1);
    plot(time, FlexExt, 'b', 'LineWidth', 1.2); grid on; xlim([0 time(end)]);
    ylabel('Angle (deg)');
    title('Flexion(+) / Extension(-)');

    ax2 = subplot(3,1,2);
    plot(time, AbdAdd, 'r', 'LineWidth', 1.2); grid on; xlim([0 time(end)]);
    ylabel('Angle (deg)');
    title('Abduction(+) / Adduction(-)');

    ax3 = subplot(3,1,3);
    plot(time, IntExt, 'g', 'LineWidth', 1.2); grid on; xlim([0 time(end)]);
    ylabel('Angle (deg)');
    xlabel(sprintf('Time (sec) [%g Hz source data, total %.3f sec]', fs, time(end)));
    title('Internal(+) / External(-) Rotation');

    linkaxes([ax1, ax2, ax3], 'x');
    setappdata(fig, 'SelectionAxes', [ax1 ax2 ax3]);
    updateSelectionPatch(fig, time(startFrame), time(endFrame));

    sgtitle(sprintf('%s | %s', file, plotTitle), 'Interpreter', 'none');
end

function updateSelectionPatch(fig, startTime, endTime)
    axesList = getappdata(fig, 'SelectionAxes');
    for ax = axesList
        delete(findobj(ax, 'Tag', 'selected_range_patch'));
        hold(ax, 'on');
        yl = ylim(ax);
        patch(ax, [startTime endTime endTime startTime], ...
            [yl(1) yl(1) yl(2) yl(2)], [1 1 0.35], ...
            'FaceAlpha', 0.25, 'EdgeColor', [0.85 0.65 0], ...
            'LineWidth', 1.5, 'Tag', 'selected_range_patch');
        hold(ax, 'off');
    end
end

function removeDefaultExcelSheets(outFile)
    try
        excel = actxserver('Excel.Application');
        excel.Visible = false;
        excel.DisplayAlerts = false;
        wb = excel.Workbooks.Open(outFile);
        for sheetName = {'Sheet1','Sheet2','Sheet3'}
            try
                wb.Sheets.Item(sheetName{1}).Delete();
            catch
            end
        end
        wb.Save();
        wb.Close();
        excel.Quit();
    catch
    end
end
