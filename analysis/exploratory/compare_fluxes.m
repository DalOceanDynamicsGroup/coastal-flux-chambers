clear; close all; clc

% -------------------------------------------------------------------------
% Load the merged data file
% -------------------------------------------------------------------------
start_path = 'G:\My Drive\Dal and MIT\Lab Experiments\Data\';
dialog_title = 'Select an experiment data folder';
selpath = uigetdir(start_path,dialog_title);
[~,expt_name] = fileparts(selpath);
cd([selpath,'\merged'])
load('allDat.mat')

% -------------------------------------------------------------------------
% Define initial conditions manually
% -------------------------------------------------------------------------
% Define plot colors
dal_ref_clr = '#8A2BE2';
dal_sample_clr = '#FF00FF';
dal_flux_clr = '#8B008B';
miniATM_air_clr = '#41b6c4';
miniATM_water_clr = '#0000CD';

fig = figure;clf
plot(TT_5min.TIME, TT_5min.dal_sample_ppm, '.', 'color', dal_sample_clr, 'DisplayName', 'Dal Eosense Sample')

dcm_obj = datacursormode(fig);
datacursormode on;
disp([newline 'Click on a data point in the plot, then press "Enter" in the Command Window']);
pause;
info_struct = getCursorInfo(dcm_obj);
if isfield(info_struct, 'DataIndex')
    ind_t0 = info_struct.DataIndex;
    cursor_position = info_struct.Position;
    disp(['Clicked data index: ', num2str(ind_t0)]);
    disp(['Clicked y-value: ', num2str(cursor_position(2),3), ' ppm']);
else
    disp('No data point was clicked.');
end

% Compare Ca (Pro-Oceanus) and Cr (Dal Eosense Reference)
figure,clf
plot(TT_5min.TIME, TT_5min.dal_ref_ppm, '.', 'color', dal_ref_clr, 'DisplayName', 'Dal Eosense Reference')
hold on
plot(TT_5min.TIME, TT_5min.miniATM_air_ppm, '.', 'color', miniATM_air_clr, 'DisplayName', 'Pro-Oceanus Mini ATM - Air Phase')
legend('show','location','best')
xlabel('Local Time')
ylabel('CO_2 Concentration (ppm)')
grid on

% Initial conditions
Cw0 = TT_5min.miniATM_water_ppm(ind_t0);  % (ppm); initial water concentration
Cs0 = TT_5min.dal_samplecorr_ppm(ind_t0); % (ppm); initial Sample concentration
Cr0 = TT_5min.dal_ref_ppm(ind_t0);        % (ppm); initial Reference concentration

% -------------------------------------------------------------------------
% Calculate kw from Eq. 22
% -------------------------------------------------------------------------
% 1) Calculate kw over entire time series to identify the pseudo-SS window
ka = 3.689E-4; % (m s-1); my average value for ref/sample side membrane k
kc = 7.532E-5; % (m s-1); my value for bottom membrane k
Cw = TT_5min.miniATM_water_ppm;
Cs = TT_5min.dal_samplecorr_ppm;
Cr = TT_5min.dal_ref_ppm;

kw_dynamic = ka ./ ((Cw - Cs) ./ (Cs - Cr) - ka/kc); % (m s-1)

figure,clf
bl = [0 0 0];
or = [0.8500 0.3250 0.0980];
colororder([bl; or])

yyaxis left
plot(TT_5min.TIME, TT_5min.dal_ref_ppm,'-','color',dal_ref_clr,'DisplayName','Dal Eosense Reference')
hold on
plot(TT_5min.TIME, TT_5min.dal_samplecorr_ppm,'-','color',dal_sample_clr,'DisplayName','Dal Eosense Sample (corrected)')
plot(TT_5min.TIME, TT_5min.miniATM_air_ppm,'-o','MarkerSize',2,'color',miniATM_air_clr,'DisplayName','Pro-Oceanus Mini ATM - Air')
plot(TT_5min.TIME, TT_5min.miniATM_water_ppm,'-^','MarkerSize',2,'color',miniATM_water_clr,'DisplayName','Pro-Oceanus Mini ATM - Water')
% plot(TT_5min.TIME, Cc, '.', 'DisplayName', 'C_c')
ylabel('CO_2 Concentration (ppm)')
grid on; box on
lgd = legend('show','location','north');
lgd.NumColumns = 3;

