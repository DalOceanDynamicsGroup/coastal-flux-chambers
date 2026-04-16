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
% Optional: Trim data if messy
%--------------------------------------------------------------------------
% startDateTime = datetime('2026-02-12 16:30','TimeZone','America/New_York');
% timeDifferences = abs(TT_5min.TIME - startDateTime);
% [~,ind_start] = min(timeDifferences);
% endDateTime = datetime('','TimeZone','local');
% timeDifferences = abs(TT_5min.TIME - endDateTime);
% [~,ind_end] = min(timeDifferences);
% TT_5min(ind_start:ind_end,:) = [];

%--------------------------------------------------------------------------
% Calculate flux using eosFD concentrations
%--------------------------------------------------------------------------
% ---Using concentrations from MIT eosFDs----------------------------------
% 1. Convert Eosense xCO2 (ppm) --> pCO2 (uatm)
pCO2ref = TT_5min.mit_ref_ppm .* TT_5min.miniATM_water_Pmbar / 1013.25;  % (uatm)
pCO2sample = TT_5min.mit_sample_ppm .* TT_5min.miniATM_water_Pmbar / 1013.25; % (uatm)
pCO2sample_corrected = TT_5min.mit_samplecorr_ppm .* TT_5min.miniATM_water_Pmbar / 1013.25; % (uatm)

% 2. Convert pCO2 (uatm) --> dissolved CO2 concentration (umol m-3) using Weiss, 1974
% Reference Node
Tref = TT_5min.mit_ref_T + 273.15; % (K)
K0 = exp(-60.2409 + 93.4517*(100./Tref) + 23.3585*log(Tref./100));  % (mol L-1 atm-1); S = 0
Cref = K0 .* pCO2ref * 10^3; % (umol m-3)
% Sample Node
T_sample = TT_5min.mit_sample_T + 273.15; % (K)
K0 = exp(-60.2409 + 93.4517*(100./T_sample) + 23.3585*log(T_sample./100));  % (mol L-1 atm-1); S = 0
Csample = K0 .* pCO2sample * 10^3; % (umol m-3)
Csample_corrected = K0 .* pCO2sample_corrected * 10^3; % (umol m-3)

% 3. Compute the flux
G = 3.01E-4;        % (m s-1); input, from Eosense calibration note
calculated_flux_mit = G * (Csample - Cref);             % (umol m-2 s-1)
corrected_flux_mit = G * (Csample_corrected - Cref);    % (umol m-2 s-1)

% ---Using concentrations from Dal eosFDs----------------------------------
% 1. Convert Eosense xCO2 (ppm) --> pCO2 (uatm)
pCO2ref = TT_5min.dal_ref_ppm .* TT_5min.miniATM_water_Pmbar / 1013.25;  % (uatm)
pCO2sample = TT_5min.dal_sample_ppm .* TT_5min.miniATM_water_Pmbar / 1013.25; % (uatm)
pCO2sample_corrected = TT_5min.dal_samplecorr_ppm .* TT_5min.miniATM_water_Pmbar / 1013.25; % (uatm)

% 2. Convert pCO2 (uatm) --> dissolved CO2 concentration (umol m-3) using Weiss, 1974
% Reference Node
Tref = TT_5min.dal_ref_T + 273.15; % (K)
K0 = exp(-60.2409 + 93.4517*(100./Tref) + 23.3585*log(Tref./100));  % (mol L-1 atm-1); S = 0
Cref = K0 .* pCO2ref * 10^3; % (umol m-3)
% Sample Node
T_sample = TT_5min.dal_sample_T + 273.15; % (K)
K0 = exp(-60.2409 + 93.4517*(100./T_sample) + 23.3585*log(T_sample./100));  % (mol L-1 atm-1); S = 0
Csample = K0 .* pCO2sample * 10^3; % (umol m-3)
Csample_corrected = K0 .* pCO2sample_corrected * 10^3;  % (umol m-3)

% 3. Compute the flux
calculated_flux_dal = G * (Csample - Cref);             % (umol m-2 s-1)
corrected_flux_dal = G * (Csample_corrected - Cref);    % (umol m-2 s-1)

