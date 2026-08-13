%% motion_path_complete_sample
% Generates 20-point femoral-head motion paths and calculates sliding
% distance, aspect ratio, angular velocity and angular acceleration from a
% resampled hip-angle workbook. Run the script and select an Excel workbook
% containing FlexExt, AbdAdd, IntExt and Metadata sheets. Metadata!A1 must
% contain the resampled time step, and RotateXYV.m must be on the MATLAB
% path. The script displays motion-path and dynamic plots and exports
% FrameData and PointMetrics sheets beside the selected workbook.
clear all
close all
clc

%% Select sampled hip-angle workbook
a = msgbox('Choose a sampled Excel file ');
uiwait(a)
[file,pathname]=uigetfile('*.xlsx');
spec_dir2=[pathname file];
inputPathname = pathname;

% Metadata!A1 stores the time step between resampled points.
try
    dt = xlsread(spec_dir2,'Metadata','A1');
catch
    error(['No Metadata sheet found in this file.\n' ...
           'This code is for sampled data only (output of gait_sampler.m).\n' ...
           'For raw data use motion_path_c3d_asp_vel_acc.m instead.']);
end

%% Read hip-angle data
FlexExt = xlsread(spec_dir2,'FlexExt','A:A');
AbdAdd  = xlsread(spec_dir2,'AbdAdd','A:A');
IntExt  = xlsread(spec_dir2,'IntExt','A:A');
L_data  = [FlexExt AbdAdd IntExt];

filename = regexprep(file,'.xlsx','');
activityName = extractActivityName(inputPathname, filename);

%% Optional comparison dataset
an = questdlg('Would you like to compare to another data set?','Comparison to other data','Yes','No','Yes');
TN = strcmpi(an, 'Yes');
if TN == 1
    b = msgbox('Select a Excel file with hip motion data');
    uiwait(b)
    [file,pathname]=uigetfile('*.xlsx');
    spec_dir2=[pathname file];
    FlexExt = xlsread(spec_dir2,'FlexExt','A:A');
    AbdAdd  = xlsread(spec_dir2,'AbdAdd','A:A');
    IntExt  = xlsread(spec_dir2,'IntExt','A:A');
    N_data  = [FlexExt AbdAdd IntExt];
end

%% Build time and sample arrays
L = length(L_data);
time_sec = (0:L-1)' * dt;

gait = zeros(L,1);
for i =1:L
    gait(i) = i;
end

if TN == 1
    N = length(N_data);
    rightlength = isequal(N,L);
    if rightlength == 0
        h = warndlg('Normal data is not the same length as LLI data, Normal data will not be analysed');
        uiwait(h);
        TN = 0;
    end
end

%% Plot hip angles
figure(1);
plot(time_sec,L_data(:,1));
if TN == 1
    hold on
    plot(time_sec,N_data(:,1),'--k');
    legend('Data set 1', 'Data set 2');
    xlim([0,time_sec(end)]);
end
xlabel('Time (sec)');
ylabel('Angle (Â°)');
title('Hip Flexion(+)-Extension');

figure(2);
plot(time_sec,L_data(:,2));
if TN == 1
    hold on
    plot(time_sec,N_data(:,2),'--k');
    legend('Data set 1', 'Data set 2');
    xlim([0,time_sec(end)]);
end
xlabel('Time (sec)');
ylabel('Angle (Â°)');
title(' Hip Abduction(+)-Adduction(-) ');

figure(3);
plot(time_sec,L_data(:,3));
if TN == 1
    hold on
    plot(time_sec,N_data(:,3),'-k');
    legend('Data set 1', 'Data set 2');
    xlim([0,time_sec(end)]);
end
xlabel('Time (sec)');
ylabel('Angle (Â°)');
title(' Hip Internal(+)-External(-)Rotation ');

%% Calculate hip-angle ranges
MaxL(1) = max(L_data(:,1));
MaxL(2) = max(L_data(:,2));
MaxL(3) = max(L_data(:,3));
MinL(1) = min(L_data(:,1));
MinL(2) = min(L_data(:,2));
MinL(3) = min(L_data(:,3));
RangeL(1) = MaxL(1)-MinL(1);
RangeL(2) = MaxL(2)-MinL(2);
RangeL(3) = MaxL(3)-MinL(3);

