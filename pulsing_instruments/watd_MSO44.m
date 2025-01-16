% Object to perform waveform averaging in the time domain using the MSO44

classdef watd_MSO44 < handle
    properties
        scope;      % reference to the relevant port for communicating with the scope
        ch;         % relevant channel on which to perform averages
        avg;        % number of averages to take for a single trace
        reps;       % repetitions to perform when averaging
        wait;       % wait time before pulling trace off the scope
        buff;       % tcpip input buffer size
        XZE; XIN; YZE; YMU; YOF;
    end

    methods
        function s = watd_MSO44(scope, ch, avg)
            s.scope=scope; 
            s.set_ch(ch);
            s.set_avg(avg);

            fprintf(scope, 'MEASU:MEAS1:TYPE MEAN');
            msg = sprintf('MEASU:MEAS1:SOURCE CH%d', ch);
            fprintf(scope, msg);
            
            fprintf(scope, 'WFMO:ENCdg BINary');
            s.update_WFMO()
        end

        function set_ch(s, val)
            msg = sprintf('DATa:SOUrce CH%d', val);
            fprintf(s.scope, msg);
            s.ch = val;
        end

        function val = get_ch(s)
            s.ch = str2double(eraseBetween(query(s.scope, 'DATa:SOUrce?'),1,2));
            val = s.ch;
        end

        function set_avg(s, val)
            msg = sprintf('ACQuire:NUMAVg %d', val);                        % set the number of averages to acquire
            fprintf(s.scope, msg);
            s.avg = val;
        end

        function val = get_avg(s)
            s.avg = str2double(query(s.scope, 'ACQuire:NUMAVg?'));
            val = s.avg;
        end

        function update_WFMO(s)
            s.XZE = str2double(query(s.scope, 'WFMP:XZE?'));
            s.XIN = str2double(query(s.scope, 'WFMP:XIN?'));
            s.YZE = str2double(query(s.scope, 'WFMP:YZE?'));
            s.YMU = str2double(query(s.scope, 'WFMP:YMU?'));
            s.YOF = str2double(query(s.scope, 'WFMP:YOF?'));
        end

        function y = bal_meas(s)
            pause(0.2);
            y = str2double(query(s.scope, 'MEASU:MEAN1:VAL?'));
        end

        function [t, V] = watd(s)
            pause(1);
            data = query(s.scope, 'CURVe?');
            header_len = str2double(data(2)) + 2;
            curve = typecast(uint8(data(header_len:end)), 'int16');
            V = ((curve-s.YOF)*s.YMU) + s.YZE;
            t = (0:length(V) - 1)*s.XIN + s.XZE;
        end

    end
end