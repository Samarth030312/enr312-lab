function c = presetConfig(name)
%PRESETCONFIG  Configuration for a named temperature preset.
    p = enr312.temperature.presets();
    k = find(strcmp({p.name}, name), 1);
    assert(~isempty(k), 'enr312:temperature:preset', 'no preset named ''%s''', name);
    c = enr312.temperature.defaultConfig();
    c.experiment = p(k).experiment;
    s = p(k).set;
    for i = 1:2:numel(s), c.(s{i}) = s{i + 1}; end
end