%--------------------------------------------------------------------------
% Plot the data
%--------------------------------------------------------------------------
cd('G:\My Drive\Dal and MIT\Lab Experiments\Figures\MIT')

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

%%
%--------------------------------------------------------------------------
% Plot offset test data (Calculate and display offsets)
%--------------------------------------------------------------------------
fig1 = figure;clf
plot(TT_5min.TIME, TT_5min.mit_ref_ppm,'-','color',mit_ref_clr,'DisplayName','MIT eosFD Reference')
hold on
plot(TT_5min.TIME, TT_5min.mit_sample_ppm,'-','color',mit_sample_clr,'DisplayName','MIT eosFD Sample')
plot(TT_5min.TIME, TT_5min.dal_ref_ppm,'-','color',dal_ref_clr,'DisplayName','Dal eosFD Reference')
plot(TT_5min.TIME, TT_5min.dal_sample_ppm,'-','color',dal_sample_clr,'DisplayName','Dal eosFD Sample')
plot(TT_5min.TIME, TT_5min.miniATM_air_ppm,'-','MarkerSize',2,'color',miniATM_air_clr,'DisplayName','Pro-Oceanus Mini ATM - Air Phase')
plot(TT_5min.TIME, TT_5min.miniATM_water_ppm,'-','MarkerSize',2,'color',rgb('darkblue'),'DisplayName','Pro-Oceanus Mini ATM - Water Phase')
ylabel('CO_2 Concentration (ppm)')
grid on; box on
lgd = legend('show','location','northoutside');
lgd.NumColumns = 3;

start_ind = 49;

eos_dal_offset = mean((TT_5min.dal_sample_ppm(start_ind:end) - TT_5min.dal_ref_ppm(start_ind:end)),'omitmissing');
eos_dal_sd = std((TT_5min.dal_sample_ppm(start_ind:end) - TT_5min.dal_ref_ppm(start_ind:end)),'omitmissing');
disp(['Dal eosFD offset: ',num2str(eos_dal_offset,3),' +/- ',num2str(eos_dal_sd,3)])

eos_mit_offset = mean((TT_5min.mit_sample_ppm(start_ind:end) - TT_5min.mit_ref_ppm(start_ind:end)),'omitmissing');
eos_mit_sd = std((TT_5min.mit_sample_ppm(start_ind:end) - TT_5min.mit_ref_ppm(start_ind:end)),'omitmissing');
disp(['MIT eosFD offset: ',num2str(eos_mit_offset,3),' +/- ',num2str(eos_mit_sd,3)])

miniATM_offset = mean((TT_5min.miniATM_water_ppm(start_ind:end) - TT_5min.miniATM_air_ppm(start_ind:end)),'omitmissing');
miniATM_sd = std((TT_5min.miniATM_water_ppm(start_ind:end) - TT_5min.miniATM_air_ppm(start_ind:end)),'omitmissing');
disp(['Pro-Oceanus Mini ATM offset: ',num2str(miniATM_offset,3),' +/- ',num2str(miniATM_sd,3)])

xlim([TT_5min.TIME(start_ind) TT_5min.TIME(end)])

txt1 = ['Dal eosFD mean offset = ',num2str(eos_dal_offset,2), ' +/- ', num2str(eos_dal_sd,2),' ppm'];
text(TT_5min.TIME(100), 550, txt1, 'FontSize', 12)
txt1 = ['MIT eosFD mean offset = ',num2str(eos_mit_offset,2), ' +/- ', num2str(eos_mit_sd,2),' ppm'];
text(TT_5min.TIME(100), 543, txt1, 'FontSize', 12)
txt1 = ['Pro-Oceanus Mini ATM mean offset = ',num2str(miniATM_offset,2), ' +/- ', num2str(miniATM_sd,2),' ppm'];
text(TT_5min.TIME(100), 536, txt1, 'FontSize', 12)

