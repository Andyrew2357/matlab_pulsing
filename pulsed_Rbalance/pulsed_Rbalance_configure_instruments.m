function [DTG, pshaper, watd] = pulsed_Rbalance_configure_instruments(config)
    DTG_config = config.DTG_config;
    pshaper_config = config.pshaper_config;
    watd_config = config.watd_config;
    DTG = open_DTG(DTG_config);
    pshaper = open_pshaper(pshaper_config);
    watd = open_watd_MSO44(watd_config);
end

%% Set up the DTG
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function DTG = open_DTG(DTG_config)
    disp(DTG_config)
    constructor_fn = DTG_config.constructor_fn;
    constructor_args = DTG_config.constructor_args;
    DTG = constructor_fn(constructor_args{:});
    fopen(DTG);
end

%% Set up the Pulse Shaper
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function pshaper = open_pshaper(pshaper_config)
    constructor_fn = pshaper_config.constructor_fn;
    constructor_args = pshaper_config.constructor_args;
    cntrlf = pshaper_config.cntrlf;
    max_step = pshaper_config.max_step;
    wait = pshaper_config.wait;
    gain = pshaper_config.gain;
    address = pshaper_config.address;
    DCvals = pshaper_config.DCvals;
    DCbox = constructor_fn(constructor_args{:});
    fopen(DCbox);
    pshaper = pulseShaper(DCbox, cntrlf, max_step, wait, gain, address, DCvals);
end

%% Set up the Waveform Averager
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function watd = open_watd_MSO44(watd_config)
    constructor_args = watd_config.constructor_args;
    RemoteHost = watd_config.RemoteHost;
    RemotePort = watd_config.RemotePort;
    scope = instrfind(constructor_args{:});
    if isempty(scope)
        scope = tcpip(RemoteHost, RemotePort);
    else
        fclose(scope)
        scope = scope(1);
    end
    scope.InputBufferSize = watd_config.InputBufferSize;
    fopen(scope);
    ch = watd_config.ch;
    avg = watd_config.avg;
    cap_coupled = watd_config.cap_coupled;
    watd = watd_MSO44(scope, ch, avg, cap_coupled);
end