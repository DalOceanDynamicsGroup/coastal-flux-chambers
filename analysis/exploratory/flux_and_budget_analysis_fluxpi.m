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
clear; close all; clc

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
Sc = 804 / 10^6;                 % (m2); membrane surface area
Vm = 16.7 / 10^6;                % (m3); volume of measuring chamber

% Calculated
Sw = pi * r_collar^2;            % (m2); enclosed water surface area
Vc = pi * r_collar^2 * h_collar; % (m3); volume of collar
kappa_c = Sc * kc / Vc;          % (s-1); rate constant for bottom membrane

% Universal constants
R = 8.314;                       % (J mol-1 K-1)

% ---Define plotting conventions-------------------------------------------
concMin = 400;
concMax = 1100; % 1100, 1500
fluxMin = -0.7; % -0.7, -1.5
fluxMax = 0.2; % 0.1, 0.2

sample_dark = [255 0 255]/255; 
sample_light = 0.5*sample_dark + 0.5*[1 1 1];
ref_dark = [138 43 226]/255;
POair_dark = [ 65 182 196]/255;
POwater_dark = [0 0 1];
POwater_light = 0.5*POwater_dark + 0.5*[1 1 1];

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
pulseStart = S.pulseStart;
if isempty(datFile)
    error('No data file found.')
end
eosOffsets = eosDat.Properties.UserData.eosOffsets;

figPath = 'C:\Users\Emily\OneDrive - Dalhousie University\Google Drive Migration\Dal and MIT\Lab Experiments\Figures\Tank';

% ---Pair EOS and THERM to PO values---------------------------------------
eosPaired = retime(eosDat, poPaired.datetime_local, 'mean');
thermPaired = retime(thermDat, poPaired.datetime_local, 'mean');

% Use the paired EOS, THERM, and PO values in calculations
Cr_pair = eosPaired.ref_conc_corr;
Cs_pair = eosPaired.sample_conc_corr;
Ca_pair = poPaired.air_conc;
Cw_pair = poPaired.water_conc;
Tair = thermPaired.air_T + 273.15; % (K)

t_pulse_h = hours(poPaired.datetime_local - pulseStart);

% -------------------------------------------------------------------------
% Fit splines to selected data
% -------------------------------------------------------------------------
modes = {'none','PO','all'};
[idx,tf] = listdlg('PromptString','Choose a smoothing mode','SelectionMode','single','ListString',modes);
smoothMode = modes{idx};

% % Test smoothing parameter
% figure
% hold on
% for p = [0.9 0.95 0.99]
%     pp = csaps(t_pulse_h,Cw_pair,p);
%     dCwdt = fnval(fnder(pp),t_pulse_h);
% 
%     plot(t_pulse_h,dCwdt,'DisplayName',sprintf('p = %.2f',p))
%     ylim([-50 600])
%     legend('show')
% end

p = 0.9;            % Set smoothing parameter

switch smoothMode
    case 'none'
        Ca_fit = Ca_pair;
        Cw_fit = Cw_pair;
        Cs_fit = Cs_pair;
        Cr_fit = Cr_pair;

    case 'PO'
        pp_Cw = csaps(t_pulse_h,Cw_pair,p); % (ppm)
        pp_Ca = csaps(t_pulse_h,Ca_pair,p); % (ppm)

        Cw_fit = fnval(pp_Cw,t_pulse_h);
        Ca_fit = fnval(pp_Ca,t_pulse_h);

        Cs_fit = Cs_pair;
        Cr_fit = Cr_pair;

    case 'all'
        pp_Cw = csaps(t_pulse_h,Cw_pair,p); % (ppm)
        pp_Ca = csaps(t_pulse_h,Ca_pair,p); % (ppm)
        pp_Cs = csaps(t_pulse_h,Cs_pair,p); % (ppm)
        pp_Cr = csaps(t_pulse_h,Cr_pair,p); % (ppm)

        Cw_fit = fnval(pp_Cw,t_pulse_h);
        Ca_fit = fnval(pp_Ca,t_pulse_h);
        Cs_fit = fnval(pp_Cs,t_pulse_h);
        Cr_fit = fnval(pp_Cr,t_pulse_h);
