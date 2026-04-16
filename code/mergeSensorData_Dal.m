function TT_5min = mergeSensorData_Dal(selpath)

% Merges the processed Eosense and Pro-Oceanus Mini ATM datasets and
% outputs a merged, synchronized timetable at 5-min intervals. 
% User interactively chooses selpath.
% Optionally saves a .mat file.

% USAGE:
%   TT_5min = mergeAllData
%   TT_5min = mergeAllData(selpath)

% Handle inputs
if nargin < 1 || isempty(selpath)
    start_path = 'G:\My Drive\Dal and MIT\Lab Experiments\Data\';
    dialog_title = 'Select an experiment data folder';
    selpath = uigetdir(start_path,dialog_title);
    if selpath == 0
        error('No folder selected.');
    end
end

[~, expName] = fileparts(selpath);

% Load Dal Eosense data
rawPath = fullfile(selpath, 'Eosense', 'Processed');
datFile = dir(fullfile(rawPath, '*.mat'));
[~, filename] = fileparts(datFile.name);
load(fullfile(rawPath, datFile.name));

% Load Dal Pro-Oceanus data
rawPath = fullfile(selpath, 'Pro-Oceanus', 'Processed');
datFile = dir(fullfile(rawPath, '*.mat'));
[~, filename] = fileparts(datFile.name);
load(fullfile(rawPath, datFile.name));

% -------------------------------------------------------------------------
% Compute the bias-corrected Eosense fluxes
% -------------------------------------------------------------------------
% INPUTS
dal_offset = 6.5;  % (ppm)

% Calculate corrected sample concentration and add to tables
dal_samplecorr_ppm = eosDat.conc_2 - dal_offset; % (ppm)

% Synchronize all the data; calculations need total pressure from Pro-Oceanus; water temperature from MIT dataset
% Switch the Dal Eosense datetime column to the local time
eosDat = timetable2table(eosDat);
newRowTimes = eosDat.datetime_local;
eosDat.datetime_utc = [];
eosDat.datetime_local = [];
eosDat.datetime_local = newRowTimes;
eosDat = addvars(eosDat,dal_samplecorr_ppm);
eosDat = table2timetable(eosDat);

TT_sync = synchronize(proDat.water, proDat.air, eosDat, 'union', 'linear');

% Rearrange variables
TT_sync = TT_sync(:,{'mean_conc_ppm_1','mean_conc_ppm_2','mean_P_mbar_1','mean_P_mbar_2'...
    'conc_1','conc_2','dal_samplecorr_ppm','T_ref','T_sample','flux_sample'});

TT_5min = retime(TT_sync,'regular','mean','TimeStep',minutes(5));
TT_5min.Properties.VariableNames = {'miniATM_water_ppm','miniATM_air_ppm','miniATM_water_Pmbar','miniATM_air_Pmbar'...
    'dal_ref_ppm','dal_sample_ppm','dal_samplecorr_ppm','dal_ref_T','dal_sample_T','dal_eos_flux'};

% Option to save merged data table
option = questdlg('Save merged data?','Save File','Yes','No','Yes');
switch option
    case 'Yes'
        cd([selpath,'\Merged'])
        save('allDat.mat','TT_5min')
        disp('File saved!')
    case 'No'
        disp('File not saved')
end

end