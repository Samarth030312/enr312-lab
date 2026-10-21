function app = MotorControlApp()
%MOTORCONTROLAPP  ENR312 DC-motor lab: speed and position control, P / I / PI.
%
%   run('<repo>/matlab/setup_enr312.m'); MotorControlApp
%
%   Move any control and every plot updates immediately. RUN replays the run
%   in real time with the motor animated; tick "Record video" first to save
%   an MP4 of the window plus the full run evidence.
%
%   TWO PLANTS (docs/knowledge-base/ENGINEERING_DECISIONS.md, ED-M1)
%     Lab rig     RMCS-2303 in digital speed mode + RMCS-5032. The Arduino runs
%                 the P / I / PI loop and talks to the drive over Modbus at
%                 9600 baud, so the loop is slow (Ts ~ 0.1 s) and delayed.
%     Bare motor  The same motor on a voltage drive: the course week-4 / CTMS
%                 model. Not the lab hardware.
%
%   HARDWARE mode talks to the Arduino with the protocol in
%   docs/architecture/SERIAL_PROTOCOL.md. The firmware does not exist yet, so
%   that path is UNTESTED against a real board.
%
%   Returns a struct of handles so a script can drive it (motor_formal_runs.m).
%   Base MATLAB only (no toolbox).

    % ================================================================ state
    C = colors();
    S = [];  busy = false;  lastVideo = '';
    link = enr312.motor.HardwareLink();
    hwTimer = [];  hwCfg = [];  hwSim = [];  runner = [];  nErrSeen = 0;
    currentExperiment = '';

    % ================================================================ layout
    fig = uifigure('Name', 'ENR312 DC Motor Lab', 'Position', [40 30 1720 980], ...
                   'Color', C.bg, 'CloseRequestFcn', @(~, ~) onClose());
    if exist('theme', 'file'), theme(fig, 'light'); end
    g = uigridlayout(fig, [3 3], 'RowHeight', {64, '1x', 250}, ...
        'ColumnWidth', {370, '1x', '1.25x'}, 'Padding', [10 10 10 10], ...
        'RowSpacing', 8, 'ColumnSpacing', 10, 'BackgroundColor', C.bg);

    hg = uigridlayout(g, [1 2], 'ColumnWidth', {'1x', 330}, 'Padding', [0 0 0 0], ...
                      'ColumnSpacing', 0, 'BackgroundColor', C.navy);
    hg.Layout.Row = 1; hg.Layout.Column = [1 3];
    uilabel(hg, 'BackgroundColor', C.navy, 'FontColor', 'w', 'FontSize', 22, 'FontWeight', 'bold', ...
        'Text', ['   ENR312  ' char(183) '  DC motor lab  ' char(183) '  speed and position, P / I / PI' ...
                 '        RMCS-2303 ' char(183) ' RMCS-5032 ' char(183) ' Arduino Uno']);
    ui.srcBadge = uilabel(hg, 'FontColor', 'w', 'FontSize', 15, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center');

    % ---------------------------------------------------------- controls
    cp = uipanel(g, 'Title', 'Controls', 'FontWeight', 'bold', 'FontSize', 14, ...
                 'BackgroundColor', 'w', 'Scrollable', 'on');
    cp.Layout.Row = [2 3]; cp.Layout.Column = 1;
    cg = uigridlayout(cp, [70 2], 'ColumnWidth', {'1x', 110}, 'RowSpacing', 2, ...
                      'Padding', [10 6 10 6], 'BackgroundColor', 'w', 'Scrollable', 'on');
    cg.RowHeight = repmat({0}, 1, 70);
    row = 0;

    section('Data source');
    ui.source = uidropdown(cg, 'Items', {'Simulation (model)', 'Hardware (Arduino + RMCS-2303)'}, ...
        'ItemsData', {'sim', 'hw'}, 'FontSize', 13, 'ValueChangedFcn', @(~, ~) onSource());
    place(ui.source, nextRow(28), [1 2]);

    section('Experiment');
    pr = enr312.motor.presets();
    ui.preset = uidropdown(cg, 'Items', [{'(custom)'}, {pr.name}], 'FontSize', 12, ...
        'ValueChangedFcn', @(~, ~) applyPreset());
    place(ui.preset, nextRow(28), [1 2]);
    ui.plant = uidropdown(cg, 'Items', {'Lab rig: RMCS-2303 speed mode + Arduino loop', ...
        'Bare motor: voltage drive (course week 4)'}, 'ItemsData', {'rig', 'bare'}, ...
        'ValueChangedFcn', @(~, ~) onStructure());
    place(ui.plant, nextRow(26), [1 2]);
    lab('Loop', nextRow(26), 1);
    ui.loop = uidropdown(cg, 'Items', {'Speed', 'Position'}, 'ItemsData', {'speed', 'position'}, ...
        'ValueChangedFcn', @(~, ~) onStructure());
    place(ui.loop, row, 2);
    lab('Controller', nextRow(26), 1);
    ui.ctrl = uidropdown(cg, 'Items', {'Open loop', 'P', 'I', 'PI', 'PID'}, ...
        'ItemsData', {'OL', 'P', 'I', 'PI', 'PID'}, 'Value', 'PI', 'ValueChangedFcn', @(~, ~) changed());
    place(ui.ctrl, row, 2);
    ui.run = uibutton(cg, 'Text', char(9654) + "  RUN", 'FontSize', 16, 'FontWeight', 'bold', ...
        'BackgroundColor', C.green, 'FontColor', 'w', 'ButtonPushedFcn', @(~, ~) animate());
    place(ui.run, nextRow(40), [1 2]);
    lab('Playback speed', nextRow(24), 1);
    ui.speed = uidropdown(cg, 'Items', {'0.25x', '0.5x', '1x', '2x'}, 'Value', '1x');
    place(ui.speed, row, 2);
    ui.record = uicheckbox(cg, 'Text', 'Record video of RUN + save evidence', 'Value', false);
    place(ui.record, nextRow(22), [1 2]);
    ui.export = uibutton(cg, 'Text', 'Export run  (CSV + JSON + PNG)', 'ButtonPushedFcn', @(~, ~) exportNow());
    place(ui.export, nextRow(30), [1 2]);

    section('Setpoint and load disturbance');
    ui.sp    = slider('Setpoint', [0 180], 100, '%.0f');
    ui.dist  = slider('Load torque step at output (N*m)', [0 1.5], 0, '%.2f');
    ui.tDist = slider('Load applied at t (s)', [0.5 11], 3, '%.1f');
    lab('Run length', nextRow(24), 1);
    ui.Tend = uidropdown(cg, 'Items', {'3 s', '5 s', '8 s', '12 s', '30 s', 'Until Stop (hardware)'}, 'Value', '5 s', ...
        'ValueChangedFcn', @(~, ~) changed());
    place(ui.Tend, row, 2);

    ui.gainHdr = section('Controller gains');
    ui.Kp = slider('Kp', [0 2], 0.4, '%.3f');
    ui.Ki = slider('Ki', [0 10], 3, '%.3f');
    ui.Kd = slider('Kd', [0 0.5], 0, '%.4f');

    section('Arduino loop timing');
    lab('Sample time Ts', nextRow(24), 1);
    ui.Ts = uidropdown(cg, 'Items', {'10 ms', '20 ms', '50 ms', '100 ms', '150 ms', '200 ms', '300 ms'}, ...
        'ItemsData', {0.01, 0.02, 0.05, 0.10, 0.15, 0.20, 0.30}, 'Value', 0.10, ...
        'ValueChangedFcn', @(~, ~) changed());
    place(ui.Ts, row, 2);
    ui.lat = slider('Command latency (ms, <= Ts)', [0 300], 70, '%.0f');
    ui.quant = uicheckbox(cg, 'Text', 'Encoder / integer-rpm quantisation', 'Value', true, ...
        'ValueChangedFcn', @(~, ~) changed());
    place(ui.quant, nextRow(22), [1 2]);

    section('Motor and drive  (ESTIMATED until MOTOR-02)');
    P0 = enr312.motor.params();
    ui.J   = slider('Rotor inertia J (x1e-6 kg*m^2)', [0.2 5], P0.J * 1e6, '%.2f');
    ui.R   = slider('Armature resistance R (ohm)', [0.5 4], P0.R, '%.2f');
    ui.wc  = slider('Drive speed-loop bandwidth (rad/s)', [10 150], P0.wc_drive, '%.0f');
    ui.acc = slider('Drive acceleration (base rpm/s)', [2000 60000], P0.acc_base_rpm_s, '%.0f');
    lab('Supply voltage', nextRow(24), 1);
    ui.Vs = uidropdown(cg, 'Items', {'12 V', '24 V'}, 'ItemsData', {12, 24}, 'Value', 12, ...
        'ValueChangedFcn', @(~, ~) changed());
    place(ui.Vs, row, 2);
    ui.reset = uibutton(cg, 'Text', 'Reset physics to datasheet estimates', 'ButtonPushedFcn', @(~, ~) resetPhysics());
    place(ui.reset, nextRow(30), [1 2]);

    section('Hardware link  (protocol v1)');
    ui.port = uidropdown(cg, 'Items', {'(no ports)'});
    place(ui.port, nextRow(26), 1);
    ui.refresh = uibutton(cg, 'Text', 'Refresh', 'ButtonPushedFcn', @(~, ~) refreshPorts());
    place(ui.refresh, row, 2);
    ui.connect = uibutton(cg, 'Text', 'Connect', 'ButtonPushedFcn', @(~, ~) onConnect());
    place(ui.connect, nextRow(30), 1);
    ui.start = uibutton(cg, 'Text', char(9654) + " Start", 'BackgroundColor', C.green, ...
        'FontColor', 'w', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) hwStart());
    place(ui.start, row, 2);
    ui.stop = uibutton(cg, 'Text', char(9632) + " Stop (power off)", 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(~, ~) hwStop(false));
    place(ui.stop, nextRow(30), 1);
    ui.estop = uibutton(cg, 'Text', 'E-STOP', 'BackgroundColor', C.red, 'FontColor', 'w', ...
        'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) hwStop(true));
    place(ui.estop, row, 2);
    ui.diag = uibutton(cg, 'Text', 'Drive check', 'ButtonPushedFcn', @(~, ~) hwDiag());
    place(ui.diag, nextRow(30), 1);
    ui.clearEstop = uibutton(cg, 'Text', 'Clear E-STOP', 'ButtonPushedFcn', @(~, ~) hwClearEstop());
    place(ui.clearEstop, row, 2);
    ui.liveHint = uilabel(cg, 'WordWrap', 'on', 'FontSize', 11, 'FontColor', C.blue, 'Text', ...
        ['LIVE: during a hardware run, move the Setpoint slider to change the speed (rpm, negative = reverse) ' ...
         'or angle immediately. Choose Run length "Until Stop" to drive it freely.']);
    place(ui.liveHint, nextRow(44), [1 2]);

    section('Hardware experiments  (automatic, each run saved)');
    hwE = enr312.motor.hwExperiments();
    ui.hwExp = uidropdown(cg, 'Items', strcat({hwE.id}, {'  '}, {hwE.name}), 'ItemsData', 1:numel(hwE), ...
        'FontSize', 11, 'ValueChangedFcn', @(~, ~) showExpInfo());
    place(ui.hwExp, nextRow(26), [1 2]);
    ui.hwExpInfo = uilabel(cg, 'WordWrap', 'on', 'FontSize', 11, 'VerticalAlignment', 'top', 'Text', '');
    place(ui.hwExpInfo, nextRow(62), [1 2]);
    ui.hwExpRun = uibutton(cg, 'Text', char(9654) + " Run experiment", 'BackgroundColor', C.blue, ...
        'FontColor', 'w', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) hwRunExperiment());
    place(ui.hwExpRun, nextRow(32), [1 2]);
    ui.hwStatus = uilabel(cg, 'Text', 'Not connected.', 'WordWrap', 'on', 'FontSize', 11, ...
        'FontColor', [0.35 0.35 0.35], 'VerticalAlignment', 'top');
    place(ui.hwStatus, nextRow(150), [1 2]);

    % ---------------------------------------------------------- centre: rig view
    rp = uipanel(g, 'BackgroundColor', 'w', 'BorderType', 'none');
    rp.Layout.Row = 2; rp.Layout.Column = 2;
    rg = uigridlayout(rp, [3 1], 'RowHeight', {36, 56, '1x'}, 'Padding', [0 0 0 0], ...
                      'RowSpacing', 2, 'BackgroundColor', 'w');
    ui.badge = uilabel(rg, 'Text', '', 'FontSize', 16, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'FontColor', 'w');
    ui.caption = uilabel(rg, 'FontSize', 14, 'WordWrap', 'on', 'HorizontalAlignment', 'center', ...
        'FontColor', C.navy, 'BackgroundColor', [0.91 0.94 0.99]);
    axV = uiaxes(rg); axV.Layout.Row = 3;
    view2 = buildView(axV, C);

    % ---------------------------------------------------------- right: plots
    pg = uigridlayout(g, [3 2], 'RowHeight', {'1.3x', '1x', '1x'}, 'ColumnWidth', {'1x', '1x'}, ...
        'Padding', [0 0 0 0], 'RowSpacing', 4, 'ColumnSpacing', 6, 'BackgroundColor', C.bg);
    pg.Layout.Row = 2; pg.Layout.Column = 3;
    ax.y = uiaxes(pg); ax.y.Layout.Row = 1; ax.y.Layout.Column = [1 2];
    ax.e = uiaxes(pg); ax.e.Layout.Row = 2; ax.e.Layout.Column = 1;
    ax.u = uiaxes(pg); ax.u.Layout.Row = 2; ax.u.Layout.Column = 2;
    ax.i = uiaxes(pg); ax.i.Layout.Row = 3; ax.i.Layout.Column = 1;
    ax.o = uiaxes(pg); ax.o.Layout.Row = 3; ax.o.Layout.Column = 2;
    tr = buildTraces(ax, C);

    ui.res = uilabel(g, 'Interpreter', 'html', 'VerticalAlignment', 'top', ...
        'BackgroundColor', 'w', 'FontSize', 13, 'WordWrap', 'on');
    ui.res.Layout.Row = 3; ui.res.Layout.Column = 2;
    ui.lim = uilabel(g, 'Interpreter', 'html', 'VerticalAlignment', 'top', 'WordWrap', 'on', ...
        'BackgroundColor', [1.0 0.97 0.88], 'FontSize', 12);
    ui.lim.Layout.Row = 3; ui.lim.Layout.Column = 3;
    ui.serial = uitextarea(g, 'Editable', 'off', 'FontName', 'monospaced', 'FontSize', 11, ...
        'Visible', 'off', 'BackgroundColor', [0.10 0.12 0.15], 'FontColor', [0.75 0.95 0.75], ...
        'Value', {'Serial monitor: not connected.'});
    ui.serial.Layout.Row = 3; ui.serial.Layout.Column = 3;

    knownPorts = {}; flashing = false; serialTic = tic; asking = false;
    showExpInfo();
    refreshPorts();
    setPreset('Rig - speed - PI, Kp 0.3 Ki 1.5');
    onSource();
    % Watch for an Arduino being plugged in / unplugged (1 s), and keep the serial
    % monitor live while connected but idle. A dialog offers to flash and connect.
    watchTimer = timer('ExecutionMode', 'fixedSpacing', 'Period', 1, 'BusyMode', 'drop', ...
        'TimerFcn', @(~, ~) watchTick(), 'ErrorFcn', @(~, e) hwSay(['port watcher: ' e.Data.message]));
    start(watchTimer);
    addlistener(fig, 'ObjectBeingDestroyed', @(~, ~) killWatch());   % never outlives the window

    app = struct('fig', fig, 'ui', ui, 'set', @setParam, 'preset', @setPreset, ...
                 'run', @animate, 'result', @() S, 'export', @exportNow, ...
                 'lastVideo', @() lastVideo, 'caption', @(txt) set(ui.caption, 'Text', txt));

    % ================================================================ nested: layout helpers
    function r = nextRow(h)
        row = row + 1; cg.RowHeight{row} = h; r = row;
    end

    function h = section(txt)
        h = uilabel(cg, 'Text', txt, 'FontWeight', 'bold', 'FontSize', 13, ...
                    'FontColor', C.navy, 'VerticalAlignment', 'bottom');
        place(h, nextRow(30), [1 2]);
    end

    function l = lab(txt, r, c)
        l = uilabel(cg, 'Text', txt, 'FontSize', 12);
        place(l, r, c);
    end

    function s = slider(txt, lims, val, fmt)
        l = lab(txt, nextRow(20), 1);
        v = uilabel(cg, 'Text', sprintf(fmt, val), 'FontWeight', 'bold', ...
                    'HorizontalAlignment', 'right', 'FontColor', C.blue);
        place(v, row, 2);
        s = uislider(cg, 'Limits', lims, 'Value', val, 'MajorTicks', [], 'MinorTicks', []);
        place(s, nextRow(26), [1 2]);
        s.UserData = struct('valueLabel', v, 'fmt', fmt, 'label', l, 'base', txt);
        s.ValueChangingFcn = @(~, e) set(v, 'Text', sprintf(s.UserData.fmt, e.Value));
        s.ValueChangedFcn  = @(~, ~) changed();
    end

    function setSlider(s, val, lims, fmt)
        if nargin >= 3 && ~isempty(lims), s.Limits = lims; end
        if nargin >= 4, s.UserData.fmt = fmt; end
        s.Value = min(max(val, s.Limits(1)), s.Limits(2));
        s.UserData.valueLabel.Text = sprintf(s.UserData.fmt, s.Value);
    end

    % ================================================================ nested: parameters
    function setParam(name, val)
        c = ui.(name);
        if isa(c, 'matlab.ui.control.Slider'), setSlider(c, val); else, c.Value = val; end
        if any(strcmp(name, {'plant', 'loop'})), onStructure(); else, changed(); end
    end

    function setPreset(name)
        ui.preset.Value = name; applyPreset();
    end

    function applyPreset()
        if strcmp(ui.preset.Value, '(custom)'), return; end
        c = enr312.motor.presetConfig(ui.preset.Value);
        currentExperiment = c.experiment;
        ui.plant.Value = c.plant; ui.loop.Value = c.loop;
        structureRanges(c);
        ui.ctrl.Value = c.ctrl;
        setSlider(ui.Kp, c.Kp); setSlider(ui.Ki, c.Ki); setSlider(ui.Kd, c.Kd);
        setSlider(ui.sp, c.setpoint); setSlider(ui.dist, c.dist); setSlider(ui.tDist, c.tDist);
        ui.Tend.Value = sprintf('%g s', c.Tend);
        if ~any(strcmp(ui.Tend.Items, ui.Tend.Value)), ui.Tend.Items{end + 1} = ui.Tend.Value; end
        ui.Ts.Value = c.Ts; setSlider(ui.lat, 1000 * c.latency);
        update();
    end

    function onStructure()
        % plant or loop changed by hand: load that combination's defaults
        c = enr312.motor.defaultConfig(ui.plant.Value, ui.loop.Value);
        structureRanges(c);
        setSlider(ui.Kp, c.Kp); setSlider(ui.Ki, c.Ki); setSlider(ui.Kd, c.Kd);
        setSlider(ui.sp, c.setpoint);
        ui.Ts.Value = c.Ts; setSlider(ui.lat, 1000 * c.latency);
        markCustom();
        update();
    end

    function structureRanges(c)
        rig = strcmp(c.plant, 'rig'); spd = strcmp(c.loop, 'speed');
        if spd
            setSlider(ui.sp, ui.sp.Value, [-150 150], '%.0f'); ui.sp.UserData.label.Text = 'Setpoint (output rpm; - = reverse)';
        else
            setSlider(ui.sp, ui.sp.Value, [-360 360], '%.0f'); ui.sp.UserData.label.Text = 'Setpoint (output deg)';
        end
        if rig && spd,      L = {[0 2], [0 10], [0 0.5]}; un = 'command rpm per rpm';
        elseif rig,         L = {[0 2], [0 1],  [0 0.5]}; un = 'command rpm per deg';
        elseif spd,         L = {[0 0.5], [0 5], [0 0.05]}; un = 'V per rpm';
        else,               L = {[0 1], [0 3],  [0 0.05]}; un = 'V per deg';
        end
        setSlider(ui.Kp, ui.Kp.Value, L{1}); setSlider(ui.Ki, ui.Ki.Value, L{2}); setSlider(ui.Kd, ui.Kd.Value, L{3});
        ui.gainHdr.Text = ['Controller gains  (' un ')'];
        ui.Kp.UserData.label.Text = 'Kp'; ui.Ki.UserData.label.Text = 'Ki  (per s)';
        ui.Kd.UserData.label.Text = 'Kd  (s)';
        on = {'off', 'on'};
        set([ui.wc ui.acc], 'Enable', on{rig + 1});
        set([ui.wc.UserData.label ui.acc.UserData.label], 'Enable', on{rig + 1});
        drawChain(view2, c.plant);
    end

    function markCustom()
        if ~strcmp(ui.preset.Value, '(custom)')
            ui.preset.Value = '(custom)';
        end
    end

    function changed()
        markCustom();
        update();
        if hwManualRunning()                             % live: new setpoint goes straight to the motor
            try
                link.setpoint(ui.sp.Value);
                un = 'deg'; if strcmp(hwCfg.loop, 'speed'), un = 'rpm'; end
                hwSay(sprintf('Live setpoint sent: %.0f %s', ui.sp.Value, un));
            catch err
                hwFault(err);
            end
        end
    end

    function tf = hwManualRunning()
        tf = link.isOpen() && ~isempty(hwTimer) && (isempty(runner) || ~runner.isActive());
    end

    function c = readConfig()
        c = enr312.motor.defaultConfig(ui.plant.Value, ui.loop.Value);
        c.experiment = currentExperiment;
        c.ctrl = ui.ctrl.Value;
        c.Kp = ui.Kp.Value; c.Ki = ui.Ki.Value; c.Kd = ui.Kd.Value;
        c.setpoint = ui.sp.Value; c.dist = ui.dist.Value; c.tDist = ui.tDist.Value;
        c.untilStop = startsWith(ui.Tend.Value, 'Until');
        if c.untilStop, c.Tend = 12; else, c.Tend = sscanf(ui.Tend.Value, '%f'); end
        c.Ts = ui.Ts.Value;
        c.latency = min(ui.lat.Value / 1000, c.Ts);
        c.latency = round(c.latency / c.dt) * c.dt;
        c.quant = ui.quant.Value;
        c.P.J = ui.J.Value * 1e-6; c.P.meta.J.status = statusIfMoved(P0.J, c.P.J, 'J');
        c.P.R = ui.R.Value;        c.P.meta.R.status = statusIfMoved(P0.R, c.P.R, 'R');
        c.P.wc_drive = ui.wc.Value;
        c.P.acc_base_rpm_s = ui.acc.Value;
        c.P.V_supply = ui.Vs.Value;
        c.preset = ui.preset.Value;
    end

    function s = statusIfMoved(v0, v, name)
        if abs(v - v0) > 1e-12 * max(1, abs(v0)), s = 'USER_OVERRIDE (ESTIMATED)';
        else, s = P0.meta.(name).status; end
    end

    function resetPhysics()
        setSlider(ui.J, P0.J * 1e6); setSlider(ui.R, P0.R);
        setSlider(ui.wc, P0.wc_drive); setSlider(ui.acc, P0.acc_base_rpm_s);
        ui.Vs.Value = 12;
        changed();
    end

    % ================================================================ nested: simulate + show
    function update()
        if busy, return; end
        c = readConfig();
        S = enr312.motor.simulate(c);
        if strcmp(ui.source.Value, 'sim')
            showTraces(tr, S, numel(S.t));
            poseView(view2, S, lastValid(S));
            showResults(S);
        else
            hwSim = S;                              % prediction overlaid on live data
            showPrediction(tr, S);
        end
        ui.lim.Text = limitsText(c);
    end

    function animate()
        if busy || ~strcmp(ui.source.Value, 'sim'), return; end
        busy = true; ui.run.Enable = 'off'; ui.run.Text = 'running...';
        cleanup = onCleanup(@() finishRun());
        rec = ui.record.Value;
        n = lastValid(S); dt = S.cfg.dt;
        if rec
            frameDt = 1 / 15; stride = max(1, round(frameDt / dt));
            vidDir = fullfile(tempdir, 'enr312_rec'); if ~exist(vidDir, 'dir'), mkdir(vidDir); end
            aviFile = fullfile(vidDir, 'simulation.avi');
            vw = VideoWriter(aviFile, 'Motion JPEG AVI'); vw.FrameRate = 15; vw.Quality = 92;
            open(vw); vwClean = onCleanup(@() close(vw));
            ui.caption.Text = 'RECORDING: the run is captured frame by frame (slower than real time).';
        else
            stride = max(1, round(0.025 / dt));       % ~40 frames per sim-second
        end
        sp = sscanf(ui.speed.Value, '%f');
        showTraces(tr, S, 1); t0 = tic;
        for k = 1:stride:n
            if ~isvalid(fig), return; end
            if ~rec, while toc(t0) * sp < S.t(k), end, end
            showTraces(tr, S, k); poseView(view2, S, k);
            if rec
                drawnow; writeVideo(vw, getframe(fig));
            else
                drawnow limitrate;
            end
        end
        showTraces(tr, S, n); poseView(view2, S, n); drawnow;
        if rec
            writeVideo(vw, getframe(fig)); clear vwClean;
            out = exportNow();
            mp4 = fullfile(out.dir, 'simulation.mp4');
            [st, msg] = system(sprintf('ffmpeg -y -loglevel error -i "%s" -c:v libx264 -pix_fmt yuv420p -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" "%s"', aviFile, mp4));
            if st == 0 && exist(mp4, 'file')
                lastVideo = mp4; delete(aviFile);
            else
                lastVideo = fullfile(out.dir, 'simulation.avi'); movefile(aviFile, lastVideo);
                warning('enr312:app:ffmpeg', 'ffmpeg conversion failed, kept AVI: %s', msg);
            end
            noteVideo(out.dir, lastVideo);
            ui.caption.Text = sprintf('Recorded: %s', strrep(lastVideo, [enr312.repoRoot() filesep], ''));
        end
    end

    function finishRun()
        busy = false;
        if isvalid(fig), ui.run.Enable = 'on'; ui.run.Text = char(9654) + "  RUN"; end
    end

    function out = exportNow()
        if strcmp(ui.source.Value, 'hw')
            out = hwExport(); return;
        end
        out = enr312.motor.exportRun(S, [], struct('preset', ui.preset.Value));
        exportgraphicsSafe(fullfile(out.dir, 'figure.png'));
        ui.caption.Text = sprintf('Exported %s', strrep(out.dir, [enr312.repoRoot() filesep], ''));
    end

    function exportgraphicsSafe(file)
        try
            exportapp(fig, file);
        catch err
            warning('enr312:app:export', 'figure not exported: %s', err.message);
        end
    end

    function showResults(S)
        m = S.metrics; c = S.cfg;
        switch m.verdict
            case 'SETTLED',      col = C.green;
            case {'NOT SETTLED', 'STEADY, OFFSET'}, col = C.amber;
            otherwise,           col = C.red;
        end
        ui.badge.Text = sprintf('%s   %s   %s-loop  %s', m.verdict, char(183), c.loop, ctrlName(c.ctrl));
        ui.badge.BackgroundColor = col;
        ui.caption.Text = captionFor(c, m);
        un = S.units.y; uu = S.units.u;
        th = theory(c);
        ui.res.Text = sprintf([ ...
            '<b style="font-size:15px">Results</b>&nbsp;&nbsp;<span style="color:#777">(%s, %s)</span><br>' ...
            '<table style="font-size:13px">' ...
            '<tr><td>Rise time 10-90 %%</td><td>&nbsp;&nbsp;<b>%s</b></td><td>&nbsp;&nbsp;Peak control</td><td>&nbsp;&nbsp;<b>%.3g</b> %s</td></tr>' ...
            '<tr><td>Overshoot</td><td>&nbsp;&nbsp;<b>%s</b></td><td>&nbsp;&nbsp;Time at the limit</td><td>&nbsp;&nbsp;<b>%.0f %%</b></td></tr>' ...
            '<tr><td>Settling (&plusmn;%.3g)</td><td>&nbsp;&nbsp;<b>%s</b></td><td>&nbsp;&nbsp;IAE</td><td>&nbsp;&nbsp;<b>%.3g</b></td></tr>' ...
            '<tr><td>Steady-state error</td><td>&nbsp;&nbsp;<b>%s</b></td><td>&nbsp;&nbsp;Theory</td><td>&nbsp;&nbsp;<b>%s</b></td></tr>' ...
            '<tr><td>Worst deviation after load&nbsp;&nbsp;</td><td>&nbsp;&nbsp;<b>%s</b></td><td>&nbsp;&nbsp;Error left under load&nbsp;&nbsp;</td><td>&nbsp;&nbsp;<b>%s</b></td></tr>' ...
            '</table><span style="color:#555">%s</span>'], ...
            un, 'SIMULATION', secs(m.rise), m.peakU, uu, pct(m.over), 100 * m.satFrac, ...
            m.band, secs(m.settle), m.iae, essTxt(m), th.ess, num(m.distPeak), num(m.distFinal), th.note);
    end

    % ================================================================ nested: hardware
    function onSource()
        hw = strcmp(ui.source.Value, 'hw');
        on = {'off', 'on'};
        set([ui.connect ui.start ui.stop ui.estop ui.port ui.refresh ui.diag ui.clearEstop ui.hwExp ui.hwExpRun], 'Enable', on{hw + 1});
        set([ui.run ui.record], 'Enable', on{~hw + 1});
        ui.serial.Visible = hw; ui.lim.Visible = ~hw;
        if hw
            ui.srcBadge.Text = 'HARDWARE  -  live data'; ui.srcBadge.BackgroundColor = C.red;
            ui.badge.Text = 'HARDWARE MODE  -  connect, then Start'; ui.badge.BackgroundColor = C.navy;
            ui.caption.Text = ['Grey dashed = simulation prediction for these settings. Solid = measured. ' ...
                               'Stop and E-STOP both switch motor power off (holding is disabled until encoder polarity is verified).'];
            clearTraces(tr);
        else
            ui.srcBadge.Text = 'SIMULATION  -  model, not measured'; ui.srcBadge.BackgroundColor = C.blue;
            hwStopTimer();
        end
        update();
    end

    function refreshPorts()
        try
            p = cellstr(serialportlist("available"));
        catch
            p = {};
        end
        cur = ui.port.Value;
        if link.isOpen(), cur = char(link.port); end       % never drop the port in use
        if ~isempty(cur) && ~strcmp(cur, '(no ports)') && ~any(strcmp(p, cur)), p{end + 1} = cur; end
        if isempty(p), p = {'(no ports)'}; end
        ui.port.Items = p;
        if any(strcmp(p, cur)), ui.port.Value = cur; end
    end

    function onConnect()
        try
            if link.isOpen()
                hwStopTimer(); link.close(); ui.connect.Text = 'Connect';
                hwSay('Disconnected.'); return;
            end
            if strcmp(ui.port.Value, '(no ports)'), hwSay('No serial port. Plug in the Uno and press Refresh.'); return; end
            link.open(ui.port.Value);
            logDir = fullfile(enr312.repoRoot(), 'results', 'evidence', 'logs');
            if ~isempty(getenv('ENR312_LOG_DIR')), logDir = getenv('ENR312_LOG_DIR'); end   % tests
            if ~exist(logDir, 'dir'), mkdir(logDir); end
            link.startLog(fullfile(logDir, ['hw_session_' char(datetime('now', 'Format', 'yyyyMMdd-HHmmss')) '.log']));
            ui.connect.Text = 'Disconnect';
            hwSay(sprintf('Opened %s. The Uno resets on connect; waiting for $HELLO ...', ui.port.Value)); drawnow;
            if link.waitForHello(6)
                h = link.hello;
                if numel(h) >= 3 && ~strcmp(h{3}, '0')
                    msg = sprintf('Firmware %s rev %s\nRMCS-2303 drive answered: slave id %s\n\nNext: "Drive check", then a 20 rpm open-loop Start.', h{1}, h{2}, h{3});
                    hwSay(strrep(msg, newline, ' ')); icon = 'success';
                else
                    msg = sprintf(['Firmware %s rev %s is running, but NO DRIVE answered.\n\n' ...
                        'Switch on the 12 V supply and check D9->pin 2, D8<-pin 3, GND->pin 1. ' ...
                        'Then press "Drive check" (it searches again).'], h{1}, h{2});
                    hwSay(strrep(msg, newline, ' ')); icon = 'warning';
                end
                uialert(fig, msg, 'Hardware connected', 'Icon', icon);
            else
                msg = 'Port open but no $HELLO within 6 s. The ENR312 motor firmware is probably not on the board: unplug and replug, then choose "Flash firmware + connect".';
                hwSay(msg); uialert(fig, msg, 'No firmware reply', 'Icon', 'warning');
            end
            refreshSerial();
        catch err
            hwSay(['Connect failed: ' err.message]);
        end
    end

    function hwStart()
        if ~link.isOpen(), hwSay('Not connected.'); return; end
        try
            hwCfg = readConfig();
            nErrSeen = countErr(link.eventLog);
            if ~strcmp(hwCfg.plant, 'rig')
                hwSay('Hardware runs use the lab-rig plant. Switch Plant to "Lab rig".'); return;
            end
            link.configure(hwCfg); link.setpoint(hwCfg.setpoint); link.run();
            clearTraces(tr); showPrediction(tr, hwSim);
            hwStopTimer();
            hwTimer = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.1, 'BusyMode', 'drop', ...
                            'TimerFcn', @(~, ~) hwTick(), 'ErrorFcn', @(~, e) hwFault(e));
            start(hwTimer);
            ui.badge.Text = 'RUNNING ON HARDWARE'; ui.badge.BackgroundColor = C.red;
            hwSay('Running. Telemetry streaming.');
        catch err
            hwFault(err);
        end
    end

    function hwTick()
        if ~isvalid(fig) || ~link.isOpen(), hwStopTimer(); return; end
        link.poll();
        if link.n == 0, return; end
        T = link.table();
        showLive(tr, T, hwCfg);
        last = link.eventLog; msg = '';
        if ~isempty(last), msg = sprintf(' Last: %s %s', last{end, 2}, last{end, 3}); end
        fl = strjoin(enr312.protocol.flagNames(T.flags(end)), ' ');
        hwSay(sprintf('%d samples, %d invalid lines, %d seq gaps. Flags: %s.%s', ...
                      link.n, link.invalidCount, link.seqGaps, fl, msg));
        if toc(serialTic) > 0.5, refreshSerial(); end
        % firmware errors (runaway, Modbus loss, watchdog) -> popup, stop polling the run
        ev = link.eventLog; errIdx = [];
        if ~isempty(ev), errIdx = find(strcmp(ev(:, 2), 'ERR')); end
        if numel(errIdx) > nErrSeen
            txt = ev{errIdx(end), 3}; nErrSeen = numel(errIdx);
            if ~isempty(runner) && runner.isActive(), runner.abort(['firmware error: ' txt]); end
            hwStopTimer();
            ui.badge.Text = 'MOTOR STOPPED BY FIRMWARE'; ui.badge.BackgroundColor = C.red;
            uialert(fig, sprintf('The Arduino stopped the motor:\n\n%s\n\nMotor power is off. Fix the cause, then "Clear E-STOP" before the next Start.', ...
                strrep(txt, ',', ' ')), 'Motor stopped', 'Icon', 'error');
            return;
        end
        if ~isempty(runner)
            runner.tick();
            hwSay(runner.message);
            if ~runner.isActive()
                hwStopTimer(); r = runner; runner = [];
                if strcmp(r.state, 'done')
                    ui.badge.Text = 'EXPERIMENT COMPLETE'; ui.badge.BackgroundColor = C.green;
                    uialert(fig, [r.message ' Raw data: data/raw/dc_motor/.'], 'Experiment complete', 'Icon', 'success');
                else
                    ui.badge.Text = 'EXPERIMENT ABORTED'; ui.badge.BackgroundColor = C.amber;
                    uialert(fig, r.message, 'Experiment aborted', 'Icon', 'warning');
                end
            end
            return;
        end
        if ~hwCfg.untilStop && T.t_s(end) >= hwCfg.Tend, hwStop(false); end
    end

    function hwRunExperiment()
        if ~link.isOpen(), hwSay('Not connected.'); return; end
        if ~isempty(runner) && runner.isActive(), hwSay('An experiment is already running.'); return; end
        hwStopTimer();
        e = hwE(ui.hwExp.Value);
        nErrSeen = countErr(link.eventLog);
        runner = enr312.motor.ExperimentRunner(link, e, @onRunStart, @onRunDone);
        try
            runner.start();
        catch err
            runner = []; hwFault(err); return;
        end
        hwTimer = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.1, 'BusyMode', 'drop', ...
                        'TimerFcn', @(~, ~) hwTick(), 'ErrorFcn', @(~, ev) hwFault(ev));
        start(hwTimer);
        ui.badge.Text = ['EXPERIMENT  ' e.id]; ui.badge.BackgroundColor = C.red;
    end

    function onRunStart(c, k)
        c.untilStop = false; hwCfg = c;
        clearTraces(tr);
        if size(hwE(ui.hwExp.Value).runs(k).profile, 1) == 1      % single step: show the prediction
            hwSim = enr312.motor.simulate(c); showPrediction(tr, hwSim);
        end
    end

    function onRunDone(spec, T, k)
        if isempty(T) || height(T) == 0, return; end
        info = struct('port', char(link.port), 'invalidCount', link.invalidCount, 'seqGaps', link.seqGaps, ...
            'experiment', hwE(ui.hwExp.Value).name, 'run', k, 'profile', spec.profile);
        r = enr312.motor.exportHardwareRun(T, hwCfg, link.eventLog, info);
        exportgraphicsSafe(fullfile(fileparts(r.meta), [r.runId '.png']));
    end

    function showExpInfo()
        e = hwE(ui.hwExp.Value); n = numel(e.runs);
        d = sum([e.runs.duration]) + 1.5 * (n - 1);
        ui.hwExpInfo.Text = sprintf('%s  %d run(s), about %.0f s. Uses %s loop.', e.purpose, n, d, e.runs(1).loop);
    end

    function n = countErr(ev)
        n = 0; if ~isempty(ev), n = nnz(strcmp(ev(:, 2), 'ERR')); end
    end

    function hwClearEstop()
        if ~link.isOpen(), hwSay('Not connected.'); return; end
        try
            link.send('HOME'); pause(0.4); link.poll();
            hwSay('E-STOP latch cleared (HOME sent; position counter zeroed). Start is allowed again.');
            ui.badge.Text = 'READY'; ui.badge.BackgroundColor = C.navy;
        catch err
            hwSay(['Clear E-STOP failed: ' err.message]);
        end
    end

    function hwFault(err)
        msg = err.message;
        if isstruct(err) && isfield(err, 'Data'), msg = err.Data.message; end
        try
            link.stop();
        catch e2
            msg = [msg ' (STOP also failed: ' e2.message ' -- REMOVE POWER)'];
        end
        hwStopTimer();
        hwSay(['FAULT, STOP sent: ' msg]);
        ui.badge.Text = 'FAULT - motion stopped'; ui.badge.BackgroundColor = C.red;
    end

    function hwStop(emergency)
        % Stop must work even if the plot timer is stuck: send first, tidy after.
        if ~isempty(runner) && runner.isActive(), runner.abort('stopped by the operator'); end
        try
            if emergency, link.estop(); else, link.stop(); end
        catch err
            hwSay(['Stop command failed: ' err.message ' -- REMOVE POWER at the supply.']);
        end
        hwStopTimer();
        if link.isOpen(), link.poll(); end
        if emergency, ui.badge.Text = 'E-STOPPED (motor unpowered)'; else, ui.badge.Text = 'STOPPED (motor power off)'; end
        ui.badge.BackgroundColor = C.amber;
    end

    function hwStopTimer()
        if ~isempty(hwTimer) && isvalid(hwTimer)
            stop(hwTimer); delete(hwTimer);
        end
        hwTimer = [];
    end

    function out = hwExport()
        out = struct('dir', '');
        if link.n == 0, hwSay('Nothing to export: no telemetry received.'); return; end
        info = struct('port', char(link.port), 'invalidCount', link.invalidCount, 'seqGaps', link.seqGaps);
        ev = link.eventLog;
        r = enr312.motor.exportHardwareRun(link.table(), hwCfg, ev, info);
        exportgraphicsSafe(fullfile(fileparts(r.meta), [r.runId '.png']));
        out.dir = fileparts(r.csv);
        hwSay(sprintf('Saved raw data %s (read-only).', r.runId));
    end

    function hwDiag()
        if ~link.isOpen(), hwSay('Not connected.'); return; end
        n0 = size(link.eventLog, 1);
        link.send('DIAG');
        t0 = tic; while toc(t0) < 3, link.poll(); pause(0.05); end
        L = link.debugLines(n0);
        if isempty(L), hwSay('No reply to $DIAG. Is the motor firmware flashed?'); return; end
        hwSay(strjoin(strrep(L, '# ', ''), newline));
        refreshSerial();
    end

    function watchTick()
        if ~isvalid(fig) || flashing, return; end
        [p, names] = enr312.io.arduinoPorts();
        added = setdiff(p, knownPorts); removed = setdiff(knownPorts, p); knownPorts = p;
        if link.isOpen() && any(strcmp(removed, char(link.port)))
            hwStopTimer();
            try
                link.close();
            catch err                                  % the device node is already gone
                warning('enr312:app:unplug', 'closing the vanished port: %s', err.message);
            end
            ui.connect.Text = 'Connect'; refreshPorts();
            msg = 'The Arduino was unplugged. The firmware watchdog stops the drive within 1 s of losing MATLAB.';
            hwSay(msg); uialert(fig, msg, 'Hardware disconnected', 'Icon', 'warning');
        end
        if ~isempty(added) && ~link.isOpen() && ~asking
            port = added{1}; nm = names{strcmp(p, port)};
            refreshPorts(); ui.port.Value = port;
            asking = true;
            uiconfirm(fig, sprintf(['Arduino detected on %s\n%s\n\n' ...
                'Flash the ENR312 motor firmware and connect, or connect to the firmware already on the board?'], port, nm), ...
                'Hardware connected', 'Options', {'Flash firmware + connect', 'Connect', 'Not now'}, ...
                'DefaultOption', 1, 'CancelOption', 3, 'Icon', 'success', ...
                'CloseFcn', @(~, e) onPlugAnswer(e.SelectedOption, port));
        end
        if link.isOpen() && isempty(hwTimer)              % idle but connected: keep monitor live
            link.poll(); refreshSerial();
        end
    end

    function onPlugAnswer(opt, port)
        asking = false;
        switch opt
            case 'Flash firmware + connect', flashAndConnect(port);
            case 'Connect', connectTo(port);
        end
    end

    function connectTo(port)
        if ~strcmp(ui.source.Value, 'hw')                   % first contact: gentlest test
            setPreset('Rig - speed - open loop (drive only)');
            setSlider(ui.sp, 20); changed();
        end
        ui.source.Value = 'hw'; onSource();
        refreshPorts(); ui.port.Value = port;
        if ~link.isOpen(), onConnect(); end
    end

    function flashAndConnect(port)
        if link.isOpen(), hwStopTimer(); link.close(); ui.connect.Text = 'Connect'; end
        flashing = true;
        d = uiprogressdlg(fig, 'Title', 'Flashing the Arduino', 'Indeterminate', 'on', ...
            'Message', sprintf('Compiling and uploading dc_motor/firmware/motor_controller to %s (about 20 s) ...', port));
        cmd = sprintf('"%s" motor %s 2>&1', fullfile(enr312.repoRoot(), 'scripts', 'setup', 'upload'), port);
        [st, out] = system(cmd);
        close(d);
        logDir = fullfile(enr312.repoRoot(), 'results', 'evidence', 'logs');
        if ~exist(logDir, 'dir'), mkdir(logDir); end
        f = fullfile(logDir, ['flash_' char(datetime('now', 'Format', 'yyyyMMdd-HHmmss')) '.log']);
        fid = fopen(f, 'w'); fprintf(fid, '%s\n%s', cmd, out); fclose(fid);
        pause(1.5);                                     % the Uno resets after upload
        knownPorts = enr312.io.arduinoPorts();
        flashing = false;
        if st == 0
            hwSay('Firmware flashed. Connecting ...'); connectTo(port);
        else
            L = splitlines(strtrim(out)); L = L(max(1, end - 6):end);
            uialert(fig, sprintf('Upload failed (log: %s):\n\n%s', f, strjoin(L, newline)), 'Flash failed', 'Icon', 'error');
            hwSay('Flash failed; see the log in results/evidence/logs.');
        end
    end

    function killWatch()
        if isvalid(watchTimer), stop(watchTimer); delete(watchTimer); end
    end

    function refreshSerial()
        if ~isvalid(fig) || ~link.isOpen(), return; end
        L = link.rawTail; L = L(max(1, end - 60):end);
        [~, lf] = fileparts(link.logFile);
        ui.serial.Value = [{sprintf('SERIAL MONITOR  %s @ %d  (live; log %s)', link.port, link.Baud, lf)}; L];
        scroll(ui.serial, 'bottom');
        serialTic = tic;
    end

    function hwSay(txt)
        if isvalid(fig), ui.hwStatus.Text = txt; end
    end

    function onClose()
        try
            killWatch(); hwStopTimer(); link.close();
        catch err
            warning('enr312:app:close', 'closing the hardware link failed: %s', err.message);
        end
        delete(fig);
    end
