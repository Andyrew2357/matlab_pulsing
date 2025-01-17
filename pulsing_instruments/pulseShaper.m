% controls the amplitudes of each output for the pulse shaper
classdef pulseShaper < handle
    properties
        Vx1, Vy1, Vx2, Vy2;     % Value for each DC input of the pulse shaper
        DCbox;                  % DC box which controls the pulse shaper
        address;                % Addresses of V's on the DC box
        cntrlf;                 % control function for DC box
        max_step;               % maximum allowed step size when sweeping
        wait;                   % wait time between steps when sweeping
        gain;                   % gain/loss of the pulse shaper (Vout/Vin)
                                % the shaper attenuates whatever signal it
                                % gets from the DCbox, so we need to
                                % divide out the gain to set the DC box
    end

    methods
        function s = pulseShaper(DCbox, cntrlf, max_step, wait, gain, address, DCvals)
            s.DCbox = DCbox;
            s.cntrlf = cntrlf;
            s.max_step = max_step;
            s.wait = wait;
            s.gain = gain;
            s.address = dictionary(["Vx1", "Vy1", "Vx2", "Vy2"], address);
            if exist('DCvals', 'var')
                s.Vx1 = DCvals(1); s.Vy1 = DCvals(2); s.Vx2 = DCvals(3); s.Vy2 = DCvals(4);
            else
            % If no starting values are provided, assume they are GND
                s.Vx1=0; s.Vy1=0; s.Vx2=0; s.Vy2=0;
            end
        end

        function set(s, ch, val)
            if ~ismember(ch, ["Vx1", "Vy1", "Vx2", "Vy2"])
                warning('pulseShaper channels are Vx1|Vy1|Vx2|Vy2.');
                return;
            end
            s.cntrlf(s.DCbox, s.address(ch), val/s.gain);
            switch ch
                case "Vx1"
                    s.Vx1 = val;
                case "Vy1"
                    s.Vy1 = val;
                case "Vx2"
                    s.Vx2 = val;
                case "Vy2"
                    s.Vy2 = val;
            end
        end

        function val = get(s, ch)
            if ~ismember(ch, ["Vx1", "Vy1", "Vx2", "Vy2"])
                warning('pulseShaper channels are Vx1|Vy1|Vx2|Vy2.');
                return;
            end
            switch ch
                case "Vx1"
                    val = s.Vx1;
                case "Vy1"
                    val = s.Vy1;
                case "Vx2"
                    val = s.Vx2;
                case "Vy2"
                    val = s.Vy2;
            end
        end

        function sweep(s, ch, val, max_step, wait)
            if ~ismember(ch, ["Vx1", "Vy1", "Vx2", "Vy2"])
                warning('pulseShaper channels are Vx1|Vy1|Vx2|Vy2.');
                return;
            end
            
            if ~exist('max_step', 'var'), max_step = s.max_step; end
            if ~exist('wait', 'var'), wait = s.wait; end

            start = s.get(ch);                                              % starting value
            dist = abs(val - start);                                        % distance to ending value
            num_step = ceil(dist/max_step);                                 % abiding by maximum step size, min number of steps to reach target
            step = dist/num_step;                                           % size of steps to actually take
            eta = sign(val - start);                                        % 1 if we're sweeping up, -1 if down
            target = start;                                 
            for i=1:num_step
                target = target + eta*step;
                disp(target);
                s.cntrlf(s.DCbox, s.address(ch), target/s.gain);            % take the step
                pause(wait);                                                % wait before proceeding
            end
            
            switch ch
                case "Vx1"
                    s.Vx1 = val;
                case "Vy1"
                    s.Vy1 = val;
                case "Vx2"
                    s.Vx2 = val;
                case "Vy2"
                    s.Vy2 = val;
            end
        end
    end
end