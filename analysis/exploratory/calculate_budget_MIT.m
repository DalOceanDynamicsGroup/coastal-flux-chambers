% Make sure to change "INPUT"

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

% -------------------------------------------------------------------------
% Calculate eosFD flux
% -------------------------------------------------------------------------
G = 3.01E-4;        % (m s-1); input, from Eosense calibration note

% ---Using concentrations from MIT eosFDs----------------------------------
% 1. Convert Eosense xCO2 (ppm) --> pCO2 (uatm)
pCO2ref = TT_5min.mit_ref_ppm .* TT_5min.miniATM_air_Pmbar / 1013.25;  % (uatm)
pCO2sample = TT_5min.mit_sample_ppm .* TT_5min.miniATM_air_Pmbar / 1013.25; % (uatm)
pCO2sample_corrected = TT_5min.mit_samplecorr_ppm .* TT_5min.miniATM_air_Pmbar / 1013.25; % (uatm)

% 2. Convert pCO2 (uatm) --> dissolved CO2 concentration (umol m-3) using Weiss, 1974
% Reference Node
Tref = TT_5min.mit_ref_T + 273.15; % (K)
K0 = exp(-60.2409 + 93.4517*(100./Tref) + 23.3585*log(Tref./100));  % (mol L-1 atm-1); S = 0
Cref = K0 .* pCO2ref * 10^3; % (umol m-3)
% Sample Node
Tsample = TT_5min.mit_sample_T + 273.15; % (K)
K0 = exp(-60.2409 + 93.4517*(100./Tsample) + 23.3585*log(Tsample./100));  % (mol L-1 atm-1); S = 0
Csample = K0 .* pCO2sample * 10^3; % (umol m-3)
Csample_corrected = K0 .* pCO2sample_corrected * 10^3; % (umol m-3)

% 3. Compute the flux
calculated_flux_mit = G * (Csample - Cref);             % (umol m-2 s-1)
corrected_flux_mit = G * (Csample_corrected - Cref);    % (umol m-2 s-1)

% ---Using concentrations from Dal eosFDs----------------------------------
% 1. Convert Eosense xCO2 (ppm) --> pCO2 (uatm)
pCO2ref = TT_5min.dal_ref_ppm .* TT_5min.miniATM_air_Pmbar / 1013.25;  % (uatm)
pCO2sample = TT_5min.dal_sample_ppm .* TT_5min.miniATM_air_Pmbar / 1013.25; % (uatm)
pCO2sample_corrected = TT_5min.dal_samplecorr_ppm .* TT_5min.miniATM_air_Pmbar / 1013.25; % (uatm)

% 2. Convert pCO2 (uatm) --> dissolved CO2 concentration (umol m-3) using Weiss, 1974
% Reference Node
Tref = TT_5min.dal_ref_T + 273.15; % (K)
K0 = exp(-60.2409 + 93.4517*(100./Tref) + 23.3585*log(Tref./100));  % (mol L-1 atm-1); S = 0
Cref = K0 .* pCO2ref * 10^3; % (umol m-3)
% Sample Node
Tsample = TT_5min.dal_sample_T + 273.15; % (K)
K0 = exp(-60.2409 + 93.4517*(100./Tsample) + 23.3585*log(Tsample./100));  % (mol L-1 atm-1); S = 0
Csample = K0 .* pCO2sample * 10^3; % (umol m-3)
Csample_corrected = K0 .* pCO2sample_corrected * 10^3; % (umol m-3)

% 3. Compute the flux
calculated_flux_dal = G * (Csample - Cref);             % (umol m-2 s-1)
corrected_flux_dal = G * (Csample_corrected - Cref);    % (umol m-2 s-1)

% Plot the flux data
% Define colors
mit_ref_clr = '#00441b';
mit_sample_clr = '#41ae76';
mit_pro_clr = '#253494';
turner_clr = '#ec7014';
dal_ref_clr = '#8A2BE2';
dal_sample_clr = '#FF00FF';
dal_flux_clr = '#8B008B';
miniATM_air_clr = '#41b6c4';
miniATM_water_clr = '#0000CD';

