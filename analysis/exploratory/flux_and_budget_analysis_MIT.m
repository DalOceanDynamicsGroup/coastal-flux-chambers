%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% flux_and_budget_analysis.m
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
% Major restructure: 5/6/2026
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear; close all; clc

% -------------------------------------------------------------------------
% Load the merged data file
% -------------------------------------------------------------------------
start_path = 'G:\My Drive\Dal and MIT\Lab Experiments\Data\';
dialog_title = 'Select an experiment data folder';
selPath = uigetdir(start_path,dialog_title);
[~,expt_name] = fileparts(selPath);
cd([selPath,'\merged - test']) % HERE
load('allDat.mat')
%%
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
% nodes.Dal.Cr = TT_5min.dal_ref_ppm;
nodes.Dal.Cr = TT_5min.dal_refcorr_ppm;
nodes.Dal.Cs = TT_5min.dal_samplecorr_ppm;
nodes.Dal.Ca = TT_5min.miniATM_air_ppm;
nodes.Dal.Cw = TT_5min.miniATM_water_ppm;

nodes.MIT.name = 'MIT';
% nodes.MIT.Cr = TT_5min.mit_ref_ppm;
nodes.MIT.Cr = TT_5min.mit_refcorr_ppm;
nodes.MIT.Cs = TT_5min.mit_samplecorr_ppm;
nodes.MIT.Cw = TT_5min.miniCO2_water_ppm;

%--------------------------------------------------------------------------
% Set path for saving figures
%--------------------------------------------------------------------------
switch expt_name
    case '2026-02-12_CO2-pulse-large'
        figPath = 'G:\My Drive\Dal and MIT\Lab Experiments\Figures\MIT\Expt - Large CO2 Pulse';
    case '2026-02-17_CO2-pulse-small'
        figPath = 'G:\My Drive\Dal and MIT\Lab Experiments\Figures\MIT\Expt - Small CO2 Pulse';
    case '2026-02-19_CO2-pulse-large-turbulent'
        figPath = 'G:\My Drive\Dal and MIT\Lab Experiments\Figures\MIT\Expt - Large Turbulent CO2 Pulse';
end

%--------------------------------------------------------------------------
% Define plotting conventions
%--------------------------------------------------------------------------
% Define plot limits
x1 = 0;  
x2 = 18;
y1 = 400;
y2 = 1300;

% Define plot colors
dal_ref_clr = '#8A2BE2';
dal_sample_clr = '#FF00FF';
mit_ref_clr = '#00441b';
mit_sample_clr = '#41ae76';
miniATM_air_clr = '#41b6c4';
miniATM_water_clr = '#0000CD';

lblsize = 18;
lgdsize = 16;

%--------------------------------------------------------------------------
% Compare Ca (Pro-Oceanus) and Cr (Dal Eosense Reference)
%--------------------------------------------------------------------------
figure,clf
plot(reltime, nodes.Dal.Cr, '.-', 'color', dal_ref_clr, 'DisplayName', 'C_{r,Dal}')
hold on
plot(reltime, nodes.MIT.Cr, '.-', 'color', mit_ref_clr, 'DisplayName', 'C_{r,MIT}')
plot(reltime, nodes.Dal.Ca, '.-', 'color', miniATM_air_clr, 'DisplayName', 'C_{a,PO}')
lgd = legend('show','location','northeast');
lgd.NumColumns = 3;
lgd.FontSize = lgdsize;
xlim([x1 x2])
ylim([y1 y2])
xlabel('Hours Elapsed','FontSize',lblsize)
ylabel('CO_2 Concentration (ppm)','FontSize',lblsize)
grid on; box on
ax = gca;
ax.XMinorGrid = 'on';
ax.XAxis.MinorTick = 'on';

% Optional save figure
% cd(figPath)
% exportgraphics(gcf,'compare_Ca_Cr.png','Padding','tight')
% savefig(gcf,'compare_Ca_Cr.fig')
%%
% disp('Press enter to continue')
% pause

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
plot(reltime, nodes.Dal.Cr, '-','color', dal_ref_clr, 'DisplayName', 'C_{r,Dal}')
hold on
plot(reltime, nodes.Dal.Cs, '-', 'color', dal_sample_clr, 'DisplayName', 'C_{s,Dal} (corrected)')
plot(reltime, nodes.MIT.Cr, '-', 'color', mit_ref_clr, 'DisplayName', 'C_{r,MIT}')
plot(reltime, nodes.MIT.Cs, '-','color', mit_sample_clr, 'DisplayName', 'C_{s,MIT} (corrected)')
plot(reltime, nodes.Dal.Ca, '-o', 'MarkerSize', 2,'color', miniATM_air_clr, 'DisplayName', 'C_{a,PO}')
plot(reltime, nodes.Dal.Cw, '-^', 'MarkerSize', 2,'color', miniATM_water_clr, 'DisplayName', 'C_{w,PO}')
xlim([x1 x2])
ylim([y1 y2])
ylabel('CO_2 Concentration (ppm)','FontSize',lblsize)
lgd = legend('show','location','northeast');
lgd.NumColumns = 4;
lgd.FontSize = lgdsize;

