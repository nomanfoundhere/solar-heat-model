function f = pipe_friction_factor(re)
%PIPE_FRICTION_FACTOR  Darcy friction factor of a smooth circular pipe.
%
%   Syntax
%     f = collector.pipe_friction_factor(re)
%
%   Inputs
%     re   double scalar, dimensionless, finite, >= 0. Reynolds number.
%
%   Outputs
%     f    double scalar, dimensionless, >= 0. Darcy friction factor:
%            re = 0            -> 0 (no flow, no friction)
%            0 < re <= 2300    -> 64/re (laminar)
%            re >= 3000        -> Petukhov smooth-pipe correlation
%            2300 < re < 3000  -> linear interpolation (a declared transition
%                                 assumption, not a transition model)
%
%   Errors
%     MATLAB:validators:*   re not a finite nonnegative real scalar.
arguments
    re (1,1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
end
if re == 0
    f = 0;
    return
end
if re <= 2300
    f = 64/re;
    return
end
% Petukhov correlation for a smooth pipe, evaluated from Re = 3000 upward.
turbulent = (0.79*log(max(re, 3000)) - 1.64)^-2;
if re >= 3000
    f = turbulent;
    return
end
fraction = (re - 2300)/(3000 - 2300); % Position between the Reynolds-number limits.
f = (1 - fraction)*64/2300 + fraction*turbulent;
end
