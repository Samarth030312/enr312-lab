function app = WaterLevelApp()
%WATERLEVELAPP  ENR312 water-level lab: tank, DC pump, HC-SR04, relay / MOSFET.
%
%   run('<repo>/matlab/setup_enr312.m'); WaterLevelApp
%
%   Course tasks (SRC-001 p.23): on-off control between Lmin (30 %) and Lmax
%   (80 %) with a relay; fill time, switching frequency, chattering; comparison
%   with simulation; P / PI for the PID questions. HARDWARE mode talks to
%   water_level/firmware/level_controller ($LTEL). Base MATLAB only.

    P0 = enr312.level.params();
    S = []; busy = false; currentExperiment = ''; lastVideo = ''; hwCfg = [];
    w = enr312.ui.LabWindow(['ENR312  ' char(183) '  Water level control  ' char(183) ...
        '  tank ' char(183) ' DC pump ' char(183) ' HC-SR04 ' char(183) ' relay ' char(183) ' Arduino Uno'], ...
        {{1, [1 2]}, {2, 1}, {2, 2}, {3, 1}, {3, 2}});
    C = w.C; fig = w.fig; fig.CloseRequestFcn = @(~, ~) onClose(); ax = w.ax;

    w.section('Data source');
    ui.source = w.dropdown('', {'Simulation (model)', 'Hardware (Arduino + pump)'}, {'sim', 'hw'}, 'sim', @onSource);
    w.section('Experiment');
    pr = enr312.level.presets();
    ui.preset = w.dropdown('', [{'(custom)'}, {pr.name}], [{'(custom)'}, {pr.name}], '(custom)', @applyPreset);
    ui.mode = w.dropdown('Control', {'On-off (relay)', 'P (PWM pump)', 'PI (PWM pump)'}, {'ONOFF', 'P', 'PI'}, 'ONOFF', @changed);
    ui.run = w.button(char(9654) + "  RUN (time-lapse)", @animate, C.green, 40);
    ui.speed = w.dropdown('Time-lapse', {'10x', '30x', '60x'}, {10, 30, 60}, 30, @() []);
    ui.record = w.checkbox('Record video of RUN + save evidence', false, @() []);
    w.button('Export run  (CSV + JSON + PNG)', @exportNow);
    w.section('Levels and controller');
    ui.Lmin = w.slider('Lmin: pump ON below (%)', [5 90], 30, '%.0f', @changed);
    ui.Lmax = w.slider('Lmax: pump OFF above (%)', [10 95], 80, '%.0f', @changed);
    ui.sp = w.slider('Setpoint for P / PI (%)', [10 85], 50, '%.0f', @changed);
    ui.Kp = w.slider('Kp (PWM counts per %)', [0 100], 20, '%.1f', @changed);
    ui.Ki = w.slider('Ki (per % s)', [0 3], 0.5, '%.2f', @changed);
    w.section('Disturbance');
    ui.drain = w.slider('Outlet opened by factor', [0.5 2], 1, '%.2f', @changed);
    ui.tDrain = w.slider('... at t (s)', [0 1200], 400, '%.0f', @changed);
    ui.Tend = w.dropdown('Run length', {'5 min', '10 min', '15 min', '20 min'}, {300, 600, 900, 1200}, 900, @changed);
    w.section('Rig physics  (ASSUMED until LEVEL-01)');
    ui.A = w.slider('Tank area (cm^2)', [100 900], P0.A * 1e4, '%.0f', @changed);
    ui.Q = w.slider('Pump max flow (L/min)', [1 10], P0.Q_max * 60000, '%.1f', @changed);
    ui.del = w.slider('Pump / pipe delay (s)', [0 5], P0.delay, '%.1f', @changed);
    w.button('Reset physics to assumptions', @resetPhysics);
    hp = enr312.ui.HardwarePanel(w, 'LTEL', @hwStart, @hwTick);

    V = buildView(w.axView, C);
    tr = buildTraces(ax, C);
    onSource();
    setPreset('On-off 30-80 % (course)');
    app = struct('fig', fig, 'ui', ui, 'preset', @setPreset, 'run', @animate, 'result', @() S, ...
                 'export', @exportNow, 'lastVideo', @() lastVideo);

    % ================================================================ nested
    function setPreset(name), ui.preset.Value = name; applyPreset(); end

    function applyPreset()
        if strcmp(ui.preset.Value, '(custom)'), return; end
        c = enr312.level.presetConfig(ui.preset.Value);
        currentExperiment = c.experiment;
        ui.mode.Value = c.mode;
        w.setSlider(ui.Lmin, c.Lmin); w.setSlider(ui.Lmax, c.Lmax); w.setSlider(ui.sp, c.setpoint);
        w.setSlider(ui.Kp, c.Kp); w.setSlider(ui.Ki, c.Ki);
        w.setSlider(ui.drain, c.drainFactor); w.setSlider(ui.tDrain, c.tDrain); ui.Tend.Value = c.Tend;
        update(c);
    end

    function changed(), ui.preset.Value = '(custom)'; update(); end

    function c = readConfig()
        c = enr312.level.defaultConfig(); c.experiment = currentExperiment;
        c.mode = ui.mode.Value; c.Lmin = ui.Lmin.Value; c.Lmax = ui.Lmax.Value; c.setpoint = ui.sp.Value;
        c.Kp = ui.Kp.Value; c.Ki = ui.Ki.Value; c.drainFactor = ui.drain.Value; c.tDrain = ui.tDrain.Value;
        c.Tend = ui.Tend.Value;
        c.P.A = ui.A.Value / 1e4; c.P.Q_max = ui.Q.Value / 60000; c.P.delay = ui.del.Value;
        for n = {'A', 'Q_max', 'delay'}
            if abs(c.P.(n{1}) - P0.(n{1})) > 1e-12, c.P.meta.(n{1}).status = 'USER_OVERRIDE (ASSUMED)'; end
        end
        c.preset = ui.preset.Value;
    end

    function resetPhysics()
        w.setSlider(ui.A, P0.A * 1e4); w.setSlider(ui.Q, P0.Q_max * 60000); w.setSlider(ui.del, P0.delay); changed();
    end

    function update(c)
        if busy, return; end
        if nargin < 1, c = readConfig(); end
        S = enr312.level.simulate(c);
        if strcmp(ui.source.Value, 'sim')
            showTraces(tr, S, numel(S.t)); poseView(V, S, numel(S.t)); showResults(S);
        else
            set(tr.pred, 'XData', S.t, 'YData', S.level);
        end
        w.lim.Text = limitsText();
    end

    function animate()
        if busy || ~strcmp(ui.source.Value, 'sim'), return; end
        busy = true; ui.run.Enable = 'off'; cl = onCleanup(@() finish());
        n = numel(S.t);
        if ui.record.Value
            out = exportNow(); nF = 150; idx = round(linspace(1, n, nF));
            w.caption.Text = 'RECORDING: captured frame by frame (time-lapse).';
            lastVideo = enr312.ui.recordFrames(fig, nF, @(j) frame(idx(j)), out.dir, 12);
            w.caption.Text = ['Recorded ' strrep(lastVideo, [enr312.repoRoot() filesep], '')];
        else
            sp = ui.speed.Value; t0 = tic; k = 1;
            while k < n && isvalid(fig)
                k = min(n, 1 + round(toc(t0) * sp / 0.1)); frame(k); drawnow limitrate;
            end
            frame(n);
        end
        function frame(k), showTraces(tr, S, k); poseView(V, S, k); end
        function finish(), busy = false; if isvalid(fig), ui.run.Enable = 'on'; end, end
    end

    function out = exportNow()
        if strcmp(ui.source.Value, 'hw'), out = hwExport(); return; end
        c = S.cfg;
        trace = table(S.t, S.level, S.meas, S.e, S.u, S.qin, S.qout, S.starts, 'VariableNames', ...
            {'t_s', 'level_true_pct', 'level_measured_pct', 'error_pct', 'u_0_255', 'q_in_L_min', 'q_out_L_min', 'pump_starts_cum'});
        out = enr312.evidence.exportRun('water_level', c.experiment, trace, [], rmfield(c, 'P'), c.P, ...
            S.metrics, S.units, struct('preset', ui.preset.Value));
        try, exportapp(fig, fullfile(out.dir, 'figure.png')); catch err, warning('enr312:app:png', '%s', err.message); end
        w.caption.Text = ['Exported ' strrep(out.dir, [enr312.repoRoot() filesep], '')];
    end

    function showResults(S)
        m = S.metrics; c = S.cfg;
        kind = 'warn';
        if any(strcmp(m.verdict, {'CYCLING', 'REGULATING'})), kind = 'good';
        elseif contains(m.verdict, 'GUARD') || contains(m.verdict, 'UNREACHABLE'), kind = 'bad'; end
        w.setVerdict(sprintf('%s   %s   %s', m.verdict, char(183), c.mode), kind);
        w.caption.Text = captionFor(c, m);
        w.res.Text = sprintf([ ...
            '<b style="font-size:15px">Results</b>&nbsp;&nbsp;<span style="color:#777">(SIMULATION)</span><br><table style="font-size:13px">' ...
            '<tr><td>Pump starts</td><td><b>%d (%.0f / h)</b></td><td>Cycle period</td><td><b>%s</b></td></tr>' ...
            '<tr><td>Fill time Lmin to Lmax</td><td><b>%s</b></td><td>Drain time Lmax to Lmin</td><td><b>%s</b></td></tr>' ...
            '<tr><td>Level band</td><td><b>%s</b></td><td>Steady-state error</td><td><b>%s</b></td></tr>' ...
            '<tr><td>Overshoot</td><td><b>%s</b></td><td>Error left after drain step</td><td><b>%s</b></td></tr>' ...
            '</table><span style="color:#555">%s</span>'], ...
            m.pump_starts, m.starts_per_hour, secs(m.cycle_period), secs(m.fill_time), secs(m.drain_time), ...
            band(m), pct(m.ss_error), pct(m.overshoot), pct(m.error_after_drain), theory(c));
    end

    % ================================================================ hardware
    function onSource()
        hw = strcmp(ui.source.Value, 'hw'); w.setSource(hw); hp.setEnabled(hw);
        ui.run.Enable = ~hw; ui.record.Enable = ~hw;
        if hw
            w.setVerdict('HARDWARE MODE  -  connect, then Start', 'none');
            w.caption.Text = 'Grey dashed = simulation prediction. Solid = measured. Keep the electronics above the waterline.';
            for h = [tr.lvl tr.meas tr.e tr.u tr.qin tr.qout tr.starts], set(h, 'XData', nan, 'YData', nan); end
        end
        if ~isempty(S), update(); end
    end

    function hwStart(link)
        hwCfg = readConfig();
        link.send('CFG', hwCfg.mode, hwCfg.Lmin, hwCfg.Lmax, hwCfg.setpoint, hwCfg.Kp, hwCfg.Ki);
    end

    function hwTick(T)
        set(tr.meas, 'XData', T.t_s, 'YData', T.level_pct); set(tr.lvl, 'XData', nan, 'YData', nan);
        set(tr.e, 'XData', T.t_s, 'YData', T.err); set(tr.u, 'XData', T.t_s, 'YData', T.u);
        set(tr.starts, 'XData', T.t_s, 'YData', cumsum([0; diff(T.pump) > 0]));
        for a = ax, xlim(a, [0 max(60, T.t_s(end))]); end
        title(ax(1), 'Level (%)  -  MEASURED');
    end

    function out = hwExport()
        out = struct('dir', '');
        if hp.link.n == 0, return; end
        root = enr312.repoRoot(); rawDir = fullfile(root, 'data', 'raw', 'water_level'); metaDir = fullfile(root, 'data', 'metadata', 'water_level');
        if ~exist(rawDir, 'dir'), mkdir(rawDir); end
        if ~exist(metaDir, 'dir'), mkdir(metaDir); end
        exp = currentExperiment; if isempty(exp), exp = 'LEVEL-XX'; end
        id = enr312.newRunId([exp '-HW'], @(i) exist(fullfile(rawDir, [i '.csv']), 'file'));
        f = fullfile(rawDir, [id '.csv']); writetable(hp.link.table(), f); fileattrib(f, '-w', 'a');
        meta = struct('run_id', id, 'data_class', 'HARDWARE', 'config_sent', rmfield(hwCfg, 'P'), ...
            'invalid_lines', hp.link.invalidCount, 'seq_gaps', hp.link.seqGaps, 'events', {hp.link.eventLog});
        fid = fopen(fullfile(metaDir, [id '.json']), 'w'); fprintf(fid, '%s\n', jsonencode(meta, 'PrettyPrint', true)); fclose(fid);
        out.dir = rawDir; w.caption.Text = ['Saved raw data ' id];
    end

    function onClose(), hp.close(); delete(fig); end
