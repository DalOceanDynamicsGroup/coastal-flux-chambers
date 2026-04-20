function proDat = processProOceanus(selpath)

% Reads raw Pro-Oceanus Mini ATM data and outputs a timetable
% containing the desired paramters. User interactively chooses selpath.
% Optionally saves a .mat file.

% USAGE:
%   proDat = processProOceanus
%   proDat = processProOceanus(selpath)

% -------------------------------------------------------------------------
% Handle inputs
% -------------------------------------------------------------------------
if nargin < 1 || isempty(selpath)
    start_path = 'G:\My Drive\Dal and MIT\Lab Experiments\Data\';
    dialog_title = 'Select an experiment data folder';
    selpath = uigetdir(start_path,dialog_title);
    if selpath == 0
        error('No folder selected.')
    end
end

[~, expt_name] = fileparts(selpath);
rawPath = fullfile(selpath, 'Pro-Oceanus', 'Raw');
procPath = fullfile(selpath, 'Pro-Oceanus', 'Processed');

% -------------------------------------------------------------------------
% Locate files and read in data
% -------------------------------------------------------------------------
datFile = dir(fullfile(rawPath, '*.txt'));
[~,filename] = fileparts(datFile.name);

rawDat = readtable(fullfile(rawPath,[filename,'.txt']));
varnames = ["phase","year","month","day","hour","minute","second","ref_a/d","current_a/d","raw_CO2_ppm","corr_CO2_ppm","T_press_sensor","P","T_irga","voltage"];
varunits = ["","","","","","","","counts","counts","ppm","ppm","degC","mbar","degC","volts"];
rawDat.Properties.VariableNames = varnames;
rawDat.Properties.VariableUnits = varunits;

rawDat.phase = string(rawDat.phase);
datetimeVector = datetime(rawDat.year,rawDat.month,rawDat.day,rawDat.hour,rawDat.minute,rawDat.second,'TimeZone','America/Halifax');
% datetimeVector = datetime(rawDat.year,rawDat.month,rawDat.day,rawDat.hour,rawDat.minute,rawDat.second,'TimeZone','America/New_York');

proDat.all = table(datetimeVector,rawDat.phase,rawDat.corr_CO2_ppm,rawDat.P,'VariableNames',{'datetime_local','phase','conc_ppm','P_mbar'});
proDat.all.Properties.VariableUnits = {'','','ppm','mbar'};
% Remove rows with missing (e.g., header or footer) or negative Pro-Oceanus pCO2 data
ind_nat = find(isnat(proDat.all.datetime_local));
proDat.all(ind_nat,:) = [];
ind = find(proDat.all.conc_ppm < 0);
proDat.all(ind,:) = [];

% proDat.all.datetime_local = proDat.all.datetime_local + hours(12); % Time correction for experiment on 2/13/26

% Convert table to timetable
proDat.all = table2timetable(proDat.all);

% -------------------------------------------------------------------------
% Clean data by using moving median to screen outliers
% -------------------------------------------------------------------------
fig = figure(1);clf
plot(proDat.all.datetime_local,proDat.all.conc_ppm,'.k','DisplayName','Raw data')
xlabel('Local time')
ylabel('conc (ppmv)')
legend('show')
grid on

dcm_obj = datacursormode(fig);
datacursormode on;
disp([newline 'Click on a data point as the start index for filtering for outliers, then press "Enter"']);
pause;
info_struct = getCursorInfo(dcm_obj);
if isfield(info_struct, 'DataIndex')
    start_ind = info_struct.DataIndex;
    cursor_position = info_struct.Position;
    disp(['Clicked data index: ', num2str(start_ind)]);
    disp(['Clicked y-value: ', num2str(cursor_position(2),3), ' ppm']);
else
    disp('No data point was clicked.');
end

window = 10^3;
TF = isoutlier(proDat.all.conc_ppm,'movmedian',window);
ind_outlier = find(TF);
ind_outlier(ind_outlier < start_ind) = [];

