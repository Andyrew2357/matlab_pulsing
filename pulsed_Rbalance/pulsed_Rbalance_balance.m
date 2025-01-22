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
    %   predictor:      object for predicting the balance point
    %   min_intvl:      minimum distance between the two initial guesses
    
    % Parse the config into relevant parameters
    watd        =   config.watd;
    puls        =   config.puls;
    logfile     =   config.logfile;
    errt        =   config.errt;
    thresh      =   config.thresh;
    max_try     =   config.max_try;
    min_Vy      =   config.min_Vy;
    max_Vy      =   config.max_Vy;
    predictor   =   config.predictor;
    min_intvl   =   config.min_intvl;
    
    Vx = puls.get("Vx1");
    % create the log for this balance point and record the excitation voltage
    log.Vx = Vx; 
    log.success = false; 
    log.terminated = "NULL"; 
    log.tries = 0; 
    log.res = "NULL";
    log.history = {};

    % Never attempt to provide a negative bias to the pulse shaper
    min_Vy = max([min_Vy, 0]);

    % Guess the balance point (this can be more sophisticated as we improve)    
    Rguess = predictor.guess(Vx);
    xa = clip(Vx/Rguess, min_Vy, max_Vy);

    % Take measurements at the points for the initial guesses. If it
    % happens to be good enough, terminate early.
    need_refinements = true;
    puls.sweep("Vy1", xa); ya = watd.bal_meas();                            % take the measurement at xa

    if abs(ya) < thresh                                                     % terminate early if we're close enough
        need_refinements = false; 
        success = true;
        log.terminated = "GOOD_GUESS";                                      % record termination condition
    end

    if need_refinements                                                     % If our guess wasn't spot on
        Rguess = predictor.refined_guess(Vx, xa, ya);
        xb = clip(Vx/Rguess, min_Vy, max_Vy);
        if abs(xb - xa) < min_intvl                                         % if xb is too close to xa, perturb it away from xa
            sig = sign(xb-xa);
            xt = xa + sig*min_intvl;
            if (xt > max_Vy) || (xt < min_Vy)
                xb = xa - sig*min_intvl;
            else
                xb = xt;
            end
        end

        puls.sweep("Vy1", xb); yb = watd.bal_meas();                        % take the measurement at xb
        log.history = [log.history, struct('method', "GUESS", 'xa', xa, ...
                                           'xb', xb, 'ya', ya, 'yb', yb)];  % add to the log history

        if abs(yb) < thresh                                                 % terminate early if we're close enough
            need_refinements = false; 
            success = true;
            log.terminated = "GOOD_GUESS";                                  % record termination condition
        end

        if xb < xa
            xtemp = xa; xa = xb; xb = xtemp;                                % switch the points if they're in the wrong order
            ytemp = ya; ya = yb; yb = ytemp;
        end
    end
    
    % Assuming we didn't luck out on our initial guesses, proceed by a root
    % finding algorithm (ITP if bracketed, secant if not)
    good_bracket = false;                                                   % are we guaranteed to enclose at root in [xa, xb]
    tries = 0;
    while need_refinements                                                  % attempt to find an optimal balance point
        tries = tries + 1;
        if tries > max_try                                                  % failed to find a balance point satisfying error bound
            log.terminated = "MAX_TRIES";                                   % record termination condition
            tries = tries - 1;
            success = false;
            break;
        end

        if good_bracket                                                     % converge on the balance point using ITP
            
            bracket.get_xITP(); xITP = bracket.xITP;                        % no need to check for clipping if we already have a bracket
            puls.sweep("Vy1", xITP); yITP = watd.bal_meas();
            met_errt = bracket.update_bracket(yITP);                        % update the bracket based on the new measurement
            
            log.history = [log.history, struct('method', "ITP", ...
                           'xa', bracket.a, 'xb', bracket.b, ...
                           'ya', bracket.ya, 'yb', bracket.yb)];            % add to the log history
            
            if met_errt                                                     % have we met the target error bound?
                log.terminated = "ERROR_BOUND_MET";                         % record termination condition
                success = true;
                break
            end

        else                                                                % attempt to find a good bracket by proceeding with secant method
            
            if abs(ya) < thresh                                             % regardless of errt, if we get a sufficiently small signal, terminate early
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
    predictor.append(Vx, Vx/Vy);                                            % update the predictor with the most recent result.

    % fill out the rest of the logging info
    log.success = success;
    log.steps = tries;
    log.res = Vy;

    encoded_log = erase(jsonencode(log), newline);                          % encode the log as a json formatted string, removing all newline characters                        
    fprintf(logfile, '%s\n', encoded_log);                                  % write everything to the log file as a line in json format

    fprintf('terminated: %s\n', log.terminated);
end
