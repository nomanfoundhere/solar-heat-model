function c = line_contact_conductance(od, di, k_tube, film, k_air, gap, h_rad)
%LINE_CONTACT_CONDUCTANCE  Plate-to-water conductance per metre of a bare round tube on a flat plate.
%
%   A bare tube touches the plate along a line. The plate heats the outside of the tube wall
%   in two ways, both strongest near the bottom of the tube:
%     air      conduction across the air gap below the tube. At angle phi from the bottom the
%              gap is gap + r(1 - cos phi); along vertical paths this gives, per unit wall area,
%              k_air*cos(phi)/(gap + r(1 - cos phi)) for phi < 90 deg
%     radiation from the black plate, h_rad*(1 + cos phi)/2 (view factor of a wall element to
%              the plane below)
%   The wall (conductance k_tube*t along the circumference) spreads this heat around the tube
%   and passes it through half the wall and the water film, h_e = 1/(1/film + t/(2 k_tube)).
%   The wall temperature around the circumference follows from
%     k_tube*t*T'' = h_e*(T - T_water) - g(phi)*(T_plate - T),   T' = 0 at the bottom and top,
%   solved by finite differences. The heat into the water per kelvin of plate-to-water
%   difference is the conductance. Convection from the gap air and exchange with the lid
%   are left out.
%
%   Syntax
%     c = collector.line_contact_conductance(od, di, k_tube, film, k_air, gap, h_rad)
%
%   Inputs
%     od, di   double scalars, m, od > di > 0. Outside diameter and bore.
%     k_tube   double scalar, W/(m K), > 0. Wall conductivity.
%     film     double scalar, W/(m^2 K), > 0. Water-side film coefficient.
%     k_air    double scalar, W/(m K), > 0. Air conductivity in the gap.
%     gap      double scalar, m, > 0. Smallest air gap between tube and plate.
%     h_rad    double scalar, W/(m^2 K), >= 0. Linear radiation coefficient plate to tube.
%
%   Outputs
%     c   1x1 struct of double scalars, all W/(m K) per metre of tube:
%       .total    plate to water
%       .air      plate to water without radiation (h_rad = 0)
%       .bond     the bond that gives .total when the radial wall and film resistances
%                 of collector.tube_wall_heat_transfer are added in series
%
%   Errors
%     MATLAB:validators:*   an input outside the stated class/size/range.
%     leaf:line_contact     od <= di, or the radial wall and film alone already exceed 1/total.
arguments
    od (1,1) double {mustBeReal, mustBeFinite, mustBePositive}
    di (1,1) double {mustBeReal, mustBeFinite, mustBePositive}
    k_tube (1,1) double {mustBeReal, mustBeFinite, mustBePositive}
    film (1,1) double {mustBeReal, mustBeFinite, mustBePositive}
    k_air (1,1) double {mustBeReal, mustBeFinite, mustBePositive}
    gap (1,1) double {mustBeReal, mustBeFinite, mustBePositive}
    h_rad (1,1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
end
if od <= di
    error('leaf:line_contact', 'Outside diameter %.4g m must exceed the bore %.4g m', od, di);
end
r = od/2;  % m, outer radius.
t = (od - di)/2;  % m, wall thickness.
h_e = 1/(1/film + t/(2*k_tube));  % W/(m^2 K), half wall plus water film.
c.total = ring(r, t, k_tube, h_e, k_air, gap, h_rad);
c.air = ring(r, t, k_tube, h_e, k_air, gap, 0);
% The tube-wall model adds a radial wall and a film resistance around the whole circumference;
% the bond carries the rest, so the three in series give .total.
radial = log(od/di)/(2*pi*k_tube) + 1/(pi*di*film);  % m K/W, per metre of tube.
if radial >= 1/c.total
    error('leaf:line_contact', 'Radial wall and film resistance exceed the line-contact resistance');
end
c.bond = 1/(1/c.total - radial);
end


function G = ring(r, t, k, h_e, k_air, gap, h_rad)
% G = ring(...): W/(m K) into the water per kelvin of plate-to-water difference, from the
% half circumference (bottom to top) doubled. 200 intervals change G by less than 1e-4.
n = 201;
phi = linspace(0, pi, n)';  % rad, from the contact line to the top of the tube.
ds = r*(phi(2) - phi(1));  % m, arc length per step.
g = h_rad*(1 + cos(phi))/2;  % W/(m^2 K), radiation from the plate.
lower = phi < pi/2;
g(lower) = g(lower) + k_air*cos(phi(lower))./(gap + r*(1 - cos(phi(lower))));
% k t T'' - (g + h_e) T = -g, with plate 1 and water 0; mirrored ends give zero slope.
A = diag(-(g + h_e)*ds^2/(k*t) - 2) + diag(ones(n-1, 1), 1) + diag(ones(n-1, 1), -1);
A(1, 2) = 2;
A(n, n-1) = 2;
T = A\(-g*ds^2/(k*t));
w = ds*ones(n, 1);
w([1 n]) = ds/2;  % trapezoid weights
G = 2*sum(h_e*T.*w);
end
