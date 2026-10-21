function out = exportHardwareRun(T, c, events, info)
%EXPORTHARDWARERUN  Save a live hardware run as immutable raw evidence.
%
%   out = enr312.motor.exportHardwareRun(T, c, events, info)
%
%   T       telemetry table from HardwareLink.table()
%   c       the configuration that was sent (CFG / SET)
%   events  HardwareLink.eventLog (ACK / ERR / debug / invalid lines)
%   info    struct: port, invalidCount, seqGaps, operator notes...
%
%   Writes data/raw/dc_motor/<run_id>.csv (made read-only) and
%   data/metadata/dc_motor/<run_id>.json. Raw data is never overwritten
%   (docs/DATA_MANAGEMENT.md).

    root = enr312.repoRoot();
    if ~isempty(getenv('ENR312_DATA_ROOT')), root = getenv('ENR312_DATA_ROOT'); end   % tests: never write into the real data/raw
    exp = c.experiment; if isempty(exp), exp = 'MOTOR-XX'; end
    rawDir = fullfile(root, 'data', 'raw', 'dc_motor');
    metaDir = fullfile(root, 'data', 'metadata', 'dc_motor');
    if ~exist(rawDir, 'dir'), mkdir(rawDir); end
    if ~exist(metaDir, 'dir'), mkdir(metaDir); end
    runId = enr312.newRunId(sprintf('%s-HW', exp), @(id) exist(fullfile(rawDir, [id '.csv']), 'file'));
    csv = fullfile(rawDir, [runId '.csv']);
    assert(~exist(csv, 'file'), 'enr312:export:exists', 'refusing to overwrite %s', csv);
    writetable(T, csv);
    fileattrib(csv, '-w', 'a');

    meta = struct();
    meta.run_id = runId;
    meta.data_class = 'HARDWARE';
    meta.raw_data_file = strrep(csv, [root filesep], '');
    meta.created = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ssZ', 'TimeZone', 'local'));
    meta.matlab_version = version();
    meta.config_sent = rmfield(c, 'P');
    meta.parameter_status = 'Plant parameters in config are the ESTIMATED simulation values; they did not influence the hardware.';
    meta.link = info;
    meta.rows = height(T);
    meta.events = events;
    meta.execution_status = 'EXECUTED';
    fid = fopen(fullfile(metaDir, [runId '.json']), 'w');
    assert(fid > 0, 'enr312:export:open', 'cannot write metadata for %s', runId);
    fprintf(fid, '%s\n', jsonencode(meta, 'PrettyPrint', true));
    fclose(fid);
    out = struct('runId', runId, 'csv', csv, 'meta', fullfile(metaDir, [runId '.json']));
end