end

% ======================================================================= view
function C = colors()
    C.bg = [0.96 0.97 0.99]; C.navy = [0.09 0.16 0.29]; C.blue = [0.16 0.38 0.78];
    C.red = [0.80 0.18 0.16]; C.green = [0.13 0.59 0.33]; C.amber = [0.85 0.52 0.05];
    C.purple = [0.45 0.25 0.65]; C.grey = [0.55 0.57 0.60]; C.teal = [0.05 0.55 0.60];
end

function v = buildView(ax, C)
%BUILDVIEW  Signal chain (top) + gear-motor side view and output-disc face view.
    hold(ax, 'on'); axis(ax, 'equal'); axis(ax, 'off');
    ax.Toolbar.Visible = 'off'; ax.Interactions = [];
    xlim(ax, [0 320]); ylim(ax, [-22 206]);
    % --- signal chain: four boxes, text filled in by drawChain
    xs = [4 86 168 250]; w = 66;
    for k = 1:4
        v.box(k) = rectangle(ax, 'Position', [xs(k) 162 w 40], 'Curvature', 0.12, ...
                             'FaceColor', [0.93 0.95 0.99], 'EdgeColor', C.navy, 'LineWidth', 1.2);
        v.boxTxt(k) = text(ax, xs(k) + w/2, 182, '', 'HorizontalAlignment', 'center', ...
                           'FontSize', 10, 'Color', C.navy, 'FontWeight', 'bold');
    end
    for k = 1:3
        x0 = xs(k) + w; x1 = xs(k + 1);
        plot(ax, [x0 x1 - 2], [188 188], '-', 'Color', C.navy, 'LineWidth', 1.4);
        plot(ax, x1 - 2, 188, '>', 'Color', C.navy, 'MarkerFaceColor', C.navy, 'MarkerSize', 5);
        v.fwdTxt(k) = text(ax, (x0 + x1)/2, 155, '', 'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', C.grey);
    end
    plot(ax, [283 283 119 119], [162 142 142 160], '-', 'Color', C.teal, 'LineWidth', 1.4);
    plot(ax, [201 201], [142 160], '-', 'Color', C.teal, 'LineWidth', 1.4);
    plot(ax, [119 201], [160 160], '^', 'Color', C.teal, 'MarkerFaceColor', C.teal, 'MarkerSize', 5);
    v.fbTxt = text(ax, 201, 135, '', 'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', C.teal);
    % --- gear-motor side view (mm-ish), encoder | motor can | gearbox | shaft
    y0 = 62;
    rectangle(ax, 'Position', [10 y0-13 15 26], 'FaceColor', [0.20 0.21 0.24], 'EdgeColor', 'none');
    rectangle(ax, 'Position', [25 y0-15 37 30], 'FaceColor', [0.62 0.64 0.67], 'EdgeColor', [0.4 0.4 0.4]);
    rectangle(ax, 'Position', [62 y0-16 32 32], 'FaceColor', [0.80 0.82 0.85], 'EdgeColor', [0.45 0.45 0.45]);
    for xg = 66:6:90, plot(ax, [xg xg], y0 + [-16 16], '-', 'Color', [0.68 0.70 0.73]); end
    rectangle(ax, 'Position', [94 y0-3 14 6], 'FaceColor', [0.85 0.86 0.88], 'EdgeColor', [0.4 0.4 0.4]);
    v.flat = plot(ax, [94 108], [y0 y0], '-', 'Color', [0.3 0.3 0.3], 'LineWidth', 2);
    v.y0 = y0;
    text(ax, 17, y0 - 24, {'encoder', '13 lines'}, 'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', C.grey);
    text(ax, 43, y0 - 24, {'motor', '12 V'}, 'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', C.grey);
    text(ax, 78, y0 - 24, {'planetary', '100 : 1'}, 'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', C.grey);
    v.baseTxt = text(ax, 58, y0 + 28, '', 'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', C.navy);
    v.curTxt  = text(ax, 58, y0 + 40, '', 'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', C.purple);
    plot(ax, [110 176], [y0 y0], ':', 'Color', C.grey);
    % --- output disc, face view
    cx = 232; cy = 62; R = 46;
    v.c = [cx cy]; v.R = R;
    th = linspace(0, 2*pi, 120);
    patch(ax, cx + R * cos(th), cy + R * sin(th), [0.97 0.97 0.98], 'EdgeColor', C.navy, 'LineWidth', 1.5);
    for a = 0:15:345
        L = 5 + 4 * (mod(a, 90) == 0);
        plot(ax, cx + [R - L, R] * sind(a), cy + [R - L, R] * cosd(a), '-', 'Color', C.navy, 'LineWidth', 1 + (mod(a, 90) == 0));
    end
    lbl = {'0', '90', '', '-90'};
    for k = [1 2 4]
        a = (k - 1) * 90;
        text(ax, cx + (R + 8) * sind(-a), cy + (R + 8) * cosd(-a), lbl{k}, 'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', C.grey);
    end
    v.trail = patch(ax, nan, nan, C.red, 'FaceAlpha', 0.15, 'EdgeColor', 'none');
    v.ref = plot(ax, [cx cx], [cy cy + R], '--', 'Color', C.green, 'LineWidth', 2.2);
    v.ptr = plot(ax, [cx cx], [cy cy + R - 4], '-', 'Color', C.red, 'LineWidth', 4);
    plot(ax, cx, cy, 'o', 'MarkerFaceColor', C.navy, 'MarkerEdgeColor', 'w', 'MarkerSize', 9);
    v.angTxt = text(ax, cx, cy - R - 9, '', 'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold', 'Color', C.red);
    v.spdTxt = text(ax, cx, cy - R - 20, '', 'HorizontalAlignment', 'center', 'FontSize', 11, 'Color', C.navy);
    v.load = text(ax, cx + R - 6, cy + R + 2, '', 'FontSize', 10, 'Color', C.amber, 'FontWeight', 'bold');
    v.tTxt = text(ax, 4, -14, '', 'FontSize', 10, 'Color', C.grey);
    text(ax, cx, cy + R + 20, 'output shaft, viewed from the shaft end (CCW +)', 'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', C.grey);
