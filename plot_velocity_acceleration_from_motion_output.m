%% plot_velocity_acceleration_from_motion_output
% Plots hip angles, angular velocity and angular acceleration from a
% motion-path results workbook. Run the script and select an Excel file
% containing a FrameData sheet with the columns listed below. Three figures
% are displayed and saved as 300 dpi PNG files beside the workbook.
%
% Required workbook format:
%   Sheet: FrameData
%   Columns:
%     Time_sec
%     FlexExt_deg, AbdAdd_deg, IntExt_deg
%     Vel_FlexExt_deg_s, Vel_AbdAdd_deg_s, Vel_IntExt_deg_s
%     Acc_FlexExt_deg_s2, Acc_AbdAdd_deg_s2, Acc_IntExt_deg_s2

clear; clc; close all;

[fileName, folderPath] = uigetfile( ...
    {'*.xlsx;*.xls', 'Excel files (*.xlsx, *.xls)'}, ...
    'Select sampled complete motion-path output Excel file');

if isequal(fileName, 0)
    disp('No file selected. Script cancelled.');
    return;
end

excelFile = fullfile(folderPath, fileName);

try
    opts = detectImportOptions(excelFile, ...
        'Sheet', 'FrameData', ...
        'VariableNamingRule', 'preserve');
    data = readtable(excelFile, opts);
catch
    error('Could not read the FrameData sheet from the selected Excel file.');
end

requiredColumns = { ...
    'Time_sec', ...
    'FlexExt_deg', 'AbdAdd_deg', 'IntExt_deg', ...
    'Vel_FlexExt_deg_s', 'Vel_AbdAdd_deg_s', 'Vel_IntExt_deg_s', ...
    'Acc_FlexExt_deg_s2', 'Acc_AbdAdd_deg_s2', 'Acc_IntExt_deg_s2'};

missingColumns = setdiff(requiredColumns, data.Properties.VariableNames);
if ~isempty(missingColumns)
    error('Missing required columns in FrameData sheet: %s', strjoin(missingColumns, ', '));
end

timeSec = data.Time_sec;

angleData = [ ...
    data.FlexExt_deg, ...
    data.AbdAdd_deg, ...
    data.IntExt_deg];

velocityData = [ ...
    data.Vel_FlexExt_deg_s, ...
    data.Vel_AbdAdd_deg_s, ...
    data.Vel_IntExt_deg_s];

accelerationData = [ ...
    data.Acc_FlexExt_deg_s2, ...
    data.Acc_AbdAdd_deg_s2, ...
    data.Acc_IntExt_deg_s2];

rotationLabels = { ...
    'Flexion/Extension', ...
    'Abduction/Adduction', ...
    'Internal/External Rotation'};

lineColors = [ ...
    0.000, 0.447, 0.741; ...
    0.850, 0.325, 0.098; ...
    0.466, 0.674, 0.188];

[~, baseName, ~] = fileparts(fileName);
plotTitleName = strrep(baseName, '_', '\_');

%% Hip-angle plot
figure('Name', 'Hip Angles', 'Color', 'w');
hold on;
for i = 1:3
    plot(timeSec, angleData(:, i), ...
        'LineWidth', 1.8, ...
        'Color', lineColors(i, :));
end
hold off;
grid on;
box on;
xlabel('Time (s)', 'FontWeight', 'bold');
ylabel('Hip angle (deg)', 'FontWeight', 'bold');
title({'Hip Angles vs Time', plotTitleName}, 'Interpreter', 'tex');
legend(rotationLabels, 'Location', 'best');
set(gca, 'FontSize', 11);

angleFig = gcf;

%% Angular-velocity plot
figure('Name', 'Angular Velocity', 'Color', 'w');
hold on;
for i = 1:3
    plot(timeSec, velocityData(:, i), ...
        'LineWidth', 1.8, ...
        'Color', lineColors(i, :));
end
hold off;
grid on;
box on;
xlabel('Time (s)', 'FontWeight', 'bold');
ylabel('Angular velocity (deg/s)', 'FontWeight', 'bold');
title({'Angular Velocity vs Time', plotTitleName}, 'Interpreter', 'tex');
legend(rotationLabels, 'Location', 'best');
set(gca, 'FontSize', 11);

velocityFig = gcf;

%% Angular-acceleration plot
figure('Name', 'Angular Acceleration', 'Color', 'w');
hold on;
for i = 1:3
    plot(timeSec, accelerationData(:, i), ...
        'LineWidth', 1.8, ...
        'Color', lineColors(i, :));
end
hold off;
grid on;
box on;
xlabel('Time (s)', 'FontWeight', 'bold');
ylabel('Angular acceleration (deg/s^2)', 'FontWeight', 'bold');
title({'Angular Acceleration vs Time', plotTitleName}, 'Interpreter', 'tex');
legend(rotationLabels, 'Location', 'best');
set(gca, 'FontSize', 11);

accelerationFig = gcf;

%% Save PNG copies beside the selected Excel file
anglePng = fullfile(folderPath, [baseName '_hip_angle_plot.png']);
velocityPng = fullfile(folderPath, [baseName '_velocity_plot.png']);
accelerationPng = fullfile(folderPath, [baseName '_acceleration_plot.png']);

try
    exportgraphics(angleFig, anglePng, 'Resolution', 300);
    exportgraphics(velocityFig, velocityPng, 'Resolution', 300);
    exportgraphics(accelerationFig, accelerationPng, 'Resolution', 300);
catch
    saveas(angleFig, anglePng);
    saveas(velocityFig, velocityPng);
    saveas(accelerationFig, accelerationPng);
end

fprintf('Created hip angle plot: %s\n', anglePng);
fprintf('Created velocity plot: %s\n', velocityPng);
fprintf('Created acceleration plot: %s\n', accelerationPng);
