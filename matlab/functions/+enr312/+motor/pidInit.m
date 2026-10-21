function st = pidInit()
%PIDINIT  Zero state for enr312.motor.pidStep.
    st = struct('i', 0, 'd', 0, 'e', 0, 'first', true);
end