end

switch smoothMode
    case 'none'
        figTitle = [expName,' (no splines)'];
        tag = "Raw";
    case 'PO'
        figTitle = [expName,' (PO splines)'];
        tag = sprintf('POspline_p%.2f',p);
    case 'all'
        figTitle = [expName,' (all splines)'];
        tag = sprintf('Allspline_p%.2f',p);
end

% Compare original data with splines
if smoothMode == "PO" || smoothMode == "all"
    fig1 = figure(1);clf
    plot(t_pulse_h,Cr_pair,'.','Color',ref_dark,'DisplayName','C_r')
    hold on
    plot(t_pulse_h,Cs_pair,'.','Color',sample_dark,'DisplayName','C_s')
    plot(t_pulse_h,Cw_pair,'.','Color',POwater_dark,'DisplayName','C_w')
    plot(t_pulse_h,Ca_pair,'.','Color',POair_dark,'DisplayName','C_a')
    plot(t_pulse_h,Cr_fit,'-','Color',ref_dark,'DisplayName','C_r (spline)')
    plot(t_pulse_h,Cs_fit,'-','Color',sample_dark,'DisplayName','C_s (spline)')
    plot(t_pulse_h,Cw_fit,'-','Color',POwater_dark,'DisplayName','C_w (spline)')
    plot(t_pulse_h,Ca_fit,'-','Color',POair_dark,'DisplayName','C_a (spline)')
    xlim([-1 17])
    legend('show','location','southeast','NumColumns',4)
    ylabel('Concentration (ppm)')
    xlabel('Elapsed Hours')
    grid on;box on
    title(figTitle,'interpreter','none')

    option = questdlg('Save Fig. 1?','Save Figure','Yes','No','Yes');
    switch option
        case 'Yes'
            exportgraphics(fig1,fullfile(figPath,'Concentration/',sprintf('%s_conc_%s.png',expName,tag)),'Padding','tight')
            savefig(fig1,fullfile(figPath,'Concentration/',sprintf('%s_conc_%s.fig',expName,tag)))
            fprintf('Figures saved as .png and .fig!\n\n')
        case 'No'
            fprintf('Figures not saved\n\n')
    end
else
    % No plot if no splines applied
end

% -------------------------------------------------------------------------
% Calculate first derivatives
% -------------------------------------------------------------------------
dt = seconds(poPaired.datetime_local(2) - poPaired.datetime_local(1));

switch smoothMode
    % dCdt in (ppm s-1)
    case 'none'
        dCwdt = gradient(Cw_fit,dt);
        dCadt = gradient(Ca_fit,dt);
        dCrdt = gradient(Cr_fit,dt);
        dCsdt = gradient(Cs_fit,dt);

    case 'PO'
        dCwdt = fnval(fnder(pp_Cw),t_pulse_h) / 3600;
        dCadt = fnval(fnder(pp_Ca),t_pulse_h) / 3600;

        dCrdt = gradient(Cr_fit,dt);
        dCsdt = gradient(Cs_fit,dt);

    case 'all'
        dCwdt = fnval(fnder(pp_Cw),t_pulse_h) / 3600;
        dCadt = fnval(fnder(pp_Ca),t_pulse_h) / 3600;
        dCrdt = fnval(fnder(pp_Cr),t_pulse_h) / 3600;
        dCsdt = fnval(fnder(pp_Cs),t_pulse_h) / 3600;
end

% -------------------------------------------------------------------------
% Calculate dynamic kw
% -------------------------------------------------------------------------
% Calculate Pro-Oceanus kw(t) from air-water flux
kwPO_dynamic = (-H * dCwdt) ./ (Cw_fit - Ca_fit); % (m s-1)

% Calculate Eosense kw(t) using Eq. 22
kwEOS_dynamic = Sc/Sw * ka ./ ((Cw_fit - Cs_fit) ./ (Cs_fit - Cr_fit) - ka/kc); % (m s-1)

