function write_video_index()
%WRITE_VIDEO_INDEX  List every recorded simulation video in results/evidence/VIDEO_INDEX.md.
%   One row per run folder that contains simulation.mp4: subsystem, experiment,
%   preset, verdict, duration (ffprobe), path. Recordings made outside MATLAB
%   (FluidSIM screen captures) are listed from results/evidence/screen_recordings/.
    root = enr312.repoRoot();
    ev = fullfile(root, 'results', 'evidence');
    fid = fopen(fullfile(ev, 'VIDEO_INDEX.md'), 'w'); cl = onCleanup(@() fclose(fid));
    fprintf(fid, '# Simulation video index\n\nGenerated %s by `write_video_index`. All entries are **SIMULATION** recordings ', ...
        char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')));
    fprintf(fid, '(the app window captured frame by frame while the model ran), not hardware.\n\n');
    for sub = {'dc_motor', 'temperature', 'water_level'}
        d = dir(fullfile(ev, 'simulation_runs', sub{1}, '*', 'simulation.mp4'));
        fprintf(fid, '## %s (%d videos)\n\n| Run | Experiment | Preset | Verdict | Length | File |\n|---|---|---|---|---|---|\n', ...
            strrep(sub{1}, '_', ' '), numel(d));
        for k = 1:numel(d)
            meta = jsondecode(fileread(fullfile(d(k).folder, 'run_config.json')));
            [~, run] = fileparts(d(k).folder);
            exp = strtok(run, '-'); exp = regexp(run, '^[A-Z0-9]+-[0-9A-Z]+', 'match', 'once');
            preset = '(custom)'; if isfield(meta, 'preset'), preset = meta.preset; end
            verdict = ''; if isfield(meta, 'metrics') && isfield(meta.metrics, 'verdict'), verdict = meta.metrics.verdict; end
            [~, dur] = system(sprintf('ffprobe -v error -show_entries format=duration -of csv=p=0 "%s"', fullfile(d(k).folder, d(k).name)));
            rel = strrep(fullfile(d(k).folder, d(k).name), [ev filesep], '');
            fprintf(fid, '| %s | %s | %s | %s | %.1f s | [%s](%s) |\n', run, exp, preset, verdict, str2double(dur), 'simulation.mp4', rel);
        end
        fprintf(fid, '\n');
    end
    s = dir(fullfile(ev, 'screen_recordings', '**', '*.mp4'));
    fprintf(fid, '## Screen recordings (FluidSIM and others) (%d)\n\n', numel(s));
    for k = 1:numel(s)
        fprintf(fid, '- %s\n', strrep(fullfile(s(k).folder, s(k).name), [ev filesep], ''));
    end
end