end

function drawChain(v, plant)
    if strcmp(plant, 'rig')
        t = {{'MATLAB', 'app'}, {'Arduino Uno', 'P / I / PI'}, {'RMCS-2303', 'Mode 1 speed'}, {'RMCS-5032', 'motor + 100:1'}};
        f = {'USB 115200', 'Modbus 9600', 'M+ / M-'};
        fb = 'encoder -> drive counts -> Modbus reads';
    else
        t = {{'MATLAB', 'app'}, {'Arduino', 'P / I / PI / PID'}, {'H-bridge', 'PWM volts'}, {'DC motor', '+ 100:1'}};
        f = {'USB', 'PWM', 'armature V'};
        fb = 'encoder -> microcontroller (not this lab''s wiring)';
    end
    for k = 1:4, v.boxTxt(k).String = t{k}; end
    for k = 1:3, v.fwdTxt(k).String = f{k}; end
    v.fbTxt.String = fb;
end

function poseView(v, S, k)
    c = S.cfg; th = S.th_deg(k); w = S.w_rpm(k);
    if abs(w) < 0.05, w = 0; end
    cx = v.c(1); cy = v.c(2); R = v.R;
    a = -th;                                         % CCW positive on screen
    v.ptr.XData = [cx, cx + (R - 4) * sind(a)]; v.ptr.YData = [cy, cy + (R - 4) * cosd(a)];
    k0 = max(1, k - round(0.08 / c.dt));             % motion trail over the last 80 ms
    a0 = -S.th_deg(k0);
    if abs(a - a0) > 0.5
        aa = linspace(a0, a, 24);
        v.trail.XData = [cx, cx + (R - 6) * sind(aa)]; v.trail.YData = [cy, cy + (R - 6) * cosd(aa)];
    else
        v.trail.XData = nan; v.trail.YData = nan;
    end
    if strcmp(c.loop, 'position')
        ar = -S.r(k);
        v.ref.XData = [cx, cx + R * sind(ar)]; v.ref.YData = [cy, cy + R * cosd(ar)];
        v.ref.Visible = 'on';
    else
        v.ref.Visible = 'off';
    end
    v.angTxt.String = sprintf('%.1f%s', mod(th + 180, 360) - 180, char(176));
    v.spdTxt.String = sprintf('%.1f rpm  (base %.0f rpm)', w, w * c.P.N);
    v.baseTxt.String = sprintf('base %.0f rpm', w * c.P.N);
    v.curTxt.String = sprintf('i = %.2f A', S.i(k));
    fa = deg2rad(th * c.P.N);                        % fake rotation of the shaft flat
    v.flat.YData = v.y0 + 2.5 * cos(fa) * [1 1];
    if c.dist ~= 0 && S.t(k) >= c.tDist
        v.load.String = sprintf('load %.2f N%sm', c.dist, char(183));
    else
        v.load.String = '';
    end
    v.tTxt.String = sprintf('t = %.2f s', S.t(k));
