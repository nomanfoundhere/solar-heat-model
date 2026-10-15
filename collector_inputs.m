function c = collector_inputs()
%COLLECTOR_INPUTS  Every input of the leaf collector model, in one place.
%
%   Edit values here only; every other file reads them from the returned struct.
%   Each value carries its unit and source in the comment beside it:
%     USER      Aeva's decisions (dated)       COURSE     Project Manual / course setup
%     LEGACY    carried over from SSA 3 scripts (an estimate, not a measured property)
%     ESTIMATE  assumed model value            DATASHEET  product datasheet
%   Material-property and geometry values retain their recorded source tags.
%
%   Syntax
%     c = collector_inputs()
%
%   Inputs
%     None.
%
%   Outputs
%     c   1x1 struct with six groups. Every field is a double scalar in the unit given
%         beside it unless listed here:
%       .design       geometry and materials
%           stages          1 x ns struct array, one element per tier of the leaf, in flow
%                           order from the inlet: name (char); outside_mm, wall_mm,
%                           length_mm (mm, per pipe); parallel (pipes side by side, integer,
%                           each tier a multiple of the previous); serial (2 = supply and
%                           mirrored return, 1 for the final tier); local_K (-, >= 0)
%           tube_material   char, label only
%           external_hoses  n x 2 double: [length m, bore mm] per hose outside the collector
%       .properties   constant material and fluid properties, SI, all > 0
%       .heat         contact, optical and loss assumptions
%           internal_model  char, 'fully_developed' or 'developing'
%           rim_shading     logical; cover  logical (false = no cover, as the Intex mat)
%           loop_ua         [] to derive vessel/hose losses each run, or a scalar override (W/K)
%           fractions (contact_fraction ... footprint_to_wall) lie in [0, 1]
%       .test         imposed test conditions (irradiance W/m2, flow L/min, degC, s)
%       .numerics     solver settings: cells_per_segment, backing_cells positive integers
%       .limits       guardrail limits (collector.check_model_limits): course_max_plate_mm 1x2 (mm),
%                     pump_flow_range_lpm 1x2 (L/min), water_property_range_c 1x2 (degC), others scalar
%     Ranges are enforced by collector.prepare_model (error leaf:inputs).

%% Design: geometry and materials
% One row per tier of the leaf tree (symmetric, mirrored return):
%   name, outside diameter mm, wall mm, length of ONE pipe mm, parallel pipes, serial traversals, local loss K
% USER 27 Sep: Gardena Micro-Drip 13 mm tube (the 23 Sep 10 mm tube is unavailable locally).
% USER 11 Oct: 13 mm is the BORE, so outside diameter = 13 + 2 x 1 = 15 mm. Wall 1 mm ASSUMED, checked
% 14 Oct against the product weight: 2200 g / 50 m = 44 g/m at 920 kg/m3 gives 47.8 mm2 of wall,
% so OD = sqrt(13^2 + 4*47.8/pi) = 15.2 mm and wall = 1.1 mm (less if the weight includes packaging).
% Lengths and counts from the leaf design.
% USER 15 Oct (build photos 10 Oct): no 60 mm trunk pieces were fitted; the hoses go straight onto
% the two root tees, so the leaf starts at the first branches.
names = {'First branches', 'Second branches', 'Tips'}; % Cell row of tier names.
% Each row contains [outside diameter mm, wall mm, pipe length mm,
% parallel pipes, supply/return traversals, local loss coefficient].
tiers = [15 1 140 2 2 0;
         15 1 90 4 2 0;
         15 1 220 8 1 0];
for k = 1:numel(names)
    d.stages(k).name = names{k};
    d.stages(k).outside_mm = tiers(k, 1);
    d.stages(k).wall_mm = tiers(k, 2);
    d.stages(k).length_mm = tiers(k, 3);
    d.stages(k).parallel = tiers(k, 4);
    d.stages(k).serial = tiers(k, 5);
    d.stages(k).local_K = tiers(k, 6); % Fitting and bend losses are omitted, not assumed physically zero.
