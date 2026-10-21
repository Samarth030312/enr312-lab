function app = TemperatureControlApp()
%TEMPERATURECONTROLAPP  ENR312 temperature lab: bulb heater, DHT sensor, SSR, LCD.
%
%   run('<repo>/matlab/setup_enr312.m'); TemperatureControlApp
%
%   Course tasks (SRC-001 p.17): on-off control at 35 / 45 / 55 C, moving average
%   with N = 10 and 500 at Ts = 0.01 s, P control with Kp = 1, 2, 50, 100, 500 on
%   PWM pin 9 (0..255), flicker and its reduction. Every change re-simulates;
%   RUN replays as a time-lapse; "Record video" saves an MP4 + evidence.
%
%   HARDWARE mode talks to temperature/firmware/temperature_controller ($TTEL).
%   Base MATLAB only.

    P0 = enr312.temperature.params();
    S = []; busy = false; currentExperiment = ''; lastVideo = ''; hwCfg = [];
    w = enr312.ui.LabWindow(['ENR312  ' char(183) '  Temperature control  ' char(183) ...
        '  bulb ' char(183) ' DHT22 ' char(183) ' SSR ' char(183) ' LCD ' char(183) ' Arduino Uno'], ...
        {{1, [1 2]}, {2, 1}, {2, 2}, {3, 1}, {3, 2}});
    C = w.C; fig = w.fig; fig.CloseRequestFcn = @(~, ~) onClose();
    ax = w.ax;

    % ------------------------------------------------------------ controls
    w.section('Data source');
    ui.source = w.dropdown('', {'Simulation (model)', 'Hardware (Arduino + SSR + bulb)'}, {'sim', 'hw'}, 'sim', @onSource);
    w.section('Experiment');
    pr = enr312.temperature.presets();
    ui.preset = w.dropdown('', [{'(custom)'}, {pr.name}], [{'(custom)'}, {pr.name}], '(custom)', @applyPreset);
    ui.mode = w.dropdown('Control', {'On-off', 'On-off + hysteresis', 'Moving average + on-off', 'P (PWM pin 9)', 'P, time-proportional'}, ...
        {'ONOFF', 'HYST', 'MA', 'P', 'TPROP'}, 'ONOFF', @changed);
    ui.sensor = w.dropdown('Sensor', {'DHT22', 'DHT11 (course)'}, {'DHT22', 'DHT11'}, 'DHT22', @changed);
    ui.run = w.button(char(9654) + "  RUN (time-lapse)", @animate, C.green, 40);
    ui.speed = w.dropdown('Time-lapse', {'10x', '30x', '60x', '120x'}, {10, 30, 60, 120}, 60, @() []);
    ui.record = w.checkbox('Record video of RUN + save evidence', false, @() []);
    ui.export = w.button('Export run  (CSV + JSON + PNG)', @exportNow);
    w.section('Setpoint and controller');
    ui.sp = w.slider('Desired temperature (C)', [25 65], 45, '%.1f', @changed);
    ui.hyst = w.slider('Hysteresis band (C)', [0 5], 1, '%.1f', @changed);
    ui.window = w.dropdown('Moving-average N', {'1', '10', '50', '100', '500'}, {1, 10, 50, 100, 500}, 10, @changed);
    ui.Kp = w.slider('Kp (PWM counts per C)', [0 500], 50, '%.0f', @changed);
    ui.ssr = w.dropdown('SSR drive', {'analogWrite pin 9 (course)', 'ideal average'}, {'pwm490', 'average'}, 'pwm490', @changed);
    ui.tprop = w.slider('Time-proportioning window (s)', [0.5 10], 2, '%.1f', @changed);
    ui.Tend = w.dropdown('Run length', {'2 min', '5 min', '10 min', '15 min', '20 min'}, {120, 300, 600, 900, 1200}, 900, @changed);
    w.section('Rig physics  (ESTIMATED until TEMP-01)');
    ui.Pb = w.slider('Bulb power (W)', [25 100], P0.P_bulb, '%.0f', @changed);
    ui.R = w.slider('Thermal resistance R (K/W)', [0.3 3], P0.R_th, '%.2f', @changed);
    ui.Cth = w.slider('Heat capacity C (J/K)', [30 600], P0.C_th, '%.0f', @changed);
    ui.del = w.slider('Bulb -> sensor delay (s)', [0 15], P0.delay, '%.1f', @changed);
    ui.Ta = w.slider('Ambient (C)', [15 40], P0.T_amb, '%.1f', @changed);
    w.button('Reset physics to estimates', @resetPhysics);
    hp = enr312.ui.HardwarePanel(w, 'TTEL', @hwStart, @hwTick);

    % ------------------------------------------------------------ view + plots
    V = buildView(w.axView, C);
    tr = buildTraces(ax, C);
    onSource();
    setPreset('On-off, 45 C');

    app = struct('fig', fig, 'ui', ui, 'preset', @setPreset, 'run', @animate, 'result', @() S, ...
                 'export', @exportNow, 'lastVideo', @() lastVideo, 'set', @setParam);

    % ================================================================ nested
    function setParam(name, val)
        c = ui.(name);
        if isa(c, 'matlab.ui.control.Slider'), w.setSlider(c, val); else, c.Value = val; end
        changed();
    end

    function setPreset(name)
        ui.preset.Value = name; applyPreset();
    end

    function applyPreset()
        if strcmp(ui.preset.Value, '(custom)'), return; end
        c = enr312.temperature.presetConfig(ui.preset.Value);
        currentExperiment = c.experiment;
        ui.mode.Value = c.mode; ui.sensor.Value = c.sensor;
        w.setSlider(ui.sp, max(c.setpoint, 25)); w.setSlider(ui.hyst, c.hyst); ui.window.Value = c.window;
        w.setSlider(ui.Kp, c.Kp); ui.ssr.Value = c.ssr; w.setSlider(ui.tprop, c.tprop);
        if ~any(cellfun(@(v) isequal(v, c.Tend), ui.Tend.ItemsData))
            ui.Tend.Items{end + 1} = sprintf('%g s', c.Tend); ui.Tend.ItemsData{end + 1} = c.Tend;
        end
        ui.Tend.Value = c.Tend;
        if c.setpoint <= 0, ui.sp.UserData.valueLabel.Text = 'heater off'; end
        update(c);
    end

    function changed()
        ui.preset.Value = '(custom)';
        update();
    end

    function c = readConfig()
        c = enr312.temperature.defaultConfig();
        c.experiment = currentExperiment;
        c.mode = ui.mode.Value; c.sensor = ui.sensor.Value; c.setpoint = ui.sp.Value;
        c.hyst = ui.hyst.Value; c.window = ui.window.Value; c.Kp = ui.Kp.Value;
        c.ssr = ui.ssr.Value; c.tprop = ui.tprop.Value; c.Tend = ui.Tend.Value;
        c.P.P_bulb = ui.Pb.Value; c.P.R_th = ui.R.Value; c.P.C_th = ui.Cth.Value;
        c.P.delay = ui.del.Value; c.P.T_amb = ui.Ta.Value;
        for n = {'P_bulb', 'R_th', 'C_th', 'delay', 'T_amb'}
            if abs(c.P.(n{1}) - P0.(n{1})) > 1e-9, c.P.meta.(n{1}).status = 'USER_OVERRIDE (ESTIMATED)'; end
        end
        c.preset = ui.preset.Value;
    end

    function resetPhysics()
        w.setSlider(ui.Pb, P0.P_bulb); w.setSlider(ui.R, P0.R_th); w.setSlider(ui.Cth, P0.C_th);
        w.setSlider(ui.del, P0.delay); w.setSlider(ui.Ta, P0.T_amb); changed();
    end

    function update(c)
        if busy, return; end
        if nargin < 1, c = readConfig(); end
        S = enr312.temperature.simulate(c);
        if strcmp(ui.source.Value, 'sim')
            showTraces(tr, S, numel(S.t)); poseView(V, S, numel(S.t)); showResults(S);
        else
            set(tr.pred, 'XData', S.t, 'YData', S.T);
        end
        w.lim.Text = limitsText(c);
    end

    function animate()
        if busy || ~strcmp(ui.source.Value, 'sim'), return; end
        busy = true; ui.run.Enable = 'off'; cl = onCleanup(@() finish());
        n = numel(S.t);
        if ui.record.Value
            out = exportNow();
            nF = 150; idx = round(linspace(1, n, nF));
            w.caption.Text = 'RECORDING: captured frame by frame (time-lapse).';
            lastVideo = enr312.ui.recordFrames(fig, nF, @(j) frame(idx(j)), out.dir, 12);
            w.caption.Text = ['Recorded ' strrep(lastVideo, [enr312.repoRoot() filesep], '')];
        else
            sp = ui.speed.Value; t0 = tic; k = 1;
            while k < n && isvalid(fig)
                k = min(n, 1 + round(toc(t0) * sp / 0.1));
                frame(k); drawnow limitrate;
            end
            frame(n);
        end
        function frame(k), showTraces(tr, S, k); poseView(V, S, k); end
        function finish(), busy = false; if isvalid(fig), ui.run.Enable = 'on'; end, end
    end

    function out = exportNow()
        if strcmp(ui.source.Value, 'hw'), out = hwExport(); return; end
        c = S.cfg;
        trace = table(S.t, S.sp, S.T, S.Tsens, S.Traw, S.Tfilt, S.e, S.u, S.heat, S.sw, ...
            'VariableNames', {'t_s', 'setpoint_C', 'zone_true_C', 'sensor_body_C', 'reading_C', ...
                              'filtered_C', 'error_C', 'u_0_255', 'heater_on_fraction', 'switches_cum'});
        out = enr312.evidence.exportRun('temperature', c.experiment, trace, [], rmfield(c, 'P'), c.P, ...
            S.metrics, S.units, struct('preset', ui.preset.Value));
        try, exportapp(fig, fullfile(out.dir, 'figure.png')); catch err, warning('enr312:app:png', '%s', err.message); end
        w.caption.Text = ['Exported ' strrep(out.dir, [enr312.repoRoot() filesep], '')];
    end

    function showResults(S)
        m = S.metrics; c = S.cfg;
        kind = 'warn';
        if strcmp(m.verdict, 'REGULATING'), kind = 'good'; elseif any(strcmp(m.verdict, {'OVER-TEMP CUT-OFF', 'NOT REACHED'})), kind = 'bad'; end
        w.setVerdict(sprintf('%s   %s   %s, %s', m.verdict, char(183), modeName(c.mode), c.sensor), kind);
        w.caption.Text = captionFor(c, m);
        w.res.Text = sprintf([ ...
            '<b style="font-size:15px">Results</b>&nbsp;&nbsp;<span style="color:#777">(SIMULATION)</span><br><table style="font-size:13px">' ...
            '<tr><td>Time to reach setpoint</td><td>&nbsp;&nbsp;<b>%s</b></td><td>&nbsp;&nbsp;Heater switches</td><td>&nbsp;&nbsp;<b>%.1f / min</b></td></tr>' ...
            '<tr><td>Overshoot</td><td>&nbsp;&nbsp;<b>%s</b></td><td>&nbsp;&nbsp;Heater duty</td><td>&nbsp;&nbsp;<b>%.0f %%</b></td></tr>' ...
            '<tr><td>Band (last 30 %%)</td><td>&nbsp;&nbsp;<b>%.2f C p-p</b></td><td>&nbsp;&nbsp;Energy</td><td>&nbsp;&nbsp;<b>%.1f Wh</b></td></tr>' ...
            '<tr><td>Mean error (last 30 %%)</td><td>&nbsp;&nbsp;<b>%+.2f C</b></td><td>&nbsp;&nbsp;Theory</td><td>&nbsp;&nbsp;<b>%s</b></td></tr>' ...
            '</table><span style="color:#555">%s</span>'], ...
            secs(m.t_reach), m.switches_per_min, degC(m.overshoot), 100 * m.duty, m.band_pp, m.energy_Wh, ...
            m.mean_error, theory(c), noteFor(c));
    end

    % ================================================================ hardware
    function onSource()
        hw = strcmp(ui.source.Value, 'hw');
        w.setSource(hw); hp.setEnabled(hw);
        ui.run.Enable = ~hw; ui.record.Enable = ~hw;
        if hw
            w.setVerdict('HARDWARE MODE  -  connect, then Start', 'none');
            w.caption.Text = 'Grey dashed = simulation prediction. Solid = measured. MAINS: enclosure closed before Start.';
            for h = [tr.T tr.raw tr.filt tr.e tr.u tr.heat tr.sw], set(h, 'XData', nan, 'YData', nan); end
        end
        if ~isempty(S), update(); end
    end

    function hwStart(link)
        hwCfg = readConfig();
        link.send('CFG', hwCfg.mode, hwCfg.setpoint, hwCfg.hyst, hwCfg.window, hwCfg.Kp, round(1000 * hwCfg.tprop));
        if ~isempty(S), set(tr.pred, 'XData', S.t, 'YData', S.T); end
    end

    function hwTick(T)
        set(tr.sp, 'XData', T.t_s, 'YData', T.setpoint);
        set(tr.raw, 'XData', T.t_s, 'YData', T.temp_raw);
        set(tr.filt, 'XData', T.t_s, 'YData', T.temp_filt);
        set(tr.T, 'XData', nan, 'YData', nan);
        set(tr.e, 'XData', T.t_s, 'YData', T.err);
        set(tr.u, 'XData', T.t_s, 'YData', T.u);
        set(tr.heat, 'XData', T.t_s, 'YData', T.heater);
        set(tr.sw, 'XData', T.t_s, 'YData', cumsum([0; abs(diff(T.heater)) > 0]));
        for a = ax, xlim(a, [0 max(60, T.t_s(end))]); ylim(a, 'auto'); end
        title(ax(1), 'Temperature (C)  -  MEASURED');
    end

    function out = hwExport()
        out = struct('dir', '');
        if hp.link.n == 0, return; end
        c = hwCfg; c.experiment = currentExperiment;
        r = exportHardware('temperature', c, hp.link);
        out.dir = fileparts(r);
        w.caption.Text = ['Saved raw data ' r];
    end

    function onClose()
        hp.close(); delete(fig);
    end