yyaxis right
plot(TT_5min.TIME, kw_dynamic, '.-','DisplayName','Calculated')
hold on
yline(0,'LineWidth',2,'Color',or,'HandleVisibility','off')
xlabel('Local Time')
ylabel('k_w (m s^{-1})')
ylim([-1E-4 1E-4])
grid on
%%
% 2) Manually define pseudo-SS conditions (x-range to average over)
% ---2-h window---
% ind_start = 24;
% ind_stop = 48;
% ---1-h window---
% ind_start = 36;
% ind_stop = 48;
% ---30-min window---
ind_start = 42;
ind_stop = 52;
x1 = TT_5min.TIME(ind_start);  
x2 = TT_5min.TIME(ind_stop);

% 3) Calculate kw from Eq. 22 only during pseudo-SS window
Cw_ss = mean(TT_5min.miniATM_water_ppm(ind_start:ind_stop));
Cs_ss = mean(TT_5min.dal_samplecorr_ppm(ind_start:ind_stop));
Cr_ss = mean(TT_5min.dal_ref_ppm(ind_start:ind_stop));

kw = ka ./ ((Cw_ss - Cs_ss) ./ (Cs_ss - Cr_ss) - ka/kc); % (m s-1)

% -------------------------------------------------------------------------
% Compare kw calculated from Eq. 22 vs. Pro-Oceanus data only
% -------------------------------------------------------------------------
% Calculate flux and kw from Pro-Oceanus only
H = 0.115;  % (m); height of water in box
dt = seconds(TT_5min.TIME(2) - TT_5min.TIME(1));    % Assumes uniform spacing

% Calculate flux from water-side measurements
dCwdt = gradient(Cw, dt); % (ppm s-1); gradient function computes central differences for interior points
flux_PO = -H * dCwdt;     % (ppm m s-1)

% Calculate kw over entire time series for comparison
Ca = TT_5min.miniATM_air_ppm;    % (ppm); use Pro-Oceanus atmosphere
kw_PO_dynamic = flux_PO ./ (Cw - Ca); % (m s-1)

% Calculate kw during pseudo-SS window
Cw_ss = mean(Cw(ind_start:ind_stop));  % (ppm)
Ca_ss = mean(Ca(ind_start:ind_stop));  % (ppm)
flux_PO_ss = mean(flux_PO(ind_start:ind_stop)); % (ppm m s-1)
kw_PO = flux_PO_ss / (Cw_ss - Ca_ss); % (m s-1)

% Convert kw from m/s to cm/h
kw_cmh = kw * 100 * 3600; % (cm h-1)
kw_PO_cmh = kw_PO * 100 * 3600; % (cm h-1)

txt1 = ['k_w (Eq. 22) = ',num2str(kw,3),' m s^{-1} or ',num2str(kw_cmh,3),' cm h^{-1}'];
txt2 = ['k_w (PO) = ',num2str(kw_PO,3),' m s^{-1} or ',num2str(kw_PO_cmh,3),' cm h^{-1}'];

