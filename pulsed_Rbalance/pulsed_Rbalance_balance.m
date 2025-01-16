% Using the kalman filtering procedure, calibrate the height of the balance
% pulse to drive the gate of the amplifier to zero. Return true on success.
% On balance, -Vx/Vy = R, where R is expressed in unites of Rst. 

% See pulsed_Rbalance_kalmanPred.m and pulsed_Rbalance_kalmanUpd for
% details related to this specific kalman filter.

function success = pulsed_Rbalance_balance(config)
    % config is a struct with the following fields:
    %   dtg:            object for controlling the data timing generator
    %   watd:           object for time-domain waveform averaging
    %   puls:           object to control the pulse shaper via DC box
    %   logfile:        file for logging data related to banace procedure
    %   errt:           acceptable error threshold for a balance point
    %   thresh:         disregarding errt, acceptable output for balance
    %   max_try:        maximum tries to find an optimal balance point
    %   min_Vy:         minimum value Vy can take
    %   max_Vy:         maximum value Vy can take
    
    % Parse the config into relevant parameters
    watd        =   config.watd;
    puls        =   config.puls;
    logfile     =   config.logfile;
    errt        =   config.errt;
    thresh      =   config.thresh;
    max_try     =   config.max_try;
    min_Vy      =   config.min_Vy;
    max_Vy      =   config.max_Vy;
    
    Vx = puls.get("Vx1");
    % create the log for this balance point and record the excitation voltage
    log.Vx = Vx; log.success; log.terminated; log.tries; log.res; log.history = {};

    % Never attempt to provide a balance pulse corresponding to negative R
    if Vx > 0, max_Vy = min([max_Vy, 0]); elseif Vx < 0, min_Vy = max([min_Vy, 0]); end

    % Guess the balance point (this can be more sophisticated as we improve)    
    % Make the initial guesses. In this case choose R=1/2 and R=2
    xa = clip(-2*Vx, min_Vy, max_Vy);
    xb = clip(-0.5*Vx, min_Vy, max_Vy);
    % LOGGGGINGGGGG

    puls.sweep("Vy1", xa); ya = watd.bal_meas();                            % take the measurement at xa
    puls.sweep("Vy1", xb); yb = watd.bal_meas();                            % take the measurement at xb
    log.history = [log.history, struct('method', "GUESS", 'xa', xa, ...
                                        'xb', xb, 'ya', ya, 'yb', yb)];     % add to the log history
    
    good_bracket = false;                                                   % are we guaranteed to enclose at root in [xa, xb]
    tries = 0;
    while 1                                                                 % attempt to find an optimal balance point
        tries = tries + 1;
        if tries > max_try                                                  % failed to find a balance point satisfying error bound
            log.terminated = "MAX_TRIES";                                   % record termination condition
            tries = tries - 1;
            success = false;
            break;
        end

        if good_bracket                                                     % converge on the balance point using ITP

            xITP = bracket.get_xITP();                                      % no need to check for clipping if we already have a bracket
            puls.sweep("Vy1", xITP); yITP = watd.bal_meas();
            met_errt = bracket.update_bracket(yITP);                        % update the bracket based on the new measurement
            
            log.history = [log.history, struct('method', "ITP", ...
                            'xa', xa, 'xb', xb, 'ya', ya, 'yb', yb)];       % add to the log history
            
            if met_errt                                                     % have we met the target error bound?
                log.terminated = "ERROR_BOUND_MET";                         % record termination condition
                success = true;
                break
            end

        else                                                                % attempt to find a good bracket
            
            if abs(ya) < thresh                                             % regardless of errt, if we get a sufficiently small signal, terminate early.
                puls.sweep("Vy1", xa);
                log.terminated = "THRESHOLD_SIGNAL_MET";                    % record termination condition
                success = true;
                break;
            elseif abs(yb) < thresh
                puls.sweep("Vy1", xb);
                log.terminated = "THRESHOLD_SIGNAL_MET";                    % record termination condition
                success = true;
                break
            end

            if sign(ya*yb) < 0                                              % If we have a bracket, proceed with ITP
                good_bracket = true;
                tries = tries - 1;
                bracket = bracket_ITP(errt, xa, xb, ya, yb);                % declare the bracket object, now that we have one
                continue
            end

            % Proceed with a secant method approach (may modify this to pad out the interval hoping for a bracket)
            x0 = clip((xa*yb - xb*ya)/(yb - ya), min_Vy, max_Vy);           % guess where the root should be
            puls.sweep("Vy1", x0); y0 = watd.bal_meas();
            
            if x0 < xa                                                      % update (xa, ya), (xb, yb) accordingly.
                xb = xa; yb = ya;
                xa = x0; ya = y0;
            else
                xa = xb; ya = yb;
                xb = x0; yb = y0;
            end
            
            log.history = [log.history, struct('method', "SECANT", ...
                                'xa', xa, 'xb', xb, 'ya', ya, 'yb', yb)];   % add to the log history
        end

    end

    Vy = puls.get("Vy1");

    % fill out the rest of the logging info
    log.success = success;
    log.steps = tries;
    log.res = Vy;

    encoded_log = erase(jsonencode(log), newline);                          % encode the log as a json formatted string, removing all newline characters                        
    fprintf(logfile, '%s\n', encoded_log);                                  % write everything to the log file as a line in json format
end