%%
%--------------------------------------------------------------------------
% Plot CO2 concentration data without uncertainty bounds for all sensors
%--------------------------------------------------------------------------
fig1 = figure;clf
plot(TT_5min.TIME, TT_5min.mit_ref_ppm,'-','color',mit_ref_clr,'DisplayName','MIT eosFD Reference')
hold on
plot(TT_5min.TIME, TT_5min.mit_samplecorr_ppm,'-','color',mit_sample_clr,'DisplayName','MIT eosFD Sample (corrected)')
% plot(TT_5min.TIME, TT_5min.miniCO2_water_ppm, '-', 'color', miniCO2_clr,'DisplayName', 'Pro-Oceanus Mini CO_2')
% plot(TT_5min.TIME, TT_5min.turner_ppm,'-','color',turner_clr,'DisplayName','Turner')
plot(TT_5min.TIME, TT_5min.dal_ref_ppm,'-','color',dal_ref_clr,'DisplayName','Dal eosFD Reference')
plot(TT_5min.TIME, TT_5min.dal_samplecorr_ppm,'-','color',dal_sample_clr,'DisplayName','Dal eosFD Sample (corrected)')
plot(TT_5min.TIME, TT_5min.miniATM_air_ppm,'-','MarkerSize',2,'color',miniATM_air_clr,'DisplayName','Pro-Oceanus Mini ATM - Air Phase')
plot(TT_5min.TIME, TT_5min.miniATM_water_ppm,'-','MarkerSize',2,'color',miniATM_water_clr,'DisplayName','Pro-Oceanus Mini ATM - Water Phase')
xlabel('Local Time')
ylabel('CO_2 Concentration (ppm)')
grid on; box on
lgd = legend('show','location','northoutside');
lgd.NumColumns = 3;

ind_start = 42;
ind_stop = 52;
x1 = TT_5min.TIME(ind_start);  
x2 = TT_5min.TIME(ind_stop);

% yl = ylim;
% fill([x1 x2 x2 x1], [yl(1) yl(1) yl(2) yl(2)], 'r', 'FaceAlpha', 0.3, 'EdgeColor', 'none','HandleVisibility','off')

%%
%--------------------------------------------------------------------------
% Plot CO2 concentrations with uncertainy bounds for all sensors
%--------------------------------------------------------------------------
fig3 = figure;clf
grid on; box on
y_upper = TT_5min.mit_ref_ppm + mit_eos_err;
y_lower = TT_5min.mit_ref_ppm - mit_eos_err;
patch_x = [TT_5min.TIME; flipud(TT_5min.TIME)];
patch_y = [y_lower; flipud(y_upper)];
h1 = patch(patch_x, patch_y,'w','FaceAlpha', alpha, 'EdgeColor', 'none');
h1.Annotation.LegendInformation.IconDisplayStyle = 'off';
h1.FaceColor = mit_ref_clr;
hold on
plot(TT_5min.TIME, TT_5min.mit_ref_ppm,'-','color',mit_ref_clr,'DisplayName','MIT eosFD Reference')

y_upper = TT_5min.mit_sample_ppm + mit_eos_err;
y_lower = TT_5min.mit_sample_ppm - mit_eos_err;
patch_x = [TT_5min.TIME; flipud(TT_5min.TIME)];
patch_y = [y_lower; flipud(y_upper)];
h2 = patch(patch_x, patch_y,'w','FaceAlpha', alpha, 'EdgeColor', 'none');
h2.Annotation.LegendInformation.IconDisplayStyle = 'off';
h2.FaceColor = mit_sample_clr;
plot(TT_5min.TIME, TT_5min.mit_sample_ppm,'-','color',mit_sample_clr,'DisplayName','MIT eosFD Sample')

y_upper = TT_5min.dal_ref_ppm + dal_eos_err;
y_lower = TT_5min.dal_ref_ppm - dal_eos_err;
patch_x = [TT_5min.TIME; flipud(TT_5min.TIME)];
patch_y = [y_lower; flipud(y_upper)];
h5 = patch(patch_x, patch_y,'w','FaceAlpha', alpha, 'EdgeColor', 'none');
h5.Annotation.LegendInformation.IconDisplayStyle = 'off';
h5.FaceColor = dal_ref_clr;
plot(TT_5min.TIME, TT_5min.dal_ref_ppm,'-','color',dal_ref_clr,'DisplayName','Dal eosFD Reference')

