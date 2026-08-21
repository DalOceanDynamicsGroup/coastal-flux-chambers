function TT_5min = mergeSensorData_MIT(selpath)

% Merges the processed Eosense, Pro-Oceanus Mini ATM, and MIT datasets and
% outputs a merged, synchronized timetable at 5-min intervals. 
% User interactively chooses selpath.
% Optionally saves a .mat file.

% USAGE:
%   TT_5min = mergeAllData
%   TT_5min = mergeAllData(selpath)

% Handle inputs
if nargin < 1 || isempty(selpath)
    start_path = 'C:\Users\Emily\OneDrive - Dalhousie University\Work\Dal and MIT\Lab Experiments\Data\';
    dialog_title = 'Select an experiment data folder';
    selpath = uigetdir(start_path,dialog_title);
    if selpath == 0
        error('No folder selected.');
    end
end

[~, expName] = fileparts(selpath);

% Load MIT data
rawPath = fullfile(selpath, 'MIT');
datFile = dir(fullfile(rawPath, '*.csv'));
[~, filename] = fileparts(datFile.name);
mitDat = readtable(fullfile(rawPath,[filename,'.csv']));
% Remove rows where TIME = NaT
mitDat(isnat(mitDat.TIME),:) = [];
mitDat.TIME.TimeZone = 'America/New_York';
mitDat = table2timetable(mitDat);

% Load Dal Eosense data
rawPath = fullfile(selpath, 'Eosense', 'Processed');
datFile = dir(fullfile(rawPath, '*.mat'));
% [~, filename] = fileparts(datFile.name);
load(fullfile(rawPath, datFile.name));

% Load Dal Pro-Oceanus data
rawPath = fullfile(selpath, 'Pro-Oceanus', 'Processed');
datFile = dir(fullfile(rawPath, '*.mat'));
% [~, filename] = fileparts(datFile.name);
load(fullfile(rawPath, datFile.name));

% INPUTS
dal_sample_offset = 16;
dal_ref_offset = 9.3;
mit_sample_offset = 3.8;
mit_ref_offset = 3.9;

% Calculate corrected sample concentration and add to tables
mit_samplecorr_ppm = mitDat.SAMPLEPCO2 - mit_sample_offset; % (ppm)
mit_refcorr_ppm = mitDat.REFPCO2 - mit_ref_offset; % (ppm)

dal_samplecorr_ppm = eosDat.conc_2 - dal_sample_offset; % (ppm)
dal_refcorr_ppm = eosDat.conc_1 - dal_ref_offset; % (ppm)

% Synchronize all the data; calculations need total pressure from Pro-Oceanus; water temperature from MIT dataset
% Switch the Dal Eosense datetime column to the local time
eosDat = timetable2table(eosDat);
newRowTimes = eosDat.datetime_local;
eosDat.datetime_utc = [];
eosDat.datetime_local = [];
eosDat.datetime_local = newRowTimes;
eosDat = addvars(eosDat,dal_samplecorr_ppm,dal_refcorr_ppm);
eosDat = table2timetable(eosDat);

mitDat = mitDat(:,["pCO2","pH","TEMP1","TEMP2","REFPCO2","REFTEMP","SAMPLEPCO2","SAMPLETEMP","OceanusPCO2","CALCULATEDFLUX"]);
mitDat = addvars(mitDat,mit_samplecorr_ppm,mit_refcorr_ppm);

% TT_sync = synchronize(mitDat, proDat.water, poDat.air, eosDat, 'union', 'nearest');
TT_sync = synchronize(mitDat, poDat.water, poDat.air, eosDat, 'union', 'linear');

% Rearrange variables
TT_sync = TT_sync(:,{'pCO2','OceanusPCO2','TEMP1','TEMP2','pH',...
    'REFPCO2','mit_refcorr_ppm','SAMPLEPCO2','mit_samplecorr_ppm','REFTEMP','SAMPLETEMP','CALCULATEDFLUX'...
    'mean_conc_2','mean_conc_3','mean_P_2','mean_P_3'...
    'conc_1','dal_refcorr_ppm','conc_2','dal_samplecorr_ppm','T_ref','T_sample','flux_sample'});

TT_5min = retime(TT_sync,'regular','mean','TimeStep',minutes(5));
TT_5min.Properties.VariableNames = {'turner_ppm','miniCO2_water_ppm','air_T','water_T','pH'...
    'mit_ref_ppm','mit_refcorr_ppm','mit_sample_ppm','mit_samplecorr_ppm','mit_ref_T','mit_sample_T','mit_eos_flux'...
    'miniATM_water_ppm','miniATM_air_ppm','miniATM_water_Pmbar','miniATM_air_Pmbar'...
    'dal_ref_ppm','dal_refcorr_ppm','dal_sample_ppm','dal_samplecorr_ppm','dal_ref_T','dal_sample_T','dal_eos_flux'};

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