yyaxis right
plot(reltime, nodes.Dal.kw_dynamic, ':', 'Color', dal_sample_clr, 'DisplayName', 'Calculated k_{w,Dal}')
hold on
plot(reltime, nodes.MIT.kw_dynamic, ':', 'Color', mit_sample_clr, 'DisplayName', 'Calculated k_{w,MIT}')
yline(0,'LineWidth',2,'Color','k','HandleVisibility','off')
xlabel('Hours Elapsed','FontSize',lblsize)
ylabel('k_w (m s^{-1})','FontSize',lblsize)
xlim([x1 x2])
ylim([-1E-4 1E-4])
ax = gca;
ax.YColor = 'k';
grid on; box on
ax.XMinorGrid = 'on';
ax.XAxis.MinorTick = 'on';

% Optional save figure
% cd(figPath)
% exportgraphics(gcf,'dynamic_kw.png','Padding','tight')
% savefig(gcf,'dynamic_kw.fig')
%%
% INPUT - choose indices!
% disp('Note start and stop indices for pseudo-steady state window, then press enter to continue')
% pause

switch expt_name
    case '2026-02-12_CO2-pulse-large'
        % ind_start_SS = 30;
        % ind_stop_SS = 36;
        % ind_start_SS = 43;
        % ind_stop_SS = 49;
        ind_start_SS = 45;
        ind_stop_SS = 51;
    case '2026-02-17_CO2-pulse-small'
        ind_start_SS = 16;
        ind_stop_SS = 22;
    case '2026-02-19_CO2-pulse-large-turbulent'
        % ind_start_SS = 19;
        % ind_stop_SS = 25;
        ind_start_SS = 17;
        ind_stop_SS = 23;
end

ind = ind_start_SS:ind_stop_SS;

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
dt = seconds(TT_5min.TIME(2) - TT_5min.TIME(1)); % TT_5min has uniform spacing by definition

% Calculate flux from water-side measurements
Cw = nodes.Dal.Cw;
dCwdt = gradient(Cw, dt);  % (ppm s-1); gradient function computes central differences for interior points
fwPO_ppm = -H * dCwdt;     % (ppm m s-1)

% Calculate kw over entire time series for comparison
Ca = nodes.Dal.Ca;                    % (ppm); use Pro-Oceanus atmosphere
kwPO_dynamic = fwPO_ppm ./ (Cw - Ca); % (m s-1)

% Calculate kw during pseudo-SS window
Ca_ss = mean(nodes.Dal.Ca(ind));      % (ppm)
fwPO_ss = mean(fwPO_ppm(ind));        % (ppm m s-1)
kwPO_ms = fwPO_ss / (Cw_ss - Ca_ss);  % (m s-1)

% -------------------------------------------------------------------------
% Convert kw's from m s-1 to cm h-1
% -------------------------------------------------------------------------
nodes.Dal.kw_cmh = nodes.Dal.kw_ms * 100 * 3600; % (cm h-1)
nodes.MIT.kw_cmh = nodes.MIT.kw_ms * 100 * 3600; % (cm h-1)
kw_PO_cmh = kwPO_ms * 100 * 3600;                % (cm h-1)

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
x1_SS = reltime(ind_start_SS);
x2_SS = reltime(ind_stop_SS);

