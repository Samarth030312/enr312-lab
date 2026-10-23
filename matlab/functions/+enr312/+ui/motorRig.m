function rig = motorRig(ax)
%MOTORRIG  3-D model of the DC-motor rig, for live display in the mission-control app.
%
%   rig = enr312.ui.motorRig(ax)                     % ax: uiaxes
%   enr312.ui.motorRigPose(rig, angleDeg, speedRpm, opts)
%
%   RMCS-5032 gear motor (encoder cap, motor can, 100:1 planetary gearbox) on a bracket,
%   an indicator disc on the output shaft, the RMCS-2303 drive, the Arduino Uno, the
%   battery, and the cables between them in the lab's colours (DC_MOTOR_WIRING.md).
%   A speed ring around the disc shows |speed| out of 180 rpm, with the setpoint as a tick.
%   Proportions are representative, not measured.

    K = enr312.ui.palette();
    hold(ax, 'on'); axis(ax, 'equal'); axis(ax, 'off');
    ax.Color = 'none'; ax.Clipping = 'off';
    try, ax.Toolbar.Visible = 'off'; catch, end
    try, disableDefaultInteractivity(ax); catch, end
    view(ax, 58, 17);
    xlim(ax, [-0.16 0.14]); ylim(ax, [-0.12 0.11]); zlim(ax, [0 0.10]);

    can = [0.66 0.69 0.73]; gear = [0.78 0.70 0.48]; dark = [0.10 0.11 0.13];
    pcbG = [0.08 0.30 0.18]; pcbB = [0.02 0.33 0.47]; alu = [0.72 0.75 0.79];

    zA = 0.058;                                                        % shaft axis height
    box3([-0.01 0 0.005], [0.30 0.22 0.010], [0.12 0.13 0.16], ax);    % base plate
    box3([0.001 0 0.031], [0.006 0.050 0.042], alu * 0.8, ax);         % motor bracket
    cyl3([-0.105 0 zA], 0.016, 0.022, dark, ax);                       % encoder cap
    cyl3([-0.083 0 zA], 0.018, 0.058, can, ax);                        % motor can
    cyl3([-0.025 0 zA], 0.019, 0.047, gear, ax);                       % planetary gearbox
    cyl3([0.022 0 zA], 0.004, 0.034, alu, ax);                         % output shaft (6 mm D)

    % output disc: rotates with the output angle (hgtransform about the x axis)
    rig.disc = hgtransform('Parent', ax);
    xD = 0.052; R = 0.040;
    cyl3([xD 0 0], R, 0.006, [0.16 0.18 0.22], rig.disc);
    for a = 0:30:330                                                   % face ticks every 30 deg
        L = 0.005 + 0.004 * (mod(a, 90) == 0);
        plot3(rig.disc, [1 1] * (xD + 0.0065), -[R - 0.002, R - 0.002 - L] * sind(a), [R - 0.002, R - 0.002 - L] * cosd(a), ...
              '-', 'Color', K.dim, 'LineWidth', 1 + (mod(a, 90) == 0));
    end
    rig.marker = patch(rig.disc, 'XData', [1 1 1 1] * (xD + 0.0068), 'YData', [-0.0028 0.0028 0.0028 -0.0028], ...
        'ZData', [0.004 0.004 R - 0.004 R - 0.004], 'FaceColor', K.orange, 'EdgeColor', 'none');
    cyl3([xD + 0.006 0 0], 0.006, 0.004, alu, rig.disc);               % hub
    rig.disc.Matrix = makehgtform('translate', [0 0 zA]);
    rig.trail = patch(ax, 'XData', nan, 'YData', nan, 'ZData', nan, 'FaceColor', K.cyan, ...
        'FaceAlpha', 0.22, 'EdgeColor', 'none');
    rig.ref = plot3(ax, nan, nan, nan, '--', 'Color', K.text, 'LineWidth', 1.6);

    % speed ring: |speed| / 180 rpm as a cyan arc; the setpoint as a white tick
    Rr = R + 0.008;
    th = linspace(0, 2 * pi, 121);
    plot3(ax, (xD + 0.008) * ones(size(th)), Rr * cos(th), zA + Rr * sin(th), '-', ...
          'Color', K.line, 'LineWidth', 3);
    rig.ring = plot3(ax, nan, nan, nan, '-', 'Color', K.cyan, 'LineWidth', 4);
    rig.ringSp = plot3(ax, nan, nan, nan, '-', 'Color', K.text, 'LineWidth', 3.5);
    rig.xRing = xD + 0.009; rig.zA = zA; rig.xFace = xD + 0.007; rig.R = R; rig.Rr = Rr;

    % RMCS-2303 drive (front left), Arduino Uno (front right), battery (behind)
    yF = -0.085;
    box3([-0.075 yF 0.016], [0.075 0.052 0.012], pcbG, ax);
    for f = -0.03:0.008:0.03, box3([-0.075 + f yF 0.030], [0.003 0.040 0.016], alu * 0.7, ax); end
    box3([0.070 yF 0.014], [0.069 0.053 0.008], pcbB, ax);
    box3([0.092 yF 0.022], [0.016 0.012 0.008], alu * 0.85, ax);      % USB-B socket
    box3([-0.100 0.075 0.027], [0.070 0.040 0.034], dark, ax);        % battery
    box3([-0.100 0.075 0.045], [0.070 0.040 0.002], [0.75 0.12 0.12], ax);

    % cables (lab colours): battery -> drive, drive -> motor, encoder, Arduino <-> drive
    cable(ax, [-0.110 0.060 0.044; -0.14 0.00 0.03; -0.105 yF + 0.02 0.024], [0.85 0.15 0.15], 2.4);
    cable(ax, [-0.090 0.060 0.044; -0.125 0.00 0.03; -0.100 yF + 0.02 0.024], [0.15 0.15 0.15], 2.4);
    cable(ax, [-0.06 yF + 0.025 0.022; -0.06 -0.03 0.04; -0.06 -0.012 zA], [0.85 0.15 0.15], 2.0);
    cable(ax, [-0.055 yF + 0.025 0.022; -0.055 -0.03 0.045; -0.055 -0.012 zA], [0.15 0.15 0.15], 2.0);
    cable(ax, [-0.11 -0.012 zA; -0.10 -0.04 0.035; -0.09 yF + 0.02 0.024], [0.20 0.70 0.30], 1.2);
    cable(ax, [-0.040 yF - 0.005 0.024; 0.00 yF - 0.015 0.03; 0.040 yF - 0.005 0.02], [0.25 0.45 0.95], 1.2);
    cable(ax, [-0.040 yF + 0.008 0.024; 0.00 yF + 0.015 0.03; 0.040 yF + 0.008 0.02], [0.95 0.85 0.20], 1.2);

    rig.labels = [ ...
        text(ax, -0.075, yF, 0.05, 'RMCS-2303', 'Color', K.dim, 'FontSize', 9, 'HorizontalAlignment', 'center'), ...
        text(ax, 0.070, yF, 0.035, 'Arduino Uno', 'Color', K.dim, 'FontSize', 9, 'HorizontalAlignment', 'center'), ...
        text(ax, -0.06, 0.0, zA + 0.035, 'RMCS-5032  100:1', 'Color', K.dim, 'FontSize', 9, 'HorizontalAlignment', 'center'), ...
        text(ax, -0.10, 0.075, 0.065, 'battery', 'Color', K.dim, 'FontSize', 9, 'HorizontalAlignment', 'center')];
    light(ax, 'Position', [0.8 -0.6 1.0]); light(ax, 'Position', [-0.5 0.5 0.6], 'Color', [0.35 0.35 0.40]);
    rig.prev = 0;
    enr312.ui.motorRigPose(rig, 0, 0);