% -------------------------------------------------------------------------
% Identify pseudo-steady state window
% -------------------------------------------------------------------------
% Plot kw results
figure,clf
yyaxis left
plot(t_pulse_h, Cr_fit, '-', 'color', ref_dark, 'DisplayName', 'C_{r}')
hold on
plot(t_pulse_h, Cs_fit, '-', 'color', sample_dark, 'DisplayName', 'C_{s}')
plot(t_pulse_h, Ca_fit, '-', 'MarkerSize', 2, 'color', POair_dark, 'DisplayName', 'C_{a}')
plot(t_pulse_h, Cw_fit, '-', 'MarkerSize', 2, 'color', POwater_dark, 'DisplayName', 'C_{w}')
ylabel('CO_2 Concentration (ppm)','FontSize',lblsize)
ylim([concMin concMax])
ax = gca;
ax.YColor = 'k';
lgd = legend('show','location','southeast');
lgd.NumColumns = 4;
lgd.FontSize = lgdsize;

yyaxis right
plot(t_pulse_h, kwEOS_dynamic, ':', 'Color', sample_light, 'DisplayName', 'k_{w} (Eq. 22)')
hold on
plot(t_pulse_h, kwPO_dynamic, ':', 'Color', POwater_light, 'DisplayName', 'k_{w,PO} (from \partialC_w/\partialt)')
yline(0,'LineWidth',2,'Color','k','HandleVisibility','off')
xlim([-1 17])
ylim([-1E-4 1E-4])
xlabel('Time Since Pulse (h)','FontSize',lblsize)
ylabel('k_w (m s^{-1})','FontSize',lblsize)
ax = gca;
ax.YColor = 'k';
grid on; box on
ax.XMinorGrid = 'on';
ax.XAxis.MinorTick = 'on';
title(figTitle,'interpreter','none')

% ---Method 1: Manually choose indices-------------------------------------
% disp('Note start and stop indices for pseudo-steady state window, then press enter to continue')
% pause

% 2026-07-09_const-5_rep1
% idx_start_SS = 24;
% idx_stop_SS = 34;

% _const-5_rep2
% idx_start_SS = 10;
% idx_stop_SS = 22;

% 2026-07-10_const-15_rep1
% idx_start_SS = 16;
% idx_stop_SS = 18;

% 2026-07-13_wave-10-15_rep1
% idx_start_SS = 8;
% idx_stop_SS = 13;

% idx = idx_start_SS:idx_stop_SS;

% ---Method 2: Sensitivity analysis----------------------------------------
t_pulse = hours(poPaired.datetime_local - pulseStart);
windowStart = [0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0];
windowEnd = windowStart + .5;

results = table();
for i = 1:numel(windowStart)

    idx = t_pulse >= windowStart(i) & t_pulse <= windowEnd(i);

    % Mean concentrations
    Ca_bar = mean(Ca_fit(idx));
    Cw_bar = mean(Cw_fit(idx));
    Cs_bar = mean(Cs_fit(idx));
    Cr_bar = mean(Cr_fit(idx));
    dCwdt_bar = mean(dCwdt(idx));

    % PO kw
    kwPO_ms = -H * dCwdt_bar / (Cw_bar - Ca_bar);
    kwPO_cmh = kwPO_ms * 100 * 3600;

    % EOS kw
    kwEOS_ms = Sc/Sw * ka / ((Cw_bar - Cs_bar)/(Cs_bar - Cr_bar) - ka/kc);
    kwEOS_cmh = kwEOS_ms * 100 * 3600;

    results = [results; table(windowStart(i),windowEnd(i),kwPO_cmh,kwEOS_cmh)];
end
results.kwPO_cmh = round(results.kwPO_cmh, 1);
results.kwEOS_cmh = round(results.kwEOS_cmh, 1);
results.Properties.VariableNames = {'windowStart_h','windowEnd_h','kwPO_cmh','kwEOS_cmh'};
disp(results)

