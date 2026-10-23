function tests = test_physics
%TEST_PHYSICS  Datasheet / dimension physics of the three rigs, the thermal fit, the run register.
    tests = functiontests(localfunctions);
end

function testMotorFromTheDatasheet(tc)
    [P, D] = enr312.motor.physics();
    tc.verifyEqual(D.R, 12 / 7.5, 'AbsTol', 1e-12);
    tc.verifyEqual(D.Kt, D.Ke);
    tc.verifyEqual(D.w_free_out, 168, 'AbsTol', 1, 'free speed at 11.2 V (measured 161-170 rpm)');
    tc.verifyEqual(P.cpr_out, 5200);
    [~, D2] = enr312.motor.physics(struct('J_factor', 1.5));
    tc.verifyEqual(D2.tau_m, 1.5 * D.tau_m, 'RelTol', 1e-9, 'tau_m scales with J');
    % the bare-motor transfer function: DC gain in output rpm per volt
    tc.verifyEqual(D.num / D.den(3) / (2 * pi / 60) / 100, D.gain_rpm_per_V, 'RelTol', 1e-9);
end

function testArmatureLoadTorqueNeedsCurrent(tc)
    [P, ~] = enr312.motor.physics();
    c = enr312.motor.defaultConfig('bare', 'speed'); c.P = P; c.ctrl = 'PI'; c.Kp = 0.05; c.Ki = 1;
    c.profile = [0 0; 0.1 100]; c.Tend = 2; c.dist = 1.0; c.tDist = 1;
    S = enr312.motor.simulate(c);
    before = mean(S.i(S.t > 0.8 & S.t < 1)); after = mean(S.i(S.t > 1.8));
    tc.verifyEqual(after - before, 1.0 / (P.N * P.Kt), 'RelTol', 0.05, '1 N*m at the output = T/(N Kt) more current');
    tc.verifyEqual(S.w_rpm(end), 100, 'AbsTol', 1, 'PI rejects the load');
end

function testTemperatureFromTheBulbAndBox(tc)
    [~, D] = enr312.temperature.physics();
    tc.verifyEqual(D.K, 0.9 * 60 * D.R_th, 'RelTol', 1e-12);
    tc.verifyEqual(D.tau, D.R_th * D.C, 'RelTol', 1e-12);
    [~, D2] = enr312.temperature.physics(struct('mains_V', 115));
    tc.verifyEqual(D2.P_el, 60 * 0.5^1.6, 'RelTol', 1e-12, 'filament power at half voltage');
end

function testTemperatureWindupAndAmbient(tc)
    [P, ~] = enr312.temperature.physics();
    c = enr312.temperature.defaultConfig(); c.P = P; c.mode = 'PI'; c.Kp = 50; c.Ki = 0.5; c.Tend = 1500; c.uMaxPct = 40;
    c.antiWindup = false; Sw = enr312.temperature.simulate(c);
    c.antiWindup = true; Sa = enr312.temperature.simulate(c);
    tc.verifyGreaterThan(max(Sw.Traw), max(Sa.Traw) + 2, 'a plain integrator overshoots after saturation');
    c.ambStep = -5; c.tAmb = 600; c.uMaxPct = 100; S = enr312.temperature.simulate(c);
    tc.verifyEqual(S.Traw(end), 45, 'AbsTol', 1, 'PI recovers from the room-temperature drop');
end

function testThermalFitOnAStoppedCurve(tc)
    [P, D] = enr312.temperature.physics();
    c = enr312.temperature.defaultConfig(); c.P = P; c.mode = 'STEP'; c.setpoint = 60; c.Tend = 1800;
    S = enr312.temperature.simulate(c);
    m = enr312.ident.fitThermal(S.t, S.Traw, S.heat);
    tc.verifyEqual(m.K, D.K, 'RelTol', 0.10);
    tc.verifyEqual(m.tau, D.tau + D.tau_s, 'RelTol', 0.15, 'tau plus the sensor lag');
end

function testTankTorricelli(tc)
    [P, D] = enr312.level.physics();
    tc.verifyEqual(D.k, 0.6 * pi * 0.0077^2 / 4 * sqrt(2 * 9.81), 'RelTol', 1e-12);
    c = enr312.level.defaultConfig(); c.P = P; c.mode = 'OL'; c.olPct = 100; c.h0 = 0; c.Tend = 1500;
    c.guards = false;                         % the 92 % overflow guard would stop it short of 95 %
    S = enr312.level.simulate(c);
    tc.verifyEqual(S.level(end), D.pct_full_pump, 'AbsTol', 1.5, 'open loop settles where q_in = k sqrt(h)');
    [P2, ~] = enr312.level.physics(struct('valve', 55));
    c.P = P2; c.guards = false; c.h0 = 50; S = enr312.level.simulate(c);
    tc.verifyGreaterThan(S.spill(end), 1, 'outlet half closed, no guard: the tank overflows');
    c.guards = true; c.mode = 'PI'; c.setpoint = 50; S = enr312.level.simulate(c);
    tc.verifyEqual(S.spill(end), 0);
end

function testRegisterIdsAndLegacy(tc)
    old = getenv('ENR312_DATA_ROOT'); c = onCleanup(@() setenv('ENR312_DATA_ROOT', old));
    tmp = tempname; mkdir(tmp); setenv('ENR312_DATA_ROOT', tmp);
    T = table((0:4)', (100:100:500)', repmat({'S'}, 5, 1), repmat({'PI'}, 5, 1), 30 * ones(5, 1), (1:5)', ...
        'VariableNames', {'seq', 't_ms', 'loop', 'ctrl', 'setpoint', 'meas'});
    r1 = enr312.data.saveRun('MOTOR', T, struct('ctrl', 'PI', 'Kp', 1), {}, struct('mission', 'M5', 'legacy_id', 'OLD-1'));
    r2 = enr312.data.saveRun('TEMP', T, struct('mode', 'ONOFF'), {}, struct('mission', 'T2'));
    r3 = enr312.data.saveRun('MOTOR', T, struct('ctrl', 'P'), {}, struct('mission', 'M3', 'result', 'STOPPED: test'));
    tc.verifyMatches(r1.runId, '^MOTOR-R0001_\d{8}-\d{6}_M5$');
    tc.verifyMatches(r2.runId, '^TEMP-R0001_\d{8}-\d{6}_T2$');
    tc.verifyMatches(r3.runId, '^MOTOR-R0002_');
    R = enr312.data.register();
    tc.verifyEqual(height(R), 3); tc.verifyEqual(R.result{3}, 'STOPPED: test');
    tc.verifyEqual(enr312.data.resolve('OLD-1'), r1.runId);
end