%% Set femoral-head and cup parameters
prompt = {'Radius of Femoral head:','Coverage Angle(degrees):','Flexion correction (degrees):','Cup inclination angle adduction (degrees):'};
dlg_title = 'Input for femoral head details';
num_lines = 1;
def = {'14','180','45','45'};
answer = inputdlg(prompt,dlg_title,num_lines,def);
Rad = str2num(answer{1});
cov = str2num(answer{2});
CA(1) = str2num(answer{3});
CA(2) = str2num(answer{4});

%% Convert hip rotations to radians
L_data_rad = L_data*pi/180;
L_rad(:,1) = L_data_rad(:,1)-CA(1)*pi/180;
L_rad(:,2) = L_data_rad(:,2);
L_rad(:,3) = L_data_rad(:,3);

if TN ==1
    N_data_rad = N_data*pi/180;
    N_rad(:,1) = N_data_rad(:,1)-CA(1)*pi/180;
    N_rad(:,2) = N_data_rad(:,2);
    N_rad(:,3) = N_data_rad(:,3);
end

NPoints = 20;
pointsx = 10;
pointsy = 10;
anglex = 180/(pointsx-1);
angley = 180/(pointsy-1);

%% Define virtual femoral-head points
P = zeros(NPoints,3);

for i=1:pointsx
    P(i,1) = Rad*cos((i-1)*anglex*pi()/180)*-1;
    P(i,2) = 0;
    P(i,3) = Rad*sin((i-1)*anglex*pi()/180);
    [P(i,1),P(i,2),P(i,3)] = RotateXYV(P(i,1),P(i,2),P(i,3),0,-CA(2)*pi/180,0);
end
for i=(pointsx+1):(pointsx+pointsy)
    P(i,1) = 0;
    P(i,2) = Rad*cos((i-11)*angley*pi()/180)*-1;
    P(i,3) = Rad*sin((i-11)*angley*pi()/180);
    [P(i,1),P(i,2),P(i,3)] = RotateXYV(P(i,1),P(i,2),P(i,3),0,-CA(2)*pi/180,0);
end

%% Initialise femoral-head geometry
P_rad = zeros(NPoints,L,3);
[X,Y,Z] = sphere(14);
Xi = zeros(15,15,L);
Yi = zeros(15,15,L);
Zi = zeros(15,15,L);
for i=1:L
    Xi(:,:,i)=X*Rad;
    Yi(:,:,i)=Y*Rad;
    Zi(:,:,i)=Z*Rad;
end

xcup = Rad*X(8:end,:);
ycup = Rad*Y(8:end,:);
zcup = Rad*Z(8:end,:);
for curve=1:8
    for curve2 = 1:15
        [xcup(curve,curve2),ycup(curve,curve2),zcup(curve,curve2)] = RotateXYV(xcup(curve,curve2),ycup(curve,curve2),zcup(curve,curve2),0,-CA(2)*pi/180,0);
    end
end

if TN ==1
    P_Nrad = zeros(NPoints,L,3);
end

for i = 1:L
    for k = 1:NPoints
        [x,y,z] = RotateXYV(P(k,1),P(k,2),P(k,3),L_rad(i,1),L_rad(i,2),L_rad(i,3));
        PRAD(k,i,:) = [x,y,z];
    end
    for curve = 1:15
        for curve2 =1:15
            [Xi(curve2,curve,i),Yi(curve2,curve,i),Zi(curve2,curve,i)] = RotateXYV(Xi(curve2,curve,i),Yi(curve2,curve,i),Zi(curve2,curve,i),L_rad(i,1),L_rad(i,2),L_rad(i,3));
        end
    end
    vector=[Xi(15,1,i)-Xi(1,1,i),Yi(15,1,i)-Yi(1,1,i),Zi(15,1,i)-Zi(1,1,i)];
    vector=vector/2;
    for le = 1:2
        femurx(i,le)=vector(1)*-le;
        femury(i,le)=vector(2)*-le;
        femurz(i,le)=vector(3)*-le;
    end
end

if TN ==1
    for i = 1:L
        for k = 1:NPoints
            [x,y,z] = RotateXYV(P(k,1),P(k,2),P(k,3),N_rad(i,1),N_rad(i,2),N_rad(i,3));
            P_Nrad(k,i,:) = [x,y,z];
        end
    end
end

more = questdlg('Would you like to remove data outside cup area?','Remove rest of Femoral head','Yes','No','Yes');
CHO = strcmpi(more,'Yes');
[planeX,planeY,planeZ] = RotateXYV(0,0,1,0,-CA(2)*pi/180,0);

