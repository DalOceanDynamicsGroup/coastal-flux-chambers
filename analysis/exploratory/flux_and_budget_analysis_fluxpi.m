%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% flux_and_budget_analysis_fluxpi.m
%
% Analysis of air-water CO2 fluxes measured using eosFD chambers and
% Pro-Oceanus sensors. Computes dynamic and steady-state kw, collar
% dynamics Cc(t), eosFD fluxes (fc, fw, fwt), and compares resulting
% budgets.
%
% Table and figure numbers refer to eosense_theory document.
%
% AUTHOR: Emily Chua
%
% DATE:
% First created: 4/2026
% Major restructures: 5/6/2026, 7/15/26
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% clear; close all; clc

% -------------------------------------------------------------------------
% Setup
% -------------------------------------------------------------------------
% Calibrated
ka = 3.689E-4;                   % (m s-1); my average value for MIT ref/sample side membrane k
kc = 7.532E-5;                   % (m s-1); my value for MIT bottom membrane k

% Measured
H = 0.15;                        % (m); height of water in tank
h_collar = 0.03;                 % (m); height of collar headspace

% Known geometry (Table 4)
r_collar = 0.025;                % (m); radius of inner collar
Sm = 804 / 10^6;                 % (m2); membrane surface area
Vm = 16.7 / 10^6;                % (m3); volume of measuring chamber

% Calculated 
Sw = pi * r_collar^2;            % (m2); enclosed water surface area
Vc = pi * r_collar^2 * h_collar; % (m3); volume of collar
kappa_c = Sm * kc / Vc;          % (s-1); rate constant for bottom membrane

% Constants
R = 8.314;                       % (J mol-1 K-1)

% ---Define plotting conventions-------------------------------------------
ref_clr = '#8A2BE2';
sample_clr = '#FF00FF';
POair_clr = '#41b6c4';
POwater_clr = '#0000CD';
lblsize = 18;
lgdsize = 16;

% ---Load analysis-ready data file-----------------------------------------
dataRoot = 'C:\Users\Emily\OneDrive - Dalhousie University\Google Drive Migration\Dal and MIT\Lab Experiments\Data\';
dialog_title = 'Select an experiment data folder';
selPath = uigetdir(dataRoot,dialog_title);
[~,expName] = fileparts(selPath);
filePath = fullfile(selPath, 'processed');

datFile = dir(fullfile(filePath, 'allDat*'));
S = load(fullfile(datFile(1).folder, datFile(1).name));
eosDat = S.eosDat;
poPaired = S.poPaired;
thermDat = S.thermDat;
if isempty(datFile)
    error('No data file found.')
end

% ---Pair EOS and THERM to PO values---------------------------------------
eosPaired = retime(eosDat, poPaired.datetime_local, 'mean');
thermPaired = retime(thermDat, poPaired.datetime_local, 'mean');

% Use the paired EOS, THERM, and PO values in calculations
Cr_pair = eosPaired.ref_conc_corr;
Cs_pair = eosPaired.sample_conc_corr;
Ca_pair = poPaired.air_conc;
Cw_pair = poPaired.water_conc;
Tair = thermPaired.air_T + 273.15; % (K)

eos_h = hours(eosDat.datetime_local - eosDat.datetime_local(1));
po_h = hours(poPaired.datetime_local - poPaired.datetime_local(1));

%% Test splines/smoothing
% Spline
pp_Cw = csaps(po_h,Cw_pair,0.99);
pp_Ca = csaps(po_h,Ca_pair,0.99);

Cw_spline = fnval(pp_Cw,po_h);
Ca_spline = fnval(pp_Ca,po_h);

dCwdt_spline = fnval(fnder(pp_Cw),po_h);

figure,clf
plot(po_h,Cw_pair,'.','Color',POwater_clr,'DisplayName','C_w')
hold on
plot(po_h,Ca_pair,'.','Color',POair_clr,'DisplayName','C_a')
plot(po_h,Cw_spline,'-','Color',POwater_clr,'DisplayName','C_w (spline)')
plot(po_h,Ca_spline,'-','Color',POair_clr,'DisplayName','C_a (spline)')
legend('show')
ylabel('dC_w/dt')
xlabel('Elapsed Hours')

% ---1. Dynamic Conditions-------------------------------------------------
% Calculate Pro-Oceanus flux and kw(t)
fwPO_ppm = -H * dCwdt_spline;                      % (ppm m s-1)
  
% Calculate Eosense kw(t) using Eq. 22
kw_dynamic = Sm / Sw * ka ./ ((Cw_spline - Cs_pair) ./ (Cs_pair - Cr_pair) - ka/kc); % (m s-1)

