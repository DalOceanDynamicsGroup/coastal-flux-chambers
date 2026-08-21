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

set(groot,'DefaultFigureWindowStyle','normal')

projectRoot = 'C:\Users\Emily\OneDrive - Dalhousie University\Work\Dal and MIT\';

% -------------------------------------------------------------------------
% Handle inputs
% -------------------------------------------------------------------------
if nargin < 1 || isempty(selPath)
    dialogTitle = 'Select an experiment data folder';
    selPath = uigetdir(projectRoot,dialogTitle);

    if selPath == 0
        error('No folder selected.')
    end
end

if nargin < 2 || isempty(pulseStart)
    pulseStart = [];
end

[~,expName] = fileparts(selPath);

if contains(selPath,'Lab Experiments')
    figPath = fullfile(projectRoot,'Lab Experiments','Figures');
elseif contains(selPath,'Field Deployments')
    figPath = fullfile(projectRoot,'Field Deployments','Figures');
end
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
% if isempty(pulseStart)
%     pulseStart = eosDat.datetime_local(1);
% end
% eos_h = hours(eosDat.datetime_local - pulseStart);
% po_h = hours(poPaired.datetime_local - pulseStart);
% therm_h = hours(thermDat.Time - pulseStart);

useRelativeTime = ~isempty(pulseStart);

if useRelativeTime
    eos_t = hours(eosDat.datetime_local - pulseStart);
    po_t = hours(poPaired.datetime_local - pulseStart);
    therm_t = hours(thermDat.Time - pulseStart);
    
    xLbl = 'Time since Pulse (hours)';
    start_time = -1;
    end_time = 17;
else
    eos_t = eosDat.datetime_local;
    po_t = poPaired.datetime_local;
    therm_t = thermDat.timeVec;

    xLbl = 'Local Time';
    start_time = eos_t(1);
    end_time = eos_t(end);
end

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
fig1.WindowState = 'maximized';
yyaxis left
% plot(eos_h, eosDat.ref_conc, '--', 'Color', ref_clr, 'DisplayName', 'eosFD Reference (Original)')
% hold on
% plot(eos_h, eosDat.sample_conc, '--', 'Color', sample_clr, 'DisplayName', 'eosFD Sample (Original)')
plot(eos_t, eosDat.ref_conc_corr, '.', 'Color', ref_clr, 'DisplayName', 'eosFD Reference (Corrected)')
hold on
plot(eos_t, eosDat.sample_conc_corr, '.', 'Color', sample_clr, 'DisplayName', 'eosFD Sample (Corrected)')
plot(po_t, poPaired.air_conc, 'o', 'markersize', 4, 'Color', POair_clr, 'DisplayName','Solu-Blu Air')
plot(po_t, poPaired.water_conc,'^', 'markersize', 4, 'Color', POwater_clr, 'DisplayName','Solu-Blu Water')
ylabel('CO_2 Concentration (ppm)')

yyaxis right
plot(therm_t, thermDat.air_T, ':', 'Color', Tair_clr, 'DisplayName', 'Air Temperature')
hold on
plot(therm_t, thermDat.water_T, ':', 'Color', Twater_clr, 'DisplayName', 'Water Temperature')
ylabel('Temperature (^oC)')

xlabel(xLbl)
legend('show','location','best','NumColumns',3)
grid on
title(expName,'Interpreter','none')

if useRelativeTime
    fig2 = figure(2);clf
    fig2.WindowState = 'maximized';
    yyaxis left
    % plot(eos_h, eosDat.ref_conc, '--', 'Color', ref_clr, 'DisplayName', 'eosFD Reference (Original)')
    % hold on
    % plot(eos_h, eosDat.sample_conc, '--', 'Color', sample_clr, 'DisplayName', 'eosFD Sample (Original)')
    plot(eos_t, eosDat.ref_conc_corr, '.', 'Color', ref_clr, 'DisplayName', 'eosFD Reference (Corrected)')
    hold on
    plot(eos_t, eosDat.sample_conc_corr, '.', 'Color', sample_clr, 'DisplayName', 'eosFD Sample (Corrected)')
    plot(po_t, poPaired.air_conc, 'o', 'markersize', 4, 'Color', POair_clr, 'DisplayName','Solu-Blu Air')
    plot(po_t, poPaired.water_conc,'^', 'markersize', 4, 'Color', POwater_clr, 'DisplayName','Solu-Blu Water')
    legend('show','location','best')
    ylabel('CO_2 Concentration (ppm)')

    yyaxis right
    plot(therm_t, thermDat.air_T, ':', 'Color', Tair_clr, 'DisplayName', 'Air Temperature')
    hold on
    plot(therm_t, thermDat.water_T, ':', 'Color', Twater_clr, 'DisplayName', 'Water Temperature')
    ylabel('Temperature (^oC)')
    xlabel('Time since Pulse (hours)')
    legend('show','location','best','NumColumns',3)
    grid on
    xlim([start_time end_time])
    title(expName,'Interpreter','none')
end

% Option to save figures
option = questdlg('Save fluxpi figure?','Save Figures','Yes','No','Yes');
switch option
    case 'Yes'
        exportgraphics(fig1,fullfile(figPath,['Concentration/',expName,'conc_Full.png']))
        savefig(fig1,fullfile(figPath,['Concentration/',expName,'_conc_Full.fig']))
        
        if useRelativeTime
            exportgraphics(fig2,fullfile(figPath,['Concentration/',expName,'_conc_Pulse-aligned.png']))
            savefig(fig2,fullfile(figPath,['Concentration/',expName,'_conc_Pulse-aligned.fig']))
        end

        disp('Figures saved as .png and .fig!')
    case 'No'
        disp('Figures not saved')
end

end