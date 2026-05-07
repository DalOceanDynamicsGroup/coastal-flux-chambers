%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% eosFD_flux_and_budget_analysis.m
%
% Analysis of air-water CO2 fluxes measured using eosFD chambers and
% Pro-Oceanus sensors. Computes dynamic and steady-state kw, collar
% dynamics Cc(t), eosFD fluxes (fc, fw, fwt), and compares resulting
% budgets.
%
% AUTHOR: Emily Chua
%
% DATE:
% First created: 4/2026
% Major resturcture: 5/6/2026
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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
%%
% Optional: Crop beginning of dataset
switch expt_name
    case '2026-02-12_CO2-pulse-large'
        % Keep as is
    case '2026-02-17_CO2-pulse-small'
        TT_5min(1:45,:) = [];
    case '2026-02-19_CO2-pulse-large-turbulent'
        TT_5min(1:41,:) = [];
end

nodes.Dal.name = 'Dal';
nodes.Dal.Cr = TT_5min.dal_ref_ppm;
nodes.Dal.Cs = TT_5min.dal_samplecorr_ppm;
nodes.Dal.Ca = TT_5min.miniATM_air_ppm;
nodes.Dal.Cw = TT_5min.miniATM_water_ppm;

nodes.MIT.name = 'MIT';
nodes.MIT.Cr = TT_5min.mit_ref_ppm;
nodes.MIT.Cs = TT_5min.mit_samplecorr_ppm;
nodes.MIT.Ca = TT_5min.miniATM_air_ppm;
nodes.MIT.Cw = TT_5min.miniATM_water_ppm;

datetime = TT_5min.TIME;

% Define plot colors
dal_ref_clr = '#8A2BE2';
dal_sample_clr = '#FF00FF';
mit_ref_clr = '#00441b';
mit_sample_clr = '#41ae76';
miniATM_air_clr = '#41b6c4';
miniATM_water_clr = '#0000CD';

% ---Compare Ca (Pro-Oceanus) and Cr (Dal Eosense Reference)---------------
figure,clf
plot(datetime, nodes.Dal.Cr, '.', 'color', dal_ref_clr, 'DisplayName', 'C_{r,Dal}')
hold on
plot(datetime, nodes.MIT.Cr, '.', 'color', mit_ref_clr, 'DisplayName', 'C_{r,MIT}')
plot(datetime, nodes.Dal.Ca, '.', 'color', miniATM_air_clr, 'DisplayName', 'C_{a,PO}')
legend('show','location','north')
xlabel('Local Time')
ylabel('CO_2 Concentration (ppm)')
grid on; box on

disp('Press enter to continue')
pause

% -------------------------------------------------------------------------
% Calculate dynamic kw(t) using Eq. 22
% -------------------------------------------------------------------------
ka = 3.689E-4; % (m s-1); my average value for ref/sample side membrane k
kc = 7.532E-5; % (m s-1); my value for bottom membrane k

for fn = fieldnames(nodes)'
    s = fn{1};

    Cw = nodes.(s).Cw;
    Cs = nodes.(s).Cs;
    Cr = nodes.(s).Cr;

    nodes.(s).kw_dynamic = ka ./ ((Cw - Cs) ./ (Cs - Cr) - ka/kc); % (m s-1)
end

% -------------------------------------------------------------------------
% Calculate true kw (m s-1) from pseudo-SS means
% -------------------------------------------------------------------------
% ---1. Visually identify pseudo-steady state window-----------------------
figure,clf
bl = [0 0 0];
or = [0.8500 0.3250 0.0980];
colororder([bl; or])

yyaxis left
plot(datetime, nodes.Dal.Cr, '-','color', dal_ref_clr, 'DisplayName', 'C_{r,Dal}')
hold on
plot(datetime, nodes.Dal.Cs, '-', 'color', dal_sample_clr, 'DisplayName', 'C_{s,Dal} (corrected)')
plot(datetime, nodes.MIT.Cr, '-', 'color', mit_ref_clr, 'DisplayName', 'C_{r,MIT}')
plot(datetime, nodes.MIT.Cs, '-','color', mit_sample_clr, 'DisplayName', 'C_{s,MIT} (corrected)')
plot(datetime, nodes.Dal.Ca, '-o', 'MarkerSize', 2,'color', miniATM_air_clr, 'DisplayName', 'C_{a,PO}')
plot(datetime, nodes.Dal.Cw, '-^', 'MarkerSize', 2,'color', miniATM_water_clr, 'DisplayName', 'C_{w,PO}')
ylabel('CO_2 Concentration (ppm)')
lgd = legend('show','location','northoutside');
lgd.NumColumns = 3;

