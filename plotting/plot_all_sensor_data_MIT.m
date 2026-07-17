%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% plot_all_sensor_data_MIT.m
% This script plots the timeseries data from the eosFDs, Pro-Oceanus and 
% Turner sensors, as obtained with the MIT experimental setup.
%
% AUTHOR: Emily Chua
%
% DATE:
% First created: 3/26/26
% Last updated:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear;close all;clc

% -------------------------------------------------------------------------
% Load the merged data file
% -------------------------------------------------------------------------
start_path = 'G:\My Drive\Dal and MIT\Lab Experiments\Data\';
dialog_title = 'Select an experiment data folder';
selpath = uigetdir(start_path,dialog_title);
[~,expt_name] = fileparts(selpath);
cd([selpath,'\merged'])
load('allDat.mat')

%--------------------------------------------------------------------------
% Set path for saving figures
%--------------------------------------------------------------------------
switch expt_name
    case '2026-02-13_all-offsets-open-box-long'
        fig_path = 'G:\My Drive\Dal and MIT\Lab Experiments\Figures\MIT\Offset Tests';
    case '2026-02-12_CO2-pulse-large'
        fig_path = 'G:\My Drive\Dal and MIT\Lab Experiments\Figures\MIT\Expt - Large CO2 Pulse';
    case '2026-02-17_CO2-pulse-small'
        fig_path = 'G:\My Drive\Dal and MIT\Lab Experiments\Figures\MIT\Expt - Small CO2 Pulse';
    case '2026-02-19_CO2-pulse-large-turbulent'
        fig_path = 'G:\My Drive\Dal and MIT\Lab Experiments\Figures\MIT\Expt - Large Turbulent CO2 Pulse';
end

%--------------------------------------------------------------------------
% Set start and end times
%--------------------------------------------------------------------------
switch expt_name
    case '2026-02-13_all-offsets-open-box-long'
        ind_start = 49;
        TT_5min(1:ind_start,:) = [];
        ind_stop = height(TT_5min);
    case '2026-02-12_CO2-pulse-large'
        ind_start = 1;
        TT_5min(1:ind_start,:) = [];
        ind_stop = height(TT_5min);
    case '2026-02-17_CO2-pulse-small'
        ind_start = 45;
        TT_5min(1:ind_start,:) = [];
        ind_stop = height(TT_5min);
    case '2026-02-19_CO2-pulse-large-turbulent'
        ind_start = 41;
        TT_5min(1:ind_start,:) = [];
        ind_stop = 280;
end

reltime = hours(TT_5min.TIME - TT_5min.TIME(1));

% -------------------------------------------------------------------------
% Unpack data
% -------------------------------------------------------------------------
nodes.Dal.name = 'Dal';
nodes.Dal.Cr = TT_5min.dal_ref_ppm;
nodes.Dal.Cs = TT_5min.dal_sample_ppm;
nodes.Dal.Ca = TT_5min.miniATM_air_ppm;
nodes.Dal.Cw = TT_5min.miniCO2_water_ppm;

nodes.MIT.name = 'MIT';
nodes.MIT.Cr = TT_5min.mit_ref_ppm;
nodes.MIT.Cs = TT_5min.mit_samplecorr_ppm;
nodes.MIT.Cw = TT_5min.miniCO2_water_ppm;

%--------------------------------------------------------------------------
% Define plotting conventions
%--------------------------------------------------------------------------
% Define plot limits
x1 = 0;  
x2 = 18;
y1 = 200;
y2 = 1300;

% Define uncertainties
mit_eos_err = 40*ones(height(TT_5min),1);           % ppm
mit_pro_err = 0.03*1000*ones(height(TT_5min),1);    % ppm
turner_err = 0.03*1000*ones(height(TT_5min),1);     % ppm
dal_eos_err = 40*ones(height(TT_5min),1);           % ppm
pro_air_err = 0.03*2000*ones(height(TT_5min),1);    % ppm
pro_water_err = 0.03*2000*ones(height(TT_5min),1);  % ppm

