function pshaper_map(config)
    % config is a struct with a the following fields
    %   puls:           object to control the pulse shaper via DC box
    %   scope:          object to communicate with the scope
    %   V:              array describing the pulse heights to use
    %   x_path:         where to save traces for Vx
    %   y_path:         where to save traces for Vy
    %   meta_path:      where to save the metadata
    
    disp('Beginning Pulse Shaper Map')

    puls        =   config.puls;
    scope       =   config.scope;
    V           =   config.V;
    x_path      =   config.x_path;
    y_path      =   config.y_path;
    meta_path   =   config.meta_path;

    x_file = fopen(x_path, 'a+');
    y_file = fopen(y_path, 'a+');

    fprintf(scope, 'DATA:WIDTh 4');
    fprintf(scope, 'DATA:ENCdg ASCII');                                     % change the encoding scheme for queried waveform to ASCII
    
    meta.x_path = x_path;
    meta.y_path = y_path;
    meta.V = jsonencode(V);                                                 % need to encode this right, otherwise it will error
    meta.XZE = str2double(query(scope, 'WFMP:XZE?'));                       % X zero
    meta.XIN = str2double(query(scope, 'WFMP:XIN?'));                       % X increment
    meta.YZE = str2double(query(scope, 'WFMP:YZE?'));                       % Y zero
    meta.YMU = str2double(query(scope, 'WFMP:YMU?'));                       % Y multiplier
    meta.YOF = str2double(query(scope, 'WFMP:YOF?'));                       % Y offset

    writestruct(meta, meta_path, 'FileType', 'json');                       % write the metadata in json format

    [rows, cols] = size(V);
    for i=1:cols
        Vx = V(1,i); Vy = V(2,i);
        fprintf("Next Levels: Vx=%d, Vy=%d\n", Vx, Vy);
        puls.sweep("Vx1", Vx); puls.sweep("Vy1", Vx);

        fprintf(scope, 'DATA:SOUrce CH1');
        pause(0.2);
        fprintf(x_file, query(scope, 'CURVe?'));
        
        fprintf(scope, 'DATA:SOUrce CH2');
        pause(0.2);
        fprintf(y_file, query(scope, 'CURVe?'));
        
        pause(0.6);
    end

    disp("Finished.")
end