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

dataRoot = 'C:\Users\Emily\OneDrive - Dalhousie University\Google Drive Migration\Dal and MIT\Lab Experiments\Data\';

% -------------------------------------------------------------------------
% Handle inputs
% -------------------------------------------------------------------------
if nargin < 1 || isempty(selPath)
    dialogTitle = 'Select an experiment data folder';
    selPath = uigetdir(dataRoot,dialogTitle);

    if selPath == 0
        error('No folder selected.')
    end
end

if nargin < 2 || isempty(pulseStart)
    pulseStart = [];
end

[~,expName] = fileparts(selPath);

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
thermDat = S.thermDat;

% -------------------------------------------------------------------------
% Convert to elapsed hours
% -------------------------------------------------------------------------
eos_h = hours(eosDat.datetime_local - pulseStart);
po_h = hours(poPaired.datetime_local - pulseStart);
therm_h = hours(thermDat.Time - pulseStart);

start_time = -1;
end_time = 17;

% -------------------------------------------------------------------------
% Create figure
% -------------------------------------------------------------------------
ref_clr = '#8A2BE2';
sample_clr = '#FF00FF';
POair_clr = '#41b6c4';
POwater_clr = '#0000CD';
Tair_clr = rgb('orange');
Twater_clr = rgb('tomato');

fig1 = figure(1);clf
yyaxis left
% plot(eos_h, eosDat.ref_conc, '--', 'Color', ref_clr, 'DisplayName', 'eosFD Reference (Original)')
% hold on
% plot(eos_h, eosDat.sample_conc, '--', 'Color', sample_clr, 'DisplayName', 'eosFD Sample (Original)')
plot(eos_h, eosDat.ref_conc_corr, '.', 'Color', ref_clr, 'DisplayName', 'eosFD Reference (Corrected)')
hold on
plot(eos_h, eosDat.sample_conc_corr, '.', 'Color', sample_clr, 'DisplayName', 'eosFD Sample (Corrected)')
plot(po_h, poPaired.air_conc, 'o', 'markersize', 4, 'Color', POair_clr, 'DisplayName','Solu-Blu Air')
plot(po_h, poPaired.water_conc,'^', 'markersize', 4, 'Color', POwater_clr, 'DisplayName','Solu-Blu Water')
ylabel('CO_2 Concentration (ppm)')

yyaxis right
plot(therm_h, thermDat.air_T, ':', 'Color', Tair_clr, 'DisplayName', 'Air Temperature')
hold on
plot(therm_h, thermDat.water_T, ':', 'Color', Twater_clr, 'DisplayName', 'Water Temperature')
ylabel('Temperature (^oC)')
ylim([20 30])

xlabel('Time since Pulse (hours)')
legend('show','location','best','NumColumns',3)
grid on
title(expName,'Interpreter','none')

if ~isempty(pulseStart)
    fig2 = figure(2);clf
    yyaxis left
    % plot(eos_h, eosDat.ref_conc, '--', 'Color', ref_clr, 'DisplayName', 'eosFD Reference (Original)')
    % hold on
    % plot(eos_h, eosDat.sample_conc, '--', 'Color', sample_clr, 'DisplayName', 'eosFD Sample (Original)')
    plot(eos_h, eosDat.ref_conc_corr, '.', 'Color', ref_clr, 'DisplayName', 'eosFD Reference (Corrected)')
    hold on
    plot(eos_h, eosDat.sample_conc_corr, '.', 'Color', sample_clr, 'DisplayName', 'eosFD Sample (Corrected)')
    plot(po_h, poPaired.air_conc, 'o', 'markersize', 4, 'Color', POair_clr, 'DisplayName','Solu-Blu Air')
    plot(po_h, poPaired.water_conc,'^', 'markersize', 4, 'Color', POwater_clr, 'DisplayName','Solu-Blu Water')
    legend('show','location','best')
    ylabel('CO_2 Concentration (ppm)')

    yyaxis right
    plot(therm_h, thermDat.air_T, ':', 'Color', Tair_clr, 'DisplayName', 'Air Temperature')
    hold on
    plot(therm_h, thermDat.water_T, ':', 'Color', Twater_clr, 'DisplayName', 'Water Temperature')
    ylabel('Temperature (^oC)')
    ylim([20 30])
    
    xlim([-1 17])
    xlabel('Time since Pulse (hours)')
    legend('show','location','best','NumColumns',3)
    grid on
    xlim([start_time end_time])
    title(expName,'Interpreter','none')
end

% Option to save figures
option = questdlg('Save figures?','Save Figures','Yes','No','Yes');
figPath = 'C:\Users\Emily\OneDrive - Dalhousie University\Google Drive Migration\Dal and MIT\Lab Experiments\Figures\Tank';
switch option
    case 'Yes'
        exportgraphics(fig1,fullfile(figPath, [expName,'_full.png']))
        savefig(fig1,fullfile(figPath, [expName,'_full.fig']))
        
        if ~isempty(pulseStart)
            exportgraphics(fig2,fullfile(figPath, [expName,'_pulse-aligned.png']))
            savefig(fig2,fullfile(figPath, [expName,'_pulse-aligned.fig']))
        end

        disp('Figures saved as .png and .fig!')
    case 'No'
        disp('Figures not saved')
end

end