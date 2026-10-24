function out = water_course_questions()
%WATER_COURSE_QUESTIONS  Simulation / analysis answers for the ENR312 WATER handout (SRC-014).
%
%   out = water_course_questions()
%
%   Uses enr312.level.simulate (MATLAB: guards, noise, pump delay) and enr312_water_level.slx
%   (Simulink, Relay block / PI). Tank and pump numbers are ASSUMED (15 x 15 cm tank, 25 cm =
%   100 %, 4 L/min pump, gravity outlet) until the rig is measured; the same analysis functions
%   (enr312.level.cycleAnalysis, enr312.level.calibrate) then run on the hardware data.
%   Writes results/evidence/simulation_runs/water_level/WATER-COURSE-SIM-<stamp>/ and refreshes
%   docs/experiments/water_level/COURSE_SIM_RESULTS.md (generated).

    here = fileparts(mfilename('fullpath'));
    run(fullfile(here, '..', 'setup_enr312.m'));
    addpath(fullfile(here, '..', 'models', 'water_level'));
    root = enr312.repoRoot();
    outRoot = fullfile(root, 'results', 'evidence', 'simulation_runs', 'water_level');
    runId = enr312.newRunId('WATER-COURSE-SIM', @(id) exist(fullfile(outRoot, id), 'file'));
    D = fullfile(outRoot, runId); mkdir(D);
    P = enr312.level.params(); base = enr312.level.defaultConfig();
    Hcm = 100 * P.H; Acm2 = 1e4 * P.A; Lmin = base.Lmin; Lmax = base.Lmax;
    N = struct(); md = {};
    say = @(varargin) addLine(sprintf(varargin{:}));
    function addLine(s), md{end + 1} = s; end

    say('# ENR312 WATER handout: simulation and analysis results');
    say('');
    say('Run `%s`, generated %s by `matlab/scripts/water_course_questions.m` (MATLAB %s, Simulink %s).', ...
        runId, char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')), version, ver('simulink').Version);
    say(['Data class: **SIMULATION**. Tank/pump ASSUMED: A = %.0f cm^2 (15 x 15 cm), 100 %% = %.0f cm, sensor %.0f cm above ' ...
         'the floor, pump %.1f L/min (%.0f mL/s) through a relay, gravity outlet sized so the pump alone settles at 96 %%. ' ...
         'Replace them with the measured values (S3-2, S3-3) and rerun.'], Acm2, Hcm, 100 * P.h_sensor, P.Q_max * 60000, P.Q_max * 1e6);
    say('Figures/CSV: `results/evidence/simulation_runs/water_level/%s/`.', runId);
    say('');

    % ================================================================== S3-1
    say('## S3-1 Ultrasonic level and the speed of sound');
    v20 = enr312.level.soundSpeed(20); v35 = enr312.level.soundSpeed(35);
    say(['HC-SR04: the Arduino sends a 10 us trigger, the module emits 8 pulses at 40 kHz and holds ECHO high for the ' ...
         'round-trip time t. Distance to the water d = v t / 2; **level = (sensor-to-floor) - d**. v = 331 + 0.6 T: ' ...
         '%.1f m/s at 20 C, %.1f m/s at 35 C (+%.2f %%).'], v20, v35, 100 * (v35 / v20 - 1));
    lv = [0 Lmin 50 Lmax 100] / 100 * Hcm;
    [~, err] = enr312.level.soundSpeed(35, 20, 100 * P.h_sensor, lv);
    N.soundSpeed = struct('v20', v20, 'v35', v35, 'level_cm', lv, 'error_cm', err);
    say('| true level | distance to water | reading if code assumes 20 C, room 35 C | error |'); say('|---|---|---|---|');
    for i = 1:numel(lv), say('| %.1f cm (%.0f %%) | %.1f cm | %.2f cm | **+%.2f cm (%.1f %% of tank)** |', ...
            lv(i), 100 * lv(i) / Hcm, 100 * P.h_sensor - lv(i), lv(i) + err(i), err(i), 100 * err(i) / Hcm); end
    say(['The error grows with the distance (empty tank worst). Firmware: `$CAL,1,<sensor_to_floor>,<full_height>,<air C>` ' ...
         'uses v(T); the host test checks a 35 C room: 1.85 %% error uncorrected, 0.10 %% corrected.']);
    say('');

    % ================================================================== S3-2
    say('## S3-2 Sensor calibration (procedure, simulated sensor)');
    rs = RandStream('mt19937ar', 'Seed', 3);
    ruler = [3 6 10 14 18 22]';                     % cm
    reading = arrayfun(@(h) mean(round((h + P.noise_us * 100 * randn(rs, 30, 1)) / (100 * P.res_us)) * 100 * P.res_us), ruler);
    staticR = round((12 + P.noise_us * 100 * randn(rs, 300, 1)) / (100 * P.res_us)) * 100 * P.res_us;
    cal = enr312.level.calibrate(ruler, reading, staticR);
    N.cal = rmfield(cal, 'correct');
    say('| ruler (cm) | mean reading (cm) | residual after fit (cm) |'); say('|---|---|---|');
    for i = 1:numel(ruler), say('| %.1f | %.2f | %+.2f |', ruler(i), reading(i), cal.residuals(i)); end
    say(['Fit reading = %.4f x ruler %+.3f cm; max error %.2f cm, RMSE %.2f cm; static noise (30 s at one level) ' ...
         'std = **%.2f cm** (SIMULATION: model noise %.1f mm, resolution %.0f mm). On the rig: hold the level at 5+ ruler marks, ' ...
         'record 30 s each in the app, run `enr312.level.calibrate`. Template: `docs/experiments/water_level/calibration_template.csv`. PENDING-HW.'], ...
         cal.a, cal.b, cal.maxErr, cal.rmse, cal.noise, 1000 * P.noise_us, 1000 * P.res_us);
    say('');

    % ================================================================== S3-3 / 4 / 5
    say('## S3-3 / S3-4 / S3-5 Flows, ON/OFF times, overshoot (ON-OFF 30-80 %%)');
    c = base; c.h0 = 10; c.Tend = 1800;
    S = enr312.level.simulate(c);
    k = S.t > 60;
    r = enr312.level.cycleAnalysis(S.t(k), S.meas(k) / 100 * Hcm, S.u(k) > 0, P.A, Lmax / 100 * Hcm);
    band = (Lmax - Lmin) / 100 * Hcm;
    Ton = Acm2 * band / (r.Qin_mL_s - r.Qout_mL_s); Toff = Acm2 * band / r.Qout_mL_s;
    N.cycles = r; N.cycles.Ton_pred_s = Ton; N.cycles.Toff_pred_s = Toff;
    fig = figure('Visible', 'off', 'Position', [0 0 1000 420]);
    plot(S.t, S.meas, 'LineWidth', 1.1); hold on; stairs(S.t, 100 * (S.u > 0), 'Color', [0.8 0.4 0.1]);
    yline([Lmin Lmax], 'k:'); xlabel('t (s)'); ylabel('level %% / pump'); grid on; legend('level (sensor)', 'pump ON = 100', 'Location', 'southeast');
    title('S3-3 SIMULATION: ON-OFF 30-80 %'); xlim([0 S.t(end)]);
    saveFig(fig, 'fig_S3-3_onoff_cycles');
    say('| quantity | value |'); say('|---|---|');
    say('| rise rate, pump ON | %.3f cm/s |', r.rise_cm_s);
    say('| fall rate, pump OFF | %.3f cm/s |', r.fall_cm_s);
    say('| Q_out = A x fall rate | **%.1f mL/s** |', r.Qout_mL_s);
    say('| Q_in = A x rise rate + Q_out | **%.1f mL/s** (model pump %.1f mL/s) |', r.Qin_mL_s, P.Q_max * 1e6);
    say('| T_on predicted A (Lmax-Lmin)/(Q_in-Q_out) | %.0f s |', Ton);
    say('| T_on measured | %.0f s |', r.Ton_s);
    say('| T_off predicted A (Lmax-Lmin)/Q_out | %.0f s |', Toff);
    say('| T_off measured | %.0f s |', r.Toff_s);
    say('| overshoot above Lmax after switch-off | %.2f cm |', r.overshoot_cm);
    say(['The formulas assume constant flows. With a gravity outlet Q_out = k sqrt(h) is larger near Lmax and smaller ' ...
         'near Lmin, so the slopes (and the predictions) are averages - the predicted and "measured" times differ by that much. ' ...
         'Overshoot: after the relay opens the pump keeps delivering for the relay + pipe delay and its spin-down ' ...
         '(model: %.1f s + %.1f s), plus surface ripples and the 0.1 s sensor update. PENDING-HW: run "On-off 30-80 %%" and ' ...
         'apply `enr312.level.cycleAnalysis` to the raw file.'], P.delay, P.tau_pump);
    say('');

    % ================================================================== S3-6
    say('## S3-6 Band width, switching frequency, chattering');
    widths = [50 25 10 5 2 1 0.5 0.25];
    rows = {};
    for wdt = widths
        c = base; c.Lmin = 55 - wdt / 2; c.Lmax = 55 + wdt / 2; c.h0 = 50; c.Tend = 1200;
        S = enr312.level.simulate(c);
        rows(end + 1, :) = {wdt, S.metrics.starts_per_hour, S.metrics.cycle_period}; %#ok<AGROW>
    end
    T6 = cell2table(rows, 'VariableNames', {'band_pct', 'starts_per_hour', 'period_s'});
    writetable(T6, fullfile(D, 'data_S3-6_band.csv')); N.band = table2struct(T6);
    noisePct = 100 * P.noise_us / P.H;
    say('| band Lmax - Lmin | pump starts / hour | cycle period |'); say('|---|---|---|');
    for i = 1:height(T6), say('| %.2f %% (%.1f mm) | %.0f | %.1f s |', T6.band_pct(i), 10 * T6.band_pct(i) / 100 * Hcm, T6.starts_per_hour(i), T6.period_s(i)); end
    fig = figure('Visible', 'off', 'Position', [0 0 760 420]);
    loglog(T6.band_pct, T6.starts_per_hour, 'o-', 'LineWidth', 1.4); grid on;
    xline(6 * noisePct, 'r--', '6 sigma of the sensor noise'); xlabel('band Lmax - Lmin (%)'); ylabel('pump starts per hour');
    title('S3-6 SIMULATION: switching frequency vs band');
    saveFig(fig, 'fig_S3-6_band');
    say(['Halving the band roughly doubles the switching frequency (the tank needs half the time to cross it). Once the ' ...
         'band approaches the sensor noise (here sigma = %.2f %% = %.1f mm, so 6 sigma = %.1f %%) single noisy readings cross ' ...
         'both thresholds and the relay chatters - the count jumps far above the 1/band trend. A relay rated for ~10^5 ' ...
         'switching operations lasts %.0f h at the 30-80 %% band but only %.0f h at the narrowest band (and pump starts wear ' ...
         'the motor too). Use a band well above the noise, plus a filter or a minimum on/off time.'], ...
         noisePct, 1000 * P.noise_us, 6 * noisePct, 1e5 / max(T6.starts_per_hour(1), eps), 1e5 / max(T6.starts_per_hour(end), eps));
    say('');

    % ================================================================== S3-7
    say('## S3-7 Task-6 Simulink model (Relay block, constant outflow) tuned to the cycle period');
    c = base; c.h0 = 10; c.Tend = 1800; Sref = enr312.level.simulate(c);
    refPeriod = Sref.metrics.cycle_period;
    cs = c; cs.outflow = 'constant'; cs.Qout = r.Qout_mL_s * 60 / 1000;     % L/min
    simPeriod = @(q) periodOf(run_level_simulink(setfield(cs, 'Qout', q)), cs); %#ok<SFLD>
    p0 = simPeriod(cs.Qout);
    qBest = fminbnd(@(q) (simPeriod(q) - refPeriod)^2, 0.3 * cs.Qout, 0.95 * P.Q_max * 60000);
    p1 = simPeriod(qBest);
    N.task6 = struct('ref_period_s', refPeriod, 'Qout_from_S33_L_min', cs.Qout, 'period_untuned_s', p0, 'Qout_tuned_L_min', qBest, 'period_tuned_s', p1);
    say(['Simulink `enr312_water_level.slx`, Relay block (pump OFF at Lmax, ON at Lmin), integrator tank, constant outflow ' ...
         '(outGravity = 0). With A, Q_in from S3-3 and Q_out = %.2f L/min the period is %.0f s against %.0f s for the ' ...
         '"hardware" (here: the MATLAB model with the gravity outlet). Tuning Q_out to **%.2f L/min** gives **%.0f s vs %.0f s**. ' ...
         'On the rig, do the same with the measured period (PENDING-HW).'], cs.Qout, p0, refPeriod, qBest, p1, refPeriod);
    say('');

    % ================================================================== S3-8
    say('## S3-8 Nonlinear outflow, PI on a PWM pump: set-point step, extra drain, windup');
    c = base; c.mode = 'PI'; c.Kp = 20; c.Ki = 0.5; c.h0 = 30; c.setpoint = 60; c.drainFactor = 1.15; c.tDrain = 500; c.Tend = 1000;
    fig = figure('Visible', 'off', 'Position', [0 0 1000 560]); rows = {};
    for aw = [true false]
        c.antiWindup = aw;
        S = enr312.level.simulate(c);
        subplot(2, 1, 1); plot(S.t, S.level, 'LineWidth', 1.3); hold on;
        subplot(2, 1, 2); plot(S.t, S.u, 'LineWidth', 1.1); hold on;
        rows(end + 1, :) = {aw, S.metrics.overshoot, S.metrics.settle, S.metrics.error_after_drain, string(S.guard)}; %#ok<AGROW>
    end
    subplot(2, 1, 1); yline(60, 'k:'); xline(500, 'k--', 'outlet opened 1.15x'); ylabel('level %'); grid on;
    legend('PI with clamping', 'PI, plain integrator', 'Location', 'southeast'); title('S3-8 SIMULATION: gravity outflow, PWM pump, setpoint 30 \rightarrow 60 %');
    subplot(2, 1, 2); ylabel('u (PWM 0-255)'); xlabel('t (s)'); grid on;
    saveFig(fig, 'fig_S3-8_PI_windup');
    T8 = cell2table(rows, 'VariableNames', {'antiWindup', 'overshoot_pct', 'settle_s', 'error_after_drain_pct', 'guard'}); N.PI = table2struct(T8);
    say('| PI | overshoot | settling (2 %%) | error after the extra drain | guard |'); say('|---|---|---|---|---|');
    for i = 1:height(T8), say('| %s | %.1f %% | %.0f s | %.2f %% | %s |', ternary(T8.antiWindup(i), 'clamping', 'plain integrator'), T8.overshoot_pct(i), T8.settle_s(i), T8.error_after_drain_pct(i), ternary(strlength(T8.guard(i)) == 0, 'none', T8.guard(i))); end
    say(['The PI holds the level after the extra drain (integral action finds the new pump speed). During the 30 -> 60 %% ' ...
         'step the pump runs at full speed (u = 255) for a long time: with a plain integrator the error keeps accumulating, ' ...
         'so the level overshoots and settles later - **windup appears**; clamping prevents it. If the extra drain exceeds ' ...
         'the pump''s maximum flow (here a 1.4x drain at 60 %%), no controller can hold the level: the pump runs flat out, the ' ...
         'level falls, and the dry-run interlock stops the pump after 60 s.']);
    say('');

    % ================================================================== S3-9
    say('## S3-9 Linearisation and time constants');
    hs = [Lmin Lmax] / 100 * P.H;                 % m
    tau = 2 * P.A * sqrt(hs) / P.k_out; Kss = 2 * sqrt(hs) / P.k_out;
    N.linear = struct('h_cm', 100 * hs, 'tau_s', tau, 'K_cm_per_mL_s', Kss * 100 / 1e6);
    say(['A dh/dt = Q_in - k sqrt(h), k = a sqrt(2g). Around h0: sqrt(h) ~ sqrt(h0) + (h - h0)/(2 sqrt(h0)), so with ' ...
         'deviations: A d(dh)/dt = dQ_in - k/(2 sqrt(h0)) dh  ->  **dh/dQ_in = K/(tau s + 1)**, K = 2 sqrt(h0)/k, ' ...
         '**tau = 2 A sqrt(h0)/k**.']);
    say('| level | tau | gain K |'); say('|---|---|---|');
    for i = 1:2, say('| %.1f cm (%.0f %%) | **%.0f s** | %.3f cm per mL/s |', 100 * hs(i), 100 * hs(i) / P.H, tau(i), N.linear.K_cm_per_mL_s(i)); end
    say(['tau grows with sqrt(h0): the outflow changes less per cm of level when the tank is fuller, so the tank is slower ' ...
         'at Lmax than at Lmin (ASSUMED k; on the rig use k = Q_out/sqrt(h) from S3-3).']);
    say('');

    % ================================================================== S3-10
    say('## S3-10 Self-regulating or integrating?');
    rows = {};
    for of = {'gravity', 'constant'}
        cc = base; cc.mode = 'P'; cc.Kp = 20; cc.h0 = 30; cc.setpoint = 60; cc.Tend = 900; cc.outflow = of{1}; cc.Qout = 1.5;
        S = enr312.level.simulate(cc);
        rows(end + 1, :) = {of{1}, S.metrics.ss_error}; %#ok<AGROW>
    end
    say(['A free outlet (water leaves by gravity, Q_out = k sqrt(h)) is **self-regulating**: with a fixed pump speed the ' ...
         'level settles where outflow = inflow. A pumped/constant outflow makes the tank a **pure integrator**: any ' ...
         'mismatch makes the level rise or fall for ever. Which one our rig is depends on its outlet: **UNVERIFIED** - ' ...
         'look at the rig (an open drain hole or tube = self-regulating). P control: in both cases the pump must keep ' ...
         'delivering the outflow, which needs a non-zero error u = Kp e, so P alone leaves an offset ' ...
         '(simulation, Kp 20, 60 %%: %s %.2f %%, %s %.2f %%); it can hold a level only if the outflow is zero. PI removes it.'], ...
         rows{1, 1}, rows{1, 2}, rows{2, 1}, rows{2, 2});
    say('');

    % ================================================================== S3-11
    say('## S3-11 Interlock: dry run and overflow');
    say('| level reading | float switch | pump commanded >= 200/255 for 60 s with < 2 %% rise | sensor fails 5 pings | host silent 3 s | pump |');
    say('|---|---|---|---|---|---|');
    say('| > 92 %% | any | any | - | - | **OFF** (overflow limit) |');
    say('| any | closed (water at top) | any | - | - | **OFF** (hardware overflow switch) |');
    say('| <= 92 %% | open | **yes** | - | - | **OFF, latched** (dry run / blocked pipe) until STOP |');
    say('| - | - | - | **yes** | - | **OFF, latched** |');
    say('| - | - | - | - | **yes** | **OFF** |');
    say('| <= 92 %% | open | no | no | no | controller output |');
    say('This is what `level_controller.ino` implements (host test: water_level/tests, all guards checked).');
    c = base; c.h0 = 10; c.pumpFailAt = 200; c.Tend = 700;
    S = enr312.level.simulate(c);
    N.dryRun = struct('guard', S.guard, 'pump_fail_s', 200);
    fig = figure('Visible', 'off', 'Position', [0 0 1000 420]);
    plot(S.t, S.meas, 'LineWidth', 1.2); hold on; stairs(S.t, 100 * (S.u > 0)); xline(200, 'k--', 'water supply fails');
    ylabel('level % / pump'); xlabel('t (s)'); grid on; legend('level', 'pump ON = 100'); title(sprintf('S3-11 SIMULATION: dry-run interlock -> %s', S.guard));
    saveFig(fig, 'fig_S3-11_dry_run');
    say('');

    % ================================================================== S3-12
    say('## S3-12 Why hardware and Simulink differ (to be filled with measured evidence)');
    say(['Expected, each to be shown from the data: (1) pump flow depends on head and supply voltage, not constant ' ...
         '(compare rise rates at low and high level); (2) relay + pipe delay and pump run-down -> overshoot above Lmax (S3-5); ' ...
         '(3) ultrasonic noise from ripples and the 3 mm resolution (static std, S3-2); (4) outflow is not constant (fall ' ...
         'rate vs level); (5) speed of sound vs room temperature (S3-1). PENDING-HW.']);
    say('');
    say('## Pending hardware runs (enr312_water, on the rig)');
    say('Calibration at 5+ ruler levels; On-off 30-80 % (3+ cycles); narrow band 50-55 %; drain-opened run; P and PI with the MOSFET wiring (S3-8 on hardware is optional: the handout asks for simulation).');

    writelines(string(md), fullfile(D, 'summary.md'));
    fid = fopen(fullfile(D, 'numbers.json'), 'w'); fwrite(fid, jsonencode(N, 'PrettyPrint', true)); fclose(fid);
    cfgOut = struct('run_id', runId, 'data_class', 'SIMULATION', 'matlab', version, 'simulink', ver('simulink').Version, ...
                    'params_status', 'ASSUMED tank and pump (enr312.level.params)');
    fid = fopen(fullfile(D, 'run_config.json'), 'w'); fwrite(fid, jsonencode(cfgOut, 'PrettyPrint', true)); fclose(fid);
    doc = strrep(string(md), '(fig_', sprintf('(../../../results/evidence/simulation_runs/water_level/%s/fig_', runId));
    doc = ["<!-- GENERATED by matlab/scripts/water_course_questions.m - do not edit; rerun the script -->", doc];
    dd = fullfile(root, 'docs', 'experiments', 'water_level'); if ~exist(dd, 'dir'), mkdir(dd); end
    writelines(doc, fullfile(dd, 'COURSE_SIM_RESULTS.md'));
    out = struct('runId', runId, 'dir', D, 'numbers', N);
    fprintf('water course questions -> %s\n', D);

    function saveFig(f, name)
        try, theme(f, 'light'); catch, end
        exportgraphics(f, fullfile(D, [name '.png']), 'Resolution', 110); close(f);
        md{end + 1} = sprintf('![%s](%s.png)', name, name);
    end
end

function p = periodOf(R, c)
    on = [false; false];   %#ok<NASGU>
    k = R.t > 60;
    m = R.meas(k); t = R.t(k);
    % pump turns on when the level crosses Lmin going down: count those crossings
    cross = t([false; m(2:end) < c.Lmin & m(1:end - 1) >= c.Lmin]);
    if numel(cross) >= 2, p = mean(diff(cross)); else, p = 1e4; end
end

function v = ternary(c, a, b)
    if c, v = a; else, v = b; end
end