% Automatically choose window where kwPO and kwEOS agree best
% Only keep windows where both kw estimates are positive
valid = results.kwPO_cmh > 0 & results.kwEOS_cmh > 0;
% Difference between methods
results.diff = abs(results.kwPO_cmh - results.kwEOS_cmh);
% Ignore invalid windows
diffValid = results.diff;
diffValid(~valid) = Inf;
% Find best window
[~,idxBest] = min(diffValid);

bestStart = results.windowStart_h(idxBest);
bestEnd = results.windowEnd_h(idxBest);

fprintf('Best window: %.1f-%.1f h\n\n',bestStart,bestEnd);

windowStart = t_pulse_h >= bestStart;
windowEnd = t_pulse_h <= bestEnd;
idx = windowStart & windowEnd;
t_start = t_pulse_h(find(idx,1,'first'));
t_stop = t_pulse_h(find(idx,1,'last'));

% ---Method 3: Choose window based on thresholds---------------------------
% D_eos = (Cw_fit-Cs_fit)./(Cs_fit-Cr_fit) - ka/kc;
% D_po = Cw_fit - Ca_fit;
% 
% gradient_threshold = 0.015; % (ppm s-1)
% D_po_threshold = 50;        % (ppm)
% D_eos_threshold = 10;       % (ppm)
% 
% mask = ...
%     abs(dCwdt) < gradient_threshold & ...
%     abs(dCadt) < gradient_threshold & ...
%     abs(dCsdt) < gradient_threshold & ...
%     abs(dCrdt) < gradient_threshold & ...
%     abs(D_po) > D_po_threshold & ...
%     abs(D_eos) > D_eos_threshold;
% 
% idx = find(mask);
% t_start = t_pulse_h(idx(1));
% t_stop = t_pulse_h(idx(end));
% 
% % Calculate steady-state means
% Ca_ss = mean(Ca_fit(idx));   % (ppm)
% Cw_ss = mean(Cw_fit(idx));
% Cs_ss = mean(Cs_fit(idx));
% Cr_ss = mean(Cr_fit(idx));
% dCwdt_ss = mean(dCwdt(idx)); % (ppm s-1)
% 
% % Steady-state PO kw
% kwPO_ms = (-H * dCwdt_ss) / (Cw_ss - Ca_ss); % (m s-1)
% kwPO_cmh = kwPO_ms * 100 * 3600;             % (cm h-1)
% 
% % Steady-state EOS kw
% kwEOS_ms = Sc / Sw * ka ./ ((Cw_ss - Cs_ss) ./ (Cs_ss - Cr_ss) - ka/kc);  % (m s-1)
% kwEOS_cmh = kwEOS_ms * 100 * 3600;                                        % (cm h-1)
% 
% % Create text box with kw values
% txt1 = ['k_{w,EOS} (Eq. 22) = ',num2str(kwEOS_cmh,3),' cm h^{-1}'];
% txt2 = ['k_{w,PO} = ',num2str(kwPO_cmh,3),' cm h^{-1}'];
% 
% figure;clf
% yyaxis left
% plot(t_pulse_h,dCrdt,'-','color',ref_dark,'DisplayName','dC_r/dt')
% hold on
% plot(t_pulse_h,dCsdt,'-','Color',sample_dark,'DisplayName','dC_s/dt')
% plot(t_pulse_h,dCwdt,'-','color',POwater_dark,'DisplayName','dC_w/dt')
% plot(t_pulse_h,dCadt,'-','color',POair_dark,'DisplayName','dC_a/dt')
% yline(0,'k','linewidth',2,'HandleVisibility','off')
% xlim([-1 17])
% ylim([-0.02 0.02])
% ax = gca;
% ax.YColor = 'k';
% ylabel('dC/dt (ppm s^{-1})','FontSize',lblsize)
% 
% yyaxis right
% plot(t_pulse_h,D_eos,':','color',sample_dark,'DisplayName','D_{EOS}')
% hold on
% plot(t_pulse_h,D_po,':','color',POwater_dark,'DisplayName','D_{PO}')
% xregion(t_start, t_stop, FaceColor='r', FaceAlpha=0.15, DisplayName='Pseudo Steady State');
% yline(0,'k','HandleVisibility','off')
% ylabel('k_w denominator, D','FontSize',lblsize)
% xlabel('Time (h)','FontSize',lblsize)
% % Add textbox with kw values
% text(t_start, -60, txt1, 'FontSize', 12)
% text(t_start, -70, txt2, 'FontSize', 12)
% ylim([-100 200])
% grid on
% ax = gca;
% ax.YColor = 'k';
% grid on; box on
% ax.XMinorGrid = 'on';
% ax.XAxis.MinorTick = 'on';
% lgd = legend('show','location','southeast','NumColumns',4);
% lgd.FontSize = lgdsize;
% title(figTitle,'interpreter','none')

