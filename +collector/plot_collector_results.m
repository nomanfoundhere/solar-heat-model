function plot_collector_results(r, out, pdf)
%PLOT_COLLECTOR_RESULTS  Temperature, energy, efficiency and flow figures for one run.
%
%   temperatures   temperatures of each part and the water target crossing
%   energy         absorbed light, stored energy and heat losses by route
%   efficiency     instantaneous and cumulative heat gain relative to incident light
%   inside         temperatures along the pipes and through the backing
%   pipe_tiers     water volume, conductance and pressure drop in each tier
%   pump_range     pressure drop and Reynolds number across the pump flow range
%   Power bands are interval averages over the output interval (trapezoid of the logged flows).
%
%   Syntax
%     collector.plot_collector_results(r, out)
%     collector.plot_collector_results(r, out, pdf)
%
%   Inputs
%     r     1x1 struct returned by simulate_collector (needs .state_c).
%     out   char or string scalar. Existing folder to write into.
%     pdf   logical, optional (default false). Also write each figure as a vector PDF.
%
%   Outputs
%     None.
%
%   Errors
%     MATLAB:validators:*   wrong class; out not an existing folder.
%
%   Side effects
%     Writes the six figures as .png (180 dpi), and .pdf (vector) when pdf is true, into out, overwriting files
%     of the same name. Figures are created invisibly with the light theme and closed.
arguments
    r (1,1) struct
    out {mustBeTextScalar, mustBeFolder}
    pdf (1,1) logical = false
end
D = derive(r);
D.pdf = pdf;
fig_temperatures(D, out);
fig_energy(D, out);
fig_efficiency(D, out);
fig_inside(D, out);
fig_pipe_tiers(D, out);
fig_pump_range(D, out);
end


%% Shared quantities
function D = derive(r)
% D = derive(r): 1x1 struct of the series the figures need (times s, powers W, energies J).
D.r = r;
c = r.inputs;
g = r.prepared;
H = r.history;
h = c.heat;
t = c.test;
D.c = c;
D.g = g;
D.H = H;
D.Y = r.state_c;  % Double matrix [degC], output times by temperature states.
D.t = H.time_s;  % Double column [s], output times.
D.tm = D.t/60;  % Double column [min], times used on the plot axes.
D.light_on_cover_w = t.irradiance*g.cover_m2;
D.footprint_w = t.irradiance*g.gross_m2;
D.never_w = D.light_on_cover_w - g.q_absorbed_w;   % reflected by cover and paint, passed beside, blocked by rim
water = H.water_energy_j;  % Double column [J], energy gained by all loop water.
kept = H.stored_j - water;  % Double column [J], energy stored in solid parts and covers.
dt = diff(D.t);  % Double column [s], width of each output interval.
mid = @(x) (x(1:end-1) + x(2:end))/2;  % Function handle averaging adjacent samples of a column.
D.rad_share = h.underside_h_radiation/h.underside_h;  % Dimensionless radiation share of the underside loss coefficient.
top_conv = H.top_loss_w - H.top_radiation_w;
D.bands.water = diff(water)./dt;
D.bands.kept = diff(kept)./dt;
D.bands.conduction = mid(H.edge_loss_w);
D.bands.convection = mid(top_conv + H.loop_loss_w + H.back_loss_w*(1 - D.rad_share));
D.bands.radiation = mid(H.top_radiation_w + H.back_loss_w*D.rad_share);
D.bands.never = repmat(D.never_w, numel(dt), 1);
D.t_mid = mid(D.t);
J = @(p) trapz(D.t, p);  % Function handle integrating a power column [W] to energy [J].
D.loss_route_j.cover_convection = J(top_conv);
D.loss_route_j.cover_radiation = J(H.top_radiation_w);
D.loss_route_j.vessel_and_hoses = J(H.loop_loss_w);
D.loss_route_j.edges = J(H.edge_loss_w);
D.loss_route_j.underside = J(H.back_loss_w);
D.col.water = [0.29 0.22 0.64];
D.col.kept = [0.91 0.49 0.64];
D.col.cond = [0.16 0.47 0.84];
D.col.conv = [0.11 0.69 0.47];
D.col.rad = [0.89 0.29 0.29];
D.col.light = [0.93 0.62 0.06];
D.col.ink2 = [0.32 0.32 0.31];
D.col.series = [0.16 0.47 0.84; 0.91 0.40 0.21; 0.11 0.69 0.47; 0.93 0.62 0.06; 0.91 0.49 0.64; 0.0 0.5 0.0; 0.89 0.29 0.29];
end


