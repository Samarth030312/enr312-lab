function T = record_all_simulations(subsystem, onlyMissing)
%RECORD_ALL_SIMULATIONS  Record a video + evidence for every preset of one app.
%
%   record_all_simulations('dc_motor' | 'temperature' | 'water_level', onlyMissing)
%
%   Opens the subsystem's app (needs a display), ticks "Record video", runs each
%   preset and lets the app export the run folder with simulation.mp4 into
%   results/evidence/simulation_runs/<subsystem>/<run_id>/.
%   onlyMissing (default true) skips presets that already have a recorded video.
%   A failure on one preset is logged and the batch continues.
%   Afterwards run write_video_index to refresh results/evidence/VIDEO_INDEX.md.
%   (Pneumatics: FluidSIM screen recordings, see pneumatic/README.md.)

    if nargin < 2, onlyMissing = true; end
    if strcmp(subsystem, 'dc_motor')                 % mission control: one video per mission
        motor_formal_runs(true, true); T = table(); return;
    end
    switch subsystem
        case 'temperature', app = TemperatureControlApp(); names = {enr312.temperature.presets().name};
        case 'water_level', app = WaterLevelApp();         names = {enr312.level.presets().name};
        otherwise, error('enr312:record:subsystem', 'unknown subsystem %s', subsystem);
    end
    cl = onCleanup(@() delete(app.fig));
    done = recordedPresets(subsystem);
    app.ui.record.Value = true;
    rows = {};
    for k = 1:numel(names)
        if onlyMissing && any(strcmp(done, names{k}))
            fprintf('skip   %-48s (already recorded)\n', names{k}); continue;
        end
        try
            t0 = tic;
            app.preset(names{k}); drawnow; pause(0.3);
            app.run();
            v = app.lastVideo();
            fprintf('ok     %-48s %5.0f s  %s\n', names{k}, toc(t0), v);
            rows(end + 1, :) = {names{k}, v, 'ok'}; %#ok<AGROW>
        catch err
            fprintf('FAILED %-48s %s\n', names{k}, err.message);
            rows(end + 1, :) = {names{k}, '', err.message}; %#ok<AGROW>
        end
    end
    T = cell2table(rows, 'VariableNames', {'preset', 'video', 'status'});
end

function p = recordedPresets(subsystem)
    root = fullfile(enr312.repoRoot(), 'results', 'evidence', 'simulation_runs', subsystem);
    p = {};
    d = dir(fullfile(root, '*', 'simulation.mp4'));
    for k = 1:numel(d)
        f = fullfile(d(k).folder, 'run_config.json');
        if isfile(f)
            m = jsondecode(fileread(f));
            if isfield(m, 'preset'), p{end + 1} = m.preset; end %#ok<AGROW>
        end
    end
end
