%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% plot_compiled_offsets.m
%
% Plot offset data from different experiments to assess whether there
% is a concentration dependence.
%
% AUTHOR: Emily Chua
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear; close all; clc

% -------------------------------------------------------------------------
% Setup
% -------------------------------------------------------------------------
% ---Load analysis-ready data file-----------------------------------------
dataRoot = 'C:\Users\Emily\OneDrive - Dalhousie University\Google Drive Migration\Dal and MIT\Lab Experiments\Data';

figPath = 'C:\Users\Emily\OneDrive - Dalhousie University\Google Drive Migration\Dal and MIT\Lab Experiments\Figures\Tank';

expFolders = {
    '2026-07-09_offset-test'
    '2026-07-14_offset-test'
    '2026-07-16_offset-test'
    '2026-07-16_offset-test-high'};

expLabel = {
    '2026-07-09'
    '2026-07-14'
    '2026-07-16_low'
    '2026-07-16_high'};

% Dark colors for Sample Node out of water
ref_dark = [138 43 226]/255;
sample_dark = [255 0 255]/255; 
% Light colors for Sample Node still sealed with water
ref_light = 0.5*ref_dark + 0.5*[1 1 1];
sample_light = 0.5*sample_dark + 0.5*[1 1 1];

POair_dark = [ 65 182 196]/255;

lblsize = 18;
lgdsize = 16;

allData = table();

% Fluxpi experiments
for i = 1:numel(expFolders)

    S = load(fullfile(dataRoot,expFolders{i},'processed',['allDat_' expFolders{i} '.mat']));

    eosDat = S.eosDat;
    poPaired = S.poPaired;

    eosPaired = retime(eosDat,poPaired.datetime_local,'nearest');

    T = table();

    T.Ca = poPaired.air_conc;

    T.SampleOffset = eosPaired.sample_conc - poPaired.air_conc;
    T.RefOffset = eosPaired.ref_conc - poPaired.air_conc;

    T.Experiment = repmat(string(expLabel{i}),height(T),1);

    allData = [allData;T];

    % figure,clf
    % plot(eosPaired.datetime_local,eosPaired.ref_conc,'.-','color',ref_dark,'DisplayName','Reference Conc')
    % hold on
    % plot(eosPaired.datetime_local,eosPaired.sample_conc,'.-','color',sample_dark,'DisplayName','Sample Conc')
    % plot(poPaired.datetime_local,poPaired.air_conc,'.-','color',POair_dark,'DisplayName','C_a')
    % ylabel('CO_2 Concentration (ppm)')
    % title(expLabel{i})
    % pause
end

% MIT experiment
expLabel = {'2026-02-13'};

S = load(fullfile(dataRoot,'2026-02-13_all-offsets-open-box-long','Merged','allDat.mat'));

TT_5min = S.TT_5min;

% Trim first 3 h 10 min
tStart = TT_5min.TIME(1);
TT_5min = TT_5min(TT_5min.TIME > tStart + hours(3) + minutes(10),:);

T = table();

T.Ca = TT_5min.miniATM_air_ppm;

T.SampleOffset = TT_5min.dal_sample_ppm - TT_5min.miniATM_air_ppm;
T.RefOffset = TT_5min.dal_ref_ppm - TT_5min.miniATM_air_ppm;

T.Experiment = repmat(string(expLabel),height(T),1);

allData = [allData;T];
% 
% figure,clf
% plot(TT_5min.TIME,TT_5min.dal_ref_ppm,'.-','color',ref_dark,'DisplayName','Reference Conc')
% hold on
% plot(TT_5min.TIME,TT_5min.dal_sample_ppm,'.-','color',sample_dark,'DisplayName','Sample Conc')
% plot(TT_5min.TIME,TT_5min.miniATM_air_ppm,'.-','color',POair_dark,'DisplayName','C_a')
% ylabel('CO_2 Concentration (ppm)')
% title(expLabel)

fig1 = figure(1);clf
hold on

exps = unique(allData.Experiment);
markers = {'d','^','o','p','s'};   % one marker per experiment

for i = 1:numel(exps)

    idx = allData.Experiment == exps(i);
    
    if i <= 3
        ref_clr = ref_light;
        sample_clr = sample_light;
    else
        ref_clr = ref_dark;
        sample_clr = sample_dark;
    end

    % Reference
    scatter(allData.Ca(idx), ...
        allData.RefOffset(idx), ...
        40, ref_clr, markers{i}, ...
        'LineWidth', 1.5, ...
        'DisplayName', sprintf('%s Ref', exps(i)));

    % Sample
    scatter(allData.Ca(idx), ...
        allData.SampleOffset(idx), ...
        40, sample_clr, markers{i}, ...
        'LineWidth', 1.5, ...
        'DisplayName', sprintf('%s Sample', exps(i)));

end

xlabel('PO Air CO_2 (ppm)')
ylabel('EOS − PO Offset (ppm)')

legend('Location','southeast','interpreter','none','NumColumns',height(exps))
grid on
box on

% Optional save figure
option = questdlg('Save Fig. 1?','Save Figure','Yes','No','Yes');
switch option
    case 'Yes'
        exportgraphics(fig1,fullfile(figPath,'QA_QC/Offsets/','compiled_offsets.png'),'Padding','tight')
        savefig(fig1,fullfile(figPath,'QA_QC/Offsets/','compiled_offsets.fig'))
        disp('Figures saved as .png and .fig!')
    case 'No'
        disp('Figures not saved')
end