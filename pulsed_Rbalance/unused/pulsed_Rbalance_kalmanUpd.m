% Kalman update function for the pulsed resistor bridge setup.
% This is passed to the kalman class, which is an abstract implementation
% of the filter
% measurement prediction z_pred = h(x_{k|k-1})

% Returns:
%   y:          measurement residual
%   H:          linearized observation matrix
%   R:          measurement covariance matrix

% State Vector: (R, A, dR/dV_x)
%   R:          sample resistance in units of R_standard
%   A:          total gain of the low and room temperature amplifiers
%   dR/dV_x:    derivative of R with respect to the excitation pulse height

%   h(R, A, dR/dV_x) = A(Vx + R*Vy)/(1 + R)

function [y, H, R] = pulsed_Rbalance_kalmanUpd(kf, z, Vx, Vy, R)
    r = kf.x(1); 
    % slightly confusing name. This is the resistance, which I'v
    % unfortunately labelled the same as the measurement covariance
    % in the comments. Hopefully it's pretty clear which is which.
    y = z - kf.x(2)*(Vx+r*Vy)/(1+r);                        % z - A*(Vx+Vy)/R
    H = [-kf.x(2)*(Vx+r*Vy)/(1+r)^2, (Vx+r*Vy)/(1+r), 0];   % dh/dx
end