end
d.tube_material = 'LDPE (assumed)';
d.tube_k = 0.33;                 % W/(m K), LEGACY estimate; replace with selected tube data
d.tube_density = 920;            % kg/m3, Goodfellow LDPE; proxy, tube product not certified
d.tube_cp = 2090;                % J/(kg K), measured LDPE at 25 C (PMC9269369 Table 2)
% Itemised absorber-node solids (see Model explanations/Pipe wall thermal storage.md)
% Finish: the course plate's own black paint; the tubes lie bare on it.
d.paint_dry_film_mm = 0.04;      % mm, ESTIMATE paint layer over the plate (not measured)
d.paint_heat_capacity = 2.1e6;   % J/(m3 K), ESTIMATE polymer paint
d.fitting_mass_g = 4;            % g per tee, ASSUMED
d.fitting_cp = 1900;             % J/(kg K), LEGACY polyolefin proxy; printed tees use PLA
% Aperture means the clear opening inside the rim, entered separately from
% the whole lid. The current 24 mm rails give 714-2*24 by 664-2*24 mm.
d.aperture_length_mm = 666;      % mm, clear opening in the current enclosure
d.aperture_width_mm = 616;       % mm, clear opening in the current enclosure
d.plate_length_mm = 720;         % COURSE maximum footprint, adopted as plate dimensions
d.plate_width_mm = 670;
d.plate_thickness_mm = 2;        % mm, COURSE aluminium plate
d.cover_length_mm = 714;         % mm, DECIDED lid dimensions; whole lid illuminated
d.cover_width_mm = 664;
d.gap_mm = 28;                   % DECIDED 27 Sep (SSA 6): 2 seal + 18 wall + 2 seal + 4 rim + 2 seal; horizontal hot lower surface assumed
d.insulation_mm = 20;            % LEGACY EPS thickness; one GAMMA 20 mm sheet
d.support_mm = 6;                % COURSE: 6 mm Trespa cart plate, open air below (0 = none)
d.vessel_l = 2;                  % COURSE vessel water
d.external_hoses = [2.0 8.5; 1.0 12.5];  % [length m, BORE mm]; COURSE lengths, second bore assumed
d.external_hose_wall_mm = 1.75;  % mm, COURSE 12/8.5 mm hose; same wall assumed for the wider hose
d.vessel_outside_mm = 110;       % mm, COURSE PVC vessel tube
d.vessel_wall_mm = 3.2;          % mm, ESTIMATE PVC wall
d.vessel_insulation_mm = 20;     % mm, COURSE PE foam around the vessel side
d.vessel_cap_mm = 3;             % mm, ESTIMATE uninsulated PVC end caps
d.fitting_water_ml = 0;          % unknown cavity water omitted
c.design = d;

%% Properties: constant, SI
p.water_density = 1000;          % kg/m3 (1 L = 1 kg)
p.water_cp = 4180;               % J/(kg K), LEGACY
p.water_mu = 7.98e-4;            % Pa s, water near 30 C
p.water_k = 0.615;               % W/(m K), same near-30 C basis
p.hose_k = 0.13;                 % W/(m K), COURSE polyurethane hose
p.vessel_k = 0.17;               % W/(m K), ESTIMATE PVC vessel and end caps
p.vessel_insulation_k = 0.038;   % W/(m K), ESTIMATE PE foam around the vessel
p.aluminium_density = 2700;      % kg/m3, LEGACY
p.aluminium_cp = 900;            % J/(kg K), LEGACY
p.insulation_k = 0.038;          % W/(m K); GAMMA B269729 Rd 0.53 m2K/W at 20 mm; rated +70 C
p.insulation_density = 15;       % kg/m3, GAMMA B269729: 1.8 kg per 12 sheets of 1 x 0.5 x 0.02 m
p.insulation_cp = 1450;          % J/(kg K), EN ISO 10456
p.support_k = 0.3;               % W/(m K), Trespa HPL datasheet
p.support_density = 1350;        % kg/m3, Trespa datasheet minimum
p.support_cp = 1400;             % J/(kg K), ESTIMATE for phenolic compact laminate
p.air_k = 0.0278;                % W/(m K), LEGACY fixed film-temperature estimate
p.air_nu = 1.76e-5;              % m2/s, kinematic viscosity at the film temperature
p.air_diffusivity = 2.50e-5;     % m2/s
p.air_film_temperature_k = 320;  % K; expansion coefficient = 1/this
p.gravity = 9.81;                % m/s2
p.sigma = 5.670374419e-8;        % W/(m2 K4)
c.properties = p;

%% Heat transfer: tube contact, absorbed light and losses
h.bond_per_length = [];          % W/(m K); [] derives it from the line contact of the bare tube on
                                 % the plate; a number overrides it (Intex: welded channels)
h.contact_gap_mm = 0.05;         % mm, ESTIMATE smallest air gap between the round tube and the flat
                                 % plate (surface waviness); used when bond_per_length is []
h.contact_fraction = 1;          % fraction of each tube length coupled to the absorber
h.circumference_fraction = 1;    % radial wall path; spreading around the wall is in the derived bond
h.internal_model = 'developing';  % Hausen mean Nu: every pipe (0.06-0.22 m) is far shorter than its
                                 % thermal entry length (0.9-7.2 m); each tee restarts the profile