end

% ======================================================================= view
function V = buildView(ax, C)
    xlim(ax, [0 320]); ylim(ax, [0 230]);
    % Arduino
    rectangle(ax, 'Position', [8 120 70 46], 'Curvature', 0.08, 'FaceColor', [0.0 0.47 0.55], 'EdgeColor', 'none');
    text(ax, 43, 150, 'Arduino Uno', 'Color', 'w', 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'FontSize', 10);
    V.ard = text(ax, 43, 134, '', 'Color', 'w', 'HorizontalAlignment', 'center', 'FontSize', 9);
    % LCD
    rectangle(ax, 'Position', [6 40 110 44], 'FaceColor', [0.15 0.20 0.15], 'EdgeColor', 'none');
    rectangle(ax, 'Position', [12 46 98 32], 'FaceColor', [0.55 0.78 0.30], 'EdgeColor', 'none');
    V.lcd1 = text(ax, 15, 70, '', 'FontName', 'Monospaced', 'FontSize', 11, 'Color', [0.05 0.15 0.05], 'FontWeight', 'bold');
    V.lcd2 = text(ax, 15, 54, '', 'FontName', 'Monospaced', 'FontSize', 11, 'Color', [0.05 0.15 0.05], 'FontWeight', 'bold');
    text(ax, 61, 33, 'LCD 16x2', 'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', C.grey);
    plot(ax, [43 43], [120 84], '-', 'Color', C.grey, 'LineWidth', 1.2);
    % SSR
    rectangle(ax, 'Position', [110 128 50 30], 'FaceColor', [0.2 0.2 0.22], 'EdgeColor', 'none');
    text(ax, 135, 146, 'SSR-40DA', 'Color', 'w', 'HorizontalAlignment', 'center', 'FontSize', 9);
    V.led = plot(ax, 152, 134, 'o', 'MarkerSize', 7, 'MarkerFaceColor', [0.3 0.1 0.1], 'MarkerEdgeColor', 'none');
    plot(ax, [78 110], [150 150], '-', 'Color', C.blue, 'LineWidth', 1.5);
    text(ax, 94, 156, 'pin 9', 'FontSize', 8, 'HorizontalAlignment', 'center', 'Color', C.blue);
    % enclosure + mains
    rectangle(ax, 'Position', [180 40 132 180], 'Curvature', 0.04, 'FaceColor', [0.97 0.97 0.97], 'EdgeColor', C.red, 'LineStyle', '--', 'LineWidth', 1.2);
    text(ax, 246, 214, 'enclosure  (230 V AC inside)', 'FontSize', 8, 'Color', C.red, 'HorizontalAlignment', 'center');
    plot(ax, [160 205 205], [143 143 180], '-', 'Color', C.red, 'LineWidth', 1.5);
    % bulb
    th = linspace(0, 2*pi, 80);
    V.glow = patch(ax, 246 + 40 * cos(th), 165 + 40 * sin(th), C.glow, 'EdgeColor', 'none', 'FaceAlpha', 0);
    V.bulb = patch(ax, 246 + 18 * cos(th), 165 + 18 * sin(th), [0.9 0.9 0.88], 'EdgeColor', [0.5 0.5 0.5]);
    rectangle(ax, 'Position', [238 135 16 13], 'FaceColor', [0.6 0.6 0.62], 'EdgeColor', 'none');
    plot(ax, [205 238], [180 141], '-', 'Color', C.red, 'LineWidth', 1);
    % sensor
    rectangle(ax, 'Position', [234 78 24 30], 'FaceColor', 'w', 'EdgeColor', C.blue, 'LineWidth', 1.2);
    for yy = 82:5:104, plot(ax, [237 255], [yy yy], '-', 'Color', [0.75 0.82 0.95]); end
    V.sensName = text(ax, 246, 71, 'DHT22', 'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', C.blue);
    V.reading = text(ax, 246, 58, '', 'HorizontalAlignment', 'center', 'FontSize', 13, 'FontWeight', 'bold', 'Color', C.blue);
    plot(ax, [78 234], [125 93], ':', 'Color', C.blue);
    % thermometer
    rectangle(ax, 'Position', [290 60 10 120], 'Curvature', 0.5, 'FaceColor', 'w', 'EdgeColor', C.navy);
    V.merc = patch(ax, [292 298 298 292], [62 62 62 62], C.red, 'EdgeColor', 'none');
    V.spMark = plot(ax, [286 304], [100 100], '-', 'Color', C.green, 'LineWidth', 2);
    text(ax, 295, 50, 'zone T', 'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', C.grey);
    V.t = text(ax, 4, 10, '', 'FontSize', 10, 'Color', C.grey);