end

function tr = buildTraces(ax, C)
    for a = struct2cell(ax)'
        h = a{1}; hold(h, 'on'); grid(h, 'on'); h.FontSize = 11; h.Box = 'on';
        h.Toolbar.Visible = 'off';
    end
    tr.ax = ax;
    tr.pred = plot(ax.y, nan, nan, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1.4);
    tr.r  = plot(ax.y, nan, nan, '--', 'Color', C.green, 'LineWidth', 1.8);
    tr.y  = plot(ax.y, nan, nan, '-', 'Color', C.blue, 'LineWidth', 2.2);
    tr.ym = stairs(ax.y, nan, nan, '-', 'Color', C.amber, 'LineWidth', 1.0);
    tr.yDot = plot(ax.y, nan, nan, 'o', 'MarkerFaceColor', C.blue, 'MarkerEdgeColor', 'w', 'MarkerSize', 7);
    tr.dist = xline(ax.y, 0, ':', 'load', 'Color', C.amber, 'LineWidth', 1.5, 'Visible', 'off');
    legend(ax.y, [tr.r tr.y tr.ym tr.pred], {'setpoint', 'true output', 'what the controller sees', 'simulation prediction'}, ...
           'Location', 'southeast');
    tr.e = stairs(ax.e, nan, nan, '-', 'Color', C.red, 'LineWidth', 1.4);
    yline(ax.e, 0, '-', 'Color', [0.5 0.5 0.5]);
    title(ax.e, 'Error e = r - y_{measured}');
    tr.uLim = [yline(ax.u, 1, '--', 'Color', [0.5 0.5 0.5]), yline(ax.u, -1, '--', 'Color', [0.5 0.5 0.5])];
    tr.u = stairs(ax.u, nan, nan, '-', 'Color', C.purple, 'LineWidth', 1.4);
    tr.i = plot(ax.i, nan, nan, '-', 'Color', C.teal, 'LineWidth', 1.4);
    tr.iLim = [yline(ax.i, 3, '--', '3 A drive limit', 'Color', [0.5 0.5 0.5]), yline(ax.i, -3, '--', 'Color', [0.5 0.5 0.5])];
    title(ax.i, 'Armature current (A)'); xlabel(ax.i, 't (s)');
    tr.o = plot(ax.o, nan, nan, '-', 'Color', C.navy, 'LineWidth', 1.4);
    xlabel(ax.o, 't (s)');
