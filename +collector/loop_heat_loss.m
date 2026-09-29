function ua = loop_heat_loss(c)
%LOOP_HEAT_LOSS  Conductance from the mixed vessel/hose water to the room.
%
%   c is the scalar input struct from collector_inputs, checked by prepare_model.
%   ua is a double scalar in W/K. Loss power is ua*(water temperature - room).
%   Dimensions come from c.design, conductivities from c.properties and film
%   coefficients from c.heat. A zero vessel volume omits the vessel entirely.
%
%   Each hose loses heat through its inner water film, cylindrical wall and
%   outer air film in series. The vessel has an insulated cylindrical side
%   and two uninsulated end caps. Its inner water-film resistance and the
%   heat stored in vessel/hose solids are omitted in this lumped model.
%   All routes share one water temperature, so their conductances add.
arguments
    c (1,1) struct
end
d = c.design;
p = c.properties;
h = c.heat;
ua = 0;  % W/K, total conductance of the external water loop.

%% Hoses: resistance per metre, multiplied by each hose's length
for k = 1:size(d.external_hoses, 1)
    length_m = d.external_hoses(k, 1);  % m, length of this hose.
    inner_radius = d.external_hoses(k, 2)/2000;  % m, half the bore diameter.
    outer_radius = inner_radius + d.external_hose_wall_mm/1000;  % m.
    inner_film = 1/(2*pi*inner_radius*h.loop_inside_h);  % m K/W.
    wall = log(outer_radius/inner_radius)/(2*pi*p.hose_k);  % m K/W.
    outer_film = 1/(2*pi*outer_radius*h.loop_outside_h);  % m K/W.
    resistance_per_length = inner_film + wall + outer_film;  % m K/W.
    ua = ua + length_m/resistance_per_length;  % W/K; zero length contributes zero.
end

%% Vessel: water volume sets the length of the filled PVC cylinder
if d.vessel_l == 0
    return
end
outer_radius = d.vessel_outside_mm/2000;  % m, outer PVC radius.
inner_radius = outer_radius - d.vessel_wall_mm/1000;  % m, water radius.
foam_radius = outer_radius + d.vessel_insulation_mm/1000;  % m, outer foam radius.
water_area = pi*inner_radius^2;  % m^2, bore area.
water_length = d.vessel_l/1000/water_area;  % m, filled length from volume/area.

wall = log(outer_radius/inner_radius)/(2*pi*p.vessel_k*water_length);  % K/W.
foam = log(foam_radius/outer_radius)/(2*pi*p.vessel_insulation_k*water_length);  % K/W.
outer_film = 1/(h.loop_outside_h*2*pi*foam_radius*water_length);  % K/W.
side_resistance = wall + foam + outer_film;  % K/W, series path through the side.

cap_area = 2*pi*outer_radius^2;  % m^2, both circular end caps together.
cap_wall = d.vessel_cap_mm/1000/p.vessel_k;  % m^2 K/W, resistance per area.
cap_film = 1/h.loop_outside_h;  % m^2 K/W.
cap_resistance = (cap_wall + cap_film)/cap_area;  % K/W, both caps in parallel.
ua = ua + 1/side_resistance + 1/cap_resistance;
end