yyaxis right
plot(datetime, nodes.Dal.kw_dynamic, ':', 'Color', dal_sample_clr, 'DisplayName', 'Calculated k_{w,Dal}')
hold on
plot(datetime, nodes.MIT.kw_dynamic, ':', 'Color', mit_sample_clr, 'DisplayName', 'Calculated k_{w,MIT}')
yline(0,'LineWidth',2,'Color','k','HandleVisibility','off')
xlabel('Local Time')
ylabel('k_w (m s^{-1})')
ylim([-1E-4 1E-4])
ax = gca;
ax.YColor = 'k';
grid on; box on
%%
disp('Note start and stop indices for pseudo-steady state window, then press enter to continue')
pause
%%
% INPUT
switch expt_name
    case '2026-02-12_CO2-pulse-large'
        ind_start = 42;
        ind_stop = 52;
    case '2026-02-17_CO2-pulse-small'
        ind_start = 42;
        ind_stop = 52;
    case '2026-02-19_CO2-pulse-large-turbulent'
        ind_start = 82;
        ind_stop = 88;
end

ind = ind_start:ind_stop;

% ---Calculate kw (m s-1) using Eq. 22-------------------------------------
for fn = fieldnames(nodes)'
    s = fn{1};

    Cw_ss = mean(nodes.(s).Cw(ind));
    Cs_ss = mean(nodes.(s).Cs(ind));
    Cr_ss = mean(nodes.(s).Cr(ind));

    nodes.(s).kw_ms = ka ./ ((Cw_ss - Cs_ss) ./ (Cs_ss - Cr_ss) - ka/kc); % (m s-1)
end

% -------------------------------------------------------------------------
% Now calculate flux and kw from Pro-Oceanus only
% -------------------------------------------------------------------------
H = 0.115;  % (m); height of water in box
dt = seconds(datetime(2) - datetime(1)); % TT_5min has uniform spacing by definition

% Calculate flux from water-side measurements
Cw = nodes.Dal.Cw;
dCwdt = gradient(Cw, dt); % (ppm s-1); gradient function computes central differences for interior points
fwPO_ppm = -H * dCwdt;     % (ppm m s-1)

% Calculate kw over entire time series for comparison
Ca = nodes.Dal.Ca;                    % (ppm); use Pro-Oceanus atmosphere
kwPO_dynamic = fwPO_ppm ./ (Cw - Ca); % (m s-1)

% Calculate kw during pseudo-SS window
Ca_ss = mean(nodes.Dal.Ca(ind));      % (ppm)
fwPO_ss = mean(fwPO_ppm(ind));        % (ppm m s-1)
kwPO_ms = fwPO_ss / (Cw_ss - Ca_ss);  % (m s-1)

% Convert kw's from m s-1 to cm h-1
nodes.Dal.kw_cmh = nodes.Dal.kw_ms * 100 * 3600; % (cm h-1)
nodes.MIT.kw_cmh = nodes.MIT.kw_ms * 100 * 3600; % (cm h-1)
kw_PO_cmh = kwPO_ms * 100 * 3600;                % (cm h-1)

% txt1 = ['k_{w,Dal} (Eq. 22) = ',num2str(nodes.Dal.kw_ms,3),' m s^{-1} or ',num2str(nodes.Dal.kw_cmh,3),' cm h^{-1}'];
% txt2 = ['k_{w,MIT} (Eq. 22) = ',num2str(nodes.MIT.kw_ms,3),' m s^{-1} or ',num2str(nodes.MIT.kw_cmh,3),' cm h^{-1}'];
% txt3 = ['k_{w,PO} = ',num2str(kwPO_ms,3),' m s^{-1} or ',num2str(kw_PO_cmh,3),' cm h^{-1}'];
txt1 = ['k_{w,Dal} (Eq. 22) = ',num2str(nodes.Dal.kw_cmh,3),' cm h^{-1}'];
txt2 = ['k_{w,MIT} (Eq. 22) = ',num2str(nodes.MIT.kw_cmh,3),' cm h^{-1}'];
txt3 = ['k_{w,PO} = ',num2str(kw_PO_cmh,3),' cm h^{-1}'];

