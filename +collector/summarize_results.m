function r = summarize_results(H, g, c, hit, Y)
%SUMMARIZE_RESULTS  Final temperatures, energy totals and performance measures of one run.
%
%   Syntax
%     r = collector.summarize_results(H, g, c, hit, Y)
%
%   Inputs
%     H     1x1 struct, the run history (collector.calculate_history).
%     g     1x1 struct from collector.prepare_model.
%     c     1x1 struct from collector_inputs.
%     hit   double scalar, s. First time the external water reaches c.test.target_c;
%           NaN if never.
%     Y     k x g.n_states double, degC. Every state at the history times (rows of H).
%
%   Outputs
%     r   1x1 struct:
%       .summary   1x1 struct of double scalars: final_water_c, final_external_water_c,
%                  final_plate_c, final_outlet_c, final_tube_wall_c (degC);
%                  time_to_target_s (s, NaN if not reached); water_energy_j, wall_energy_j,
%                  backing_energy_j, absorbed_j, lost_j, stored_j, energy_residual_j (J);
%                  water_efficiency_gross, water_efficiency_aperture (-); pipe_dp_pa,
%                  minor_dp_pa (Pa); tube_cells (count); tube_water_l, whole_water_l (L);
%                  total_length_m (m); kf_w_k, ua_w_k (W/K); aperture_m2, gross_m2 (m^2)
%       .history   H
%       .state_c   Y (every temperature state at the history times, order of g.idx)
%       .stages    g.stages
%       .prepared  g
%       .inputs    c
%
%   Errors
%     MATLAB:validators:*   an input of the wrong class or size.
arguments
    H (1,1) struct
    g (1,1) struct
    c (1,1) struct
    hit (1,1) double
    Y (:,:) double
end
t = c.test;
incident = t.irradiance*g.gross_m2*t.duration_s;  % J, lamp energy incident on the full plate footprint.
s.final_water_c = H.water_c(end);
s.final_external_water_c = H.external_water_c(end);
s.final_plate_c = H.plate_c(end);
s.final_outlet_c = H.outlet_c(end);
s.time_to_target_s = hit;
s.water_energy_j = H.water_energy_j(end);
s.wall_energy_j = H.wall_energy_j(end);
s.backing_energy_j = H.backing_energy_j(end);
s.final_tube_wall_c = H.tube_wall_mean_c(end);
s.absorbed_j = H.absorbed_j(end);
s.lost_j = H.lost_j(end);
s.stored_j = H.stored_j(end);
% Energy closure: absorbed light equals losses plus energy stored in all parts.
s.energy_residual_j = s.absorbed_j - s.lost_j - s.stored_j;
% Water-only efficiencies use the same stored energy but different illuminated areas.
s.water_efficiency_gross = s.water_energy_j/incident;
s.water_efficiency_aperture = s.water_energy_j/(t.irradiance*g.aperture_m2*t.duration_s);
s.pipe_dp_pa = sum([g.stages.pipe_dp_path_pa]);
s.minor_dp_pa = sum([g.stages.minor_dp_path_pa]);
s.tube_cells = numel(g.idx.water);
s.tube_water_l = g.tube_water_l;
s.whole_water_l = g.whole_water_l;
s.total_length_m = g.total_length_m;
s.kf_w_k = g.kf_w_k;
s.ua_w_k = g.ua_w_k;
s.aperture_m2 = g.aperture_m2;
s.gross_m2 = g.gross_m2;
r.summary = s;
r.history = H;
r.state_c = Y;
r.stages = g.stages;
r.prepared = g;
r.inputs = c;
end
