function S = simulate(c)
%SIMULATE  Tank level loop as the Arduino runs it.
%
%   S = enr312.level.simulate(c)
%
%   TANK (ASSUMED):  A dh/dt = q_pump - k_out d sqrt(h),  0 <= h <= H
%     d = 1, or c.drainFactor after c.tDrain (outlet opened: disturbance)
%   PUMP: command -> dead time -> first-order spin-up; PWM below pwm_dead gives no flow
%   SENSOR: HC-SR04 every 0.1 s, distance = h_sensor - h, quantised, noisy
%   CONTROL every 0.1 s:
%     ONOFF  relay: on below Lmin, off above Lmax, hold in between (course)
%     P / PI u = Kp e (+ Ki integral, clamping anti-windup), 0..255 PWM
%   GUARDS (as the firmware): pump off above L_over; latched off if commanded
%   near full (u >= 200) for t_dry without a 2 % rise (dry run / empty supply).

    P = c.P; dt = 0.01; Ts = P.Ts;
    N = round(c.Tend / dt) + 1; nTs = round(Ts / dt); nDel = max(1, round(P.delay / dt));
    rs = RandStream('mt19937ar', 'Seed', c.seed);
    dec = round(0.1 / dt); M = floor((N - 1) / dec) + 1;
    [tt, hl, lml, el, ul, qil, qol, stl] = deal(nan(M, 1));

    h = c.h0 / 100 * P.H; q = 0; cmdBuf = zeros(nDel, 1); dp = 1;
    pumpOn = false; u = 0; I = 0; lvl = c.h0; starts = 0; lastOn = false;
    fullSince = NaN; lvlAtFull = 0; dryLatched = false;
    guard = ''; m = 0;
    for k = 1:N
        t = (k - 1) * dt;
        if mod(k - 1, nTs) == 0
            d = P.h_sensor - h + P.noise_us * randn(rs);
            d = round(d / P.res_us) * P.res_us;
            lvl = 100 * (P.h_sensor - d) / P.H;
            switch c.mode
                case 'ONOFF'
                    if lvl < c.Lmin, pumpOn = true; elseif lvl > c.Lmax, pumpOn = false; end
                    u = 255 * pumpOn;
                case {'P', 'PI'}
                    e = c.setpoint - lvl;
                    Ki = c.Ki * strcmp(c.mode, 'PI');
                    iNew = I + Ki * Ts * e;
                    uRaw = c.Kp * e + iNew;
                    u = min(max(uRaw, 0), 255);
                    if u ~= uRaw && Ki ~= 0 && sign(uRaw - u) == sign(e)
                        iNew = min(max(iNew, -c.Kp * e), 255 - c.Kp * e);
                        if (e > 0 && iNew < I) || (e < 0 && iNew > I), iNew = I; end
                        u = min(max(c.Kp * e + iNew, 0), 255);
                    end
                    I = iNew; u = round(u);
                otherwise, error('enr312:level:mode', 'unknown mode %s', c.mode);
            end
            if lvl > P.L_over, u = 0; pumpOn = false; guard = 'OVERFLOW'; end
            on = u > 0;
            if on && ~lastOn, starts = starts + 1; end
            lastOn = on;
            % dry-run guard: commanded near full for t_dry with < 2 % rise => no water reaching the tank
            if u >= 200
                if isnan(fullSince), fullSince = t; lvlAtFull = lvl; end
                if t - fullSince > P.t_dry && lvl - lvlAtFull < 2
                    u = 0; pumpOn = false; guard = 'DRY-RUN'; dryLatched = true;
                end
            else
                fullSince = NaN;
            end
            if dryLatched, u = 0; end
        end
        duty = u / 255;
        if strcmp(c.mode, 'ONOFF'), flowCmd = P.Q_max * (u > 0);                 % relay: full on / off
        else, flowCmd = P.Q_max * max(0, (duty - P.pwm_dead) / (1 - P.pwm_dead)); end   % PWM via MOSFET
        delayed = cmdBuf(dp); cmdBuf(dp) = flowCmd; dp = mod(dp, nDel) + 1;
        q = q + dt / P.tau_pump * (delayed - q);
        dFac = 1 + (c.drainFactor - 1) * (t >= c.tDrain);
        qo = P.k_out * dFac * sqrt(max(h, 0));
        h = min(max(h + dt / P.A * (q - qo), 0), P.H);
        if mod(k - 1, dec) == 0
            m = m + 1;
            tt(m) = t; hl(m) = 100 * h / P.H; lml(m) = lvl; ul(m) = u;
            qil(m) = q * 60000; qol(m) = qo * 60000; stl(m) = starts;
            if strcmp(c.mode, 'ONOFF'), el(m) = NaN; else, el(m) = c.setpoint - lvl; end
        end
    end
    S = struct('t', tt(1:m), 'level', hl(1:m), 'meas', lml(1:m), 'e', el(1:m), 'u', ul(1:m), ...
        'qin', qil(1:m), 'qout', qol(1:m), 'starts', stl(1:m), 'guard', guard, 'cfg', c);
    S.units = struct('level', '% of tank height', 'u', '0..255 PWM (255 = relay on)', 'flow', 'L/min');
    S.metrics = enr312.level.metrics(S);
end
