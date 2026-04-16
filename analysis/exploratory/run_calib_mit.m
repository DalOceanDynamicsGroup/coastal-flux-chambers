clear;close all;clc

% Load MIT data file
cd('G:\My Drive\Dal and MIT\Lab Experiments\Data\MIT')
[filename,pathname] = uigetfile('*.csv','Select a CSV file');

dat = readtable(filename);

% Remove rows where TIME = NaT
dat(isnat(dat.TIME),:) = [];

figure(1),clf
plot(dat.RUNTIME,dat.REFPCO2,'.','DisplayName','Reference Node')
hold on
plot(dat.RUNTIME,dat.SAMPLEPCO2,'.','DisplayName','Sample Node')
plot(dat.RUNTIME,dat.OceanusPCO2,'.','DisplayName','Pro-Oceanus')
xlim([min(dat.RUNTIME),max(dat.RUNTIME)])
xlabel('Run time (s)')
ylabel('pCO2 (ppm)')
legend('show','location','best')
%%
start = 127;
% start = 135; % Use only data starting at this index
stop = start + 360;   % 240 indices = 8 minutes for side membrane
% stop = start + 430;     % 430 indices = 14.4 minutes for bottom membrane
t = dat.RUNTIME(start:stop);
tfit = t - t(1);
% y_actual = dat.SAMPLEPCO2(start:stop);
y_actual = dat.REFPCO2(start:stop);

% 1. Define the exponential model
expMdl = fittype('a.*exp(-b.*t) + c','independent','t','dependent','y');

% 2. Fit the data
fitresult = fit(tfit,y_actual,expMdl,'startpoint',[0,.01,500],'lower',[-500,0,0],'upper',[0,.1,1000]);
fiteval = fitresult.a.*exp(-fitresult.b.*tfit) + fitresult.c;

% Trouble-shooting: Try best-guess coefficients
% a = -500;
% b = 0.014;
% c = 970;
% fiteval = a*exp(-b*t) + c;

% 3. View results
disp(fitresult)

% Solve for k
Sc = 804/10^6; % (m^2)
V = 16.7/10^6; % (m^3)
kc = fitresult.b*V/Sc;

figure(1),clf
plot(dat.RUNTIME,dat.REFPCO2,'.','DisplayName','Reference Node')
hold on
plot(dat.RUNTIME,dat.SAMPLEPCO2,'.','DisplayName','Sample Node')
plot(dat.RUNTIME,dat.OceanusPCO2,'.','DisplayName','Pro-Oceanus')
plot(t,fiteval,'-','LineWidth',2,'DisplayName',['Fitted (k = ',num2str(kc,4),' ms^{-1})'])
plot(dat.RUNTIME,dat.pCO2,'.','DisplayName','Turner')
xlim([min(dat.RUNTIME),max(dat.RUNTIME)])
xlabel('Run time (s)')
ylabel('pCO2 (ppm)')
legend('show','location','best')
% title('Reference Node - Side Membrane Calibration')
% title('Sample Node - Side Membrane Calibration')
title('Sample Node - Bottom Membrane Calibration')

cd('G:\My Drive\Dal and MIT\Lab Experiments\Figures\MIT')

%% Calculate standard deviation
k1 = 4.299E-4;
k2 = 3.846E-4;
k3 = 3.3738E-4;
k4 = 3.158E-4;
k5 = 3.424E-4;
k6 = 3.457E-4;
avg = mean([k1 k2 k3 k4 k5 k6])
sd = std([k1 k2 k3 k4 k5 k6])

%% Conversions
% From gamma (s-1) --> k (m s-1)
gamma = 0.0022;
k_m_s = gamma*(16.7/10^6)/(804/10^6)

% From gamma (s-1) --> k (cm h-1)
k_cm_h = gamma*(16.7/10^6)/(804/10^6)*100*3600