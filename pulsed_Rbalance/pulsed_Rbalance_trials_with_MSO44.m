%% Load all of the instruments
inst_config = load('C:\Users\avdif\Documents\MATLAB\matlab_pulsing\pulsed_Rbalance\MSO44_trial_inst_config.mat');
DTG, pulseshaper, watd = pulsed_Rbalance_configure_instruments(inst_config);

%% Set up the DTG parameters

fprintf(DTG, 'TBAS:RUN OFF');
fprintf(DTG, 'TBAS:FREQ 1E7');
fprintf(DTG, 'PGENA1:CH1:PRATe EIGHth');
fprintf(DTG, 'PGENA1:CH1:LOW 0');
fprintf(DTG, 'PGENA1:CH1:HIGH 1');
fprintf(DTG, 'PGENA1:CH1:DCYCle 10');
fprintf(DTG, 'PGENA1:CH2:PRATe EIGHth');
fprintf(DTG, 'PGENA1:CH2:LOW 0');
fprintf(DTG, 'PGENA1:CH2:HIGH 1');

%% Create the balancing script config
logfilepath = 'C:\Users\avdif\Documents\MATLAB\matlab_pulsing\pulsed_Rbalance\bal_log.txt';
logfile = fopen(logfilepath, 'a+');

bal_config.watd = watd;
bal_config.puls = pulseshaper;
bal_config.logfile = logfile;
bal_config.errt = 0.01;
bal_config.thresh = 0.01;
bal_config.max_try = 10;
bal_config.min_Vy = -10;
bal_config.max_Vy =  10;

%% Sweep excitation amplitude and balance at each point
sweep_log_path = 'C:\Users\avdif\Documents\MATLAB\matlab_pulsing\pulsed_Rbalance\sweep_log.txt';
sweep_log = fopen(sweep_log_path, 'a+');

for Vx=0.1:0.1:5
    fprintf('Changing Excitation to %d ---------------------------\n', Vx);
    result.Vx = Vx; result.Vy; result.R; result.t, result.V
    pulseshaper.sweep("Vx1", Vx);
    pulsed_Rbalance_balance(bal_config);
    Vy = pulsshaper.get("Vy1");
    result.Vy = Vy;
    result.R = -Vx/Vy;
    fprintf('Settled on balance with Vy = %d, R = %d\n', Vy, result.R);
    t, V = watd.watd();
    result.t = t;
    result.V = V;
    disp('Plotting Result...')
    plot(t, V);
    
    encoded_result = erase(jsonencode(result), newline);                      
    fprintf(sweep_log, '%s\n', encoded_result); 
end