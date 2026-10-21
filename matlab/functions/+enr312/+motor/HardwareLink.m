classdef HardwareLink < enr312.io.SerialLink
%HARDWARELINK  Serial link to the DC-motor Arduino ($TEL telemetry).
%   link = enr312.motor.HardwareLink(); link.open(port); link.configure(c); ...
%   See enr312.io.SerialLink for everything else.
    methods
        function obj = HardwareLink()
            obj@enr312.io.SerialLink('TEL');
        end

        function configure(obj, c)
            %CONFIGURE  $CFG from an enr312.motor config (loop, controller, gains, Ts, limit).
            %   speed loop: c.spdFb 'drive' -> S (drive speed register), 'encoder' -> E (counts / Ts)
            loops = struct('speed', 'S', 'position', 'P');
            L = loops.(c.loop);
            if strcmp(c.loop, 'speed') && isfield(c, 'spdFb') && strcmp(c.spdFb, 'encoder'), L = 'E'; end
            obj.send('CFG', L, c.ctrl, c.Kp, c.Ki, c.Kd, ...
                     round(1000 * c.Tf), round(1000 * c.Ts), c.uMax);
        end
    end
end