yyaxis left
plot(reltime, nodes.Dal.Cr,'-','color',dal_ref_clr,'DisplayName','C_{r,Dal}')
hold on
plot(reltime, nodes.Dal.Cs,'-','color',dal_sample_clr,'DisplayName','C_{s,Dal} (corrected)')
plot(reltime, nodes.MIT.Cr,'-','color',mit_ref_clr,'DisplayName','C_{r,MIT}')
plot(reltime, nodes.MIT.Cs,'-','color',mit_sample_clr,'DisplayName','C_{w,MIT} (corrected)')
plot(reltime, nodes.Dal.Ca,'-o','MarkerSize',2,'color',miniATM_air_clr,'DisplayName','C_{a,PO}')
plot(reltime, nodes.Dal.Cw,'-^','MarkerSize',2,'color',miniATM_water_clr,'DisplayName','C_{w,PO}')
xlim([x1 x2])
ylim([y1 y2])
ylabel('CO_2 Concentration (ppm)','FontSize',lblsize)
switch expt_name
    case '2026-02-12_CO2-pulse-large'
        xt = reltime(ind_start_SS); % x-position of text
        text(xt, 600, txt1, 'FontSize', 12)
        text(xt, 550, txt2, 'FontSize', 12)
        text(xt, 500, txt3, 'FontSize', 12)
    case '2026-02-17_CO2-pulse-small'
        xt = reltime(ind_start_SS); % x-position of text
        text(xt, 570, txt1, 'FontSize', 12)
        text(xt, 530, txt2, 'FontSize', 12)
        text(xt, 490, txt3, 'FontSize', 12)
    case '2026-02-19_CO2-pulse-large-turbulent'
        xt = reltime(ind_start_SS + 20); % x-position of text
        text(xt, 800, txt1, 'FontSize', 12)
        text(xt, 760, txt2, 'FontSize', 12)
        text(xt, 720, txt3, 'FontSize', 12)
end

yyaxis right
plot(reltime, nodes.Dal.kw_dynamic, ':', 'color', dal_sample_clr, 'DisplayName', 'k_{w,Dal} (Eq. 22)')
hold on
plot(reltime, nodes.MIT.kw_dynamic, ':', 'color', mit_sample_clr, 'DisplayName', 'k_{w,MIT} (Eq. 22)')
plot(reltime, kwPO_dynamic, ':', 'color', miniATM_water_clr, 'DisplayName', 'k_{w,PO} (from \partialC_w/\partialt)')
yline(0, 'k', 'LineWidth', 2, 'HandleVisibility', 'off')
xlabel('Hours Elapsed','FontSize',lblsize)
ylabel('k_w (m s^{-1})','FontSize',lblsize)
lgd = legend('show','location','northeast');
lgd.NumColumns = 5;
lgd.FontSize = lgdsize;
xlim([x1 x2])
% ylim([-1E-4 1E-4])
ylim([-0.0001 0.0001])

yl = ylim;
fill([x1_SS x2_SS x2_SS x1_SS], [yl(1) yl(1) yl(2) yl(2)], 'r', 'FaceAlpha', 0.3, 'EdgeColor', 'none','DisplayName','Pseudo Steady State')
ax = gca;
ax.YColor = 'k';
grid on; box on
ax.XMinorGrid = 'on';
ax.XAxis.MinorTick = 'on';

% Optional save figure
% cd(figPath)
% exportgraphics(gcf,'identify_pseudoSS.png','Padding','tight')
% savefig(gcf,'identify_pseudoSS.fig')

%%
figure,clf
plot(reltime, nodes.Dal.Cw - nodes.Dal.Cs, '-', 'color', dal_sample_clr, 'DisplayName', 'C_w - C_s (Dal)')
hold on
plot(reltime, nodes.Dal.Cs - nodes.Dal.Cr, '--', 'color', dal_sample_clr, 'DisplayName', 'C_s - C_r (Dal)')
plot(reltime, nodes.Dal.Cw - nodes.MIT.Cs, '-', 'color', mit_sample_clr, 'DisplayName', 'C_w - C_s (MIT)')
hold on
plot(reltime, nodes.MIT.Cs - nodes.MIT.Cr, '--', 'color', mit_sample_clr, 'DisplayName', 'C_s - C_r (MIT)')
xlabel('Hours Elapsed','FontSize',lblsize)
ylabel('Concentration difference (ppm)','FontSize',lblsize)
lgd = legend('show','FontSize',lblsize,'location','southeast');
lgd.NumColumns = 3;
lgd.FontSize = lgdsize;
xlim([x1 x2])
ylim([-700 100])

yl = ylim;
fill([x1_SS x2_SS x2_SS x1_SS], [yl(1) yl(1) yl(2) yl(2)], 'r', 'FaceAlpha', 0.3, 'EdgeColor', 'none','DisplayName','Pseudo Steady State')
ax = gca;

grid on; box on
ax.XMinorGrid = 'on';
ax.XAxis.MinorTick = 'on';