end

function poseView(V, S, k)
    c = S.cfg; h = S.heat(k);
    V.glow.FaceAlpha = 0.55 * h; V.bulb.FaceColor = (1 - h) * [0.9 0.9 0.88] + h * [1 0.92 0.45];
    if h > 0, V.led.MarkerFaceColor = [1 0.15 0.1]; else, V.led.MarkerFaceColor = [0.3 0.1 0.1]; end
    V.sensName.String = c.sensor;
    V.reading.String = sprintf('%.1f C', S.Traw(k));
    yOf = @(T) 62 + 116 * min(max((T - 20) / 60, 0), 1);
    V.merc.YData = [62 62 yOf(S.T(k)) yOf(S.T(k))];
    V.spMark.YData = yOf(c.setpoint) * [1 1];
    on = 'OFF'; if h > 0, on = 'ON '; end
    V.lcd1.String = sprintf('T=%5.1fC SP=%2.0f', S.Traw(k), max(c.setpoint, 0));
    if any(strcmp(c.mode, {'P', 'TPROP'}))
        V.lcd2.String = sprintf('e=%+5.1f u=%3.0f', S.e(k), S.u(k));
    else
        V.lcd2.String = sprintf('%s e=%+5.1f', on, S.e(k));
    end
    V.ard.String = sprintf('%s, Ts 10 ms', c.mode);
    V.t.String = sprintf('t = %5.0f s  (%4.1f min)', S.t(k), S.t(k) / 60);
