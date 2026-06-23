% ms8607_matlab_debug.m
%
% MATLAB debug interface for AC701 / MicroBlaze / MS8607 UART output.
%
% Expected output:
%   Battery : GOOD
%   Heater  : OFF
%   25.94C | 996.63hPa | 41.94%RH | T[25.94, 25.94] | P[996.63, 996.63] | H[41.94, 43.07]
%
% Run:
%   ms8607_matlab_debug

clear;
clc;

%% User Settings
portName       = "COM5";
baudRate       = 115200;
serialTimeout  = 0.25;
displayWindow  = 300;
sendRunOnStart = true;
promptText     = "debug>";
runCommand     = "run";

%% Output Files
tag = datestr(now, 'yyyymmdd_HHMMSS');
csvFile = "ms8607_ac701_" + tag + ".csv";

fprintf("Opening %s at %d baud...\n", portName, baudRate);

%% Open Serial Port
s = serialport(portName, baudRate, "Timeout", serialTimeout);
configureTerminator(s, "CR/LF");
flush(s);

%% Wait for debug prompt and send run
if sendRunOnStart
    fprintf("Waiting for '%s' prompt...\n", promptText);

    rxBuffer = "";

    while ~contains(rxBuffer, promptText)
        if s.NumBytesAvailable > 0
            line = readline(s);
            fprintf("%s\n", line);
            rxBuffer = rxBuffer + line + newline;

            if strlength(rxBuffer) > 4096
                rxBuffer = extractAfter(rxBuffer, strlength(rxBuffer) - 4096);
            end
        else
            pause(0.05);
        end
    end

    fprintf("Sending command: %s\n", runCommand);
    writeline(s, runCommand);
end

%% Regex Patterns
dataPattern = ...
    "([-+]?\d+(?:\.\d+)?)\s*C\s*\|\s*" + ...
    "([-+]?\d+(?:\.\d+)?)\s*hPa\s*\|\s*" + ...
    "([-+]?\d+(?:\.\d+)?)\s*%RH\s*\|\s*" + ...
    "T\[\s*([-+]?\d+(?:\.\d+)?)\s*,\s*([-+]?\d+(?:\.\d+)?)\s*\]\s*\|\s*" + ...
    "P\[\s*([-+]?\d+(?:\.\d+)?)\s*,\s*([-+]?\d+(?:\.\d+)?)\s*\]\s*\|\s*" + ...
    "H\[\s*([-+]?\d+(?:\.\d+)?)\s*,\s*([-+]?\d+(?:\.\d+)?)\s*\]";

batteryPattern = "Battery\s*:\s*(.+)";
heaterPattern  = "Heater\s*:\s*(.+)";

%% CSV Setup
fid = fopen(csvFile, 'w');
fprintf(fid, "sample,timestamp,elapsed_s,temp_c,pressure_hpa,humidity_rh,temp_min_c,temp_max_c,pressure_min_hpa,pressure_max_hpa,humidity_min_rh,humidity_max_rh,battery_status,heater_status\n");

%% Plot Setup
figureHandle = figure('Name', 'AC701 MS8607 MATLAB Debug', ...
                      'NumberTitle', 'off', ...
                      'Color', 'w');

tiledlayout(3, 1);

axTemp = nexttile;
hTemp = animatedline('LineWidth', 1.5);
grid on;
ylabel('Temp [C]');
title('MS8607 Temperature');

axPress = nexttile;
hPress = animatedline('LineWidth', 1.5);
grid on;
ylabel('Pressure [hPa]');
title('MS8607 Pressure');

axHum = nexttile;
hHum = animatedline('LineWidth', 1.5);
grid on;
ylabel('Humidity [%RH]');
xlabel('Elapsed Time [s]');
title('MS8607 Humidity');

%% State Variables
sample = 0;
batteryStatus = "UNKNOWN";
heaterStatus  = "UNKNOWN";
startTime = tic;

timeBuf = nan(1, displayWindow);

fprintf("\nCapture running. Close the plot window or press Ctrl+C to stop.\n\n");

%% Main Capture Loop
try
    while isvalid(figureHandle)
        if s.NumBytesAvailable > 0
            raw = strtrim(readline(s));
            fprintf("%s\n", raw);

            bTok = regexp(raw, batteryPattern, 'tokens', 'once');
            if ~isempty(bTok)
                batteryStatus = string(strtrim(bTok{1}));
                continue;
            end

            hTok = regexp(raw, heaterPattern, 'tokens', 'once');
            if ~isempty(hTok)
                heaterStatus = string(strtrim(hTok{1}));
                continue;
            end

            tok = regexp(raw, dataPattern, 'tokens', 'once');

            if isempty(tok)
                continue;
            end

            tempC       = str2double(tok{1});
            pressureHpa = str2double(tok{2});
            humidityRh  = str2double(tok{3});

            tempMin     = str2double(tok{4});
            tempMax     = str2double(tok{5});
            pressureMin = str2double(tok{6});
            pressureMax = str2double(tok{7});
            humidityMin = str2double(tok{8});
            humidityMax = str2double(tok{9});

            sample = sample + 1;
            elapsed = toc(startTime);
            timestamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

            fprintf(fid, "%d,%s,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%s,%s\n", ...
                sample, timestamp, elapsed, ...
                tempC, pressureHpa, humidityRh, ...
                tempMin, tempMax, pressureMin, pressureMax, humidityMin, humidityMax, ...
                batteryStatus, heaterStatus);
            fflush(fid);

            addpoints(hTemp, elapsed, tempC);
            addpoints(hPress, elapsed, pressureHpa);
            addpoints(hHum, elapsed, humidityRh);

            timeBuf = [timeBuf(2:end), elapsed];

            xmin = min(timeBuf, [], 'omitnan');
            xmax = max(timeBuf, [], 'omitnan');

            if ~isnan(xmin) && ~isnan(xmax) && xmax > xmin
                xlim(axTemp,  [xmin xmax]);
                xlim(axPress, [xmin xmax]);
                xlim(axHum,   [xmin xmax]);
            end

            title(axTemp, sprintf("Temp %.2f C    Min %.2f / Max %.2f C", tempC, tempMin, tempMax));
            title(axPress, sprintf("Pressure %.2f hPa    Min %.2f / Max %.2f hPa", pressureHpa, pressureMin, pressureMax));
            title(axHum, sprintf("Humidity %.2f %%RH    Min %.2f / Max %.2f %%RH    Battery %s    Heater %s", ...
                humidityRh, humidityMin, humidityMax, batteryStatus, heaterStatus));

            drawnow limitrate;
        else
            pause(0.02);
        end
    end

catch ME
    fprintf("\nStopped: %s\n", ME.message);
end

%% Cleanup
fprintf("\nClosing serial port and CSV file...\n");

if fid > 0
    fclose(fid);
end

clear s;

fprintf("Saved CSV: %s\n", csvFile);