% Define colors
mit_ref_clr = '#00441b';
mit_sample_clr = '#41ae76';
miniCO2_clr = '#7FFFD4';
turner_clr = '#ec7014';
dal_ref_clr = '#8A2BE2';
dal_sample_clr = '#FF00FF';
dal_flux_clr = '#8B008B';
miniATM_air_clr = '#41b6c4';
miniATM_water_clr = '#0000CD';

alpha = 0.12;

lblsize = 18;
lgdsize = 16;

%%
%--------------------------------------------------------------------------
% OFFSET TEST ONLY: Calculate offsets and plot data
%--------------------------------------------------------------------------
eos_dal_offset = mean((nodes.Dal.Cs(ind_start:end) - nodes.Dal.Cr(ind_start:end)),'omitmissing');
eos_dal_sd = std((nodes.Dal.Cs(ind_start:end) - nodes.Dal.Cr(ind_start:end)),'omitmissing');
disp(['Dal eosFD offset: ',num2str(eos_dal_offset,3),' +/- ',num2str(eos_dal_sd,3)])

eos_mit_offset = mean((nodes.MIT.Cs(ind_start:end) - nodes.MIT.Cr(ind_start:end)),'omitmissing');
eos_mit_sd = std((nodes.MIT.Cs(ind_start:end) - nodes.MIT.Cr(ind_start:end)),'omitmissing');
disp(['MIT eosFD offset: ',num2str(eos_mit_offset,3),' +/- ',num2str(eos_mit_sd,3)])

miniATM_offset = mean((nodes.Dal.Cw(ind_start:end) - nodes.Dal.Ca(ind_start:end)),'omitmissing');
miniATM_sd = std((nodes.Dal.Cw(ind_start:end) - nodes.Dal.Ca(ind_start:end)),'omitmissing');
disp(['Pro-Oceanus Mini ATM offset: ',num2str(miniATM_offset,3),' +/- ',num2str(miniATM_sd,3)])

dal_Cs_Ca_offset = mean((nodes.Dal.Cs(ind_start:end) - nodes.Dal.Ca(ind_start:end)),'omitmissing');
dal_Cs_Ca_sd = std((nodes.Dal.Cs(ind_start:end) - nodes.Dal.Ca(ind_start:end)),'omitmissing');
disp(['Dal Sample-PO offset: ',num2str(dal_Cs_Ca_offset,3),' +/- ',num2str(dal_Cs_Ca_sd,3)])

dal_Cr_Ca_offset = mean((nodes.Dal.Cr(ind_start:end) - nodes.Dal.Ca(ind_start:end)),'omitmissing');
dal_Cr_Ca_sd = std((nodes.Dal.Cr(ind_start:end) - nodes.Dal.Ca(ind_start:end)),'omitmissing');
disp(['Dal Ref-PO offset: ',num2str(dal_Cr_Ca_offset,3),' +/- ',num2str(dal_Cr_Ca_sd,3)])

mit_Cs_Ca_offset = mean((nodes.MIT.Cs(ind_start:end) - nodes.Dal.Ca(ind_start:end)),'omitmissing');
mit_Cs_Ca_sd = std((nodes.MIT.Cs(ind_start:end) - nodes.Dal.Ca(ind_start:end)),'omitmissing');
disp(['MIT Sample-PO offset: ',num2str(mit_Cs_Ca_offset,3),' +/- ',num2str(mit_Cs_Ca_sd,3)])

mit_Cr_Ca_offset = mean((nodes.MIT.Cr(ind_start:end) - nodes.Dal.Ca(ind_start:end)),'omitmissing');
mit_Cr_Ca_sd = std((nodes.MIT.Cr(ind_start:end) - nodes.Dal.Ca(ind_start:end)),'omitmissing');
disp(['MIT Ref-PO offset: ',num2str(mit_Cr_Ca_offset,3),' +/- ',num2str(mit_Cr_Ca_sd,3)])

