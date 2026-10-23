function [P, D] = physics(spec)
%PHYSICS  Motor and drive parameters derived from datasheet values you can change.
%
%   [P, D] = enr312.motor.physics()          % the RMCS-5032 / RMCS-2303 / 11.2 V battery
%   [P, D] = enr312.motor.physics(spec)      % spec: any subset of enr312.motor.physics().spec fields
%
%   Datasheet inputs (spec, defaults from SRC-003 / SRC-002 unless marked):
%     V_nom 12 V, w_nl_out 180 rpm, N 100, I_nl 0.8 A, I_stall 7.5 A (the datasheet's "load
%     current up to 7.5 A", taken as stall: ESTIMATED), eta 1 (ASSUMED), J_rotor 1e-6 kg m^2
%     (ESTIMATED), L 0.5 mH (ESTIMATED), lines 13, J_load_out 0 (nothing on the shaft),
%     J_factor 1 (x1.5 for "+50 % inertia"), V_supply 11.2 V (battery, reported), capacity_mAh
%     NaN (unknown: runtime is then not estimated), I_drive 3 A (RMCS-2303 peak per phase).
%   Derived (standard permanent-magnet DC motor relations, base-motor side):
%     R  = V_nom / I_stall                         (stall: back-EMF zero)
%     Ke = (V_nom - I_nl R) / w_nl                  w_nl = N * w_nl_out in rad/s
%     Kt = Ke                                       (SI units)
%     b  = Kt I_nl / w_nl                           (no-load friction as viscous)
%     J  = J_factor (J_rotor + J_load_out / N^2)
%     tau_e = L / R,  tau_m = J R / (Kt Ke + R b)
%     w(s)/V(s) = Kt / ((J s + b)(L s + R) + Kt Ke)   (base rad/s per volt)
%   P is enr312.motor.params() with these values in place, ready for enr312.motor.simulate.
%   D holds the derived numbers and the transfer function (num, den; and in output rpm per V).
    def = struct('V_nom', 12, 'w_nl_out', 180, 'N', 100, 'I_nl', 0.8, 'I_stall', 7.5, 'eta', 1, ...
        'J_rotor', 1e-6, 'L', 0.5e-3, 'lines', 13, 'J_load_out', 0, 'J_factor', 1, ...
        'V_supply', 11.2, 'capacity_mAh', NaN, 'I_drive', 3);
    if nargin < 1, spec = struct(); end
    for f = fieldnames(def)', if ~isfield(spec, f{1}) || isempty(spec.(f{1})), spec.(f{1}) = def.(f{1}); end, end
    P = enr312.motor.params();
    rpm = 2 * pi / 60;
    w_nl = spec.w_nl_out * spec.N * rpm;
    R = spec.V_nom / spec.I_stall;
    Ke = (spec.V_nom - spec.I_nl * R) / w_nl;
    Kt = Ke; b = Kt * spec.I_nl / w_nl;
    J = spec.J_factor * (spec.J_rotor + spec.J_load_out / spec.N^2);
    P.N = spec.N; P.V_nom = spec.V_nom; P.w_nl_base = w_nl; P.I_nl = spec.I_nl;
    P.R = R; P.Ke = Ke; P.Kt = Kt; P.b = b; P.L = spec.L; P.eta = spec.eta;
    P.J = spec.J_factor * spec.J_rotor; P.J_load_out = spec.J_factor * spec.J_load_out;
    P.V_supply = spec.V_supply; P.I_lim_drive = spec.I_drive;
    P.lines = spec.lines; P.cpr_out = 4 * spec.lines * spec.N; P.deg_per_count = 360 / P.cpr_out;
    st = {'R', 'Ke', 'Kt', 'b'};
    for k = 1:numel(st), P.meta.(st{k}).status = 'ESTIMATED'; P.meta.(st{k}).note = 'derived from the datasheet values in enr312.motor.physics'; end
    num = Kt; den = [J * spec.L, J * R + b * spec.L, b * R + Kt * Ke];
    D = struct('spec', spec, 'R', R, 'Ke', Ke, 'Kt', Kt, 'b', b, 'J', J, 'L', spec.L, ...
        'tau_e', spec.L / R, 'tau_m', J * R / (Kt * Ke + R * b), 'num', num, 'den', den, ...
        'gain_rpm_per_V', Kt / (b * R + Kt * Ke) / rpm / spec.N, ...
        'w_free_out', spec.V_supply * Kt / (b * R + Kt * Ke) / rpm / spec.N, ...
        'T_stall_out', Kt * spec.I_stall * spec.N * spec.eta, 'cpr_out', P.cpr_out);
    D.tf = sprintf('w(s)/V(s) = %.4g / (%.3g s^2 + %.3g s + %.3g)  [base rad/s per V]', num, den);
end
