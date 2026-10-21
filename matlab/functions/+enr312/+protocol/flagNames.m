function names = flagNames(flags, type)
%FLAGNAMES  Decode a telemetry status bit field into a cell array of names.
%   names = enr312.protocol.flagNames(flags, type)     type default 'TEL'
    if nargin < 2, type = 'TEL'; end
    bits = enr312.protocol.schema(type).flags;
    names = bits(logical(bitget(uint16(flags), 1:numel(bits))));
end
