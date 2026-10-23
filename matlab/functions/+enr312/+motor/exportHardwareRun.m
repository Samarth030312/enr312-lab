function out = exportHardwareRun(T, c, events, info)
%EXPORTHARDWARERUN  Save a live DC-motor run as evidence and register it (enr312.data.saveRun).
%
%   out = enr312.motor.exportHardwareRun(T, c, events, info)
%
%   info.mission sets the run id's tag (M1..M10, LAB); see enr312.data.saveRun for the rest.
%   out: runId, runNo, csv, meta. Raw data is never overwritten (docs/DATA_MANAGEMENT.md).
    if nargin < 4, info = struct(); end
    if ~isfield(info, 'mission') || isempty(info.mission), info.mission = 'LAB'; end
    if ~isfield(info, 'experiment'), info.experiment = getf(c, 'preset', ''); end
    out = enr312.data.saveRun('MOTOR', T, c, events, info);
end

function v = getf(s, f, d)
    if isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = d; end
end