% -------------------------------------------------------------------------
% Plot to compare kw from Dal & MIT eosFDs with kw from Pro-Oceanus
% -------------------------------------------------------------------------
figure,clf
bl = [0 0 0];
or = [0.8500 0.3250 0.0980];
colororder([bl; or])
x1 = datetime(ind_start);
x2 = datetime(ind_stop);

yyaxis left
plot(datetime, nodes.Dal.Cr,'-','color',dal_ref_clr,'DisplayName','C_{r,Dal}')
hold on
plot(datetime, nodes.Dal.Cs,'-','color',dal_sample_clr,'DisplayName','C_{s,Dal} (corrected)')
plot(datetime, nodes.MIT.Cr,'-','color',mit_ref_clr,'DisplayName','C_{r,MIT}')
plot(datetime, nodes.MIT.Cs,'-','color',mit_sample_clr,'DisplayName','C_{w,MIT} (corrected)')
plot(datetime, nodes.Dal.Ca,'-o','MarkerSize',2,'color',miniATM_air_clr,'DisplayName','C_{a,PO}')
plot(datetime, nodes.Dal.Cw,'-^','MarkerSize',2,'color',miniATM_water_clr,'DisplayName','C_{w,PO}')
ylabel('CO_2 Concentration (ppm)')
switch expt_name
    case '2026-02-12_CO2-pulse-large'
        xt = datetime(ind_start - 15); % x-position of text
        text(xt, 600, txt1, 'FontSize', 12)
        text(xt, 550, txt2, 'FontSize', 12)
        text(xt, 500, txt3, 'FontSize', 12)
    case '2026-02-17_CO2-pulse-small'
        xt = datetime(ind_start - 30); % x-position of text
        text(xt, 570, txt1, 'FontSize', 12)
        text(xt, 540, txt2, 'FontSize', 12)
        text(xt, 510, txt3, 'FontSize', 12)
    case '2026-02-19_CO2-pulse-large-turbulent'
        xt = datetime(ind_start - 10); % x-position of text
        text(xt, 650, txt1, 'FontSize', 12)
        text(xt, 620, txt2, 'FontSize', 12)
        text(xt, 590, txt3, 'FontSize', 12)
end

yyaxis right
plot(datetime, nodes.Dal.kw_dynamic, ':', 'color', dal_sample_clr, 'DisplayName', 'k_{w,Dal} (Eq. 22)')
hold on
plot(datetime, nodes.MIT.kw_dynamic, ':', 'color', mit_sample_clr, 'DisplayName', 'k_{w,MIT} (Eq. 22)')
plot(datetime, kwPO_dynamic, ':', 'color', miniATM_water_clr, 'DisplayName', 'k_{w,PO} (from \partialC_w/\partialt)')
yline(0, 'k', 'LineWidth', 2, 'HandleVisibility', 'off')
ylabel('k_w (m s^{-1})')
lgd = legend('show','location','northoutside');
lgd.NumColumns = 5;
% ylim([-1E-4 1E-4])
ylim([-0.0001 0.0001])

yl = ylim;
fill([x1 x2 x2 x1], [yl(1) yl(1) yl(2) yl(2)], 'r', 'FaceAlpha', 0.3, 'EdgeColor', 'none','DisplayName','Pseudo Steady State')
ax = gca;
ax.YColor = 'k';
grid on; box on

%%
% -------------------------------------------------------------------------
% Calculate eosFD fluxes
% -------------------------------------------------------------------------
% ---1. Calculate Cc(t) using Eq. 18---------------------------------------
% Define initial conditions manually
fig = figure;clf
plot(datetime, nodes.Dal.Cs, '.', 'color', dal_sample_clr, 'DisplayName', 'C_{s,Dal}')
hold on
plot(datetime, nodes.MIT.Cs, '.', 'color', mit_sample_clr, 'DisplayName', 'C_{s,MIT}')
ylabel('CO_2 Concentration (ppm)')
grid on; box on;

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

% Known values
Sm = 804 / 10^6;          % (m2); membrane surface area
% Sw = pi * 0.025^2;        % (m2); enclosed water surface area <-- NEED TO MEASURE
Sw = Sm;
Vc = pi * 0.025^2 * 0.01; % (m3); volume of collar, assuming water level is 1.5 cm from bottom
kappa_c = Sm*kc/Vc;       % (s-1); rate constant for bottom membrane

