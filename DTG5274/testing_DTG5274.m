%% INITIALIZATION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% SM instrument initialization
clear all;
close all;
instrreset;
global smdata;

% GPIB addresses
GPIB_BOARD = 'ni';
BOARD_NUM = 0;

DTG5274.name = 'DTG';
DTG5274.COM = 27;
DTG5274.adaptor = 'ni';

%% Load the scope
ind = smloadinst('DTG5274', [], DTG5274.adaptor, 0, DTG5274.COM);

% open GPIB communication
smclose(ind);
smopen(ind);
smdata.inst(ind).name = DTG5274.name;

% add channels
% 'IDN', 'CAL', 'TRIGGER', 'CLK_FREQ', 'MODE', 'P_POLARITY', 'P_LDELAY', 'P_WIDTH', 'P_HIGH', 'P_LOW', 'P_OFFSET', 'P_DCYCLE', 'P_RELRATE'
% generic commands
smaddchannel(smdata.inst(ind).name, 'IDN', [smdata.inst(ind).name, '.IDN'])
smaddchannel(smdata.inst(ind).name, 'CAL', [smdata.inst(ind).name, '.CAL'])
smaddchannel(smdata.inst(ind).name, 'RUN', [smdata.inst(ind).name, '.RUN'])
smaddchannel(smdata.inst(ind).name, 'CLK_FREQ', [smdata.inst(ind).name, '.CLK_FREQ'])
smaddchannel(smdata.inst(ind).name, 'MODE', [smdata.inst(ind).name, '.MODE'])
% pulse generator mode
smaddchannel(smdata.inst(ind).name, 'P_POLARITY', [smdata.inst(ind).name, '.P_POLARITY'])
smaddchannel(smdata.inst(ind).name, 'P_LDELAY', [smdata.inst(ind).name, '.P_LDELAY'])
smaddchannel(smdata.inst(ind).name, 'P_WIDTH', [smdata.inst(ind).name, '.P_WIDTH'])
smaddchannel(smdata.inst(ind).name, 'P_HIGH', [smdata.inst(ind).name, '.P_HIGH'])
smaddchannel(smdata.inst(ind).name, 'P_LOW', [smdata.inst(ind).name, '.P_LOW'])
smaddchannel(smdata.inst(ind).name, 'P_OFFSET', [smdata.inst(ind).name, '.P_OFFSET'])
smaddchannel(smdata.inst(ind).name, 'P_DCYCLE', [smdata.inst(ind).name, '.P_DCYCLE'])
smaddchannel(smdata.inst(ind).name, 'P_RELRATE', [smdata.inst(ind).name, '.P_RELRATE'])

% generic commands test
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% IDN (works)
disp('testing IDN')
smget('DTG.IDN') % standard identification query

%% CAL (works)
disp('testing CAL')
smget('DTG.CAL') % calibrate levels and return 0 on success
%smset('DTG.CAL') % calibrate without return

%% clock frequency (works)
disp('testing CLK_FREQ')
smget('DTG.CLK_FREQ')
smset('DTG.CLK_FREQ', 10E6)
disp('should be 10E6:')
smget('DTG.CLK_FREQ')
smset('DTG.CLK_FREQ', 100E6)
disp('should be 100E6:')
smget('DTG.CLK_FREQ')

%% operational mode (works)
disp('testing MODE')
smget('DTG.MODE')
smset('DTG.MODE', 'DATA')
disp('should be DATA:')
smget('DTG.MODE')
smset('DTG.MODE', 'PULS')
disp('should be PULS:') 
smget('DTG.MODE')

%% pulse generator commands test
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% pulse polarity (works)
disp('testing P_POLARITY')
smget('DTG.P_POLARITY', {1, 'A', 1})
smset('DTG.P_POLARITY', 'INV', 'ico4', {1, 'A', 1})
disp('should be INV:') 
smget('DTG.P_POLARITY', {1, 'A', 1})
smset('DTG.P_POLARITY', 'NORM', 'ico4', {1, 'A', 1})
disp('should be NORM:') 
smget('DTG.P_POLARITY', {1, 'A', 1})

