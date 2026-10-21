classdef HardwarePanel < handle
%HARDWAREPANEL  Port / Connect / Start / Stop controls + polling timer for a LabWindow.
%
%   hp = enr312.ui.HardwarePanel(w, telType, @startFcn, @tickFcn, stopLabel)
%
%   startFcn(link)   send $CFG / $SET before RUN (the panel then sends RUN)
%   tickFcn(T)       called every 0.1 s with link.table() while data arrives
%   Stop sends STOP first and tidies afterwards, so it never waits on plotting.
%   The firmware stops its actuator if the host is silent for 1 s (PING every 0.25 s).

    properties
        link; port; connectBtn; startBtn; stopBtn; status
    end
    properties (Access = private)
        w; timerObj = []; startFcn; tickFcn
    end

    methods
        function hp = HardwarePanel(w, telType, startFcn, tickFcn, stopLabel)
            if nargin < 5, stopLabel = char(9632) + " Stop"; end
            hp.w = w; hp.startFcn = startFcn; hp.tickFcn = tickFcn;
            hp.link = enr312.io.SerialLink(telType);
            C = w.C; cg = w.cg;
            w.section(sprintf('Hardware link  (protocol v1, $%s)', telType));
            hp.port = uidropdown(cg, 'Items', {'(no ports)'});
            hp.port.Layout.Row = w.nextRow(26); hp.port.Layout.Column = 1;
            b = uibutton(cg, 'Text', 'Refresh', 'ButtonPushedFcn', @(~, ~) hp.refresh());
            b.Layout.Row = hp.port.Layout.Row; b.Layout.Column = 2;
            hp.connectBtn = uibutton(cg, 'Text', 'Connect', 'ButtonPushedFcn', @(~, ~) hp.connect());
            hp.connectBtn.Layout.Row = w.nextRow(30); hp.connectBtn.Layout.Column = 1;
            hp.startBtn = uibutton(cg, 'Text', char(9654) + " Start", 'BackgroundColor', C.green, ...
                'FontColor', 'w', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) hp.start());
            hp.startBtn.Layout.Row = hp.connectBtn.Layout.Row; hp.startBtn.Layout.Column = 2;
            hp.stopBtn = uibutton(cg, 'Text', stopLabel, 'BackgroundColor', C.red, 'FontColor', 'w', ...
                'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) hp.stop());
            hp.stopBtn.Layout.Row = w.nextRow(32); hp.stopBtn.Layout.Column = [1 2];
            hp.status = uilabel(cg, 'Text', 'Not connected.', 'WordWrap', 'on', 'FontSize', 11, ...
                'FontColor', [0.35 0.35 0.35], 'VerticalAlignment', 'top');
            hp.status.Layout.Row = w.nextRow(64); hp.status.Layout.Column = [1 2];
            hp.refresh();
        end

        function setEnabled(hp, on)
            v = matlab.lang.OnOffSwitchState(on);
            set([hp.port hp.connectBtn hp.startBtn hp.stopBtn], 'Enable', v);
        end

        function refresh(hp)
            try, p = cellstr(serialportlist("available")); catch, p = {}; end
            if isempty(p), p = {'(no ports)'}; end
            hp.port.Items = p;
        end

        function connect(hp)
            try
                if hp.link.isOpen()
                    hp.stopTimer(); hp.link.close(); hp.connectBtn.Text = 'Connect';
                    hp.say('Disconnected.'); return;
                end
                if strcmp(hp.port.Value, '(no ports)'), hp.say('No serial port: plug in the Uno, press Refresh.'); return; end
                hp.link.open(hp.port.Value); hp.link.send('PING');
                hp.connectBtn.Text = 'Disconnect';
                hp.say(sprintf('Opened %s. Waiting for $HELLO ...', hp.port.Value));
            catch err
                hp.say(['Connect failed: ' err.message]);
            end
        end

        function start(hp)
            if ~hp.link.isOpen(), hp.say('Not connected.'); return; end
            try
                hp.startFcn(hp.link);
                hp.link.run();
                hp.stopTimer();
                hp.timerObj = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.1, 'BusyMode', 'drop', ...
                    'TimerFcn', @(~, ~) hp.tick(), 'ErrorFcn', @(~, e) hp.fault(e.Data.message));
                start(hp.timerObj);
                hp.w.setVerdict('RUNNING ON HARDWARE', 'bad');
                hp.say('Running. Telemetry streaming.');
            catch err
                hp.fault(err.message);
            end
        end

        function stop(hp)
            try
                hp.link.stop();
            catch err
                hp.say(['STOP failed: ' err.message ' -- REMOVE POWER.']);
            end
            hp.stopTimer();
            if hp.link.isOpen(), hp.link.poll(); end
            hp.w.setVerdict('STOPPED', 'warn');
        end

        function close(hp)
            try
                hp.stopTimer(); hp.link.close();
            catch err
                warning('enr312:ui:close', 'closing the serial link failed: %s', err.message);
            end
        end
    end

    methods (Access = private)
        function tick(hp)
            if ~isvalid(hp.w.fig) || ~hp.link.isOpen(), hp.stopTimer(); return; end
            hp.link.poll();
            if hp.link.n == 0, return; end
            T = hp.link.table();
            hp.tickFcn(T);
            ev = hp.link.eventLog; last = '';
            if ~isempty(ev), last = sprintf(' Last: %s %s', ev{end, 2}, ev{end, 3}); end
            fl = strjoin(enr312.protocol.flagNames(T.flags(end), hp.link.telType), ' ');
            hp.say(sprintf('%d samples, %d invalid, %d seq gaps. Flags: %s.%s', ...
                hp.link.n, hp.link.invalidCount, hp.link.seqGaps, fl, last));
        end

        function fault(hp, msg)
            try
                hp.link.stop();
            catch e2
                msg = [msg ' (STOP also failed: ' e2.message ' -- REMOVE POWER)'];
            end
            hp.stopTimer();
            hp.say(['FAULT, STOP sent: ' msg]);
            hp.w.setVerdict('FAULT - stopped', 'bad');
        end

        function stopTimer(hp)
            if ~isempty(hp.timerObj) && isvalid(hp.timerObj), stop(hp.timerObj); delete(hp.timerObj); end
            hp.timerObj = [];
        end

        function say(hp, txt)
            if isvalid(hp.status), hp.status.Text = txt; end
        end
    end
end
