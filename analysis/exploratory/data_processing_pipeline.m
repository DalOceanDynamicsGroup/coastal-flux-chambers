%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% data_processing_pipeline.m
% This script runs all the functions/scripts to process raw sensor data 
% from the fluxTank DAQ and outputs and plots merged datasets for 
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
addpath(genpath('C:\Users\Emily\OneDrive - Dalhousie University\Documents\MATLAB'))
addpath(genpath('C:\Users\Emily\Documents\GitHub\coastal-flux-chambers'))

%==========================================================================
% Interactively select the experiment folder
%==========================================================================
projectRoot = 'C:\Users\Emily\OneDrive - Dalhousie University\Work\Dal and MIT\';
dialog_title = 'Select an experiment data folder';
selPath = uigetdir(projectRoot,dialog_title);
if selPath == 0
    error('No folder selected.');
end

[~,expName] = fileparts(selPath);

% Prevent offset experiments from using the normal pipeline
if contains(lower(expName),'offset')
    error(['Offset test experiments should be processed with ',...
        'determine_offsets.m, not data_processing_pipeline.m.'])
end

%==========================================================================
% Process raw data
%==========================================================================
% Eosense data
% Apply previously determined EOS offsets (generated using determine_offsets.m)
eosDat = processEOSModbus(selPath,true);

% Pro-Oceanus data
poDat = processPO(selPath);

% Thermistor data
thermDat = processTHERM(selPath);

%==========================================================================
% Prepare datasets for analysis
%==========================================================================
isField = contains(selPath,'Field Deployments');

if isField
    pulseStart = [];
else
    % Prompt user for pulse start
    expDate = extractBefore(expName,'_');
    answer = inputdlg('Enter pulse start time (HH:mm:ss):', 'Pulse Time', 1);
    pulseStart = datetime(expDate + " " + answer{1}, 'InputFormat', 'yyyy-MM-dd HH:mm:ss', 'TimeZone', 'America/Halifax');
end

[eosDat, poPaired, thermDat, pulseStart] = prepFluxpiData(selPath, eosDat, poDat, thermDat, pulseStart);

%==========================================================================
% Plot datasets
%==========================================================================
plotFluxpiData(selPath,pulseStart);

% %==========================================================================
% % Compute fluxes and kw
% %==========================================================================
% run('fluxTank_analysis')