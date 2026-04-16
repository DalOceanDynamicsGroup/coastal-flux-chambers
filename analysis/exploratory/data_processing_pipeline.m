%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% data_processing_pipeline.m
% This script runs all the functions/scripts to read in raw sensor data and
% output merged datasets for further analysis.
%
% AUTHOR: Emily Chua
%
% DATE:
% First created: 3/26/26
% Last updated:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear; close all; clc

%==========================================================================
% Add in main paths
%==========================================================================
addpath(genpath('C:\Users\chuaem\Documents\MATLAB'))
addpath('G:\My Drive\Dal and MIT\MATLAB')

%==========================================================================
% Interactively select the experiment folder
%==========================================================================
start_path = 'G:\My Drive\Dal and MIT\Lab Experiments\Data\';
dialog_title = 'Select an experiment data folder';
selpath = uigetdir(start_path,dialog_title);
if selpath == 0
    error('No folder selected.');
end

[~,expName] = fileparts(selpath);

%==========================================================================
% Process raw data
%==========================================================================
% Internally logged Eosense data
eosDat = processEosense(selpath);
close

% Pro-Oceanus data
proDat = processProOceanus(selpath);
close

mergedDat = mergeSensorData(selpath);
close

%==========================================================================
% Plot raw data
%==========================================================================
run('plot_all_sensor_data.m')