end

function box3(c, d, col, parent)
    [X, Y, Z] = ndgrid([-1 1] * d(1) / 2, [-1 1] * d(2) / 2, [-1 1] * d(3) / 2);
    V = [X(:) Y(:) Z(:)] + c;
    F = [1 2 4 3; 5 6 8 7; 1 2 6 5; 3 4 8 7; 1 3 7 5; 2 4 8 6];
    shade = [0.70 0.70 0.86 0.86 0.78 1.00]';
    patch('Vertices', V, 'Faces', F, 'FaceVertexCData', min(1, shade * col), 'FaceColor', 'flat', ...
          'EdgeColor', col * 0.5, 'LineWidth', 0.5, 'FaceLighting', 'none', 'Parent', parent);
end

function cyl3(base, rad, len, col, parent)
%CYL3  Cylinder along +x from base, closed at both ends.
    [Y, Z, X] = cylinder(rad, 36); X = X * len;
    surf(X + base(1), Y + base(2), Z + base(3), 'FaceColor', col, 'EdgeColor', 'none', ...
         'FaceLighting', 'gouraud', 'AmbientStrength', 0.5, 'SpecularStrength', 0.6, 'Parent', parent);
    th = linspace(0, 2 * pi, 37);
    for e = [0 len]
        patch(base(1) + e + 0 * th, base(2) + rad * cos(th), base(3) + rad * sin(th), col * 0.92, ...
              'EdgeColor', 'none', 'FaceLighting', 'gouraud', 'Parent', parent);
    end
end

function cable(ax, P, col, w)
    t = linspace(0, 1, 24)';
    B = (1 - t).^2 .* P(1, :) + 2 * (1 - t) .* t .* P(2, :) + t.^2 .* P(3, :);   % quadratic Bezier
    plot3(ax, B(:, 1), B(:, 2), B(:, 3), '-', 'Color', col, 'LineWidth', w);
end