y_upper = TT_5min.dal_sample_ppm + dal_eos_err;
y_lower = TT_5min.dal_sample_ppm - dal_eos_err;
patch_x = [TT_5min.TIME; flipud(TT_5min.TIME)];
patch_y = [y_lower; flipud(y_upper)];
h6 = patch(patch_x, patch_y,'w','FaceAlpha', alpha, 'EdgeColor', 'none');
h6.Annotation.LegendInformation.IconDisplayStyle = 'off';
h6.FaceColor = dal_sample_clr;
plot(TT_5min.TIME, TT_5min.dal_sample_ppm,'-','color',dal_sample_clr,'DisplayName','Dal eosFD Sample')

y_upper = TT_5min.miniCO2_water_ppm + mit_pro_err;
y_lower = TT_5min.miniCO2_water_ppm - mit_pro_err;
patch_x = [TT_5min.TIME; flipud(TT_5min.TIME)];
patch_y = [y_lower; flipud(y_upper)];
h3 = patch(patch_x, patch_y, 'w', 'FaceAlpha', alpha, 'EdgeColor', 'none');
h3.Annotation.LegendInformation.IconDisplayStyle = 'off';
h3.FaceColor = miniCO2_clr;
plot(TT_5min.TIME, TT_5min.miniCO2_water_ppm, '-', 'color', miniCO2_clr,'DisplayName', 'Pro-Oceanus Mini CO_2')

y_upper = TT_5min.turner_ppm + turner_err;
y_lower = TT_5min.turner_ppm - turner_err;
patch_x = [TT_5min.TIME; flipud(TT_5min.TIME)];
patch_y = [y_lower; flipud(y_upper)];
h4 = patch(patch_x, patch_y,'w','FaceAlpha', alpha, 'EdgeColor', 'none');
h4.Annotation.LegendInformation.IconDisplayStyle = 'off';
h4.FaceColor = turner_clr;
plot(TT_5min.TIME, TT_5min.turner_ppm,'-','color',turner_clr,'DisplayName','Turner')

y_upper = TT_5min.miniATM_air_ppm + pro_air_err;
y_lower = TT_5min.miniATM_air_ppm - pro_air_err;
patch_x = [TT_5min.TIME; flipud(TT_5min.TIME)];
patch_y = [y_lower; flipud(y_upper)];
h7 = patch(patch_x, patch_y,'w','FaceAlpha', alpha, 'EdgeColor', 'none');
h7.Annotation.LegendInformation.IconDisplayStyle = 'off';
h7.FaceColor = miniATM_air_clr;
plot(TT_5min.TIME, TT_5min.miniATM_air_ppm,'-','MarkerSize',2,'color',miniATM_air_clr,'DisplayName','Pro-Oceanus Mini ATM - Air Phase')

y_upper = TT_5min.miniATM_water_ppm + pro_water_err;
y_lower = TT_5min.miniATM_water_ppm - pro_water_err;
patch_x = [TT_5min.TIME; flipud(TT_5min.TIME)];
patch_y = [y_lower; flipud(y_upper)];
h8 = patch(patch_x, patch_y,'w','FaceAlpha', alpha, 'EdgeColor', 'none');
h8.Annotation.LegendInformation.IconDisplayStyle = 'off';
h8.FaceColor = miniATM_water_clr;
plot(TT_5min.TIME, TT_5min.miniATM_water_ppm,'-','MarkerSize',2,'color',miniATM_water_clr,'DisplayName','Pro-Oceanus Mini ATM - Water Phase')

ylabel('CO_2 Concentration (ppm)')

lgd = legend('show','location','north');
lgd.NumColumns = 4;

%%
%--------------------------------------------------------------------------
% Plot eosFD fluxes
%--------------------------------------------------------------------------
fig1 = figure;clf