% -------------------------------------------------------------------------
% Calculate pseudo-SS kw
% -------------------------------------------------------------------------
% Calculate steady-state means
Ca_ss = mean(Ca_fit(idx));   % (ppm)
Cw_ss = mean(Cw_fit(idx));
Cs_ss = mean(Cs_fit(idx));
Cr_ss = mean(Cr_fit(idx));
dCwdt_ss = mean(dCwdt(idx)); % (ppm s-1)

% Steady-state PO kw
kwPO_ms = (-H*dCwdt_ss) / (Cw_ss-Ca_ss); % (m s-1)
kwPO_cmh = kwPO_ms*100*3600;             % (cm h-1)

% Steady-state EOS kw
kwEOS_ms = Sc/Sw*ka ./ ((Cw_ss-Cs_ss)./(Cs_ss-Cr_ss) - ka/kc);  % (m s-1)
kwEOS_cmh = kwEOS_ms*100*3600;                                  % (cm h-1)

% Create text box with kw values
txt1 = ['k_{w,EOS} (Eq. 22) = ',num2str(kwEOS_cmh,3),' cm h^{-1}'];
txt2 = ['k_{w,PO} = ',num2str(kwPO_cmh,3),' cm h^{-1}'];

% Plot Pro-Oceanus and Eosense kw's
fig2 = figure(2);clf
yyaxis left
plot(t_pulse_h, Cr_fit,'-','color',ref_dark,'DisplayName','C_{r}')
hold on
plot(t_pulse_h, Cs_fit,'-','color',sample_dark,'DisplayName','C_{s} (corrected)')
plot(t_pulse_h, Ca_fit,'-','MarkerSize',2,'color',POair_dark,'DisplayName','C_{a,PO}')
plot(t_pulse_h, Cw_fit,'-','MarkerSize',2,'color',POwater_dark,'DisplayName','C_{w,PO}')
ylabel('CO_2 Concentration (ppm)','FontSize',lblsize)
ylim([concMin concMax])
% Add textbox with kw values
text(t_start, 490, txt1, 'FontSize', 12)
text(t_start, 450, txt2, 'FontSize', 12)
ax = gca;
ax.YColor = 'k';

yyaxis right
plot(t_pulse_h, kwEOS_dynamic, ':', 'color', sample_light, 'DisplayName', 'k_{w} (Eq. 22)')
hold on
plot(t_pulse_h, kwPO_dynamic, ':', 'color', POwater_light, 'DisplayName', 'k_{w,PO} (from \partialC_w/\partialt)')
xregion(t_start, t_stop, FaceColor='r', FaceAlpha=0.15, DisplayName='Pseudo Steady State');
xlim([-1 17])
ylim([-1E-4 1E-4])
yline(0, 'k', 'LineWidth', 2, 'HandleVisibility', 'off')
xlabel('Time Since Pulse (h)','FontSize',lblsize)
ylabel('k_w (m s^{-1})','FontSize',lblsize)
lgd = legend('show','location','best','NumColumns',5);
lgd.FontSize = lgdsize;
ax = gca;
ax.YColor = 'k';
grid on; box on
ax.XMinorGrid = 'on';
ax.XAxis.MinorTick = 'on';
title(figTitle,'interpreter','none')