figure,clf
plot(TT_5min.TIME, kw_dynamic ,'.-', 'color', or, 'DisplayName', 'Calculated from Eq. 22')
hold on
plot(TT_5min.TIME, kw_PO_dynamic, '.-', 'color', miniATM_water_clr, 'DisplayName', 'Calculated from Pro-Oceanus \partialC_w/\partialt only')
yline(0, 'k', 'LineWidth', 2, 'HandleVisibility', 'off')
text(TT_5min.TIME(ind_stop-30), .5E-4, txt1, 'FontSize', 12)
text(TT_5min.TIME(ind_stop-30), .4E-4, txt2, 'FontSize', 12)
yl = ylim;
fill([x1 x2 x2 x1], [yl(1) yl(1) yl(2) yl(2)], 'r', 'FaceAlpha', 0.3, 'EdgeColor', 'none','DisplayName','Pseudo Steady State')
ylabel('k_w (m s^{-1})')
legend('show','location','north')
grid on
% xlim([TT_5min.TIME(ind_start) TT_5min.TIME(ind_stop)])
ylim([-1E-4 1E-4])

%%
% -------------------------------------------------------------------------
% Calculate Cc(t) using Eq. 18
% -------------------------------------------------------------------------
% Known values
S = 804 / 10^6; % (m2); membrane surface area
Vc = pi * 0.025^2 * 0.01; % (m3); volume of collar, assuming water level is 1.5 cm from bottom
kappa_c = S*kc/Vc; % (s-1); rate constant for bottom membrane

t = seconds(TT_5min.TIME - TT_5min.TIME(1)); % (s)

% --Calculate Cc using kw from Eq. 22-------------
kappa_w = S*kw/Vc; % (s-1); rate constant for enclosed water
tau_chamber = 1 / (kappa_w + kappa_c); % (s); estimate of chamber time constant
A = Ca - (kappa_w*Cw0 + kappa_c*Cs0) ./ (kappa_w + kappa_c);
Cc = A .* exp(-(kappa_w + kappa_c) .* t) + (kappa_w .* Cw + kappa_c .* Cs) ./ (kappa_w + kappa_c); % (ppm)

% --Calculate Cc(t) using kw from PO data-------------
kappa_w = S*kw_PO/Vc; % (s-1); rate constant for enclosed water
A = Ca - (kappa_w*Cw0 + kappa_c*Cs0) ./ (kappa_w + kappa_c);
Cc_PO = A .* exp(-(kappa_w + kappa_c) .* t) + (kappa_w .* Cw + kappa_c .* Cs) ./ (kappa_w + kappa_c); % (ppm)

% Plot result
cd('G:\My Drive\Dal and MIT\Lab Experiments\Figures\MIT')
figure,clf
plot(TT_5min.TIME, TT_5min.dal_samplecorr_ppm, '.', 'color', dal_sample_clr, 'DisplayName', 'Dal Eosense Sample (corrected)')
hold on
plot(TT_5min.TIME, Cc, '.', 'DisplayName', 'Calculated C_c(t) using k_w from Eq. 22')
plot(TT_5min.TIME, Cc_PO, '.', 'color', miniATM_water_clr, 'DisplayName', 'Calculated C_c(t) using k_w from PO')
legend('show','location','best')
xlabel('Local Time')
ylabel('CO_2 Concentration (ppm)')
grid on

figure,clf
plot(TT_5min.dal_sample_ppm, Cc_PO, '.', 'color', miniATM_water_clr, 'DisplayName', 'Calculated C_c(t) using k_w from PO')
hold on
plot(TT_5min.dal_sample_ppm, Cc, '.', 'DisplayName', 'Calculated C_c(t) using k_w from Eq. 22')
currentLimits = [xlim ylim];
minLimit = min(currentLimits);
maxLimit = max(currentLimits);
plot([minLimit maxLimit], [minLimit maxLimit], '--k', 'DisplayName', '1:1 Reference Line')
legend('show','location','north')
xlabel('Dal Eosense Sample (ppm)')
ylabel('Calculated C_c(t) (ppm)')
axis square

%% Compare fluxes (all in ppm m s-1)
fw = kw * (Cw - Cc); % Flux beneath chamber (Eq. 19)

flux_PO_smooth = smoothdata(flux_PO,"movmean",5); % Smoothed flux from PO C_w data only

