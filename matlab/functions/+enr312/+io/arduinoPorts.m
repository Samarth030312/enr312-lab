function [ports, names] = arduinoPorts()
%ARDUINOPORTS  USB serial ports that can be an Arduino (Linux: /dev/ttyACM*, /dev/ttyUSB*; Windows: COMn).
%
%   [ports, names] = enr312.io.arduinoPorts()
%
%   ports  cellstr of device paths; names  matching description from /dev/serial/by-id
%   (e.g. 'usb-Arduino__www.arduino.cc__0043_...') or '' when none. Built-in ports such
%   as /dev/ttyS4 are excluded. Used by the apps to notice an Uno being plugged in.
    ports = {}; names = {};
    if ispc                                          % Windows: COM ports (no by-id names)
        try, ports = cellstr(serialportlist("all")); catch, ports = {}; end
        ports = ports(startsWith(ports, 'COM')); names = repmat({''}, size(ports));
        return
    end
    d = [dir('/dev/ttyACM*'); dir('/dev/ttyUSB*')];
    for k = 1:numel(d), ports{end + 1} = fullfile('/dev', d(k).name); end %#ok<AGROW>
    names = repmat({''}, size(ports));
    byid = dir('/dev/serial/by-id/*');
    for k = 1:numel(byid)
        [st, target] = system(sprintf('readlink -f "%s"', fullfile(byid(k).folder, byid(k).name)));
        if st == 0
            i = find(strcmp(ports, strtrim(target)), 1);
            if ~isempty(i), names{i} = byid(k).name; end
        end
    end
end
