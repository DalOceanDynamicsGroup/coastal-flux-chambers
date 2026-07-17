%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% determineEOSOffsets.m
%
% Compute eosFD Reference and Sample offsets from Pro-Oceanus air data.
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
dataRoot = 'G:\My Drive\Dal and MIT\Lab Experiments\Data\';
dialogTitle = 'Select an experiment data folder';
selPath = uigetdir(dataRoot,dialogTitle);

[~,expName] = fileparts(selPath);

eosDat = processEOSModbus(selPath,false);
poDat = processPO(selPath);

[eosDat,poPaired] = prepSensorData_fluxpi(selPath,eosDat,poDat);

% -------------------------------------------------------------------------
% Put EOS and PO air on common times
% -------------------------------------------------------------------------
eosPaired = retime(eosDat, poPaired.datetime_local, 'mean');
elapsed_h = hours(poPaired.datetime_local - poPaired.datetime_local(1));

% for t0 = [0.5 1 2 3]
%     ind = elapsed_h > t0;
% 
%     fprintf('Start %0.1f h\n', t0)
%     fprintf(' Ref - Air = %0.2f ppm\n',mean(dRef(ind),'omitnan'))
%     fprintf(' Sample - Air = %0.2f ppm\n\n',mean(dSample(ind),'omitnan'))
% end

% Exclude first 2 h to allow complete equilibration of sensors
equil_h = 2; 
ind = elapsed_h > equil_h; 
dRef = eosPaired.ref_conc - poPaired.Ca;
dSample = eosPaired.sample_conc - poPaired.Ca;

% Save the mean and variability and cal info
eosOffsets.ref_avg = mean(dRef(ind),'omitnan');
eosOffsets.ref_std = std(dRef(ind),'omitnan');

eosOffsets.sample_avg = mean(dSample(ind),'omitnan');
eosOffsets.sample_std = std(dSample(ind),'omitnan');

eosOffsets.calibration_experiment = expName;
eosOffsets.equilibration_hours = equil_h;

ref_clr = '#8A2BE2';
sample_clr = '#FF00FF';

figure
plot(elapsed_h,dRef,'o-','color',ref_clr)
hold on
plot(elapsed_h,dSample,'o-','color',sample_clr)
yline(mean(dRef,'omitmissing'),'k--')
yline(mean(dSample,'omitmissing'),'k--')
ylabel('Offset from PO Air (ppm)')
xlabel('Hours Elapsed')
legend('Ref - Air','Sample - Air')
grid on
title(expName,'Interpreter','none')

% Option to save offset data and figure
calPath = fullfile(dataRoot, 'Calibration');
figPath = 'G:\My Drive\Dal and MIT\Lab Experiments\Figures\Tank';

if ~exist(calPath, 'dir')
    mkdir(calPath)
end

option = questdlg('Save offset data and figure?','Save File','Yes','No','Yes');
switch option
    case 'Yes'
        save(fullfile(calPath, 'eosOffsets.mat'), 'eosOffsets')
        disp('File saved!')

        exportgraphics(gcf,fullfile(figPath,[expName,'_results.png']))
        savefig(gcf,fullfile(figPath,[expName,'_results.fig']))
    case 'No'
        disp('File not saved')
end

