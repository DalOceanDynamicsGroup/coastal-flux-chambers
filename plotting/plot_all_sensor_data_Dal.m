clear;close all;clc

start_path = 'G:\My Drive\Dal and MIT\Lab Experiments\Data\';
dialog_title = 'Select an experiment data folder';
selpath = uigetdir(start_path,dialog_title);
[~,expt_name] = fileparts(selpath);
cd([selpath,'\merged'])
load('allDat.mat')

%--Calculate flux using concentrations from Dal eosFDs---------------------
% 1. Convert Eosense xCO2 (ppm) --> pCO2 (uatm)
pCO2ref = TT_5min.dal_ref_ppm .* TT_5min.miniATM_water_Pmbar / 1013.25;  % (uatm)
pCO2sample = TT_5min.dal_sample_ppm .* TT_5min.miniATM_water_Pmbar / 1013.25; % (uatm)
pCO2sample_corrected = TT_5min.dal_samplecorr_ppm .* TT_5min.miniATM_water_Pmbar / 1013.25; % (uatm)

% 2. Convert pCO2 (uatm) --> dissolved CO2 concentration (umol m-3) using Weiss, 1974
Tw = 20 + 273.15; % (K); didn't measure water temp, so assume it's 20oC
K0 = exp(-60.2409 + 93.4517*(100./Tw) + 23.3585*log(Tw./100));  % (mol L-1 atm-1); S = 0
K0 = repelem(K0,height(TT_5min))';

CO2ref = K0 .* pCO2ref * 10^3; % (umol m-3)
CO2sample = K0 .* pCO2sample * 10^3; % (umol m-3)
CO2sample_corrected = K0 .* pCO2sample_corrected * 10^3; % (umol m-3)

% 3. Compute the flux
G = 3.01E-4;        % (m s-1); input, from Eosense calibration note
calculated_flux_dal = G * (CO2sample - CO2ref);
corrected_flux_dal = G * (CO2sample_corrected - CO2ref);
%%
%--------------------------------------------------------------------------
% Plot the data
%--------------------------------------------------------------------------
% Define concentration uncertainties
dal_eos_err = 40*ones(height(TT_5min),1);             % ppm
miniATM_err = 0.03*2000*ones(height(TT_5min),1);     % ppm

% Define colors
dal_ref_clr = '#8A2BE2';
dal_sample_clr = '#FF00FF';
dal_flux_clr = '#8B008B';
miniATM_air_clr = '#41b6c4';
miniATM_water_clr = '#0000CD';

lblsize = 18;
lgdsize = 16;

alpha = 0.12;

% Plot as multi-panel figure
f = figure;clf
tiledlayout(2,1,'TileSpacing','tight','padding','tight')

ind_start = 10;
ind_end = height(TT_5min) - 20;

%--Plot CO2 concentrations-------------------------------------------------
ax1 = nexttile(1); grid on; box on
y_upper = TT_5min.miniATM_air_ppm + miniATM_err;
y_lower = TT_5min.miniATM_air_ppm - miniATM_err;
patch_x = [TT_5min.datetime_local; flipud(TT_5min.datetime_local)];
patch_y = [y_lower; flipud(y_upper)];
h7 = patch(patch_x, patch_y,'w','FaceAlpha', alpha, 'EdgeColor', 'none');
h7.Annotation.LegendInformation.IconDisplayStyle = 'off';
h7.FaceColor = miniATM_air_clr;
hold on
% plot(TT_5min.datetime_local, TT_5min.miniATM_air_ppm,'-','MarkerSize',2,'color',miniATM_air_clr,'DisplayName','Mini ATM - Air')
plot(TT_5min.datetime_local, TT_5min.miniATM_air_ppm,'-','MarkerSize',2,'color',miniATM_air_clr,'DisplayName','Pro-Oceanus Air')

