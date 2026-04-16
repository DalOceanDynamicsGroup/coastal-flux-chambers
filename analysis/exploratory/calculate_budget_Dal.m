% Make sure to change "INPUT"

clear;close all;clc

% -------------------------------------------------------------------------
% Load Dal Eosense and Pro-Oceanus data
% -------------------------------------------------------------------------
start_path = 'G:\My Drive\Dal and MIT\Lab Experiments\Data\';
dialog_title = 'Select an experiment data folder';
selpath = uigetdir(start_path,dialog_title);
[~,sample_date] = fileparts(selpath);

% Load Dal Eosense data
cd([selpath,'\Eosense\Processed'])
datFile = dir('*.mat');
load(datFile.name);

% Load Dal Pro-Oceanus data
cd([selpath,'\Pro-Oceanus\Processed'])
datFile = dir('*.mat');
load(datFile.name);
% Remove rows with missing Pro-Oceanus pCO2 data
pro_air(find(isnan(pro_air.mean_xCO2_ppm)),:) = [];
pro_water(find(isnan(pro_water.mean_xCO2_ppm)),:) = [];
% Remove phase column
pro_air.phase = [];
pro_water.phase = [];

% -------------------------------------------------------------------------
% Compute Eosense flux from bias-corrected concentrations
% -------------------------------------------------------------------------
% INPUTS
G = 3.01E-4;        % (m s-1); from Eosense calibration note
dal_offset = 6.51;  % (ppm)

% First, synchronize all the data (calculations need total pressure from Pro-Oceanus)
% Switch the Dal Eosense datetime column to the local time
eosDat = timetable2table(eosDat);
newRowTimes = eosDat.datetime_local;
eosDat.datetime_utc = [];
eosDat.datetime_local = [];
eosDat.datetime_local = newRowTimes;
eosDat = table2timetable(eosDat);

TT_sync = synchronize(pro_water, pro_air, eosDat, 'union', 'nearest');
TT_5min = retime(TT_sync,'regular','mean','TimeStep',minutes(5));
TT_5min.Properties.VariableNames = {'ppm_water','P_mbar_water','T_irga_water','ppm_air','P_mbar_air','T_irga_air','ppm_ref','ppm_sample','T_ref','T_sample','flux_sample'};

% 1. Convert Eosense xCO2 (ppm) --> pCO2 (uatm)
% pCO2(uatm) = xCO2(ppm) * P(uatm)
pCO2ref = TT_5min.ppm_ref .* TT_5min.P_mbar_water / 1013.25;  % (uatm)
pCO2sample = TT_5min.ppm_sample .* TT_5min.P_mbar_water / 1013.25; % (uatm)
pCO2sample_corrected = (TT_5min.ppm_sample - dal_offset) .* TT_5min.P_mbar_water / 1013.25; % (uatm)

% 2. Convert pCO2 (uatm) --> aqueous CO2 concentration (umol m-3) using Henry's Law; get K0 from Weiss, 1974
% Use chamber T's (T_ref and T_sample)
% Reference Node
T_ref = TT_5min.T_ref + 273.15; % (K)
K0 = exp(-60.2409 + 93.4517*(100./T_ref) + 23.3585*log(T_ref./100));  % (mol L-1 atm-1); S = 0
Cref = K0 .* pCO2ref * 10^3; % (umol m-3)
% Sample Node
T_sample = TT_5min.T_sample + 273.15; % (K)
K0 = exp(-60.2409 + 93.4517*(100./T_sample) + 23.3585*log(T_sample./100));  % (mol L-1 atm-1); S = 0
Csample = K0 .* pCO2sample * 10^3; % (umol m-3)
Csample_corrected = K0 .* pCO2sample_corrected * 10^3; % (umol m-3)

% 3. Compute the flux
calculated_flux_dal = G * (Csample - Cref);             % (umol m-2 s-1)
corrected_flux_dal = G * (Csample_corrected - Cref);    % (umol m-2 s-1)
%%
% -------------------------------------------------------------------------
% Compute Pro-Oceanus aqueous concentrations from water- and air-side xCO2 measurements
% -------------------------------------------------------------------------
% 1. Convert Pro-Oceanus water and air concentrations (ppm) --> pCO2 (uatm)
pCO2w = TT_5min.ppm_water .* TT_5min.P_mbar_water / 1013.25;  % (uatm)
pCO2a = TT_5min.ppm_air .* TT_5min.P_mbar_air / 1013.25;      % (uatm)

% 2. Convert pCO2 (uatm) --> aqueous CO2 concentration (umol m-3) using Henry's Law; get K0 from Weiss, 1974
% Use IR cell T's (T_irga for water- and air-side measurements)
% Water side
T_w = TT_5min.T_irga_water + 273.15; % (K)
K0 = exp(-60.2409 + 93.4517*(100./T_w) + 23.3585*log(T_w./100));  % (mol L-1 atm-1); S = 0
Cw = K0 .* pCO2w * 10^3;    % (umol m-3)
% Air side
T_a = TT_5min.T_irga_air + 273.15;  % (K)
K0 = exp(-60.2409 + 93.4517*(100./T_a) + 23.3585*log(T_a./100));  % (mol L-1 atm-1); S = 0
Ca = K0 .* pCO2a * 10^3;    % (umol m-3)

C_TT = table(TT_5min.datetime_local,Cw,Ca,'VariableNames',{'datetime_local','Cw','Ca'});
C_TT = table2timetable(C_TT);

