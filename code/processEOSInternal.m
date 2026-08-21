function eosDat = processEOSInternal(selPath)

% Reads raw internally logged Eosense data and outputs a timetable
% containing the desired parameters. User interactively chooses selpath.
% Optionally saves a .mat file.

% USAGE:
%   eosDat = processEOSInternal
%   eosDat = processEOSInternal(selpath)

% Handle inputs
if nargin < 1 || isempty(selPath)
    start_path = 'C:\Users\Emily\OneDrive - Dalhousie University\Work\Dal and MIT\Lab Experiments\Data\';
    dialog_title = 'Select an experiment data folder';
    selPath = uigetdir(start_path, dialog_title);
    if selPath == 0
        error('No folder selected.');
    end
end

[~, expName] = fileparts(selPath);
rawPath = fullfile(selPath, 'Eosense', 'Raw');
procPath = fullfile(selPath, 'Eosense', 'Processed');

% Locate files
datFile = dir(fullfile(rawPath, '*.dat'));
[~, filename] = fileparts(datFile.name);

% Main flux data (.dat)
dat = readtable(fullfile(rawPath,[filename,'.dat']));
varnames = ["datetime_utc","datetime_local","n_pairs","addr_ref","T_ref","addr_sample","flux_sample","T_sample","max_status","time_code"];
varunits = ["","","","","degC","","umol m-2 s-1","degC","",""];
% varnames = ["datetime_utc","datetime_local","n_pairs","addr_ref","misc","T_ref","addr_sample","flux_sample","T_sample","max_status","time_code"];
% varunits = ["","","","","","degC","","umol m-2 s-1","degC","",""];
dat.Properties.VariableNames = varnames;
dat.Properties.VariableUnits = varunits;
dat.datetime_utc = datetime(dat.datetime_utc,'InputFormat','yyyy/MM/dd HH:mm:ss','TimeZone','UTC');
dat.datetime_local = datetime(dat.datetime_local,'InputFormat','yyyy/MM/dd HH:mm:ss','Timezone','America/Halifax');

% Raw concentration data (.raw)
raw = readtable(fullfile(rawPath,[filename,'.RAW']),'FileType','text');
varnames = ["datetime_utc","datetime_local","n_nodes","addr_1","conc_1","T_1","addr_2","conc_2","T_2"];
varunits = ["","","","","ppm","degC","","ppm","degC"];
raw.Properties.VariableNames = varnames;
raw.Properties.VariableUnits = varunits;
raw.datetime_utc = datetime(raw.datetime_utc,'InputFormat','yyyy/MM/dd HH:mm:ss','TimeZone','UTC');
raw.datetime_local = datetime(raw.datetime_local,'InputFormat','yyyy/MM/dd HH:mm:ss','Timezone','America/Halifax');

% Auxiliary data (.aux)
aux = readtable(fullfile(rawPath,[filename,'.AUX']),'FileType','text');
varnames = ["datetime_utc","datetime_local","n_nodes","addr_1","status_1","int_T_1","int_press_1","int_RH_1","lat_1","lon_1","alt_1",...
    "addr_2","status_2","int_T_2","int_press_2","int_RH_2","lat_2","lon_2","alt_2"];
varunits = ["","","","","","degC","kPa","%","decimal_deg","decimal_deg","m","","","degC","kPa","%","decimal_deg","decimal_deg","m"];
aux.Properties.VariableNames = varnames;
aux.Properties.VariableUnits = varunits;
aux.datetime_utc = datetime(aux.datetime_utc,'InputFormat','yyyy/MM/dd HH:mm:ss','TimeZone','UTC');
aux.datetime_local = datetime(aux.datetime_local,'InputFormat','yyyy/MM/dd HH:mm:ss','Timezone','America/Halifax');

% Convert to timetables
dat = table2timetable(dat);
raw = table2timetable(raw);
aux = table2timetable(aux);

% Synchronize and aggregate
uniqueTimes = unique(dat.Properties.RowTimes); % Aggregate Dal data using the mean of variables at duplicate times
dat = retime(dat,uniqueTimes,'lastvalue');
raw = retime(raw,uniqueTimes,'lastvalue');
aux = retime(aux,uniqueTimes,'lastvalue');

% Build final dataset
eosDat = [raw(:,{'datetime_local','conc_1','conc_2'}),dat(:,{'T_ref','T_sample','flux_sample'})];

% Plot
figure(1),clf
yyaxis left
plot(eosDat.datetime_local,eosDat.conc_1,'ok--','MarkerSize',6,'DisplayName','Reference Node')
hold on
plot(eosDat.datetime_local,eosDat.conc_2,'.k-','MarkerSize',20,'DisplayName','Sample Node')
ylabel('CO_2 Conc. (ppm)')
ax = gca;
ax.YColor = 'k';

yyaxis right
plot(eosDat.datetime_local,eosDat.flux_sample,'.-','MarkerSize',20,'HandleVisibility','off')
xlabel('Local time')
ylabel('CO_2 Flux (\mumol m^{-2} s^{-1})')

legend('show','location','best')

% Option to save data
option = questdlg('Save data?','Save File','Yes','No','Yes');
switch option
    case 'Yes'
        save(fullfile(procPath, ['eos_',expName,'.mat']), 'eosDat')
        disp('File saved!')
    case 'No'
        disp('File not saved')
end

end