%% Plot and animate 3D motion paths
figure(4);
hold on
axis([-Rad*1.5, Rad*1.5, -Rad*1.5, Rad*1.5,-Rad*1.5, Rad]);
for i=1:NPoints
    if CHO==1
        for j=1:NPoints
            plotok = 1;
            for l=1:L
                if planeX*PRAD(j,l,1)+planeY*PRAD(j,l,2)+planeZ*PRAD(j,l,3)<0
                    plotok = 0;
                end
            end
            if plotok==1
                plot3(PRAD(j,:,1),PRAD(j,:,2),PRAD(j,:,3),'-b','linewidth',1.1,'Clipping','on');
            end
        end
    else
        plot3(PRAD(i,:,1),PRAD(i,:,2),PRAD(i,:,3),'-b','linewidth',1.1,'Clipping','on');
    end
end

[X2,Y2] = meshgrid(-Rad:2:Rad, -Rad:2:Rad);
Z2=zeros(Rad+1);
for i=1:Rad+1
    for j=1:Rad+1
        [X2(i,j),Y2(i,j),Z2(i,j)] = RotateXYV(X2(i,j),Y2(i,j),Z2(i,j),0,-CA(2)*pi/180,0);
    end
end
surf(X2,Y2,Z2,'EdgeColor','none');

if TN == 1
    for i=1:NPoints
        plot3(P_Nrad(i,:,1),P_Nrad(i,:,2),P_Nrad(i,:,3),'-k','linewidth',1,'Clipping','on')
    end
end
surf(xcup,ycup,zcup,'EdgeColor','none');
hidden off
grid on
alpha(.5)
colormap([0.8 0.8 0.8])
xlabel('x:Axial Plane');
ylabel('y:Sagittal Plane');
zlabel('z:Coronal Plane');
view(-18,18);

for i=1:L
    for j=1:NPoints
        f(j)=plot3(PRAD(j,i,1),PRAD(j,i,2),PRAD(j,i,3),'ro','MarkerFaceColor','r','Clipping','on');
    end
    h(1)=surf(Xi(:,:,i),Yi(:,:,i),Zi(:,:,i),'FaceAlpha','0.1','EdgeAlpha','0.5','Clipping','on');
    h(2)=plot3(femurx(i,:),femury(i,:),femurz(i,:),'Clipping','on','linewidth',5,'color',[0,0,0,0.5]);
    pause(0.125);
    for j=1:length(h)
        delete(h(j));
    end
    for j=1:length(f)
        delete(f(j));
    end
end
hold off
view(0,90);

%% Calculate spherical-arc sliding distance
% Consecutive positions are joined by their spherical arc length.
s = zeros(NPoints,1);
for k = 1:NPoints
    for i = 1:L-1
        dotVal = PRAD(k,i,1)*PRAD(k,i+1,1) + ...
                 PRAD(k,i,2)*PRAD(k,i+1,2) + ...
                 PRAD(k,i,3)*PRAD(k,i+1,3);
        cosTheta = max(-1, min(1, dotVal/(Rad^2)));
        dtheta = acos(cosTheta);
        s(k) = s(k) + dtheta*Rad;
    end
end
averageS = mean(s);

%% Identify points outside cup coverage
h = 1;
for k=1:NPoints
    for i = 1:L
        if PRAD(k,i,1)*planeX+PRAD(k,i,2)*planeY+planeZ*PRAD(k,i,3) < 0
            alc(h,1)=k;
            alc(h,2)=i;
            h = h+1;
        end
    end
end

