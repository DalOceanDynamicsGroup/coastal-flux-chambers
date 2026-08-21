%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% fluxDrifter_analysis.m
%
% Analysis of air-water CO2 fluxes measured using eosFD chambers and
% Pro-Oceanus sensors. Computes dynamic and steady-state kw, collar
% dynamics Cc(t), eosFD fluxes (fc, fw, fwt).
%
% Table and figure numbers refer to eosense_theory document.
%
% AUTHOR: Emily Chua
%
% DATE:
% First created: 8/2026
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
sample_dark = [255 0 255]/255; 
sample_light = 0.5*sample_dark + 0.5*[1 1 1];
ref_dark = [138 43 226]/255;
ref_light = 0.5*ref_dark + 0.5*[1 1 1];
POair_dark = [ 65 182 196]/255;
POwater_dark = [0 0 1];
POwater_light = 0.5*POwater_dark + 0.5*[1 1 1];

lblsize = 18;
lgdsize = 16;

% ---Load analysis-ready data file-----------------------------------------
projectRoot = 'C:\Users\Emily\OneDrive - Dalhousie University\Work\Dal and MIT\Field Deployments\Data\';
dialog_title = 'Select an experiment data folder';
selPath = uigetdir(projectRoot,dialog_title);
[~,expName] = fileparts(selPath);
filePath = fullfile(selPath, 'processed');

datFile = dir(fullfile(filePath, 'allDat*'));
S = load(fullfile(datFile(1).folder, datFile(1).name));
eosDat = S.eosDat;
thermDat = S.thermDat;
poFile = dir(fullfile(filePath, 'po*'));
S = load(fullfile(poFile(1).folder, poFile(1).name));
poDat = S.poDat;

eosOffsets = eosDat.Properties.UserData.eosOffsets;

figPath = fullfile(projectRoot,'Field Deployments','Figures');

figure,clf
plot(eosDat.datetime_local, eosDat.ref_conc, '.', 'color', ref_light, 'DisplayName', 'Reference eosFD')
hold on
plot(eosDat.datetime_local, eosDat.ref_conc_corr, '.', 'color', ref_dark, 'DisplayName', 'Reference eosFD (corrected)')
plot(eosDat.datetime_local, eosDat.sample_conc, '.', 'color', sample_light, 'DisplayName', 'Sample eosFD')
plot(eosDat.datetime_local, eosDat.sample_conc_corr, '.', 'color', sample_dark, 'DisplayName', 'Sample eosFD (Corrected)')
plot(poDat.all.datetime_local, poDat.all.conc, '.', 'color', POwater_dark, 'DisplayName', 'PO')
ylim([325 425])
xlabel('Local Time')
ylabel('CO_2 Concentration (ppm)')
legend('show','location','best','NumColumns',3)
grid on
title(expName,'Interpreter','none')

phaseID = findgroups(poDat.all.phase);

nPhase = max(phaseID);

phaseType = strings(nPhase,1);
phaseMean = nan(nPhase,1);
phaseTime = NaT(nPhase,1);
phaseTime.TimeZone = 'America/Halifax';

for k = 1:nPhase
    idxPhase = phaseID == k;
    thisDat = poDat.all(idxPhase,:);
    tEnd = thisDat.datetime_local(end);
    last30 = thisDat(thisDat.datetime_local >= tEnd - seconds(30),:);
    phaseMean(k) = mean(last30.conc,"omitnan");
    phaseTime(k) = tEnd;
    phaseType(k) = thisDat.phase(1);
end

poSummary = table(phaseTime,phaseType,phaseMean);
%%
Cr = eosDat.ref_conc_corr;
Cs = eosDat.sample_conc_corr;
% Cr = eosDat.ref_conc;
% Cs = eosDat.sample_conc;
Tair = thermDat.air_T + 273.15; % (K)

waterIdx = strcmp(poSummary.phaseType,'W M');
airIdx   = strcmp(poSummary.phaseType,'A M');

Cw = mean(poSummary.phaseMean(waterIdx),'omitnan');

if any(airIdx)
    Ca = mean(poSummary.phaseMean(airIdx),'omitnan');
else
    Ca = NaN;
end

Cw_vec = Cw*ones(size(Cs));
if ~isnan(Ca)
    Ca_vec = Ca*ones(size(Cs));
end

% -------------------------------------------------------------------------
% Calculate kw
% -------------------------------------------------------------------------
% idx = 260:length(Cr);
% idx = eosDat.datetime_local > datetime(2026,08,17,10,15,00,'TimeZone','America/Halifax');
idx = eosDat.datetime_local > datetime(2026,08,17,10,00,00,'TimeZone','America/Halifax');

Cs_bar = mean(Cs(idx));
Cr_bar = mean(Cr(idx));

kwEOS_ms = Sc/Sw * ka ./ ((Cw - Cs_bar) ./ (Cs_bar - Cr_bar) - ka/kc);

% kwEOS_ms = Sc/Sw * ka ./ ((Cw - Cs(idx)) ./ (Cs(idx) - Cr(idx)) - ka/kc);
kwEOS_cmh = kwEOS_ms * 100 * 3600;

R = (Cw - Cs_bar)/(Cs_bar - Cr_bar);

%%
figure,clf
yyaxis left
plot(eosDat.datetime_local, eosDat.ref_conc, '.', 'color', ref_light, 'DisplayName', 'Reference eosFD')
hold on
plot(eosDat.datetime_local, eosDat.ref_conc_corr, '.', 'color', ref_dark, 'DisplayName', 'Reference eosFD (corrected)')
plot(eosDat.datetime_local, eosDat.sample_conc, '.', 'color', sample_light, 'DisplayName', 'Sample eosFD')
plot(eosDat.datetime_local, eosDat.sample_conc_corr, '.', 'color', sample_dark, 'DisplayName', 'Sample eosFD (Corrected)')
plot(poDat.all.datetime_local, poDat.all.conc, '.', 'color', POwater_dark, 'DisplayName', 'PO')
ylim([325 425])
ylabel('CO_2 Concentration (ppm)')

yyaxis right
plot(eosDat.datetime_local(idx),kwEOS_cmh,'.')
ylim([-50 100])
ylabel('k_w (cm h^-1)')
xlabel('Local Time')
legend('show','location','best','NumColumns',3)
grid on
title(expName,'Interpreter','none')