end

function tr = buildTraces(ax, C)
    tr.pred = plot(ax(1), nan, nan, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1.4);
    tr.sp = plot(ax(1), nan, nan, '--', 'Color', C.green, 'LineWidth', 1.8);
    tr.T = plot(ax(1), nan, nan, '-', 'Color', C.red, 'LineWidth', 1.2);
    tr.raw = stairs(ax(1), nan, nan, '-', 'Color', C.blue, 'LineWidth', 1.8);
    tr.filt = plot(ax(1), nan, nan, '-', 'Color', C.amber, 'LineWidth', 1.2);
    legend(ax(1), [tr.sp tr.T tr.raw tr.filt tr.pred], {'setpoint', 'zone (true)', 'sensor reading', 'moving average', 'prediction'}, 'Location', 'southeast');
    title(ax(1), 'Temperature (C)  -  SIMULATION');
    tr.e = stairs(ax(2), nan, nan, '-', 'Color', C.red, 'LineWidth', 1.2); yline(ax(2), 0, 'Color', [0.5 0.5 0.5]);
    title(ax(2), 'Error = desired - reading (C)');
    tr.u = plot(ax(3), nan, nan, '-', 'Color', C.purple, 'LineWidth', 1.2); yline(ax(3), 255, '--', 'Color', [0.5 0.5 0.5]);
    title(ax(3), 'Control signal u (0..255)'); ylim(ax(3), [-10 270]);
    tr.heat = stairs(ax(4), nan, nan, '-', 'Color', C.amber, 'LineWidth', 1.2);
    title(ax(4), 'Heater on-fraction (zoom: last 30 s)'); ylim(ax(4), [-0.05 1.05]); xlabel(ax(4), 't (s)');
    tr.sw = plot(ax(5), nan, nan, '-', 'Color', C.navy, 'LineWidth', 1.6);
    title(ax(5), 'Light switchings (cumulative)  =  flicker'); xlabel(ax(5), 't (s)');
    tr.ax = ax;
