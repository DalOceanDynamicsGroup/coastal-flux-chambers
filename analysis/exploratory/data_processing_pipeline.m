%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% data_processing_pipeline.m
% This script runs all the functions/scripts to process raw sensor data 
% from the fluxpi tank setup and outputs and plots merged datasets for 
% further analysis.
%
% AUTHOR: Emily Chua
%
% DATE:
% First created: 3/26/26
% Last updated: 7/10/26
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear; close all; clc

%==========================================================================
% Add in main paths
%==========================================================================
addpath(genpath('C:\Users\chuaem\Documents\MATLAB'))
addpath(genpath('G:\My Drive\Dal and MIT\coastal-flux-chambers'))

%==========================================================================
% Interactively select the experiment folder
%==========================================================================
dataRoot = 'G:\My Drive\Dal and MIT\Lab Experiments\Data\';
dialog_title = 'Select an experiment data folder';
selPath = uigetdir(dataRoot,dialog_title);
if selPath == 0
    error('No folder selected.');
end

[~,expName] = fileparts(selPath);

%==========================================================================
% Process and plot raw data
%==========================================================================
% Eosense data
eosDat = processEOSModbus(selPath,true);

% Pro-Oceanus data
poDat = processPO(selPath);

% % Thermistor data
% processTHERM(selpath);

% Process datasets
[eosDat,poPaired] = prepSensorData_fluxpi(selPath,eosDat,poDat);

% Prompt user for pulse start unless this is an offset test
if contains(lower(expName),'offset')
    pulseStart = [];
else
    expDate = extractBefore(expName,'_');
    answer = inputdlg('Enter pulse start time (HH:mm:ss):', 'Pulse Time', 1);
    pulseStart = datetime(expDate + " " + answer{1}, 'InputFormat', 'yyyy-MM-dd HH:mm:ss', 'TimeZone', 'America/Halifax');
end

% Plot datasets
plotFluxpiData(selPath,pulseStart);

% %==========================================================================
% % Compute fluxes and kw
% %==========================================================================
% run('flux_and_budget_analysis')