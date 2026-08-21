function thermDat = processTHERM(selPath)
% Wrapper for detecting the THERM file format (depending on the DAQ code used)
% and dispatching the correct appropriate THERM parser.

rawPath = fullfile(selPath,'raw');
thermFiles = dir(fullfile(rawPath,'*.THERM'));

if isempty(thermFiles)
    error('No THERM files found.');
end

firstFile = fullfile(thermFiles(1).folder,thermFiles(1).name);

firstLine = readlines(firstFile);
firstLine = firstLine(find(strlength(firstLine)>0,1));

% Current format: THERM,2026-08-17 09:53:50.781, water, 15.63, air, 20.36...
if contains(firstLine,'THERM,20')
    thermDat = processTHERM_current(selPath);

% TemperatureAir = 15.63, TemperatureH2O = 20.36,...
else
    thermDat = processTHERM_v06_AIb(selPath);
end

end