%% Load all of the instruments
inst_config = load('C:\Users\avdif\Documents\MATLAB\matlab_pulsing\pulsed_Rbalance\MSO44_trials\MSO44_trial_inst_config.mat');
DTG, pulseshaper, watd = pulsed_Rbalance_configure_instruments(inst_config);

%% Set up the DTG parameters
RELRATE = 'SIXTeenth';
WIDTH = '1E-4';

fprintf(DTG, 'TBAS:RUN OFF');                                               % turn off the pulse generation

fprintf(DTG, 'TBAS:FREQ 1e5');                                              % set the internal clock frequency

fprintf(DTG, ['PGENA1:CH2:PRATe ', RELRATE]);                               % configure the input to the pulse shaper (X CLK, AC1)
fprintf(DTG, 'PGENA1:CH2:LOW 0');
fprintf(DTG, 'PGENA1:CH2:HIGH 2.7');                                        % 2.7 V is the max output of the dtg, the pshaper box wants this high
fprintf(DTG, ['PGENA1:CH2:WIDTh ', WIDTH]);
fprintf(DTG, 'PGENA1:CH2:POLarity NORM');

fprintf(DTG, ['PGENA1:CH1:PRATe ', RELRATE]);                               % configure the input to the pulse shaper (Y CLK, AC1!)
fprintf(DTG, 'PGENA1:CH1:LOW 0');
fprintf(DTG, 'PGENA1:CH1:HIGH 2.7');                                        % 2.7 V is the max output of the dtg, the pshaper box wants this high
fprintf(DTG, ['PGENA1:CH1:WIDTh ', WIDTH]);
fprintf(DTG, 'PGENA1:CH1:POLarity INV');                                    % AC1! must have the opposite polarity of AC1

fprintf(DTG, ['PGENB1:CH1:PRATe ', RELRATE]);                               % configure the trigger for the scope
fprintf(DTG, 'PGENB1:CH1:LOW 0');
fprintf(DTG, 'PGENB1:CH1:HIGH 1.0');                                        % This can be any sufficiently high logical level, just adjust scope
fprintf(DTG, ['PGENB1:CH1:WIDTh ', WIDTH]);

% configure AC2 and AC2!, which still need to be on
fprintf(DTG, 'PGENB1:CH2:PRATe OFF');
fprintf(DTG, ['PGENC1:CH1:PRATe ', RELRATE]);
fprintf(DTG, 'PGENC1:CH1:HIGH 2.7');
fprintf(DTG, 'PGENC1:CH1:POLarity INV'); 
fprintf(DTG, ['PGENC1:CH2:PRATe ', RELRATE]);
fprintf(DTG, 'PGENC1:CH2:HIGH 2.7');
fprintf(DTG, 'PGENC1:CH2:POLarity NORM'); 

fprintf(DTG, 'TBAS:RUN ON');                                                % turn on pulse generation

%% THE USER MUST MAKE NECESSARY ADJUSTMENTS TO THE DELAY FOR EACH CLOCK SO THAT THE PULSES ARRIVE AT THE GATE SIMULTANEOUSLY
% NOTE: XSG2, and YSG2 must be grounded. AC2 and AC2! must be active.
% NOTE: X! and Y! should be capped with shorting caps.
% NOTE: Above 1 MHz, it seems like the shaper struggles to keep up, and
%       pulses are no longer independent.
% NOTE: The outputs, X and Y, must be run through 3 dB to 30 dB attenuators
%       in order for the polarity of Y to actually be opposite X.
% NOTE: All inputs, XSG1, YSG1, XSG2, YSG2, take non-negative biases.

% Internally, Vx and Vy will always be used to refer to the absolute value 
% of the pulse, regardless of polarity. For negative Vx, we simply change 
% the polarity of both channels (they are always opposite each other).

%% Here are my current delay settings
% 1-A1: 0.0000400 us
% 1-A2: 0.0042500 us
% 1-C1: 0.0151540 us
% 1-C2: 0.0024100 us

%% Create the balancing script config
logfilepath = 'C:\Users\avdif\Documents\MATLAB\matlab_pulsing\pulsed_Rbalance\MSO44_trials\logs\bal_log.txt';
logfile = fopen(logfilepath, 'a+');                                         % open the log file for balancing

bal_config.watd = watd;
bal_config.puls = pulseshaper;
bal_config.logfile = logfile;
bal_config.errt = 0.005;        % 0.01 V
bal_config.thresh = 0.005;      % 0.01 V
bal_config.max_try = 10;
bal_config.min_Vy =  0;         %  0.00 V
bal_config.max_Vy =  0.43;      %  0.43 V

%% Sweep excitation amplitude and balance at each point
sweep_log_path = 'C:\Users\avdif\Documents\MATLAB\matlab_pulsing\pulsed_Rbalance\MSO44_trials\logs\sweep_log.txt';
sweep_log = fopen(sweep_log_path, 'a+');

for Vx=0.1:0.01:0.2
    fprintf('Changing Excitation to %d V -------------------------\n', Vx);
    result.Vx = Vx; result.Vy; result.R; result.t; result.V;                % set up the result struct that will be logged later
    pulseshaper.sweep("Vx1", Vx);                                           % sweep to the right excitation amplitude
    good_balance = pulsed_Rbalance_balance(bal_config);                     % perform the balancing procedure
    fprintf('Good Balance Point Found: %d', good_balance);
    Vy = pulseshaper.get("Vy1");                                            % get the actual balance pulse height located
    result.Vy = Vy;
    result.R = Vx/Vy;                                                       % calculate the associated resistance
    fprintf('Settled on balance with Vy = %d, R = %d\n', Vy, result.R);
    t, V = watd.watd();                                                     % perform waveform averaging at the balance point
    result.t = t;
    result.V = V;
    disp('Plotting Result...')
    plot(t, V);                                                             % plot the averaged trace
    
    encoded_result = erase(jsonencode(result), newline);                    % write everything to the log file encoded in json format as one line
    fprintf(sweep_log, '%s\n', encoded_result); 
end