end

function showTraces(tr, S, k)
    t = S.t(1:k); ax = tr.ax;
    set(tr.sp, 'XData', t, 'YData', S.sp(1:k)); set(tr.T, 'XData', t, 'YData', S.T(1:k));
    set(tr.raw, 'XData', t, 'YData', S.Traw(1:k));
    if strcmp(S.cfg.mode, 'MA'), set(tr.filt, 'XData', t, 'YData', S.Tfilt(1:k)); else, set(tr.filt, 'XData', nan, 'YData', nan); end
    set(tr.pred, 'XData', nan, 'YData', nan);
    set(tr.e, 'XData', t, 'YData', S.e(1:k)); set(tr.u, 'XData', t, 'YData', S.u(1:k));
    set(tr.heat, 'XData', t, 'YData', S.heat(1:k)); set(tr.sw, 'XData', t, 'YData', S.sw(1:k));
    T = S.cfg.Tend;
    for a = ax([1 2 3 5]), xlim(a, [0 T]); end
    xlim(ax(4), max(0, S.t(k) - 30) + [0 30]);
    ylim(ax(1), [min([S.Traw; S.T]) - 2, max([S.Traw; S.T; S.cfg.setpoint]) + 3]);
    ylim(ax(2), [min(S.e) - 1, max(S.e) + 1]);
    ylim(ax(5), [0 max(1, S.sw(end)) * 1.1]);
    title(ax(1), 'Temperature (C)  -  SIMULATION');
