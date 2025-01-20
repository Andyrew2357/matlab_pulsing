function gain = calibrate_pshaper_gain(pshaper, scope, Vin)
    assert(pshaper.get("Vx1") == 0, "Vx1 is initialized to a nonzero value.");
    assert(pshaper.get("Vy1") == 0, "Vy1 is initialized to a nonzero value.");
    assert(pshaper.get("Vx2") == 0, "Vx2 is initialized to a nonzero value.");
    assert(pshaper.get("Vy2") == 0, "Vy2 is initialized to a nonzero value.");

    pshaper.gain = 1; % set the gain to 1 initially
    
    if ~exist('Vin', 'var'), Vin = 0:0.2:5; end % if no input voltages provided, choose this

    Vx1out = [];
    fprintf(scope, 'DISplay:SELect:SOUrce CH1');
    for V=Vin
        pshaper.sweep("Vx1", V);
        cursor = split(query(scope, 'DISplay:WAVEView:CURSor?'), ";");
        Vout = str2double(cursor{8});
        Vx1out = [Vx1out, Vout];
    end
    pshaper.sweep("Vx1", 0);
    
    fprintf(scope, 'DISplay:SELect:SOUrce CH2');
    Vy1out = [];
    for V=Vin
        pshaper.sweep("Vy1", V);
        cursor = split(query(scope, 'DISplay:WAVEView:CURSor?'), ";");
        Vout = str2double(cursor{8});
        Vy1out = [Vy1out, -Vout];
    end
    pshaper.sweep("Vy1", 0);
    
    p = polyfit([Vin, Vin], [Vx1out, Vy1out], 1);
    fprintf('Fit Parameters: slope=%d, intercept=%d\n', p(:));
    gain = p(1);
    pshaper.gain = gain;

    plot(Vin, Vx1out, 'r-', Vin, Vy1out, 'b-', Vin, polyval(p, Vin), 'g--');
    legend("Vx", "Vy", "fit");

    fprintf(scope, 'DISplay:SELect:SOUrce CH1');
end