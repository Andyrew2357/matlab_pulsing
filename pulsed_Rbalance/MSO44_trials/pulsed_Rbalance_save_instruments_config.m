% DTG config
DTG_config.constructor_fn = @gpib;                                          % we use GPIB for this instrument
DTG_config.constructor_args = {'ni', 0, 27, ...                             % adaptor, board number, GPIB address
                               'OutputBufferSize', 512, ...                 % size of buffer on the DTG end
                               'EOSCharCode', 'LF', ...
                               'EOIMode', 'on', ...
                               'EOSMode', 'none'};


% pulse shaper config
pshaper_config.constructor_fn = @serial;                                    % The DC box is really an arduino that we talk to over USB
pshaper_config.constructor_args = {'COM3', ...                              % name of the port
                                   'BaudRate', 115200, ...                  % don't totally understand this, usually would be 9600, but needs to be the instructions to be read correctly
                                   'OutputBufferSize', 512, ...             % size of the buffer on the arduino end
                                   'DataBits', 8, ...
                                   'Parity', 'none', ...
                                   'StopBits', 1};
pshaper_config.cntrlf = @AD5764;                                            % control function for the pulse shaper
pshaper_config.max_step = 0.05;                                             % maximum voltage step to take when sweeping
pshaper_config.wait = 0.1;                                                  % wait time between steps when sweeping
pshaper_config.gain = 0.09441739;
pshaper_config.address = [2, 1, 4, 3];                                      % which outputs on the DC box correspond to Vx1, Vy1, Vx2, Vy2
pshaper_config.DCvals = [0, 0, 0, 0];                                       % starting values for outputs on the DC box

% watd (MSO44) config
watd_config.RemoteHost = '169.254.9.11';                                    % TCP/IP address
watd_config.RemotePort = 4000;                                              % port number
watd_config.constructor_args = {'Type', 'tcpip', ...
                                'RemoteHost', watd_config.RemoteHost, ...
                                'RemotePort', watd_config.RemotePort, ...
                                'Tag', ''};
watd_config.InputBufferSize = 16384;                                        % Input buffer size on the computer end
watd_config.ch = 1;                                                         % which channel to use for trace averaging
watd_config.avg = 10240;                                                    % how many averages to take for a waveform
watd_config.cap_coupled = false;

% save as a .mat
path = 'C:\Users\pulsing_meas\Documents\MATLAB\matlab_pulsing\pulsed_Rbalance\MSO44_trials\MSO44_trial_inst_config.mat';
save(path, 'DTG_config', 'pshaper_config', 'watd_config');