y_upper = TT_5min.miniATM_water_ppm + miniATM_err;
y_lower = TT_5min.miniATM_water_ppm - miniATM_err;
patch_x = [TT_5min.datetime_local; flipud(TT_5min.datetime_local)];
patch_y = [y_lower; flipud(y_upper)];
h8 = patch(patch_x, patch_y,'w','FaceAlpha', alpha, 'EdgeColor', 'none');
h8.Annotation.LegendInformation.IconDisplayStyle = 'off';
h8.FaceColor = miniATM_water_clr;
% plot(TT_5min.datetime_local, TT_5min.miniATM_water_ppm,'-','MarkerSize',2,'color',miniATM_water_clr,'DisplayName','Mini ATM - Water')
plot(TT_5min.datetime_local, TT_5min.miniATM_water_ppm,'-','MarkerSize',2,'color',miniATM_water_clr,'DisplayName','Pro-Oceanus Water')

y_upper = TT_5min.dal_ref_ppm + dal_eos_err;
y_lower = TT_5min.dal_ref_ppm - dal_eos_err;
patch_x = [TT_5min.datetime_local; flipud(TT_5min.datetime_local)];
patch_y = [y_lower; flipud(y_upper)];
h5 = patch(patch_x, patch_y,'w','FaceAlpha', alpha, 'EdgeColor', 'none');
h5.Annotation.LegendInformation.IconDisplayStyle = 'off';
h5.FaceColor = dal_ref_clr;
plot(TT_5min.datetime_local, TT_5min.dal_ref_ppm,'-','color',dal_ref_clr,'DisplayName','eosFD Reference')

y_upper = TT_5min.dal_sample_ppm + dal_eos_err;
y_lower = TT_5min.dal_sample_ppm - dal_eos_err;
patch_x = [TT_5min.datetime_local; flipud(TT_5min.datetime_local)];
patch_y = [y_lower; flipud(y_upper)];
h6 = patch(patch_x, patch_y,'w','FaceAlpha', alpha, 'EdgeColor', 'none');
h6.Annotation.LegendInformation.IconDisplayStyle = 'off';
h6.FaceColor = dal_sample_clr;
plot(TT_5min.datetime_local, TT_5min.dal_sample_ppm,'-','color',dal_sample_clr,'DisplayName','eosFD Sample')

xline(datetime(2026,01,31,8,00,00,'TimeZone','America/Halifax'),'--','Sunrise','linewidth',2,'FontSize',lgdsize,'LabelVerticalAlignment','bottom','handlevisibility','off')
xline(datetime(2026,01,31,17,00,00,'TimeZone','America/Halifax'),'--','Sunset','linewidth',2,'FontSize',lgdsize,'LabelVerticalAlignment','bottom','handlevisibility','off')
xline(datetime(2026,02,01,8,00,00,'TimeZone','America/Halifax'),'--','Sunrise','linewidth',2,'FontSize',lgdsize,'LabelVerticalAlignment','bottom','handlevisibility','off')
xline(datetime(2026,02,01,17,00,00,'TimeZone','America/Halifax'),'--','Sunset','linewidth',2,'FontSize',lgdsize,'LabelVerticalAlignment','bottom','handlevisibility','off')
xline(datetime(2026,02,02,8,00,00,'TimeZone','America/Halifax'),'--','Sunrise','linewidth',2,'FontSize',lgdsize,'LabelVerticalAlignment','bottom','handlevisibility','off')

xticklabels(ax1,{})
ax1.FontSize = lblsize;
ylabel('CO_2 Concentration (ppm)','FontSize',lblsize)

lgd = legend('show','location','north');
lgd.NumColumns = 2;
lgd.FontSize = lgdsize;

xlim([TT_5min.datetime_local(ind_start) TT_5min.datetime_local(ind_end)])
ylim([350 600])

% nexttile(2); grid on; box on
% yyaxis left
% plot(TT_5min.datetime_local,TT_5min.dal_ref_T,'DisplayName','Reference T')
% hold on
% plot(TT_5min.datetime_local,TT_5min.dal_sample_T,'g','DisplayName','Sample T')

% yyaxis right
% % plot(TT_5min.datetime_local,TT_5min.)
% legend('show')
% xlim([TT_5min.datetime_local(ind_start) TT_5min.datetime_local(ind_end)])
% grid on
% xline(datetime(2026,01,31,8,00,00,'TimeZone','America/Halifax'),'--','linewidth',2,'handlevisibility','off')
% xline(datetime(2026,01,31,17,00,00,'TimeZone','America/Halifax'),'--','linewidth',2,'handlevisibility','off')
% xline(datetime(2026,02,01,8,00,00,'TimeZone','America/Halifax'),'--','linewidth',2,'handlevisibility','off')
% xline(datetime(2026,02,01,17,00,00,'TimeZone','America/Halifax'),'--','linewidth',2,'handlevisibility','off')
% xline(datetime(2026,02,02,8,00,00,'TimeZone','America/Halifax'),'--','linewidth',2,'handlevisibility','off')

