function g = prepare_model(c)
%PREPARE_MODEL  Check the inputs and derive everything the leaf model needs, in SI units.
%
%   Syntax
%     g = collector.prepare_model(c)
%
%   Inputs
%     c   1x1 struct from collector_inputs (fields design, properties, heat, test, numerics;
%         see collector_inputs for every field's class, unit and range).
%
%   Outputs
%     g   1x1 struct:
%       .stages            ns x 1 struct, one per tier: name (char), outside_mm, wall_mm,
%                          bore_mm, length_mm (mm); parallel, serial, count (double counts);
%                          flow_lpm (L/min per pipe); water_ml (mL, whole tier); reynolds,
%                          nusselt (-); h_w_m2k (W/(m^2 K)); bond_k_w, wall_k_w, film_k_w
%                          (K/W per pipe); ua_each_w_k, ua_total_w_k, ga_total_w_k,
%                          gf_total_w_k (W/K); wall_c_each_j_k, wall_c_total_j_k (J/K);
%                          velocity_m_s (m/s); darcy_factor (-); pipe_dp_each_pa,
%                          pipe_dp_path_pa, minor_dp_path_pa (Pa)
%       .C                 1x4 double, J/K: absorber, WHOLE water, inner cover, outer cover
%       .C_external        double, J/K: vessel + hoses water (+ unlocated fitting water)
%       .absorber_items    1x1 struct of double J/K: plate, tape_foil, tape_adhesive, paint, fittings
%       .cells             1x1 struct, per tube-water cell in flow order (m x 1 double each):
%                          C_water, C_wall (J/K), ga, gf (W/K), footprint_share (-, sums to 1),
%                          length_m (m, cell length along ONE path), bond_share (-, share of the
%                          absorber-to-wall resistance that is the tape bond: the pipe's outer surface
%                          sits at Ta - bond_share*(Ta - Tw)); label (m x 1 cell of char, tier name)
%       .backing           1x1 struct: C (nb x 1, J/K per layer), G ((nb+1) x 1, W/K:
%                          plate->layer 1, layer k->k+1, last layer->air), material (nb x 1
%                          cell of char), is_eps (nb x 1 logical), depth_m (nb x 1, m, layer
%                          centre below the plate), steady_ua_w_k (W/K)
%       .idx               1x1 struct of state indices (double): absorber, external,
%                          cover_inner, cover_outer (scalars); water, wall, backing (column vectors)
%       .n_states          double, number of temperature states
%       .P                 1x1 struct of double scalars used by the stores and
%                          collector.surface_heat_flows (see there), plus q_solar, q_tube, q_cover (W),
%                          mcp (W/K), edge_ua, loop_ua (W/K), C_absorber, C_external,
%                          C_cover_inner, C_cover_outer (J/K), T0 (degC)
%       .aperture_m2, .gross_m2, .cover_m2                        m^2
%       .tube_water_l, .external_water_l, .whole_water_l          L
%       .total_length_m (m), .junctions (count), .mcp_w_k, .ua_w_k, .kf_w_k (W/K),
%       .shadow_fraction, .diffuse_view_factor, .optical_access (-), .underside_h (W/(m^2 K)),
%       .q_solar_w, .q_tube_w, .q_cover_w, .q_absorbed_w (W)
%
%   Errors
%     MATLAB:validators:*   c is not a 1x1 struct.
%     leaf:inputs           an input violates its range or the leaf topology (message names it).
%     leaf:prepare          the external water volume is not positive.
%     (errors from collector.water_heat_transfer and collector.tube_wall_heat_transfer propagate)
%
%   Topology: symmetric leaf with a mirrored return and equal flow in every branch; the
%   parallel pipes of a tier share one temperature, so they are lumped per tier.
arguments
    c (1,1) struct
end
validate(c);
d = c.design;  % Struct of collector dimensions and construction inputs.
p = c.properties;  % Struct of constant fluid and solid properties in SI units.
h = c.heat;  % Struct of contact, optical and heat-loss assumptions.
t = c.test;  % Struct of lamp, room, flow and test-duration inputs.
numerics = c.numerics;  % Struct of time-step, cell-count and convergence settings.
q = t.flow_lpm/60000;  % m^3/s, total loop flow; 1000 L/m^3 times 60 s/min.

%% Pipe tiers
stages = d.stages;  % Struct row, one entry per branching tier.
number_tiers = numel(stages);  % Number of branching tiers.
tier_results = repmat(struct(), number_tiers, 1);  % Struct column holding the calculated properties of each tier.
for i = 1:number_tiers
    s = stages(i);  % Dimensions and pipe counts for this tier.
    od = s.outside_mm/1000;  % m, outside diameter of one pipe.
    di = (s.outside_mm - 2*s.wall_mm)/1000;  % m, bore after subtracting both walls.
    L = s.length_mm/1000;  % m, length of one pipe in the tier.
    count = s.parallel*s.serial;  % Total pipes in this tier, including its return section.
    pipe_flow = q/s.parallel;  % m^3/s through one pipe; equal flow division is assumed.
    [water_h, reynolds, nusselt] = collector.water_heat_transfer(di, L, pipe_flow, c);  % Water film coefficient [W/(m^2 K)], Reynolds number and Nusselt number.
    w = collector.tube_wall_heat_transfer(od, di, L, d.tube_k, water_h, d.tube_density, d.tube_cp, h.bond_per_length, h.contact_fraction, h.circumference_fraction);
    % The heat path includes the bond, tube wall and water film. Pressure loss
    % uses the same bore and flow but follows one route, not all parallel pipes.
    bore_area = pi*di^2/4;  % m^2, cross-section of one water passage.
    v = pipe_flow/bore_area;  % m/s, flow divided by the bore area.
    friction = collector.pipe_friction_factor(reynolds);  % Dimensionless Darcy friction factor.
    dynamic_pressure = p.water_density*v^2/2;  % Pa, dynamic pressure in one pipe.
    pipe_drop = friction*L/di*dynamic_pressure;  % Pa, straight-pipe loss along one pipe, excluding fittings.
    r.name = s.name;
    r.outside_mm = s.outside_mm;
    r.wall_mm = s.wall_mm;
    r.bore_mm = di*1000;
    r.length_mm = s.length_mm;
    r.parallel = s.parallel;
    r.serial = s.serial;
    r.count = count;
    r.flow_lpm = t.flow_lpm/s.parallel;
    tier_length_m = count*L;  % m, all parallel and return pipes in this tier.
    water_volume_m3 = tier_length_m*pi*di^2/4;  % m^3, cylindrical water volume across the tier.
    r.water_ml = water_volume_m3*1e6;  % mL, the same inventory used for water heat capacity.
    r.reynolds = reynolds;
    r.nusselt = nusselt;
    r.h_w_m2k = water_h;
    r.bond_k_w = w.bond;
    r.wall_k_w = w.wall;
    r.film_k_w = w.film;
    r.ua_each_w_k = w.ua;
    r.ua_total_w_k = count*w.ua;
    r.ga_total_w_k = count*w.ga;
    r.gf_total_w_k = count*w.gf;
    r.wall_c_each_j_k = w.capacity;
    r.wall_c_total_j_k = count*w.capacity;
    r.velocity_m_s = v;
    r.darcy_factor = friction;
    r.pipe_dp_each_pa = pipe_drop;
    r.pipe_dp_path_pa = s.serial*pipe_drop;
    r.minor_dp_path_pa = s.serial*s.local_K*dynamic_pressure;
    fields = fieldnames(r);  % Cell column of field names copied into the tier results.
    for k = 1:numel(fields)
        tier_results(i).(fields{k}) = r.(fields{k});
    end
end
g.stages = tier_results;

%% Water inventory, areas and lumped capacities
tube_water_l = sum([tier_results.water_ml])/1000;  % L, water inside every collector pipe.
hose_lengths = d.external_hoses(:, 1);  % Double column [m], one length per hose.
hose_bores = d.external_hoses(:, 2)/1000;  % Double column [m], corresponding inside diameters.
hose_volumes = hose_lengths.*pi.*hose_bores.^2/4*1000;  % Double column [L], cylindrical water volumes.
hose_water_l = sum(hose_volumes);  % L, water in all external hoses.
g.tube_water_l = tube_water_l;
g.external_water_l = d.vessel_l + hose_water_l;
g.whole_water_l = d.vessel_l + hose_water_l + tube_water_l + d.fitting_water_ml/1000;
g.aperture_m2 = d.aperture_length_mm*d.aperture_width_mm/1e6;
g.gross_m2 = d.plate_length_mm*d.plate_width_mm/1e6;
g.cover_m2 = d.cover_length_mm*d.cover_width_mm/1e6;
g.total_length_m = sum([tier_results.count].*[tier_results.length_mm])/1000;
tape_area = g.total_length_m*d.tape_width_mm/1000;  % m^2, one full-width strip per tube length; overlaps are counted.
g.junctions = 2*(stages(end).parallel - 1);  % One binary branching tree on each side of the tips.
% Each solid stores mass*specific_heat [J/K], or volume*volumetric_heat_capacity.
% The plate, tape, equivalent finish and fittings share the absorber temperature.
g.absorber_items.plate = g.gross_m2*d.plate_thickness_mm/1000*p.aluminium_density*p.aluminium_cp;
g.absorber_items.tape_foil = tape_area*d.tape_foil_mm/1000*p.aluminium_density*p.aluminium_cp;
g.absorber_items.tape_adhesive = tape_area*d.tape_adhesive_mm/1000*d.adhesive_heat_capacity;
g.absorber_items.paint = g.gross_m2*d.paint_dry_film_mm/1000*d.paint_heat_capacity;
g.absorber_items.fittings = g.junctions*d.fitting_mass_g/1000*d.fitting_cp;
% Heat capacities [J/K]: absorber solids, all loop water, then the two cover faces.
g.C(1) = sum(cell2mat(struct2cell(g.absorber_items)));
g.C(2) = g.whole_water_l/1000*p.water_density*p.water_cp;
g.C(3) = g.cover_m2*h.cover_capacity_area/2;
g.C(4) = g.cover_m2*h.cover_capacity_area/2;
g.C_external = (g.external_water_l + d.fitting_water_ml/1000)/1000*p.water_density*p.water_cp;

%% Backing: EPS then support, each split into equal layers that store heat.
% Links join layer centres; the first starts at the plate (perfect contact), the last
% ends in the underside air. Conductances are over the whole plate area.
layer_thickness = [];  % Double row of backing-layer thicknesses [m], from plate to underside.
conductivity = [];  % Double row of thermal conductivities [W/(m K)], one per layer.
heat_capacity_per_volume = [];  % Double row of volumetric heat capacities [J/(m^3 K)].
materials = {};  % Cell row of layer material names, in the same order.
if d.insulation_mm > 0
    layer_thickness = [layer_thickness, repmat(d.insulation_mm/1000/numerics.backing_cells, 1, numerics.backing_cells)];
    conductivity = [conductivity, repmat(p.insulation_k, 1, numerics.backing_cells)];
    heat_capacity_per_volume = [heat_capacity_per_volume, repmat(p.insulation_density*p.insulation_cp, 1, numerics.backing_cells)];
    materials = [materials, repmat({'EPS'}, 1, numerics.backing_cells)];
end
if d.support_mm > 0
    layer_thickness = [layer_thickness, repmat(d.support_mm/1000/numerics.backing_cells, 1, numerics.backing_cells)];
    conductivity = [conductivity, repmat(p.support_k, 1, numerics.backing_cells)];
    heat_capacity_per_volume = [heat_capacity_per_volume, repmat(p.support_density*p.support_cp, 1, numerics.backing_cells)];
    materials = [materials, repmat({'support'}, 1, numerics.backing_cells)];
end
half_layer_resistance = layer_thickness./(2*conductivity*g.gross_m2);  % K/W, resistance between each layer centre and either face.
between_layers = half_layer_resistance(1:end-1) + half_layer_resistance(2:end);  % Double row [K/W], touching half-layers in series.
underside_film = 1/(h.underside_h*g.gross_m2);  % K/W, exterior convection and radiation combined.
layer_resistances = [half_layer_resistance(1), between_layers, half_layer_resistance(end) + underside_film];  % K/W, every link from plate to room.
g.underside_h = h.underside_h;
g.backing.C = (g.gross_m2*layer_thickness.*heat_capacity_per_volume)';
g.backing.G = (1./layer_resistances)';
g.backing.material = materials';
g.backing.depth_m = (cumsum(layer_thickness) - layer_thickness/2)';
g.backing.is_eps = strcmp(materials, 'EPS')';
g.backing.steady_ua_w_k = 1/sum(layer_resistances);

%% Per-cell tube network (supply tiers, then the mirrored return)
cells_per_segment = numerics.cells_per_segment;  % Water cells per supply or return segment.
order = [1:number_tiers, number_tiers-1:-1:1];  % Tier indices along the water path; the tips are traversed once.
water_cells = numel(order)*cells_per_segment;  % One water cell and wall cell at each position.
water_capacity = zeros(water_cells, 1);  % Double column of water heat capacities [J/K].
wall_capacity = zeros(water_cells, 1);  % Double column of tube-wall heat capacities [J/K].
plate_to_wall = zeros(water_cells, 1);  % Double column of plate-to-wall conductances [W/K].
wall_to_water = zeros(water_cells, 1);  % Double column of wall-to-water conductances [W/K].
projected_area = zeros(water_cells, 1);  % Double column of projected pipe areas [mm^2], before normalising.
tier_labels = cell(water_cells, 1);  % Cell column of tier names, one per water cell.
cell_lengths = zeros(water_cells, 1);  % Double column of cell lengths along one pipe [m].
bond_share = zeros(water_cells, 1);  % Double column of bond shares in the plate-to-wall resistance.
for segment = 1:numel(order)
    j = order(segment);  % Tier visited by this supply or return segment.
    r = tier_results(j);
    % Tier totals include every parallel pipe and both traversals. Dividing
    % by the total cell count gives one cell's share without duplicating mass.
    tier_cells = r.serial*cells_per_segment;
    first = (segment - 1)*cells_per_segment + 1;  % Index of this segment's first cell.
    last = segment*cells_per_segment;  % Index of its last cell.
    water_capacity(first:last) = r.water_ml/1e6/tier_cells*p.water_density*p.water_cp;
    wall_capacity(first:last) = r.wall_c_total_j_k/tier_cells;
    plate_to_wall(first:last) = r.ga_total_w_k/tier_cells;
    wall_to_water(first:last) = r.gf_total_w_k/tier_cells;
    projected_area(first:last) = r.count*r.length_mm*r.outside_mm/tier_cells;
    tier_labels(first:last) = {r.name};
    cell_lengths(first:last) = r.length_mm/1000/cells_per_segment;
    bond_share(first:last) = r.bond_k_w/(r.bond_k_w + r.wall_k_w/2);
end
g.cells.C_water = water_capacity;
g.cells.C_wall = wall_capacity;
g.cells.ga = plate_to_wall;
g.cells.gf = wall_to_water;
g.cells.footprint_share = projected_area/sum(projected_area);
g.cells.label = tier_labels;
g.cells.length_m = cell_lengths;
g.cells.bond_share = bond_share;
backing_cells = numel(g.backing.C);  % Number of backing temperature states.
g.idx.absorber = 1;
g.idx.external = 2;
g.idx.cover_inner = 3;
g.idx.cover_outer = 4;
g.idx.water = (5:4+water_cells)';
g.idx.wall = (5+water_cells:4+2*water_cells)';
g.idx.backing = (5+2*water_cells:4+2*water_cells+backing_cells)';
g.n_states = 4 + 2*water_cells + backing_cells;
if g.C_external <= 0
    error('leaf:prepare', 'The external mixed-water volume must be positive');
end

%% Flow, optics and light
% Flow carries heat at mass flow times specific heat [W/K].
g.mcp_w_k = q*p.water_density*p.water_cp;
g.ua_w_k = sum([tier_results.ua_total_w_k]);
if g.mcp_w_k > 0
    g.kf_w_k = g.mcp_w_k*(1 - exp(-g.ua_w_k/g.mcp_w_k));
else
    g.kf_w_k = 0;
end
% Projected pipe area divides absorbed light between plate and tube walls.
% It is the sum of diameter*length, neglecting overlap between pipe shadows.
pipe_projection = sum([tier_results.count].*[tier_results.length_mm].*[tier_results.outside_mm])/1e6;  % m^2.
g.shadow_fraction = min(pipe_projection/g.aperture_m2, 1);
aperture_length = d.aperture_length_mm/1000;  % m, opening inside the rim.
aperture_width = d.aperture_width_mm/1000;  % m.
gap = d.gap_mm/1000;  % m, plate-to-cover distance.
g.diffuse_view_factor = collector.cover_view_factor(aperture_length, aperture_width, gap);
if h.rim_shading
    beam_fraction = 1 - t.diffuse_fraction;  % Normal-incidence beam is assumed to clear the rim.
    diffuse_access = t.diffuse_fraction*g.diffuse_view_factor;
    g.optical_access = beam_fraction + diffuse_access;  % Fraction of incident light clearing the rim.
else
    g.optical_access = 1;
end
if h.cover
    through = h.cover_transmittance*g.optical_access;  % Fraction passing both cover and rim.
else
    through = 1;  % Removing the cover also bypasses its rim-screening correction.
end
reaching = g.aperture_m2*t.irradiance*h.absorptance*through;  % W absorbed across the aperture before pipe-shadow corrections.
g.q_solar_w = reaching*(1 - g.shadow_fraction*(1 - h.capture_recovery));  % W, plate and tube-wall absorption together.
g.q_tube_w = reaching*g.shadow_fraction*h.capture_recovery*h.footprint_to_wall;  % W, the part of q_solar deposited in tube walls.
% The absorber receives q_solar - q_tube, so tube light is counted only once.
g.q_cover_w = h.cover*g.cover_m2*t.irradiance*h.cover_absorptance;  % W, absorption over the whole illuminated lid.
g.q_absorbed_w = g.q_solar_w + g.q_cover_w;

%% Parameters passed to the Simulink heat stores
% Each field is a numeric scalar. This fixed layout is also used by the
% compiled MATLAB Function block for convection and radiation.
g.P.aperture_m2 = g.aperture_m2;
g.P.gross_m2 = g.gross_m2;
g.P.cover_m2 = g.cover_m2;
g.P.gap_m = d.gap_mm/1000;
g.P.air_k = p.air_k;
g.P.air_nu = p.air_nu;
g.P.air_diffusivity = p.air_diffusivity;
g.P.air_film_k = p.air_film_temperature_k;
g.P.gravity = p.gravity;
g.P.sigma = p.sigma;
g.P.emissivity = h.emissivity;
g.P.cover_emissivity = h.cover_emissivity;
g.P.external_h = h.external_h;
g.P.cover_resistance = h.cover_resistance;
g.P.ambient_c = t.ambient_c;
g.P.radiant_c = t.radiant_c;
g.P.cover = double(h.cover);
g.P.edge_ua = h.edge_ua;
if isempty(h.loop_ua)
    g.P.loop_ua = collector.loop_heat_loss(c);  % W/K, recalculated from the current vessel and hoses.
else
    g.P.loop_ua = h.loop_ua;  % W/K, explicit override for a different external rig.
end
g.P.mcp = g.mcp_w_k;
g.P.q_solar = g.q_solar_w;
g.P.q_tube = g.q_tube_w;
g.P.q_cover = g.q_cover_w;
g.P.C_absorber = g.C(1);
g.P.C_external = g.C_external;
g.P.C_cover_inner = g.C(3);
g.P.C_cover_outer = g.C(4);
g.P.T0 = t.initial_c;
end


function validate(c)
% validate(c): c 1x1 struct from collector_inputs. Raises leaf:inputs naming the first violated range or topology rule; no output.
d = c.design;  % Struct of collector dimensions and construction inputs.
p = c.properties;  % Struct of constant fluid and solid properties in SI units.
h = c.heat;  % Struct of contact, optical and heat-loss assumptions.
t = c.test;  % Struct of lamp, room, flow and test-duration inputs.
numerics = c.numerics;  % Struct of time-step, cell-count and convergence settings.
pos = {d.tube_k;
       d.aperture_length_mm;
       d.aperture_width_mm;
       d.plate_length_mm;
       d.plate_width_mm;
       d.plate_thickness_mm;
       d.cover_length_mm;
       d.cover_width_mm;
       d.gap_mm;
       d.insulation_mm;
       d.tube_density;
       d.tube_cp;
       h.cover_resistance;
       h.cover_capacity_area;
       h.emissivity;
       h.cover_emissivity;
       h.laminar_nusselt;
       h.underside_h;
       numerics.step_s;
       numerics.record_s;
       numerics.convergence_tolerance_k};
if any(cellfun(@(v) ~(isfinite(v) && v > 0), pos))
    error('leaf:inputs', 'A dimension, property or step that must be positive is not');
end
if any(structfun(@(v) ~(isfinite(v) && v > 0), p))
    error('leaf:inputs', 'Every material property must be positive');
end
nonneg = {d.vessel_l;
       d.fitting_water_ml;
       d.support_mm;
       d.tape_width_mm;
       d.tape_foil_mm;
       d.tape_adhesive_mm;
       d.adhesive_heat_capacity;
       d.paint_dry_film_mm;
       d.paint_heat_capacity;
       d.fitting_mass_g;
       d.fitting_cp;
       h.bond_per_length;
       h.external_h;
       h.edge_ua;
       t.flow_lpm;
       t.duration_s;
       t.irradiance};
if any(cellfun(@(v) ~(isfinite(v) && v >= 0), nonneg))
    error('leaf:inputs', 'A quantity that cannot be negative is negative');
end
if isempty(h.loop_ua)
    % These dimensions are needed only for the cylindrical course-loop model.
    loop_positive = [d.external_hose_wall_mm, d.vessel_outside_mm, d.vessel_wall_mm, d.vessel_cap_mm, h.loop_inside_h, h.loop_outside_h];
    if any(~isfinite(loop_positive) | loop_positive <= 0)
        error('leaf:inputs', 'External-loop walls, diameters and film coefficients must be positive');
    end
    if ~isfinite(d.vessel_insulation_mm) || d.vessel_insulation_mm < 0 || d.vessel_outside_mm <= 2*d.vessel_wall_mm
        error('leaf:inputs', 'Vessel needs a positive bore and nonnegative insulation thickness');
    end
elseif ~isscalar(h.loop_ua) || ~isfinite(h.loop_ua) || h.loop_ua < 0
    error('leaf:inputs', 'loop_ua must be empty or a finite nonnegative conductance in W/K');
end
fr = [h.contact_fraction, h.circumference_fraction, h.absorptance, h.emissivity, h.cover_transmittance, h.cover_absorptance, h.cover_emissivity, h.capture_recovery, h.footprint_to_wall, t.diffuse_fraction];
if any(fr < 0 | fr > 1)
    error('leaf:inputs', 'A fraction lies outside [0, 1]');
end
if h.cover_transmittance + h.cover_absorptance > 1
    error('leaf:inputs', 'Cover transmission plus absorption exceeds one');
end
if ~any(strcmp(h.internal_model, {'fully_developed', 'developing'}))
    error('leaf:inputs', 'Unknown internal_model');
end
if t.initial_c < 0 || t.initial_c >= 100
    error('leaf:inputs', 'Initial water must be liquid');
end
if d.aperture_length_mm > min(d.plate_length_mm, d.cover_length_mm) || d.aperture_width_mm > min(d.plate_width_mm, d.cover_width_mm)
    error('leaf:inputs', 'Aperture must fit inside both plate and cover');
end
if numerics.cells_per_segment < 1 || numerics.backing_cells < 1 || mod(numerics.cells_per_segment, 1) || mod(numerics.backing_cells, 1)
    error('leaf:inputs', 'Cell counts must be positive integers');
end
stages = d.stages;  % Struct row, one entry per branching tier.
prev = 1;
for i = 1:numel(stages)
    s = stages(i);  % Dimensions and pipe counts for this tier.
    if s.wall_mm <= 0 || s.outside_mm <= 2*s.wall_mm || s.length_mm <= 0
        error('leaf:inputs', '%s: positive bore, wall and length required', s.name);
    end
    if s.parallel < 1 || mod(s.parallel, prev)
        error('leaf:inputs', '%s: parallel count must be an integer multiple of the previous tier', s.name);
    end
    if s.serial ~= 1 + (i < numel(stages))
        error('leaf:inputs', 'Each non-final tier needs supply and return; the final tier one traversal');
    end
    if s.local_K < 0
        error('leaf:inputs', 'local_K cannot be negative');
    end
    prev = s.parallel;
end
if any(d.external_hoses(:,1) < 0) || any(d.external_hoses(:,2) <= 0)
    error('leaf:inputs', 'External hoses need nonnegative length and positive bore');
end
end
