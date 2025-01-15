% Implementation of a Kalman Filter compatible with the nonlinear EKF variety
% A Kalman filter is intended to optimally converge on the true state by 
% calculating the optimal mixing weights of extrapolated states (there must 
% be a model for the process) and new measurements. The extended Kalman filter 
% (EKF) is not optimal due to the linearization, and it tends to underestimate
% covariance. It may also diverge if the measurement and process noise are 
% not set appropriately. 

% Extraptolation Equations
%       State Extrapolation:            x_{k|k-1} = f(x_{k|k}, u_k)
%       Covariance Extrapolation:       P_{k|k-1} = F_k P_{k-1|k-1} (F_k)^T + Q_{k-1}

% Update Equations
%       Measurement Residual:           y_k = z_k - h(x_{k|k-1})
%       Residual Covariance:            S_k = H_k P_{k|k-1} (H_k)^T + R_k
%       Kalman Gain:                    K_k = P_{k|k-1} (H_k)^T (S_k)^{-1}
%       State Prediction:               x_{k|k} = x_{k|k-1} + K_k y_k
%       Covariance Prediction:          P_{k|k} = (I - K_k H_k) P_{k|k-1}

% Where F_k and H_k are defined by:
%       State Transition Matrix:        F_k = (df/dx)|_{x_{k|k-1}, u_{k}}
%       Observation Matrix:             H_k = (dh/dx)|_{x{k|k-1}}

% Other variables:
%       Estimated State at k:           x_{k|k}
%       Extrapolated State at k-1:      x_{k|k-1}
%       Est. Covariance Matrix at k:    P_{k|k}
%       Est. Covariance Extra. at k:    P_{k|k-1}

classdef kalman < handle
    properties
        pred;       % Predictor Function
        upd;        % Update Function
        x;          % State Vector
        P;          % Covariance Matrix
        K;          % Kalman Gain
    end

    methods
        function s = kalman(fpred, fupd, x0, P0)
            s.pred = fpred;
            s.upd = fupd;
            s.x = x0;
            s.P = P0;
            s.K = 0;
        end

        function s = predict(s, varargin)
            nx, F, Q = s.pred(s, varargin{:});  % extrapolate state, compute F, process covariance (Q)
            s.x = nx;
            s.P = F*s.P*F.' + Q;                % extrapolate covariance
        end

        function s = update(s, varargin)
            y, H, R = s.upd(s, varargin{:});    % measurment residual (y), compute H, measurement covariance (R)
            S = H*s.P*H.' + R;                  % residual covariance (S)
            s.K = s.P*(H.')/S;                  % Kalman gain (K)
            s.x = s.x + s.K*y;                  % update state
            s.P = s.P - s.K*H*s.P;              % update covariance
        end
    end
end