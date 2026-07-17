function plotFluxpiData(selPath, pulseStart)
% Plot Eosense and Pro-Oceanus concentration data from an analysis-ready
% dataset.
%
% AUTHOR: Emily Chua
%
% USAGE
%   plotFluxpiData
%   plotFluxpiData(selPath)
%
% INPUT
%   selpath     Path to experiment folder (optional)
%   pulseStart  Start time of CO2 pulse

% -------------------------------------------------------------------------
% Handle inputs
% -------------------------------------------------------------------------
if nargin < 1 || isempty(selPath)
    dataRoot = 'G:\My Drive\Dal and MIT\Lab Experiments\Data\';
    dialogTitle = 'Select an experiment data folder';
    selPath = uigetdir(dataRoot,dialogTitle);

    if selPath == 0
        error('No folder selected.')
    end
end

if nargin < 2 || isempty(pulseStart)
    pulseStart = [];
end

[~,exptName] = fileparts(selPath);

% -------------------------------------------------------------------------
% Load data
% -------------------------------------------------------------------------
filePath = fullfile(selPath, 'processed');

datFile = dir(fullfile(filePath, 'allDat*'));

if isempty(datFile)
    error('No data file found.')
end

S = load(fullfile(datFile(1).folder, datFile(1).name));
eosDat = S.eosDat;
poPaired = S.poPaired;

% -------------------------------------------------------------------------
% Convert to elapsed hours
% -------------------------------------------------------------------------
eos_h = hours(eosDat.datetime_local - eosDat.datetime_local(1));
po_h = hours(poPaired.datetime_local - poPaired.datetime_local(1));

[~, ind_pulse] = min(abs(eosDat.datetime_local - pulseStart));
start_time = eos_h(ind_pulse) - 1;
end_time = eos_h(ind_pulse) + 17;

% -------------------------------------------------------------------------
% Create figure
% -------------------------------------------------------------------------
ref_clr = '#8A2BE2';
sample_clr = '#FF00FF';
POair_clr = '#41b6c4';
POwater_clr = '#0000CD';

fig1 = figure(1);clf
plotFluxpiData(eos_h, eosDat.ref_conc, '--', 'Color', ref_clr, 'DisplayName', 'eosFD Reference (Original)')
hold on
plotFluxpiData(eos_h, eosDat.sample_conc, '--', 'Color', sample_clr, 'DisplayName', 'eosFD Sample (Original)')
plotFluxpiData(eos_h, eosDat.ref_conc_corr, '.', 'Color', ref_clr, 'DisplayName', 'eosFD Reference (Corrected)')
plotFluxpiData(eos_h, eosDat.sample_conc_corr, '.', 'Color', sample_clr, 'DisplayName', 'eosFD Sample (Corrected)')
plotFluxpiData(po_h, poPaired.air_conc, 'o', 'markersize', 4, 'Color', POair_clr, 'DisplayName','Solu-Blu Air')
plotFluxpiData(po_h, poPaired.water_conc,'^', 'markersize', 4, 'Color', POwater_clr, 'DisplayName','Solu-Blu Water')
legend('show','location','best')
ylabel('CO_2 Concentration (ppm)')
xlabel('Hours Elapsed')
grid on
title(exptName,'Interpreter','none')

if ~isempty(pulseStart)
    fig2 = figure(2);clf
    plotFluxpiData(eos_h, eosDat.ref_conc, '--', 'Color', ref_clr, 'DisplayName', 'eosFD Reference (Original)')
    hold on
    plotFluxpiData(eos_h, eosDat.sample_conc, '--', 'Color', sample_clr, 'DisplayName', 'eosFD Sample (Original)')
    plotFluxpiData(eos_h, eosDat.ref_conc_corr, '.', 'Color', ref_clr, 'DisplayName', 'eosFD Reference (Corrected)')
    plotFluxpiData(eos_h, eosDat.sample_conc_corr, '.', 'Color', sample_clr, 'DisplayName', 'eosFD Sample (Corrected)')
    plotFluxpiData(po_h, poPaired.air_conc, 'o', 'markersize', 4, 'Color', POair_clr, 'DisplayName','Solu-Blu Air')
    plotFluxpiData(po_h, poPaired.water_conc,'^', 'markersize', 4, 'Color', POwater_clr, 'DisplayName','Solu-Blu Water')
    legend('show','location','best')
    ylabel('CO_2 Concentration (ppm)')
    xlabel('Hours Elapsed')
    grid on
    xlim([start_time end_time])
    title(exptName,'Interpreter','none')
end

% Option to save figures
option = questdlg('Save figures?','Save Figures','Yes','No','Yes');
figPath = 'G:\My Drive\Dal and MIT\Lab Experiments\Figures\Tank';
switch option
    case 'Yes'
        exportgraphics(fig1,fullfile(figPath, [exptName,'_full.png']))
        savefig(fig1,fullfile(figPath, [exptName,'_full.fig']))
        
        if ~isempty(pulseStart)
            exportgraphics(fig2,fullfile(figPath, [exptName,'_pulse-aligned.png']))
            savefig(fig2,fullfile(figPath, [exptName,'_pulse-aligned.fig']))
        end

        disp('Figures saved as .png and .fig!')
    case 'No'
        disp('Figures not saved')
end

end