% Optional save figure
option = questdlg('Save Fig. 2?','Save Figure','Yes','No','Yes');
switch option
    case 'Yes'
        exportgraphics(fig2,fullfile(figPath,'kw/',sprintf('%s_kw_%s.png',expName,tag)),'Padding','tight')
        savefig(fig2,fullfile(figPath,'kw/',sprintf('%s_kw_%s.fig',expName,tag)))
        fprintf('Figures saved as .png and .fig!\n\n')
    case 'No'
        fprintf('Figures not saved\n\n')
end

% -------------------------------------------------------------------------
% Calculate fluxes
% -------------------------------------------------------------------------
% ---1. Calculate time-varying collar concentration, Cc(t) (Eq. 18)--------
% Initial conditions
diff_vec = abs(eosPaired.datetime_local - pulseStart);
idx0 = find(diff_vec == min(abs(diff_vec)));
ind_t0 = idx0 - 1;
Cw0 = Cw_fit(ind_t0); % (ppm); initial water concentration
Cs0 = Cs_fit(ind_t0); % (ppm); initial Sample concentration
Cr0 = Cr_fit(ind_t0); % (ppm); initial Reference concentration

kappa_w = Sw * kwEOS_ms / Vc;           % (s-1); rate constant for enclosed water
tau_chamber = 1 / (kappa_w + kappa_c);  % (s); estimate of chamber time constant
A = Ca_fit - (kappa_w*Cw0 + kappa_c*Cs0) ./ (kappa_w + kappa_c);  % (ppm); constant (Eq. 17)
Cc = A .* exp(-(kappa_w + kappa_c) .* dt) + (kappa_w .* Cw_fit + kappa_c .* Cs_fit) ./ (kappa_w + kappa_c); % (ppm)

% % Plot result
% figure,clf
% plot(t_pulse_h, Cs_pair, '.-', 'color', sample_clr, 'DisplayName', 'C_{s} (corrected)')
% hold on
% plot(t_pulse_h, Cc, '.--', 'color', sample_clr, 'DisplayName', 'Calculated C_{c,}(t)')
% plot(t_pulse_h(ind_t0), Cs_pair(ind_t0), 'ok', 'MarkerSize', 8, 'DisplayName', 'Initial Conditions')
% lgd = legend('show','location','northeast');
% lgd.NumColumns = 3;
% lgd.FontSize = lgdsize;
% xlabel('Time Since Pulse (h)','FontSize',lblsize)
% ylabel('CO_2 Concentration (ppm)','FontSize',lblsize)
% grid on; box on
% ax = gca;
% ax.XMinorGrid = 'on';
% ax.XAxis.MinorTick = 'on';
% title(figTitle,'interpreter','none')

% ---2. Calculate fluxes---------------------------------------------------
% 2a. Flux through bottom membrane, fc (Eq. 10)
fc_ppm = Vm/Sc*(gradient(Cs_fit,dt) - gradient(Cr_fit,dt)) + ka*(Cs_fit - Cr_fit); % (ppm m s-1)

% 2b. Flux beneath chamber, fw (Eq. 19)
fw_ppm = kwEOS_ms*(Cw_fit - Cc); % (ppm m s-1)

% 2c. True flux, fwt (Eq. 24)
fwt_ppm = kwEOS_ms*(Cw_fit - Cr_fit); % (ppm m s-1)

% Convert fluxes from ppm m s-1 --> umol m-2 s-1
P_Pa = poPaired.air_press * 100; % (Pa)
fc = fc_ppm .* P_Pa ./ (R * Tair);
fw = fw_ppm .* P_Pa ./ (R * Tair);
fwt = fwt_ppm .* P_Pa ./ (R * Tair);
fwPO = (-H * dCwdt) .* P_Pa ./ (R * Tair);

% Smooth fc and PO water-inventory flux for comparison
fwPO_smooth = smoothdata(fwPO,"movmean",5);
fc_smooth = smoothdata(fc,"movmean",5);

