function poDat = processPO(selPath)

% Reads raw Pro-Oceanus Solu-Blu data and outputs a timetable containing
% phase-averaged values. User interactively chooses selPath.
% Optionally saves a .mat file.

% USAGE:
%   poDat = processPO
%   poDat = processPO(selPath)

% -------------------------------------------------------------------------
% Handle inputs
% -------------------------------------------------------------------------
dataRoot = 'G:\My Drive\Dal and MIT\Lab Experiments\Data\';

if nargin < 1 || isempty(selPath)
    dialog_title = 'Select an experiment data folder';
    selPath = uigetdir(dataRoot,dialog_title);
    if selPath == 0
        error('No folder selected.')
    end
end

[~, expt_name] = fileparts(selPath);
rawPath1 = fullfile(selPath, 'Pro-Oceanus', 'Raw');
rawPath2 = fullfile(selPath, 'raw');

if exist(rawPath1, 'dir')
    rawPath = rawPath1;
elseif exist(rawPath2, 'dir')
    rawPath = rawPath2;
else
    error('No Pro-Oceanus or PO raw folder found.')
end

procPath1 = fullfile(selPath, 'Pro-Oceanus', 'Processed');
procPath2 = fullfile(selPath, 'processed');

if exist(procPath1, 'dir')
    procPath = procPath1;
elseif exist(procPath2, 'dir')
    procPath = procPath2;
else
    error('No Pro-Oceanus or PO processed folder found.')
end

% -------------------------------------------------------------------------
% Locate files (.txt or .PO)
% -------------------------------------------------------------------------
txtFiles = dir(fullfile(rawPath, '*.txt'));
poFiles  = dir(fullfile(rawPath, '*.PO'));

if ~isempty(txtFiles) && ~isempty(poFiles)
    error('Both .txt and .PO files found — unclear which to use.')
elseif isempty(txtFiles) && isempty(poFiles)
    error('No .txt or .PO files found in raw folder.')
end

% Decide which set to use
if ~isempty(txtFiles)
    files = txtFiles;
    fileType = 'txt';
else
    files = poFiles;
    fileType = 'po';
end

% Build filename label (for saving)
[~, expName] = fileparts(selPath);

% -------------------------------------------------------------------------
% Read and concatenate all lines
% -------------------------------------------------------------------------
allLines = strings(0);

for i = 1:length(files)
    filePath = fullfile(files(i).folder, files(i).name);
    lines = readlines(filePath);

    % Remove PO prefix if needed
    if fileType == "po"
        lines = regexprep(lines, '^PO,?', '');
    end
    
    % Remove "??" if present
    lines = regexprep(lines, '^>>', '');
    allLines = [allLines; lines];

    % Remove empty lines
    lines = lines(strlength(strtrim(lines)) > 0);

    % Keep only valid data rows (15 columns --> 14 commas)
    numCommas = count(lines, ',');
    lines = lines(numCommas == 14);

    % Keep only lines that start with valid phase markers
    % (e.g., "W M", "A M", possibly preceded by ">>")
    isData = startsWith(lines, ["W M", "A M", ">>W M", ">>A M"]);

    lines = lines(isData);

    % Remove ">>" if present
    lines = regexprep(lines, '^>>', '');
end

% Optional: inform user
if fileType == "po" && length(files) > 1
    disp(['Concatenated ', num2str(length(files)), ' PO files'])
end

% -------------------------------------------------------------------------
% Convert to table
% -------------------------------------------------------------------------
tmpFile = tempname + ".txt";
writelines(allLines, tmpFile);

rawDat = readtable(tmpFile);

varNames = ["phase","year","month","day","hour","minute","second","ref_a/d","current_a/d","raw_CO2_ppm","corr_CO2_ppm","T_press_sensor","P","T_irga","voltage"];
varUnits = ["","","","","","","","counts","counts","ppm","ppm","degC","mbar","degC","volts"];
rawDat.Properties.VariableNames = varNames;
rawDat.Properties.VariableUnits = varUnits;

rawDat.phase = string(rawDat.phase);
datetimeVector = datetime(rawDat.year,rawDat.month,rawDat.day,rawDat.hour,rawDat.minute,rawDat.second,'TimeZone','America/Halifax');

poDat.all = table(datetimeVector,rawDat.phase,rawDat.corr_CO2_ppm,rawDat.P,'VariableNames',{'datetime_local','phase','conc','P'});
poDat.all.Properties.VariableUnits = {'','','ppm','mbar'};
% Remove rows with missing (e.g., header or footer) or negative Pro-Oceanus pCO2 data
ind_nat = find(isnat(poDat.all.datetime_local));
poDat.all(ind_nat,:) = [];
ind = find(poDat.all.conc < 0);
poDat.all(ind,:) = [];

% Convert table to timetable
poDat.all = table2timetable(poDat.all);

% -------------------------------------------------------------------------
% Average last half-minute of data for each phase change
% -------------------------------------------------------------------------
% Find the start/end indices of consecutive phase changes
[G, group_ids] = findgroups(poDat.all.phase);

% Find the indices where the group ID changes
changeIdx = find(diff(G) ~= 0) + 1; % +1 to get start of *new* phase
startIdx = [1; changeIdx];  % Start of the very first period is index 1
endIdx = [changeIdx - 1; height(poDat.all)]; % End of the very last period is the last index

% Iterate through the periods and calculate the average for the last 30 s
numPeriods = length(startIdx);
results = table('Size', [numPeriods,4], 'VariableNames', {'datetime_local', 'phase', 'mean_conc', 'mean_P'},...
    'VariableTypes', {'datetime', 'string', 'double', 'double'});
results = table2timetable(results);
results.Properties.VariableUnits = {'', 'ppm', 'mbar'};
results.datetime_local.TimeZone = 'America/Halifax';

for i = 1:numPeriods-1
    % Get the sub-timetable for the current continuous phase period
    currentPeriodTT = poDat.all(startIdx(i):endIdx(i), :);

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
        mean_conc = mean(windowData.conc,'omitnan');
        mean_P = mean(windowData.P,'omitnan'); 
    else
        % Handles cases where a period is <1 minute long
        mean_conc = NaN;    
        mean_P = NaN;
    end

    % Store the results
    results.datetime_local(i) = mean([halfMinuteBeforeEnd,periodEndTime]);
    results.phase(i) = currentPeriodTT.phase(1);
    results.mean_conc(i) = mean_conc;
    results.mean_P(i) = mean_P;
end

id_water = contains(results.phase,"W M");
id_air = contains(results.phase,"A M");

poDat.water = results(id_water,:);
poDat.air = results(id_air,:);

% Remove phase column
poDat.water.phase = [];
poDat.air.phase = [];

% Sanity check
figure(3),clf
plot(poDat.all.datetime_local,poDat.all.conc,'.','DisplayName','All Data')
hold on
plot(poDat.water.datetime_local,poDat.water.mean_conc,'o','DisplayName','Pro-Oceanus Water')
plot(poDat.air.datetime_local,poDat.air.mean_conc,'o','DisplayName','Pro-Oceanus Air')
legend('show')
grid on

% -------------------------------------------------------------------------
% Option to save data
% -------------------------------------------------------------------------
option = questdlg('Save cleaned data?','Save File','Yes','No','Yes');
switch option
    case 'Yes'
        save(fullfile(procPath, ['po_',expName,'.mat']), 'poDat')
        disp('File saved!')
    case 'No'
        disp('File not saved')
end

end