% Initial conditions
Cw0 = TT_5min.miniATM_water_ppm(ind_t0);  % (ppm); initial water concentration
Cs0 = TT_5min.dal_samplecorr_ppm(ind_t0); % (ppm); initial Sample concentration
Cr0 = TT_5min.dal_ref_ppm(ind_t0);        % (ppm); initial Reference concentration

t = seconds(TT_5min.TIME - TT_5min.TIME(1)); % (s)

% --Calculate Cc using Eq. 18----------------------------------------------
for fn = fieldnames(nodes)'
    s = fn{1};

    Cs = nodes.(s).Cs;
    Cw = nodes.(s).Cw;
    kw = nodes.(s).kw_ms;

    kappa_w = Sw * kw / Vc;        % (s-1); rate constant for enclosed water
    tau_chamber = 1 / (kappa_w + kappa_c);  % (s); estimate of chamber time constant
    A = Ca - (kappa_w*Cw0 + kappa_c*Cs0) ./ (kappa_w + kappa_c);  % (ppm); constant (Eq. 17)
    nodes.(s).Cc = A .* exp(-(kappa_w + kappa_c) .* t) + (kappa_w .* Cw + kappa_c .* Cs) ./ (kappa_w + kappa_c); % (ppm)
end

% Plot result
cd('G:\My Drive\Dal and MIT\Lab Experiments\Figures\MIT')
figure,clf
plot(datetime, nodes.Dal.Cs, '.-', 'color', dal_sample_clr, 'DisplayName', 'C_{s,Dal} (corrected)')
hold on
plot(datetime, nodes.Dal.Cc, '-.', 'color', dal_sample_clr, 'DisplayName', 'Calculated C_{c,Dal}(t)')
plot(datetime, nodes.MIT.Cs, '.-', 'color', mit_sample_clr, 'DisplayName', 'C_{s,MIT} (corrected)')
plot(datetime, nodes.MIT.Cc, '-.', 'color', mit_sample_clr, 'DisplayName', 'Calculated C_{c,MIT}(t)')
plot(datetime(ind_t0), nodes.Dal.Cs(ind_t0), 'ok', 'MarkerSize', 8, 'DisplayName', 'Initial Conditions')
lgd = legend('show','location','north');
lgd.NumColumns = 3;
xlabel('Local Time')
ylabel('CO_2 Concentration (ppm)')
grid on; box on

% disp('Press enter to continue to next plot')
% pause
%
figure,clf
plot(nodes.Dal.Cs, nodes.Dal.Cc, '.', 'Color', dal_sample_clr, 'DisplayName', 'Dal')
hold on
plot(nodes.MIT.Cs, nodes.MIT.Cc, '.', 'Color', mit_sample_clr, 'DisplayName', 'MIT')
currentLimits = [xlim ylim];
minLimit = min(currentLimits);
maxLimit = max(currentLimits);
plot([minLimit maxLimit], [minLimit maxLimit], '--k', 'DisplayName', '1:1 Reference Line')
legend('show','location','north')
xlabel('C_s (ppm)')
ylabel('C_c(t) (ppm)')
axis square
%%
% -------------------------------------------------------------------------
% Calculate fc, fw, fwt and compare with PO water-inventory flux
% -------------------------------------------------------------------------
% For converting from ppm m 2-1 --> umol m-2 s-1
R = 8.314;                            % (J mol-1 K-1)
Tair = TT_5min.air_T + 273.15;        % (K)
P_Pa = TT_5min.miniATM_air_Pmbar*100; % (Pa)

for fn = fieldnames(nodes)'
    s = fn{1};

    Cs = nodes.(s).Cs;
    Cr = nodes.(s).Cr;
    Cw = nodes.(s).Cw;
    Cc = nodes.(s).Cc;
    kw = nodes.(s).kw_ms;

    % Flux through bottom membrane (Eq. 10)
    % nodes.(s).fc = kc * (Cc - Cs); % (Eq. 13)
    Vm = 16.7/10^6; % (m3); volume of measuring chamber
    fc_ppm = Vm/Sm * (gradient(Cs, dt) - gradient(Cr, dt)) + ka * (Cs - Cr);
    nodes.(s).fc = fc_ppm .* P_Pa ./ (R * Tair);

    % Flux beneath chamber (Eq. 19)
    fw_ppm = kw * (Cw - Cc);
    nodes.(s).fw = fw_ppm.* P_Pa ./ (R * Tair);

    % True flux (Eq. 24)
    fwt_ppm = kw * (Cw - Cr);
    nodes.(s).fwt = fwt_ppm .* P_Pa ./ (R * Tair);