flux_err = 0.2; % (umol m-2 s-1); same for all eosFDs
yline(0,'Color','k','LineWidth',2,'HandleVisibility','off')
hold on

% Dal - provided flux
y_upper = TT_5min.dal_eos_flux + flux_err;
y_lower = TT_5min.dal_eos_flux - flux_err;
patch_x = [TT_5min.TIME; flipud(TT_5min.TIME)];
patch_y = [y_lower; flipud(y_upper)];
h9 = patch(patch_x,patch_y,'w','FaceAlpha',alpha,'EdgeColor','none');
h9.Annotation.LegendInformation.IconDisplayStyle = 'off';
h9.FaceColor = dal_sample_clr;
plot(TT_5min.TIME,TT_5min.dal_eos_flux,'--','color',dal_sample_clr,'DisplayName','Dal Provided Flux')

% Dal - calculated, bias-corrected flux
y_upper = corrected_flux_dal + flux_err;
y_lower = corrected_flux_dal - flux_err;
patch_x = [TT_5min.TIME; flipud(TT_5min.TIME)];
patch_y = [y_lower; flipud(y_upper)];
h10 = patch(patch_x,patch_y,'w','FaceAlpha',alpha,'EdgeColor','none');
h10.Annotation.LegendInformation.IconDisplayStyle = 'off';
h10.FaceColor = dal_sample_clr;
plot(TT_5min.TIME,corrected_flux_dal,':','color',dal_sample_clr,'DisplayName','Dal Corrected Flux')

% MIT - provided flux
y_upper = TT_5min.mit_eos_flux + flux_err;
y_lower = TT_5min.mit_eos_flux - flux_err;
patch_x = [TT_5min.TIME; flipud(TT_5min.TIME)];
patch_y = [y_lower; flipud(y_upper)];
h11 = patch(patch_x,patch_y,'w','FaceAlpha',alpha,'EdgeColor','none');
h11.Annotation.LegendInformation.IconDisplayStyle = 'off';
h11.FaceColor = mit_sample_clr;
plot(TT_5min.TIME,TT_5min.mit_eos_flux,'--','color',mit_sample_clr,'DisplayName','MIT Provided Flux (5-min avg)')

% MIT - calculated, bias-corrected flux
y_upper = corrected_flux_mit + flux_err;
y_lower = corrected_flux_mit - flux_err;
patch_x = [TT_5min.TIME; flipud(TT_5min.TIME)];
patch_y = [y_lower; flipud(y_upper)];
h12 = patch(patch_x,patch_y,'w','FaceAlpha',alpha,'EdgeColor','none');
h12.Annotation.LegendInformation.IconDisplayStyle = 'off';
h12.FaceColor = mit_sample_clr;
plot(TT_5min.TIME,corrected_flux_mit,':','color',mit_sample_clr,'DisplayName','MIT Corrected Flux (5-min avg)')
ylabel('Flux (\mumol m^{-2} s^{-1})')

lgd = legend('show','location','northoutside');
lgd.NumColumns = 2;

% xlim([TT_5min.TIME(1) TT_5min.TIME(end)])
% % ylim([-1 0.5])

grid on
box on


% % set(fig1,"Position",[1 1 1353 857])
% 
% %% ------------------------------------------------------------------------
% % Save plot - make sure to change label!!
% %--------------------------------------------------------------------------
% %--Option to save plot-----------------------------------------------------
% option = questdlg('Save plot?','Save plot','Yes','No','Yes');
% switch option
%     case 'Yes'
%         folder = uigetdir('G:\My Drive\Dal and MIT\Lab Experiments\Figures\','Select a folder');
%         txt = input("Enter the plot name: ","s");
%         disp("Plot name: " + txt);
%         imageName = [txt,'.png'];
%         figName = [txt,'.fig'];
%         exportgraphics(fig1, imageName, 'ContentType', 'image', 'BackgroundColor', 'white');
%         savefig(figName)
%         disp('Plot saved!')
%     case 'No'
%         disp('Plot not saved')
% end
