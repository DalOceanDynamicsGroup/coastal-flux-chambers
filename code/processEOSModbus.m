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
%   applyOffsets    Apply EOS offset corrections if available (optional; default = true)

projectRoot = 'C:\Users\Emily\OneDrive - Dalhousie University\Work\Dal and MIT\';

% Handle inputs
if nargin < 1 || isempty(selPath)
    dialog_title = 'Select an experiment data folder';
    selPath = uigetdir(projectRoot,dialog_title);
    if selPath == 0
        error('No folder selected.')
    end
end

if nargin < 2
    applyOffsets = true;
end

[dataDir, expName] = fileparts(selPath);
rawPath = fullfile(selPath, 'raw');
procPath = fullfile(selPath, 'processed');

if ~exist(procPath, 'dir')
    mkdir(procPath);
end

if contains(selPath,'Lab Experiments')
    figPath = fullfile(projectRoot,'Lab Experiments','Figures','Wave Tank','QA_QC');
elseif contains(selPath,'Field Deployments')
    figPath = fullfile(projectRoot,'Field Deployments','Figures','QA_QC');
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
    % Determine whether lab or field experiment
    if contains(selPath,'Lab Experiments')
        offsetDir = fullfile(projectRoot,'Lab Experiments','Data','Offsets');
    elseif contains(selPath,'Field Deployments')
        offsetDir = fullfile(projectRoot,'Field Deployments','Data','Offsets');
    else
        error('Could not determine lab vs. field deployment')
    end
    
    % Look for an experiment-specific offset file
    offsetFiles = dir(fullfile(offsetDir,['*',expName,'*.mat']));

    if ~isempty(offsetFiles)
        offsetFile = fullfile(offsetFiles(1).folder,offsetFiles(1).name);
        fprintf('Using experiment-specific offset file:\n%s\n',offsetFiles(1).name)
    else
        % Legacy fallback
        offsetFile = fullfile(projectRoot,'Lab Experiments','Data','Offsets','eosOffsets_2026-07-16.mat');
        warning(['No experiment-specific offset file found for "',expName,...
            '". Using legacy offset file "eosOffsets_2026-07-16.mat".'])
    end

    if exist(offsetFile,'file')
        load(offsetFile,'eosOffsets')
        eosDat.ref_conc_corr = eosDat.ref_conc - eosOffsets.ref_avg;
        eosDat.sample_conc_corr = eosDat.sample_conc - eosOffsets.sample_avg;

        % Save metadata
        eosDat.Properties.UserData.offsetsApplied = true;
        eosDat.Properties.UserData.offsetFile = offsetFile;
        eosDat.Properties.UserData.eosOffsets = eosOffsets;

        fprintf(['Reference offset: ', num2str(eosOffsets.ref_avg,2), ' ± ', num2str(eosOffsets.ref_std,1), ' ppm\n'])
        fprintf(['Sample offset: ', num2str(eosOffsets.sample_avg,2), ' ± ', num2str(eosOffsets.sample_std,1), ' ppm\n'])
   
    else
        warning('Offset file not found. No correction applied.')
    end

else
    eosDat.Properties.UserData.OffsetsApplied = false;
end

ref_clr = '#8A2BE2';
sample_clr = '#FF00FF';

fig=figure;clf
plot(eosDat.datetime_local, eosDat.ref_conc, '.', 'color', ref_clr, 'DisplayName', 'Reference eosFD')
hold on
plot(eosDat.datetime_local, eosDat.sample_conc, '.', 'color', sample_clr, 'DisplayName', 'Sample eosFD')
if applyOffsets
    plot(eosDat.datetime_local, eosDat.ref_conc_corr, '--', 'color', ref_clr, 'DisplayName', 'Reference eosFD (corrected)')
    plot(eosDat.datetime_local, eosDat.sample_conc_corr, '--', 'color', sample_clr, 'DisplayName', 'Sample eosFD (Corrected)')
else
    % Do not plot non-existent corrected values for offset datasets
end
xlabel('Local Time')
ylabel('CO_2 Concentration (ppm)')
legend('show','location','best','NumColumns',2)
grid on
title(expName,'Interpreter','none')

% Option to save data
option = questdlg('Save EOS data and figure?','Save File','Yes','No','Yes');
switch option
    case 'Yes'
        if applyOffsets
            save(fullfile(procPath, ['eos_',expName,'.mat']), 'eosDat', 'eosOffsets')
        else
            save(fullfile(procPath, ['eos_',expName,'.mat']), 'eosDat')
        end
        disp('File saved!')
        exportgraphics(fig, fullfile(figPath,[expName,'_EOSprocess.png']))
        savefig(fig, fullfile(figPath,[expName,'_EOSprocess.fig']))
        disp('Figure saved!')
    case 'No'
        disp('File and figure not saved')
end

end