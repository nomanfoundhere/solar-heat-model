function f = cover_view_factor(len, width, gap)
%COVER_VIEW_FACTOR  Diffuse view factor between two equal, parallel, directly opposed rectangles.
%
%   Used for rim screening: the share of diffuse light entering the cover opening that
%   reaches the absorber across the air gap. Assumes a uniformly diffuse field,
%   aligned rectangular openings and absorbing side walls (no reflected recovery).
%   Direct light is treated separately as normal to the opening.
%   This optical factor is not used in the large-surface thermal-radiation model.
%
%   Syntax
%     f = collector.cover_view_factor(len, width, gap)
%
%   Inputs
%     len     double scalar, m, > 0. Rectangle length.
%     width   double scalar, m, > 0. Rectangle width.
%     gap     double scalar, m, > 0. Distance between the rectangles.
%
%   Outputs
%     f       double scalar in (0, 1), dimensionless.
%
%   Errors
%     MATLAB:validators:*   an input outside the stated class/size/range.
arguments
    len (1,1) double {mustBeReal, mustBeFinite, mustBePositive}
    width (1,1) double {mustBeReal, mustBeFinite, mustBePositive}
    gap (1,1) double {mustBeReal, mustBeFinite, mustBePositive}
end
x = len/gap;  % Dimensionless rectangle length divided by separation.
y = width/gap;  % Dimensionless rectangle width divided by separation.
% Integrating the diffuse kernel cos(theta_1)*cos(theta_2)/(pi*r^2)
% over both rectangles gives the expression below. For parallel planes,
% each cosine is gap/r; r is the distance between the two area elements.
% Only length/gap and width/gap remain, so uniform scaling cannot change f.
diagonal_x = sqrt(1 + x^2);  % Dimensionless diagonal in the length-gap plane.
diagonal_y = sqrt(1 + y^2);  % Dimensionless diagonal in the width-gap plane.
log_term = 0.5*log((1 + x^2)*(1 + y^2)/(1 + x^2 + y^2));
length_term = x*diagonal_y*atan(x/diagonal_y);
width_term = y*diagonal_x*atan(y/diagonal_x);
length_edge = x*atan(x);
width_edge = y*atan(y);
integrated_geometry = log_term + length_term + width_term;
integrated_geometry = integrated_geometry - length_edge - width_edge;
f = 2*integrated_geometry/(pi*x*y);  % Fraction of diffuse power reaching the opposite opening.
end
