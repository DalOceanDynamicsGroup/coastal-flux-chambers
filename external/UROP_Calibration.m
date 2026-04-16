%% Extract data and plot for visual inspection
%cd('/Users/erinhovendon/Documents/MATLAB')  % directory
data = readtable('fluxChamber_sensorData_2025-11-03_standardsealed.csv','VariableNamingRule','preserve');
data(1,:) = []; % remove units row
% disp(data.Properties.VariableNames);

runtime_sec = data.RUNTIME;
runtime_hrs = runtime_sec / 3600;
sample_pco2 = data.("SAMPLE pCO2");
ref_pco2 = data.("REF pCO2");
Turner = data.("pCO2");

figure;
plot(runtime_hrs, sample_pco2, '.', 'DisplayName', 'Sample node reading','LineWidth',1);
xlabel('Time (hrs)');
ylabel('CO2 Concentration (ppm)');
title('Sample node raw data');
improvePlot;
%% Crop dataset, fit curve, extract calibration constant
clc;

% crop dataset to time response curve, value from visual inspection
startup_sample = find(runtime_sec == 9220.74, 1, 'first'); 
startup_ref = find(runtime_sec == 9220.74, 1, 'first'); % index to inspection value
[~, stop_sample] = max(sample_pco2);
[~, stop_ref] = max(ref_pco2);

% leakage slope
[~, max_index] = max(ref_pco2);
leak_ref = ref_pco2(max_index:end, :);
leak_runtime_hrs = runtime_hrs(max_index:end, :);
leak_runtime_sec = runtime_sec(max_index:end, :);
p_hrs = polyfit(leak_runtime_hrs, leak_ref, 1);
p_sec = polyfit(leak_runtime_sec, leak_ref, 1);
leak_slope_hrs = p_hrs(1);
leak_slope_sec = p_sec(1);
disp(['Leakage slope (ppm per hour): ', num2str(leak_slope_hrs)]);

% atmospheric value, adjusted for leakage
Ca_max_sample = max(sample_pco2); % atmospheric value, will subtract leakage
Ca_max_ref = max(ref_pco2);
time_response_sample = runtime_sec(stop_sample) - runtime_sec(startup_sample);
time_response_ref = runtime_sec(stop_ref) - runtime_sec(startup_ref);
Ca_set_sample = Ca_max_sample - leak_slope_sec*time_response_sample;
Ca_set_ref = Ca_max_ref - leak_slope_sec*time_response_ref;

% cropped datasets
runtime_fit_sample = runtime_sec(startup_sample:stop_sample);
runtime_fit_ref = runtime_sec(startup_ref:stop_ref);
Cm_sample_fit = sample_pco2(startup_sample:stop_sample);
Cm_ref_fit = ref_pco2(startup_ref:stop_ref);

% slightly less cropped datasets (show before input and after max)
runtime_fit2_sample = runtime_sec(startup_sample-200:stop_sample+300);
runtime_fit2_ref = runtime_sec(startup_ref-200:stop_ref+300);
Cm_sample2_fit = sample_pco2(startup_sample-200:stop_sample+300);
Cm_ref2_fit = ref_pco2(startup_ref-200:stop_ref+300);

% initial concentration at the start of the fit (Cm0)
Cm0s = Cm_sample_fit(1);
Cm0r = Cm_ref_fit(1);

% model: Cm(t) = Ca + (Cm0 - Ca) * exp(-K * (t - t0))
model_sample = @(K, t) Ca_set_sample + (Cm0s - Ca_set_sample) * exp(-K * (t - runtime_fit_sample(1)));
model_ref = @(K, t) Ca_set_ref + (Cm0r - Ca_set_ref) * exp(-K * (t - runtime_fit_ref(1)));

% nonlinear least squares, estimate K
K_guess = 0.1;  % initial guess for K
options = optimset('Display', 'off');
K_estimate_sample = lsqcurvefit(@(K, t) model_sample(K, t), K_guess, runtime_fit_sample, Cm_sample_fit, [], [], options);
K_estimate_ref = lsqcurvefit(@(K, t) model_ref(K, t), K_guess, runtime_fit_ref, Cm_ref_fit, [], [], options);

% display calibration value and C_atm
disp(['Estimated K, sample node: ', num2str(K_estimate_sample)]);
disp(['Estimated K, reference node: ', num2str(K_estimate_ref)]);
disp(['Unadjusted atmospheric concentration, sample:', num2str(Ca_max_sample)]);
disp(['Atmospheric concentration, sample:', num2str(Ca_set_sample)]);
disp(['Unadjusted atmospheric concentration, ref:', num2str(Ca_max_ref)]);
disp(['Atmospheric concentration, ref:', num2str(Ca_set_ref)]);
% logic check

%% Plot full dataset and cropped fit view

% plot data
figure;
plot(runtime_fit2_sample./3600, Cm_sample2_fit, '.', 'DisplayName', 'Sample node reading','LineWidth',1); 
hold on;
plot(runtime_fit_sample./3600, model_sample(K_estimate_sample, runtime_fit_sample), '-','LineWidth',2, 'DisplayName', 'Time response curve');
xlabel('Time (hrs)');
ylabel('CO2 Concentration (ppm)');
title('CO2 Response: Sample Node Bottom Membrane, cropped');
improvePlot;

%figure;
%plot(runtime_sec, sample_pco2, '.', 'DisplayName', 'Sample node reading','LineWidth',1); 
%hold on;
%plot(runtime_fit_sample./3600, model_sample(K_estimate_sample, runtime_fit_sample), '-','LineWidth',2, 'DisplayName', 'Time response curve');
%legend;
%xlabel('Time (hrs)');
%ylabel('CO2 Concentration (ppm)');
%title('CO2 Response Through Bottom Membrane');
%improvePlot;

figure;
plot(runtime_fit2_ref./3600, Cm_ref2_fit, '.', 'DisplayName', 'Sample node reading','LineWidth',1); 
hold on;
plot(runtime_fit_ref./3600, model_ref(K_estimate_ref, runtime_fit_ref), '-','LineWidth',2, 'DisplayName', 'Time response curve');
xlabel('Time (hrs)');
ylabel('CO2 Concentration (ppm)');
title('CO2 Response: Ref Side Membrane, cropped');
improvePlot;

%% just for taped reference trial, comparison plot
% Plot sample node and reference node concentrations on the sample fit timescale
figure;
plot(runtime_fit_sample./3600, Cm_sample_fit, '.', 'DisplayName', 'Sample node reading', 'LineWidth', 1); 
hold on;

% Interpolate reference node data onto the sample fit time range
Cm_ref_interp = interp1(runtime_fit_ref, Cm_ref_fit, runtime_fit_sample, 'linear', 'extrap');

% Plot interpolated reference node data
plot(runtime_fit_sample./3600, Cm_ref_interp, '.', 'DisplayName', 'Reference node reading', 'LineWidth', 1);

xlabel('Time (hrs)');
ylabel('CO2 Concentration (ppm)');
title('CO2 Concentration: Sample vs Reference Nodes (Cropped)');
legend('Sample node', 'Reference node');
improvePlot;

