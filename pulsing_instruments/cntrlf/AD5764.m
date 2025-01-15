% function for controlling the AD5764 DC box (Arduino based). This is
% essentially stolen from the control function implemented for special
% measure, attributed to Elena Lazareva (2017-06-29) and Sergio de la
% Barrera (2018-04-19).

function AD5764(inst, ch, V)
    switch ch
        case 1
            n1=19; n2=0; m1=1; m2=0;
        case 2
            n1=18; n2=0; m1=1; m2=0;
        case 3
            n1=17; n2=0; m1=1; m2=0;
        case 4
            n1=16; n2=0; m1=1; m2=0;
        case 5
            n1=0; n2=19; m1=0; m2=1;
        case 6
            n1=0; n2=18; m1=0; m2=1;
        case 7
            n1=0; n2=17; m1=0; m2=1;
        case 8
            n1=0; n2=16; m1=0; m2=1;
    end

    if V >= 0
        dec16 = round((2^15-1)*V/10); %Decimal equivalent of 16 bit data
    else
        dec16 = round(2^16 - abs(V)/10 * 2^15); %Decimal equivalent of 16 bit data
    end

    try % hack to avoid error from especially small numbers
        bin16 = de2bi(dec16,16,2,'left-msb'); % 16 bit binary
        d1=bi2de(fliplr(bin16(1:8))); % first 8 bits
        d2=bi2de(fliplr(bin16(9:16))); % second 8 bits
        fwrite(inst,[255,254,253,n1,d1*m1,d2*m1,n2,d1*m2,d2*m2]);
        % disp([255,254,253,n1,d1*m1,d2*m1,n2,d1*m2,d2*m2]);
        while inst.BytesAvailable
            fscanf(inst,'%e');
        end
    catch
    % pass
    end
end