% Visually identify pseudo-steady state window
figure,clf
title(expName,'Interpreter','none')
elapsed_h = eosPaired.elapsed_s / 3600;

yyaxis left
plot(elapsed_h, Cr_pair, '.-','color', ref_clr, 'DisplayName', 'C_{r}')
hold on
plot(elapsed_h, Cs_pair, '.-', 'color', sample_clr, 'DisplayName', 'C_{s}')
plot(elapsed_h, Ca_spline, '-o', 'MarkerSize', 2,'color', POair_clr, 'DisplayName', 'C_{a} (spline)')
plot(elapsed_h, Cw_spline, '-^', 'MarkerSize', 2,'color', POwater_clr, 'DisplayName', 'C_{w} (spline)')
ylabel('CO_2 Concentration (ppm)','FontSize',lblsize)
lgd = legend('show','location','northeast');
lgd.NumColumns = 4;
lgd.FontSize = lgdsize;

yyaxis right
plot(elapsed_h, kw_dynamic, '.:', 'Color', sample_clr, 'DisplayName', 'k_{w} (Eq. 22)')
hold on
plot(elapsed_h, kwPO_dynamic, '.:', 'Color', POwater_clr, 'DisplayName', 'k_{w,PO} (from \partialC_w/\partialt)')
yline(0,'LineWidth',2,'Color','k','HandleVisibility','off')
xlim([0 20])
ylim([-5E-4 5E-4])
xlabel('Hours Elapsed','FontSize',lblsize)
ylabel('k_w (m s^{-1})','FontSize',lblsize)
ax = gca;
ax.YColor = 'k';
grid on; box on
ax.XMinorGrid = 'on';
ax.XAxis.MinorTick = 'on';


%%
% -------------------------------------------------------------------------
% kw Calculations
% -------------------------------------------------------------------------
% ---1. Dynamic Conditions-------------------------------------------------
% Calculate Pro-Oceanus flux and kw(t)
dt = seconds(poPaired.datetime_local(2) - poPaired.datetime_local(1)); % TT_5min has uniform spacing by definition
dCwdt_sg = gradient(Cw_pair, dt);  % (ppm s-1); gradient function computes central differences for interior points
fwPO_ppm = -H * dCwdt_sg;          % (ppm m s-1)
kwPO_dynamic = fwPO_ppm ./ (Cw_pair - Ca_pair); % (m s-1)

% Calculate Eosense kw(t) using Eq. 22
kw_dynamic = Sm / Sw * ka ./ ((Cw_pair - Cs_pair) ./ (Cs_pair - Cr_pair) - ka/kc); % (m s-1)

% Visually identify pseudo-steady state window
figure,clf
title(expName,'Interpreter','none')
elapsed_h = eosPaired.elapsed_s / 3600;

yyaxis left
plot(elapsed_h, Cr_pair, '.-','color', ref_clr, 'DisplayName', 'C_{r}')
hold on
plot(elapsed_h, Cs_pair, '.-', 'color', sample_clr, 'DisplayName', 'C_{s}')
plot(elapsed_h, Ca_pair, '-o', 'MarkerSize', 2,'color', POair_clr, 'DisplayName', 'C_{a}')
plot(elapsed_h, Cw_pair, '-^', 'MarkerSize', 2,'color', POwater_clr, 'DisplayName', 'C_{w}')
ylabel('CO_2 Concentration (ppm)','FontSize',lblsize)
lgd = legend('show','location','northeast');
lgd.NumColumns = 4;
lgd.FontSize = lgdsize;

yyaxis right
plot(elapsed_h, kw_dynamic, '.:', 'Color', sample_clr, 'DisplayName', 'k_{w} (Eq. 22)')
hold on
plot(elapsed_h, kwPO_dynamic, '.:', 'Color', POwater_clr, 'DisplayName', 'k_{w,PO} (from \partialC_w/\partialt)')
yline(0,'LineWidth',2,'Color','k','HandleVisibility','off')
xlim([0 20])
ylim([-5E-4 5E-4])
xlabel('Hours Elapsed','FontSize',lblsize)
ylabel('k_w (m s^{-1})','FontSize',lblsize)
ax = gca;
ax.YColor = 'k';
grid on; box on
ax.XMinorGrid = 'on';
ax.XAxis.MinorTick = 'on';
%%
% INPUT - choose indices!
% disp('Note start and stop indices for pseudo-steady state window, then press enter to continue')
% pause

% 2026-07-09_const-5_rep1
% ind_start_SS = 35;
% ind_stop_SS = 35;

% _const-5_rep2
% ind_start_SS = 10;
% ind_stop_SS = 22;