end

function showTraces(tr, S, k)
    c = S.cfg; t = S.t(1:k);
    set(tr.r, 'XData', t, 'YData', S.r(1:k));
    set(tr.y, 'XData', t, 'YData', S.y(1:k));
    set(tr.yDot, 'XData', S.t(k), 'YData', S.y(k));
    j = S.tk <= S.t(k);
    set(tr.ym, 'XData', S.tk(j), 'YData', S.ym(j));
    set(tr.e, 'XData', S.tk(j), 'YData', S.e(j));
    set(tr.u, 'XData', t, 'YData', S.u(1:k));
    set(tr.i, 'XData', t, 'YData', S.i(1:k));
    set(tr.pred, 'XData', nan, 'YData', nan);
    if strcmp(c.loop, 'speed')
        set(tr.o, 'XData', t, 'YData', S.th_deg(1:k)); title(tr.ax.o, 'Output angle (deg)');
        title(tr.ax.y, 'Output speed (rpm)  -  SIMULATION');
    else
        set(tr.o, 'XData', t, 'YData', S.w_rpm(1:k)); title(tr.ax.o, 'Output speed (rpm)');
        title(tr.ax.y, 'Output angle (deg)  -  SIMULATION');
    end
    title(tr.ax.u, ['Control output u: ' S.units.u]);
    set(tr.uLim(1), 'Value', c.uMax); set(tr.uLim(2), 'Value', -c.uMax);
    set(tr.iLim, 'Visible', strcmp(c.plant, 'rig'));
    if c.dist ~= 0, tr.dist.Value = c.tDist; tr.dist.Visible = 'on'; else, tr.dist.Visible = 'off'; end
    v = isfinite(S.y);
    for a = struct2cell(tr.ax)', xlim(a{1}, [0 c.Tend]); end
    ylim(tr.ax.y, padLim([min([S.y(v); S.r; 0]) max([S.y(v); S.r; 0])], 1));
    ylim(tr.ax.e, padLim([min([S.e; 0]) max([S.e; 0])], 1));
    ylim(tr.ax.u, padLim([min([S.u(v); -0.05 * c.uMax]) max([S.u(v); 0.05 * c.uMax])], 0.1));
    ylim(tr.ax.i, padLim([min(S.i(v)) max(S.i(v))], 0.2));
    yo = get(tr.o, 'YData'); ylim(tr.ax.o, padLim([min([yo 0]) max([yo 0])], 1));
