function thermDat = processTHERM_current(selPath)
% Reads raw thermistor data and outputs a timetable using the current 
% version of the DAQ code and outputs a timetable containing the air and 
% water temperatures.
% User interactively chooses selPath.
%
% NOTE: Thermistor data do not contain timestamps. Timestamps are inherited
% from the processed EOS dataset because EOS and THERM records are written
% synchronously by the acquisition software.
%
% Optionally saves a .mat file

dataRoot = 'C:\Users\Emily\OneDrive - Dalhousie University\Work\Dal and MIT\';

% Handle inputs
if nargin < 1 || isempty(selPath)
    dialog_title = 'Select an experiment data folder';
    selPath = uigetdir(dataRoot,dialog_title);
    if selPath == 0
        error('No folder selected.')
    end
end

[~, expName] = fileparts(selPath);
rawPath = fullfile(selPath, 'raw');
procPath = fullfile(selPath, 'processed');

% Locate raw data files
datFiles = dir(fullfile(rawPath, '*.THERM')); % adjust extension if needed

if isempty(datFiles)
    error('No .dat files found in %s', rawPath);
end

% Sort files by name
[~, idx] = sort({datFiles.name});
datFiles = datFiles(idx);

fprintf('Found %d raw file(s).\n', numel(datFiles));

% Initialize container
thermDat = timetable();

% Loop through files
filePath = fullfile(datFiles(1).folder,datFiles(1).name);
lines = readlines(filePath);

% Remove THERM prefix
lines = regexprep(lines,'^THERM,\s*','');

n = numel(lines);

timeVec = NaT(n,1,'TimeZone','America/Halifax');
waterT = nan(n,1);
airT = nan(n,1);

for i = 1:n
    parts = split(lines(i),',');

    if numel(parts) < 5
        continue
    end

    try
        timeVec(i) = datetime(...
            strtrim(parts{1}), ...
            'InputFormat','yyyy-MM-dd HH:mm:ss.SSS', ...
            'TimeZone','America/Halifax');

        waterT(i) = str2double(strtrim(parts{3}));
        airT(i) = str2double(strtrim(parts{5}));
    catch
    end
end

% Check if there is a final empty line and remove if so
if strlength(strtrim(lines(end))) == 0
    lines(end) = [];
end

% for i = 1:n
% 
%     token = regexp(lines(i), 'TemperatureAir\s*=\s*([-\d\.]+),\s*TemperatureH2O\s*=\s*([-\d\.]+)', 'tokens');
% 
%     if ~isempty(token)
%         airT(i) = str2double(token{1}{1});
%         waterT(i) = str2double(token{1}{2});
%     end
% 
% end

thermDat = timetable(timeVec, airT, waterT, 'VariableNames', {'air_T','water_T'});

% Sort combined timetable (important if restart occurred)
[~, uniqueIdx] = unique(thermDat.timeVec);
thermDat = thermDat(uniqueIdx, :);

% Replace invalid PT100 values with NaN
thermDat.air_T(thermDat.air_T < 0 | thermDat.air_T > 50) = NaN;
thermDat.water_T(thermDat.water_T < 0 | thermDat.water_T > 50) = NaN;

% First row where both thermistors are valid
idx = ~isnan(thermDat.air_T) & ~isnan(thermDat.water_T);
% Remove first continuous block of invalid data
firstValid = find(idx, 1, 'first');
thermDat = thermDat(firstValid:end, :);
startupDuration = thermDat.timeVec(firstValid) - thermDat.timeVec(1);

% After trimming, fill isolated NaNs
thermDat.air_T = fillmissing(thermDat.air_T, 'linear');
thermDat.water_T = fillmissing(thermDat.water_T, 'linear');

figure,clf
plot(thermDat.timeVec, thermDat.air_T, '.', 'DisplayName', 'Air Temperature')
hold on
plot(thermDat.timeVec, thermDat.water_T, '.', 'DisplayName', 'Water Temperature')
xlabel('Local Time')
ylabel('Temperature (^oC)')
legend('show','location','best')
grid on
title(expName,'Interpreter','none')

% Option to save data
option = questdlg('Save THERM data?','Save File','Yes','No','Yes');
switch option
    case 'Yes'
        save(fullfile(procPath, ['therm_',expName,'.mat']), 'thermDat')
        disp('File saved!')
    case 'No'
        disp('File not saved')
end

end