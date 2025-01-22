% This is a balance point predictor object to be used by the balancing
% function. This one naively extrapolates the new balance point based on
% the last few balance points.

classdef naive_extrap < handle
    properties
        Vxdat;      % array that keeps track of previous Vx data
        Rdat;       % array that keeps track of previous R data
        support;    % support to use for extrapolation
        order;      % order of the polynomial fit to use
        buffer;     % how many of the previous entries are placeholders
        gain;       % gain of the amplifier at the balance point
    end

    methods
        function s = naive_extrap(support, order, gain)
            s.support = support;
            s.order = order;
            s.gain = gain;
            s.buffer = support;
            s.Vxdat = zeros(1, support);
            s.Rdat = zeros(1, support);
        end

        function append(s, Vx, R)
            s.Vxdat = circshift(s.Vxdat, -1);       % cycle the saved data and insert the new point
            s.Vxdat(end) = Vx;
            s.Rdat = circshift(s.Rdat, -1); 
            s.Rdat(end) = R;
            s.buffer = max([0, s.buffer - 1]);      % update the buffer
        end

        function reset(s)
            s.buffer = s.support;                   % reset the buffer to reflect having no data
        end

        function R = guess(s, Vx)
            if s.buffer == s.support                % If we have no data, return 1
                R = 1;
                return
            end

            R = extrap1d(s.Vxdat(s.buffer+1:end), ...
                         s.Rdat(s.buffer+1:end), ...
                         Vx, s.support, s.order);   % extrapolate using previous data
        end

        function R = refined_guess(s, Vx, prev_Vy, y)
            falsi = -(s.gain*Vx - y)/(s.gain*prev_Vy - y);
            R = extrap1d([s.Vxdat(s.buffer+1:end), Vx], ...
                         [s.Rdat(s.buffer+1:end), falsi], ...
                         Vx, s.support, s.order);   % extrapolate based on the previous data and a gain-dependent off-balance estimate.
        end

    end
end