%% Optional contact-area analysis
an = questdlg('Would you like to input a load data file for contact area analysis? ','Use of load data','Yes','No','Yes');
CAA = strcmpi(an, 'Yes');
if CAA == 1
    a = msgbox('Choose a load file input for contact area analysis.');
    uiwait(a)
    [file,pathname]=uigetfile('*.xlsx');
    spec_dir2=[pathname file];
    [load_data,info]= xlsread(spec_dir2,'A:C');
    for i = 1:length(load_data)
        resload(i) = sqrt(load_data(i,1)^2+load_data(i,2)^2+load_data(i,3)^2);
    end
    Rh = Rad;
    Rc = Rad+0.25;
    Modh = 210000;
    Modc = 700;
    v1 = 0.3;
    v2 = 0.46;
    ER = (Rh*Rc)/(Rc-Rh);
    EMod = 1/((1-v1^2)/Modh + (1-v2^2)/Modc);
    L_load = length(load_data);
    for i = 1:L_load
        A(i) = ((3*resload(i)*ER)/(4*EMod))^(1/3);
        Area(i) = pi()*A(i)^2;
    end
    prompt = {'Percentage magnification of contact area (for ease of visualisation of graph)(between 1-100%):'};
    dlg_title = 'Magnification';
    num_lines = 1;
    def = {'10'};
    answer = inputdlg(prompt,dlg_title,num_lines,def);
    if isempty(answer)
        Mag = 10;
    else
        Mag = str2num(answer{1});
    end
    mag = Mag/100;
    Prad = squeeze(PRAD(5,:,:))';
    j=1;
    for i=1:10:min(91,size(Prad,1))
        con_rad(j) = A(i);
        con_x(j) = Prad(i,1);
        con_y(j) = Prad(i,2);
        con_z(j) = Prad(i,3);
        j = j+1;
    end
    figure(6);
    plot3(Prad(:,1),Prad(:,2),Prad(:,3),'-k','linewidth',1.1)
    hold on
    [X, Y, Z] = sphere(14);
    for ii = 1:length(con_rad)
        Sx = X*con_rad(ii)*mag;
        Sy = Y*con_rad(ii)*mag;
        Sz = Z*con_rad(ii)*mag;
        surf(Sx+con_x(ii),Sy+con_y(ii),Sz+con_z(ii),'EdgeColor','none')
        plot3(con_x(ii),con_y(ii),con_z(ii),'-o','MarkerEdgeColor','k','MarkerFaceColor','k','MarkerSize',3)
    end
    xlabel('x: Flexion/Extension')
    ylabel('y: Abduction/Adduction')
    title('Contact Area at Ten Intervals during one Gait Cycle for Point Five on the Femoral Head')
    var = num2str(mag*100);
    text(-6,4,['Magnification Factor of contact areas:' var '%']);
    hidden off
    grid on
    alpha(.3)
    colormap([0.8 0.8 0.8])
    axis([-7 7 -5 5 0 Rad])
    view([0 0 1]);
    hold off
end

%% Calculate aspect ratios
% Aspect ratio is the major path dimension divided by its perpendicular width.
AR = zeros(NPoints,1);
AR_height = zeros(NPoints,1);
AR_width = zeros(NPoints,1);

for k = 1:NPoints
    Prad_k = squeeze(PRAD(k,:,:));   % Samples-by-coordinate matrix.

    maxDist = 0;
    p1 = 1;
    p2 = 2;
    for i = 1:size(Prad_k,1)
        for j = i+1:size(Prad_k,1)
            d = norm(Prad_k(j,:) - Prad_k(i,:));
            if d > maxDist
                maxDist = d;
                p1 = i;
                p2 = j;
            end
        end
    end

    longVec = Prad_k(p2,:) - Prad_k(p1,:);
    if norm(longVec) > 0
        longUnit = longVec / norm(longVec);

        centred = Prad_k - mean(Prad_k,1);
        longProj = centred * longUnit';
        residual = centred - longProj * longUnit;

        [~,~,V] = svd(residual,'econ');
        perpUnit = V(:,1);
        perpProj = centred * perpUnit;

        AR_height(k) = max(longProj) - min(longProj);
        AR_width(k)  = max(perpProj) - min(perpProj);

        if AR_width(k) > 0
            AR(k) = AR_height(k) / AR_width(k);
        else
            AR(k) = NaN;
        end
    else
        AR(k) = NaN;
    end
end

validAR = AR(~isnan(AR));
avg = mean(validAR);
min_AR = min(validAR);
max_AR = max(validAR);

message = sprintf('The Mean Aspect Ratio:%0.3f\nThe Minimum Aspect Ratio:%0.3f\nThe Maximum Aspect Ratio:%0.3f\n', avg, min_AR, max_AR);
h = msgbox(message,'Aspect Ratio Results');

%% Calculate angular velocity and acceleration
% First differences use the time step read from the workbook.
% The first sample has no previous sample, so its velocity is undefined.
Vel_FlexExt = [NaN; diff(L_data(:,1)) / dt];
Vel_AbdAdd  = [NaN; diff(L_data(:,2)) / dt];
Vel_IntExt  = [NaN; diff(L_data(:,3)) / dt];

