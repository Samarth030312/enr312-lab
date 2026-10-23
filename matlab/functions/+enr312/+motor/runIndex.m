function I = runIndex()
%RUNINDEX  Every recorded DC-motor rig run, newest first, from data/metadata/dc_motor/*.json.
%
%   I = enr312.motor.runIndex()       % table
%
%   Columns: id, created (datetime), experiment (MOTOR-nn), name (the hardware experiment,
%   without the "[run k/n]" suffix), run (k), loop, fb ('drive' | 'encoder' | ''), ctrl,
%   Kp, Ki, uMax, rows, result ('FINISHED' or the firmware's first error), port.
%   Only metadata is read (fast); the raw CSV is loaded on demand with loadHardwareRun.
    root = enr312.repoRoot();
    if ~isempty(getenv('ENR312_DATA_ROOT')), root = getenv('ENR312_DATA_ROOT'); end
    d = dir(fullfile(root, 'data', 'metadata', 'dc_motor', 'MOTOR-*-HW-*.json'));
    n = numel(d);
    id = cell(n, 1); created = NaT(n, 1); experiment = cell(n, 1); name = cell(n, 1); run = nan(n, 1);
    loop = cell(n, 1); fb = cell(n, 1); ctrl = cell(n, 1); Kp = nan(n, 1); Ki = nan(n, 1); uMax = nan(n, 1);
    rows = nan(n, 1); result = cell(n, 1); port = cell(n, 1); keep = true(n, 1);
    for k = 1:n
        try
            J = jsondecode(fileread(fullfile(d(k).folder, d(k).name)));
            c = J.config_sent;
            id{k} = J.run_id;
            created(k) = datetime(J.created(1:19), 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss');
            experiment{k} = getf(c, 'experiment', '');
            pr = getf(c, 'preset', '');
            tok = regexp(pr, '^(.*) \[run (\d+)/\d+\]$', 'tokens', 'once');
            if isempty(tok), name{k} = pr; else, name{k} = tok{1}; run(k) = str2double(tok{2}); end
            loop{k} = getf(c, 'loop', ''); ctrl{k} = getf(c, 'ctrl', '');
            fb{k} = ''; if strcmp(loop{k}, 'speed'), fb{k} = getf(c, 'spdFb', 'drive'); end
            Kp(k) = getf(c, 'Kp', NaN); Ki(k) = getf(c, 'Ki', NaN); uMax(k) = getf(c, 'uMax', NaN);
            rows(k) = getf(J, 'rows', NaN);
            result{k} = runResult(J, getf(c, 'Ts', 0.1));
            port{k} = ''; if isfield(J, 'link') && isfield(J.link, 'port'), port{k} = J.link.port; end
        catch
            keep(k) = false;                                  % unreadable metadata: not listed
        end
    end
    I = table(id, created, experiment, name, run, loop, fb, ctrl, Kp, Ki, uMax, rows, result, port);
    I = I(keep, :);
    I = sortrows(I, 'created', 'descend');
end

function v = getf(s, f, d)
    if isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = d; end
end

function s = runResult(J, Ts)
%RUNRESULT  'FINISHED', or the firmware error that stopped THIS run.
%   The stored event log covers the whole session up to the export, which happens right
%   after the run: the run's own events are the last rows*Ts (+1 s) seconds of it. Only
%   errors that stop a run ($ERR,1,RUN,... or HOME) count; a host-frame checksum complaint
%   ($ERR,1,?,...,checksum) is link noise, reported in link.invalidCount instead.
    s = 'FINISHED';
    if ~isfield(J, 'events') || ~iscell(J.events) || numel(J.events) < 3, return; end
    ev = J.events;
    if size(ev, 2) ~= 3, ev = reshape(ev, [], 3); end
    t = cellfun(@(x) double(x(1)), ev(:, 1));
    win = t >= max(t) - (getf(J, 'rows', 0) * Ts + 1);
    stop = win & strcmp(ev(:, 2), 'ERR') & startsWith(string(ev(:, 3)), ["RUN,", "HOME,"]);
    j = find(stop, 1);
    if ~isempty(j)
        p = strsplit(char(ev{j, 3}), ',');
        s = ['STOPPED: ' strtrim(p{end})];
    end
end
