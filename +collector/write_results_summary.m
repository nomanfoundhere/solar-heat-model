function write_results_summary(r, out)
%WRITE_RESULTS_SUMMARY  Write summary.md for one checked run: key numbers, checks, guardrails, figures.
%
%   Syntax
%     collector.write_results_summary(r, out)
%
%   Inputs
%     r     1x1 struct from run_collector: as collector.summarize_results plus .solver (char), .checks
%           (struct of double scalars solver_difference_k, grid_difference_k (K),
%           energy_residual_j (J)), .guardrails (struct array) and .verdict (char).
%     out   char or string scalar. Existing folder.
%
%   Outputs
%     None.
%
%   Errors
%     MATLAB:validators:*   wrong class; out not an existing folder.
%
%   Side effects
%     Writes out/summary.md (overwrites).
arguments
    r (1,1) struct
    out {mustBeTextScalar, mustBeFolder}
end
s = r.summary;
c = r.inputs;
k = r.checks;
H = r.history;
tc = c.test.target_c;
if isnan(s.time_to_target_s)
    tv = 'not reached';
else
    tv = sprintf('%.1f min', s.time_to_target_s/60);
end
j = find(H.water_c >= tc, 1);
if isempty(j) || j == 1
    tw = 'not reached';
else
    tw = sprintf('%.1f min', interp1(H.water_c(j-1:j), H.time_s(j-1:j), tc)/60);
end
L = {};
L{end+1} = '# Leaf model results';
L{end+1} = '';
L{end+1} = sprintf('Model `simulink/solar_collector.slx` (%s), inputs `collector_inputs.m`, run %s. Test: %g W/m², %g L/min, %g min, room %g °C.', r.solver, char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')), c.test.irradiance, c.test.flow_lpm, c.test.duration_s/60, c.test.ambient_c);
L{end+1} = '';
L{end+1} = '## Key numbers';
L{end+1} = '';
L{end+1} = '| Quantity | Result |';
L{end+1} = '|---|---:|';
L{end+1} = sprintf('| All water (energy-weighted mean) after %g min | %.2f °C |', c.test.duration_s/60, s.final_water_c);
L{end+1} = sprintf('| Time to %g °C: all water / vessel water | %s / %s |', tc, tw, tv);
L{end+1} = sprintf('| Heat into the water | %.0f kJ |', s.water_energy_j/1000);
L{end+1} = sprintf('| Efficiency: water heat / light on the footprint | %.1f %% |', 100*s.water_efficiency_gross);
L{end+1} = sprintf('| Plate above the water at the end | %.1f K |', s.final_plate_c - s.final_water_c);
L{end+1} = sprintf('| Collector outlet / absorber plate at the end | %.2f / %.2f °C |', s.final_outlet_c, s.final_plate_c);
L{end+1} = sprintf('| Light absorbed / lost / stored | %.1f / %.1f / %.1f kJ |', s.absorbed_j/1000, s.lost_j/1000, s.stored_j/1000);
L{end+1} = sprintf('| Straight-pipe pressure drop along one path (tees, bends excluded) | %.1f Pa |', s.pipe_dp_pa);
L{end+1} = sprintf('| Tube water in the collector / tube length | %.1f mL / %.3f m |', s.tube_water_l*1000, s.total_length_m);
L{end+1} = sprintf('| Diffuse opening view factor / rim optical access | %.5f / %.5f |', r.prepared.diffuse_view_factor, r.prepared.optical_access);
L{end+1} = sprintf('| External vessel and hose heat-loss conductance | %.5f W/K |', r.prepared.P.loop_ua);
L{end+1} = '';
L{end+1} = '## Checks of the calculation (all passed before these files were written)';
L{end+1} = '';
L{end+1} = sprintf('- Solver: 10x tighter tolerance changes temperatures by at most %.2g K.', k.solver_difference_k);
L{end+1} = sprintf('- Grid: doubling water cells and backing layers changes temperatures by at most %.2g K.', k.grid_difference_k);
L{end+1} = sprintf('- Energy: absorbed - lost - stored = %.2g J.', k.energy_residual_j);
L{end+1} = '';
L{end+1} = sprintf('## Guardrails: %s', r.verdict);
L{end+1} = '';
L{end+1} = 'Is the result inside what the model assumes? FAIL: do not use; WARN: an assumption is broken, error either way; NOTE: broken, but the model errs on the safe side.';
L{end+1} = '';
L{end+1} = '| Level | Check | Value | Limit | Meaning |';
L{end+1} = '|---|---|---|---|---|';
for g = r.guardrails'
    L{end+1} = sprintf('| %s | %s | %s | %s | %s |', g.level, g.name, g.value, g.limit, g.meaning); %#ok<AGROW>
end
L{end+1} = '';
L{end+1} = '## Figures';
L{end+1} = '';
figs = {'temperatures', 'How every part heats up';
    'energy', 'Where the lamp energy goes';
    'efficiency', 'How well it collects';
    'inside', 'Along the pipes and through the backing';
    'pipe_tiers', 'What each tier of the leaf does';
    'pump_range', 'Pressure drop and flow regime across the pump range'};
for q = 1:size(figs, 1)
    L{end+1} = sprintf('![%s](%s.png)', figs{q, 2}, figs{q, 1}); %#ok<AGROW>
end
L{end+1} = '';
L{end+1} = '## Assumptions';
L{end+1} = '';
L{end+1} = '- Equal flow in every branch of the symmetric leaf; one absorber temperature.';
L{end+1} = '- Vessel and hoses are one mixed water temperature.';
L{end+1} = '- Diffuse solar screening uses the finite opening geometry; direct light is assumed normal to the opening. Longwave plate-to-cover exchange separately uses a view factor of one.';
L{end+1} = '- External-loop conductance follows the entered vessel and hose geometry unless heat.loop_ua supplies an explicit value.';
L{end+1} = '- Black paint, LDPE conductivity, a bare tube resting on the plate (line contact through an air gap) and fixed material properties are assumed (see collector_inputs.m).';
L{end+1} = sprintf('- Flow is imposed (%g L/min), not solved from the pump curve.', c.test.flow_lpm);
L{end+1} = '- The outlet is the last collector water cell; sensor-line transport is not modelled.';
L{end+1} = '- Each water cell has its own tube-wall cell (half the wall resistance on each side).';
L{end+1} = '- The back loses heat through layered EPS and the Trespa plate, both storing heat; edges are one steady conductance.';
fid = fopen(fullfile(out, 'summary.md'), 'w');
fprintf(fid, '%s\n', L{:});
fclose(fid);
end
