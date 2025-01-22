
classdef extrap < handle
    properties
        backlog;
        support;
        order;
    end

    methods
        function s = extrap(support, order, backlog)
            s.support = support;
            s.order = order;
        end

        function y = extrapolate(s, x)

        end
    end
end