%% Figures
function fig_temperatures(D, out)
% D is the scalar plot-data struct from derive; out is the output folder path.
% Writes this figure as PNG and, when D.pdf is true, PDF. No returned value.
% fig_temperatures(D, out): every part's temperature over the test, labelled at the end.
H = D.H;
c = D.c;
col = D.col;
f = light_figure([1100 520]);
ax = axes(f);
hold(ax, 'on');
series = {'plate_c', 'Absorber plate';
    'tube_wall_mean_c', 'Pipe walls (mean)';
    'outlet_c', 'Collector outlet';
    'external_water_c', 'Vessel + hoses water';
    'cover_inner_c', 'Cover, inner face';
    'eps_mean_c', 'EPS (mean)';
    'cover_outer_c', 'Cover, outer face'};
ends = zeros(size(series, 1) + 1, 1);  % Double column [degC], final value of each labelled curve.
labels = cell(size(ends));  % Cell column of the printed end labels.
colors = zeros(numel(ends), 3);  % Double RGB matrix, one colour per end label.
for k = 1:size(series, 1)
    y = H.(series{k, 1});
    plot(ax, D.tm, y, 'Color', col.series(k, :), 'LineWidth', 1.6, 'DisplayName', series{k, 2});
    ends(k) = y(end);
    labels{k} = sprintf('%.1f °C', y(end));
    colors(k, :) = col.series(k, :);
end
plot(ax, D.tm, H.water_c, 'Color', col.water, 'LineWidth', 3, 'DisplayName', 'All water (mean)');
ends(end) = H.water_c(end);
labels{end} = sprintf('%.1f °C (all water)', H.water_c(end));
colors(end, :) = col.water;
yline(ax, c.test.target_c, ':', sprintf('%g °C target', c.test.target_c), 'Color', col.ink2, 'HandleVisibility', 'off');
k = find(H.water_c >= c.test.target_c, 1);
if ~isempty(k) && k > 1
    tx = interp1(H.water_c(k-1:k), D.tm(k-1:k), c.test.target_c);
    plot(ax, tx, c.test.target_c, 'o', 'MarkerFaceColor', col.water, 'MarkerEdgeColor', 'w', 'MarkerSize', 7, 'HandleVisibility', 'off');
    text(ax, tx, c.test.target_c - 1.5, sprintf('all water at %g °C: %.1f min', c.test.target_c, tx), 'FontSize', 8.5);
end
xlim(ax, [0 D.tm(end)]);
style(ax, 'Temperatures of every part', 'Time (min)', 'Temperature (°C)', 'northwest');
ax.Position(3) = ax.Position(3)*0.9;              % room on the right for the end labels
end_labels(ax, ends, labels, colors, D.tm(end));
collector.save_result_figure(f, out, 'temperatures', 180, D.pdf);
end

function fig_energy(D, out)
% D is the scalar plot-data struct from derive; out is the output folder path.
% Writes this figure as PNG and, when D.pdf is true, PDF. No returned value.
% fig_energy(D, out): light budget over time, energy split over the test, losses by route.
col = D.col;
b = D.bands;
s = D.r.summary;
lt = D.loss_route_j;
f = light_figure([1550 520]);
% Explicit positions (normalized): the light budget keeps a gutter on its right for its
% end labels, which a tiled layout cannot reserve.
ax = axes(f, 'Position', [0.045 0.13 0.225 0.77]);
hold(ax, 'on');
names = {'water', 'Heats the water', col.water;
    'kept', 'Warms collector parts', col.kept;
    'conduction', 'Conduction loss', col.cond;
    'convection', 'Convection loss', col.conv;
    'radiation', 'Radiation loss', col.rad;
    'never', 'Never absorbed', col.light};
% One column per energy route, with power averaged over each output interval.
Yb = zeros(numel(D.t_mid), size(names, 1));
for k = 1:size(names, 1)
    Yb(:, k) = b.(names{k, 1});
