%% Load all of the instruments
inst_config = load('C:\Users\avdif\Documents\MATLAB\matlab_pulsing\pulsed_Rbalance\MSO44_trial_inst_config.mat');
DTG, pulseshaper, watd = pulsed_Rbalance_configure_instruments(inst_config);

%% Set up the DTG parameters

fprintf(DTG, 'TBAS:RUN OFF');                                               % turn off the pulse generation

fprintf(DTG, 'TBAS:FREQ 1e5');                                              % set the internal clock frequency

fprintf(DTG, 'PGENA1:CH1:PRATe SIXTeenth');                                 % configure the input to the pulse shaper (X CLK)
fprintf(DTG, 'PGENA1:CH1:LOW 0');
fprintf(DTG, 'PGENA1:CH1:HIGH 2.7');
fprintf(DTG, 'PGENA1:CH1:WIDTh 1e-4');
fprintf(DTG, 'PGENA1:CH2:POLarity NORM');

fprintf(DTG, 'PGENA1:CH2:PRATe SIXTeenth');                                 % configure the input to the pulse shaper (Y CLK)
fprintf(DTG, 'PGENA1:CH2:LOW 0');
fprintf(DTG, 'PGENA1:CH2:HIGH 2.7');
fprintf(DTG, 'PGENA1:CH2:WIDTh 1e-4');
fprintf(DTG, 'PGENA1:CH2:POLarity INV');

fprintf(DTG, 'PGENB1:CH1:PRATe SIXTeenth');                                 % configure the trigger for the scope
fprintf(DTG, 'PGENB1:CH1:LOW 0');
fprintf(DTG, 'PGENB1:CH1:HIGH 1.0');
fprintf(DTG, 'PGENB1:CH1:WIDTh 1e-4');

fprintf(DTG, 'TBAS:RUN ON');                                                % turn on pulse generation

%% THE USER MUST MAKE NECESSARY ADJUSTMENTS TO THE DELAY FOR EACH CLOCK SO THAT THE PULSES ARRIVE AT THE GATE SIMULTANEOUSLY

%% Create the balancing script config
logfilepath = 'C:\Users\avdif\Documents\MATLAB\matlab_pulsing\pulsed_Rbalance\bal_log.txt';
logfile = fopen(logfilepath, 'a+');                                         % open the log file for balancing

bal_config.watd = watd;
bal_config.puls = pulseshaper;
bal_config.logfile = logfile;
bal_config.errt = 0.01;     % 0.01 V
bal_config.thresh = 0.01;   % 0.01 V
bal_config.max_try = 10;
bal_config.min_Vy = -10;    % -0.1 V
bal_config.max_Vy =  10;    %  0.1 V

%% Sweep excitation amplitude and balance at each point
sweep_log_path = 'C:\Users\avdif\Documents\MATLAB\matlab_pulsing\pulsed_Rbalance\sweep_log.txt';
sweep_log = fopen(sweep_log_path, 'a+');

for Vx=0.1:0.1:5
    fprintf('Changing Excitation to %d ---------------------------\n', Vx);
    result.Vx = Vx; result.Vy; result.R; result.t; result.V;                % set up the result struct that will be logged later
    pulseshaper.sweep("Vx1", Vx);                                           % sweep to the right excitation amplitude
    good_balance = pulsed_Rbalance_balance(bal_config);                     % perform the balancing procedure
    fprintf('Good Balance Point Found: %d', good_balance);
    Vy = pulseshaper.get("Vy1");                                            % get the actual balance pulse height located
    result.Vy = Vy;
    result.R = -Vx/Vy;                                                      % calculate the associated resistance
    fprintf('Settled on balance with Vy = %d, R = %d\n', Vy, result.R);
    t, V = watd.watd();                                                     % perform waveform averaging at the balance point
    result.t = t;
    result.V = V;
    disp('Plotting Result...')
    plot(t, V);                                                             % plot the averaged trace
    
    encoded_result = erase(jsonencode(result), newline);                    % write everything to the log file encoded in json format as one line
    fprintf(sweep_log, '%s\n', encoded_result); 
end