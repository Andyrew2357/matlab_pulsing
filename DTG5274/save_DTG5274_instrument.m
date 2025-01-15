% Create a variable
constructor = struct;
visa_address = 27;
visa_brand = 'ni';
adaptor = 'ni'; 


constructor.params = {'OutputBufferSize', 'EOSCharCode', 'EOIMode', 'EOSMode'};
constructor.vals = {[540], 'LF', 'on', 'none'};
constructor.args = {0, visa_address;};
constructor.adaptor = {adaptor;}; 
constructor.fn = @gpib;

inst = struct; 
inst.cntrlfn = @smcDTG5274;
inst.data = struct;
inst.datadim = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
inst.device = 'DTG5274';
inst.name = ''; 
inst.type = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
inst.channels = char(cellfun(@char, {'IDN', 'CAL', 'RUN', 'CLK_FREQ', 'MODE', 'P_POLARITY', 'P_LDELAY', 'P_WIDTH', 'P_HIGH', 'P_LOW', 'P_OFFSET', 'P_DCYCLE', 'P_RELRATE'}, 'UniformOutput', false));
inst.channels
filePath = 'C:\Users\graphene\Documents\MATLAB\special-measure\instruments\sminst_DTG5274.mat';
save(filePath, 'constructor', 'inst');