fig = figure;clf
plot(reltime, TT_5min.mit_ref_ppm,'-','color',mit_ref_clr,'DisplayName','MIT eosFD Reference')
hold on
plot(reltime, TT_5min.mit_sample_ppm,'-','color',mit_sample_clr,'DisplayName','MIT eosFD Sample')
plot(reltime, TT_5min.dal_ref_ppm,'-','color',dal_ref_clr,'DisplayName','Dal eosFD Reference')
plot(reltime, TT_5min.dal_sample_ppm,'-','color',dal_sample_clr,'DisplayName','Dal eosFD Sample')
plot(reltime, TT_5min.miniATM_air_ppm,'-','MarkerSize',2,'color',miniATM_air_clr,'DisplayName','Pro-Oceanus Mini ATM Air')
plot(reltime, TT_5min.miniATM_water_ppm,'-','MarkerSize',2,'color',rgb('darkblue'),'DisplayName','Pro-Oceanus Mini ATM Water')
xlabel('Hours Elapsed','FontSize',lblsize)
ylabel('CO_2 Concentration (ppm)','FontSize',lblsize)
ax = gca;
ax.FontSize = lblsize;
lgd = legend('show','location','northeast');
lgd.NumColumns = 3;
lgd.FontSize = lgdsize;
grid on; box on
ax = gca;
ax.XMinorGrid = 'on';
ax.XAxis.MinorTick = 'on';

% txt1 = ['Dal eosFD mean offset = ',num2str(eos_dal_offset,2), ' +/- ', num2str(eos_dal_sd,2),' ppm'];
% text(reltime(100), 550, txt1, 'FontSize', 12)
% txt1 = ['MIT eosFD mean offset = ',num2str(eos_mit_offset,2), ' +/- ', num2str(eos_mit_sd,2),' ppm'];
% text(reltime(100), 543, txt1, 'FontSize', 12)
% txt1 = ['Pro-Oceanus Mini ATM mean offset = ',num2str(miniATM_offset,2), ' +/- ', num2str(miniATM_sd,2),' ppm'];
% text(reltime(100), 536, txt1, 'FontSize', 12)

txt1 = ['Dal C_s - C_a mean offset = ',num2str(dal_Cs_Ca_offset,2), ' +/- ', num2str(dal_Cs_Ca_sd,2),' ppm'];
text(reltime(5), 550, txt1, 'FontSize', 12)
txt1 = ['Dal C_r - C_a mean offset = ',num2str(dal_Cr_Ca_offset,2), ' +/- ', num2str(dal_Cr_Ca_sd,2),' ppm'];
text(reltime(5), 543, txt1, 'FontSize', 12)
txt1 = ['MIT C_s - C_a mean offset = ',num2str(mit_Cs_Ca_offset,2), ' +/- ', num2str(mit_Cs_Ca_sd,2),' ppm'];
text(reltime(5), 536, txt1, 'FontSize', 12)
txt1 = ['MIT C_r - C_a mean offset = ',num2str(mit_Cr_Ca_offset,2), ' +/- ', num2str(mit_Cr_Ca_sd,2),' ppm'];
text(reltime(5), 529, txt1, 'FontSize', 12)

% Optional save figure as .png
% cd(fig_path)
% exportgraphics(gcf,'select_sensor_concentrations.png','Padding','tight')
% savefig(gcf,'select_sensor_concentrations.fig')

