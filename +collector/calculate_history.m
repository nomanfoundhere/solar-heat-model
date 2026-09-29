function H = calculate_history(Y, time, absorbed, lost, g, C, t)
%CALCULATE_HISTORY  Output history of one run, built from the logged temperatures in one pass.
%
%   Uses the temperature states logged by Simulink. The whole-water mean is energy-weighted: heat stored in all
%   loop water divided by the whole-water heat capacity g.C(2).
%
%   Syntax
%     H = collector.calculate_history(Y, time, absorbed, lost, g, C, t)
%
%   Inputs
%     Y          k x g.n_states double, degC. One row of temperatures per output time.
%     time       k x 1 double, s, nondecreasing.
%     absorbed   k x 1 double, J. Light absorbed since t = 0 at each output time.
%     lost       k x 1 double, J. Heat lost to the room since t = 0.
%     g          1x1 struct from collector.prepare_model.
%     C          g.n_states x 1 double, J/K, > 0. Heat capacity of every state.
%     t          1x1 struct, c.test (reads initial_c, ambient_c).
%
%   Outputs
%     H   1x1 struct of k x 1 double columns: time_s (s); plate_c, water_c,
%         external_water_c, collector_water_mean_c, tube_wall_mean_c, eps_mean_c (NaN if
%         no EPS), underside_c, cover_inner_c, cover_outer_c, outlet_c (NaN at zero flow)
%         (degC); wall_energy_j, backing_energy_j, eps_energy_j, absorbed_j, lost_j,
%         stored_j, water_energy_j (J, relative to initial_c); plate_to_tube_w,
%         tube_solar_w, plate_to_water_w, plate_to_backing_w, back_loss_w, edge_loss_w,
%         top_loss_w, loop_loss_w, gap_w, cover_core_w, gap_radiation_w, top_radiation_w (W)
%
%   Errors
%     MATLAB:validators:*   an input of the wrong class, size or range.
arguments
    Y (:,:) double {mustBeReal, mustBeFinite}
    time (:,1) double {mustBeReal, mustBeFinite}
    absorbed (:,1) double {mustBeReal}
    lost (:,1) double {mustBeReal}
    g (1,1) struct
    C (:,1) double {mustBeReal, mustBeFinite, mustBePositive}
    t (1,1) struct
end
i = g.idx;  % Struct locating each physical heat store in the state matrix.
P = g.P;  % Struct of heat-flow parameters.
T0 = t.initial_c;  % degC, common initial temperature used as the energy reference.
k = size(Y, 1);  % Number of recorded times.
Cw = C(i.water);  % Double column [J/K], heat capacity of each tube-water cell.
Cwall = C(i.wall);  % Double column [J/K], heat capacity of each tube-wall cell.
Cb = C(i.backing);  % Double column [J/K], heat capacity of each backing layer.
eps = g.backing.is_eps;  % Logical column selecting the EPS layers within the backing.
Ta = Y(:, i.absorber);  % Double column [degC], absorber temperature through time.
Te = Y(:, i.external);  % Double column [degC], mixed vessel and hose-water temperature.
Tq = Y(:, i.water);  % Double matrix [degC], one tube-water cell per column.
Tw = Y(:, i.wall);  % Double matrix [degC], one tube-wall cell per column.
Tb = Y(:, i.backing);  % Double matrix [degC], one backing layer per column.
water_j = C(i.external)*(Te - T0) + (Tq - T0)*Cw;  % Double column [J], energy stored in all loop water above its initial state.
H.time_s = time;
H.plate_c = Ta;
% The whole-loop mean weights each water volume by its heat capacity.
H.water_c = T0 + water_j/g.C(2);
H.external_water_c = Te;
H.collector_water_mean_c = Tq*Cw/sum(Cw);
H.tube_wall_mean_c = Tw*Cwall/sum(Cwall);
H.wall_energy_j = (Tw - T0)*Cwall;
H.backing_energy_j = (Tb - T0)*Cb;
if any(eps)
    H.eps_energy_j = (Tb(:, eps) - T0)*Cb(eps);
    H.eps_mean_c = Tb(:, eps)*Cb(eps)/sum(Cb(eps));
else
    H.eps_energy_j = zeros(k, 1);
    H.eps_mean_c = nan(k, 1);
end
back = g.backing.G(end)*(Tb(:, end) - P.ambient_c);            % last layer -> underside air
H.underside_c = t.ambient_c + back/(g.underside_h*g.gross_m2);  % underside surface temperature
H.cover_inner_c = Y(:, i.cover_inner);
H.cover_outer_c = Y(:, i.cover_outer);
if g.mcp_w_k > 0
    H.outlet_c = Tq(:, end);
else
    H.outlet_c = nan(k, 1);
end
H.absorbed_j = absorbed;
H.lost_j = lost;
% Sum capacity times temperature rise across every heat store.
H.stored_j = (Y - T0)*C;
H.water_energy_j = water_j;
% Multiply each temperature difference by its conductance, then sum cells.
H.plate_to_tube_w = (Ta - Tw)*g.cells.ga;
H.tube_solar_w = repmat(P.q_tube, k, 1);
H.plate_to_water_w = (Tw - Tq)*g.cells.gf;
H.plate_to_backing_w = g.backing.G(1)*(Ta - Tb(:, 1));
H.back_loss_w = back;
H.edge_loss_w = P.edge_ua*(Ta - P.ambient_c);
[gap, core, top_c, top_a, ~, gap_rad, top_rad] = deal(zeros(k, 1));
for r = 1:k                                                     % scalar correlation (also used in Simulink)
    [gap(r), core(r), top_c(r), top_a(r), ~, gap_rad(r), top_rad(r)] = collector.surface_heat_flows(Ta(r), Y(r, i.cover_inner), Y(r, i.cover_outer), P);
end
H.top_loss_w = top_c + top_a;
H.loop_loss_w = P.loop_ua*(Te - P.ambient_c);
H.gap_w = gap;
H.cover_core_w = core;
H.gap_radiation_w = gap_rad;
H.top_radiation_w = top_rad;
end
