%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% determine_offsets.m
%
% Run on offset test data only.
% Computes eosFD Reference and Sample offsets from Pro-Oceanus air data.
%
% AUTHOR: Emily Chua
%
% DATE:
% First created: 7/13/26
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear; close all; clc

% -------------------------------------------------------------------------
% Load the analysis-ready data file
% -------------------------------------------------------------------------
dataRoot = 'C:\Users\Emily\OneDrive - Dalhousie University\Google Drive Migration\Dal and MIT\Lab Experiments\Data\';
dialogTitle = 'Select an experiment data folder';
selPath = uigetdir(dataRoot,dialogTitle);

[~,expName] = fileparts(selPath);
calDate = extractBefore(expName,"_");

eosDat = processEOSModbus(selPath,false);
poDat = processPO(selPath);

[eosDat, poPaired] = prepFluxpiData(selPath, eosDat, poDat);

% -------------------------------------------------------------------------
% Put EOS and PO air on common times
% -------------------------------------------------------------------------
eosPaired = retime(eosDat, poPaired.datetime_local, 'mean');
eos_h = hours(eosDat.datetime_local - eosDat.datetime_local(1));
po_h = hours(poPaired.datetime_local - poPaired.datetime_local(1));

% for t0 = [0.5 1 2 3]
%     ind = elapsed_h > t0;
% 
%     fprintf('Start %0.1f h\n', t0)
%     fprintf(' Ref - Air = %0.2f ppm\n',mean(dRef(ind),'omitnan'))
%     fprintf(' Sample - Air = %0.2f ppm\n\n',mean(dSample(ind),'omitnan'))
% end

% Option to exclude initial data to allow complete equilibration of sensors
equil_h = 0; 
ind = po_h >= equil_h; 
dRef = eosPaired.ref_conc - poPaired.air_conc;
dSample = eosPaired.sample_conc - poPaired.air_conc;

% Save the mean and variability and cal info
eosOffsets.ref_avg = mean(dRef(ind),'omitnan');
eosOffsets.ref_std = std(dRef(ind),'omitnan');

eosOffsets.sample_avg = mean(dSample(ind),'omitnan');
eosOffsets.sample_std = std(dSample(ind),'omitnan');

eosOffsets.calibration_experiment = expName;
eosOffsets.equilibration_hours = equil_h;

% Create figures
ref_clr = '#8A2BE2';
sample_clr = '#FF00FF';
POair_clr = '#41b6c4';
POwater_clr = '#0000CD';
Tair_clr = rgb('orange');
Twater_clr = rgb('tomato');

fig1 = figure(1);clf
plot(eos_h,eosDat.ref_conc,'.','color',ref_clr,'DisplayName','Ref - Air')
hold on
plot(eos_h,eosDat.sample_conc,'.','color',sample_clr,'DisplayName','Sample - Air')
plot(po_h, poPaired.air_conc, 'o', 'markersize', 4, 'Color', POair_clr, 'DisplayName','Solu-Blu Air')
plot(po_h, poPaired.water_conc,'^', 'markersize', 4, 'Color', POwater_clr, 'DisplayName','Solu-Blu Water')
ylabel('CO_2 Concentration (ppm)')
xlabel('Hours Elapsed')
legend('show','location','best','NumColumns',2)
grid on
title(expName,'Interpreter','none')

start_ind = find(ind == 1, 1);
fig2 = figure(2);clf
plot(po_h,dRef,'o-','color',ref_clr,'DisplayName','Ref - Air')
hold on
plot(po_h,dSample,'o-','color',sample_clr,'DisplayName','Sample - Air')
line([po_h(start_ind) po_h(end)],[eosOffsets.ref_avg eosOffsets.ref_avg],'LineStyle','--','color',ref_clr,'LineWidth',2,'DisplayName','Mean(Ref - Air)')
line([po_h(start_ind) po_h(end)],[eosOffsets.sample_avg eosOffsets.sample_avg],'LineStyle','--','color',sample_clr,'LineWidth',2,'DisplayName','Mean(Sample - Air)')
xline(po_h(start_ind),'--k','LineWidth',2,'label','Start average','HandleVisibility','off')
ylabel('Offset from PO Air (ppm)')
xlabel('Hours Elapsed')
legend('show','location','best','NumColumns',2)
grid on
title(expName,'Interpreter','none')

% Option to save offset data and figure
calPath = fullfile(dataRoot, 'Offsets');
figPath = 'C:\Users\Emily\OneDrive - Dalhousie University\Google Drive Migration\Dal and MIT\Lab Experiments\Figures\Tank';

if ~exist(calPath, 'dir')
    mkdir(calPath)
end

option = questdlg('Save offset data and figure?','Save File','Yes','No','Yes');
switch option
    case 'Yes'
        save(fullfile(calPath, ['eosOffsets_',calDate,'.mat']), 'eosOffsets')
        disp('File saved!')

        exportgraphics(fig1,fullfile(figPath,[expName,'.png']))
        savefig(fig1,fullfile(figPath,[expName,'.fig']))
        exportgraphics(fig2,fullfile(figPath,[expName,'_results.png']))
        savefig(fig2,fullfile(figPath,[expName,'_results.fig']))
        disp('Figures saved!')
    case 'No'
        disp('File not saved')
end

