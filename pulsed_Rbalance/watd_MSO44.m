% Object to perform waveform averaging in the time domain using the MSO44

classdef watd_MSO44 < handle
    properties
        scope;      % reference to the relevant port for communicating with the scope
        ch;         % relevant channel on which to perform averages
        avg;        % number of averages to take for a single trace
        reps;       % repetitions to perform when averaging
        wait;       % wait time before pulling trace off the scope
        buff;       % tcpip input buffer size
    end

    methods
        function s = watd_MSO44(scope, ch, avg, reps, wait)
            s.scope=scope; 
            s.reps=reps; 
            s.wait=wait;
            s.set_avg(avg);
            s.set_ch(ch);

            fprintf(scope, 'MEASU:MEAS1:TYPE MEAN');
            msg = sprintf('MEASU:MEAS1:SOURCE CH%d', ch);
            fprintf(scope, msg);
        end

        % function val = watd(s, quick)
        %     val = s.watd_single();
        %     if quick                                                        % if quick, only do one average
        %         return;
        %     end
        % 
        %     for i=2:s.reps                                                  % otherwise we take reps averages
        %         val = val + s.watd_single();                                % aggregate the results
        %     end
        %     val = val/s.reps;
        % end
        % 
        % function val = watd_single(s)
        %     fprintf(s.scope, 'CLEAR');                                      % clear to run a measurement
        %     pause(s.wait);                                                  % wait for the average to finish
        %                                                                     % (make sure to set this long enough)
        %     disp('num acq')
        %     disp(query(s.scope, 'ACQuire:NUMACq?'))
        %     val = str2num(query(s.scope, 'CURVe?'));                        % pull the trace from the scope
        % end

        function val = watd(s)
            fprintf(s.scope, 'CLEAR');
            pause(s.wait);
            val = str2num(query(s.scope, 'CURVe?'));
        end

        function val = trace_mean(s)
            val = str2double(query(s.scope, 'MEASU:MEAN1:VAL?'));
        end

        function set_avg(s, val)
            %limit = str2double(query(s.scope, 'ACQuire:FASTAVerage:LIMit?'));
            %if (val > limit)
            %    val = limit;
            %    msg = sprintf('The provided setting is too high. Setting to %d', limit);
            %    warn(msg);
            %end
                
            msg = sprintf('ACQuire:NUMAVg %d', val);                        % set the number of averages to acquire
            fprintf(s.scope, msg);
            %msg = sprintf('ACQuire:FASTAVerage:STOPafter %d', val);         % set stop count (same)
            %fprintf(s.scope, msg);
            s.avg = val;
        end

        function val = get_avg(s)
            s.avg = str2double(query(s.scope, 'ACQuire:NUMAVg?'));
            val = s.avg;
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

        function val = get_maxSampleRate(s)
            val = str2double(query(s.scope, 'ACQuire:MAXSamplerate?'));
        end
    end
end