%%
%--------------------------------------------------------------------------
% Plot CO2 concentration data without uncertainty bounds for all sensors
%--------------------------------------------------------------------------
fig = figure;clf
plot(reltime, TT_5min.mit_ref_ppm,'-','color',mit_ref_clr,'DisplayName','MIT eosFD Reference')
hold on
plot(reltime, TT_5min.mit_samplecorr_ppm,'-','color',mit_sample_clr,'DisplayName','MIT eosFD Sample')
plot(reltime, TT_5min.miniCO2_water_ppm, '-', 'color', miniCO2_clr,'DisplayName', 'Pro-Oceanus Mini CO_2')
plot(reltime, TT_5min.turner_ppm,'-','color',turner_clr,'DisplayName','Turner')
plot(reltime, TT_5min.dal_ref_ppm,'-','color',dal_ref_clr,'DisplayName','Dal eosFD Reference')
plot(reltime, TT_5min.dal_samplecorr_ppm,'-','color',dal_sample_clr,'DisplayName','Dal eosFD Sample')
plot(reltime, TT_5min.miniATM_air_ppm,'-','MarkerSize',2,'color',miniATM_air_clr,'DisplayName','Pro-Oceanus Mini ATM Air')
plot(reltime, TT_5min.miniATM_water_ppm,'-','MarkerSize',2,'color',miniATM_water_clr,'DisplayName','Pro-Oceanus Mini ATM Water')
xlabel('Hours Elapsed','FontSize',lblsize)
ylabel('CO_2 Concentration (ppm)','FontSize',lblsize)
lgd = legend('show','location','southeast');
lgd.NumColumns = 4;
lgd.FontSize = lgdsize;
ax = gca;
ax.FontSize = lblsize;
grid on; box on
ax = gca;
ax.XMinorGrid = 'on';
ax.XAxis.MinorTick = 'on';
xlim([x1 x2])
ylim([y1 y2])

% Optional save figure as .png
cd(fig_path)
exportgraphics(gcf,'all_sensor_concentrations.png','Padding','tight')
savefig(gcf,'all_sensor_concentrations.fig')

%%
%--------------------------------------------------------------------------
% Plot CO2 concentrations with uncertainy bounds for all sensors
%--------------------------------------------------------------------------
fig = figure;clf
y_upper = TT_5min.mit_ref_ppm + mit_eos_err;
y_lower = TT_5min.mit_ref_ppm - mit_eos_err;
patch_x = [reltime; flipud(reltime)];
patch_y = [y_lower; flipud(y_upper)];
h1 = patch(patch_x, patch_y,'w','FaceAlpha', alpha, 'EdgeColor', 'none');
h1.Annotation.LegendInformation.IconDisplayStyle = 'off';
h1.FaceColor = mit_ref_clr;
hold on
plot(reltime, TT_5min.mit_ref_ppm,'-','color',mit_ref_clr,'DisplayName','MIT eosFD Reference')

y_upper = TT_5min.mit_sample_ppm + mit_eos_err;
y_lower = TT_5min.mit_sample_ppm - mit_eos_err;
patch_x = [reltime; flipud(reltime)];
patch_y = [y_lower; flipud(y_upper)];
h2 = patch(patch_x, patch_y,'w','FaceAlpha', alpha, 'EdgeColor', 'none');
h2.Annotation.LegendInformation.IconDisplayStyle = 'off';
h2.FaceColor = mit_sample_clr;
plot(reltime, TT_5min.mit_sample_ppm,'-','color',mit_sample_clr,'DisplayName','MIT eosFD Sample')

y_upper = TT_5min.dal_ref_ppm + dal_eos_err;
y_lower = TT_5min.dal_ref_ppm - dal_eos_err;
patch_x = [reltime; flipud(reltime)];
patch_y = [y_lower; flipud(y_upper)];
h5 = patch(patch_x, patch_y,'w','FaceAlpha', alpha, 'EdgeColor', 'none');
h5.Annotation.LegendInformation.IconDisplayStyle = 'off';
h5.FaceColor = dal_ref_clr;
plot(reltime, TT_5min.dal_ref_ppm,'-','color',dal_ref_clr,'DisplayName','Dal eosFD Reference')

