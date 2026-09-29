function [h, re, nu] = water_heat_transfer(bore, len, flow, c)
%WATER_HEAT_TRANSFER  Water-side heat-transfer coefficient inside one tube.
%
%   Syntax
%     [h, re, nu] = collector.water_heat_transfer(bore, len, flow, c)
%
%   Inputs
%     bore   double scalar, m, > 0. Inner diameter of the tube.
%     len    double scalar, m, > 0. Length of the tube (used by the developing-flow option).
%     flow   double scalar, m^3/s, >= 0. Volume flow through THIS tube.
%     c      1x1 struct from collector_inputs. Reads c.properties.water_density, water_mu,
%            water_cp, water_k and c.heat.internal_model, laminar_nusselt.
%
%   Outputs
%     h      double scalar, W/(m^2 K), > 0. Film coefficient, nu*k/bore.
%     re     double scalar, dimensionless, >= 0. Reynolds number.
%     nu     double scalar, dimensionless, > 0. Nusselt number:
%              re <= 2300: laminar_nusselt ('fully_developed', 4.36 = constant-flux limit)
%                          or the Hausen developing-flow expression ('developing');
%              re >= 3000: Gnielinski; 2300..3000 interpolated.
%            At zero flow the laminar value is kept as an effective conductance: trapped
%            water can heat, but stagnant radial diffusion is not resolved.
%
%   Errors
%     MATLAB:validators:*       an input outside the stated class/size/range.
%     leaf:film_coefficient     turbulent flow outside Re <= 5e6, 0.5 <= Pr <= 2000.
arguments
    bore (1,1) double {mustBeReal, mustBeFinite, mustBePositive}
    len  (1,1) double {mustBeReal, mustBeFinite, mustBePositive}
    flow (1,1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
    c    (1,1) struct
end
p = c.properties;  % Struct of constant water properties in SI units.
ht = c.heat;  % Struct selecting the water-film correlation.
re = 4*p.water_density*flow/(pi*bore*p.water_mu);  % Dimensionless Reynolds number, using the mean bore velocity.
pr = p.water_cp*p.water_mu/p.water_k;  % Dimensionless Prandtl number of the water.
% The laminar correlation uses the Graetz number Re*Pr*diameter/length.
if re <= 2300
    nu = laminar(bore/len*re*pr, ht);
else
    if re > 5e6 || pr < 0.5 || pr > 2000
        error('leaf:film_coefficient', 'Outside the turbulent-film correlation range (Re %.3g, Pr %.3g)', re, pr);
    end
    rt = max(re, 3000);  % Reynolds number used in the turbulent correlation.
    f = (0.79*log(rt) - 1.64)^-2;  % Dimensionless smooth-pipe Darcy factor (Petukhov).
    numerator = (f/8)*(rt - 1000)*pr;  % Dimensionless Gnielinski numerator.
    denominator = 1 + 12.7*sqrt(f/8)*(pr^(2/3) - 1);
    turbulent_nu = numerator/denominator;  % Dimensionless turbulent Nusselt number.
    if re >= 3000
        nu = turbulent_nu;
    else
        % A linear blend joins the laminar and turbulent limits.
        fraction = (re - 2300)/(3000 - 2300);  % Position between the two Reynolds-number limits.
        laminar_nu = laminar(bore/len*2300*pr, ht);  % Laminar value at the lower limit.
        nu = (1 - fraction)*laminar_nu + fraction*turbulent_nu;
    end
end
h = nu*p.water_k/bore;  % W/(m^2 K), from the definition Nu = h*diameter/conductivity.
end


function nu = laminar(gz, ht)
% nu = laminar(gz, ht): gz double scalar (Graetz number, -), ht = c.heat -> nu double scalar, laminar Nusselt number.
if strcmp(ht.internal_model, 'fully_developed')
    nu = ht.laminar_nusselt;
else
    % Hausen correlation: the entrance region raises heat transfer above 3.66.
    nu = 3.66 + 0.0668*gz/(1 + 0.04*gz^(2/3));
end
end
