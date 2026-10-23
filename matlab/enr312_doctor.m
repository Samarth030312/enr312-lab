function report = enr312_doctor(varargin)
%ENR312_DOCTOR  Check this computer for the ENR312 lab and say how to fix each problem.
%
%   enr312_doctor            check (Windows, macOS, Linux)
%   enr312_doctor fix        also install the Arduino toolchain if it is missing
%   enr312_doctor probe      also ask the board for its firmware ($HELLO)
%
%   Run from the matlab folder of the repository. Details: enr312.doctor.
    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, 'functions'));
    a = lower(string(varargin));
    r = enr312.doctor('Fix', any(a == "fix"), 'Probe', any(a == "probe"));
    if nargout, report = r; end
end
