function setup_enr312()
%SETUP_ENR312  Put the ENR312 MATLAB code (and only it) on the path for this session.
%
%   run('<repo>/matlab/setup_enr312.m')
%   then: MotorControlApp, TemperatureControlApp, WaterLevelApp
%   (pneumatics are done in Festo FluidSIM, not MATLAB: see pneumatic/README.md)
%
%   Only folders inside this repository are added. Nothing from other projects
%   is touched; check with scripts/validation/check_isolation.sh.
    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, 'functions'));
    apps = dir(fullfile(here, 'apps'));
    for a = apps([apps.isdir] & ~startsWith({apps.name}, '.'))'
        addpath(fullfile(a.folder, a.name));
    end
    models = dir(fullfile(here, 'models'));
    for m = models([models.isdir] & ~startsWith({models.name}, '.'))'
        addpath(fullfile(m.folder, m.name));
    end
    addpath(fullfile(here, 'scripts'));
end
