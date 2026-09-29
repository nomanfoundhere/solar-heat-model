function [G, verdict] = check_model_limits(r)
%CHECK_MODEL_LIMITS  Check the result against the model assumptions and operating limits.
%
%   Each check gets one of four levels:
%     FAIL  do not use the result (energy not conserved, water outside the liquid range)
%     WARN  an assumption is broken and the error could go either way; use with care
%     NOTE  an assumption is broken, but the model then errs on the pessimistic side
%     OK    inside the assumption
%   Solver-tolerance and grid-convergence checks are included when r.checks
%   is supplied by run_collector. These labels do not change the computed result.
%
%   Syntax
%     [G, verdict] = collector.check_model_limits(r)
%
%   Inputs
%     r   1x1 struct from simulate_collector (needs .state_c,
%         .history, .prepared, .inputs with .limits; optional .checks from run_collector).
%
%   Outputs
%     G         n x 1 struct array, worst level first: level (char 'FAIL'/'WARN'/'NOTE'/'OK'),
%               name (char), value (char), limit (char), meaning (char).
%     verdict   char, one line judging the whole result.
%
%   Errors
%     MATLAB:validators:*   r not a 1x1 struct.
arguments
    r (1,1) struct
end
c = r.inputs;
L = c.limits;  % Struct of operating and correlation limits from collector_inputs.
g = r.prepared;
H = r.history;
Y = r.state_c;
i = g.idx;
P = g.P;
G = struct('level', {}, 'name', {}, 'value', {}, 'limit', {}, 'meaning', {});
    function rule(ok, bad, name, value, limit, meaning)
        % ok is a logical scalar. The other inputs are character labels.
        % Append one result with level OK or the supplied failure level.
        if ok
            lev = 'OK';
        else
            lev = bad;
        end
        G(end+1, 1) = struct('level', lev, 'name', name, 'value', value, 'limit', limit, 'meaning', meaning);
    end
s = r.summary;
water = Y(:, [i.external; i.water]);  % Double matrix [degC], all water states at every recorded time.
rule(abs(s.energy_residual_j) <= L.energy_residual_max*s.absorbed_j, 'FAIL', 'Energy conserved', sprintf('%.1e J', s.energy_residual_j), sprintf('< %.0e x absorbed', L.energy_residual_max), 'every joule absorbed is either stored or lost');
if isfield(r, 'checks')
    rule(r.checks.solver_difference_k <= c.numerics.convergence_tolerance_k, 'WARN', 'Solver tolerance converged', sprintf('%.1e K', r.checks.solver_difference_k), sprintf('< %g K', c.numerics.convergence_tolerance_k), '10x tighter solver tolerance barely moves any temperature');
    rule(r.checks.grid_difference_k <= c.numerics.convergence_tolerance_k, 'WARN', 'Grid converged', sprintf('%.4f K', r.checks.grid_difference_k), sprintf('< %g K', c.numerics.convergence_tolerance_k), 'doubling the water cells and backing layers barely moves any temperature');
