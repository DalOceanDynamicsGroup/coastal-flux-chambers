clear;close all;clc

% Load MIT data file
cd('G:\My Drive\Dal and MIT\Lab Experiments\Data\MIT')
[filename,filepath] = uigetfile('*.csv','Select a CSV file');

dat_mit = readtable(filename);
dat_mit.TIME.TimeZone = 'America/New_York';
tt_mit = table2timetable(dat_mit); % Convert to timetable

% Remove rows where TIME = NaT
dat_mit(isnat(dat_mit.TIME),:) = [];

% Load Dal Eosense data
cd('G:\My Drive\Dal and MIT\Lab Experiments\Data\Eosense\Processed')
[filename,filepath] = uigetfile('*.mat','Select a .mat file');
dat_dal = load(filename);
tt_dal = dat_dal.raw;

% Define colors
mit_ref_clr = '#00441b';
mit_sample_clr = '#41ae76';
dal_ref_clr = '#4d004b';
dal_sample_clr = '#8c6bb1';

% % Plot data without uncertainties
% figure,clf
% plot(tt_mit.TIME,tt_mit.REFPCO2,'-','Color',mit_ref_clr,'DisplayName','MIT Reference')
% hold on
% plot(tt_mit.TIME,tt_mit.SAMPLEPCO2,'-','Color',mit_sample_clr,'DisplayName','MIT Sample')
% plot(tt_dal.datetime_local,tt_dal.conc_1,'-','Color',dal_ref_clr,'DisplayName','Dal Reference')
% plot(tt_dal.datetime_local,tt_dal.conc_2,'-','Color',dal_sample_clr,'DisplayName','Dal Sample')
% 
% xlabel('Local Time')
% ylabel('pCO_2 (ppm)')
% 
% grid on
% legend('show','location','best')
% 
% title('eosFD Offsets - Benchtest in Air')
% cd('G:\My Drive\Dal and MIT\Lab Experiments\Figures')
%%
% Plot data with uncertainties
figure,clf
eosense_err = 40*ones(height(tt_mit),1);        % ppm

h1 = shadedErrorBar(tt_mit.RUNTIME/3600,tt_mit.REFPCO2,eosense_err,'lineprops',{'-','color',mit_ref_clr},'patchSaturation',0.3);
h1.patch.FaceColor = mit_ref_clr;
set(h1.edge,'LineStyle','none')
h1.mainLine.DisplayName = 'MIT Reference';

hold on
h2 = shadedErrorBar(tt_mit.RUNTIME/3600,tt_mit.SAMPLEPCO2,eosense_err,'lineprops',{'-','color',mit_sample_clr},'patchSaturation',0.3);
h2.patch.FaceColor = mit_sample_clr;
set(h2.edge,'LineStyle','none')
h2.mainLine.DisplayName = 'MIT Sample';

eosense_err = 40*ones(height(tt_dal),1);        % ppm

h3 = shadedErrorBar(tt_dal.runtime/3600,tt_dal.conc_1,eosense_err,'lineprops',{'-','color',dal_ref_clr},'patchSaturation',0.3);
h3.patch.FaceColor = dal_ref_clr;
set(h3.edge,'LineStyle','none')
h3.mainLine.DisplayName = 'Dal Reference';

h4 = shadedErrorBar(tt_dal.runtime/3600,tt_dal.conc_2,eosense_err,'lineprops',{'-','color',dal_sample_clr},'patchSaturation',0.3);
h4.patch.FaceColor = dal_sample_clr;
set(h4.edge,'LineStyle','none')
h4.mainLine.DisplayName = 'Dal Sample';

xlabel('Run Time (h)')
ylabel('pCO_2 (ppm)')

grid on
legend('show','location','best')

title('eosFD Offsets - Bench Test in Air')

%%
% Find offset between Ref and Sample Nodes for each pair
offset_mit = mean(abs(tt_mit.REFPCO2 - tt_mit.SAMPLEPCO2));
offset_dal = mean(abs(tt_dal.conc_1 - tt_dal.conc_2));

% Find offset between mean of MIT pair and mean of Dal pair
% Retime timetables to same datetimes
newTimes = tt_dal.runtime;
tt_mit_retime = retime(tt_mit,uniqueTimes,'nearest');

mean_mit = mean([tt_mit_retime.REFPCO2,tt_mit_retime.SAMPLEPCO2],2);
mean_dal = mean([tt_dal.conc_1,tt_dal.conc_2],2);
offset_mit_dal = mean(abs(mean_mit - mean_dal));

disp(['MIT offset: ',num2str(offset_mit,3)])
disp(['Dal offset: ',num2str(offset_dal,3)])
disp(['MIT-Dal offset: ',num2str(offset_mit_dal,3)])