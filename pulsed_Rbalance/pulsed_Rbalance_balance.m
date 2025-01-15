% Using the kalman filtering procedure, calibrate the height of the balance
% pulse to drive the gate of the amplifier to zero. On balance, -Vx/Vy = R,
% where R is expressed in unites of Rst. 
% 
% See pulsed_Rbalance_kalmanPred.m and pulsed_Rbalance_kalmanUpd for
% details related to this specific kalman filter.

function pulsed_Rbalance_balance(config)
    % config is a struct with the following fields:
    %   watd:           object for time-domain waveform averaging
    %   puls:           object to control the pulse shaper via DC box
    %   logfile:        file for logging data related to banace procedure
    %   errt:           acceptable error threshold for a balance point
    %   max_try:        maximum tries to find an optimal balance point
    %   min_Vy:         minimum value Vy can take
    %   max_Vy:         maximum value Vy can take
    
    % Parse the config into relevant parameters
    watd        =   config.watg;
    puls        =   config.puls;
    logfile     =   config.logfile;
    errt        =   config.errt;
    max_try     =   config.max_try;
    min_Vy      =   config.min_Vy;
    max_Vy      =   config.max_Vy;

    Vx = puls.get("Vx1"); Vy = puls.get("Vy1");

    % Guess the balance point (this can be more sophisticated as we improve)
    % right now we just start with the current R = 2
    Rguess = 2;

      

end

% x is the initial value, dx is the proposed step in that value
% truncateStep returns the new value with step size not exceeding mdx.
function y = truncateStep(x, dx, mdx, miny, maxy)
    if abs(dx) > mdx
        dx = sign(dx)*mdx;
    end
    y = x + dx;
    y = min([y, maxy]);
    y = max([y, miny]);
end

% write a message to 
function dump_log(msg, logfile)
    if strcmp(logfile, "")
        return;
    end
    writelines(msg, logfile, WriteMode="append");
end