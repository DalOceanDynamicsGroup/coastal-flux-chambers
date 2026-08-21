function poDat = processPO(selPath)
% Wrapper for detecting the PO file format (depending on the DAQ code used)
% and dispatching the correct appropriate PO parser.

rawPath = fullfile(selPath,'raw');
poFiles = dir(fullfile(rawPath,'*.PO'));

if isempty(poFiles)
    error('No PO files found.');
end

firstFile = fullfile(poFiles(1).folder,poFiles(1).name);

lines = readlines(firstFile);
lines = lines(strlength(strtrim(lines)) > 0);

idx = find(startsWith(lines,"PO,"),1,'first');

if isempty(idx)
    error('No PO records found');
end

firstPOLine = lines(idx);

% Current format: PO,2026-08-17 09:53:50.781,W M,...
if startsWith(firstPOLine,"PO,20")
    poDat = processPO_current(selPath);
% Old format: W M,2026,...
else
    poDat = processPO_v06_AIb(selPath);
end

end