end

% ======================================================================= text
function s = modeName(m)
    n = struct('ONOFF', 'on-off', 'HYST', 'on-off + hysteresis', 'MA', 'moving average', 'P', 'P control', 'TPROP', 'P, time-proportional');
    s = n.(m);
end

function s = theory(c)
    P = c.P; G = P.eta_heat * P.P_bulb * P.R_th;            % C rise at full power
    switch c.mode
        case {'P', 'TPROP'}
            e = (c.setpoint - P.T_amb) / (1 + c.Kp * G / 255);
            s = sprintf('e_ss = (SP-Ta)/(1+Kp G/255) = %.2f C', e);
        otherwise
            s = sprintf('max reachable %.0f C', P.T_amb + G);
    end
end

function s = noteFor(c)
    switch c.mode
        case 'ONOFF', s = 'On-off: the light switches each time the reading crosses the setpoint; the band is set by the sensor lag and the 1-2 s DHT update, not by the controller.';
        case 'HYST', s = 'Hysteresis: the heater waits for a full band of error before switching, so it switches less often but the temperature swings more.';
        case 'MA', s = 'Moving average over N x 10 ms. The DHT only updates every 1-2 s, so N = 10 (0.1 s) averages the same reading: no effect. N = 500 (5 s) does smooth, and adds lag.';
        case 'P', s = 'P on pin 9: analogWrite makes 490 Hz PWM, but a zero-cross SSR only switches at mains zero crossings (every 10 ms), so the bulb receives a random pattern of half-cycles: intense flicker while 0 < u < 255.';
        otherwise, s = 'Time-proportional: one on/off cycle per window. Same average power as P, far fewer switchings.';
    end