% 2026-07-10_const-15_rep1
ind_start_SS = 16;
ind_stop_SS = 18;

% 2026-07-13_wave-10-15_rep1
% ind_start_SS = 9;
% ind_stop_SS = 14;

% ---2. Pseudo-Steady State Conditions-------------------------------------
% Calculate mean concentrations
ind = ind_start_SS:ind_stop_SS;

Cw_ss = mean(Cw_pair(ind));
Cs_ss = mean(Cs_pair(ind));
Cr_ss = mean(Cr_pair(ind));

% Calculate Pro-Oceanus kw during pseudo-SS window
Ca_ss = mean(Ca_pair(ind));           % (ppm)
fwPO_ss = mean(fwPO_ppm(ind));        % (ppm m s-1)
kwPO_ms = fwPO_ss / (Cw_ss - Ca_ss);  % (m s-1)

% Calculate Eosense kw during pseudo-SS window
kw_ms = Sm / Sw * ka ./ ((Cw_ss - Cs_ss) ./ (Cs_ss - Cr_ss) - ka/kc); % (m s-1)

% Convert kw's from m s-1 to cm h-1
kw_cmh = kw_ms * 100 * 3600;           % (cm h-1)
kw_PO_cmh = kwPO_ms * 100 * 3600;      % (cm h-1)

txt1 = ['k_{w,EOS} (Eq. 22) = ',num2str(kw_cmh,3),' cm h^{-1}'];
txt2 = ['k_{w,PO} = ',num2str(kw_PO_cmh,3),' cm h^{-1}'];

% Plot Pro-Oceanus and Eosense kw's
figure,clf
title(expName,'Interpreter','none')
x1_SS = elapsed_h(ind_start_SS);
x2_SS = elapsed_h(ind_stop_SS);

yyaxis left
plot(elapsed_h, Cr_pair,'.-','color',ref_clr,'DisplayName','C_{r}')
hold on
plot(elapsed_h, Cs_pair,'.-','color',sample_clr,'DisplayName','C_{s} (corrected)')
plot(elapsed_h, Ca_pair,'-o','MarkerSize',2,'color',POair_clr,'DisplayName','C_{a,PO}')
plot(elapsed_h, Cw_pair,'-^','MarkerSize',2,'color',POwater_clr,'DisplayName','C_{w,PO}')
ylabel('CO_2 Concentration (ppm)','FontSize',lblsize)
% Add textbox with kw values
xt = elapsed_h(ind_start_SS);
text(xt, 490, txt1, 'FontSize', 12)
text(xt, 450, txt2, 'FontSize', 12)

yyaxis right
plot(elapsed_h, kw_dynamic, '.:', 'color', sample_clr, 'DisplayName', 'k_{w} (Eq. 22)')
hold on
plot(elapsed_h, kwPO_dynamic, '.:', 'color', POwater_clr, 'DisplayName', 'k_{w,PO} (from \partialC_w/\partialt)')
xlim([0 20])
ylim([-5E-4 5E-4])
yline(0, 'k', 'LineWidth', 2, 'HandleVisibility', 'off')
xlabel('Hours Elapsed','FontSize',lblsize)
ylabel('k_w (m s^{-1})','FontSize',lblsize)
lgd = legend('show','location','best');
lgd.NumColumns = 5;
lgd.FontSize = lgdsize;

yl = ylim;
fill([x1_SS x2_SS x2_SS x1_SS], [yl(1) yl(1) yl(2) yl(2)], 'r', 'FaceAlpha', 0.3, 'EdgeColor', 'none','DisplayName','Pseudo Steady State')
ax = gca;
ax.YColor = 'k';
grid on; box on
ax.XMinorGrid = 'on';
ax.XAxis.MinorTick = 'on';

%%
% Optional save figure
% cd(figPath)
% exportgraphics(gcf,'identify_pseudoSS.png','Padding','tight')
% savefig(gcf,'identify_pseudoSS.fig')

% -------------------------------------------------------------------------
% Flux Calculations
% -------------------------------------------------------------------------
% Calculate Cc(t) using Eq. 18
fig = figure;clf
plot(elapsed_h, Cs_pair, '.', 'color', sample_clr, 'DisplayName', 'C_{s}')
hold on
xlabel('Hours Elapsed','FontSize',lblsize)
ylabel('CO_2 Concentration (ppm)','FontSize',lblsize)
grid on; box on;
ax = gca;
ax.XMinorGrid = 'on';
ax.XAxis.MinorTick = 'on';

dcm_obj = datacursormode(fig);
datacursormode on;
disp([newline 'Click on the initial conditions data point in the plot, then press "Enter" in the Command Window']);
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