y_upper = TT_5min.dal_sample_ppm + dal_eos_err;
y_lower = TT_5min.dal_sample_ppm - dal_eos_err;
patch_x = [reltime; flipud(reltime)];
patch_y = [y_lower; flipud(y_upper)];
h6 = patch(patch_x, patch_y,'w','FaceAlpha', alpha, 'EdgeColor', 'none');
h6.Annotation.LegendInformation.IconDisplayStyle = 'off';
h6.FaceColor = dal_sample_clr;
plot(reltime, TT_5min.dal_sample_ppm,'-','color',dal_sample_clr,'DisplayName','Dal eosFD Sample')

y_upper = TT_5min.miniCO2_water_ppm + mit_pro_err;
y_lower = TT_5min.miniCO2_water_ppm - mit_pro_err;
patch_x = [reltime; flipud(reltime)];
patch_y = [y_lower; flipud(y_upper)];
h3 = patch(patch_x, patch_y, 'w', 'FaceAlpha', alpha, 'EdgeColor', 'none');
h3.Annotation.LegendInformation.IconDisplayStyle = 'off';
h3.FaceColor = miniCO2_clr;
plot(reltime, TT_5min.miniCO2_water_ppm, '-', 'color', miniCO2_clr,'DisplayName', 'Pro-Oceanus Mini CO_2')

y_upper = TT_5min.turner_ppm + turner_err;
y_lower = TT_5min.turner_ppm - turner_err;
patch_x = [reltime; flipud(reltime)];
patch_y = [y_lower; flipud(y_upper)];
h4 = patch(patch_x, patch_y,'w','FaceAlpha', alpha, 'EdgeColor', 'none');
h4.Annotation.LegendInformation.IconDisplayStyle = 'off';
h4.FaceColor = turner_clr;
plot(reltime, TT_5min.turner_ppm,'-','color',turner_clr,'DisplayName','Turner')

y_upper = TT_5min.miniATM_air_ppm + pro_air_err;
y_lower = TT_5min.miniATM_air_ppm - pro_air_err;
patch_x = [reltime; flipud(reltime)];
patch_y = [y_lower; flipud(y_upper)];
h7 = patch(patch_x, patch_y,'w','FaceAlpha', alpha, 'EdgeColor', 'none');
h7.Annotation.LegendInformation.IconDisplayStyle = 'off';
h7.FaceColor = miniATM_air_clr;
plot(reltime, TT_5min.miniATM_air_ppm,'-','MarkerSize',2,'color',miniATM_air_clr,'DisplayName','Pro-Oceanus Mini ATM Air')

y_upper = TT_5min.miniATM_water_ppm + pro_water_err;
y_lower = TT_5min.miniATM_water_ppm - pro_water_err;
patch_x = [reltime; flipud(reltime)];
patch_y = [y_lower; flipud(y_upper)];
h8 = patch(patch_x, patch_y,'w','FaceAlpha', alpha, 'EdgeColor', 'none');
h8.Annotation.LegendInformation.IconDisplayStyle = 'off';
h8.FaceColor = miniATM_water_clr;
plot(reltime, TT_5min.miniATM_water_ppm,'-','MarkerSize',2,'color',miniATM_water_clr,'DisplayName','Pro-Oceanus Mini ATM Water')

xlabel('Hours Elapsed','FontSize',24)
ylabel('CO_2 Concentration (ppm)','FontSize',24)
ax.FontSize = lblsize;
ax = gca;
ax.XMinorGrid = 'on';
ax.XAxis.MinorTick = 'on';

lgd = legend('show','location','southeast');
lgd.NumColumns = 4;
lgd.FontSize = lgdsize;
grid on; box on

xlim([x1 x2])
ylim([y1 y2])

% Optional save figure as .png
% cd(fig_path)
% exportgraphics(gcf,'all_sensor_concentrations_shaded.png','Padding','tight')
% savefig(gcf,'all_sensor_concentrations_shaded.fig')