% Optional save figure
% cd(figPath)
% exportgraphics(gcf,'conc_differences.png','Padding','tight')
% savefig(gcf,'conc_differences.fig')
%%
% -------------------------------------------------------------------------
% Calculate eosFD fluxes
% -------------------------------------------------------------------------
% ---First calculate Cc(t) using Eq. 18------------------------------------
% Define initial conditions manually
fig = figure;clf
plot(reltime, nodes.Dal.Cs, '.', 'color', dal_sample_clr, 'DisplayName', 'C_{s,Dal}')
hold on
plot(reltime, nodes.MIT.Cs, '.', 'color', mit_sample_clr, 'DisplayName', 'C_{s,MIT}')
xlim([x1 x2])
xlabel('Hours Elapsed','FontSize',lblsize)
ylabel('CO_2 Concentration (ppm)','FontSize',lblsize)
grid on; box on;
ax = gca;
ax.XMinorGrid = 'on';
ax.XAxis.MinorTick = 'on';

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
plot(reltime, nodes.Dal.Cs, '.-', 'color', dal_sample_clr, 'DisplayName', 'C_{s,Dal} (corrected)')
hold on
plot(reltime, nodes.Dal.Cc, '-.', 'color', dal_sample_clr, 'DisplayName', 'Calculated C_{c,Dal}(t)')
plot(reltime, nodes.MIT.Cs, '.-', 'color', mit_sample_clr, 'DisplayName', 'C_{s,MIT} (corrected)')
plot(reltime, nodes.MIT.Cc, '-.', 'color', mit_sample_clr, 'DisplayName', 'Calculated C_{c,MIT}(t)')
plot(reltime(ind_t0), nodes.Dal.Cs(ind_t0), 'ok', 'MarkerSize', 8, 'DisplayName', 'Initial Conditions')
xlim([x1 x2])
ylim([y1 y2])
lgd = legend('show','location','northeast');
lgd.NumColumns = 3;
lgd.FontSize = lgdsize;
xlabel('Hours Elapsed','FontSize',lblsize)
ylabel('CO_2 Concentration (ppm)','FontSize',lblsize)
grid on; box on
ax = gca;
ax.XMinorGrid = 'on';
ax.XAxis.MinorTick = 'on';

% Optional save figure
% cd(figPath)
% exportgraphics(gcf,'compare_Cs_Cc.png','Padding','tight')
% savefig(gcf,'compare_Cs_Cc.fig')

% disp('Press enter to continue to next plot')
% pause
%
% figure,clf
% plot(nodes.Dal.Cs, nodes.Dal.Cc, '.', 'Color', dal_sample_clr, 'DisplayName', 'Dal')
% hold on
% plot(nodes.MIT.Cs, nodes.MIT.Cc, '.', 'Color', mit_sample_clr, 'DisplayName', 'MIT')
% currentLimits = [xlim ylim];
% minLimit = min(currentLimits);
% maxLimit = max(currentLimits);
% plot([minLimit maxLimit], [minLimit maxLimit], '--k', 'DisplayName', '1:1 Reference Line')
% legend('show','location','northeast')
% xlabel('C_s (ppm)','FontSize',lblsize)
% ylabel('C_c(t) (ppm)','FontSize',lblsize)
% axis square
%%
% -------------------------------------------------------------------------
% Calculate fc, fw, fwt and compare with PO water-inventory flux
% -------------------------------------------------------------------------
% For converting from ppm m s-1 --> umol m-2 s-1
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

figure,clf
t = tiledlayout(2,1,'TileSpacing','tight');

ax1 = nexttile;
yline(0,'k','LineWidth',2,'HandleVisibility','off','Layer','bottom')
hold on
plot(reltime, nodes.Dal.fc, '-', 'Color', dal_sample_clr, 'DisplayName', '$f_{c,Dal}$ (Eq. 10)')
plot(reltime, nodes.Dal.fw, '--', 'Color', dal_sample_clr, 'DisplayName', '$f_{w,Dal}$ (Eq. 19)')
plot(reltime, nodes.Dal.fwt, ':', 'Color', dal_sample_clr, 'DisplayName', '$f_{w,Dal}^\dagger$ (Eq. 24)')
plot(reltime, flux_PO_smooth, '-', 'Color', miniATM_water_clr, 'DisplayName', '$f_{w,PO} = -h\cdot \partial C_w / \partial t$')
xlim([x1 x2])
ylim([-0.8 0.2])
xticklabels({})
lgd = legend('show','location','south','interpreter','latex');
lgd.NumColumns = 2;
lgd.FontSize = lgdsize;
grid on; box on
ax = gca;
ax.XMinorGrid = 'on';
ax.XAxis.MinorTick = 'on';

