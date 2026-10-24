function out = temperature_course_questions()
%TEMPERATURE_COURSE_QUESTIONS  Simulation / analysis answers for the ENR312 TEMP handout (SRC-015).
%
%   out = temperature_course_questions()
%
%   Uses enr312.temperature.simulate (MATLAB, with the zero-cross SSR) and enr312_temperature.slx
%   (Simulink). The thermal constants are ESTIMATED until the heater-step run (STEP mode) is done on
%   the rig; then put the fitted K, tau, theta into params (or enr312.temperature.withFOPDT) and rerun.
%   Writes results/evidence/simulation_runs/temperature/TEMP-COURSE-SIM-<stamp>/ and refreshes
%   docs/experiments/temperature/COURSE_SIM_RESULTS.md (generated).

    here = fileparts(mfilename('fullpath'));
    run(fullfile(here, '..', 'setup_enr312.m'));
    addpath(fullfile(here, '..', 'models', 'temperature'));
    root = enr312.repoRoot();
    outRoot = fullfile(root, 'results', 'evidence', 'simulation_runs', 'temperature');
    runId = enr312.newRunId('TEMP-COURSE-SIM', @(id) exist(fullfile(outRoot, id), 'file'));
    D = fullfile(outRoot, runId); mkdir(D);
    P = enr312.temperature.params();
    N = struct(); md = {};
    say = @(varargin) addLine(sprintf(varargin{:}));
    function addLine(s), md{end + 1} = s; end
    base = enr312.temperature.defaultConfig();        % DHT11, pwm490 SSR, ESTIMATED plant

    say('# ENR312 TEMP handout: simulation and analysis results');
    say('');
    say('Run `%s`, generated %s by `matlab/scripts/temperature_course_questions.m` (MATLAB %s, Simulink %s).', ...
        runId, char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')), version, ver('simulink').Version);
    say(['Data class: **SIMULATION** with ESTIMATED thermal constants (60 W bulb, R %.2f K/W, C %.0f J/K, delay %.0f s, ' ...
         'ambient %.0f C). Every hardware question is listed as PENDING with the run to make. Sensor: DHT11.'], ...
         P.R_th, P.C_th, P.delay, P.T_amb);
    say('Figures/CSV: `results/evidence/simulation_runs/temperature/%s/`.', runId);
    say('');

    % ================================================================== S3-1
    say('## S3-1 DHT11 datasheet values');
    say('| quantity | DHT11 | DHT22 (AM2302) |'); say('|---|---|---|');
    say('| temperature range | %g to %g C | %g to %g C |', P.range_dht11, P.range_dht22);
    say('| resolution | %g C | %g C |', P.res_dht11, P.res_dht22);
    say('| accuracy | +/- %g C | +/- %g C |', P.acc_dht11, P.acc_dht22);
    say('| minimum time between readings | %g s | %g s |', P.per_dht11, P.per_dht22);
    say(['Values are the commonly published Aosong datasheet figures, status UNVERIFIED until the datasheet is filed (SRC-009). ' ...
         '**55 C is outside the DHT11''s rated 0-50 C**: above 50 C the reading is not specified, so at the 55 C setpoint ' ...
         'trust it at best to +/- 2 C plus an unknown extrapolation error; check it against a thermometer (PENDING-HW).']);
    say('');

    % ================================================================== S3-2 / S3-3
    say('## S3-2 / S3-3 Moving-average windows: span, distinct readings, delay');
    Ts = P.Ts; W = [10 500];
    span = W * Ts; vals = floor(span / P.per_dht11) + 1; del = (W - 1) * Ts / 2;
    N.ma = struct('N', W, 'span_s', span, 'distinct_values_max', vals, 'delay_s', del);
    say('| N | span N x Ts | distinct DHT11 readings in the window | delay (N-1) Ts / 2 |'); say('|---|---|---|---|');
    note = {'1, occasionally 2 (a new reading every 1 s)', 'up to 6'};
    for i = 1:2, say('| %d | %.2f s | %s | %.3f s |', W(i), span(i), note{i}, del(i)); end
    say(['N = 10 spans 0.1 s, but the DHT11 gives a new value only once per second: the window almost always holds ' ...
         '10 copies of the SAME reading, so the average equals the reading and nothing is filtered - flicker unchanged. ' ...
         'N = 500 spans 5 s = 5-6 different readings: the average moves in small steps between them, so the on/off ' ...
         'decision changes less often, at the price of a 2.5 s delay.']);
    rows = {};
    fig = figure('Visible', 'off', 'Position', [0 0 1000 450]); hold on;
    for cfgName = {'On-off, 45 C', 'Moving average N = 10, 45 C', 'Moving average N = 500, 45 C'}
        c = enr312.temperature.presetConfig(cfgName{1}); c.Tend = 900;
        S = enr312.temperature.simulate(c); m = S.metrics;
        rows(end + 1, :) = {cfgName{1}, m.overshoot, m.band_pp, m.switches_per_min}; %#ok<AGROW>
        plot(S.t, S.T, 'LineWidth', 1.2, 'DisplayName', [cfgName{1} ' (zone T)']);
    end
    yline(45, 'k:', 'HandleVisibility', 'off'); xlabel('t (s)'); ylabel('C'); grid on; legend('Location', 'southeast'); xlim([0 900]);
    title('S3-3 SIMULATION: overshoot and band with the moving-average filter');
    saveFig(fig, 'fig_S3-3_moving_average');
    Tma = cell2table(rows, 'VariableNames', {'case', 'overshoot_C', 'band_pp_C', 'switches_per_min'});
    writetable(Tma, fullfile(D, 'data_S3-3_moving_average.csv')); N.maSim = table2struct(Tma);
    say('| case | overshoot (C) | band p-p (C) | switches/min |'); say('|---|---|---|---|');
    for i = 1:height(Tma), say('| %s | %.2f | %.2f | %.1f |', Tma.case{i}, Tma.overshoot_C(i), Tma.band_pp_C(i), Tma.switches_per_min(i)); end
    say('The 2.5 s filter delay adds to the bulb-to-sensor delay: the heater stays on longer after the true temperature passes 45 C, so the overshoot grows (SIMULATION; hardware: TEMP-03/04 runs PENDING).');
    say('');

    % ================================================================== S3-4
    say('## S3-4 ON-OFF at 35 / 45 / 55 C: swing and switching period');
    rows = {};
    for sp = [35 45 55]
        c = base; c.setpoint = sp; c.Tend = 1500;
        S = enr312.temperature.simulate(c);
        [pp, per] = swingPeriod(S, 0.5);
        rows(end + 1, :) = {sp, pp, per, S.metrics.switches_per_min, S.metrics.duty}; %#ok<AGROW>
    end
    T4 = cell2table(rows, 'VariableNames', {'setpoint_C', 'swing_pp_C', 'period_s', 'switches_per_min', 'duty'});
    writetable(T4, fullfile(D, 'data_S3-4_onoff_table.csv')); N.onoff = table2struct(T4);
    say('| setpoint | swing p-p (reading) | switching period | switches/min | heater duty |'); say('|---|---|---|---|---|');
    for i = 1:height(T4), say('| %g C | %.1f C | %.1f s | %.1f | %.0f %% |', T4.setpoint_C(i), T4.swing_pp_C(i), T4.period_s(i), T4.switches_per_min(i), 100 * T4.duty(i)); end
    say(['Trend: the higher the setpoint, the closer it is to the bulb''s maximum (ambient + %.0f C), so heating is slower ' ...
         'and cooling faster near it - the duty rises and the ON part of each cycle gets longer. With the 1 C DHT11 steps ' ...
         'the swing is never below one or two steps. Hardware: run On-off 35 / 45 / 55 C (PENDING-HW).'], P.eta_heat * P.P_bulb * P.R_th);
    say('');

    % ================================================================== S3-5
    say('## S3-5 First-order-plus-dead-time model from the heating curve');
    c = enr312.temperature.presetConfig('Heater step: full ON to 55 C, then cool (K, tau, theta)');
    c.setpoint = 65; c.Tend = 1500;                       % 65 C = firmware maximum setpoint (cut-off 70 C)
    S = enr312.temperature.simulate(c);
    kOff = find(S.heat < 0.5, 1);
    th = S.t(1:kOff - 1); yh = S.Traw(1:kOff - 1);
    f = enr312.ident.fitFOPDT(th, yh, 255);
    N.fopdt = struct('K_C_per_count', f.K, 'K_full_C', f.K * 255, 'tau_s', f.tau, 'theta_s', f.theta, 'rmse_C', f.rmse, ...
                     'true_K_full_C', P.eta_heat * P.P_bulb * P.R_th, 'true_tau_s', P.R_th * P.C_th, 'true_delay_s', P.delay, 'sensor_lag_s', P.tau_dht11);
    tc = S.t(kOff:end) - S.t(kOff); yc = S.Traw(kOff:end);
    fc = enr312.ident.fitFOPDT(tc, yc, -1, struct('theta', 0));
    N.cooling = struct('tau_s', fc.tau);
    fig = figure('Visible', 'off', 'Position', [0 0 1000 450]);
    plot(S.t, S.Traw, '.', 'MarkerSize', 5, 'DisplayName', 'DHT11 reading'); hold on;
    plot(th, f.fit, 'LineWidth', 1.6, 'DisplayName', sprintf('FOPDT fit: K = %.1f C, tau = %.0f s, theta = %.1f s', 255 * f.K, f.tau, f.theta));
    xline(S.t(kOff), 'k:', 'heater OFF'); xlabel('t (s)'); ylabel('C'); grid on; legend('Location', 'east');
    title('S3-5 SIMULATION: heater step (full ON from ambient), then cooling');
    saveFig(fig, 'fig_S3-5_heater_step');
    say(['Procedure (works the same on the rig with the "Heater step" preset): K = (T_final - T_start)/du, read where the ' ...
         'curve flattens; theta = time before the reading starts to rise; tau = time from theta to 63 %% of the rise. ' ...
         'With the curve cut off at 65 C (safety), K comes from the least-squares fit: **K = %.1f C at full power ' ...
         '(%.3f C per PWM count), tau = %.0f s, theta = %.1f s** (RMSE %.2f C). The model behind it has K = %.0f C, ' ...
         'tau = %.0f s, a %.0f s transport delay and a %.0f s sensor lag - the fit lumps the lag into tau and theta.'], ...
         255 * f.K, f.K, f.tau, f.theta, f.rmse, N.fopdt.true_K_full_C, N.fopdt.true_tau_s, P.delay, P.tau_dht11);
    say(['Cooling (heater OFF): fitted tau = %.0f s. In a single-R model heating and cooling share tau, but the rate ' ...
         'differs: heating is driven by the full bulb power (slope K/tau at the start), cooling only by the losses, ' ...
         'which shrink as the temperature falls towards ambient. On the rig cooling is usually slower still because ' ...
         'the bulb, holder and enclosure keep releasing stored heat. Measurement **PENDING-HW** ("Heater step" preset).'], fc.tau);
    say('');

    % ================================================================== S3-6
    say('## S3-6 PWM (490 Hz) into a zero-cross SSR (50 Hz mains)');
    fp = P.pwm_hz; fz = 2 * P.mains_hz; tz = (0:1 / fz:2)';            % zero crossings over 2 s
    u = 128; ph = 0.37;
    on = mod(tz * fp + ph, 1) < u / 255;
    N.ssr = struct('u', u, 'fraction_on', mean(on), 'beat_Hz', abs(fp - 5 * fz));
    uu = 0:255; frac = arrayfun(@(v) mean(mod(tz * fp + ph, 1) < v / 255), uu);
    fig = figure('Visible', 'off', 'Position', [0 0 1100 520]);
    subplot(2, 1, 1); stairs(tz(1:61), double(on(1:61)), 'LineWidth', 1.4); ylim([-0.2 1.2]); grid on;
    xlabel('t (s)'); ylabel('half-cycle ON'); title(sprintf('u = 128: half-cycles the bulb receives (%.0f %% on, pattern repeats at %.1f Hz)', 100 * mean(on), N.ssr.beat_Hz));
    subplot(2, 1, 2); plot(uu, frac, 'LineWidth', 1.4); hold on; plot(uu, uu / 255, 'k:'); grid on;
    xlabel('u (0..255)'); ylabel('power fraction delivered'); legend('zero-cross SSR, 2 s average', 'ideal u/255', 'Location', 'northwest');
    saveFig(fig, 'fig_S3-6_ssr_zero_cross');
    say(['A zero-cross SSR can only turn on at a mains zero crossing (every 10 ms) and stays on for that half-cycle. ' ...
         'analogWrite(9, 128) is a 490 Hz square wave (2 ms period), so at each crossing the SSR sees whatever the PWM ' ...
         'happens to be: about half the half-cycles are ON (%.0f %% here), but in a pattern set by the beat between ' ...
         '490.2 Hz and 5 x 100 Hz = **%.1f Hz**: runs of ON and OFF half-cycles that the eye sees as flicker. When the ' ...
         'error is near 0 the P output is small and keeps changing, so the pattern changes all the time - intense flicker. ' ...
         'Use time-proportioning (TPROP mode, one switch per 2 s) or a phase-angle (random-turn-on) SSR for real proportional power.'], ...
         100 * mean(on), N.ssr.beat_Hz);
    say('');

    % ================================================================== S3-7
    say('## S3-7 Control signal for e = 10 C and e = 1 C');
    Kps = [1 2 50 100 500];
    say('| Kp | u at e = 10 C | u at e = 1 C | saturated? |'); say('|---|---|---|---|');
    for Kp = Kps
        u10 = min(255, Kp * 10); u1 = min(255, Kp * 1);
        sat = ''; if Kp * 10 > 255, sat = 'at 10 C'; end
        if Kp * 1 > 255, sat = 'at 10 C and 1 C'; end
        say('| %g | %g | %g | %s |', Kp, u10, u1, sat);
    end
    say(['With Kp = 500 even a 1 C error asks for 500 -> clamped to 255 and any error < 0 gives 0: the output is 255 or 0 ' ...
         'except within 0.5 C of the setpoint, and the DHT11 reads in 1 C steps, so it never sits in between - it is ON-OFF control.']);
    say('');

    % ================================================================== S3-8 / S3-9
    say('## S3-8 / S3-9 Simulink model with K, tau, theta; hysteresis');
    cF = enr312.temperature.withFOPDT(base, 255 * f.K, f.tau, f.theta);
    rows = {};
    for mode = {'ONOFF', 'HYST'}
        c = cF; c.mode = mode{1}; c.hyst = 1; c.ssr = 'average'; c.Tend = 1500;
        Sm = enr312.temperature.simulate(c);
        R = run_temperature_simulink(c);
        Sl = struct('t', R.t, 'Traw', R.reading, 'heat', R.heat);
        [pp, per] = swingPeriod(Sm, 0.5); [pp2, per2] = swingPeriod(Sl, 0.5);
        rows(end + 1, :) = {mode{1}, pp, per, Sm.metrics.switches_per_min, pp2, per2, switchesPerMin(Sl)}; %#ok<AGROW>
    end
    T8 = cell2table(rows, 'VariableNames', {'mode', 'matlab_swing_C', 'matlab_period_s', 'matlab_switches_per_min', ...
                                           'simulink_swing_C', 'simulink_period_s', 'simulink_switches_per_min'});
    writetable(T8, fullfile(D, 'data_S3-8_simulink_onoff_hyst.csv')); N.simulinkFOPDT = table2struct(T8);
    say('Model: `matlab/models/temperature/enr312_temperature.slx` set from the fitted K, tau, theta (`enr312.temperature.withFOPDT`), DHT11 1 C resolution and 1 s update, 45 C.');
    say('| control | MATLAB swing | MATLAB period | MATLAB switches/min | Simulink swing | Simulink period | Simulink switches/min |'); say('|---|---|---|---|---|---|---|');
    for i = 1:height(T8), say('| %s | %.1f C | %.1f s | %.1f | %.1f C | %.1f s | %.1f |', T8.mode{i}, T8.matlab_swing_C(i), T8.matlab_period_s(i), ...
            T8.matlab_switches_per_min(i), T8.simulink_swing_C(i), T8.simulink_period_s(i), T8.simulink_switches_per_min(i)); end
    say(['Hysteresis +/-0.5 C (band 1 C): the heater waits for the reading to leave the band, so with 1 C sensor steps it ' ...
         'stops reacting to single-step jitter - fewer switches per minute, slightly larger swing. Arduino: mode HYST, ' ...
         'band 1 C (already in the firmware). Compare with measured values: PENDING-HW (On-off 45 C and hysteresis presets).']);
    say('');

    % ================================================================== S3-10
    say('## S3-10 P control: steady-state error');
    K = P.eta_heat * P.P_bulb * P.R_th / 255;            % C per PWM count
    N.Kplant = K;
    say(['Plant (deviation from ambient): dT = K u / (tau s + 1), u = Kp e, e = r - T. At steady state dT = K Kp e, and ' ...
         'r - T_a = e + dT = e (1 + K Kp), so **e_ss = (r - T_a)/(1 + K Kp)** (r measured from ambient). ' ...
         'K = %.3f C per count (ESTIMATED; from the step fit on the rig).'], K);
    say('| Kp | predicted e_ss at 45 C | simulated, average SSR | simulated, zero-cross SSR |'); say('|---|---|---|---|');
    rows = {};
    for Kp = Kps
        c = base; c.mode = 'P'; c.Kp = Kp; c.Tend = 1800; c.ssr = 'average';
        Sa = enr312.temperature.simulate(c); c.ssr = 'pwm490'; Sp = enr312.temperature.simulate(c);
        e = (45 - P.T_amb) / (1 + K * Kp);
        rows(end + 1, :) = {Kp, e, Sa.metrics.mean_error, Sp.metrics.mean_error}; %#ok<AGROW>
        say('| %g | %.2f C | %.2f C | %.2f C |', Kp, e, Sa.metrics.mean_error, Sp.metrics.mean_error);
    end
    T10 = cell2table(rows, 'VariableNames', {'Kp', 'predicted_C', 'sim_average_C', 'sim_zero_cross_C'});
    writetable(T10, fullfile(D, 'data_S3-10_P_error.csv')); N.Perror = table2struct(T10);
    say('For large Kp the formula predicts < 1 C but the 1 C sensor steps and the delay make the loop oscillate (limit cycle) instead: compare the mean, not a single reading. Measured: PENDING-HW (P Kp presets).');
    say('');

    % ================================================================== S3-11
    say('## S3-11 Limit cycle and dead time');
    dels = [0 2 4 8 12]; rows = {};
    for dd = dels
        c = base; c.ssr = 'average'; c.Tend = 1500; c.P.delay = dd; c.P.noise = 0;
        S = enr312.temperature.simulate(c);
        pp = max(S.T(S.t > 900)) - min(S.T(S.t > 900));
        rows(end + 1, :) = {dd, pp}; %#ok<AGROW>
    end
    T11 = cell2table(rows, 'VariableNames', {'delay_s', 'zone_swing_pp_C'}); N.limitCycle = table2struct(T11);
    writetable(T11, fullfile(D, 'data_S3-11_limit_cycle.csv'));
    fig = figure('Visible', 'off', 'Position', [0 0 700 420]);
    plot(T11.delay_s, T11.zone_swing_pp_C, 'o-', 'LineWidth', 1.4); grid on;
    xlabel('bulb-to-sensor dead time theta (s)'); ylabel('zone temperature swing p-p (C)'); title('S3-11 SIMULATION: ON-OFF limit cycle grows with dead time');
    saveFig(fig, 'fig_S3-11_limit_cycle');
    say(['ON-OFF has no "middle" output: the heater is either full on or off, so the temperature must keep moving; it ' ...
         'can only reverse after the reading crosses the setpoint, and the reading arrives theta seconds late. During ' ...
         'that time the temperature keeps rising at about (heating slope) x theta above, and falling at (cooling slope) x ' ...
         'theta below: a steady oscillation whose size grows with theta (table/figure: %.1f C p-p at 0 s, %.1f C at %g s; ' ...
         'the remaining swing at 0 s comes from the sensor lag and the 1 C steps).'], T11.zone_swing_pp_C(1), T11.zone_swing_pp_C(end), dels(end));
    say('');

    % ================================================================== S3-12
    say('## S3-12 PI with anti-windup');
    say('```');
    say('every Ts:                          // firmware mode PI (temperature_controller.ino)');
    say('  e = setpoint - T');
    say('  iNew = I + Ki * Ts * e');
    say('  uRaw = Kp * e + iNew');
    say('  if not ((uRaw > 255 and e > 0) or (uRaw < 0 and e < 0)):  I = iNew   // clamp: freeze I at the limits');
    say('  u = constrain(round(Kp * e + I), 0, 255)');
    say('  analogWrite(9, u)');
    say('```');
    fig = figure('Visible', 'off', 'Position', [0 0 1000 450]); hold on; rows = {};
    for mm = {'P', 'PI'}
        c = base; c.mode = mm{1}; c.Kp = 50; c.Ki = 0.5 * strcmp(mm{1}, 'PI'); c.ssr = 'average'; c.Tend = 1500;
        S = enr312.temperature.simulate(c);
        rows(end + 1, :) = {mm{1}, S.metrics.mean_error, S.metrics.overshoot, S.metrics.t_reach}; %#ok<AGROW>
        plot(S.t, S.T, 'LineWidth', 1.3, 'DisplayName', sprintf('%s Kp 50%s', mm{1}, repmat(' Ki 0.5', 1, strcmp(mm{1}, 'PI'))));
    end
    yline(45, 'k:', 'HandleVisibility', 'off'); xlabel('t (s)'); ylabel('zone C'); grid on; legend('Location', 'southeast');
    title('S3-12 SIMULATION: P vs PI at 45 C');
    saveFig(fig, 'fig_S3-12_P_vs_PI');
    T12 = cell2table(rows, 'VariableNames', {'mode', 'mean_error_C', 'overshoot_C', 't_reach_s'}); N.PI = table2struct(T12);
    say('| mode | mean error | overshoot | time to reach | '); say('|---|---|---|---|');
    for i = 1:height(T12), say('| %s | %+.2f C | %.2f C | %.0f s |', T12.mode{i}, T12.mean_error_C(i), T12.overshoot_C(i), T12.t_reach_s(i)); end
    say(['Prediction for 45 C: P leaves an offset (S3-10); PI removes it - the integral keeps adding power until the ' ...
         'mean reading is 45 C. Without clamping the integral would grow during the long warm-up at u = 255 and cause a ' ...
         'large overshoot; with clamping it starts integrating only once u leaves 255. Hardware: preset "PI Kp = 50, Ki = 0.5" (PENDING-HW).']);
    say('');
    say('## Pending hardware runs (enr312_temp, on the rig)');
    say('Heater step (K, tau, theta) first; then On-off 35/45/55 C, hysteresis +/-0.5 C, MA N = 10 and 500, P Kp 1/2/50/100/500, PI; check the 55 C readings against a thermometer.');

    writelines(string(md), fullfile(D, 'summary.md'));
    fid = fopen(fullfile(D, 'numbers.json'), 'w'); fwrite(fid, jsonencode(N, 'PrettyPrint', true)); fclose(fid);
    cfg = struct('run_id', runId, 'data_class', 'SIMULATION', 'matlab', version, 'simulink', ver('simulink').Version, ...
                 'params_status', 'ESTIMATED thermal constants (enr312.temperature.params)');
    fid = fopen(fullfile(D, 'run_config.json'), 'w'); fwrite(fid, jsonencode(cfg, 'PrettyPrint', true)); fclose(fid);
    doc = strrep(string(md), '(fig_', sprintf('(../../../results/evidence/simulation_runs/temperature/%s/fig_', runId));
    doc = ["<!-- GENERATED by matlab/scripts/temperature_course_questions.m - do not edit; rerun the script -->", doc];
    if ~exist(fullfile(root, 'docs', 'experiments', 'temperature'), 'dir'), mkdir(fullfile(root, 'docs', 'experiments', 'temperature')); end
    writelines(doc, fullfile(root, 'docs', 'experiments', 'temperature', 'COURSE_SIM_RESULTS.md'));
    out = struct('runId', runId, 'dir', D, 'numbers', N);
    fprintf('temperature course questions -> %s\n', D);

    function saveFig(f, name)
        try, theme(f, 'light'); catch, end
        exportgraphics(f, fullfile(D, [name '.png']), 'Resolution', 110); close(f);
        md{end + 1} = sprintf('![%s](%s.png)', name, name);
    end
end

function [pp, per] = swingPeriod(S, frac)
    % peak-to-peak of the READING and mean time between heater switch-ons, over the last part of the run
    k = S.t >= (1 - frac) * S.t(end);
    pp = max(S.Traw(k)) - min(S.Traw(k));
    h = S.heat(k) > 0.5; tt = S.t(k);
    ons = tt([false; diff(h) > 0]);
    if numel(ons) >= 2, per = mean(diff(ons)); else, per = NaN; end
end

function r = switchesPerMin(S)
    h = S.heat > 0.5; r = nnz(diff(h) ~= 0) / (S.t(end) / 60);
end
