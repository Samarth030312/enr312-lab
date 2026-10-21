function ok = e2e_motor_app_pty(simBinary)
%E2E_MOTOR_APP_PTY  End-to-end: MotorControlApp <-> real motor firmware code <-> emulated drive.
%
%   ok = e2e_motor_app_pty('/path/to/fwsim')      (needs a display)
%
%   The firmware (dc_motor/firmware/motor_controller) is compiled for the PC
%   (dc_motor/tests/firmware_host_test.cpp, --pty mode) and runs in real time on a
%   pseudo-terminal with an emulated RMCS-2303. The app is driven through its own
%   buttons: connect, Drive check, manual run with a LIVE setpoint change, E-STOP,
%   Clear E-STOP, and an automatic hardware experiment. Data and logs go to a
%   temporary folder. This tests everything except the physical wiring.
    tmp = tempname; mkdir(tmp);
    setenv('ENR312_DATA_ROOT', tmp); setenv('ENR312_LOG_DIR', tmp);
    ptyFile = fullfile(tmp, 'pty.txt');
    system(sprintf('"%s" --pty > "%s" 2>&1 & echo $! > "%s/sim.pid"', simBinary, ptyFile, tmp));
    cleanSim = onCleanup(@() system(sprintf('kill $(cat "%s/sim.pid") 2>/dev/null', tmp)));
    t0 = tic; pty = '';
    while isempty(pty) && toc(t0) < 5
        pause(0.2); txt = fileread(ptyFile); tok = regexp(txt, 'PTY (\S+)', 'tokens', 'once');
        if ~isempty(tok), pty = tok{1}; end
    end
    assert(~isempty(pty), 'simulator did not start');
    fprintf('emulated board on %s\n', pty);

    app = MotorControlApp(); cl = onCleanup(@() delete(app.fig)); ui = app.ui;
    press = @(b) feval(b.ButtonPushedFcn, b, []);
    ui.source.Value = 'hw'; feval(ui.source.ValueChangedFcn, ui.source, []);
    ui.port.Items = {pty}; ui.port.Value = pty;
    press(ui.connect); log = newestLog(tmp);
    fprintf('        status after connect: %s\n', ui.hwStatus.Text);
    ok = check(contains(ui.hwStatus.Text, 'slave id 7'), 'connect: HELLO received, drive at slave id 7');

    press(ui.diag);
    fprintf('        status after Drive check: %s\n', strrep(ui.hwStatus.Text, newline, ' | '));
    ok = check(contains(ui.hwStatus.Text, 'LPR = 13'), 'Drive check: register dump shows LPR = 13') & ok;

    % manual run, open loop, "Until Stop", live setpoint 20 -> 60 rpm
    app.preset('Rig - speed - open loop (drive only)');
    app.set('sp', 20);
    ui.Tend.Value = 'Until Stop (hardware)'; feval(ui.Tend.ValueChangedFcn, ui.Tend, []);
    press(ui.start); pause(3);
    app.set('sp', 60); pause(3.5);
    L = fileread(log);
    ok = check(contains(L, '> $SET,1,60'), 'live setpoint: slider change sent $SET,1,60 during the run') & ok;
    tel = regexp(L, '\$TEL,1,\d+,\d+,S,OL,60\.00,([-\d.]+),', 'tokens');
    meas = str2double(tel{end}{1});
    ok = check(abs(meas - 60) < 2, sprintf('motor follows the live setpoint: %.1f rpm measured', meas)) & ok;

    press(ui.estop); pause(0.5);
    ok = check(contains(fileread(log), '> $ESTOP,1'), 'E-STOP button sends $ESTOP') & ok;
    press(ui.start); pause(1);
    ok = check(contains(fileread(log), 'estopped'), 'Start refused while E-STOP is latched') & ok;
    press(ui.clearEstop); pause(0.5);

    % automatic experiment: direction and reversal (12 s), saved as raw data
    E = enr312.motor.hwExperiments();
    ui.hwExp.Value = find(strcmp({E.name}, 'Direction and reversal, open loop'));
    press(ui.hwExpRun); pause(16);
    raw = dir(fullfile(tmp, 'data', 'raw', 'dc_motor', 'MOTOR-02-HW-*.csv'));
    ok = check(numel(raw) == 1, sprintf('experiment saved raw data (%d file)', numel(raw))) & ok;
    if ~isempty(raw)
        T = readtable(fullfile(raw(1).folder, raw(1).name));
        ok = check(any(T.meas > 25) && any(T.meas < -25), 'experiment ran both directions (+30 / -30 rpm)') & ok;
        ok = check(~contains(fileread(log), 'runaway'), 'no false runaway trip during the reversal') & ok;
    end
    ok = check(contains(ui.badge.Text, 'COMPLETE'), ['experiment finished: ' ui.badge.Text]) & ok;
    fprintf('\nE2E %s (data and logs in %s)\n', string(ifthen(ok)), tmp);
end

function f = newestLog(d)
    l = dir(fullfile(d, 'hw_session_*.log')); [~, i] = max([l.datenum]); f = fullfile(d, l(i).name);
end

function ok = check(c, msg)
    ok = logical(c);
    if ok, fprintf('  ok    %s\n', msg); else, fprintf('  FAIL  %s\n', msg); end
end

function s = ifthen(ok)
    if ok, s = 'PASSED'; else, s = 'FAILED'; end
end

