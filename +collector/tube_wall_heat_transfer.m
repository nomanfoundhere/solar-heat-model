function w = tube_wall_heat_transfer(od, di, len, k, film, rho, cp, bond, contact, circumference)
%TUBE_WALL_HEAT_TRANSFER  Heat path from the absorber through one tube wall into its water.
%
%   The wall's temperature state sits at the geometric-mean radius sqrt(ro*ri): half the
%   wall resistance lies on each side of it. The path is
%     absorber --(bond + wall/2)--> wall state --(wall/2 + film)--> water.
%
%   Syntax
%     w = collector.tube_wall_heat_transfer(od, di, len, k, film, rho, cp, bond, contact, circumference)
%
%   Inputs
%     od             double scalar, m, > di. Outside diameter.
%     di             double scalar, m, > 0. Inside diameter (bore).
%     len            double scalar, m, > 0. Tube length.
%     k              double scalar, W/(m K), > 0. Wall conductivity.
%     film           double scalar, W/(m^2 K), > 0. Water-side film coefficient.
%     rho            double scalar, kg/m^3, > 0. Wall density.
%     cp             double scalar, J/(kg K), > 0. Wall specific heat.
%     bond           double scalar, W/(m K) per metre of tube, >= 0. Plate-to-tube contact
%                    conductance; 0 disconnects the tube from the absorber.
%     contact        double scalar in [0, 1]. Fraction of the length touching the absorber.
%     circumference  double scalar in [0, 1]. Fraction of the circumference conducting.
%
%   Outputs
%     w   1x1 struct:
%       .capacity  double, J/K. Heat capacity of the WHOLE wall (always, even if uncoupled).
%       .bond      double, K/W. Contact resistance (NaN if uncoupled).
%       .wall      double, K/W. Full wall resistance (NaN if uncoupled).
%       .film      double, K/W. Film resistance (NaN if uncoupled).
%       .ua        double, W/K. Absorber-to-water conductance 1/(bond + wall + film); 0 if uncoupled.
%       .ga        double, W/K. Absorber-to-wall-state conductance 1/(bond + wall/2); 0 if uncoupled.
%       .gf        double, W/K. Wall-state-to-water conductance 1/(film + wall/2); 0 if uncoupled.
%
%   Errors
%     MATLAB:validators:*   an input outside the stated class/size/range.
%     leaf:wall_path        od <= di.
arguments
    od (1,1) double {mustBeReal, mustBeFinite, mustBePositive}
    di (1,1) double {mustBeReal, mustBeFinite, mustBePositive}
    len (1,1) double {mustBeReal, mustBeFinite, mustBePositive}
    k (1,1) double {mustBeReal, mustBeFinite, mustBePositive}
    film (1,1) double {mustBeReal, mustBeFinite, mustBePositive}
    rho (1,1) double {mustBeReal, mustBeFinite, mustBePositive}
    cp (1,1) double {mustBeReal, mustBeFinite, mustBePositive}
    bond (1,1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
    contact (1,1) double {mustBeInRange(contact, 0, 1)}
    circumference (1,1) double {mustBeInRange(circumference, 0, 1)}
end
if od <= di
    error('leaf:wall_path', 'Outside diameter %.4g m must exceed the bore %.4g m', od, di);
end
% The full annular wall stores heat, including wall material outside the contact.
w.capacity = rho*pi/4*(od^2 - di^2)*len*cp;
if ~(contact > 0 && circumference > 0 && bond > 0)
    % This model switches off the entire plate-wall-water path when contact
    % is removed. Radial heating of an unbonded pipe needs a separate model.
    w.bond = NaN;
    w.wall = NaN;
    w.film = NaN;
    w.ua = 0;
    w.ga = 0;
    w.gf = 0;
    return
end
% Resistances [K/W] add along the plate-to-water path. The contact factors
% reduce the available path but do not reduce the wall mass above.
w.bond = 1/(bond*len*contact);
w.wall = log(od/di)/(2*pi*k*len*contact*circumference);
w.film = 1/(pi*di*film*len*contact);
w.ua = 1/(w.bond + w.wall + w.film);
% Split the wall resistance in half around its temperature state.
w.ga = 1/(w.bond + w.wall/2);
w.gf = 1/(w.film + w.wall/2);
end
