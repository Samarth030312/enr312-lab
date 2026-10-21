function P = params()
%PARAMS  RMCS-5032 motor + RMCS-2303 drive parameters, with provenance.
%
%   P = enr312.motor.params()
%
%   P.<name>       value, SI units unless the name says otherwise
%   P.meta.<name>  struct('unit', 'status', 'source', 'note')
%
%   Status vocabulary (docs/knowledge-base/INDEX.md):
%     VERIFIED_FROM_MANUAL  MEASURED  TESTED  ESTIMATED  ASSUMED  UNVERIFIED
%
%   MEASURED values cite the hardware session log they came from. The electromechanical
%   constants stay ESTIMATED (derivations: docs/knowledge-base/HARDWARE_REFERENCE.md 1.5):
%   behind the RMCS-2303 they are not observable at the Arduino's 100 ms sampling. The rig
%   itself is identified as a black box (enr312.motor.fitIdentified: K = 1, ramp 53 rpm/s).

    P = struct(); P.meta = struct();
    kgfcm = 0.0980665;                       % N*m per kgf*cm
    rpm   = 2 * pi / 60;                     % rad/s per rpm

    % ---------------------------------------------------- RMCS-5032 (SRC-003)
    add('N',            100,          '-',     'VERIFIED_FROM_MANUAL', 'SRC-003', 'gear ratio 1:100');
    add('V_nom',        12,           'V',     'VERIFIED_FROM_MANUAL', 'SRC-003', '');
    add('w_nl_base',    18000 * rpm,  'rad/s', 'VERIFIED_FROM_MANUAL', 'SRC-003', 'base no-load 18000 rpm');
    add('I_nl',         0.8,          'A',     'VERIFIED_FROM_MANUAL', 'SRC-003', 'no-load current');
    add('I_max_motor',  7.5,          'A',     'VERIFIED_FROM_MANUAL', 'SRC-003', '"up to 7.5 A (Max)"; stall vs peak UNVERIFIED');
    add('T_rated_out',  15 * kgfcm,   'N*m',   'VERIFIED_FROM_MANUAL', 'SRC-003', '15 kgf*cm');
    add('T_stall_out',  60 * kgfcm,   'N*m',   'VERIFIED_FROM_MANUAL', 'SRC-003', '60 kgf*cm; unreachable through 3 A drive (C-M5)');
    add('lines',        13,           '-',     'VERIFIED_FROM_MANUAL', 'SRC-003', 'encoder lines per base rev');
    add('cpr_out',      5200,         'count', 'VERIFIED_FROM_MANUAL', 'SRC-003', '13 x 4 x 100');

    % ------------------------------------------- electromechanical (ESTIMATED)
    add('R',   1.6,    'ohm',      'ESTIMATED', 'SRC-003', '12 V / 7.5 A, assuming 7.5 A is stall current');
    add('Ke',  (P.V_nom - P.I_nl * P.R) / P.w_nl_base, 'V*s/rad', 'ESTIMATED', 'SRC-003', '(V - I_nl R) / w_nl');
    add('Kt',  P.Ke,   'N*m/A',    'ESTIMATED', 'SRC-003', 'SI units: Kt = Ke');
    add('b',   P.Kt * P.I_nl / P.w_nl_base, 'N*m*s/rad', 'ESTIMATED', 'SRC-003', ...
        'Kt I_nl / w_nl; lumps Coulomb friction into viscous');
    add('J',   1.0e-6, 'kg*m^2',   'ESTIMATED', '',        'base side rotor + gearbox; typical 30 mm can; LARGEST UNCERTAINTY');
    add('L',   0.5e-3, 'H',        'ESTIMATED', '',        'typical; tau_e = L/R ~ 0.3 ms');
    add('eta', 1.0,    '-',        'ASSUMED',   'SRC-003', 'datasheet rated torques imply ~1');
    add('J_load_out', 0, 'kg*m^2', 'ASSUMED',   '',        'nothing mounted on the output shaft');

    % ---------------------------------------------------- RMCS-2303 (SRC-002)
    add('I_lim_drive',  3.0,   'A',       'VERIFIED_FROM_MANUAL', 'SRC-002', 'peak 3 A per phase, p.4');
    add('V_supply',     11.2,  'V',       'ASSUMED',              'user',    'battery, 11.2 V as reported 2026-10-11 (not measured); no power switch');
    add('acc_base_rpm_s', 5000, 'rpm/s',  'MEASURED',             'hw_session_20261011-122159', 'register 12 READ from the lab drive = 5000 (factory default 20000); units still UNVERIFIED (OI-M5)');
    add('spd_fb_step_base_rpm', 461.5, 'rpm', 'MEASURED',    'hw_session_20261011-131428', ...
        'speed register 24 moves in steps of 450-465 base rpm (mean 461.5 = 60/(13 lines x 10 ms)): the drive counts encoder LINES over a ~10 ms window (inferred)');
    add('w_free_out_rpm', 166, 'rpm',     'MEASURED',             'hw_session_20261011-122950', ...
        'full-voltage free-running speed on the 11.2 V battery (runaway with reversed encoder, LPR 13): 161-170 output rpm');
    add('spd_max_base_rpm', 18000, 'rpm', 'VERIFIED_FROM_MANUAL', 'SRC-002', 'never command above no-load speed, p.18');
    add('wc_drive',     40,    'rad/s',   'ESTIMATED',            '',        'drive internal speed-loop bandwidth; internals undocumented');

    % ------------------------------------------- Arduino <-> drive Modbus link
    add('baud_drive',   9600,  'bit/s',   'VERIFIED_FROM_MANUAL', 'SRC-002', 'all vendor examples; framing UNVERIFIED (OI-M3)');
    add('Ts_speed',     0.10,  's',       'ESTIMATED', '', 'write SPD + read speed ~ 66 chars at 9600 baud (ED-M1)');
    add('Ts_position',  0.15,  's',       'ESTIMATED', '', 'adds two position reads ~ 135 ms (ED-M1)');
    add('lat_speed',    0.07,  's',       'ESTIMATED', '', 'read then write: command lands ~ 69 ms after the sample');
    add('lat_position', 0.135, 's',       'ESTIMATED', '', '');

    % ------------------------------------------------------------ derived
    P.rpm = rpm;
    P.deg_per_count = 360 / P.cpr_out;
    P.w_max_out_rpm = P.spd_max_base_rpm / P.N;

    function add(name, value, unit, status, source, note)
        P.(name) = value;
        P.meta.(name) = struct('unit', unit, 'status', status, 'source', source, 'note', note);
    end
end
