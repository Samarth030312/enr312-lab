function P = paths()
%PATHS  Where the project's own Arduino toolchain lives on this computer.
%
%   P = enr312.tools.paths()
%
%   P.root      tool folder, used by this project only
%   P.cli       arduino-cli executable (P.root/arduino-cli/arduino-cli[.exe])
%   P.data, P.downloads, P.user   arduino-cli directories (cores, archives, libraries)
%   P.build     build folder for compiled sketches
%   P.arch      MATLAB's computer('arch'): win64, maci64, maca64, glnxa64, glnxaarm64
%
%   Default root:
%     Windows   %LOCALAPPDATA%\enr312      (C:\enr312-tools if that path is not plain ASCII:
%                                           the AVR compiler fails on non-ASCII paths)
%     macOS     ~/Library/Application Support/enr312
%     Linux     ~/.local/share/enr312  (or ~/Projects/tools if an earlier set-up is there)
%   Set the environment variable ENR312_TOOLS to use another folder.
%
%   Nothing is written to the global Arduino folders (~/.arduino15, Documents\Arduino),
%   so an Arduino IDE on the same computer is unaffected.

    P.arch = computer('arch');
    root = getenv('ENR312_TOOLS');
    if isempty(root)
        if ispc
            root = fullfile(getenv('LOCALAPPDATA'), 'enr312');
            if isempty(getenv('LOCALAPPDATA')) || any(double(root) > 127)
                root = fullfile(getenv('SystemDrive'), 'enr312-tools');
                if isempty(getenv('SystemDrive')), root = 'C:\enr312-tools'; end
            end
        elseif ismac
            root = fullfile(getenv('HOME'), 'Library', 'Application Support', 'enr312');
        else
            legacy = fullfile(getenv('HOME'), 'Projects', 'tools');
            if isfolder(fullfile(legacy, 'arduino-enr312'))
                root = legacy;
            else
                root = fullfile(getenv('HOME'), '.local', 'share', 'enr312');
            end
        end
    end
    P.root = root;
    exe = 'arduino-cli'; if ispc, exe = 'arduino-cli.exe'; end
    P.cli = fullfile(root, 'arduino-cli', exe);
    P.data = fullfile(root, 'arduino-enr312', 'data');
    P.downloads = fullfile(root, 'arduino-enr312', 'downloads');
    P.user = fullfile(root, 'arduino-enr312', 'user');
    P.build = fullfile(root, 'build');
end