%--Plot fluxes-------------------------------------------------------------
dal_flux_err = 0.2*ones(height(TT_5min),1);  % (umol m-2 s-1)

valid = ~isnan(corrected_flux_dal);

ax2 = nexttile(2); grid on; box on
yline(0,'Color','k','LineWidth',2,'HandleVisibility','off')
hold on

% Dal - provided flux
% y_upper = TT_5min.dal_eos_flux + dal_flux_err;
% y_lower = TT_5min.dal_eos_flux - dal_flux_err;
% patch_x = [TT_5min.datetime_local; flipud(TT_5min.datetime_local)];
% patch_y = [y_lower; flipud(y_upper)];
% h9 = patch(patch_x,patch_y,'w','FaceAlpha',alpha,'EdgeColor','none');
% h9.Annotation.LegendInformation.IconDisplayStyle = 'off';
% h9.FaceColor = dal_sample_clr;
% plot(TT_5min.datetime_local,TT_5min.flux_sample,'--','color',dal_sample_clr,'DisplayName','Dal Provided Flux')

% Dal - calculated, bias-corrected flux
y_upper = corrected_flux_dal(valid) + dal_flux_err(valid);
y_lower = corrected_flux_dal(valid) - dal_flux_err(valid);
patch_x = [TT_5min.datetime_local(valid); flipud(TT_5min.datetime_local(valid))];
patch_y = [y_lower; flipud(y_upper)];
h10 = patch(patch_x,patch_y,'w','FaceAlpha',alpha,'EdgeColor','none');
h10.Annotation.LegendInformation.IconDisplayStyle = 'off';
h10.FaceColor = dal_flux_clr;
plot(TT_5min.datetime_local,corrected_flux_dal,'-','color',dal_flux_clr,'DisplayName','eosFD Corrected Flux')

xline(datetime(2026,01,31,8,00,00,'TimeZone','America/Halifax'),'--','linewidth',2,'FontSize',lgdsize,'LabelVerticalAlignment','bottom','handlevisibility','off')
xline(datetime(2026,01,31,17,00,00,'TimeZone','America/Halifax'),'--','linewidth',2,'FontSize',lgdsize,'LabelVerticalAlignment','bottom','handlevisibility','off')
xline(datetime(2026,02,01,8,00,00,'TimeZone','America/Halifax'),'--','linewidth',2,'FontSize',lgdsize,'LabelVerticalAlignment','bottom','handlevisibility','off')
xline(datetime(2026,02,01,17,00,00,'TimeZone','America/Halifax'),'--','linewidth',2,'FontSize',lgdsize,'LabelVerticalAlignment','bottom','handlevisibility','off')
xline(datetime(2026,02,02,8,00,00,'TimeZone','America/Halifax'),'--','linewidth',2,'FontSize',lgdsize,'LabelVerticalAlignment','bottom','handlevisibility','off')

ylabel('Flux (\mumol m^{-2} s^{-1})','FontSize',lblsize)

lgd = legend('show','location','north');
lgd.FontSize = lgdsize;

xlim([TT_5min.datetime_local(ind_start) TT_5min.datetime_local(ind_end)])
% ylim([-0.3 0.3])
ylim([-0.45 0.25])
ax2.FontSize = lblsize;
xlabel('Local Time','FontSize',lblsize)

set(f,"Position",[3 929 1533 700])

%% -------------------------------------------------------------------------
% Save plot - make sure to change folder and label!!
%--------------------------------------------------------------------------
cd('G:\My Drive\Dal and MIT\Lab Experiments\Figures\Kelp Tank') % INPUT

label = 'kelp-tank_data';   % INPUT
imageName = [label,'.png'];
figName = [label,'.fig'];
exportgraphics(gcf, imageName, 'ContentType', 'image', 'BackgroundColor', 'white');
savefig(figName)