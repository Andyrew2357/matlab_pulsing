% Kalman prediction function for the pulsed resistor bridge setup.
% This is passed to the kalman class, which is an abstract implementation
% of the filter
% state extrapolation:  x_{k|k-1} = f(x_{k|k}, u_k)

% Returns:
%   nx:         extrapolated state
%   F:          linearized state transition matrix
%   Q:          process covariance matrix

% State Vector: (R, A, dR/dV_x)
%   R:          sample resistance in units of R_standard
%   A:          total gain of the low and room temperature amplifiers
%   dR/dV_x:    derivative of R with respect to the excitation pulse height

%   f(x) cannot be explicitly specified
%   F = 1 + delta_Vx*|R><dR/dV_x|

function [nx, F, Q] = pulsed_Rbalance_kalmanPred(kf, Q, delta_Vx)
    F = eye(3);                 % when there is no excitation change, f(x) = x
    nx = kf.x;                  % this is because we don't have a good a-priori model
    if exist('delta_Vx', 'var')
        F(1, 3) = delta_Vx;     % Jacobian of f includes one off diagonal term
        nx = F*nx;              % extraptolate the state
    end
end