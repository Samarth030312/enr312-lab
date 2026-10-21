classdef LabWindow < handle
%LABWINDOW  Shared layout for the ENR312 lab apps (same look as MotorControlApp).
%
%   w = enr312.ui.LabWindow(title, plotLayout)
%
%   Header bar with a data-source badge; a scrollable control column (left);
%   status badge, caption and a picture axes (centre); a grid of plot axes
%   (right); results and model-limits panels (bottom).
%
%   plotLayout: cell array of {row, columns} for each plot axes in a 3 x 2 grid,
%   e.g. {{1, [1 2]}, {2, 1}, {2, 2}, {3, 1}, {3, 2}}.
%
%   Control helpers add rows to the control column:
%     s = w.slider(label, limits, value, fmt, @onChange)
%     d = w.dropdown(label, items, itemsData, value, @onChange)   label '' = full width
%     c = w.checkbox(text, value, @onChange)
%     b = w.button(text, @onPress, color)
%     h = w.section(text)
%   w.setSlider(s, value, limits, fmt) updates a slider and its value label.

    properties
        fig; srcBadge; cg; badge; caption; axView; ax; res; lim
        C
    end
    properties (Access = private)
        row = 0
    end

    methods
        function w = LabWindow(title, plotLayout)
            w.C = enr312.ui.colors();
            C = w.C;
            w.fig = uifigure('Name', title, 'Position', [40 30 1720 980], 'Color', C.bg);
            if exist('theme', 'file'), theme(w.fig, 'light'); end
            g = uigridlayout(w.fig, [3 3], 'RowHeight', {64, '1x', 250}, ...
                'ColumnWidth', {370, '1x', '1.25x'}, 'Padding', [10 10 10 10], ...
                'RowSpacing', 8, 'ColumnSpacing', 10, 'BackgroundColor', C.bg);
            hg = uigridlayout(g, [1 2], 'ColumnWidth', {'1x', 330}, 'Padding', [0 0 0 0], ...
                'ColumnSpacing', 0, 'BackgroundColor', C.navy);
            hg.Layout.Row = 1; hg.Layout.Column = [1 3];
            uilabel(hg, 'BackgroundColor', C.navy, 'FontColor', 'w', 'FontSize', 22, ...
                'FontWeight', 'bold', 'Text', ['   ' title]);
            w.srcBadge = uilabel(hg, 'FontColor', 'w', 'FontSize', 15, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', 'BackgroundColor', C.blue, ...
                'Text', 'SIMULATION  -  model, not measured');

            cp = uipanel(g, 'Title', 'Controls', 'FontWeight', 'bold', 'FontSize', 14, ...
                'BackgroundColor', 'w', 'Scrollable', 'on');
            cp.Layout.Row = [2 3]; cp.Layout.Column = 1;
            w.cg = uigridlayout(cp, [80 2], 'ColumnWidth', {'1x', 120}, 'RowSpacing', 2, ...
                'Padding', [10 6 10 6], 'BackgroundColor', 'w', 'Scrollable', 'on');
            w.cg.RowHeight = repmat({0}, 1, 80);

            rp = uipanel(g, 'BackgroundColor', 'w', 'BorderType', 'none');
            rp.Layout.Row = 2; rp.Layout.Column = 2;
            rg = uigridlayout(rp, [3 1], 'RowHeight', {36, 56, '1x'}, 'Padding', [0 0 0 0], ...
                'RowSpacing', 2, 'BackgroundColor', 'w');
            w.badge = uilabel(rg, 'Text', '', 'FontSize', 16, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', 'FontColor', 'w', 'BackgroundColor', C.navy);
            w.caption = uilabel(rg, 'FontSize', 14, 'WordWrap', 'on', 'HorizontalAlignment', 'center', ...
                'FontColor', C.navy, 'BackgroundColor', [0.91 0.94 0.99]);
            w.axView = uiaxes(rg); w.axView.Layout.Row = 3;
            hold(w.axView, 'on'); axis(w.axView, 'equal'); axis(w.axView, 'off');
            w.axView.Toolbar.Visible = 'off'; w.axView.Interactions = [];

            pg = uigridlayout(g, [3 2], 'RowHeight', {'1.3x', '1x', '1x'}, 'ColumnWidth', {'1x', '1x'}, ...
                'Padding', [0 0 0 0], 'RowSpacing', 4, 'ColumnSpacing', 6, 'BackgroundColor', C.bg);
            pg.Layout.Row = 2; pg.Layout.Column = 3;
            w.ax = gobjects(1, numel(plotLayout));
            for k = 1:numel(plotLayout)
                a = uiaxes(pg); a.Layout.Row = plotLayout{k}{1}; a.Layout.Column = plotLayout{k}{2};
                hold(a, 'on'); grid(a, 'on'); a.FontSize = 11; a.Box = 'on'; a.Toolbar.Visible = 'off';
                w.ax(k) = a;
            end

            w.res = uilabel(g, 'Interpreter', 'html', 'VerticalAlignment', 'top', ...
                'BackgroundColor', 'w', 'FontSize', 13, 'WordWrap', 'on');
            w.res.Layout.Row = 3; w.res.Layout.Column = 2;
            w.lim = uilabel(g, 'Interpreter', 'html', 'VerticalAlignment', 'top', 'WordWrap', 'on', ...
                'BackgroundColor', [1.0 0.97 0.88], 'FontSize', 12);
            w.lim.Layout.Row = 3; w.lim.Layout.Column = 3;
        end

        function r = nextRow(w, h)
            w.row = w.row + 1; w.cg.RowHeight{w.row} = h; r = w.row;
        end

        function h = section(w, txt)
            h = uilabel(w.cg, 'Text', txt, 'FontWeight', 'bold', 'FontSize', 13, ...
                'FontColor', w.C.navy, 'VerticalAlignment', 'bottom');
            place(h, w.nextRow(30), [1 2]);
        end

        function l = label(w, txt, r, c)
            l = uilabel(w.cg, 'Text', txt, 'FontSize', 12, 'WordWrap', 'on');
            place(l, r, c);
        end

        function s = slider(w, txt, lims, val, fmt, cb)
            l = w.label(txt, w.nextRow(20), 1);
            v = uilabel(w.cg, 'Text', sprintf(fmt, val), 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'right', 'FontColor', w.C.blue);
            place(v, w.row, 2);
            s = uislider(w.cg, 'Limits', lims, 'Value', val, 'MajorTicks', [], 'MinorTicks', []);
            place(s, w.nextRow(26), [1 2]);
            s.UserData = struct('valueLabel', v, 'fmt', fmt, 'label', l);
            s.ValueChangingFcn = @(~, e) set(v, 'Text', sprintf(s.UserData.fmt, e.Value));
            s.ValueChangedFcn = @(~, ~) cb();
        end

        function setSlider(~, s, val, lims, fmt)
            if nargin >= 4 && ~isempty(lims), s.Limits = lims; end
            if nargin >= 5, s.UserData.fmt = fmt; end
            s.Value = min(max(val, s.Limits(1)), s.Limits(2));
            s.UserData.valueLabel.Text = sprintf(s.UserData.fmt, s.Value);
        end

        function d = dropdown(w, txt, items, data, val, cb)
            if isempty(txt)
                d = uidropdown(w.cg, 'Items', items, 'ItemsData', data, 'Value', val, ...
                    'FontSize', 12, 'ValueChangedFcn', @(~, ~) cb());
                place(d, w.nextRow(28), [1 2]);
            else
                w.label(txt, w.nextRow(26), 1);
                d = uidropdown(w.cg, 'Items', items, 'ItemsData', data, 'Value', val, ...
                    'ValueChangedFcn', @(~, ~) cb());
                place(d, w.row, 2);
            end
        end

        function c = checkbox(w, txt, val, cb)
            c = uicheckbox(w.cg, 'Text', txt, 'Value', val, 'ValueChangedFcn', @(~, ~) cb());
            place(c, w.nextRow(22), [1 2]);
        end

        function b = button(w, txt, cb, color, h)
            if nargin < 5, h = 30; end
            b = uibutton(w.cg, 'Text', txt, 'ButtonPushedFcn', @(~, ~) cb());
            if nargin >= 4 && ~isempty(color)
                b.BackgroundColor = color; b.FontColor = 'w'; b.FontWeight = 'bold'; b.FontSize = 15;
            end
            place(b, w.nextRow(h), [1 2]);
        end

        function setVerdict(w, text, kind)
            switch kind
                case 'good', col = w.C.green;
                case 'warn', col = w.C.amber;
                case 'bad',  col = w.C.red;
                otherwise,   col = w.C.navy;
            end
            w.badge.Text = text; w.badge.BackgroundColor = col;
        end

        function setSource(w, hw)
            if hw
                w.srcBadge.Text = 'HARDWARE  -  live data'; w.srcBadge.BackgroundColor = w.C.red;
            else
                w.srcBadge.Text = 'SIMULATION  -  model, not measured'; w.srcBadge.BackgroundColor = w.C.blue;
            end
        end
    end
end

function place(h, r, c)
    h.Layout.Row = r; h.Layout.Column = c;
end
