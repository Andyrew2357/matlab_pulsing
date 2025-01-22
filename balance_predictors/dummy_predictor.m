% maximally naive predictor function to pass for debugging purposes.

classdef dummy_predictor < handle
    properties
        Rguessa;     % first guessed R
        Rguessb;     % second guessed R
    end

    methods
        function s = dummy_predictor(Rguessa, Rguessb)
            s.Rguessa = Rguessa;
            s.Rguessb = Rguessb;
        end

        function append(varargin)
            % This predictor doesn't keep track of prior data
        end

        function R = guess(s, varargin)
            R = s.Rguessa;  % return whatever we set our guess as
        end

        function R = refined_guess(s, varargin)
            R = s.Rguessb;  % return whatever we set our guess as
        end
    end
end