end

% Smooth the flux from PO water-inventory method for comparison
fwPO = fwPO_ppm .* P_Pa ./ (R * Tair);
flux_PO_smooth = smoothdata(fwPO,"movmean",5);
%%
figure,clf
t = tiledlayout(2,1,'TileSpacing','compact');

ax1 = nexttile;
yline(0,'k','LineWidth',2,'HandleVisibility','off','Layer','bottom')
hold on
plot(datetime, nodes.Dal.fc, '-', 'Color', dal_sample_clr, 'DisplayName', '$f_{c,Dal}$ (Eq. 10)')
% plot(datetime, nodes.Dal.fw, '.-', 'Color', rgb('OrangeRed'), 'DisplayName', '$f_w$ (Eq. 19)')
% plot(datetime, nodes.Dal.fwt, '.-', 'Color', rgb('Goldenrod'), 'DisplayName', '$f_w^\dagger$ (Eq. 24)')
plot(datetime, nodes.Dal.fw, '--', 'Color', dal_sample_clr, 'DisplayName', '$f_{w,Dal}$ (Eq. 19)')
plot(datetime, nodes.Dal.fwt, ':', 'Color', dal_sample_clr, 'DisplayName', '$f_{w,Dal}^\dagger$ (Eq. 24)')
plot(datetime, flux_PO_smooth, '-', 'Color', miniATM_water_clr, 'DisplayName', '$f_{w,PO} = -h\cdot \partial C_w / \partial t$')
xticklabels({})
lgd = legend('show','location','south','interpreter','latex');
lgd.NumColumns = 2;
grid on; box on

ax2 = nexttile;
yline(0,'k','LineWidth',2,'HandleVisibility','off','Layer','bottom')
hold on
plot(datetime, nodes.MIT.fc, '-', 'Color', mit_sample_clr, 'DisplayName', '$f_{c,MIT}$ (Eq. 10)')
% plot(datetime, nodes.MIT.fw, '.-', 'Color', rgb('OrangeRed'), 'DisplayName', '$f_w$ (Eq. 19)')
% plot(datetime, nodes.MIT.fwt, '.-', 'Color', rgb('Goldenrod'), 'DisplayName', '$f_w^\dagger$ (Eq. 24)')
plot(datetime, nodes.MIT.fw, '--', 'Color', mit_sample_clr, 'DisplayName', '$f_{w,MIT}$ (Eq. 19)')
plot(datetime, nodes.MIT.fwt, ':', 'Color', mit_sample_clr, 'DisplayName', '$f_{w,MIT}^\dagger$ (Eq. 24)')
plot(datetime, flux_PO_smooth, '-', 'Color', miniATM_water_clr, 'DisplayName', '$f_{w,PO} = -h\cdot \partial C_w / \partial t$')

xlabel('Local Time')
lgd = legend('show','location','south','interpreter','latex');
lgd.NumColumns = 2;
grid on; box on
linkaxes([ax1 ax2], 'y')
ylabel(t, 'Flux (\mumol m^{-2} s^{-1})','FontSize',14)


%%
% -------------------------------------------------------------------------
% Budget Calculations
% -------------------------------------------------------------------------
% 1. Calculate Pro-Oceanus net CO2 exchange rate using waterside measurements
H = 0.115;  % INPUT: Height of water (m)
L = 0.5;    % Length of container (m)
V = H*L^2;  % Volume of water (m3)
A = L^2;    % Area of water (m2)

% a. Convert xCO2 (ppmv) --> pCO2 (uatm)
P_atm = TT_5min.miniATM_air_Pmbar / 1013.25;    % total pressure conversion (atm)
pCO2_uatm = TT_5min.miniCO2_water_ppm .* P_atm; % CO2 partial pressure (uatm)

% b. Compute solubility constant, K0 using Weiss, 1974
Tw = TT_5min.water_T + 273.15; % (K)
K0 = exp(-60.2409 + 93.4517*(100./Tw) + 23.3585*log(Tw./100));  % (mol kg-1 atm-1); S = 0

