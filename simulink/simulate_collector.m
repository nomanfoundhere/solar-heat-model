function r = simulate_collector(c, tolerance)
%SIMULATE_COLLECTOR  Run the plain Simulink leaf model (solar_collector.slx) for one set of inputs.
%
%   The model solves C dT/dt = heat in - heat out for every heat store with ode15s
%   (variable step, stiff), logging every state each second.
%
%   Syntax
%     r = simulate_collector(c)
%     r = simulate_collector(c, tolerance)
%
%   Inputs
%     c           1x1 struct from collector_inputs (or a modified copy).
%     tolerance   double scalar in (0, 1e-3], optional. Solver relative AND absolute
%                 tolerance; default 1e-7 (set in the model).
%
%   Outputs
%     r   1x1 struct, as collector.summarize_results (summary, history every c.numerics.record_s,
%         stages, prepared, inputs), plus
%       .solver   char, 'Simulink ode15s (solar_collector.slx)'.
%
%   Errors
%     MATLAB:validators:*   wrong class, size or range.
%     leaf:inputs, leaf:prepare   from collector.prepare_model.
%     leaf:simulink         a temperature became non-finite.
%     (Simulink errors propagate, e.g. if solar_collector.slx is missing: run build_collector_model)
%
%   Side effects
%     Runs with the model folder as the current folder and restores it afterwards.
%     Loads solar_collector into memory (not opened). Simulink's build cache goes to
%     <tempdir>/leaf_model_cache (previous cache settings restored afterwards). No result files.
arguments
    c (1,1) struct
    tolerance (1,1) double {mustBePositive, mustBeLessThanOrEqual(tolerance, 1e-3)} = 1e-7
end
here = fileparts(mfilename('fullpath'));
g = collector.prepare_model(c);  % Struct of capacities, conductances, geometry and state indices.
t = c.test;
nm = c.numerics;
i = g.idx;  % Positions of each physical heat store in the logged state vector.
[P, LP] = workspace(g, t);
model = 'solar_collector';
restore = cache_outside(); %#ok<NASGU>   % build cache in tempdir, restored on return
% Code generation has required the model root as the current folder to find
% +collector, even with that folder on the path. The underlying cause is unresolved.
% onCleanup restores the caller's folder if the simulation returns or errors.
back = cd(fileparts(here)); % Caller folder path, restored by the cleanup object.
restore_folder = onCleanup(@() cd(back));
load_system(fullfile(here, [model '.slx']));
in = Simulink.SimulationInput(model);
in = in.setVariable('P', P).setVariable('LP', LP);
in = in.setModelParameter('RelTol', num2str(tolerance), 'AbsTol', num2str(tolerance));
out = sim(in);  % Simulink output object containing times, temperatures and energy totals.
% yout (Array format): the logged state vector, then [absorbed, lost] energy
tt = out.tout;  % Double column [s], solver output times.
Y = out.yout(:, 1:g.n_states);  % Double matrix [degC], one column per heat store.
E = out.yout(:, g.n_states + (1:2));  % Two double columns [J]: cumulative absorbed and lost energy.
if any(~isfinite(Y(:)))
    error('leaf:simulink', 'Nonphysical thermal state');
end
% Output rows every record_s (the model also returns 1 s samples for the target time)
C = zeros(g.n_states, 1);  % Double column [J/K], heat capacity matched to each state.
C([i.absorber, i.external, i.cover_inner, i.cover_outer]) = [g.C(1), g.C_external, g.C(3), g.C(4)];
C(i.water) = g.cells.C_water;
C(i.wall) = g.cells.C_wall;
C(i.backing) = g.backing.C;
% Select the requested recording interval from the one-second solver output.
keep = abs(mod(tt + 1e-9, nm.record_s)) < 1e-6 | abs(tt - t.duration_s) < 1e-9;
H = collector.calculate_history(Y(keep, :), tt(keep), E(keep, 1), E(keep, 2), g, C, t);
Te = Y(:, i.external);  % Double column [degC], vessel and hose-water temperature.
hit = NaN;  % s, first vessel target crossing; NaN if the target is not reached.
if t.initial_c >= t.target_c
    hit = 0;
else
    % Estimate the crossing time between the two samples that straddle the target.
    k = find(Te(1:end-1) < t.target_c & Te(2:end) >= t.target_c, 1);
    if ~isempty(k)
        hit = tt(k) + (tt(k+1) - tt(k))*(t.target_c - Te(k))/(Te(k+1) - Te(k));
    end
end
r = collector.summarize_results(H, g, c, hit, Y(keep, :));
r.solver = 'Simulink ode15s (solar_collector.slx)';
end


function [P, LP] = workspace(g, t)
% [P, LP] = workspace(g, t): g from collector.prepare_model, t = c.test -> P 1x1 struct of double scalars (g.P with T0);
% LP 1x1 struct: nw, nb (counts); Cwat, Cwall, ga, gf, share (nw x 1); Cb (nb x 1); Gb ((nb+1) x 1);
% Ab (nb x nb, W/K, layer conduction); e1G, bamb (nb x 1); duration (s); out_times (column, s).
P = g.P;
P.T0 = t.initial_c;
nb = numel(g.backing.C);  % Number of backing layers.
G = g.backing.G;  % Double column [W/K], links from plate through backing to room.
Ab = zeros(nb);  % Double matrix [W/K], conduction contributions between backing states.
for k = 1:nb
    Ab(k, k) = -(G(k) + G(k+1));
    if k < nb
        Ab(k, k+1) = G(k+1);
        Ab(k+1, k) = G(k+1);
    end
end
e1G = zeros(nb, 1);  % Double column [W/K], plate conductance at the first layer only.
e1G(1) = G(1);
bamb = zeros(nb, 1);  % Double column [W], ambient-temperature source at the last layer.
bamb(end) = G(end)*t.ambient_c;
% 1 s grid plus the exact end
LP.nw = numel(g.cells.C_water);
LP.nb = nb;
LP.Cwat = g.cells.C_water;
LP.Cwall = g.cells.C_wall;
LP.ga = g.cells.ga;
LP.gf = g.cells.gf;
LP.share = g.cells.footprint_share;
LP.Cb = g.backing.C;
LP.Gb = G;
LP.Ab = Ab;
LP.e1G = e1G;
LP.bamb = bamb;
LP.duration = t.duration_s;
LP.out_times = unique([(0:1:t.duration_s)'; t.duration_s]);
end


function restore = cache_outside()
% restore = cache_outside(): points Simulink's cache and code-generation folders at
% <tempdir>/leaf_model_cache so no slprj/ or .slxc lands in the model folder; returns an
% onCleanup object that restores the previous folders when it goes out of scope.
old = Simulink.fileGenControl('getConfig');
d = fullfile(tempdir, 'leaf_model_cache');
if ~exist(d, 'dir')
    mkdir(d);
end
Simulink.fileGenControl('set', 'CacheFolder', d, 'CodeGenFolder', d, 'createDir', true);
restore = onCleanup(@() Simulink.fileGenControl('set', 'CacheFolder', old.CacheFolder, 'CodeGenFolder', old.CodeGenFolder));
end
