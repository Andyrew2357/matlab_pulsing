% Performs a least-squares fit on the data and interpolates or extrapolates
% the desired point based on that fit.

function y = extrap1d(xdat, ydat, x, support, order)
    % xdat and ydat are the previous data points collected. x is the
    % desired point. support limits the number of data points we use. order
    % is the order of the polynomial fit.

    support = min([length(xdat), support]); % if we have fewer than the max number of data points to use, use what we have
    order = min([support - 1, order]);      % you can only get a unique fit if the polynomial order is less than the support

    p = polyfit(xdat(end+1-support:end), ydat(end+1-support:end), order);
    y = polyval(p, x);
end