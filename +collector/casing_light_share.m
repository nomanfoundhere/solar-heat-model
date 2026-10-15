function share = casing_light_share(cs, window_l, window_w, diffuse_fraction)
%CASING_LIGHT_SHARE  Share of the lamp light that reaches a collector window inside a test casing.
%
%   The lamp light enters the casing through its glass top. Direct light (1 - diffuse_fraction)
%   falls straight down; diffuse light enters with a Lambertian distribution. Light that hits a
%   casing wall, the floor beside the collector or the collector frame is reflected diffusely with
%   that surface's reflectance; light that reaches the window is absorbed; light that returns to
%   the top leaves. The share is the light reaching the window per unit window area, relative to
%   the lamp irradiance: 1 = an unscreened window, (1 - f_d) + f_d F = black walls.
%   Solved by ray tracing with a fixed seed (repeatable to about 0.002).
%
%   Syntax
%     share = collector.casing_light_share(cs, window_l, window_w, diffuse_fraction)
%
%   Inputs
%     cs                1x1 struct: opening_mm [length width], depth_mm (window to glass),
%                       footprint_mm [length width] of the collector body, wall_reflectance,
%                       floor_reflectance, frame_reflectance (all in [0, 1]).
%     window_l, window_w  double, m. Window (aperture) size, centred in the casing.
%     diffuse_fraction  double in [0, 1].
%
%   Outputs
%     share   double scalar.
arguments
    cs (1,1) struct
    window_l (1,1) double {mustBePositive}
    window_w (1,1) double {mustBePositive}
    diffuse_fraction (1,1) double {mustBeInRange(diffuse_fraction, 0, 1)}
end
LO = cs.opening_mm(1)/1000; WO = cs.opening_mm(2)/1000; H = cs.depth_mm/1000;
LK = min(cs.footprint_mm(1)/1000, LO); WK = min(cs.footprint_mm(2)/1000, WO);
n = 400000;
old = rng; rng(1, 'twister'); cleanup = onCleanup(@() rng(old));
absorbed = 0;
for part = 1:2
    if part == 1, frac = 1 - diffuse_fraction; else, frac = diffuse_fraction; end
    if frac == 0, continue, end
    x = (rand(n, 1) - 0.5)*LO; y = (rand(n, 1) - 0.5)*WO; z = H*ones(n, 1);
    if part == 1
        dx = zeros(n, 1); dy = zeros(n, 1); dz = -ones(n, 1);
    else
        [a, b, c] = lambert(n); dx = a; dy = b; dz = -c;
    end
    w = frac*ones(n, 1);
    for bounce = 1:40
        if isempty(w), break, end
        tx = inf(size(x)); ty = tx; tz = tx;
        tx(dx > 0) = (LO/2 - x(dx > 0))./dx(dx > 0); tx(dx < 0) = (-LO/2 - x(dx < 0))./dx(dx < 0);
        ty(dy > 0) = (WO/2 - y(dy > 0))./dy(dy > 0); ty(dy < 0) = (-WO/2 - y(dy < 0))./dy(dy < 0);
        tz(dz > 0) = (H - z(dz > 0))./dz(dz > 0);    tz(dz < 0) = (0 - z(dz < 0))./dz(dz < 0);
        t = min(min(tx, ty), tz);
        x = x + t.*dx; y = y + t.*dy; z = z + t.*dz;
        wx = t == tx; wy = (t == ty) & ~wx; hz = (t == tz) & ~wx & ~wy;
        top = hz & dz > 0; bot = hz & dz < 0;
        win = bot & abs(x) <= window_l/2 & abs(y) <= window_w/2;
        absorbed = absorbed + sum(w(win));
        frame = bot & ~win & abs(x) <= LK/2 & abs(y) <= WK/2;
        floor_ = bot & ~win & ~frame;
        rho = zeros(size(w));
        rho(wx | wy) = cs.wall_reflectance; rho(frame) = cs.frame_reflectance; rho(floor_) = cs.floor_reflectance;
        w = w.*rho;
        keep = ~top & ~win & w > 1e-4;
        x = x(keep); y = y(keep); z = z(keep); w = w(keep);
        wx = wx(keep); wy = wy(keep); bb = bot(keep);
        [a, b, c] = lambert(numel(w));
        dx = a; dy = b; dz = c;                         % floor and frame: reflect upward
        dx(wx) = -sign(x(wx)).*c(wx); dy(wx) = a(wx); dz(wx) = b(wx);   % walls: reflect inward
        dx(wy) = a(wy); dy(wy) = -sign(y(wy)).*c(wy); dz(wy) = b(wy);
        dz(bb) = c(bb);
        x = min(max(x, -LO/2 + 1e-9), LO/2 - 1e-9); y = min(max(y, -WO/2 + 1e-9), WO/2 - 1e-9);
        z = min(max(z, 1e-9), H - 1e-9);
    end
end
share = absorbed/n*(LO*WO)/(window_l*window_w);
end


function [a, b, c] = lambert(n)
% Cosine-weighted directions about a surface normal: tangential components a, b and normal c.
u = rand(n, 1); v = rand(n, 1);
r = sqrt(u); phi = 2*pi*v;
a = r.*cos(phi); b = r.*sin(phi); c = sqrt(1 - u);
end