%% lead delay (DOESN'T WORK FOR SOME REASON)
% I just keep getting 3E-6 for the max lead delay regardless of what I try
% to set.
disp('testing P_LDELAY')
smget('DTG.P_LDELAY', {1, 'A', 1, 'MAX'})
smget('DTG.P_LDELAY', {1, 'A', 1, 'MIN'})
smset('DTG.P_LDELAY', 4E-6, 'ico4', {1, 'A', 1})
disp('should be 4E-6:')
smget('DTG.P_LDELAY', {1, 'A', 1, 'MAX'})
smget('DTG.P_LDELAY', {1, 'A', 1, 'MIN'})
smset('DTG.P_LDELAY', 3E-6, 'ico4', {1, 'A', 1})
disp('should be 3E-6:')
smget('DTG.P_LDELAY', {1, 'A', 1, 'MAX'})
smget('DTG.P_LDELAY', {1, 'A', 1, 'MIN'})

%% pulse width (works)
disp('testing P_WIDTH')
smget('DTG.P_WIDTH', {1, 'A', 1})
smset('DTG.P_WIDTH', 6E-9, 'ico4', {1, 'A', 1})
disp('should be 6E-9:')
smget('DTG.P_WIDTH', {1, 'A', 1})
smset('DTG.P_WIDTH', 5E-9, 'ico4', {1, 'A', 1})
disp('should be 5E-9:')
smget('DTG.P_WIDTH',{1, 'A', 1})

%% high level for pulse (works)
disp('testing P_HIGH')
smget('DTG.P_HIGH', {1, 'A', 1})
smset('DTG.P_HIGH', 0.3, 'ico4', {1, 'A', 1})
disp('should be 0.3:')
smget('DTG.P_HIGH', {1, 'A', 1})
smset('DTG.P_HIGH', 1.0, 'ico4', {1, 'A', 1})
disp('should be 1.0:')
smget('DTG.P_HIGH',{1, 'A', 1})

%% low level for pulse (works)
disp('testing P_LOW')
smget('DTG.P_LOW', {1, 'A', 1})
smset('DTG.P_LOW', 0.1, 'ico4', {1, 'A', 1})
disp('should be 0.1:')
smget('DTG.P_LOW', {1, 'A', 1})
smset('DTG.P_LOW', 0.0, 'ico4', {1, 'A', 1})
disp('should be 0.0:')
smget('DTG.P_LOW',{1, 'A', 1})

%% pulse offset (works)
disp('testing P_OFFSET')
smget('DTG.P_OFFSET', {1, 'A', 1})
smset('DTG.P_OFFSET', 0.1, 'ico4', {1, 'A', 1})
disp('should be 0.1:')
smget('DTG.P_OFFSET', {1, 'A', 1})
smset('DTG.P_OFFSET', 0.5, 'ico4', {1, 'A', 1})
disp('should be 0.5:')
smget('DTG.P_OFFSET',{1, 'A', 1})

%% duty cycle (works)
disp('testing P_DCYCLE')
smget('DTG.P_DCYCLE', {1, 'A', 1})
smset('DTG.P_DCYCLE', 40, 'ico4', {1, 'A', 1})
disp('should be 40:')
smget('DTG.P_DCYCLE', {1, 'A', 1})
smset('DTG.P_DCYCLE', 50, 'ico4', {1, 'A', 1})
disp('should be 50:')
smget('DTG.P_DCYCLE',{1, 'A', 1})

%% relative repetition rate with respect to clock frequency (works)
disp('testing P_RELRATE')
smget('DTG.P_RELRATE', {1, 'A', 1})
smset('DTG.P_RELRATE', 'OFF', 'ico4', {1, 'A', 1})
disp('should be OFF:')
smget('DTG.P_RELRATE', {1, 'A', 1})
smset('DTG.P_RELRATE', 'SIXT', 'ico4', {1, 'A', 1})
disp('should be SIXT:')
smget('DTG.P_RELRATE', {1, 'A', 1})
smset('DTG.P_RELRATE', 'EIGH', 'ico4', {1, 'A', 1})
disp('should be EIGH:')
smget('DTG.P_RELRATE', {1, 'A', 1})
smset('DTG.P_RELRATE', 'QUAR', 'ico4', {1, 'A', 1})
disp('should be QUAR:')
smget('DTG.P_RELRATE',{1, 'A', 1})
smset('DTG.P_RELRATE', 'HALF', 'ico4', {1, 'A', 1})
disp('should be HALF:')
smget('DTG.P_RELRATE',{1, 'A', 1})
smset('DTG.P_RELRATE', 'NORM', 'ico4', {1, 'A', 1})
disp('should be NORM:')
smget('DTG.P_RELRATE',{1, 'A', 1})

%% actually running
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%
smset('DTG.RUN', 'ON')

%%
smset('DTG.RUN', 'OFF')

%%
smset('DTG.CLK_FREQ', 1E5)
smget('DTG.CLK_FREQ')

%%
smset('DTG.RUN', 'ON')

%%
smset('DTG.P_DCYCLE', 50, 'ico4', {1, 'A', 1})