figure(2),clf
plot(proDat.all.datetime_local,proDat.all.conc_ppm,'.k','DisplayName','Raw data')
hold on
plot(proDat.all.datetime_local(ind_outlier),proDat.all.conc_ppm(ind_outlier),'o','DisplayName','Outlier to remove')
xlabel('Local time')
ylabel('conc (ppmv)')
legend('show')
grid on

% Remove outliers
proDat.all.conc_ppm(ind_outlier) = NaN;

% -------------------------------------------------------------------------
% Average last half-minute of data for each phase change
% -------------------------------------------------------------------------
% Find the start/end indices of consecutive phase changes
[G, group_ids] = findgroups(proDat.all.phase);

% Find the indices where the group ID changes
changeIdx = find(diff(G) ~= 0) + 1; % +1 to get start of *new* phase
startIdx = [1; changeIdx];  % Start of the very first period is index 1
endIdx = [changeIdx - 1; height(proDat.all)]; % End of the very last period is the last index

% Iterate through the periods and calculate the average for the last minute
numPeriods = length(startIdx);
results = table('Size', [numPeriods,4], 'VariableNames', {'datetime_local', 'phase', 'mean_conc_ppm', 'mean_P_mbar'},...
    'VariableTypes', {'datetime', 'string', 'double', 'double'});
results = table2timetable(results);
results.datetime_local.TimeZone = 'America/Halifax';
% results.datetime_local.TimeZone = 'America/New_York';

for i = 1:numPeriods-1
    % Get the sub-timetable for the current continuous phase period
    currentPeriodTT = proDat.all(startIdx(i):endIdx(i), :);

    % Determine the end time of the current period
    periodEndTime = currentPeriodTT.datetime_local(end);

    % Determine the start time for the averaging window
    % oneMinuteBeforeEnd = periodEndTime - minutes(1);
    halfMinuteBeforeEnd = periodEndTime - minutes(0.5);

    % Extract the last minute of data
    windowRange = timerange(halfMinuteBeforeEnd, periodEndTime, 'closedright');
    windowData = currentPeriodTT(windowRange,:);

    % Calculate the means of these last minute periods
    if ~isempty(windowData)
        mean_conc_ppm = mean(windowData.conc_ppm,'omitnan');
        mean_P_mbar = mean(windowData.P_mbar,'omitnan'); 
    else
        % Handles cases where a period is <1 minute long
        mean_conc_ppm = NaN;    
        mean_P_mbar = NaN;
    end

    % Store the results
    results.datetime_local(i) = mean([halfMinuteBeforeEnd,periodEndTime]);
    results.phase(i) = currentPeriodTT.phase(1);
    results.mean_conc_ppm(i) = mean_conc_ppm;
    results.mean_P_mbar(i) = mean_P_mbar;
end

id_water = contains(results.phase,"W M");
id_air = contains(results.phase,"A M");

proDat.water = results(id_water,:);
proDat.air = results(id_air,:);

% Remove phase column
proDat.water.phase = [];
proDat.air.phase = [];

% Sanity check
figure(3),clf
plot(proDat.all.datetime_local,proDat.all.conc_ppm,'.','DisplayName','All Data')
hold on
plot(proDat.water.datetime_local,proDat.water.mean_conc_ppm,'o','DisplayName','Pro-Oceanus Water')
plot(proDat.air.datetime_local,proDat.air.mean_conc_ppm,'o','DisplayName','Pro-Oceanus Air')
legend('show')
grid on

% -------------------------------------------------------------------------
% Option to save data
% -------------------------------------------------------------------------
option = questdlg('Save cleaned data?','Save File','Yes','No','Yes');
switch option
    case 'Yes'
        save(fullfile(procPath, ['pro_',filename,'.mat']), 'proDat')
        disp('File saved!')
    case 'No'
        disp('File not saved')
end

end