fig3 = figure(3); clf
yline(0,'k','LineWidth',2,'HandleVisibility','off')
hold on
% Raw fluxes
plot(t_pulse_h, fc, '-', 'Color', sample_dark, 'DisplayName', '$f_{c}$ (Eq. 10)')
plot(t_pulse_h, fw, '--', 'Color', sample_dark, 'DisplayName', '$f_{w}$ (Eq. 19)')
plot(t_pulse_h, fwt, '-.', 'Color', sample_dark, 'DisplayName', '$f_{w}^\dagger$ (Eq. 24)')
plot(t_pulse_h, fwPO, '-', 'Color', POwater_dark, 'DisplayName', '$f_{w,PO} = -h\cdot \partial C_w / \partial t$')
% Smoothed fluxes
plot(t_pulse_h, fc_smooth, ':', 'Color', sample_light, 'LineWidth', 1.5, 'DisplayName', '$f_{c}$ (Eq. 10) (smoothed)')
plot(t_pulse_h, fwPO_smooth, ':', 'Color', POwater_light, 'LineWidth', 1.5, 'DisplayName', '$f_{w,PO} = -h\cdot \partial C_w / \partial t$ (smoothed)')
lgd = legend('show','location','south','interpreter','latex','NumColumns',3,'FontSize',lgdsize);
grid on; box on
ax = gca;
ax.XMinorGrid = 'on';
ax.XAxis.MinorTick = 'on';
xlabel('Time Since Pulse (h)','FontSize',lblsize)
ylabel('Flux (\mumol m^{-2} s^{-1})','FontSize',lblsize)
xlim([-1 17])
ylim([fluxMin fluxMax])
title(figTitle,'interpreter','none')

% Optional save figure
option = questdlg('Save Fig. 3?','Save Figure','Yes','No','Yes');
switch option
    case 'Yes'
        exportgraphics(fig3,fullfile(figPath,'Flux/',sprintf('%s_flux_%s.png',expName,tag)),'Padding','tight')
        savefig(fig3,fullfile(figPath,'Flux/',sprintf('%s_flux_%s.fig',expName,tag)))
        fprintf('Figures saved as .png and .fig!\n\n')
    case 'No'
        fprintf('Figures not saved\n\n')
end

% -------------------------------------------------------------------------
% Uncertainty propagation
% -------------------------------------------------------------------------
% Uncertainties
% Calibration coeffs: use standard error of the mean
sigma_ref = 4.11E-5/sqrt(6);
sigma_sample = 5.80E-5/sqrt(3);
sigma_ka = 0.5*sqrt(sigma_ref^2 + sigma_sample^2);
sigma_kc = 1.45E-6/sqrt(3);
% Concentrations: Use standard error of the pseudo-SS window means
sigma_Cw = std(Cw_fit(idx))/sqrt(sum(idx));
sigma_Ca = std(Ca_fit(idx))/sqrt(sum(idx));
sigma_Cr = std(Cr_fit(idx))/sqrt(sum(idx));
sigma_Cs = std(Cs_fit(idx))/sqrt(sum(idx));

% ---1. Uncertainty in kw--------------------------------------------------
A = Sc/Sw;
D = (Cw_ss-Cs_ss)/(Cs_ss-Cr_ss) - ka/kc;

dkw_dka = A*((Cw_ss-Cs_ss)/(Cs_ss-Cr_ss))/D^2;
dkw_dkc = -A*ka^2/(kc^2*D^2);
dkw_dCw = -A*ka/((Cs_ss-Cr_ss)*D^2);
dkw_dCs = A*ka*(Cw_ss-Cr_ss)/((Cs_ss-Cr_ss)^2*D^2);
dkw_dCr = -A*ka*(Cw_ss-Cs_ss)/((Cs_ss-Cr_ss)^2*D^2);

sigma_kw_ms = sqrt(...
    (dkw_dka*sigma_ka)^2 + ...
    (dkw_dkc*sigma_kc)^2 + ...
    (dkw_dCw*sigma_Cw)^2 + ...
    (dkw_dCr*sigma_Cr)^2) + ...
    (dkw_dCs*sigma_Cs)^2;            % (m s-1)

sigma_kw_cmh = sigma_kw_ms*100*3600; % (cm h-1)

fprintf('k_w (EOS) = %.1f +- %.1f\n\n',kwEOS_cmh,sigma_kw_cmh)