% -------------------------------------------------------------------------
% Budget calculations
% -------------------------------------------------------------------------
% 1. Convert Pro-Oceanus water and air concentrations (ppm) --> pCO2 (uatm)
pCO2w = TT_5min.miniATM_water_ppm .* TT_5min.miniATM_water_Pmbar / 1013.25;  % (uatm)
pCO2a = TT_5min.miniATM_air_ppm .* TT_5min.miniATM_water_Pmbar / 1013.25;      % (uatm)

% 2. Convert pCO2,w (uatm) --> dissolved CO2 concentration (umol m-3) using Weiss, 1974
% Water side
T_w = TT_5min.water_T + 273.15; % (K)
K0 = exp(-60.2409 + 93.4517*(100./T_w) + 23.3585*log(T_w./100));  % (mol L-1 atm-1); S = 0
Cw = K0 .* pCO2w * 10^3;    % (umol m-3)
% Air side
T_a = TT_5min.air_T + 273.15;  % (K)
K0 = exp(-60.2409 + 93.4517*(100./T_a) + 23.3585*log(T_a./100));  % (mol L-1 atm-1); S = 0
Ca = K0 .* pCO2a * 10^3;    % (umol m-3)

C_TT = table(TT_5min.TIME,Cw,Ca,'VariableNames',{'datetime_local','Cw','Ca'});
C_TT = table2timetable(C_TT);

% 3. Convert dissolved CO2 --> Total moles in bucket
H = 0.115;  % INPUT: Height of water (m) 
L = 0.5;    % Length of container (m)
W  = 0.5;   % Width of container (m)
V = H*W*L;  % Volume of water (m3)
N = C_TT.Cw .* V;  % (umol)
N_TT = table(TT_5min.TIME,N,'VariableNames',{'datetime_local','NCO2'});
% N_smooth = smooth(N_TT.NCO2,5); % (umol)

% 4. Compute the Pro-Oceanus rate of CO2 change across the measurement period
dN_dt = diff(N) ./ seconds(diff(N_TT.datetime_local));
% dN_dt = diff(N_smooth) ./ seconds(diff(N_TT.datetime_local)); % (umol s-1)

% 5. Compute F_eos x A
flux_total_dal = TT_5min.dal_eos_flux * W * L; % (umol s-1)
flux_total_mit = TT_5min.mit_eos_flux * W * L; % (umol s-1)
flux_total_dal_calculated = calculated_flux_dal * W * L;
flux_total_dal_corrected = corrected_flux_dal * W * L;
flux_total_mit_calculated = calculated_flux_mit * W * L;
flux_total_mit_corrected = corrected_flux_mit * W * L;

% -------------------------------------------------------------------------
% Plot the budget estimate
% -------------------------------------------------------------------------
cd('G:\My Drive\Dal and MIT\Lab Experiments\Figures\MIT')

