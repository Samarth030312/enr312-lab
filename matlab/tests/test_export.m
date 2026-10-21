function tests = test_export
%TEST_EXPORT  Simulation evidence files are complete and labelled SIMULATION.
    tests = functiontests(localfunctions);
end

function setupOnce(~)
    run(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'setup_enr312.m'));
end

function testExportWritesLabelledEvidence(tc)
    tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
    c = enr312.motor.presetConfig('Rig - speed - PI, Kp 0.3 Ki 1.5');
    S = enr312.motor.simulate(c);
    out = enr312.motor.exportRun(S, tmp.Folder);
    tc.verifyTrue(startsWith(out.runId, 'MOTOR-07-SIM-'));
    for f = {'trace.csv', 'samples.csv', 'run_config.json', 'summary.md'}
        tc.verifyTrue(isfile(fullfile(out.dir, f{1})), f{1});
    end
    meta = jsondecode(fileread(fullfile(out.dir, 'run_config.json')));
    tc.verifyEqual(meta.data_class, 'SIMULATION');
    tc.verifyEqual(meta.parameters.J.status, 'ESTIMATED');
    tc.verifyEqual(meta.config.Kp, 0.3);
    T = readtable(fullfile(out.dir, 'trace.csv'));
    tc.verifyEqual(T.Properties.VariableNames, {'t_s', 'setpoint', 'output_true', 'control_applied', ...
        'current_A', 'speed_out_rpm', 'angle_out_deg'});
    tc.verifyEqual(height(T), numel(S.t));
    tc.verifySubstring(fileread(fullfile(out.dir, 'summary.md')), 'Data class: SIMULATION');
end

function testRunIdsAreNeverReused(tc)
    tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
    S = enr312.motor.simulate(enr312.motor.presetConfig('Rig - speed - P, Kp 0.5'));
    ids = cell(1, 3);
    for k = 1:3, o = enr312.motor.exportRun(S, tmp.Folder); ids{k} = o.runId; end
    tc.verifyEqual(numel(unique(ids)), 3);
    tc.verifyEqual(numel(dir(fullfile(tmp.Folder, 'MOTOR-05-SIM-*'))), 3);
end
