function migrate_run_ids_20261024()
%MIGRATE_RUN_IDS_20261024  One-off (2026-10-24): the 61 motor runs to the run-register scheme.
%
%   Old ids (MOTOR-02-HW-20261023-185447) named an internal experiment number (MOTOR-02 ... 07)
%   that matched neither the app's missions nor the course questions. New ids are
%   MOTOR-R<nnnn>_<yyyymmdd-HHMMSS>_<mission>, numbered in time order. For every run:
%   the CSV and PNG are renamed with git mv (content unchanged), the JSON gets run_id,
%   run_no, apparatus, mission, rig and legacy_id, and a row goes into data/RUN_REGISTER.csv.
%   enr312.data.resolve and loadHardwareRun still accept the old ids. Kept as a record;
%   running it again does nothing (it only touches files with old names).
    root = enr312.repoRoot();
    raw = fullfile(root, 'data', 'raw', 'dc_motor'); meta = fullfile(root, 'data', 'metadata', 'dc_motor');
    d = dir(fullfile(raw, 'MOTOR-0*-HW-*.csv'));
    if isempty(d), disp('nothing to migrate'); return; end
    ids = erase({d.name}, '.csv');
    stamp = regexprep(ids, '^MOTOR-\d+-HW-', '');
    [~, o] = sort(stamp); ids = ids(o); stamp = stamp(o);
    M = enr312.motor.missions();
    I = enr312.motor.runIndex();                   % results, read from the old files before renaming
    for k = 1:numel(ids)
        old = ids{k};
        J = jsondecode(fileread(fullfile(meta, [old '.json'])));
        c = J.config_sent;
        tag = missionTag(c, M);
        new = sprintf('MOTOR-R%04d_%s_%s', k, stamp{k}, tag);
        git(sprintf('mv "%s" "%s"', fullfile(raw, [old '.csv']), fullfile(raw, [new '.csv'])));
        if isfile(fullfile(meta, [old '.png']))
            git(sprintf('mv "%s" "%s"', fullfile(meta, [old '.png']), fullfile(meta, [new '.png'])));
        end
        hello = {};
        if isfield(J, 'events') && iscell(J.events)
            ev = J.events; if size(ev, 2) ~= 3, ev = reshape(ev, [], 3); end
            h = find(strcmp(ev(:, 2), 'HELLO'), 1, 'last');
            if ~isempty(h), hello = strsplit(ev{h, 3}, ','); end
        end
        fw = ''; if numel(hello) >= 2, fw = sprintf('%s %s', hello{1}, hello{2}); end
        rig = 'MOTOR bench'; if numel(hello) >= 3, rig = sprintf('MOTOR bench, drive id %s', hello{3}); end
        result = 'FINISHED';
        j = find(strcmp(I.id, old), 1); if ~isempty(j), result = I.result{j}; end
        pr = getf(c, 'preset', ''); tok = regexp(pr, '^(.*) \[run (\d+)/\d+\]$', 'tokens', 'once');
        expName = pr; runK = 1; if ~isempty(tok), expName = tok{1}; runK = str2double(tok{2}); end
        J2 = struct('run_id', new, 'run_no', k, 'apparatus', 'MOTOR', 'legacy_id', old, 'mission', tag, ...
            'rig', rig, 'experiment', expName, 'run_in_series', runK, 'firmware', fw, 'result', result);
        for f = fieldnames(J)'
            if ~isfield(J2, f{1}), J2.(f{1}) = J.(f{1}); end
        end
        J2.raw_data_file = ['data/raw/dc_motor/' new '.csv'];
        fid = fopen(fullfile(meta, [new '.json']), 'w'); fprintf(fid, '%s\n', jsonencode(J2, 'PrettyPrint', true)); fclose(fid);
        git(sprintf('rm -q "%s"', fullfile(meta, [old '.json'])));
        row = {new, 'MOTOR', k, J.created, rig, tag, expName, runK, getf(c, 'ctrl', ''), ...
               sprintf('loop=%s ctrl=%s Kp=%g Ki=%g', getf(c, 'loop', ''), getf(c, 'ctrl', ''), getf(c, 'Kp', NaN), getf(c, 'Ki', NaN)), ...
               result, getf(J, 'rows', NaN), fw, getf(J.link, 'port', ''), 'glnxa64', old, J2.raw_data_file, ...
               ['data/metadata/dc_motor/' new '.json']};
        enr312.data.appendRegister(row);
        fprintf('%-30s -> %s\n', old, new);
    end
    git(sprintf('add "%s" "%s"', meta, fullfile(root, 'data', 'RUN_REGISTER.csv')));

    function git(args)
        [st, out] = system(sprintf('git -C "%s" %s', root, args));
        assert(st == 0, 'migrate:git', '%s', out);
    end
end

function tag = missionTag(c, M)
    pr = getf(c, 'preset', '');
    tok = regexp(pr, '^(.*) \[run (\d+)/\d+\]$', 'tokens', 'once'); if ~isempty(tok), pr = tok{1}; end
    for k = 1:numel(M)
        if any(strcmp(M(k).experiments, pr)), tag = M(k).tag; return; end
    end
    loop = getf(c, 'loop', 'speed'); ctrl = getf(c, 'ctrl', 'OL');
    T = struct('speed', struct('OL', 'M1', 'P', 'M3', 'I', 'M4', 'PI', 'M5', 'PID', 'M5'), ...
               'position', struct('OL', 'M7', 'P', 'M7', 'I', 'M8', 'PI', 'M9', 'PID', 'M9'));
    tag = T.(loop).(ctrl);
end

function v = getf(s, f, d)
    if isstruct(s) && isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = d; end
end