term_ka = (dkw_dka*sigma_ka)^2;
term_kc = (dkw_dkc*sigma_kc)^2;
term_Cw = (dkw_dCw*sigma_Cw)^2;
term_Cs = (dkw_dCs*sigma_Cs)^2;
term_Cr = (dkw_dCr*sigma_Cr)^2;

pct = 100*[term_ka term_kc term_Cw term_Cs term_Cr] / ...
    (term_ka + term_kc + term_Cw + term_Cs + term_Cr);

fprintf(['Uncertainty contributions:\n',...
    '  k_a : %.1f%%\n',...
    '  k_c : %.1f%%\n',...
    '  C_w : %.1f%%\n',...
    '  C_s : %.1f%%\n',...
    '  C_r : %.1f%%\n'], ...
    pct(1), pct(2), pct(3), pct(4), pct(5))
%%
% ---2. Uncertainty in flux------------------------------------------------
dfwt_dkw = (Cw_ss - Ca_ss);
dfwt_dCw = kwEOS_ms;
dfwt_dCa = -kwEOS_ms;

sigma_fwt_ppm = sqrt(...
    (dfwt_dkw*sigma_kw_ms)^2 + ...
    (dfwt_dCw*sigma_Cw)^2 + ...
    (dfwt_dCa*sigma_Ca)^2);       % (ppm m s-1)

P_Pa_ss = mean(P_Pa(idx));
Tair_ss = mean(Tair(idx));
sigma_fwt_umol = sigma_fwt_ppm .* P_Pa_ss ./ (R * Tair_ss); % (umol m-2 s-1)

%%
delta_fwt = abs(fwt - fwPO);

fig4 = figure(4); clf
yline(0,'k','LineWidth',2,'HandleVisibility','off')
hold on
plot(t_pulse_h, delta_fwt, '-', 'Color', 'r', 'DisplayName', '$|f_{w}^\dagger - f_{w,PO}|$')
hold on
yline(sigma_fwt_umol, '--', 'LineWidth', 2, 'DisplayName' , '$\sigma_{f_w^\dagger}$')
lgd = legend('show','location','north','interpreter','latex','FontSize',lgdsize);
xlim([-1 17])
grid on; box on
ax = gca;
ax.XMinorGrid = 'on';
ax.XAxis.MinorTick = 'on';
xlabel('Time Since Pulse (h)','FontSize',lblsize)
ylabel('\Delta flux (\mumol m^{-2} s^{-1})','FontSize',lblsize)
title(figTitle,'interpreter','none')
%%
fig5 = figure(5); clf
yline(0,'k','LineWidth',2,'HandleVisibility','off')
hold on
% Raw fluxes
plot(t_pulse_h, fc*Sc/Sw, '-', 'Color', sample_dark, 'DisplayName', '$S_c/S_w f_c$')
hold on
% yline(sigma_fwt_umol, '--', 'LineWidth', 2, 'DisplayName' , '$\sigma_{f_w^\dagger}$')
plot(t_pulse_h, fw, '--', 'Color', sample_dark, 'DisplayName', '$f_{w}$')
lgd = legend('show','location','north','interpreter','latex','FontSize',lgdsize);
xlim([-1 17])
grid on; box on
ax = gca;
ax.XMinorGrid = 'on';
ax.XAxis.MinorTick = 'on';
xlabel('Time Since Pulse (h)','FontSize',lblsize)
ylabel('\Delta flux (\mumol m^{-2} s^{-1})','FontSize',lblsize)
title(figTitle,'interpreter','none')


% plot(t_pulse_h, fc, '-', 'Color', sample_dark, 'DisplayName', '$f_{c}$ (Eq. 10)')
% plot(t_pulse_h, fw, '--', 'Color', sample_dark, 'DisplayName', '$f_{w}$ (Eq. 19)')
% plot(t_pulse_h, fwt, '-.', 'Color', sample_dark, 'DisplayName', '$f_{w}^\dagger$ (Eq. 24)')
% plot(t_pulse_h, fwPO, '-', 'Color', POwater_dark, 'DisplayName', '$f_{w,PO} = -h\cdot \partial C_w / \partial t$')