ax2 = nexttile;
yline(0,'k','LineWidth',2,'HandleVisibility','off','Layer','bottom')
hold on
plot(reltime, nodes.MIT.fc, '-', 'Color', mit_sample_clr, 'DisplayName', '$f_{c,MIT}$ (Eq. 10)')
plot(reltime, nodes.MIT.fw, '--', 'Color', mit_sample_clr, 'DisplayName', '$f_{w,MIT}$ (Eq. 19)')
plot(reltime, nodes.MIT.fwt, ':', 'Color', mit_sample_clr, 'DisplayName', '$f_{w,MIT}^\dagger$ (Eq. 24)')
plot(reltime, flux_PO_smooth, '-', 'Color', miniATM_water_clr, 'DisplayName', '$f_{w,PO} = -h\cdot \partial C_w / \partial t$')
xlabel('Hours Elapsed','FontSize',lblsize)
lgd = legend('show','location','south','interpreter','latex');
lgd.NumColumns = 2;
lgd.FontSize = lgdsize;
grid on; box on
ax = gca;
ax.XMinorGrid = 'on';
ax.XAxis.MinorTick = 'on';
xlim([x1 x2])
ylim([-0.8 0.2])
linkaxes([ax1 ax2], 'x', 'y')
ax2.XTick = ax1.XTick;
ylabel(t, 'Flux (\mumol m^{-2} s^{-1})','FontSize',lblsize)

% Optional save figure
% cd(figPath)
% exportgraphics(gcf,'compare_fluxes.png','Padding','tight')
% savefig(gcf,'compare_fluxes.fig')

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
% plot(reltime, nodes.Dal.fw_total, '--', 'color', dal_sample_clr, 'DisplayName','$f_{w,Dal} \cdot A$')
% hold on
% plot(reltime, nodes.MIT.fw_total, '--', 'color', mit_sample_clr, 'DisplayName','$f_{w,MIT} \cdot A$')
% plot(reltime(1:end-1), -dNsmooth_dt, '-', 'color', miniATM_water_clr, 'DisplayName', '$\frac{-dN_{PO}}{dt}$')
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
plot(reltime, nodes.Dal.fc_total, '-', 'Color', dal_sample_clr, 'DisplayName', '$f_{c,Dal} \cdot A$')
plot(reltime, nodes.Dal.fw_total, '--', 'Color', dal_sample_clr, 'DisplayName', '$f_{w,Dal} \cdot A$')
plot(reltime, nodes.Dal.fwt_total, '-.', 'Color', dal_sample_clr, 'DisplayName', '$f_{w,Dal}^\dagger \cdot A$')
plot(reltime(1:end-1), -dNsmooth_dt, '-', 'color', miniATM_water_clr, 'DisplayName', '$\frac{-dN_{PO}}{dt}$')
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
plot(reltime, nodes.MIT.fc_total, '-', 'Color', mit_sample_clr, 'DisplayName', '$f_{c,MIT} \cdot A$')
plot(reltime, nodes.MIT.fw_total, '--', 'Color', mit_sample_clr, 'DisplayName', '$f_{w,MIT} \cdot A$')
plot(reltime, nodes.MIT.fwt_total, '-.', 'Color', mit_sample_clr, 'DisplayName', '$f_{w,MIT}^\dagger \cdot A$')
plot(reltime(1:end-1), -dNsmooth_dt, '-', 'color', miniATM_water_clr, 'DisplayName', '$\frac{-dN_{PO}}{dt}$')
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

%% Simplified plot
figure,clf
plot(reltime, nodes.Dal.fw, '-', 'Color', dal_sample_clr, 'DisplayName', '$f_{w,Dal}$')
hold on
plot(reltime, nodes.MIT.fw, '-', 'Color', mit_sample_clr, 'DisplayName', '$f_{w,MIT}$')
plot(reltime, flux_PO_smooth, '-', 'Color', miniATM_water_clr, 'DisplayName', '$f_{w,PO} = -h\cdot \partial C_w / \partial t$')
xlim([x1 x2])
% ylim([-0.8 0.2])
xlabel('Hours Elapsed','FontSize',24)
ylabel('Air-water Flux (\mumol m^{-2} s^{-1})','FontSize',24)
lgd = legend('show','location','south','interpreter','latex');
lgd.NumColumns = 3;
lgd.FontSize = 24;
grid on; box on
ax = gca;
ax.XMinorGrid = 'on';
ax.XAxis.MinorTick = 'on';