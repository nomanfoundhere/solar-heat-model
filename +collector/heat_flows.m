function f = heat_flows(y, g)
%HEAT_FLOWS  Every named heat flow for one full temperature vector.
%
%   Each heat flow follows from its temperature difference and conductance.
%   Losses are positive when heat leaves the collector or water loop.
%
%   Syntax
%     f = collector.heat_flows(y, g)
%
%   Inputs
%     y   g.n_states x 1 double, degC. Temperatures in the order of g.idx.
%     g   1x1 struct from collector.prepare_model.
%
%   Outputs
%     f   1x1 struct of double scalars, W unless stated; each positive in the direction
%         its name gives, losses positive when leaving the collector:
%           gap_w, gap_radiation_w, cover_core_w, top_loss_w, top_radiation_w,
%           edge_loss_w, loop_loss_w, back_loss_w (last backing layer -> underside air),
%           plate_to_backing_w, plate_to_tube_w (absorber -> all walls),
%           plate_to_water_w (all walls -> water), tube_solar_w, absorbed_w, lost_w;
%           rayleigh (dimensionless)
%
%   Errors
%     MATLAB:validators:*   y not a real finite column vector, or g not a 1x1 struct.
arguments
    y (:,1) double {mustBeReal, mustBeFinite}
    g (1,1) struct
end
P = g.P;
i = g.idx;
Ta = y(i.absorber);  % degC, absorber plate and attached lumped solids.
Te = y(i.external);  % degC, mixed vessel and hose water.
Tw = y(i.wall);  % Double column [degC], tube-wall temperatures in flow order.
Tq = y(i.water);  % Double column [degC], matching tube-water temperatures.
Tb = y(i.backing);  % Double column [degC], backing layers from plate to underside.
[f.gap_w, f.cover_core_w, q_top_cover, q_top_abs, f.rayleigh, f.gap_radiation_w, f.top_radiation_w] = collector.surface_heat_flows(Ta, y(i.cover_inner), y(i.cover_outer), P);
f.top_loss_w = q_top_cover + q_top_abs;
f.edge_loss_w = P.edge_ua*(Ta - P.ambient_c);
f.loop_loss_w = P.loop_ua*(Te - P.ambient_c);
f.back_loss_w = g.backing.G(end)*(Tb(end) - P.ambient_c);          % underside of the last backing layer
f.plate_to_backing_w = g.backing.G(1)*(Ta - Tb(1));
f.plate_to_tube_w = g.cells.ga'*(Ta - Tw);                        % absorber into the tube walls
f.plate_to_water_w = g.cells.gf'*(Tw - Tq);                       % walls into the water
f.tube_solar_w = P.q_tube;
f.absorbed_w = P.q_solar + P.q_cover;
f.lost_w = f.top_loss_w + f.edge_loss_w + f.loop_loss_w + f.back_loss_w;
end