% c. Convert pCO2 (uatm) --> dissolved CO2 concentration (umol kg-1)
Cw_umol_kg = K0 .* pCO2_uatm; % (umol kg-1)

% d. Convert Cw from mol kg-1 --> mol L-1 assuming water density = 1000 kg m-3
Cw_umol_m3 = Cw_umol_kg * 10^3; % (umol L-1)

% e. Compute inventory
N_umol = Cw_umol_m3 * V; % (umol)
% N_umol_smooth = smooth(N_umol,5); % (umol)
N_umol_smooth = smoothdata(N_umol,"movmean",5);

% f. Compute budget (exchange rate)
dN_dt = diff(N_umol) ./ seconds(diff(TT_5min.TIME)); % (umol s-1)
dNsmooth_dt = diff(N_umol_smooth) ./ seconds(diff(TT_5min.TIME)); % (umol s-1)

% 2. Calculate Eosense net CO2 exchange rate via F_eos x A
for fn = fieldnames(nodes)'
    s = fn{1};

    nodes.(s).fc_total = nodes.(s).fc * A;   % (umol s-1)
    nodes.(s).fw_total = nodes.(s).fw * A;   % (umol s-1)
    nodes.(s).fwt_total = nodes.(s).fwt * A; % (umol s-1)
end

% figure,clf
% plot(datetime, nodes.Dal.fw_total, '--', 'color', dal_sample_clr, 'DisplayName','$f_{w,Dal} \cdot A$')
% hold on
% plot(datetime, nodes.MIT.fw_total, '--', 'color', mit_sample_clr, 'DisplayName','$f_{w,MIT} \cdot A$')
% plot(datetime(1:end-1), -dNsmooth_dt, '-', 'color', miniATM_water_clr, 'DisplayName', '$\frac{-dN_{PO}}{dt}$')
% yline(0,'k','linewidth',2,'HandleVisibility','off')
% xlabel('Local Time')
% ylabel('Net CO_2 exchange rate (\mumol s^{-1})','FontSize',14)
% legend('show','location','south','interpreter','latex')
% grid on; box on

figure,clf
t = tiledlayout(2,1,'TileSpacing','tight');

ax1 = nexttile;
yline(0,'k','LineWidth',2,'HandleVisibility','off','Layer','bottom')
hold on
plot(datetime, nodes.Dal.fc_total, '-', 'Color', dal_sample_clr, 'DisplayName', '$f_{c,Dal} \cdot A$')
plot(datetime, nodes.Dal.fw_total, '--', 'Color', dal_sample_clr, 'DisplayName', '$f_{w,Dal} \cdot A$')
plot(datetime, nodes.Dal.fwt_total, '-.', 'Color', dal_sample_clr, 'DisplayName', '$f_{w,Dal}^\dagger \cdot A$')
plot(datetime(1:end-1), -dNsmooth_dt, '-', 'color', miniATM_water_clr, 'DisplayName', '$\frac{-dN_{PO}}{dt}$')
% ylabel('Net CO_2 exchange rate (\mumol s^{-1})','FontSize',14)
xticklabels({})
lgd = legend('show','location','south','interpreter','latex');
lgd.NumColumns = 2;
grid on; box on

ax2 = nexttile;
yline(0,'k','LineWidth',2,'HandleVisibility','off','Layer','bottom')
hold on
plot(datetime, nodes.MIT.fc_total, '-', 'Color', mit_sample_clr, 'DisplayName', '$f_{c,MIT} \cdot A$')
plot(datetime, nodes.MIT.fw_total, '--', 'Color', mit_sample_clr, 'DisplayName', '$f_{w,MIT} \cdot A$')
plot(datetime, nodes.MIT.fwt_total, '-.', 'Color', mit_sample_clr, 'DisplayName', '$f_{w,MIT}^\dagger \cdot A$')
plot(datetime(1:end-1), -dNsmooth_dt, '-', 'color', miniATM_water_clr, 'DisplayName', '$\frac{-dN_{PO}}{dt}$')

xlabel('Local Time')
lgd = legend('show','location','south','interpreter','latex');
lgd.NumColumns = 2;
grid on; box on
linkaxes([ax1 ax2], 'y')
ylabel(t, 'Net CO_2 exchange rate (\mumol s^{-1})','FontSize',14)
