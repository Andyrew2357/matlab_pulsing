% This class implements a modified version of the ITP method for root
% finding. This is likely more sophisticated than our purposes demand, but
% it may help in reducing the required number of function calls
% (measurements) to converge on a balance point.

% The ITP method relies on iteratively narrowing a bracket around the root
% of a function. However, we cannot always rely on having a strict bracket 
% at the start. This should be worked out in the parent program before
% declaring a bracket.

classdef bracket_ITP < handle
    properties
        a, b;               % bracket bounds
        ya, yb;             % function value at the bracket bounds
        eps;                % target error bound
        kap1, kap2, n0;     % ITP hyperparameters
                            % kap1 > 0, usually order 0.1
                            % kap2 in [1, 1+phi) where phi is golden ratio
                            % n0 > 0, usually order 1
        n12, nmax, j;       % parameters evaluated during preprocessing  
        eta;                %  ya < yb ? 1 : -1 
        % The reference source I'm working with implicitly assumes ya < yb.
        % If this is not the case, I internally multiply negate whatever 
        % result is passed to me by multiplying by eta.
        xITP;               % estimated root, gets accessed by the parent
                            % script between get_xITP and update_bracket.
    end

    methods
        function s = bracket_ITP(eps, a, b, ya, yb, kap1, kap2, n0)
            s.eps = eps;
            assert(eps>0, 'In bracket_ITP: eps must be positive.')
            s.a = a; s.b = b;
            assert(a<b, 'In bracket_ITP: a must be less than b.')
            assert(~(ya==yb), 'In bracket_ITP: ya and yb cannot be equal.')
            s.eta = sign(yb - ya);
            s.ya = s.eta*ya; s.yb = s.eta*yb;
            
            % set up hyperparameters, default values if not provided
            if exist('kap1', 'var'), s.kap1 = kap1; else, s.kap1 = 0.1; end
            if exist('kap2', 'var'), s.kap2 = kap2; else, s.kap2 = 2; end
            if exist('n0', 'var'), s.n0 = n0; else, s.n0 = 1; end

            % preprocessed parameters
            s.n12 = ceil(log2((b-a)/(2*eps)));
            s.nmax = s.n0 + s.n12;
            s.j = 0;
        end

        function get_xITP(s)
            % calculate parameters
            x12 = (s.a + s.b)/2;                        % midpoint of bracket
            r = s.eps*(2^(s.nmax-s.j)) - (s.b-s.a)/2;   % max step from x12 to xITP
            delta = s.kap1*(s.b-s.a)^s.kap2;            % max step from xf to xt
            % I: interpolation (regula falsi point)
            xf = (s.yb*s.a - s.ya*s.b)/(s.yb - s.ya);
            % T: truncation (perturb estimator toward the center)
            sig = sign(x12 - xf);
            if delta<=abs(x12-xf), xt=xf+sig*delta; else, xt=x12; end
            % P: projection (project estimator to the minmax interval)
            if abs(xt-x12)<=r, s.xITP=xt; else, s.xITP=x12-sig*r; end
        end
        
        function eps_met = update_bracket(s, yITP)
            yITP = s.eta*yITP; % fix the sign of y to make the bracket increasing
            if yITP > 0 
                s.b = s.xITP; s.yb = yITP;              % update b
            elseif yITP < 0
                s.a = s.xITP; s.ya = yITP;              % update a
            else
                s.a = s.xITP; s.b = s.xITP;             % update a and b
            end
            s.j = s.j + 1;
            eps_met = (s.b - s.a) <= s.eps;             % have we reached the desired precision?
        end
    end
end  