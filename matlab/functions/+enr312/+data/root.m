function r = root()
%ROOT  Where run data lives: the repository, or ENR312_DATA_ROOT (tests write elsewhere).
    r = enr312.repoRoot();
    if ~isempty(getenv('ENR312_DATA_ROOT')), r = getenv('ENR312_DATA_ROOT'); end
end