h.laminar_nusselt = 4.36;        % constant heat-flux limit, used only with 'fully_developed'
h.absorptance = 0.94;            % -, LEGACY estimate for the plate's black paint (USER 24 Sep: keep)
h.emissivity = 0.90;             % LEGACY estimate, black paint
% Gutta 4.5 mm clear twinwall: 82 % light transmission (Hornbach product data, solar proxy);
% US6635342B1 Table 1: 4 % absorption.
h.cover_transmittance = 0.82;
h.cover_absorptance = 0.04;      % split equally between the two cover nodes
h.cover_emissivity = 0.90;
h.cover_resistance = 0.08;       % m2 K/W, twinwall core (air channel conduction + radiation)
h.cover_capacity_area = 1200;    % J/(m2 K), whole two-node cover
h.capture_recovery = 1;          % fraction of tube-footprint light absorbed
h.footprint_to_wall = 1;         % the bare black tube shades its footprint, so all of that light lands
                                 % on the tube wall (absorptance taken equal to the black paint)
h.rim_shading = true;            % aperture view factor applied to diffuse light only
h.cover = true;                  % false: no cover, absorber loses to the room directly (uncovered Intex)
h.external_h = 8;                % W/(m2 K), convection over the outer lid, LEGACY
h.edge_ua = 0.25;                % W/K, lumped edge conduction
h.loop_ua = [];                 % [] derives vessel + hose conductance from geometry each run; a number overrides it (W/K)
h.loop_inside_h = 3000;         % W/(m2 K), ESTIMATE water film inside external hoses
h.loop_outside_h = 13;          % W/(m2 K), ESTIMATE external convection + radiation around vessel and hoses
h.underside_h = 6.5;             % W/(m2 K), Trespa underside to cart air, ESTIMATE
h.underside_h_radiation = 5.5;   % W/(m2 K), radiative part of underside_h (rest ~1 = downward convection), ESTIMATE
c.heat = h;

%% Test conditions (imposed)
t.irradiance = 1000;             % W/m2, COURSE
t.diffuse_fraction = 0.80;       % COURSE
t.flow_lpm = 1;                  % L/min total
t.initial_c = 20;                % C, all states initially equal
t.ambient_c = 20;                % C
t.radiant_c = 20;                % C, effective longwave surroundings (USER 24 Sep: keep 20)
t.duration_s = 1800;             % s, COURSE 30-minute run
t.target_c = 40;                 % C, group target (Meeting 3, 10 Sep)
c.test = t;

%% Numerics
n.step_s = 0.25;                 % s, reference (backward-Euler) solver step
n.cells_per_segment = 32;        % equal-volume water cells per pipe segment
n.nonlinear_tolerance_k = 1e-10; % convergence of the nonlinear-loss iteration
n.record_s = 10;                 % s, output interval
n.backing_cells = 16;            % layers per backing material (EPS, Trespa)
n.convergence_tolerance_k = 0.01;% K, allowed change on halving the step or doubling the cells
c.numerics = n;

%% Guardrail limits: the model is only trustworthy while these hold (collector.check_model_limits)
L.energy_residual_max = 1e-6;          % -, of the absorbed energy
L.course_max_plate_mm = [720 670];     % mm, COURSE largest collector footprint
L.pump_flow_range_lpm = [1.0 5.5];     % L/min, COURSE manual p. 10, pump settings
L.pump_max_pa = 3.1e5;                 % Pa, COURSE manual p. 10, pump maximum (3.1 bar)
L.pipe_drop_share_max = 0.10;          % -, straight-pipe drop as a share of the pump maximum; tees and
                                       %   bends are not modelled, so the rest is kept free for them
L.eps_max_c = 70;                      % C, DATASHEET GAMMA B269729 EPS service limit
L.pipe_max_c = 60;                     % C, ESTIMATE: LDPE continuous use is quoted 60-80 C; lower end
                                       %   until the chosen tube's datasheet is known
L.water_property_range_c = [15 60];    % C, ESTIMATE: water properties fixed at 30 C; over this range
                                       %   the conductivity changes by under 5 %
L.gap_rayleigh_max = 1e5;              % -, HANDBOOK upper end of the Hollands gap correlation
L.gap_film_band_k = 20;                % K, ESTIMATE allowed distance of the real gap air from
                                       %   air_film_temperature_k (air properties then within ~6 %)
L.underside_rise_max_k = 20;           % K, ESTIMATE underside above room; beyond this the linear
                                       %   radiation coefficient is off by ~10 %
c.limits = L;
end