% Acceleration is the first difference of velocity, so the first two
% samples are undefined.
Acc_FlexExt = [NaN; diff(Vel_FlexExt) / dt];
Acc_AbdAdd  = [NaN; diff(Vel_AbdAdd) / dt];
Acc_IntExt  = [NaN; diff(Vel_IntExt) / dt];

%% Create time-based results table
FrameDataTable = table(gait, time_sec, ...
    L_data(:,1), L_data(:,2), L_data(:,3), ...
    Vel_FlexExt, Vel_AbdAdd, Vel_IntExt, ...
    Acc_FlexExt, Acc_AbdAdd, Acc_IntExt, ...
    'VariableNames', {'SampleNumber','Time_sec', ...
    'FlexExt_deg','AbdAdd_deg','IntExt_deg', ...
    'Vel_FlexExt_deg_s','Vel_AbdAdd_deg_s','Vel_IntExt_deg_s', ...
    'Acc_FlexExt_deg_s2','Acc_AbdAdd_deg_s2','Acc_IntExt_deg_s2'});

%% Create point-based results table
PointNumber = (1:NPoints)';
PointMetricsTable = table(PointNumber, s, AR, ...
    'VariableNames', {'PointNumber','SlidingDistance','AspectRatio'});

%% Write results to Excel
outputBaseName = buildOutputBaseName(filename, activityName);
outFile = fullfile(inputPathname, [outputBaseName '_validation_velocity_acceleration.xlsx']);

if isfile(outFile)
    delete(outFile);
end

writetable(FrameDataTable, outFile, ...
    'Sheet', 'FrameData', ...
    'WriteMode', 'overwritesheet');

writetable(PointMetricsTable, outFile, ...
    'Sheet', 'PointMetrics', ...
    'WriteMode', 'overwritesheet');

%% Plot angular velocity
figure(7)
plot(time_sec, Vel_FlexExt, 'b', 'LineWidth', 1.2)
hold on
plot(time_sec, Vel_AbdAdd, 'r', 'LineWidth', 1.2)
plot(time_sec, Vel_IntExt, 'g', 'LineWidth', 1.2)
grid on
xlabel('Time (sec)')
ylabel('Angular Velocity (Â°/s)')
title('Hip Angular Velocity')
legend('Flexion/Extension','Abduction/Adduction','Internal/External')
hold off

%% Plot angular acceleration
figure(8)
plot(time_sec, Acc_FlexExt, 'b', 'LineWidth', 1.2)
hold on
plot(time_sec, Acc_AbdAdd, 'r', 'LineWidth', 1.2)
plot(time_sec, Acc_IntExt, 'g', 'LineWidth', 1.2)
grid on
xlabel('Time (sec)')
ylabel('Angular Acceleration (Â°/s^2)')
title('Hip Angular Acceleration')
legend('Flexion/Extension','Abduction/Adduction','Internal/External')
hold off

%% Optional MATLAB workspace tables
SummaryTable_FrameData = FrameDataTable;
SummaryTable_PointMetrics = PointMetricsTable;

%% Local functions
function activityName = extractActivityName(inputPathname, filename)
    inputPathname = regexprep(inputPathname, '[\\/]+$', '');
    [~, folderName] = fileparts(inputPathname);
    activityName = regexprep(folderName, '[_\s]*\d+\s*$', '');
    activityName = regexprep(activityName, '^\d+[_\s]+\d+[_\s]*', '');
    activityName = cleanName(activityName);

    if strcmp(activityName, 'activity')
        activityName = regexprep(filename, '\.xlsx$', '', 'ignorecase');
        activityName = regexprep(activityName, '^HipAngles_(Left|Right)_?', '', 'ignorecase');
        activityName = regexprep(activityName, '_sampled\d+.*$', '', 'ignorecase');
        activityName = cleanName(activityName);
    end
end

function outputBaseName = buildOutputBaseName(filename, activityName)
    outputBaseName = regexprep(filename, '\.xlsx$', '', 'ignorecase');
    if ~contains(lower(outputBaseName), lower(activityName))
        outputBaseName = sprintf('%s_%s', outputBaseName, activityName);
    end
end

function nameOut = cleanName(nameIn)
    nameOut = strtrim(nameIn);
    nameOut = regexprep(nameOut, '\s+', '_');
    nameOut = regexprep(nameOut, '[^\w-]', '_');
    nameOut = regexprep(nameOut, '_+', '_');
    nameOut = regexprep(nameOut, '^_|_$', '');
    if isempty(nameOut)
        nameOut = 'activity';
    end
end
