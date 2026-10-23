function app = enr312_start(which)
%ENR312_START  One command: set the path, check the computer, install what is missing, open the lab.
%
%   enr312_start              DC-motor mission control (enr312_motor)
%   enr312_start temperature  temperature mission control (enr312_temp)
%   enr312_start water        water-level mission control (enr312_water)
%   enr312_start none         set-up and checks only
%
%   The first time, it installs the project's Arduino toolchain (about 60 MB, into a
%   folder of your user account; no admin rights). Then it opens the app. Problems that
%   need you (a missing USB driver, Rosetta 2, permissions) are printed with the fix.
    if nargin < 1, which = 'motor'; end
    here = fileparts(mfilename('fullpath'));
    run(fullfile(here, 'setup_enr312.m'));
    fprintf('\nENR312 lab, %s\n', enr312.repoRoot());
    r = enr312.doctor('Fix', true, 'Quiet', true);
    bad = r(strcmp({r.status}, 'FAIL') | strcmp({r.status}, 'WARN'));
    for k = 1:numel(bad)
        fprintf('  %-4s %s: %s\n', bad(k).status, bad(k).check, bad(k).detail);
        if ~isempty(bad(k).fix), fprintf('       -> %s\n', bad(k).fix); end
    end
    if isempty(bad), fprintf('  All checks passed.\n'); end
    fprintf('  Full check any time: enr312_doctor\n\n');
    h = [];
    switch lower(char(which))
        case 'motor',       h = enr312_motor();
        case {'temperature', 'temp'}, h = enr312_temp();
        case {'level', 'water'}, h = enr312_water();
        case 'none'
        otherwise, error('enr312:start', 'Unknown app "%s": use motor, temperature, level or none.', which);
    end
    if nargout, app = h; end
end
