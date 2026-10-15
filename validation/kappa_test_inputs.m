function c = kappa_test_inputs(data, optics)
%KAPPA_TEST_INPUTS  The Blue Bay Kappa Curve test of 14 Oct 2024 (course reference system 2)
%   written as inputs of the collector model. Starts from collector_inputs() and changes only
%   inputs, like intex_test_inputs. Nothing is fitted to the measurement.
%
%   Sources: MEASURED groupX.txt; DATASHEET 'Solar heater kappa curve.pdf' (73.5 x 52 cm, 7 L,
%   PVC, 10 L black non-insulated bucket, casing closed with the glass cover); COURSE project
%   manual (design space 720 x 670 x 365 mm, 6 mm Trespa floor, hoses); PHOTO the two photographs
%   in the datasheet (ten tubes, clear window, light birch-plywood casing walls, white floor);
%   SOURCED glass: AGC Planibel Clearlite, energy transmittance 0.85-0.88 for 6-3 mm;
%   birch light reflectance 0.56-0.71 (Gustafs LRV table); white surface 0.85.
%   ASSUMED (no source): Kappa dome transmittance 0.85, range 0.80-0.90.
%
%   Syntax
%     c = kappa_test_inputs(data, optics)
%
%   Inputs
%     data    1x1 struct with time_s, vessel_c, flow_lpm (column double) from groupX.txt.
%     optics  char: 'central', 'low', 'high' (ends of the sourced ranges), 'black' (black casing
%             walls and floor: the old lower bound) or 'none' (no casing: the old upper bound).
%
%   Outputs
%     c   1x1 struct in the collector_inputs format.
arguments
    data (1,1) struct
    optics {mustBeMember(optics, {'central', 'low', 'high', 'black', 'none'})} = 'central'
end
c = collector_inputs();
d = c.design; p = c.properties; h = c.heat; t = c.test;

%% Collector: ten black PVC tubes between an inlet and an outlet header (PHOTO, DATASHEET)
tubes = 10; tube_mm = 620; header_mm = 230; wall = 2;       % PHOTO; header = half the window width (ASSUMED)
path_m = (2*header_mm + tubes*tube_mm)/1000;
bore = 1000*sqrt(7.0/1000*4/(pi*path_m));                   % DATASHEET 7 L in headers and tubes
d.stages = struct('name', {'Header', 'Tubes'}, 'outside_mm', {bore + 2*wall, bore + 2*wall}, ...
    'wall_mm', {wall, wall}, 'length_mm', {header_mm, tube_mm}, 'parallel', {1, tubes}, ...
    'serial', {2, 1}, 'local_K', {0, 0});
d.tube_material = 'PVC';
d.tube_k = 0.17; d.tube_density = 1400; d.tube_cp = 1000;  % rigid PVC, as the Intex mat
d.paint_dry_film_mm = 0; d.fitting_mass_g = 0;               % moulded black PVC: no paint, no tees
d.plate_length_mm = 735; d.plate_width_mm = 520;             % DATASHEET footprint lying flat
d.plate_thickness_mm = 2;                                    % ASSUMED black PVC tray = absorber store
p.aluminium_density = 1400; p.aluminium_cp = 1000;           % the absorber store is PVC
d.aperture_length_mm = 655; d.aperture_width_mm = 465;       % PHOTO clear window
d.cover_length_mm = 735; d.cover_width_mm = 520;
d.gap_mm = 50;                                               % ASSUMED tubes to the curved dome
d.insulation_mm = 10;                                        % ASSUMED still air under the tray
p.insulation_k = p.air_k; p.insulation_density = 1.1; p.insulation_cp = 1007;
d.support_mm = 6;                                            % COURSE Trespa floor

%% Loop: 10 L poured into the bucket; the collector and hoses fill from it (as the 2 L rule)
d.loop_water_l = 10;                                         % DATASHEET
d.vessel_outside_mm = 265; d.vessel_wall_mm = 2;             % ASSUMED bucket, PE wall
d.vessel_insulation_mm = 0; d.vessel_cap_mm = 2;             % DATASHEET non-insulated
p.vessel_k = 0.33;

%% Covers: the Kappa's dome (inner) under the casing glass (outer)
[glass, dome, walls] = optical(optics);
h.cover_transmittance = glass*dome;
h.cover_absorptance = 0.08 + glass*0.04;                     % glass, then the dome, of what passes
h.cover_resistance = 0.17;                                   % dome to glass across the casing air
h.cover_capacity_area = 8400 + 2900;                         % 4 mm glass + 2 mm dome
h.footprint_to_wall = 0;                                     % light is absorbed on the black tube surface
h.bond_per_length = 1e4;                                     % surface and wall are one PVC part
h.circumference_fraction = 0.5;                              % heat enters through the lit upper half
h.rim_shading = false;
if ~strcmp(optics, 'none')
    % COURSE design space 720 x 670 x 365 mm: glass 365 mm above the floor, tubes about 65 mm up
    d.casing = struct('opening_mm', [720 670], 'depth_mm', 300, 'footprint_mm', [735 520], ...
        'wall_reflectance', walls, 'floor_reflectance', walls_floor(optics), 'frame_reflectance', 0.05);
end

%% Test: measured flow, start and duration; room = start (ASSUMED)
t.flow_lpm = mean(data.flow_lpm);
t.initial_c = mean(data.vessel_c(data.time_s <= 10));
t.ambient_c = t.initial_c; t.radiant_c = t.initial_c;
t.duration_s = data.time_s(end);
c.design = d; c.properties = p; c.heat = h; c.test = t;
c.numerics.record_s = 10;
end


function [glass, dome, walls] = optical(optics)
% Glass: AGC Planibel Clearlite 0.87 at 4 mm (0.85-0.88 for 6-3 mm). Dome: ASSUMED 0.85 (0.80-0.90).
% Walls: birch plywood light reflectance, central of 0.56-0.71.
switch optics
    case 'central', glass = 0.87; dome = 0.85; walls = 0.635;
    case 'low',     glass = 0.85; dome = 0.80; walls = 0.56;
    case 'high',    glass = 0.88; dome = 0.90; walls = 0.71;
    case 'black',   glass = 0.87; dome = 0.85; walls = 0;
    case 'none',    glass = 0.87; dome = 0.85; walls = 0;
end
end

function r = walls_floor(optics)
% White Trespa floor beside the collector: 0.80 (white surfaces ~0.85); black case: 0.
if strcmp(optics, 'black'), r = 0; else, r = 0.80; end
end
