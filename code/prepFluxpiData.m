function [eosDat, poPaired, thermDat, pulseStart] = prepFluxpiData(selPath, eosDat, poDat, thermDat, pulseStart)

% Takes the processed Eosense, Pro-Oceanus Solu-Blu, and thermistor
% datasets and:
% 1. Performs timestamp corrections if necessary
% 2. Constructs PO air-water pairs
% 3. Saves output timetables
% User interactively chooses selPath.
% Optionally saves a .mat file.

% USAGE:
%   [eosDat, poPaired, thermDat] = prepFluxpiData
%   [eosDat, poPaired, thermDat] = prepFluxpiData(selPath, eosDat, poDat, thermDat)

dataRoot = 'C:\Users\Emily\OneDrive - Dalhousie University\Google Drive Migration\Dal and MIT\Lab Experiments\Data\';

% Handle inputs
if nargin < 1 || isempty(selPath)
    dialog_title = 'Select an experiment data folder';
    selPath = uigetdir(dataRoot,dialog_title);
    if selPath == 0
        error('No folder selected.');
    end
end

if nargin < 4
    thermDat = timetable();
end

[~, expName] = fileparts(selPath);
filePath = fullfile(selPath, 'processed');

% 1. Check and fix date offset between EOS and PO data
timeOffset = eosDat.datetime_local(end) - poDat.all.datetime_local(end);

if timeOffset ~= 0
    warning('Start-time discrepancy detected: %.1f min\n',minutes(timeOffset));
    poDat.all.datetime_local = poDat.all.datetime_local + timeOffset;
    poDat.air.datetime_local = poDat.air.datetime_local + timeOffset;
    poDat.water.datetime_local = poDat.water.datetime_local + timeOffset;
end

% 2. Build paired PO timetable
N = min(height(poDat.air), height(poDat.water));

airTT = poDat.air(1:N,:);
waterTT = poDat.water(1:N,:);

tPaired = airTT.datetime_local + (waterTT.datetime_local - airTT.datetime_local)/2;

poPaired = timetable;
poPaired.air_conc = airTT.mean_conc;
poPaired.water_conc = waterTT.mean_conc;
poPaired.air_press = airTT.mean_P;
poPaired.water_press = waterTT.mean_P;
poPaired.Time = tPaired;
poPaired.Properties.DimensionNames{1} = 'datetime_local';
poPaired.Properties.VariableUnits = {'ppm', 'ppm', 'mbar', 'mbar'};

% 3. Option to save everything separately
option = questdlg('Save analysis-ready EOS, PO, and THERM data sets?','Save File','Yes','No','Yes');
switch option
    case 'Yes'
        if isempty(thermDat)
            save(fullfile(filePath, ['allDat_',expName,'.mat']),'eosDat', 'poPaired', 'pulseStart')
        else
            save(fullfile(filePath, ['allDat_',expName,'.mat']), 'eosDat', 'poPaired', 'thermDat', 'pulseStart')
        end
        disp('File saved!')
    case 'No'
        disp('File not saved')
end

end