%%
% -------------------------------------------------------------------------
% Do the budget calculations
% -------------------------------------------------------------------------
% 1. Convert dissolved CO2 --> Total moles in bucket
H = 0.279;  % (m)
W = 0.356;  % (m)
L = 0.381;  % (m)
V = H*W*L;  % Volume of water (m3)
N = C_TT.Cw * V;  % (umol)
N_TT = table(TT_5min.datetime_local,N,'VariableNames',{'datetime_local','NCO2'});

N_smooth = smooth(N_TT.NCO2,5); % (umol)

% 4. Compute the Pro-Oceanus rate of CO2 change across the measurement period
% dN_dt = diff(N) ./ seconds(diff(N_TT.datetime_local));    % (umol s-1); unsmoothed
dN_dt = diff(N_smooth) ./ seconds(diff(N_TT.datetime_local)); % (umol s-1); smoothed

% 5. Compute F_eos x A
flux_total_dal = TT_5min.flux_sample * W * L; % (umol s-1)
flux_total_dal_calculated = calculated_flux_dal * W * L;
flux_total_dal_corrected = corrected_flux_dal * W * L;

% -------------------------------------------------------------------------
% Plot the budget estimate
% -------------------------------------------------------------------------
dal_sample_clr = '#8c6bb1';
dal_pro_clr = '#41b6c4';

f = figure;clf
yline(0,'k','linewidth',2,'HandleVisibility','off')
hold on
plot(TT_5min.datetime_local,flux_total_dal,'--','color',dal_sample_clr,'DisplayName','Dal - Area-integrated provided flux')
plot(TT_5min.datetime_local,flux_total_dal_corrected,':','color',dal_sample_clr,'DisplayName','Dal - Area-integrated corrected flux')
plot(TT_5min.datetime_local(2:end),-dN_dt,'-','color',dal_pro_clr,'DisplayName','Pro-Oceanus Mini ATM - Negative molar CO_2 change in water (5-min avg)')
xlabel('Local Time')
ylabel('\DeltaN_{CO_2}/\Deltat (\mumol s^{-1})','FontSize',14)
legend('show','location','best')
grid on
xlim([pro_water.datetime_local(4) pro_water.datetime_local(end-4)])
set(f,"Position",[1 1 1151 587])

%--------------------------------------------------------------------------
% Option to save plot
%--------------------------------------------------------------------------
option = questdlg('Save plot?','Save plot','Yes','No','Yes');
switch option
    case 'Yes'
        folder = uigetdir('G:\My Drive\Dal and MIT\Lab Experiments\Figures\','Select a folder');
        cd(folder)
        txt = input("Enter the plot name: ","s");
        disp("Plot name: " + txt);
        imageName = [txt,'.png'];
        figName = [txt,'.fig'];
        exportgraphics(gcf, imageName, 'ContentType', 'image', 'BackgroundColor', 'white');
        savefig(figName)
        disp('Plot saved!')
    case 'No'
        disp('Plot not saved')
end

%% 
%--------------------------------------------------------------------------
% Calculate kw
%--------------------------------------------------------------------------
% From Eq. 21 in Eosense Theory doc
G = 3.01E-4; % (m/s); Eosense average calibration coefficient
Cs = Csample_corrected; % (umol m-3)
ka = G;
kc = G;
kw_thy1 = ka*(Cs - Ca) ./ (Cw - Cs - ka/kc*(Cs - Ca));

ka = 2.9745E-4; % (m/s); mean of Erin's values for Sample and Ref side membranes
kc = 5.276E-5;  % (m/s); Erin's value for Sample bottom membrane
kw_thy2 = ka*(Cs - Ca) ./ (Cw - Cs - ka/kc*(Cs - Ca));

% From Eosense corrected flux and Pro-Oceanus concentration data (re-arranged Eq. 22)
kw_flux = corrected_flux_dal ./ (Cw - Ca);

figure,clf
yline(0,'k','linewidth',2,'HandleVisibility','off')
hold on
plot(TT_5min.datetime_local,kw_thy1,'.','DisplayName','From theory (Eq. 21) - Eosense G')
plot(TT_5min.datetime_local,kw_thy2,'.','DisplayName','From theory (Eq. 21) - Erin k_a, k_c')
plot(C_TT.datetime_local(2:end),kw_flux,'.','DisplayName','From flux data (Eq. 22)')
ylabel('k_w (m/s)')
legend('show')
ylim([-0.005 0.005])
grid on;box on

% folder = uigetdir('G:\My Drive\Dal and MIT\Lab Experiments\Figures\','Select a folder');
% cd(folder)
% txt = input("Enter the plot name: ","s");
% disp("Plot name: " + txt);
% imageName = [txt,'.png'];
% figName = [txt,'.fig'];
% exportgraphics(gcf, imageName, 'ContentType', 'image', 'BackgroundColor', 'white');
% savefig(figName)

%%
% Calculate flux from Pro-Oceanus measurements
dt = seconds(C_TT.datetime_local(2) - C_TT.datetime_local(1));  % Assumes uniform spacing
dCdt = gradient(C_TT.Cw,dt); % (umol m-3); gradient function computes central differences for interior points
flux_pro = -H * dCdt; % (umol m-2 s-1)

figure,clf
yyaxis left
plot(C_TT.datetime_local,C_TT.Cw,'.')
ylabel('C_w (\mumol m^{-3})')

yyaxis right
yline(0,'linewidth',2)
hold on
plot(C_TT.datetime_local,flux_pro,'.-','DisplayName','Pro-Oceanus flux')
ylabel('Flux (\mumol m^{-2} s^{-1})')
