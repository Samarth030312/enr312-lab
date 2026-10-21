function tests = test_simulink_temperature_level
%TEST_SIMULINK_TEMPERATURE_LEVEL  Simulink models agree with the MATLAB simulators.
%   Switching systems: compared on metrics (a relay can flip one sample apart),
%   noise off, ideal-average SSR. Skipped without Simulink.
    tests = functiontests(localfunctions);
end

function setupOnce(tc)
    run(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'setup_enr312.m'));
    tc.assumeTrue(~isempty(ver('simulink')) && license('test', 'Simulink'), 'Simulink not installed');
    tc.TestData.dir = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
    build_temperature_simulink(tc.TestData.dir);
    build_level_simulink(tc.TestData.dir);
end

function testTemperatureModes(tc)
    for mode = {'ONOFF', 'HYST', 'MA', 'P'}
        c = enr312.temperature.defaultConfig(); c.mode = mode{1}; c.ssr = 'average'; c.P.noise = 0;
        c.Tend = 600; if strcmp(mode{1}, 'MA'), c.window = 500; end
        M = enr312.temperature.simulate(c);
        R = run_temperature_simulink(c, tc.TestData.dir);
        tail = M.t >= 0.7 * c.Tend;
        dMean = abs(mean(M.Traw(tail)) - mean(R.reading(tail)));
        dDuty = abs(mean(M.heat) - mean(R.heat));
        dMax = max(abs(M.T(M.t <= 60) - R.T(M.t <= 60)));      % heating phase, before switching
        fprintf('  temperature %-6s  mean diff %.3f C, duty diff %.3f, early max diff %.3f C\n', mode{1}, dMean, dDuty, dMax);
        tc.verifyLessThan(dMean, 0.3, mode{1});
        tc.verifyLessThan(dDuty, 0.03, mode{1});
        tc.verifyLessThan(dMax, 0.05, mode{1});
    end
end

function testLevelModes(tc)
    for mode = {'ONOFF', 'P', 'PI'}
        c = enr312.level.defaultConfig(); c.mode = mode{1}; c.P.noise_us = 0;
        M = enr312.level.simulate(c);
        R = run_level_simulink(c, tc.TestData.dir);
        if strcmp(mode{1}, 'ONOFF')
            on = R.q > 0.5 * c.P.Q_max; tOn = R.t([false; diff(on) > 0]);
            tOn = tOn(tOn > 5);                               % drop the start-up edge (flow rising from 0)
            perR = mean(diff(tOn)); perM = M.metrics.cycle_period;
            fprintf('  level ONOFF  period MATLAB %.1f s, Simulink %.1f s\n', perM, perR);
            tc.verifyLessThan(abs(perR - perM) / perM, 0.03);
        else
            tail = R.t >= 0.75 * c.Tend;                      % same window as enr312.level.metrics (no drain step)
            essR = c.setpoint - mean(R.level(tail));
            fprintf('  level %-5s  e_ss MATLAB %.2f %%, Simulink %.2f %%\n', mode{1}, M.metrics.ss_error, essR);
            tc.verifyLessThan(abs(essR - M.metrics.ss_error), 0.5, mode{1});
        end
    end
end
