function tests = test_temperature_model
%TEST_TEMPERATURE_MODEL  Temperature simulation against closed-form results and safety rules.
    tests = functiontests(localfunctions);
end

function setupOnce(~)
    run(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'setup_enr312.m'));
end

function testPSteadyStateErrorMatchesTheory(tc)
    % Average-power P loop: e = (SP - Ta) / (1 + Kp eta P R / 255)
    for Kp = [2 10 50]
        c = enr312.temperature.defaultConfig(); c.mode = 'P'; c.Kp = Kp; c.ssr = 'average';
        c.P.noise = 0; c.Tend = 1500;
        S = enr312.temperature.simulate(c); P = c.P;
        e = (c.setpoint - P.T_amb) / (1 + Kp * P.eta_heat * P.P_bulb * P.R_th / 255);
        tc.verifyEqual(S.metrics.mean_error, e, 'AbsTol', 0.15, sprintf('Kp %g', Kp));
    end
end

function testOpenLoopRiseMatchesFirstOrder(tc)
    % Heater fully on (setpoint unreachable): zone T follows Ta + G (1 - exp(-t/RC)).
    c = enr312.temperature.defaultConfig(); c.setpoint = 64; c.Tend = 300; c.P.noise = 0;
    S = enr312.temperature.simulate(c); P = c.P;
    G = P.eta_heat * P.P_bulb * P.R_th; tau = P.R_th * P.C_th;
    k = S.t <= 100;
    tc.verifyEqual(S.T(k), P.T_amb + G * (1 - exp(-S.t(k) / tau)), 'AbsTol', 0.05);
end

function testShortWindowDoesNotFilter(tc)
    % N = 10 at 10 ms spans 0.1 s; the DHT22 updates every 2 s: same behaviour as plain on-off.
    a = enr312.temperature.simulate(enr312.temperature.presetConfig('On-off, 45 C'));
    b = enr312.temperature.simulate(enr312.temperature.presetConfig('Moving average N = 10, 45 C'));
    tc.verifyEqual(b.metrics.switches_per_min, a.metrics.switches_per_min, 'RelTol', 0.15);
end

function testHysteresisReducesSwitching(tc)
    a = enr312.temperature.simulate(enr312.temperature.presetConfig('On-off, 45 C'));
    b = enr312.temperature.simulate(enr312.temperature.presetConfig('On-off with 1 C hysteresis, 45 C'));
    tc.verifyLessThan(b.metrics.switches_per_min, a.metrics.switches_per_min);
    tc.verifyGreaterThan(b.metrics.band_pp, a.metrics.band_pp);
end

function testPwmIntoZeroCrossSsrAveragesToDuty(tc)
    % 490.196 Hz PWM sampled every 10 ms half-cycle: long-run on-fraction ~ u / 255.
    c = enr312.temperature.defaultConfig(); c.mode = 'P'; c.Kp = 0; c.Tend = 60;
    for u = [15 64 128 200]
        c.setpoint = c.P.T_amb + 100; c.Kp = u / 100;          % e ~ 100 C -> u counts, far from setpoint
        S = enr312.temperature.simulate(c);
        tc.verifyEqual(mean(S.heat), mean(S.u) / 255, 'AbsTol', 0.03, sprintf('u %d', u));
    end
end

function testOvertemperatureCutoffLatches(tc)
    c = enr312.temperature.defaultConfig(); c.P.T_cutoff = 50; c.setpoint = 60; c.Tend = 600;
    S = enr312.temperature.simulate(c);
    tc.verifyTrue(S.cutoff); tc.verifyEqual(S.metrics.verdict, 'OVER-TEMP CUT-OFF');
    tc.verifyEqual(S.heat(end), 0);
    tc.verifyLessThan(max(S.Traw), 55);
end

function testEveryPresetRuns(tc)
    p = enr312.temperature.presets();
    for k = 1:numel(p)
        S = enr312.temperature.simulate(enr312.temperature.presetConfig(p(k).name));
        tc.verifyTrue(all(isfinite(S.T)), p(k).name);
        tc.verifyFalse(S.cutoff, p(k).name);
    end
end
