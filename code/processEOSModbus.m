function eosDat = processEOSModbus(selPath,applyOffsets)
% Reads raw externally-polled Eosense data and outputs a timetable at 1-s
% resolution containing the desired parameters. User interactively chooses selPath. 
% Optionally saves a .mat file

% USAGE
%   eosDat = processEOSModbus
%   eosDat = processEOSModbus(selPath)
%   eosDat = processEOSModbus(selPath,true)
%   eosDat = processEOSModbus(selPath,false)

% INPUTS
%   selPath         Path to experiment folder (optional)
%   applyOffsets    Apply EOS offset corrections if available (optional;
%   default = true)

dataRoot = 'C:\Users\Emily\OneDrive - Dalhousie University\Google Drive Migration\Dal and MIT\Lab Experiments\Data\';

% Handle inputs
if nargin < 1 || isempty(selPath)
    dialog_title = 'Select an experiment data folder';
    selPath = uigetdir(dataRoot,dialog_title);
    if selPath == 0
        error('No folder selected.')
    end
end

if nargin < 2
    applyOffsets = true;
end

[~, expName] = fileparts(selPath);
rawPath = fullfile(selPath, 'raw');
procPath = fullfile(selPath, 'processed');

if ~exist(procPath, 'dir')
    mkdir(procPath);
end

% Locate raw data files
datFiles = dir(fullfile(rawPath, '*.EOS')); % adjust extension if needed

if isempty(datFiles)
    error('No .dat files found in %s', rawPath);
end

% Sort files by name
[~, idx] = sort({datFiles.name});
datFiles = datFiles(idx);

fprintf('Found %d raw file(s).\n', numel(datFiles));

% Initialize container
eosDat = timetable();

% Loop through files
for i = 1:numel(datFiles)
    filePath = fullfile(datFiles(i).folder, datFiles(i).name);
    fprintf('Reading file: %s\n', datFiles(i).name);

    % Read files
    opts = delimitedTextImportOptions('Delimiter', ',');

    opts.VariableNames = {'tag','datetime_local','elapsed_s','ref_conc','ref_T','sample_conc','sample_T'};
    opts.VariableTypes = {'string','string','double','double','double','double','double'};

    T = readtable(filePath, opts);

    % Remove "tag" column (EOS)
    T.tag = [];

    % Convert "datetime_local" column
    T.datetime_local = datetime(T.datetime_local, 'InputFormat', 'yyyy-MM-dd HH:mm:ss.SSS');

    % Convert to timetable
    TT = table2timetable(T, 'RowTimes', 'datetime_local');
    TT.datetime_local = datetime(TT.datetime_local,'InputFormat','yyyy/MM/dd HH:mm:ss','Timezone','America/Halifax');

    % Append data
    eosDat = [eosDat; TT];
end

eosDat.Properties.VariableUnits = {'s','ppm','degC','ppm','degC'};

% Sort combined timetable (important if restart occurred)
[~, uniqueIdx] = unique(eosDat.datetime_local);
eosDat = eosDat(uniqueIdx, :);

% Apply offset corrections
if applyOffsets
    offsetFile = fullfile(dataRoot, 'Offsets', 'eosOffsets_2026-07-16.mat');
    if exist(offsetFile,'file')
        load(offsetFile,'eosOffsets')
        eosDat.ref_conc_corr = eosDat.ref_conc - eosOffsets.ref_avg;
        eosDat.sample_conc_corr = eosDat.sample_conc - eosOffsets.sample_avg;
        fprintf(['Reference offset: ', num2str(eosOffsets.ref_avg,2), ' \xB1 ', num2str(eosOffsets.ref_std,1), ' ppm\n'])
        fprintf(['Sample offset: ', num2str(eosOffsets.sample_avg,2), ' \xB1 ', num2str(eosOffsets.sample_std,1), ' ppm\n'])
    else
        warning('Offset file not found. No correction applied.')
    end
end

ref_clr = '#8A2BE2';
sample_clr = '#FF00FF';

figure,clf
plot(eosDat.datetime_local, eosDat.ref_conc, '.', 'color', ref_clr, 'DisplayName', 'Reference eosFD')
hold on
plot(eosDat.datetime_local, eosDat.sample_conc, '.', 'color', sample_clr, 'DisplayName', 'Sample eosFD')
xlabel('Local Time')
ylabel('CO_2 Concentration (ppm)')
legend('show')
grid on
title(expName,'Interpreter','none')

% Option to save data
option = questdlg('Save EOS data?','Save File','Yes','No','Yes');
switch option
    case 'Yes'
        save(fullfile(procPath, ['eos_',expName,'.mat']), 'eosDat')
        disp('File saved!')
    case 'No'
        disp('File not saved')
end

end