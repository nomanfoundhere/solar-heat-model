function R = validate_kappa()
%VALIDATE_KAPPA  The collector model against the Blue Bay Kappa Curve measurement (14 Oct 2024).
%   Runs the model with the Kappa inputs (kappa_test_inputs) and nothing fitted: the central
%   optical case, the two ends of the sourced optical ranges, and for reference the black-casing
%   and no-casing cases. Writes validation/results/kappa_validation.csv (time, measured vessel,
%   model vessel per case) and returns a summary.
%
%   Syntax
%     R = validate_kappa()
here = fileparts(mfilename('fullpath'));
addpath(fileparts(here), fullfile(fileparts(here), 'simulink'));
data = read_kappa(fullfile(here, 'data', 'kappa_2024-10-14.txt'));
cases = {'central', 'low', 'high', 'black', 'none'};
tm = data.time_s; Tv = data.vessel_c;
out = tm;
for k = 1:numel(cases)
    c = kappa_test_inputs(data, cases{k});
    g = collector.prepare_model(c);
    r = simulate_collector(c);
    tt = r.history.time_s; Te = r.history.external_water_c;
    Tm = interp1(tt, Te, tm, 'linear', 'extrap');
    e = Tm - Tv;
    R.(cases{k}) = struct('light_share', g.optical_access, 'v30', interp1(tt, Te, 1800), 'vend', Te(end), ...
        'rms_k', sqrt(mean(e.^2)), 'end_error_k', mean(e(tm >= tm(end) - 30)), 'max_abs_k', max(abs(e)));
    out = [out, Tm]; %#ok<AGROW>
    fprintf('%-8s share %.3f: 30 min %.2f C, end %.2f C, RMS %.2f K, end error %+.2f K\n', cases{k}, ...
        g.optical_access, R.(cases{k}).v30, R.(cases{k}).vend, R.(cases{k}).rms_k, R.(cases{k}).end_error_k);
end
R.measured = struct('v30', mean(Tv(abs(tm - 1800) <= 30)), 'vend', mean(Tv(tm >= tm(end) - 30)), ...
    'start', Tv(1), 'flow_mean_lpm', mean(data.flow_lpm), 'duration_min', tm(end)/60);
inside = Tv >= min(out(:, 3), out(:, 4)) & Tv <= max(out(:, 3), out(:, 4));   % low .. high
R.inside_band_share = mean(inside(tm > 360));
fprintf('measured: 30 min %.2f C, end %.2f C; inside the sourced band after 6 min: %.0f %%\n', ...
    R.measured.v30, R.measured.vend, 100*R.inside_band_share);
T = array2table([out, Tv], 'VariableNames', [{'time_s'}, strcat('model_', cases), {'measured_vessel_c'}]);
writetable(T, fullfile(here, 'results', 'kappa_validation.csv'));
end


function data = read_kappa(file)
% groupX.txt: 'hh:mm:ss<TAB>T-in ; T-out ; T-vessel ; flow' every second.
L = readlines(file);
L = L(contains(L, ':') & contains(L, ';'));
L = L(~startsWith(strtrim(L), 'time'));
n = numel(L); s = zeros(n, 1); v = zeros(n, 4);
for k = 1:n
    parts = split(strtrim(L(k)), char(9));
    hms = sscanf(parts(1), '%d:%d:%d');
    s(k) = hms(1)*3600 + hms(2)*60 + hms(3);
    v(k, :) = sscanf(strrep(parts(2), ';', ' '), '%f')';
end
data.time_s = s - s(1); data.inlet_c = v(:, 1); data.outlet_c = v(:, 2);
data.vessel_c = v(:, 3); data.flow_lpm = v(:, 4);
end