end

function showPrediction(tr, S)
    if isempty(S), return; end
    set(tr.pred, 'XData', S.t, 'YData', S.y);
    xlim(tr.ax.y, [0 S.cfg.Tend]);
end

function clearTraces(tr)
    for h = [tr.r tr.y tr.ym tr.yDot tr.e tr.u tr.i tr.o]
        set(h, 'XData', nan, 'YData', nan);
    end
    tr.dist.Visible = 'off';
end

function showLive(tr, T, c)
    set(tr.r, 'XData', T.t_s, 'YData', T.setpoint);
    set(tr.y, 'XData', T.t_s, 'YData', T.meas);
    set(tr.yDot, 'XData', T.t_s(end), 'YData', T.meas(end));
    set(tr.ym, 'XData', nan, 'YData', nan);
    set(tr.e, 'XData', T.t_s, 'YData', T.err);
    set(tr.u, 'XData', T.t_s, 'YData', T.u);
    set(tr.i, 'XData', nan, 'YData', nan); title(tr.ax.i, 'Current: not reported by the drive');
    if strcmp(c.loop, 'speed')
        set(tr.o, 'XData', T.t_s, 'YData', T.pos_counts * 360 / c.P.cpr_out); title(tr.ax.o, 'Output angle (deg)  -  MEASURED');
        title(tr.ax.y, 'Output speed (rpm)  -  MEASURED');
    else
        set(tr.o, 'XData', T.t_s, 'YData', T.spd_base_rpm / c.P.N); title(tr.ax.o, 'Output speed (rpm)  -  MEASURED');
        title(tr.ax.y, 'Output angle (deg)  -  MEASURED');
    end
    tEnd = max(c.Tend, T.t_s(end));
    for a = struct2cell(tr.ax)', xlim(a{1}, [0 tEnd]); end
    for a = {tr.ax.y, tr.ax.e, tr.ax.u, tr.ax.o}, ylim(a{1}, 'auto'); end