% Initial conditions
Cw0 = poPaired.water_conc(ind_t0);   % (ppm); initial water concentration
Cs0 = eosPaired.sample_conc(ind_t0); % (ppm); initial Sample concentration
Cr0 = eosPaired.ref_conc(ind_t0);    % (ppm); initial Reference concentration

t = seconds(eosPaired.datetime_local - eosPaired.datetime_local(1)); % (s)

kappa_w = Sw * kw_ms / Vc;              % (s-1); rate constant for enclosed water
tau_chamber = 1 / (kappa_w + kappa_c);  % (s); estimate of chamber time constant
A = Ca_pair - (kappa_w*Cw0 + kappa_c*Cs0) ./ (kappa_w + kappa_c);  % (ppm); constant (Eq. 17)
Cc = A .* exp(-(kappa_w + kappa_c) .* t) + (kappa_w .* Cw_pair + kappa_c .* Cs_pair) ./ (kappa_w + kappa_c); % (ppm)

% Plot result
figure,clf
plot(elapsed_h, Cs_pair, '.-', 'color', sample_clr, 'DisplayName', 'C_{s} (corrected)')
hold on
plot(elapsed_h, Cc, '.--', 'color', sample_clr, 'DisplayName', 'Calculated C_{c,}(t)')
plot(elapsed_h(ind_t0), Cs_pair(ind_t0), 'ok', 'MarkerSize', 8, 'DisplayName', 'Initial Conditions')
lgd = legend('show','location','northeast');
lgd.NumColumns = 3;
lgd.FontSize = lgdsize;
xlabel('Hours Elapsed','FontSize',lblsize)
ylabel('CO_2 Concentration (ppm)','FontSize',lblsize)
grid on; box on
ax = gca;
ax.XMinorGrid = 'on';
ax.XAxis.MinorTick = 'on';
title(expName,'Interpreter','none')

% Optional save figure
% cd(figPath)
% exportgraphics(gcf,'compare_Cs_Cc.png','Padding','tight')
% savefig(gcf,'compare_Cs_Cc.fig')

% disp('Press enter to continue to next plot')
% pause
%%
% ---Calculate fc, fw, fwt-------------------------------------------------
% For converting from ppm m s-1 --> umol m-2 s-1
P_Pa = poPaired.air_press * 100; % (Pa)

% Flux through bottom membrane (Eq. 10)
% nodes.(s).fc = kc * (Cc - Cs); % (Eq. 13)
fc_ppm = Vm/Sm * (gradient(Cs_pair, dt) - gradient(Cr_pair, dt)) + ka * (Cs_pair - Cr_pair);
fc = fc_ppm .* P_Pa ./ (R * Tair);

% Flux beneath chamber (Eq. 19)
fw_ppm = kw_ms * (Cw_pair - Cc);
fw = fw_ppm.* P_Pa ./ (R * Tair);

% True flux (Eq. 24)
fwt_ppm = kw_ms * (Cw_pair - Cr_pair);
fwt = fwt_ppm .* P_Pa ./ (R * Tair);

% Smooth the flux from PO water-inventory method for comparison
fwPO = fwPO_ppm .* P_Pa ./ (R * Tair);
flux_PO_smooth = smoothdata(fwPO,"movmean",5);

figure,clf
yline(0,'k','LineWidth',2,'HandleVisibility','off','Layer','bottom')
hold on
plot(elapsed_h, fc, '-', 'Color', sample_clr, 'DisplayName', '$f_{c}$ (Eq. 10)')
plot(elapsed_h, fw, '--', 'Color', sample_clr, 'DisplayName', '$f_{w}$ (Eq. 19)')
plot(elapsed_h, fwt, ':', 'Color', sample_clr, 'DisplayName', '$f_{w}^\dagger$ (Eq. 24)')
plot(elapsed_h, flux_PO_smooth, '-', 'Color', POwater_clr, 'DisplayName', '$f_{w,PO} = -h\cdot \partial C_w / \partial t$')
lgd = legend('show','location','south','interpreter','latex');
lgd.NumColumns = 2;
lgd.FontSize = lgdsize;
grid on; box on
ax = gca;
ax.XMinorGrid = 'on';
ax.XAxis.MinorTick = 'on';
xlabel('Hours Elapsed','FontSize',lblsize)
ylabel('Flux (\mumol m^{-2} s^{-1})','FontSize',lblsize)
xlim([0 18])
title(expName,'Interpreter','none')

% Optional save figure
% cd(figPath)
% exportgraphics(gcf,'compare_fluxes.png','Padding','tight')
% savefig(gcf,'compare_fluxes.fig')

