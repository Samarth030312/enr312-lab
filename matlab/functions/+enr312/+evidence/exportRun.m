function out = exportRun(subsystem, experiment, trace, samples, cfg, P, metrics, units, extra)
%EXPORTRUN  Write one simulation run as evidence (any subsystem).
%
%   out = enr312.evidence.exportRun(subsystem, experiment, trace, samples, cfg, P, metrics, units, extra)
%
%   subsystem   'temperature' | 'water_level' | 'dc_motor'   (pneumatics: FluidSIM only)
%   experiment  e.g. 'TEMP-02'; the run ID is <experiment>-SIM-<timestamp>[-n]
%   trace       table, fine-grid signals          -> trace.csv
%   samples     table or [], controller samples   -> samples.csv
%   cfg         configuration struct (no parameter struct inside)
%   P           parameter struct with P.meta.<name>.status/unit/source
%   metrics     struct
%   units       struct of unit strings
%   extra       struct merged into run_config.json
%
%   Output: results/evidence/simulation_runs/<subsystem>/<run_id>/ with
%   trace.csv, [samples.csv], run_config.json, summary.md. SIMULATION data only.

    if nargin < 9, extra = struct(); end
    root = fullfile(enr312.repoRoot(), 'results', 'evidence', 'simulation_runs', subsystem);
    if isfield(extra, 'outRoot'), root = extra.outRoot; extra = rmfield(extra, 'outRoot'); end
    if ~exist(root, 'dir'), mkdir(root); end
    if isempty(experiment), experiment = 'UNASSIGNED'; end
    runId = enr312.newRunId([experiment '-SIM'], @(id) exist(fullfile(root, id), 'file'));
    dirOut = fullfile(root, runId);
    mkdir(dirOut);
    writetable(trace, fullfile(dirOut, 'trace.csv'));
    if ~isempty(samples), writetable(samples, fullfile(dirOut, 'samples.csv')); end

    meta = struct();
    meta.run_id = runId;
    meta.subsystem = subsystem;
    meta.data_class = 'SIMULATION';
    meta.statement = 'MODEL output. Not measured. Parameters are ESTIMATED/ASSUMED unless marked otherwise.';
    meta.created = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ssZ', 'TimeZone', 'local'));
    meta.matlab_version = version();
    meta.git = gitInfo();
    meta.config = cfg;
    meta.units = units;
    meta.parameters = paramTable(P);
    meta.metrics = metrics;
    f = fieldnames(extra);
    for i = 1:numel(f), meta.(f{i}) = extra.(f{i}); end
    fid = fopen(fullfile(dirOut, 'run_config.json'), 'w');
    assert(fid > 0, 'enr312:export:open', 'cannot write %s', dirOut);
    fprintf(fid, '%s\n', jsonencode(meta, 'PrettyPrint', true));
    fclose(fid);
    writeSummary(fullfile(dirOut, 'summary.md'), meta);
    out = struct('runId', runId, 'dir', dirOut);
end

function p = paramTable(P)
    p = struct();
    if ~isfield(P, 'meta'), return; end
    f = fieldnames(P.meta);
    for i = 1:numel(f)
        m = P.meta.(f{i});
        p.(f{i}) = struct('value', P.(f{i}), 'unit', m.unit, 'status', m.status, 'source', m.source);
    end
end

function g = gitInfo()
    root = enr312.repoRoot();
    [s1, rev] = system(sprintf('git -C "%s" rev-parse --short HEAD', root));
    [s2, st]  = system(sprintf('git -C "%s" status --porcelain', root));
    g = struct('revision', strtrim(rev), 'dirty', s2 == 0 && ~isempty(strtrim(st)));
    if s1 ~= 0, g.revision = 'unknown'; end
end

function writeSummary(file, meta)
    fid = fopen(file, 'w'); cleaner = onCleanup(@() fclose(fid));
    fprintf(fid, '# %s\n\n**Data class: SIMULATION.** %s\n\n', meta.run_id, meta.statement);
    fprintf(fid, '| Setting | Value |\n|---|---|\n');
    writeRows(fid, meta.config);
    fprintf(fid, '| MATLAB | %s |\n| Git | %s (dirty: %d) |\n\n', meta.matlab_version, meta.git.revision, meta.git.dirty);
    fprintf(fid, '## Metrics\n\n| Metric | Value |\n|---|---|\n');
    writeRows(fid, meta.metrics);
    fprintf(fid, '\nNaN means "not applicable" or "did not happen in the window".\n');
    fprintf(fid, '\nParameter values and their status (ESTIMATED / ASSUMED / VERIFIED_FROM_MANUAL) are in run_config.json.\n');
end

function writeRows(fid, s)
    f = fieldnames(s);
    for i = 1:numel(f)
        v = s.(f{i});
        if isnumeric(v) || islogical(v)
            if isscalar(v), t = sprintf('%.4g', v); else, t = mat2str(v, 4); end
        elseif ischar(v) || isstring(v), t = char(v);
        else, continue;
        end
        fprintf(fid, '| %s | %s |\n', f{i}, t);
    end
end
