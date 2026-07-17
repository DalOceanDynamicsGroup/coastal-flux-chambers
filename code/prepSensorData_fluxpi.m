function [eosDat,poPaired] = prepSensorData_fluxpi(selPath,eosDat,poDat)

% Takes the processed Eosense, Pro-Oceanus Solu-Blu, and thermistor
% datasets and:
% 1. Performs timestamp corrections if necessary
% 2. Constructs PO air-water pairs
% 3. Saves output timetables
% User interactively chooses selPath.
% Optionally saves a .mat file.

% USAGE:
%   [eosDat, poPaired] = prepSensorData_fluxpi
%   [eosDat, poPaired] = prepSensorData_fluxpi(selPath,eosDat,poDat)

% Handle inputs
if nargin < 1 || isempty(selPath)
    start_path = 'G:\My Drive\Dal and MIT\Lab Experiments\Data\';
    dialog_title = 'Select an experiment data folder';
    selPath = uigetdir(start_path,dialog_title);
    if selPath == 0
        error('No folder selected.');
    end
end

[~, expName] = fileparts(selPath);
filePath = fullfile(selPath, 'processed');

% Load EOS data
datFile = dir(fullfile(filePath, 'eos*'));
[~, filename] = fileparts(datFile.name);
load(fullfile(filePath, datFile.name));

% Load PO data
datFile = dir(fullfile(filePath, 'po*'));
[~, filename] = fileparts(datFile.name);
load(fullfile(filePath, datFile.name));

% 1. Check and fix date offset between EOS and PO data
d1 = dateshift(eosDat.datetime_local(1),'start','day');
d2 = dateshift(poDat.air.datetime_local(1),'start','day');
d3 = dateshift(poDat.water.datetime_local(1),'start','day');

shiftDays = days(d1 - d2);

if abs(shiftDays) > 1
    warning('Start-time discrepancy detected: %.1f days',shiftDays);
    poDat.water.datetime_local = poDat.water.datetime_local + days(shiftDays);
    poDat.air.datetime_local = poDat.air.datetime_local + days(shiftDays);
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

% Option to save everything separately
option = questdlg('Save analysis-ready data?','Save File','Yes','No','Yes');
switch option
    case 'Yes'
        save(fullfile(filePath, ['allDat_',expName,'.mat']), 'eosDat', 'poPaired')
        disp('File saved!')
    case 'No'
        disp('File not saved')
end

end