end

% ===================================================================== text
function n = lastValid(S)
    n = find(isfinite(S.y), 1, 'last');
end

function l = padLim(l, minSpan)
    if ~all(isfinite(l)), l = [-1 1]; end
    c = mean(l); h = max(diff(l) / 2 * 1.15, minSpan / 2);
    l = c + [-h h];
end

function s = ctrlName(c)
    names = struct('OL', 'open loop', 'P', 'P', 'I', 'I', 'PI', 'PI', 'PID', 'PID');
    s = names.(c);
end

function th = theory(c)
%THEORY  Closed-form predictions to check the simulation against.
    P = c.P; th.ess = '--'; th.note = '';
    Kss = P.Kt / (P.R * P.b + P.Kt * P.Ke) / P.rpm / P.N;      % bare: output rpm per volt
    spd = strcmp(c.loop, 'speed'); rig = strcmp(c.plant, 'rig');
    hasI = any(strcmp(c.ctrl, {'I', 'PI', 'PID'}));
    if strcmp(c.ctrl, 'OL')
        if spd, th.ess = '0 if the model is exact'; else, th.ess = 'depends on the ramp'; end
        th.note = 'Open loop: nothing corrects a wrong model, a load, or the drive''s acceleration ramp.';
    elseif spd && ~hasI
        K = c.Kp * (rig + ~rig * Kss);
        th.ess = sprintf('r/(1+K) = %.1f %%', 100 / (1 + K));
        if rig
            th.note = sprintf(['Speed P around a speed-controlled drive: loop gain K = Kp = %.2f. ' ...
                'Sampled with a one-step lag, it oscillates as Kp approaches 1, so P alone cannot get below ~50 %% error.'], c.Kp);
        else
            th.note = sprintf('Loop gain K = Kp x %.1f rpm/V = %.2f.', Kss, K);
        end
    elseif spd
        th.ess = '0 (integral action)';
        if rig, th.note = sprintf('Pure I is stable for Ki*Ts < 1 (here %.2f).', c.Ki * c.Ts); end
    elseif ~hasI
        th.ess = '0 for a step (plant integrates)';
        if rig
            th.note = sprintf(['Position P: discrete pole at 1 - 6*Ts*Kp = %.2f (stable while > -1). ' ...
                'Latency and the acceleration ramp make the real limit lower.'], 1 - 6 * c.Ts * c.Kp);
        else
            th.note = 'A constant load leaves a position error Kp must hold against; I removes it.';
        end
    else
        th.ess = '0';
        if strcmp(c.ctrl, 'I'), th.note = 'I alone on an integrating plant = two integrators: it oscillates.'; end
    end