end

function s = captionFor(c, m)
    s = sprintf('%s at %g C: %s. Mean error %+.2f C, %.1f switchings/min.', modeName(c.mode), c.setpoint, lower(m.verdict), m.mean_error, m.switches_per_min);
end

function s = limitsText(c)
    s = ['<b style="font-size:14px">&#9888; Model limits: read before trusting a result</b><br>' ...
         '<b>Simulated as the Arduino will run it:</b> Ts = 10 ms loop, DHT update every 1 s (DHT11) / 2 s (DHT22), ' ...
         'resolution and noise, moving average on the 10 ms samples, 0..255 clamp, zero-cross SSR vs 490 Hz PWM, 70 C cut-off.<br>' ...
         '<b>NOT known:</b><br>&bull; <b>Thermal R, C, delay and sensor lag are ESTIMATED</b> for a 60 W bulb with the sensor close by. ' ...
         'TEMP-01 (heater step) must measure them.<br>&bull; Single lumped temperature: no air currents, no enclosure walls, no radiation on the sensor.<br>' ...
         '&bull; Bulb rating and SSR type (zero-cross vs random) not yet inspected (OI-T2, OI-T3).<br>' ...
         sprintf('&bull; Sensor: %s. The course specifies DHT11; this rig uses DHT22 (better resolution, slower update).', c.sensor)];
end

function s = secs(v), if isnan(v), s = 'not reached'; else, s = sprintf('%.0f s', v); end, end
function s = degC(v), if isnan(v), s = '--'; else, s = sprintf('%.2f C', v); end, end

function f = exportHardware(subsystem, c, link)
    root = enr312.repoRoot();
    rawDir = fullfile(root, 'data', 'raw', subsystem); metaDir = fullfile(root, 'data', 'metadata', subsystem);
    if ~exist(rawDir, 'dir'), mkdir(rawDir); end
    if ~exist(metaDir, 'dir'), mkdir(metaDir); end
    exp = c.experiment; if isempty(exp), exp = 'TEMP-XX'; end
    id = enr312.newRunId([exp '-HW'], @(i) exist(fullfile(rawDir, [i '.csv']), 'file'));
    f = fullfile(rawDir, [id '.csv']);
    writetable(link.table(), f); fileattrib(f, '-w', 'a');
    meta = struct('run_id', id, 'data_class', 'HARDWARE', 'config_sent', rmfield(c, 'P'), ...
        'invalid_lines', link.invalidCount, 'seq_gaps', link.seqGaps, 'events', {link.eventLog});
    fid = fopen(fullfile(metaDir, [id '.json']), 'w'); fprintf(fid, '%s\n', jsonencode(meta, 'PrettyPrint', true)); fclose(fid);
end