end

% ======================================================================= view
function V = buildView(ax, C)
    xlim(ax, [0 320]); ylim(ax, [0 230]);
    % tank (x 150..250, y 30..190 = 0..100 %)
    V.x0 = 150; V.x1 = 250; V.y0 = 30; V.y1 = 190;
    V.water = patch(ax, [150 250 250 150], [30 30 60 60], C.water, 'EdgeColor', 'none', 'FaceAlpha', 0.75);
    plot(ax, [150 150 250 250], [195 30 30 195], '-', 'Color', C.navy, 'LineWidth', 2.5);
    V.lmin = plot(ax, [146 254], [0 0], '--', 'Color', C.amber, 'LineWidth', 1.4);
    V.lmax = plot(ax, [146 254], [0 0], '--', 'Color', C.red, 'LineWidth', 1.4);
    V.spl = plot(ax, [146 254], [0 0], '-', 'Color', C.green, 'LineWidth', 1.6);
    V.lminT = text(ax, 256, 0, 'Lmin', 'FontSize', 9, 'Color', C.amber);
    V.lmaxT = text(ax, 256, 0, 'Lmax', 'FontSize', 9, 'Color', C.red);
    V.lvl = text(ax, 200, 110, '', 'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Color', C.navy);
    % sensor
    rectangle(ax, 'Position', [185 205 30 12], 'FaceColor', [0.15 0.35 0.65], 'EdgeColor', 'none');
    th = linspace(-0.4, 0.4, 20);
    rr = [8 14 20];
    for j = 1:3, V.ping(j) = plot(ax, 200 + rr(j) * sin(th), 205 - rr(j) * cos(th), '-', 'Color', C.teal); end
    text(ax, 220, 216, 'HC-SR04', 'FontSize', 8, 'Color', C.grey);
    % reservoir + pump
    rectangle(ax, 'Position', [20 30 90 40], 'FaceColor', [0.85 0.92 1], 'EdgeColor', C.navy);
    text(ax, 65, 40, 'reservoir', 'FontSize', 8, 'HorizontalAlignment', 'center', 'Color', C.grey);
    V.pump = rectangle(ax, 'Position', [50 50 30 18], 'Curvature', 0.5, 'FaceColor', [0.5 0.5 0.5], 'EdgeColor', 'none');
    text(ax, 65, 76, 'pump', 'FontSize', 9, 'HorizontalAlignment', 'center');
    V.pipe = plot(ax, [65 65 160 160], [68 200 200 185], '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 4);
    V.flowT = text(ax, 110, 207, '', 'FontSize', 9, 'HorizontalAlignment', 'center', 'Color', C.blue);
    % drain
    plot(ax, [250 285 285], [40 40 25], '-', 'Color', C.water, 'LineWidth', 4);
    V.drainT = text(ax, 287, 50, '', 'FontSize', 9, 'Color', C.blue);
    % relay + Arduino
    rectangle(ax, 'Position', [8 120 60 40], 'Curvature', 0.08, 'FaceColor', [0.0 0.47 0.55], 'EdgeColor', 'none');
    text(ax, 38, 145, 'Arduino', 'Color', 'w', 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'FontSize', 10);
    V.ard = text(ax, 38, 130, '', 'Color', 'w', 'HorizontalAlignment', 'center', 'FontSize', 8);
    rectangle(ax, 'Position', [80 95 45 22], 'FaceColor', [0.2 0.3 0.6], 'EdgeColor', 'none');
    V.relayT = text(ax, 102, 106, 'relay', 'Color', 'w', 'HorizontalAlignment', 'center', 'FontSize', 9);
    plot(ax, [68 80], [130 108], '-', 'Color', C.grey); plot(ax, [102 75], [95 68], '-', 'Color', C.grey);
    V.t = text(ax, 4, 10, '', 'FontSize', 10, 'Color', C.grey);
end

function poseView(V, S, k)
    c = S.cfg; yOf = @(p) V.y0 + (V.y1 - V.y0) * p / 100;
    V.water.YData = [V.y0 V.y0 yOf(S.level(k)) yOf(S.level(k))];
    isOn = strcmp(c.mode, 'ONOFF');
    set([V.lmin V.lminT V.lmax V.lmaxT], 'Visible', isOn); V.spl.Visible = ~isOn;
    V.lmin.YData = yOf(c.Lmin) * [1 1]; V.lmax.YData = yOf(c.Lmax) * [1 1]; V.spl.YData = yOf(c.setpoint) * [1 1];
    V.lminT.Position(2) = yOf(c.Lmin); V.lmaxT.Position(2) = yOf(c.Lmax);
    V.lvl.String = sprintf('%.1f %%', S.meas(k));
    on = S.u(k) / 255;
    V.pump.FaceColor = (1 - on) * [0.5 0.5 0.5] + on * [0.13 0.59 0.33];
    V.pipe.Color = (1 - min(1, S.qin(k) / 2)) * [0.6 0.6 0.6] + min(1, S.qin(k) / 2) * [0.30 0.60 0.90];
    V.flowT.String = sprintf('in %.2f L/min', S.qin(k));
    V.drainT.String = sprintf('out %.2f L/min', S.qout(k));
    if isOn, V.relayT.String = sprintf('relay %s', onoff(S.u(k) > 0)); else, V.relayT.String = sprintf('PWM %3.0f', S.u(k)); end
    V.ard.String = c.mode;
    set(V.ping, 'Visible', mod(k, 4) < 2);
    V.t.String = sprintf('t = %4.0f s  (%4.1f min)', S.t(k), S.t(k) / 60);
end

function s = onoff(b), if b, s = 'ON'; else, s = 'OFF'; end, end

function tr = buildTraces(ax, C)
    tr.pred = plot(ax(1), nan, nan, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1.4);
    tr.lmin = yline(ax(1), 30, '--', 'Lmin', 'Color', C.amber); tr.lmax = yline(ax(1), 80, '--', 'Lmax', 'Color', C.red);
    tr.sp = yline(ax(1), 50, '-', 'setpoint', 'Color', C.green);
    tr.lvl = plot(ax(1), nan, nan, '-', 'Color', C.water, 'LineWidth', 2.2);
    tr.meas = plot(ax(1), nan, nan, '-', 'Color', [C.navy], 'LineWidth', 0.6);
    legend(ax(1), [tr.lvl tr.meas tr.pred], {'level (true)', 'HC-SR04 reading', 'prediction'}, 'Location', 'southeast');
    title(ax(1), 'Level (% of tank)  -  SIMULATION'); ylim(ax(1), [0 100]);
    tr.e = plot(ax(2), nan, nan, '-', 'Color', C.red, 'LineWidth', 1.2); yline(ax(2), 0, 'Color', [0.5 0.5 0.5]);
    title(ax(2), 'Error (%)  (P / PI only)');
    tr.u = stairs(ax(3), nan, nan, '-', 'Color', C.purple, 'LineWidth', 1.2); ylim(ax(3), [-10 270]);
    title(ax(3), 'Pump command (255 = relay on)');
    tr.qin = plot(ax(4), nan, nan, '-', 'Color', C.green, 'LineWidth', 1.4);
    tr.qout = plot(ax(4), nan, nan, '-', 'Color', C.red, 'LineWidth', 1.4);
    legend(ax(4), {'in (pump)', 'out (drain)'}, 'Location', 'best'); title(ax(4), 'Flow (L/min)'); xlabel(ax(4), 't (s)');
    tr.starts = stairs(ax(5), nan, nan, '-', 'Color', C.navy, 'LineWidth', 1.6);
    title(ax(5), 'Pump starts (cumulative)'); xlabel(ax(5), 't (s)');
    tr.ax = ax;
end

function showTraces(tr, S, k)
    c = S.cfg; t = S.t(1:k); ax = tr.ax;
    set(tr.lvl, 'XData', t, 'YData', S.level(1:k)); set(tr.meas, 'XData', t, 'YData', S.meas(1:k));
    set(tr.pred, 'XData', nan, 'YData', nan);
    set(tr.e, 'XData', t, 'YData', S.e(1:k)); set(tr.u, 'XData', t, 'YData', S.u(1:k));
    set(tr.qin, 'XData', t, 'YData', S.qin(1:k)); set(tr.qout, 'XData', t, 'YData', S.qout(1:k));
    set(tr.starts, 'XData', t, 'YData', S.starts(1:k));
    isOn = strcmp(c.mode, 'ONOFF');
    tr.lmin.Value = c.Lmin; tr.lmax.Value = c.Lmax; tr.sp.Value = c.setpoint;
    set([tr.lmin tr.lmax], 'Visible', isOn); tr.sp.Visible = ~isOn;
    for a = ax, xlim(a, [0 c.Tend]); end
    ylim(ax(5), [0 max(1, S.starts(end)) + 1]);
    title(ax(1), 'Level (% of tank)  -  SIMULATION');
end

function s = theory(c)
    if strcmp(c.mode, 'ONOFF')
        s = 'On-off with hysteresis (Lmin / Lmax): a narrower band means more pump starts per hour; a wider band means larger level swings. Pump and pipe delay make the level overshoot both thresholds.';
    elseif strcmp(c.mode, 'P')
        s = 'P alone: the outlet needs a steady inflow, which needs a steady pump command, which needs a steady error. Bigger Kp, smaller error.';
    else
        s = 'PI: the integral supplies the steady pump command, so the error goes to zero, even after the drain is opened (if the pump is big enough).';
    end
end

function s = captionFor(c, m)
    if strcmp(c.mode, 'ONOFF')
        s = sprintf('On-off %g-%g %%: %s, %d pump starts (%.0f per hour).', c.Lmin, c.Lmax, lower(m.verdict), m.pump_starts, m.starts_per_hour);
    else
        s = sprintf('%s at %g %%: %s, steady-state error %.2f %%.', c.mode, c.setpoint, lower(m.verdict), m.ss_error);
    end
end

function s = limitsText()
    s = ['<b style="font-size:14px">&#9888; Model limits: read before trusting a result</b><br>' ...
         '<b>Simulated as the Arduino will run it:</b> 100 ms ping, HC-SR04 resolution and noise, relay hysteresis, ' ...
         'PWM dead zone, pump delay and spin-up, overflow and dry-run guards.<br>' ...
         '<b>NOT known:</b><br>&bull; <b>Tank size, pump flow and outlet are ASSUMED</b>: the course gives none. LEVEL-01 must measure fill and drain times.<br>' ...
         '&bull; Pump flow treated as independent of head; outlet as an ideal orifice.<br>' ...
         '&bull; No surface ripple, foam or echo from the tank wall on the ultrasonic reading.<br>' ...
         '&bull; P / PI need a MOSFET on the pump; the course relay module can only switch on/off.'];
end

function s = secs(v), if isnan(v), s = '--'; else, s = sprintf('%.0f s', v); end, end
function s = pct(v), if isnan(v), s = '--'; else, s = sprintf('%.2f %%', v); end, end
function s = band(m), if isnan(m.band_low), s = '--'; else, s = sprintf('%.1f - %.1f %%', m.band_low, m.band_high); end, end
