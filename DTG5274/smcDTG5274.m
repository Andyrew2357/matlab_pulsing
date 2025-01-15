function val = smcDTG5274(ico, val, rate)
%  This is the control function for Tektronix Data Timing Generator DTG5274

% NOTE: ico are parameters called upon by other sm functions.
%       ico(1) corresponds to the instrument
%       ico(2) corresponds to the channel we are accessing
%       ico(3) corresponds to the operation type (0=get,1=set)


global smdata;
instrument = smdata.inst(ico(1)).data.inst;

switch ico(2) % channel
    case 1 % *IDN?
        switch ico(3)
            case 0 % returns query result
                val = query(instrument, '*IDN?');
            % for some reason special measure wants to call this with
            % ico(1) = 1 and ico(2) = 6 on setup, so any relevant
            % initialization code goes here.
            case 6 % Initialization
                % nothing yet
                instrument.Timeout = 30;
                buffer = 20000 * 1024;
                fclose(instrument);% adding this so that was can transfer larger scans correctly
                instrument.InputBufferSize = buffer;
                fopen(instrument);
            otherwise 
                error('Operation not supported');
        end
    case 2 % level calibration
        switch ico(3)
            case 0 % perform calibration, returning 0 on success
                val = query(instrument, '*CAL?');
           % case 1 % perform calibration with no return
          %      fprintf(instrument, 'CAL');
            otherwise
                error('Operation not supported');
        end
    case 3 % run
        switch ico(3)
            case 1
                if isnumeric(val)
                    val = num2str(val);
                end
                if ~ismember(val, ["ON", "OFF", "1", "0"])
                    error('val must be ON, OFF, 1, or 0')
                end
                msg = sprintf('TBAS:RUN %s', val);
                fprintf(instrument, msg);
            otherwise
                error('Operation not supported');
        end

    case 4 % clock frequency
        switch ico(3)
            case 0
                val = str2double(query(instrument, 'TBAS:FREQ?'));
            case 1
                fprintf(instrument, 'TBAS:FREQ %f', val);
            otherwise
                error('Operation not supported');
        end

    case 5 % pulse and data generator modes
        switch ico(3)
            case 0
                val = query(instrument, 'TBAS:OMODe?');
            case 1
                if ~ismember(val, ["DATA", "PULS"])
                    error('Allowed modes are DATA or PULS')
                end
                fprintf(instrument, 'TBAS:OMODe %s', val);
            otherwise
                error('Operation not supported');
        end

    % ALL OF THESE ARE ASSOCIATED WITH THE PULSE GENERATOR MODE

    case 6 % pulse generator polarity
        switch ico(3)
            case 0
                mnframe = val{1};
                slot = val{2};
                chnl = val{3};
                msg = sprintf('PGEN%s%d:CH%d:POLarity?', slot, mnframe, chnl);
                val = query(instrument, msg);
            case 1
                mnframe = ico(4);
                slot = ico(5);
                chnl = ico(6);
                pol = val;
                if ~ismember(pol, ["NORM", "INV"])
                    error('Allowed polarity settings are NORM or INV');
                end
                msg = sprintf('PGEN%s%d:CH%d:POLarity %s', slot, mnframe, chnl, pol);
                fprintf(instrument, msg);
            otherwise
                error('Operation not supported');
        end
    case 7 % pulse generator lead delay
        switch ico(3)
            case 0
                mnframe = val{1};
                slot = val{2};
                chnl = val{3};
                param = val{4};
                msg = sprintf('PGEN%s%d:CH%d:LDELay? %s', slot, mnframe, chnl, param);
                val = str2double(query(instrument, msg));
            case 1
                mnframe = ico(4);
                slot = ico(5);
                chnl = ico(6);
                delay = val;
                msg= sprintf('PGEN%s%d:CH%d:LDELay %d', slot, mnframe, chnl, delay);
                fprintf(instrument, msg); 
            otherwise
                error('Operation not supported');
        end
    case 8 % pulse generator width
        switch ico(3)
            case 0
                mnframe = val{1};
                slot = val{2};
                chnl = val{3};
                msg = sprintf('PGEN%s%d:CH%d:WIDTh?', slot, mnframe, chnl);
                val = str2double(query(instrument, msg));
            case 1
                mnframe = ico(4);
                slot = ico(5);
                chnl = ico(6);
                width = val;
                msg = sprintf('PGEN%s%d:CH%d:WIDTh %d', slot, mnframe, chnl, width);
                fprintf(instrument, msg);
            otherwise
                error('Operation not supported');
        end
    case 9 % pulse generator high value
        switch ico(3)
            case 0
                mnframe = val{1};
                slot = val{2};
                chnl = val{3};
                msg = sprintf('PGEN%s%d:CH%d:HIGH?', slot, mnframe, chnl);
                val = str2double(query(instrument, msg));
            case 1
                mnframe = ico(4);
                slot = ico(5);
                chnl = ico(6);
                high = val;
                msg = sprintf('PGEN%s%d:CH%d:HIGH %f', slot, mnframe, chnl, high);
                fprintf(instrument, msg);
            otherwise
                error('Operation not supported');
        end
    case 10 % pulse generator low value
        switch ico(3)
            case 0
                mnframe = val{1};
                slot = val{2};
                chnl = val{3};
                msg = sprintf('PGEN%s%d:CH%d:LOW?', slot, mnframe, chnl);
                val = str2double(query(instrument, msg));
            case 1
                mnframe = ico(4);
                slot = ico(5);
                chnl = ico(6);
                low = val;
                msg = sprintf('PGEN%s%d:CH%d:LOW %f', slot, mnframe, chnl, low);
                fprintf(instrument, msg);
            otherwise
                error('Operation not supported');
        end
    case 11 % pulse generator offset
        switch ico(3)
            case 0
                mnframe = val{1};
                slot = val{2};
                chnl = val{3};
                msg = sprintf('PGEN%s%d:CH%d:OFFSet?', slot, mnframe, chnl);
                val = str2double(query(instrument, msg));
            case 1
                mnframe = ico(4);
                slot = ico(5);
                chnl = ico(6);
                offset = val;
                msg = sprintf('PGEN%s%d:CH%d:OFFSet %f', slot, mnframe, chnl, offset);
                fprintf(instrument, msg);
            otherwise
                error('Operation not supported');
        end
    case 12 % pulse generator duty cycle (percentage)
        switch ico(3)
            case 0
                mnframe = val{1};
                slot = val{2};
                chnl = val{3};
                msg = sprintf('PGEN%s%d:CH%d:DCYCle?', slot, mnframe, chnl);
                val = str2double(query(instrument, msg));
            case 1
                mnframe = ico(4);
                slot = ico(5);
                chnl = ico(6);
                duty = val;
                msg = sprintf('PGEN%s%d:CH%d:DCYCle %d', slot, mnframe, chnl, duty);
                fprintf(instrument, msg);
            otherwise
                error('Operation not supported');
        end
    case 13 % pulse rate setting (this is a relative rate in terms of the clock frequency)
        switch ico(3)
            case 0
                mnframe = val{1};
                slot = val{2};
                chnl = val{3};
                msg = sprintf('PGEN%s%d:CH%d:PRATe?', slot, mnframe, chnl);
                val = query(instrument, msg);
            case 1
                mnframe = ico(4);
                slot = ico(5);
                chnl = ico(6);
                prate = val;
                if ~ismember(prate, ["NORM", "HALF", "QUAR", "EIGH", "SIXT", "OFF"])
                    error('pulse rate must be NORM, HALF, QUAR, EIGH, SIXT, or OFF');
                end
                msg = sprintf('PGEN%s%d:CH%d:PRATe %s', slot, mnframe, chnl, prate);
                fprintf(instrument, msg);
            otherwise
                error('Operation not supported');
        end
    otherwise
        error('Operation not supported');
end

end