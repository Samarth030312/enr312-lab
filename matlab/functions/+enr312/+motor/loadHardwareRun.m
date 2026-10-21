function R = loadHardwareRun(runId)
%LOADHARDWARERUN  Read one exported DC-motor hardware run (raw CSV + metadata JSON).
%
%   R = enr312.motor.loadHardwareRun('MOTOR-02-HW-20261011-133631')
%
%   R.T     table (seq, t_ms, loop, ctrl, setpoint, meas, err, u, pos_counts, spd_base_rpm, flags, t_s)
%   R.meta  decoded metadata (config_sent, link, ...)
%   R.cfg   simulation config rebuilt from config_sent (enr312.motor.defaultConfig + fields)
%   R.id    run id
%   Raw files are only read.

    root = enr312.repoRoot();
    if ~isempty(getenv('ENR312_DATA_ROOT')), root = getenv('ENR312_DATA_ROOT'); end
    f = fullfile(root, 'data', 'raw', 'dc_motor', [runId '.csv']);
    assert(isfile(f), 'enr312:motor:run', 'no raw data %s', f);
    R.id = runId;
    R.T = readtable(f, 'TextType', 'char');
    R.meta = jsondecode(fileread(fullfile(root, 'data', 'metadata', 'dc_motor', [runId '.json'])));
    cs = R.meta.config_sent;
    c = enr312.motor.defaultConfig('rig', cs.loop);
    for k = fieldnames(cs)'
        if ~strcmp(k{1}, 'P'), c.(k{1}) = cs.(k{1}); end
    end
    R.cfg = c;
end
