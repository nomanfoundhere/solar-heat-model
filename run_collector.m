function r = run_collector(c, options)
%RUN_COLLECTOR  Run the collector model and save checked results.
%
%   Before anything is written, three checks must pass:
%     solver   rerunning with 10x tighter solver tolerance moves no temperature by more
%              than c.numerics.convergence_tolerance_k
%     grid     doubling the water cells and backing layers moves no temperature by more
%              than that tolerance
%     energy   absorbed light - losses - stored heat closes to 1e-6 of the absorbed energy
%
%   Syntax
%     run_collector
%     r = run_collector(c)
%     run_collector(PDF=true)          also write every figure as a vector PDF (for reports)
%
%   Inputs
%     c             1x1 struct from collector_inputs, optional (default collector_inputs()).
%     options.PDF   logical, optional name-value (default false). Vector PDFs of the figures
%                   as well as PNGs.
%
%   Outputs
%     r   1x1 struct from simulate_collector, plus
%       .checks      1x1 struct of double scalars: solver_difference_k, grid_difference_k (K),
%                    energy_residual_j (J).
%       .guardrails  struct array from collector.check_model_limits; .verdict (char).
%
%   Errors
%     MATLAB:validators:*   c not a 1x1 struct.
%     leaf:check            a check or a FAIL guardrail failed (message gives the value);
%                           nothing is written.
%     (errors of simulate_collector propagate)
%
%   Side effects
%     Adds this folder and "simulink" to the MATLAB path. Replaces results/ with this
%     run only: summary.md (key numbers, checks, guardrails), history.csv, stages.csv,
%     results.mat and six figures (.png; .pdf too with PDF=true). The files are written to a temporary folder
%     first, so results/ is only replaced by a complete, checked run. Prints the headline,
%     every guardrail that is not OK, and the verdict.
arguments
    c (1,1) struct = collector_inputs()
    options.PDF (1,1) logical = false
end
root = fileparts(mfilename('fullpath'));  % Folder path containing the model entry point.
addpath(root, fullfile(root, 'simulink'));
tol = c.numerics.convergence_tolerance_k;  % K, allowed temperature change under numerical refinement.

r = simulate_collector(c);
keys = {'plate_c', 'water_c', 'external_water_c', 'collector_water_mean_c', 'tube_wall_mean_c', 'eps_mean_c', 'underside_c', 'cover_inner_c', 'cover_outer_c', 'outlet_c'};
tight = simulate_collector(c, 1e-8);  % Same physical inputs with a tenfold tighter solver tolerance.
cf = c;  % Copy of the inputs used for the spatial-refinement check.
cf.numerics.cells_per_segment = 2*c.numerics.cells_per_segment;
cf.numerics.backing_cells = 2*c.numerics.backing_cells;
% Refine both the water path and backing; each has its own temperature gradient.
fine = simulate_collector(cf);
r.checks.solver_difference_k = max_difference(r.history, tight.history, keys);
r.checks.grid_difference_k = max_difference(r.history, fine.history, keys);
r.checks.energy_residual_j = r.summary.energy_residual_j;
if r.checks.solver_difference_k > tol
    error('leaf:check', 'Solver tolerance not converged: %.3g K', r.checks.solver_difference_k);
end
if r.checks.grid_difference_k > tol
    error('leaf:check', 'Grid not converged: %.3g K; increase cells_per_segment', r.checks.grid_difference_k);
end
if abs(r.checks.energy_residual_j) > 1e-6*max(1, r.summary.absorbed_j)
    error('leaf:check', 'Energy ledger does not close');
end

[r.guardrails, r.verdict] = collector.check_model_limits(r);
fails = r.guardrails(strcmp({r.guardrails.level}, 'FAIL'));
if ~isempty(fails)
    error('leaf:check', 'Guardrail failed: %s (%s)', fails(1).name, fails(1).value);
end

% Write into a fresh folder first; only a complete, checked run replaces results/.
out = tempname;  % Temporary output-folder path; complete files replace results together.
mkdir(out);
writetable(struct2table(r.history), fullfile(out, 'history.csv'));
writetable(struct2table(r.stages), fullfile(out, 'stages.csv'));
collector.plot_collector_results(r, out, options.PDF);
collector.write_results_summary(r, out);
save(fullfile(out, 'results.mat'), 'r');
results = fullfile(root, 'results');
if exist(results, 'dir')
    rmdir(results, 's');
end
movefile(out, results);
fprintf('Water %.3f C after %g min; %.1f kJ in the water; 40 C at %s.\n', r.summary.final_water_c, c.test.duration_s/60, r.summary.water_energy_j/1000, target_text(r.summary.time_to_target_s));
for k = 1:numel(r.guardrails)
    if ~strcmp(r.guardrails(k).level, 'OK')
        fprintf('[%s] %s: %s\n', r.guardrails(k).level, r.guardrails(k).name, r.guardrails(k).value);
    end
end
fprintf('Guardrails: %s.\nResults: %s\n', r.verdict, results);
end


function d = max_difference(a, b, keys)
% d = max_difference(a, b, keys): a, b run histories (struct of equal-length double columns); keys cellstr ->
% d double scalar (K), largest |a - b| over the listed columns, ignoring NaN.
d = 0;  % K, largest difference across the selected history columns.
for k = 1:numel(keys)
    x = a.(keys{k});
    y = b.(keys{k});
    ok = ~isnan(x) & ~isnan(y);  % Logical column excluding undefined outputs such as outlet temperature at zero flow.
    d = max([d; abs(x(ok) - y(ok))]);
end
end


function s = target_text(t)
% s = target_text(t): t double scalar (s, NaN = not reached) -> s char, e.g. '22.2 min'.
if isnan(t)
    s = 'not reached';
else
    s = sprintf('%.1f min', t/60);
end
end
