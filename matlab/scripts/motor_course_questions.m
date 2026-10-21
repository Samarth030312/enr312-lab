function out = motor_course_questions()
%MOTOR_COURSE_QUESTIONS  Every simulation / data-analysis answer for the ENR312 MOTOR handout (SRC-013).
%
%   out = motor_course_questions()
%
%   Uses the hardware runs of 2026-10-11 (data/raw/dc_motor, read only) and the models:
%     enr312.motor.identifiedSim + enr312_motor_identified.slx   identified rig model (S3-4, S3-7)
%     enr312.motor.simulate                                       physics model, ESTIMATED constants (S3-3, S3-8)
%   Writes one evidence bundle:
%     results/evidence/simulation_runs/dc_motor/MOTOR-COURSE-SIM-<stamp>/
%        summary.md  numbers.json  run_config.json  fig_*.png  data_*.csv
%   and refreshes docs/experiments/dc_motor/COURSE_SIM_RESULTS.md (generated; do not edit).
%   Questions that need new hardware runs are listed as PENDING with the experiment to run.

    here = fileparts(mfilename('fullpath'));
    run(fullfile(here, '..', 'setup_enr312.m'));
    addpath(fullfile(here, '..', 'models', 'dc_motor'));
    root = enr312.repoRoot();
    outRoot = fullfile(root, 'results', 'evidence', 'simulation_runs', 'dc_motor');
    runId = enr312.newRunId('MOTOR-COURSE-SIM', @(id) exist(fullfile(outRoot, id), 'file'));
    D = fullfile(outRoot, runId); mkdir(D);
    P = enr312.motor.params();
    N = struct();                        % every number reported, -> numbers.json
    md = {};                             % summary lines
    say = @(varargin) addLine(sprintf(varargin{:}));
    function addLine(s), md{end + 1} = s; end

    hw = struct( ...
        'ol',      {{'MOTOR-02-HW-20261011-131457', 'MOTOR-02-HW-20261011-131818', 'MOTOR-02-HW-20261011-132536', 'MOTOR-02-HW-20261011-133631'}}, ...
        'spdP',    {{'MOTOR-05-HW-20261011-132405', 'MOTOR-05-HW-20261011-132415', 'MOTOR-05-HW-20261011-132424'}}, ...
        'spdPI',   {{'MOTOR-07-HW-20261011-132747', 'MOTOR-07-HW-20261011-133343', 'MOTOR-03-HW-20261011-132327', 'MOTOR-03-HW-20261011-133011', 'MOTOR-03-HW-20261011-133713'}}, ...
        'posP',    {{'MOTOR-04-HW-20261011-132143', 'MOTOR-04-HW-20261011-133810', 'MOTOR-05-HW-20261011-133840', 'MOTOR-05-HW-20261011-133849', 'MOTOR-05-HW-20261011-133858'}}, ...
        'posI',    {{'MOTOR-06-HW-20261011-132656'}});

    say('# ENR312 MOTOR handout: simulation and data-analysis results');
    say('');
    say('Run `%s`, generated %s by `matlab/scripts/motor_course_questions.m` (MATLAB %s, Simulink %s).', ...
        runId, char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')), version, ver('simulink').Version);
    say('Hardware data: runs of 2026-10-11 (data class HARDWARE). Everything else: SIMULATION.');
    say('Figures and CSV files are in `results/evidence/simulation_runs/dc_motor/%s/`.', runId);
    say('');

    % ================================================================== S3-1
    say('## S3-1 Motor, encoder and drive');
    N.cpr_out = P.lines * 4 * P.N; N.deg_per_count = 360 / N.cpr_out;
    say('RMCS-5032: 12 V, 180 rpm output no-load (18000 rpm base), 1:100, encoder 13 lines per motor rev. Drive: Rhino RMCS-2303.');
    say('Counts per output revolution with x4 decoding = 13 x 4 x 100 = **%d**; resolution = 360/%d = **%.4f deg**.', N.cpr_out, N.cpr_out, N.deg_per_count);
    say('');

    % ================================================================== S3-2
    say('## S3-2 Speed resolution versus counting window');
    dts = [0.010 0.050 0.100];
    N.speed_res_rpm = 60 ./ (N.cpr_out * dts);
    say('| window dt | resolution (1 count) = 60/(5200 dt) |'); say('|---|---|');
    for i = 1:3, say('| %g ms | %.3f rpm |', 1000 * dts(i), N.speed_res_rpm(i)); end
    N.drive_quantum_rpm = P.spd_fb_step_base_rpm / P.N;
    N.drive_window_ms = 1000 * 60 / (P.lines * P.spd_fb_step_base_rpm);
    say('');
    say(['The drive''s speed register (loop **S**) moved in steps of %.2f output rpm on the rig: that is one encoder ' ...
         'LINE (not count) per window of 60/(13 x %.1f) = **%.1f ms**. Loop **E** counts all four edges over Ts = 100 ms: %.3f rpm.'], ...
         N.drive_quantum_rpm, P.spd_fb_step_base_rpm, N.drive_window_ms, N.speed_res_rpm(3));
    m0 = struct('K', 1, 'tau', 1e-4, 'theta', 0, 'acc', 53.4, 'qSpd', N.drive_quantum_rpm);
    fig = figure('Visible', 'off', 'Position', [0 0 1000 420]); hold on;
    c = enr312.motor.defaultConfig('rig', 'speed'); c.ctrl = 'OL';
    S = enr312.motor.identifiedSim(m0, c, [0 0; 1 60], 3);
    plot(S.t, S.w, 'k', 'LineWidth', 1.2, 'DisplayName', 'true speed');
    stairs(S.tk, S.meas, 'LineWidth', 1.4, 'DisplayName', 'drive register (~10 ms window), Ts 100 ms');
    for Ts = [0.05 0.1 0.2]
        c.Ts = Ts; c.latency = min(c.latency, Ts); c.spdFb = 'encoder';
        S = enr312.motor.identifiedSim(m0, c, [0 0; 1 60], 3);
        stairs(S.tk, S.meas, 'LineWidth', 1.2, 'DisplayName', sprintf('encoder counts over %g ms', 1000 * Ts));
    end
    xlabel('t (s)'); ylabel('output rpm'); grid on; legend('Location', 'southeast');
    title('S3-2 SIMULATION: speed measured with different windows (step 0 \rightarrow 60 rpm)');
    saveFig(fig, 'fig_S3-2_speed_windows');
    say('Trade-off (fig_S3-2_speed_windows.png): a longer window gives finer resolution and less noise, but the value is an average over the window, so it lags the true speed by about dt/2 and updates only once per window.');
    say('');

    % ================================================================== S3-3
    say('## S3-3 Static map: steady speed versus command');
    cmds = 0:10:180; wss = nan(size(cmds));
    for i = 1:numel(cmds)
        c = enr312.motor.defaultConfig('rig', 'speed'); c.ctrl = 'OL'; c.setpoint = cmds(i); c.tStep = 0; c.Tend = 6; c.quant = false;
        S = enr312.motor.simulate(c); wss(i) = mean(S.w_rpm(end - 500:end));
    end
    N.static_map_sim = struct('cmd', cmds, 'speed', wss);
    N.free_speed_sim = max(wss); N.free_speed_hw = P.w_free_out_rpm;
    fig = figure('Visible', 'off', 'Position', [0 0 760 460]);
    plot(cmds, wss, 'o-', 'LineWidth', 1.4, 'DisplayName', 'physics model, 11.2 V (SIMULATION)'); hold on;
    plot(cmds, cmds, 'k:', 'DisplayName', 'ideal (speed = command)');
    yline(P.w_free_out_rpm, 'r--', sprintf('measured full-voltage speed %.0f rpm (HARDWARE)', P.w_free_out_rpm), 'LabelHorizontalAlignment', 'left');
    xlabel('speed command (output rpm)  [the drive''s equivalent of PWM 0-255]'); ylabel('steady speed (output rpm)'); grid on; legend('Location', 'northwest');
    title('S3-3 static map: dead zone and saturation');
    saveFig(fig, 'fig_S3-3_static_map');
    writetable(table(cmds', wss', 'VariableNames', {'cmd_rpm', 'speed_sim_rpm'}), fullfile(D, 'data_S3-3_static_map_sim.csv'));
    say(['Our actuator command is a speed (output rpm, 0-180, firmware limit) instead of PWM 0-255; the drive closes its own ' ...
         'loop, so the map is speed = command up to the voltage limit. Saturation: the physics model (ESTIMATED Ke) saturates at ' ...
         '**%.0f rpm** at 11.2 V; the rig ran at **161-170 rpm** at full voltage (HARDWARE, 2026-10-11 runaway). ' ...
         'Dead zone: **PENDING hardware** - run "Course S3-3: static map" (1, 2, 3, 5, 8 rpm steps, encoder feedback).'], N.free_speed_sim);
    say('');

    % ================================================================== S3-4
    say('## S3-4 Identification from open-loop steps');
    rows = {};
    for i = 1:numel(hw.ol)
        R = enr312.motor.loadHardwareRun(hw.ol{i}); T = R.T; sp = T.setpoint;
        ch = [find(diff(sp) ~= 0) + 1; height(T) + 1];
        for s = 1:numel(ch) - 1
            a = ch(s); b = ch(s + 1) - 1; du = sp(a) - sp(a - 1);
            f = enr312.ident.fitFOPDT(T.t_s(a - 1:b) - T.t_s(a - 1), T.meas(a - 1:b), du);
            rows(end + 1, :) = {hw.ol{i}, sp(a - 1), sp(a), f.K, f.tau, f.theta, f.rmse}; %#ok<AGROW>
        end
    end
    Tid = cell2table(rows, 'VariableNames', {'run', 'from_rpm', 'to_rpm', 'K', 'tau_s', 'theta_s', 'rmse_rpm'});
    writetable(Tid, fullfile(D, 'data_S3-4_fopdt_per_step.csv'));
    big = abs(Tid.to_rpm - Tid.from_rpm) >= 40; small = ~big;
    N.fopdt = struct('K_mean', mean(Tid.K), 'K_std', std(Tid.K), ...
                     'tau_big_mean', mean(Tid.tau_s(big)), 'theta_big_mean', mean(Tid.theta_s(big)), ...
                     'tau_20_mean', mean(Tid.tau_s(small)), 'theta_20_mean', mean(Tid.theta_s(small)));
    [mFit, info] = enr312.motor.fitIdentified(hw.ol);
    N.identified = mFit; N.identified_rmse = info.rmse;
    N.quant_noise_rpm = N.drive_quantum_rpm / sqrt(12);
    say('First-order-plus-dead-time fit to each of the %d measured steps (data_S3-4_fopdt_per_step.csv):', height(Tid));
    say('- K = **%.2f +- %.2f** output rpm per command rpm', N.fopdt.K_mean, N.fopdt.K_std);
    say('- 40-rpm steps: tau = **%.2f s**, theta = %.2f s;  20-rpm steps: tau = **%.2f s**, theta = %.2f s', ...
        N.fopdt.tau_big_mean, N.fopdt.theta_big_mean, N.fopdt.tau_20_mean, N.fopdt.theta_20_mean);
    say(['**Is first-order good enough? No.** tau depends on the step size, which a linear model cannot do. A model with a ' ...
         'rate limit fits all four runs at once with K = %.3f, acceleration = **%.1f rpm/s**, tau = %.3g s, theta = %.3g s ' ...
         '(RMSE %.2f rpm, close to the %.2f rpm rms of the 4.6-rpm quantisation itself). The drive ramps the speed ' ...
         '(acceleration register 5000 = 50 rpm/s) and its internal dynamics are faster than the 100 ms sampling can show.'], ...
         mFit.K, mFit.acc, mFit.tau, mFit.theta, info.rmse, N.quant_noise_rpm);
    fig = figure('Visible', 'off', 'Position', [0 0 1100 700]);
    for i = 1:numel(info.runs)
        subplot(2, 2, i); r = info.runs(i);
        stairs(r.tk, r.r, 'k:'); hold on; plot(r.tk, r.meas, '.', 'MarkerSize', 8); plot(r.tk, r.sim, 'LineWidth', 1.4);
        title(sprintf('%s (rmse %.2f rpm)', r.id, r.rmse), 'Interpreter', 'none', 'FontSize', 9);
        xlabel('t (s)'); ylabel('rpm'); grid on;
        if i == 1, legend('command', 'measured (HARDWARE)', 'identified model', 'Location', 'northwest'); end
    end
    sgtitle('S3-4 identified model (rate limit + K) against the open-loop hardware runs');
    saveFig(fig, 'fig_S3-4_identification');
    % first-order model used by the course theory questions: K = 1, tau from a 0 -> 60 step
    c = enr312.motor.defaultConfig('rig', 'speed'); c.ctrl = 'OL'; c.quant = false; c.spdFb = 'encoder';
    S = enr312.motor.identifiedSim(mFit, c, [0 0; 1 60; 7 0], 10); k = S.tk >= 1 & S.tk < 7;
    f60 = enr312.ident.fitFOPDT(S.tk(k) - 1, S.meas(k), 60, struct('theta', 0, 'K', 1));
    N.course_model = struct('K', 1, 'tau', f60.tau, 'note', 'first-order fit (K fixed at the measured 1.0) to the identified 0->60 rpm step; the course procedure');
    say('Course first-order model for S3-9/S3-10 (fit to a 0 -> 60 rpm step, K fixed at the measured 1.0): **K = 1, tau = %.2f s**. Hardware check: run "Course S3-2/S3-4: open-loop step".', f60.tau);
    say('');

    % ================================================================== S3-5
    say('## S3-5 Position P: final error');
    rowsP = {};
    for i = 1:numel(hw.posP)
        R = enr312.motor.loadHardwareRun(hw.posP{i}); T = R.T; sp = T.setpoint;
        ch = [1; find(diff(sp) ~= 0) + 1; height(T) + 1];
        for s = 1:numel(ch) - 1
            idx = ch(s):ch(s + 1) - 1; tail = idx(max(1, round(0.7 * numel(idx))):end);
            rowsP(end + 1, :) = {hw.posP{i}, R.cfg.Kp, sp(ch(s)), mean(T.meas(tail)), sp(ch(s)) - mean(T.meas(tail))}; %#ok<AGROW>
        end
    end
    Tp = cell2table(rowsP, 'VariableNames', {'run', 'Kp', 'target_deg', 'final_deg', 'error_deg'});
    writetable(Tp, fullfile(D, 'data_S3-5_position_final_error.csv'));
    N.posP_max_abs_error_deg = max(abs(Tp.error_deg));
    say('| run | Kp | target (deg) | final (deg) | error (deg) |'); say('|---|---|---|---|---|');
    for i = 1:height(Tp), say('| %s | %.1f | %+g | %+.2f | %+.2f |', Tp.run{i}, Tp.Kp(i), Tp.target_deg(i), Tp.final_deg(i), Tp.error_deg(i)); end
    say(['HARDWARE: every move ends within **%.2f deg** (a few counts of %.4f deg) for Kp 0.2, 0.3, 0.5: no stopping short. ' ...
         'The RMCS-2303 closes its own speed loop, so a command of even 1 rpm still turns the motor - the drive removes the ' ...
         'dead zone that a bare PWM-driven motor has. With a dead zone d, P control stops where Kp*e < d, i.e. e_final = d/Kp ' ...
         '(simulated in S3-11). Small 10 deg moves with Kp 0.1/0.3/1.0: **PENDING hardware** ("Course S3-5").'], N.posP_max_abs_error_deg, N.deg_per_count);
    say('');

    % ================================================================== S3-6
    say('## S3-6 Loop time');
    chars = struct('readSpeed', 17 + 15, 'readPos', 17 + 19, 'writeSpeed', 17 + 17);
    N.modbus_ms = structfun(@(n) n * 10 / 9600 * 1000, chars, 'UniformOutput', false);
    say(['Firmware now measures it with micros() (DIAG prints mean/max of the control law and of the whole sample) - ' ...
         '**PENDING hardware** reading. Budget at 9600 baud (10 bits per character): read speed %.0f ms, read position %.0f ms, ' ...
         'write command %.0f ms per transaction, so one speed sample needs ~%.0f ms of the 100 ms period and the control law ' ...
         'itself is microseconds. The loop period (Ts) and the ~70 ms command latency, not the arithmetic, limit the gains: ' ...
         'delay adds phase lag, and the loop oscillates once Kp is large (rig model: Kp >= 1.2 in speed P).'], ...
         N.modbus_ms.readSpeed, N.modbus_ms.readPos, N.modbus_ms.writeSpeed, N.modbus_ms.readSpeed + N.modbus_ms.writeSpeed);
    say('');

    % ================================================================== S3-7
    say('## S3-7 Simulink identified model against the hardware runs');
    allRuns = [hw.spdP, hw.spdPI, hw.posP, hw.posI];
    rowsB = {};
    fig = figure('Visible', 'off', 'Position', [0 0 1500 1100]);
    nr = ceil(numel(allRuns) / 4);
    for i = 1:numel(allRuns)
        R = enr312.motor.loadHardwareRun(allRuns{i}); T = R.T; c = R.cfg;
        t0 = T.t_ms(1) / 1000; tk = T.t_ms / 1000 - t0;
        ch = [1; find(diff(T.setpoint) ~= 0) + 1];
        prof = [tk(ch), T.setpoint(ch)];
        Rs = run_motor_identified_simulink(mFit, c, prof, tk(end));
        sim = interp1(Rs.tk, Rs.measK, tk, 'previous', 'extrap');
        e = T.meas(2:end) - sim(2:end);
        rng = max(abs(T.setpoint)); rmse = sqrt(mean(e.^2));
        rowsB(end + 1, :) = {allRuns{i}, c.loop, c.ctrl, c.Kp, c.Ki, rmse, 100 * rmse / rng}; %#ok<AGROW>
        subplot(nr, 4, i);
        stairs(tk, T.setpoint, 'k:'); hold on; plot(tk, T.meas, '.', 'MarkerSize', 6); plot(Rs.tk, Rs.measK, 'LineWidth', 1.3);
        title(sprintf('%s %s Kp %g Ki %g\n%s  rmse %.1f%%', c.loop, c.ctrl, c.Kp, c.Ki, allRuns{i}(end - 5:end), 100 * rmse / rng), 'FontSize', 8);
        grid on;
    end
    sgtitle('S3-7 measured (dots, HARDWARE) vs Simulink identified model (line, SIMULATION)');
    saveFig(fig, 'fig_S3-7_sim_vs_hw');
    Tb = cell2table(rowsB, 'VariableNames', {'run', 'loop', 'ctrl', 'Kp', 'Ki', 'rmse', 'rmse_pct_of_setpoint'});
    writetable(Tb, fullfile(D, 'data_S3-7_sim_vs_hw.csv'));
    N.simVsHw = table2struct(Tb);
    say('| run | loop | ctrl | Kp | Ki | RMSE | RMSE (%% of setpoint) |'); say('|---|---|---|---|---|---|---|');
    for i = 1:height(Tb), say('| %s | %s | %s | %g | %g | %.2f | %.1f %% |', Tb.run{i}, Tb.loop{i}, Tb.ctrl{i}, Tb.Kp(i), Tb.Ki(i), Tb.rmse(i), Tb.rmse_pct_of_setpoint(i)); end
    say('Model: `matlab/models/dc_motor/enr312_motor_identified.slx` (Arduino PID with clamping, Modbus latency, dead zone, drive acceleration limit, K/(tau s+1), dead time, encoder/drive quantisation, backlash). Parameters fitted on the OPEN-LOOP runs only, so every closed-loop comparison above is a prediction.');
    say('');

    % ================================================================== S3-8
    say('## S3-8 +50 %% inertia without retuning');
    cases = {'speed', 'P', 0.5, 0; 'speed', 'I', 0, 1.0; 'speed', 'PI', 0.3, 1.5; 'position', 'P', 0.3, 0};
    rowsJ = {};
    for i = 1:size(cases, 1)
        for plant = {'rig', 'bare'}
            for js = [1 1.5]
                c = enr312.motor.defaultConfig(plant{1}, cases{i, 1}); c.ctrl = cases{i, 2};
                if strcmp(plant{1}, 'rig'), c.Kp = cases{i, 3}; c.Ki = cases{i, 4}; end
                if strcmp(plant{1}, 'bare') && strcmp(c.ctrl, 'I'), c.Kp = 0; end
                if strcmp(c.ctrl, 'P'), c.Ki = 0; end
                c.Tend = 12; c.quant = false; c.P.J = c.P.J * js;
                S = enr312.motor.simulate(c); mt = S.metrics;
                rowsJ(end + 1, :) = {plant{1}, cases{i, 1}, c.ctrl, js, mt.over, mt.settle, mt.ess_pct}; %#ok<AGROW>
            end
        end
    end
    Tj = cell2table(rowsJ, 'VariableNames', {'plant', 'loop', 'ctrl', 'J_scale', 'overshoot_pct', 't_settle_s', 'ess_pct'});
    writetable(Tj, fullfile(D, 'data_S3-8_inertia.csv'));
    N.inertia = table2struct(Tj);
    say('| plant | loop | ctrl | J | overshoot %% | settle (s) | e_ss %% |'); say('|---|---|---|---|---|---|---|');
    for i = 1:height(Tj), say('| %s | %s | %s | x%.1f | %.1f | %.2f | %.2f |', Tj.plant{i}, Tj.loop{i}, Tj.ctrl{i}, Tj.J_scale(i), Tj.overshoot_pct(i), Tj.t_settle_s(i), Tj.ess_pct(i)); end
    accNeed = P.acc_base_rpm_s * P.rpm * P.J * 1.5; accHave = P.Kt * P.I_lim_drive;
    N.torque_margin = accHave / accNeed;
    say(['**Rig (drive in speed mode): the responses do not change.** The drive ramps at 50 rpm/s; accelerating 1.5 J at that ' ...
         'rate needs %.2g N*m at the motor, the 3 A current limit gives %.2g N*m (%.0fx margin), so its speed loop hides the extra inertia. ' ...
         '**Bare motor (voltage/PWM drive, course model): tau grows ~50 %%**, the loops slow down and overshoot more; ' ...
         'PI copes best in speed (integral action keeps e_ss = 0), P in position keeps zero error (type 1) but rings more.'], ...
         accNeed, accHave, N.torque_margin);
    say('');

    % ================================================================== S3-9
    say('## S3-9 I-only speed control');
    tau = f60.tau; Kis = [0.5 1 2 4];
    N.Ionly = struct('Ki', Kis, 'zeta', 1 ./ (2 * sqrt(tau * 1 * Kis)), 'wn', sqrt(Kis / tau));
    say(['Plant G = K/(tau s+1), controller C = Ki/s. Loop: 1 + C G = 0  ->  s(tau s + 1) + K Ki = 0  ->  **tau s^2 + s + K Ki = 0**. ' ...
         'Compare with s^2 + 2 zeta wn s + wn^2: wn = sqrt(K Ki/tau), **zeta = 1/(2 sqrt(tau K Ki))** - damping falls as 1/sqrt(Ki).']);
    say('| Ki | zeta (tau %.2f s) | predicted overshoot | identified-model overshoot |', tau); say('|---|---|---|---|');
    fig = figure('Visible', 'off', 'Position', [0 0 900 450]); hold on;
    for i = 1:numel(Kis)
        z = N.Ionly.zeta(i); osT = 100 * exp(-pi * z / sqrt(max(1 - z^2, eps))) * (z < 1);
        c = enr312.motor.defaultConfig('rig', 'speed'); c.ctrl = 'I'; c.Kp = 0; c.Ki = Kis(i); c.spdFb = 'encoder';
        S = enr312.motor.identifiedSim(mFit, c, [0 30], 10);
        osM = max(0, 100 * (max(S.meas) - 30) / 30);
        N.Ionly.os_theory(i) = osT; N.Ionly.os_model(i) = osM;
        say('| %g | %.2f | %.0f %% | %.0f %% |', Kis(i), z, osT, osM);
        stairs(S.tk, S.meas, 'LineWidth', 1.3, 'DisplayName', sprintf('Ki %g (zeta %.2f)', Kis(i), z));
    end
    yline(30, 'k:', 'HandleVisibility', 'off'); xlabel('t (s)'); ylabel('output rpm'); grid on; legend; title('S3-9 SIMULATION: I-only speed control, identified model');
    saveFig(fig, 'fig_S3-9_I_only');
    say(['The identified model departs from the formula in both directions. The rig is really fast (tau ~ 0) behind a ' ...
         '70 ms latency and a 53 rpm/s ramp; the 0.72 s "tau" is mostly the ramp time. At low Ki the integrator moves the ' ...
         'command slower than the ramp, so there is no overshoot; at high Ki the latency adds phase lag and the overshoot ' ...
         'exceeds the formula. Hardware: the earlier position I-only run (MOTOR-06, Ki 0.1) oscillated without settling, as ' ...
         'two integrators predict; speed I-only sweep **PENDING hardware** ("Course S3-9").']);
    say('');

    % ================================================================== S3-10
    say('## S3-10 PI design for zeta = 0.7');
    zeta = 0.7; wn = 2;
    Kp = 2 * zeta * wn * tau - 1; Ki = wn^2 * tau;
    N.PIdesign = struct('tau', tau, 'zeta', zeta, 'wn', wn, 'Kp', Kp, 'Ki', Ki, ...
                        'os_pred_pct', 100 * exp(-pi * zeta / sqrt(1 - zeta^2)), 'ts_pred_s', 4 / (zeta * wn));
    say(['Closed loop with C = Kp + Ki/s: tau s^2 + (1 + K Kp) s + K Ki = 0. Matching s^2 + 2 zeta wn s + wn^2: ' ...
         '**Ki = wn^2 tau / K, Kp = (2 zeta wn tau - 1)/K**. With K = 1, tau = %.2f s, zeta = 0.7, wn = 2 rad/s: ' ...
         '**Kp = %.2f, Ki = %.2f** (hardware preset uses 1.0 / 2.9). Predicted overshoot %.1f %%, 2 %% settling 4/(zeta wn) = %.1f s ' ...
         '(the PI zero at -Ki/Kp adds a little overshoot).'], tau, Kp, Ki, N.PIdesign.os_pred_pct, N.PIdesign.ts_pred_s);
    c = enr312.motor.defaultConfig('rig', 'speed'); c.ctrl = 'PI'; c.Kp = 1.0; c.Ki = 2.9; c.spdFb = 'encoder';
    S = enr312.motor.identifiedSim(mFit, c, [0 30; 8 40; 16 30], 22);
    k = S.tk >= 8 & S.tk < 16; N.PIdesign.os_model_pct = 100 * (max(S.meas(k)) - 40) / 10;
    cl = c; cl.latency = 0; cl.quant = false;
    Sl = enr312.motor.identifiedSim(struct('K', 1, 'tau', tau), cl, [0 30; 8 40; 16 30], 22);
    N.PIdesign.os_firstorder_sim_pct = 100 * (max(Sl.meas(k)) - 40) / 10;
    fig = figure('Visible', 'off', 'Position', [0 0 900 450]);
    stairs(S.tk, S.r, 'k:'); hold on; stairs(Sl.tk, Sl.meas, 'LineWidth', 1.3); stairs(S.tk, S.meas, 'LineWidth', 1.3);
    legend('setpoint', 'first-order design model', 'identified model (latency + ramp + quantisation)', 'Location', 'southeast');
    xlabel('t (s)'); ylabel('output rpm'); grid on; title('S3-10 SIMULATION: PI Kp 1.0, Ki 2.9');
    saveFig(fig, 'fig_S3-10_PI_design');
    say(['30 -> 40 rpm step: first-order model overshoot %.1f %%; identified model **%.0f %%** - the 70 ms latency and the ' ...
         'sampling add phase lag the design ignored. Measurement **PENDING hardware** ("Course S3-10"). Earlier hand-tuned PI ' ...
         '(Kp 0.3, Ki 1.5) measured 3-12 %% overshoot (HARDWARE).'], N.PIdesign.os_firstorder_sim_pct, N.PIdesign.os_model_pct);
    say('');

    % ================================================================== S3-11
    say('## S3-11 Why P position control can stop short, and backlash hunting');
    dz = 1; rowsD = {};
    fig = figure('Visible', 'off', 'Position', [0 0 1100 420]);
    subplot(1, 2, 1); hold on;
    for KpD = [0.1 0.3 1.0]
        c = enr312.motor.defaultConfig('rig', 'position'); c.ctrl = 'P'; c.Kp = KpD; c.Ki = 0;
        md_ = mFit; md_.dz = dz;
        S = enr312.motor.identifiedSim(md_, c, [0 10], 8);
        rowsD(end + 1, :) = {KpD, 10 - S.meas(end), dz / KpD}; %#ok<AGROW>
        stairs(S.tk, S.meas, 'LineWidth', 1.3, 'DisplayName', sprintf('Kp %.1f', KpD));
    end
    yline(10, 'k:', 'HandleVisibility', 'off'); xlabel('t (s)'); ylabel('deg'); grid on; legend('Location', 'southeast');
    title(sprintf('dead zone %g rpm: P stops where Kp e < d', dz));
    Td = cell2table(rowsD, 'VariableNames', {'Kp', 'final_error_deg', 'predicted_d_over_Kp'});
    N.deadzoneP = table2struct(Td);
    subplot(1, 2, 2); hold on;
    for atLoad = [false true]
        c = enr312.motor.defaultConfig('rig', 'position'); c.ctrl = 'PI'; c.Kp = 0.3; c.Ki = 0.3;
        mb = mFit; mb.backlash = 3; mb.dz = 1; mb.sensorAtLoad = atLoad;
        S = enr312.motor.identifiedSim(mb, c, [0 30], 60);
        plot(S.t, S.thOut, 'LineWidth', 1.2, 'DisplayName', sprintf('output shaft, encoder at %s', ternary(atLoad, 'LOAD', 'motor')));
        k = S.t > 40;
        N.backlash.(ternary(atLoad, 'load', 'motor')) = struct('pp_last20s', max(S.thOut(k)) - min(S.thOut(k)), 'mean_err_deg', 30 - mean(S.thOut(k)));
    end
    yline(30, 'k:', 'HandleVisibility', 'off'); xlabel('t (s)'); ylabel('output deg'); grid on; legend('Location', 'southeast');
    title('backlash 3 deg, dead zone 1 rpm, PI Kp 0.3 Ki 0.3');
    saveFig(fig, 'fig_S3-11_deadzone_backlash');
    say('| Kp | final error, sim (deg) | d/Kp (deg) |'); say('|---|---|---|');
    for i = 1:height(Td), say('| %.1f | %.2f | %.2f |', Td.Kp(i), Td.final_error_deg(i), Td.predicted_d_over_Kp(i)); end
    say(['Type 1 means zero error for a LINEAR plant. Real drives have a dead zone (static friction, gearbox, driver drop): ' ...
         'near the target Kp*e falls below it and the motor stops with e = d/Kp (table, 1 rpm dead zone, SIMULATION). ' ...
         'Our rig showed <= %.2f deg because the servo drive has no dead zone (S3-5). Backlash: with the sensor after the ' ...
         'gears, an integrator keeps pushing while the gears cross the gap, overshoots, reverses, crosses the gap again: a ' ...
         'limit cycle ("hunting": the output swings %.1f deg peak-to-peak for ever, SIMULATION). Our encoder is on the motor ' ...
         'shaft, so the loop does not see backlash (%.2f deg p-p): the output shaft simply rests %.1f deg off (up to half the 3 deg gap).'], ...
         N.posP_max_abs_error_deg, N.backlash.load.pp_last20s, N.backlash.motor.pp_last20s, N.backlash.motor.mean_err_deg);
    say('');

    % ================================================================== S3-12
    say('## S3-12 Integral windup');
    c = enr312.motor.defaultConfig('rig', 'speed'); c.ctrl = 'PI'; c.Kp = 0.3; c.Ki = 1.5; c.uMax = 50; c.spdFb = 'encoder';
    prof = [0 80; 6 30];
    fig = figure('Visible', 'off', 'Position', [0 0 900 600]);
    for aw = [true false]
        c.antiWindup = aw;
        R = run_motor_identified_simulink(mFit, c, prof, 30);
        k = R.tk > 6; kk = find(k & abs(R.measK - 30) <= 3, 1);
        rec = R.tk(kk) - 6; if isempty(rec), rec = NaN; end
        N.windup.(ternary(aw, 'clamping', 'none')) = struct('recovery_s', rec, 'min_after_drop', min(R.measK(k)));
        subplot(2, 1, 1); stairs(R.tk, R.measK, 'LineWidth', 1.3); hold on;
        subplot(2, 1, 2); stairs(R.tk, R.uK, 'LineWidth', 1.3); hold on;
    end
    subplot(2, 1, 1); stairs([0 6 30], [80 30 30], 'k:');
    ylabel('speed (rpm)'); grid on; legend('clamping anti-windup', 'plain integrator (windup)', 'setpoint'); title('S3-12 SIMULATION (Simulink): command limited to 50 rpm');
    subplot(2, 1, 2); ylabel('command u (rpm)'); xlabel('t (s)'); grid on; yline(50, 'r--', 'limit');
    saveFig(fig, 'fig_S3-12_windup');
    say(['Setpoint 80 rpm with the command limited to 50 rpm: the output saturates and the error stays at 30 rpm. A plain ' ...
         'integrator keeps growing; when the setpoint drops to 30 rpm at t = 6 s it must first unwind, so the motor stays at ' ...
         '50 rpm for **%.1f s** before reaching 30 rpm; with clamping it takes **%.1f s**. The same happens with PWM at 255. ' ...
         'Code (firmware pidStep, matlab pidStep.m): when the output is saturated and the error pushes further into saturation, ' ...
         'stop integrating (`if (sat && sign(uRaw) == sign(e)) iNew = iOld;`). Hardware run: "Course S3-12".'], ...
         N.windup.none.recovery_s, N.windup.clamping.recovery_s);
    say('');
    say('## Pending hardware runs (MotorControlApp -> Hardware experiments)');
    say('Course S3-3 static map; S3-2/S3-4 open-loop step (drive vs encoder); S3-5 10-deg position P; S3-9 I-only Ki sweep; S3-10 designed PI; S3-12 saturation. Then DIAG after any run for S3-6 loop time.');

    % ------------------------------------------------------------------ write
    writelines(string(md), fullfile(D, 'summary.md'));
    fid = fopen(fullfile(D, 'numbers.json'), 'w'); fwrite(fid, jsonencode(N, 'PrettyPrint', true)); fclose(fid);
    cfg = struct('run_id', runId, 'data_class', 'SIMULATION + analysis of HARDWARE runs', 'hardware_runs', hw, ...
                 'matlab', version, 'simulink', ver('simulink').Version, 'identified_model', mFit);
    fid = fopen(fullfile(D, 'run_config.json'), 'w'); fwrite(fid, jsonencode(cfg, 'PrettyPrint', true)); fclose(fid);
    doc = strrep(string(md), sprintf('(fig_'), sprintf('(../../../results/evidence/simulation_runs/dc_motor/%s/fig_', runId));
    doc = ["<!-- GENERATED by matlab/scripts/motor_course_questions.m - do not edit; rerun the script -->", doc];
    writelines(doc, fullfile(root, 'docs', 'experiments', 'dc_motor', 'COURSE_SIM_RESULTS.md'));
    out = struct('runId', runId, 'dir', D, 'numbers', N);
    fprintf('motor course questions -> %s\n', D);

    function saveFig(f, name)
        try, theme(f, 'light'); catch, end          % reports are printed on white
        exportgraphics(f, fullfile(D, [name '.png']), 'Resolution', 110);
        close(f);
        md{end + 1} = sprintf('![%s](%s.png)', name, name);
    end
end

function v = ternary(c, a, b)
    if c, v = a; else, v = b; end
end
