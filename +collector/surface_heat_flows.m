function [q_gap, q_core, q_top_cover, q_top_abs, rayleigh, q_gap_rad, q_top_rad] = surface_heat_flows(Ta, Tci, Tco, P)
%SURFACE_HEAT_FLOWS  Convection, radiation and conduction above the absorber.
%
%   Called by the Simulink block "Air gap, cover core, top loss".
%   Compatible with MATLAB code generation for that block.
%
%   Syntax
%     [q_gap, q_core, q_top_cover, q_top_abs] = collector.surface_heat_flows(Ta, Tci, Tco, P)
%     [..., rayleigh, q_gap_rad, q_top_rad]   = collector.surface_heat_flows(Ta, Tci, Tco, P)
%
%   Inputs
%     Ta    double scalar, degC, > -273.15. Absorber temperature.
%     Tci   double scalar, degC, > -273.15. Inner cover temperature.
%     Tco   double scalar, degC, > -273.15. Outer cover temperature.
%     P     1x1 struct of double scalars (g.P from collector.prepare_model). Fields read:
%             cover            1 = cover route on, 0 = off (uncovered Intex mat)
%             aperture_m2, cover_m2, gross_m2        m^2
%             gap_m                                  m
%             air_k W/(m K), air_nu m^2/s, air_diffusivity m^2/s, air_film_k K, gravity m/s^2
%             sigma W/(m^2 K^4); emissivity, cover_emissivity (0..1)
%             external_h W/(m^2 K); cover_resistance m^2 K/W
%             ambient_c, radiant_c                   degC
%
%   Outputs (all double scalars, W unless stated; positive = upward / out of the collector)
%     q_gap        absorber -> inner cover: natural convection across the horizontal gap
%                  heated from below (Nu = 1 + 1.44[1 - 1708/Ra]+ + [(Ra/5830)^(1/3) - 1]+)
%                  plus grey-body radiation. 0 when the cover route is off.
%     q_core       inner -> outer cover through the twinwall core, cover_m2/R (Tci - Tco).
%     q_top_cover  outer cover -> room: convection external_h + radiation to radiant_c.
%     q_top_abs    absorber -> room, only when the cover route is off (else 0).
%     rayleigh     dimensionless, >= 0. Rayleigh number of the gap air (0 if not heated from below).
%     q_gap_rad    radiation part of q_gap.
%     q_top_rad    radiation part of the top loss (from the outer cover, or from the
%                  absorber when the cover route is off).
%
%   Preconditions
%     Temperatures must be finite and above -273.15 degC. The arguments below
%     specify scalar types; the simulation functions check the resulting states.
%
%   Errors
%     MATLAB:validators:*   a temperature not a double scalar, or P not a 1x1 struct.
arguments
    Ta  (1,1) double
    Tci (1,1) double
    Tco (1,1) double
    P   (1,1) struct
end
s = P;
if s.cover > 0.5
    % Buoyancy is active when the horizontal absorber is hotter than the cover.
    % Rayleigh compares buoyancy with viscous and thermal diffusion in the gap.
    rayleigh = s.gravity/s.air_film_k*max(Ta - Tci, 0)*s.gap_m^3/(s.air_nu*s.air_diffusivity);
    if rayleigh == 0
        nu = 1; % Pure conduction across stable or isothermal gap air.
    else
        nu = 1 + 1.44*max(1 - 1708/rayleigh, 0) + max((rayleigh/5830)^(1/3) - 1, 0);
    end
    % Longwave exchange uses the large-parallel-surface approximation F = 1.
    % Side-wall radiation is omitted. The finite-opening solar view factor
    % in prepare_model does not multiply this thermal exchange.
    absorber_k = Ta + 273.15;  % K, absolute absorber temperature.
    inner_cover_k = Tci + 273.15;  % K, absolute inner-cover temperature.
    radiation_resistance = 1/s.emissivity + 1/s.cover_emissivity - 1;  % Dimensionless grey-surface resistance.
    q_gap_rad = s.aperture_m2*s.sigma*(absorber_k^4 - inner_cover_k^4)/radiation_resistance;
    gap_conductance = s.aperture_m2*s.air_k*nu/s.gap_m;  % W/K, gas conduction and natural convection over the aperture.
    q_gap = gap_conductance*(Ta - Tci) + q_gap_rad;
    % The cover resistance is per unit area, so area/resistance gives W/K.
    q_core = s.cover_m2/s.cover_resistance*(Tci - Tco);
    % Convection uses room-air temperature; radiation uses surrounding-surface temperature.
    q_top_rad = s.cover_m2*s.cover_emissivity*s.sigma*((Tco + 273.15)^4 - (s.radiant_c + 273.15)^4);
    q_top_cover = s.cover_m2*s.external_h*(Tco - s.ambient_c) + q_top_rad;
    q_top_abs = 0;
else
    % Without a cover, the absorber exchanges heat directly with the room.
    rayleigh = 0;
    q_gap = 0;
    q_core = 0;
    q_top_cover = 0;
    q_gap_rad = 0;
    q_top_rad = s.gross_m2*s.emissivity*s.sigma*((Ta + 273.15)^4 - (s.radiant_c + 273.15)^4);
    q_top_abs = s.gross_m2*s.external_h*(Ta - s.ambient_c) + q_top_rad;
end
end
