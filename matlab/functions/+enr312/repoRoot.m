function r = repoRoot()
%REPOROOT  Absolute path of the enr312-lab repository.
    r = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end