end
wmin = min(water(:));
wmax = max(water(:));
rule(wmin > 0 && wmax < 100, 'FAIL', 'Water stays liquid', sprintf('%.1f to %.1f C', wmin, wmax), '0 to 100 C', 'the model has no ice or steam');
rule(wmin >= L.water_property_range_c(1) && wmax <= L.water_property_range_c(2), 'WARN', 'Water properties fixed at 30 C', sprintf('%.1f to %.1f C', wmin, wmax), sprintf('%g to %g C', L.water_property_range_c), 'outside this range the fixed viscosity and conductivity drift');
rule(max(H.plate_c) <= L.eps_max_c, 'WARN', 'EPS below its service limit', sprintf('%.1f C', max(H.plate_c)), sprintf('< %g C', L.eps_max_c), 'the EPS touches the plate; above its limit it softens and shrinks');
surface = Y(:, i.absorber) - (Y(:, i.absorber) - Y(:, i.wall)).*g.cells.bond_share';   % pipe outer surface under the tape
rule(max(surface(:)) <= L.pipe_max_c, 'WARN', 'Pipe below its service limit', sprintf('%.1f C', max(surface(:))), sprintf('< %g C', L.pipe_max_c), 'hottest pipe outer surface under the tape; check the tube datasheet');
q = c.test.flow_lpm;
rule(q >= L.pump_flow_range_lpm(1) && q <= L.pump_flow_range_lpm(2), 'WARN', 'Flow inside the pump range', sprintf('%g L/min', q), sprintf('%g to %g L/min', L.pump_flow_range_lpm), 'the course pump cannot run outside this range');
rule(s.pipe_dp_pa <= L.pipe_drop_share_max*L.pump_max_pa, 'WARN', 'Pressure drop small for the pump', sprintf('%.1f Pa', s.pipe_dp_pa), sprintf('< %.0f Pa', L.pipe_drop_share_max*L.pump_max_pa), 'straight pipes only; tees and bends add more');
d = c.design;
rule(d.plate_length_mm <= L.course_max_plate_mm(1) && d.plate_width_mm <= L.course_max_plate_mm(2), 'WARN', 'Footprint within the course limit', sprintf('%g x %g mm', d.plate_length_mm, d.plate_width_mm), sprintf('%g x %g mm', L.course_max_plate_mm), 'a larger collector breaks the brief');
pr = c.properties.water_cp*c.properties.water_mu/c.properties.water_k;  % Dimensionless Prandtl number at the fixed water-property temperature.
for k = 1:numel(g.stages)
    st = g.stages(k);
    re = st.reynolds;
    rule(~(re > 2300 && re < 3000), 'WARN', sprintf('%s: clear flow regime', st.name), sprintf('Re %.0f', re), 'not 2300-3000', 'between laminar and turbulent the film coefficient is a straight-line guess');
    if re <= 2300
        entrance = 0.05*re*pr*st.bore_mm;                       % mm, laminar thermal entrance length
        rule(entrance <= st.length_mm, 'NOTE', sprintf('%s: fully developed laminar flow', st.name), sprintf('entrance %.0f mm', entrance), sprintf('< pipe %.0f mm', st.length_mm), 'a longer entrance means a thinner film than Nu 4.36 assumes: more heat reaches the water');
    end
end
ra = zeros(size(Y, 1), 1);  % Double column of gap Rayleigh numbers, one per output time.
for k = 1:size(Y, 1)
    [~, ~, ~, ~, ra(k)] = collector.surface_heat_flows(Y(k, i.absorber), Y(k, i.cover_inner), Y(k, i.cover_outer), P);
end
rule(max(ra) <= L.gap_rayleigh_max, 'WARN', 'Gap convection correlation in range', sprintf('Ra %.0f', max(ra)), sprintf('< %.0e', L.gap_rayleigh_max), 'Hollands correlation fitted up to here');
if c.heat.cover
    gap_air = (H.plate_c(end) + H.cover_inner_c(end))/2 + 273.15;  % K, final mean temperature of the surfaces bounding the gap.
    rule(abs(gap_air - P.air_film_k) <= L.gap_film_band_k, 'WARN', 'Gap air near its assumed temperature', sprintf('%.1f C', gap_air - 273.15), sprintf('%.0f +/- %g C', P.air_film_k - 273.15, L.gap_film_band_k), 'air properties in the gap are fixed at air_film_temperature_k');
end
rise = max(H.underside_c) - c.test.ambient_c;  % K, largest underside surface rise above room air.
rule(rise <= L.underside_rise_max_k, 'WARN', 'Underside radiation stays near linear', sprintf('%.1f K above room', rise), sprintf('< %g K', L.underside_rise_max_k), 'the underside uses a fixed radiation coefficient');
order = {'FAIL', 'WARN', 'NOTE', 'OK'};
[~, o] = sort(cellfun(@(x) find(strcmp(order, x)), {G.level}));
G = G(o);
worst = find(ismember(order, {G.level}), 1);
verdict = {'do NOT trust this result; fix the FAIL lines first', 'usable with care; read the WARN lines', 'inside the model assumptions (NOTE lines err on the safe side)', 'inside every model assumption'};
verdict = verdict{worst};
end