end
a = area(ax, D.t_mid/60, Yb, 'EdgeColor', 'w', 'LineWidth', 0.8);
for k = 1:numel(a)
    a(k).FaceColor = names{k, 3};
    a(k).DisplayName = names{k, 2};
end
xlim(ax, [0 D.tm(end)]);
ylim(ax, [0 D.light_on_cover_w*1.05]);
style(ax, sprintf('Where the %.0f W of lamp light on the cover goes', D.light_on_cover_w), 'Time (min)', 'Power (W)', 'none');
total = D.light_on_cover_w*D.c.test.duration_s;
last = Yb(end, :);
centre = cumsum(last) - last/2;
txt = arrayfun(@(k) sprintf('%s\n%.0f kJ · %.0f %%', names{k, 2}, sum(Yb(:, k).*diff(D.t))/1000, 100*sum(Yb(:, k).*diff(D.t))/total), 1:size(names, 1), 'UniformOutput', false);
end_labels(ax, centre', txt, vertcat(names{:, 3})*0.6, D.tm(end));
% Energy split over the whole test; the loss bar is split by mechanism
ax = axes(f, 'Position', [0.45 0.13 0.2 0.77]);
hold(ax, 'on');
total = D.light_on_cover_w*D.c.test.duration_s;
conv = lt.cover_convection + lt.vessel_and_hoses + lt.underside*(1 - D.rad_share);
rad = lt.cover_radiation + lt.underside*D.rad_share;
rows = {D.never_w*D.c.test.duration_s, col.light; s.water_energy_j, col.water; s.stored_j - s.water_energy_j, col.kept};
for k = 1:3
    hbar(ax, k, {rows{k, 1}, rows{k, 2}}, total, 'of the cover light');
end
hbar(ax, 4, {lt.edges, col.cond; conv, col.conv; rad, col.rad}, total, 'of the cover light');
ax.YTick = 1:4;
ax.YTickLabel = {'Never absorbed', 'Into the water', 'Kept by parts', 'Lost to the room'};
ax.YDir = 'reverse';
ylim(ax, [0.4 4.75]);
xlim(ax, [0 max([rows{:, 1}, lt.edges + conv + rad])/1000*1.75]);
text(ax, 0, 4.48, sprintf('conduction %.0f · convection %.0f · radiation %.0f kJ', lt.edges/1000, conv/1000, rad/1000), 'FontSize', 7.8, 'Color', col.ink2, 'VerticalAlignment', 'top');
style(ax, sprintf('Energy split, %.0f kJ on the cover', total/1000), 'Energy over the test (kJ)', '', 'none');
% Losses by route, each split by mechanism
ax = axes(f, 'Position', [0.765 0.2 0.2 0.7]);
hold(ax, 'on');
lost = sum(cell2mat(struct2cell(lt)));
routes = {'Cover top', {lt.cover_convection, col.conv;
    lt.cover_radiation, col.rad};
    'Vessel + hoses', {lt.vessel_and_hoses, col.conv};
    'Box edges', {lt.edges, col.cond};
    'Cart underside', {lt.underside*(1 - D.rad_share), col.conv;
    lt.underside*D.rad_share, col.rad}};
for k = 1:4
    hbar(ax, k, routes{k, 2}, lost, 'of losses');
end
ax.YTick = 1:4;
ax.YTickLabel = routes(:, 1);
ax.YDir = 'reverse';
ylim(ax, [0.4 4.6]);
xlim(ax, [0 (lt.cover_convection + lt.cover_radiation)/1000*1.9]);
mech_legend(ax, col);
style(ax, sprintf('Heat losses by route (%.0f kJ)', lost/1000), 'Heat lost over the test (kJ)', '', 'none');
legend(ax, 'Location', 'southoutside', 'Orientation', 'horizontal', 'Box', 'off', 'FontSize', 8.5);
collector.save_result_figure(f, out, 'energy', 180, D.pdf);
end

function fig_efficiency(D, out)
% D is the scalar plot-data struct from derive; out is the output folder path.
% Writes this figure as PNG and, when D.pdf is true, PDF. No returned value.
% fig_efficiency(D, out): efficiency over time and the warm-up efficiency curve.
col = D.col;
H = D.H;
lamp_w = D.footprint_w;
f = light_figure([1200 480]);
t = tiledlayout(f, 1, 2, 'TileSpacing', 'compact');
ax = nexttile(t);
hold(ax, 'on');
collector_efficiency = 100*H.plate_to_water_w/lamp_w;  % Percent, instantaneous wall-to-water power / lamp power on the footprint.
net = 100*D.bands.water/lamp_w;  % Percent, rate of energy gained by all water / lamp power on the footprint.
running = 100*cumsum(D.bands.water.*diff(D.t))./(lamp_w*D.t(2:end));  % Percent, accumulated water-energy gain / accumulated incident energy.
plot(ax, D.tm, collector_efficiency, 'Color', col.series(1, :), 'LineWidth', 1.8, 'DisplayName', 'Collector: heat into the pipe water');
plot(ax, D.t_mid/60, net, 'Color', col.series(2, :), 'LineWidth', 1.8, 'DisplayName', 'Water gain (after vessel loss)');
plot(ax, D.t(2:end)/60, running, 'Color', col.series(3, :), 'LineWidth', 1.8, 'DisplayName', 'Running average of water gain');
text(ax, D.tm(end), running(end), sprintf('%.1f %% at %g min', running(end), D.tm(end)), 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', 'FontSize', 8.5, 'Color', col.series(3, :));
xlim(ax, [0 D.tm(end)]);
ylim(ax, [0 max([collector_efficiency; net])*1.15]);
style(ax, 'Efficiency over time', 'Time (min)', 'Efficiency (% of light on the footprint)', 'southeast');
ax = nexttile(t);
hold(ax, 'on');
x = (H.water_c - D.c.test.ambient_c)/D.c.test.irradiance;
y = collector_efficiency;
plot(ax, x, y, 'o', 'MarkerSize', 3.5, 'MarkerFaceColor', col.series(1, :), 'MarkerEdgeColor', 'w', 'DisplayName', sprintf('every %g s of the test', D.c.numerics.record_s));
late = D.t >= D.t(end)/2;  % Logical column selecting the second half of the warm-up.
p = polyfit(x(late), y(late), 1);  % Double row: slope and intercept of the warm-up efficiency fit.
xs = [0 max(x)];
plot(ax, xs, polyval(p, xs), '--', 'Color', col.ink2, 'LineWidth', 1.2, 'DisplayName', 'straight fit, second half');
text(ax, 0.3, 0.3, sprintf(['fit: η = %.2f − %.1f W/(m² K) × (T_water − T_room) / G\n' '(the slope is the heat loss per kelvin the water sees)'], p(2)/100, -p(1)/100), 'Units', 'normalized', 'FontSize', 8, 'Color', col.ink2, 'Interpreter', 'none');
ylim(ax, [0 max(y)*1.1]);
style(ax, 'Efficiency curve (warm-up test, not steady state)', '(water mean − room) / irradiance (K m²/W)', 'Collector efficiency (%)', 'northeast');
ax.XLabel.Interpreter = 'none';
collector.save_result_figure(f, out, 'efficiency', 180, D.pdf);
end

function fig_inside(D, out)
% D is the scalar plot-data struct from derive; out is the output folder path.
% Writes this figure as PNG and, when D.pdf is true, PDF. No returned value.
% fig_inside(D, out): temperatures along the water path at the end, and through the backing over time.
col = D.col;
g = D.g;
Y = D.Y;
i = g.idx;
c = D.c;
f = light_figure([1200 480]);
t = tiledlayout(f, 1, 2, 'TileSpacing', 'compact');
ax = nexttile(t);
hold(ax, 'on');
last = Y(end, :);  % Double row [degC], all temperatures at the end of the run.
x = 1000*(cumsum(g.cells.length_m) - g.cells.length_m/2);  % Double column [mm], cell centres along one water path.
plot(ax, x, last(i.water), 'Color', col.water, 'LineWidth', 1.8, 'DisplayName', 'water');
plot(ax, x, last(i.wall), 'Color', col.series(2, :), 'LineWidth', 1.8, 'DisplayName', 'pipe wall');
yline(ax, last(i.absorber), 'Color', col.series(1, :), 'LineWidth', 1.8, 'DisplayName', 'plate (one temperature)');
yline(ax, last(i.external), ':', 'Color', col.ink2, 'DisplayName', 'vessel (feeds the trunk)');
lab = g.cells.label;  % Cell column of tier names, following the water path.
bounds = [1; find(~strcmp(lab(2:end), lab(1:end-1))) + 1; numel(lab) + 1];  % Indices where tier labels change, plus the final boundary.
xe = [0; cumsum(g.cells.length_m)]*1000;
top = max([last(i.absorber); last(i.wall)']) + 1.5;
for k = 1:numel(bounds) - 1
    if k > 1
        xline(ax, xe(bounds(k)), 'Color', [0.85 0.85 0.85], 'HandleVisibility', 'off');
    end
    nm = strsplit(lab{bounds(k)});
    text(ax, mean(xe(bounds(k:k+1))), top, nm{1}, 'HorizontalAlignment', 'center', 'FontSize', 7.5, 'Color', col.ink2);
end
xlim(ax, [0 xe(end)]);
ylim(ax, [min(last(i.water)) - 3, top + 1.5]);
style(ax, sprintf('Along the pipes at %g min', D.tm(end)), 'Distance along the water path (mm)', 'Temperature (°C)', 'east');
ax = nexttile(t);
hold(ax, 'on');
depth = [0; g.backing.depth_m]*1000;  % Double column [mm], plate surface and backing-layer centres.
eps_mm = c.design.insulation_mm;
tre = c.design.support_mm;
patch(ax, [0 200 200 0], [0 0 eps_mm eps_mm], [0.94 0.94 0.93], 'EdgeColor', 'none', 'HandleVisibility', 'off');
ramp = [0.55 0.72 0.92; 0.30 0.52 0.85; 0.15 0.33 0.65; 0.05 0.15 0.40];
fr = [1/6 1/3 2/3 1];  % Fractions of the run selected for the through-backing profiles.
for k = 1:4
    j = round(fr(k)*(size(Y, 1) - 1)) + 1;
    plot(ax, [Y(j, i.absorber) Y(j, i.backing)], depth, 'Color', ramp(k, :), 'LineWidth', 1.8, 'DisplayName', sprintf('%.0f min', D.t(j)/60));
end
xr = c.limits.eps_max_c - 1;                       % labels on the right, clear of the curves
text(ax, xr, 0.08*eps_mm, 'EPS', 'Color', col.ink2, 'FontSize', 8.5, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top');
text(ax, xr, eps_mm + tre/2, 'Trespa', 'Color', col.ink2, 'FontSize', 8.5, 'HorizontalAlignment', 'right');
xline(ax, c.limits.eps_max_c, '--', sprintf('EPS limit %g °C', c.limits.eps_max_c), 'Color', col.rad, 'HandleVisibility', 'off');
ax.YDir = 'reverse';
ylim(ax, [0 eps_mm + tre]);
xlim(ax, [c.test.ambient_c - 1, max(c.limits.eps_max_c, max(Y(:, i.absorber))) + 4]);
style(ax, 'Through the backing', 'Temperature (°C)', 'Depth below the plate (mm)', 'east');
collector.save_result_figure(f, out, 'inside', 180, D.pdf);
end

function fig_pipe_tiers(D, out)
% D is the scalar plot-data struct from derive; out is the output folder path.
% Writes this figure as PNG and, when D.pdf is true, PDF. No returned value.
% fig_pipe_tiers(D, out): water volume, conductance and pressure drop of each tier at the design flow.
col = D.col;
S = D.g.stages;
f = light_figure([1350 450]);
t = tiledlayout(f, 1, 3, 'TileSpacing', 'compact');
lab = arrayfun(@(s) sprintf('%s (%g/%g mm)', s.name, s.outside_mm, s.bore_mm), S, 'UniformOutput', false);
spec = {'water_ml', 'Water in each tier', 'mL', col.water, '%.1f';
    'ua_total_w_k', 'Plate-to-water conductance', 'W/K', col.series(3, :), '%.2f';
    'pipe_dp_path_pa', sprintf('Pressure drop along one path at %g L/min', D.c.test.flow_lpm), 'Pa', col.series(1, :), '%.1f'};
for k = 1:3
    ax = nexttile(t);
    hold(ax, 'on');
    v = [S.(spec{k, 1})];
    barh(ax, v, 0.55, 'FaceColor', spec{k, 4}, 'EdgeColor', 'none');
    for j = 1:numel(S)
        txt = sprintf(spec{k, 5}, v(j));
        if k == 3
            re = S(j).reynolds;
            reg = 'laminar';
            if re >= 3000
                reg = 'turbulent';
            elseif re > 2300
                reg = 'transition';
            end
            txt = sprintf('%s · Re %.0f (%s)', txt, re, reg);
        end
        text(ax, v(j), j, ['  ' txt], 'FontSize', 8.3);
    end
    ax.YTick = 1:numel(S);
    ax.YTickLabel = lab;
    ax.YDir = 'reverse';
    xlim(ax, [0 max(v)*(1.5 + (k == 3))]);
    if k > 1
        ax.YTickLabel = {};
    end
    style(ax, spec{k, 2}, spec{k, 3}, '', 'none');
end
title(t, 'One stage table sets the water volume, heat transfer and pressure drop of each tier');
collector.save_result_figure(f, out, 'pipe_tiers', 180, D.pdf);
end

function fig_pump_range(D, out)
% D is the scalar plot-data struct from derive; out is the output folder path.
% Writes this figure as PNG and, when D.pdf is true, PDF. No returned value.
% fig_pump_range(D, out): straight-pipe pressure drop and Reynolds number across the pump range.
col = D.col;
c = D.c;
L = c.limits;
f = light_figure([1200 450]);
t = tiledlayout(f, 1, 2, 'TileSpacing', 'compact');
flows = linspace(L.pump_flow_range_lpm(1), L.pump_flow_range_lpm(2), 46);
dp = zeros(size(flows));  % Double row [Pa], straight-pipe loss at each pump flow.
re = zeros(numel(flows), numel(c.design.stages));  % Dimensionless matrix, one row per flow and one column per tier.
for k = 1:numel(flows)                                   % hydraulics only: no heat simulation
    cc = c;
    cc.test.flow_lpm = flows(k);
    gk = collector.prepare_model(cc);
    dp(k) = sum([gk.stages.pipe_dp_path_pa]);
    re(k, :) = [gk.stages.reynolds];
end
ax = nexttile(t);
hold(ax, 'on');
plot(ax, flows, dp, 'Color', col.series(1, :), 'LineWidth', 1.8, 'DisplayName', 'straight pipes, whole leaf');
plot(ax, c.test.flow_lpm, D.r.summary.pipe_dp_pa, 'o', 'MarkerSize', 8, 'MarkerFaceColor', col.series(1, :), 'MarkerEdgeColor', 'w', 'DisplayName', sprintf('design: %.1f Pa', D.r.summary.pipe_dp_pa));
text(ax, 0.03, 0.92, sprintf('pump maximum %g bar = %.0f Pa (far above this scale);\ntees and bends not included', L.pump_max_pa/1e5, L.pump_max_pa), 'Units', 'normalized', 'FontSize', 8, 'Color', col.ink2, 'VerticalAlignment', 'top');
xlim(ax, L.pump_flow_range_lpm);
ylim(ax, [0 max(dp)*1.1]);
style(ax, 'Pressure drop across the pump range', 'Pump flow (L/min)', 'Pressure drop (Pa)', 'southeast');
ax = nexttile(t);
hold(ax, 'on');
patch(ax, [flows(1) flows(end) flows(end) flows(1)], [2300 2300 3000 3000], [0.94 0.94 0.93], 'EdgeColor', 'none', 'HandleVisibility', 'off');
text(ax, flows(end) - 0.05, 2650, 'transition 2300-3000', 'FontSize', 8, 'Color', col.ink2, 'HorizontalAlignment', 'right');
for j = 1:size(re, 2)
    plot(ax, flows, re(:, j), 'Color', col.series(j, :), 'LineWidth', 1.8, 'DisplayName', c.design.stages(j).name);
end
xline(ax, c.test.flow_lpm, ':', 'Color', col.ink2, 'HandleVisibility', 'off');
xlim(ax, L.pump_flow_range_lpm);
ylim(ax, [0 max(re(:))*1.08]);
style(ax, 'Flow regime of each tier', 'Pump flow (L/min)', 'Reynolds number', 'northwest');
collector.save_result_figure(f, out, 'pump_range', 180, D.pdf);
end


%% Helpers
function hbar(ax, y, segments, total, of)
% hbar(ax, y, segments, total, of): one horizontal bar at row y made of segments (n x 2 cell:
% energy J, 1x3 RGB), labelled with its sum in kJ and as a percentage of total (J) "of" text.
left = 0;
for k = 1:size(segments, 1)
    w = segments{k, 1}/1000;
    rectangle(ax, 'Position', [left y - 0.275 max(w, eps) 0.55], 'FaceColor', segments{k, 2}, 'EdgeColor', 'w');
    left = left + w;
end
text(ax, left, y, sprintf('  %.0f kJ · %.0f %% %s', left, 100*left*1000/total, of), 'FontSize', 8.3);
end

function end_labels(ax, y, txt, colors, x)
% end_labels(ax, y, txt, colors, x): y n x 1 double (data units) where each label belongs; txt 1 x n
% cell of char, used as is (line breaks as newline characters); colors n x 3 RGB; x double, the
% right end of the data.
% Labels go just right of x, pushed apart so none overlap: the minimum spacing is the label's own
% text height (font size x lines x 1.25) converted to data units with the axes' real height, so it
% scales with the axes height and font size. A dense set of labels can still
% exceed the available vertical space.
units = ax.Units;
ax.Units = 'points';
h_pt = ax.Position(4);
ax.Units = units;
per_pt = diff(ylim(ax))/h_pt;  % Vertical data units per typographic point.
fs = 8;
lines = cellfun(@(s) 1 + numel(strfind(s, newline)), txt(:));
need = fs*1.25*lines*per_pt;                        % height of each label in data units
[ys, o] = sort(y(:));  % Sorted label heights and their original indices.
need = need(o);
pos = ys;
for k = 2:numel(pos)                                % push up from the bottom
    pos(k) = max(pos(k), pos(k-1) + (need(k-1) + need(k))/2);
end
over = pos(end) + need(end)/2 - max(ylim(ax));      % then shift down if the top ran past the axis
if over > 0
    pos = pos - over;
end
for k = 1:numel(pos)                                % and keep the bottom inside
    if k == 1
        pos(k) = max(pos(k), min(ylim(ax)) + need(k)/2);
    else
        pos(k) = max(pos(k), pos(k-1) + (need(k-1) + need(k))/2);
    end
end
dx = 0.015*diff(xlim(ax));
for k = 1:numel(pos)
    text(ax, x + dx, pos(k), txt{o(k)}, 'Color', colors(o(k), :), 'FontSize', fs, 'VerticalAlignment', 'middle', 'Clipping', 'off');
end
end

function mech_legend(ax, col)
% mech_legend(ax, col): invisible markers so the legend explains the mechanism colours.
plot(ax, nan, nan, 's', 'MarkerFaceColor', col.cond, 'MarkerEdgeColor', 'none', 'DisplayName', 'conduction');
plot(ax, nan, nan, 's', 'MarkerFaceColor', col.conv, 'MarkerEdgeColor', 'none', 'DisplayName', 'convection');
plot(ax, nan, nan, 's', 'MarkerFaceColor', col.rad, 'MarkerEdgeColor', 'none', 'DisplayName', 'radiation');
end

function f = light_figure(sz)
% f = light_figure(sz): sz 1x2 double (px) -> f 1x1 Figure, invisible, light theme whatever the desktop theme.
f = figure('Visible', 'off', 'Position', [0 0 sz]);
theme(f, 'light');
f.Color = 'w';
end

function style(ax, ttl, xl, yl, legend_where)
% style(ax, ttl, xl, yl, legend_where): ax 1x1 Axes; ttl, xl, yl char; legend_where char
% (a legend Location, or 'none'). Labels, left-aligned title, light grid.
xlabel(ax, xl);
ylabel(ax, yl);
title(ax, ttl);
ax.TitleHorizontalAlignment = 'left';
grid(ax, 'on');
ax.GridAlpha = 0.15;
box(ax, 'off');
ax.FontSize = 9;
if ~strcmp(legend_where, 'none')
    legend(ax, 'Location', legend_where, 'Box', 'off', 'FontSize', 8.5);
end
end