fwt_PO = kw_PO * (Cw - Ca); % True flux (Eq. 23), using k_w calculated from PO

fwt = kw * (Cw - Ca); % True flux (Eq. 23), using k_w calculated from Eq. 22

figure,clc 
yline(0,'k','LineWidth',2,'HandleVisibility','off','Layer','bottom')
hold on
plot(TT_5min.TIME, flux_PO, '.-', 'Color', miniATM_water_clr, 'DisplayName', 'Calculated from Pro-Oceanus $\partial C_w / \partial t$ only')
% plot(TT_5min.TIME, flux_PO_smooth, '.-', 'Color', miniATM_water_clr, 'DisplayName', '$f_{w,PO} = -h\cdot \partial C_w / \partial t$')
plot(TT_5min.TIME, fw, '.-', 'DisplayName', '$f_w$ (Eq. 19; flux beneath chamber)')
plot(TT_5min.TIME, fwt_PO, '.-', 'DisplayName', '$f_w^\dagger$ (Eq. 23 using $k_w$ from PO)')
plot(TT_5min.TIME, fwt, '.-', 'DisplayName', '$f_w^\dagger$ (Eq. 23 using $k_w$ from Eq. 22)')
xlabel('Local Time')
ylabel('f_w (ppm m s^{-1})')
legend('show','location','best','interpreter','latex')
grid on

%% Convert fluxes in ppm m s-1 --> umol m-2 s-1
R = 8.314; % (J mol-1 K-1)
Tair = TT_5min.air_T + 273.15; % (K)

fw_umol = fw .* TT_5min.miniATM_air_Pmbar*100 ./ (R * Tair);           % Flux beneath chamber

flux_PO_umol = flux_PO .* TT_5min.miniATM_air_Pmbar*100 ./ (R * Tair); % Flux from PO water-inventory method

fwt_PO_umol = fwt_PO .* TT_5min.miniATM_air_Pmbar*100 ./ (R * Tair);   % Flux from solely PO measurements

fwt_umol = fwt .* TT_5min.miniATM_air_Pmbar*100 ./ (R * Tair);         % True flux

flux_PO_umol_smooth = smoothdata(flux_PO_umol,"movmean",4);            % Smoothed PO water-inventory flux

lblsize = 18;
lgdsize = 16;

f = figure;clc 
yline(0,'k','LineWidth',2,'HandleVisibility','off','Layer','bottom')
hold on
% plot(TT_5min.TIME, flux_PO_umol, '.-', 'Color', miniATM_water_clr, 'DisplayName', 'Pro-Oceanus water-inventory flux')
plot(TT_5min.TIME, flux_PO_umol_smooth, '.-', 'Color', miniATM_water_clr, 'DisplayName', 'Pro-Oceanus water-inventory flux = $-h\cdot \partial C_w / \partial t$')
% plot(TT_5min.TIME, fwt_PO_umol, '.-', 'Color', miniATM_water_clr, 'DisplayName', 'Flux from Pro-Oceanus = $k_{w,PO}(C_w - C_a)$')
plot(TT_5min.TIME, fw_umol, '.-', 'Color', dal_flux_clr, 'DisplayName', 'Flux beneath chamber = $k_w(C_w - C_c)$')
% plot(TT_5min.TIME, fwt_umol, '.-', 'DisplayName', '"True" flux')
xlabel('Local Time')
ylabel('Air-water flux (\mumol m^{-2} s^{-1})')
ax = gca;
ax.FontSize = lblsize;

lgd = legend('show','location','south','interpreter','latex');
lgd.FontSize = lgdsize;

grid on
box on

set(f,"Position",[3 929 1533 700])
%%
cd('G:\My Drive\Dal and MIT\Lab Experiments\Figures\MIT\Expt - Large CO2 Pulse')
exportgraphics(gcf,'large_CO2pulse_flux-comparison_V2.png','Padding','tight')