fig1 = figure;clf
plot(TT_5min.TIME(1:end-1),-dN_dt,':','color',miniATM_water_clr,'DisplayName','Pro-Oceanus Mini ATM - Negative molar CO_2 change in water')
hold on
% plot(TT_5min.TIME,flux_total_dal,'-.','color',dal_sample_clr,'DisplayName','Dal Eosense - Area-integrated provided flux')
plot(TT_5min.TIME,flux_total_dal_corrected,'-.','color',dal_flux_clr,'DisplayName','Dal Eosense - Area-integrated corrected flux')
% plot(TT_5min.TIME,flux_total_mit,'-.','color',mit_sample_clr,'DisplayName','MIT Eosense - Area-integrated provided flux (5-min avg)')
plot(TT_5min.TIME,flux_total_mit_corrected,'-.','color',mit_sample_clr,'DisplayName','MIT Eosense - Area-integrated corrected flux (5-min avg)')
yline(0,'k','linewidth',2,'HandleVisibility','off')
xlabel('Local Time')
ylabel('\DeltaN_{CO_2}/\Deltat (\mumol s^{-1})','FontSize',14)
legend('show','location','southeast')
grid on
% title('CO_2 Budget Comparison','FontSize',14)
xlim([TT_5min.TIME(3) TT_5min.TIME(end)]) % start ind = 3 for large pulse; 15 for small and large/turbulent pulses
set(fig1,"Position",[250 200 1151 587])
% ylim([-0.3 0.05])
% ylim([-0.15 0.05])
% xlim([TT_5min.TIME(17) TT_5min.TIME(end)])
%%
%--Option to save plot-----------------------------------------------------
option = questdlg('Save plot?','Save plot','Yes','No','Yes');
switch option
    case 'Yes'
        folder = uigetdir('G:\My Drive\Dal and MIT\Lab Experiments\Figures\','Select a folder');
        txt = input("Enter the plot name: ","s");
        disp("Plot name: " + txt);
        imageName = [txt,'.png'];
        figName = [txt,'.fig'];
        exportgraphics(fig1, imageName, 'ContentType', 'image', 'BackgroundColor', 'white');
        savefig(figName)
        disp('Plot saved!')
    case 'No'
        disp('Plot not saved')
end

%%
% -------------------------------------------------------------------------
% Budget estimate: Total molar change
% -------------------------------------------------------------------------
% Dal Eosense
% 1. Convert timetable to usable vectors for integration
timeVec = seconds(TT_5min.TIME - TT_5min.TIME(1));
dataVec = flux_total_dal_corrected;
% 2. Calculate cumulative N added
cumulative_eos_dal = cumtrapz(timeVec,dataVec);
% 3. Calculate total N added
total_eos_dal = trapz(timeVec,dataVec);
% 4. Add result to a new timetable
eos_dal = timetable(TT_5min.TIME,cumulative_eos_dal,'VariableNames',{'cumulative_N'});

% MIT Eosense
% 1. Convert timetable to usable vectors for integration
dataVec = flux_total_mit_corrected;
% 2. Calculate cumulative N added
cumulative_eos_mit = cumtrapz(timeVec,dataVec);
% 3. Calculate total N added
total_eos_mit = trapz(timeVec,dataVec);
% 4. Add result to a new timetable
eos_mit = timetable(TT_5min.TIME,cumulative_eos_mit,'VariableNames',{'cumulative_N'});

% Pro-Oceanus
% 1. Convert timetable to usable vectors for integration
timeVec = seconds(TT_5min.TIME(1:end-1) - TT_5min.TIME(1));
dataVec = -dN_dt;
% 2. Calculate cumulative N added
cumulative_pro = cumtrapz(timeVec,dataVec);
% 3. Calculate total N added
total_pro = trapz(timeVec,dataVec);
% 4. Add result to a new timetable
pro = timetable(TT_5min.TIME(1:end-1),cumulative_pro,'VariableNames',{'cumulative_N'});

fig2 = figure(2);clf
plot(eos_dal.Time,eos_dal.cumulative_N,':','color',dal_sample_clr,'DisplayName',['Dal integrated total flux (corrected data); N_{total} = ',num2str(total_eos_dal,3),' \mumol'])
hold on
plot(eos_mit.Time,eos_mit.cumulative_N,':','color',mit_sample_clr,'DisplayName',['MIT integrated total flux (corrected data); N_{total} = ',num2str(total_eos_mit,3),' \mumol'])
% plot(N_TT.datetime_local,-N_TT.NCO2,'color',dal_pro_clr,'DisplayName','Pro-Oceanus Mini ATM - Negative molar CO_2 addition to water')
% plot(N_TT.datetime_local,-N_TT.NCO2 + 738,'color',dal_pro_clr,'DisplayName','Pro-Oceanus Mini ATM - Negative molar CO_2 addition to water')
plot(pro.Time,pro.cumulative_N,'color',miniATM_water_clr,'DisplayName',['Pro-Oceanus Mini ATM negative molar change in water; N_{total} = ',num2str(total_pro,3),' \mumol'])
xlabel('Local Time')
ylabel('Cumulative N_{CO_2} (\mumol)')
l=legend('show','location','best');
grid on
xlim([TT_5min.TIME(1) TT_5min.TIME(end)])
set(fig2,"Position",[250 200 1151 587])

%--Option to save plot-----------------------------------------------------
option = questdlg('Save plot?','Save plot','Yes','No','Yes');
switch option
    case 'Yes'
        folder = uigetdir('G:\My Drive\Dal and MIT\Lab Experiments\Figures\','Select a folder');
        txt = input("Enter the plot name: ","s");
        disp("Plot name: " + txt);
        imageName = [txt,'.png'];
        figName = [txt,'.fig'];
        exportgraphics(fig2, imageName, 'ContentType', 'image', 'BackgroundColor', 'white');
        savefig(figName)
        disp('Plot saved!')
    case 'No'
        disp('Plot not saved')
end