end

function s = captionFor(c, m)
    rig = strcmp(c.plant, 'rig');
    switch [c.loop '-' c.ctrl]
        case 'speed-OL'
            if rig, s = 'Open loop: the Arduino just writes the speed register. The drive''s own loop does the work, so it looks good, until the model is wrong.';
            else,   s = 'Open loop on a bare motor: a fixed voltage. Add a load and watch the speed sag with nothing to correct it.'; end
        case 'speed-P'
            s = sprintf('P alone always leaves error. Here %.1f %%. Raise Kp: the error shrinks, then the loop starts to ring.', m.ess_pct);
        case 'speed-I'
            s = 'I alone removes the steady-state error, but it is slow to react. Push Ki up and it overshoots.';
        case {'speed-PI', 'speed-PID'}
            s = 'PI: P for a fast reaction, I to remove what P leaves behind. Apply a load and watch I pull the speed back.';
        case 'position-OL'
            s = 'Open-loop position: run at a fixed speed for a calculated time. The acceleration ramp alone makes it miss.';
        case 'position-P'
            if rig, s = 'Position P: the drive turns speed into angle (an integrator), so P alone reaches the target. Too much Kp and the slow Modbus loop overshoots.';
            else,   s = 'Position P on a bare motor reaches the target, but a load leaves an offset that only a larger Kp can shrink.'; end
        case 'position-I'
            s = 'I alone on position: two integrators in the loop. It oscillates, which is why nobody uses it.';
        otherwise
            s = 'PI / PID on position: I removes load offsets but adds overshoot and a slow tail.';
    end
    if strcmp(m.verdict, 'OSCILLATING') || strcmp(m.verdict, 'DIVERGED')
        s = ['UNSTABLE: ' s];
    end
end

function s = limitsText(c)
    rig = strcmp(c.plant, 'rig');
    s = ['<b style="font-size:14px">&#9888; Model limits: read before trusting a result</b><br>' ...
         '<b>Simulated as the Arduino will run it:</b> sample time Ts, command latency, ' ...
         'encoder counts (5200 / output rev), output clipping, anti-windup.<br><b>NOT simulated / NOT known:</b><br>'];
    if rig
        s = [s '&bull; <b>The RMCS-2303''s internal loop is undocumented.</b> It is modelled as a ramp + PI speed loop ' ...
             '(bandwidth and ramp units ESTIMATED, OI-M5). MOTOR-02 must identify it.<br>' ...
             '&bull; Modbus timing (Ts, latency) is a 9600-baud calculation, <b>not measured</b> (OI-M8).<br>' ...
             '&bull; Direction change costs an extra Modbus write; the model treats the command as signed.<br>'];
    else
        s = [s '&bull; <b>This is not the lab hardware.</b> It is the course week-4 voltage-driven motor, using RMCS-5032 numbers.<br>'];
    end
    s = [s '&bull; Motor R, K<sub>t</sub>, J, b are <b>ESTIMATED from the datasheet</b>, not measured (OI-M9).<br>' ...
         '&bull; No stiction or dead band, no gearbox backlash, no encoder noise, ideal current loop.<br>' ...
         '&bull; Direction sign on the real motor is UNVERIFIED (C-M3).'];
end

function s = secs(v), if isnan(v), s = 'not settled'; else, s = sprintf('%.2f s', v); end, end
function s = pct(v),  if isnan(v), s = '--'; else, s = sprintf('%.1f %%', v); end, end
function s = num(v),  if isnan(v), s = '--'; else, s = sprintf('%.3g', v); end, end
function s = essTxt(m), if isnan(m.ess), s = '--'; else, s = sprintf('%.3g (%.1f %%)', m.ess, m.ess_pct); end, end

function place(h, r, c)
    h.Layout.Row = r; h.Layout.Column = c;
end

function noteVideo(dirOut, video)
    f = fullfile(dirOut, 'run_config.json');
    meta = jsondecode(fileread(f));
    d = dir(video);
    meta.video = struct('file', d.name, 'bytes', d.bytes, ...
        'method', 'MATLAB getframe of the app window at 15 fps, converted with ffmpeg', ...
        'note', 'Frames are the app''s own rendering of the simulation, captured while it ran.');
    fid = fopen(f, 'w'); fprintf(fid, '%s\n', jsonencode(meta, 'PrettyPrint', true)); fclose(fid);
end