%% HERE
% -------------------------------------------------------------------------
% Budget Calculations
% -------------------------------------------------------------------------
% 1. Calculate Pro-Oceanus net CO2 exchange rate using waterside measurements
L = 0.5;    % Length of container (m)
V = H*L^2;  % Volume of water (m3)
A = L^2;    % Area of water (m2)

% a. Convert xCO2 (ppmv) --> pCO2 (uatm)
P_atm = TT_5min.miniATM_air_Pmbar / 1013.25;    % total pressure conversion (atm)
pCO2_uatm = TT_5min.miniCO2_water_ppm .* P_atm; % CO2 partial pressure (uatm)

% b. Compute solubility constant, K0 using Weiss, 1974
Tw = TT_5min.water_T + 273.15; % (K)
K0 = expName(-60.2409 + 93.4517*(100./Tw) + 23.3585*log(Tw./100));  % (mol kg-1 atm-1); S = 0

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
% plot(elapsed_h, nodes.Dal.fw_total, '--', 'color', sample_clr, 'DisplayName','$f_{w,Dal} \cdot A$')
% hold on
% plot(elapsed_h, nodes.MIT.fw_total, '--', 'color', mit_sample_clr, 'DisplayName','$f_{w,MIT} \cdot A$')
% plot(elapsed_h(1:end-1), -dNsmooth_dt, '-', 'color', POwater_clr, 'DisplayName', '$\frac{-dN_{PO}}{dt}$')
% yline(0,'k','linewidth',2,'HandleVisibility','off')
% xlabel('Local Time')
% ylabel('Net CO_2 exchange rate (\mumol s^{-1})','FontSize',lblsize)
% legend('show','location','south','interpreter','latex')
% grid on; box on
% ax = gca;
% ax.XMinorGrid = 'on';
% ax.XAxis.MinorTick = 'on';

figure,clf
t = tiledlayout(2,1,'TileSpacing','tight');

ax1 = nexttile;
yline(0,'k','LineWidth',2,'HandleVisibility','off','Layer','bottom')
hold on
plot(elapsed_h, nodes.Dal.fc_total, '-', 'Color', sample_clr, 'DisplayName', '$f_{c,Dal} \cdot A$')
plot(elapsed_h, nodes.Dal.fw_total, '--', 'Color', sample_clr, 'DisplayName', '$f_{w,Dal} \cdot A$')
plot(elapsed_h, nodes.Dal.fwt_total, '-.', 'Color', sample_clr, 'DisplayName', '$f_{w,Dal}^\dagger \cdot A$')
plot(elapsed_h(1:end-1), -dNsmooth_dt, '-', 'color', POwater_clr, 'DisplayName', '$\frac{-dN_{PO}}{dt}$')
xlim([x1 x2])
ylim([-0.2 0.05])
xticklabels({})
lgd = legend('show','location','south','interpreter','latex');
lgd.NumColumns = 2;
lgd.FontSize = lgdsize;
grid on; box on;
ax = gca;
ax.XMinorGrid = 'on';
ax.XAxis.MinorTick = 'on';

ax2 = nexttile;
yline(0,'k','LineWidth',2,'HandleVisibility','off','Layer','bottom')
hold on
plot(elapsed_h, nodes.MIT.fc_total, '-', 'Color', mit_sample_clr, 'DisplayName', '$f_{c,MIT} \cdot A$')
plot(elapsed_h, nodes.MIT.fw_total, '--', 'Color', mit_sample_clr, 'DisplayName', '$f_{w,MIT} \cdot A$')
plot(elapsed_h, nodes.MIT.fwt_total, '-.', 'Color', mit_sample_clr, 'DisplayName', '$f_{w,MIT}^\dagger \cdot A$')
plot(elapsed_h(1:end-1), -dNsmooth_dt, '-', 'color', POwater_clr, 'DisplayName', '$\frac{-dN_{PO}}{dt}$')
xlim([x1 x2])
ylim([-0.2 0.05])
xlabel('Hours Elapsed','FontSize',lblsize)
lgd = legend('show','location','south','interpreter','latex');
lgd.NumColumns = 2;
lgd.FontSize = lgdsize;
grid on; box on
ax = gca;
ax.XMinorGrid = 'on';
ax.XAxis.MinorTick = 'on';
linkaxes([ax1 ax2], 'x', 'y')
ax2.XTick = ax1.XTick;
ylabel(t, 'Net CO_2 exchange rate (\mumol s^{-1})','FontSize',lblsize)

% Optional save figure
% cd(figPath)
% exportgraphics(gcf,'budget.png','Padding','tight')
% savefig(gcf,'budget.fig')

