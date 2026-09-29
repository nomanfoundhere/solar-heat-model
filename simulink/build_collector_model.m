function build_collector_model()
%BUILD_COLLECTOR_MODEL  Generate solar_collector.slx, the leaf collector as a Simulink block diagram.
%
%   Run after changing the model STRUCTURE. Inputs are not built in: they live in
%   collector_inputs.m and are passed in by simulate_collector.m at run time.
%
%   Layout follows the heat path, top to bottom: outer cover, inner cover, absorber
%   plate, tube walls, tube water (feeding the external water on the right), backing.
%   Each heat store is a subsystem that adds up the heat flowing into it and integrates
%   C dT/dt = net heat. Links compute heat flows from temperatures. All physics formulas
%   come from the +collector package. Workspace variables read by the model: P and LP (see
%   simulate_collector/workspace).
%
%   Syntax
%     build_collector_model
%
%   Inputs
%     None.
%
%   Outputs
%     None.
%
%   Errors
%     Simulink errors propagate (e.g. a library block renamed in a future release).
%
%   Side effects
%     Closes solar_collector if loaded (unsaved changes discarded), deletes and rewrites
%     "simulink/solar_collector.slx". Prints the path.
here = fileparts(mfilename('fullpath'));
name = 'solar_collector';
if bdIsLoaded(name)
    close_system(name, 0);
end
if exist(fullfile(here, [name '.slx']), 'file')
    delete(fullfile(here, [name '.slx']));
end
new_system(name);
m = name;
set_param(m, 'Solver', 'ode15s');
set_param(m, 'RelTol', '1e-7');
set_param(m, 'AbsTol', '1e-7');
set_param(m, 'MaxStep', '5');
set_param(m, 'StartTime', '0');
set_param(m, 'StopTime', 'LP.duration');
set_param(m, 'SaveOutput', 'on');
set_param(m, 'SaveTime', 'on');
set_param(m, 'SaveFormat', 'Array');
set_param(m, 'OutputOption', 'SpecifiedOutputTimes');
set_param(m, 'OutputTimes', 'LP.out_times');
set_param(m, 'SaveState', 'off');
set_param(m, 'ReturnWorkspaceOutputs', 'on');

%% Layout: one row per heat store, top (cover) to bottom (backing), along the heat path.
% Temperatures are broadcast with Goto tags and picked up with From blocks where they are
% needed, so the only wires left are the heat-flow wires between neighbours. Each Goto/From
% is placed from the port it serves (see goto/from), so every tag wire is straight.
% Block widths (px): links and stores fit their equation icons beside the port labels; the
% backing carries three port labels on the right and a three-line equation, so it is wider.
WL = 240;
WS = 260;
WB = WS + 80;
[tw, ~, tg] = tag_size();
TAG = tw + tg;  % a Goto/From beside its port
XL = 180;                                           % columns follow from the widths:
XS = XL + WL + TAG + 40;                            % stores: link tags + 40 px wire channel
XR = XS + WS + TAG + 60;                            % vessel: store tags + room for T outlet
XO = XR + WS + TAG + 40 + TAG;                      % outputs: vessel tags, channel, ledger tags

% Cover: outer and inner sheet, with the surface link (gap, core, top loss) to their left
store_cover(m, 'Outer cover', [XS 70 XS+WS 140], 'outer');
store_cover(m, 'Inner cover', [XS 190 XS+WS 260], 'inner');
surface_link(m, [XL 90 XL+WL 250]);
from(m, 'T_absorber', 'Air gap, cover core, top loss/1');
from(m, 'T_inner_cover', 'Air gap, cover core, top loss/2');
from(m, 'T_outer_cover', 'Air gap, cover core, top loss/3');
wire(m, 'Air gap, cover core, top loss/1', 'Inner cover/1');
wire(m, 'Air gap, cover core, top loss/2', 'Inner cover/2');
wire(m, 'Air gap, cover core, top loss/2', 'Outer cover/1');
wire(m, 'Air gap, cover core, top loss/3', 'Outer cover/2');
goto(m, 'Outer cover/1', 'T_outer_cover');
goto(m, 'Inner cover/1', 'T_inner_cover');
% The top-loss outputs also feed the stores to the right, so their tags sit under the link
% block, facing left so each wire drops straight down the channel into the tag's right-hand input.
goto(m, 'Air gap, cover core, top loss/3', 'q_top_cover', [XL+WL-tw 270]);
goto(m, 'Air gap, cover core, top loss/4', 'q_top_absorber', [XL+WL-tw 305]);

% Absorber plate, pipe walls and pipe water, with the links between them on the left
store_absorber(m, [XS 400 XS+WS 520]);
wire(m, 'Air gap, cover core, top loss/1', 'Absorber plate/1');
wire(m, 'Air gap, cover core, top loss/4', 'Absorber plate/2');
goto(m, 'Absorber plate/1', 'T_absorber');
goto(m, 'Absorber plate/2', 'q_edge');
from(m, 'q_plate_backing', 'Absorber plate/4');
vector_link(m, 'Plate to tube walls', [XL 560 XL+WL 630], 'ga', true);
from(m, 'T_absorber', 'Plate to tube walls/1');
from(m, 'T_walls', 'Plate to tube walls/2');
store_walls(m, [XS 560 XS+WS 630]);
wire(m, 'Plate to tube walls/1', 'Tube walls/1');
wire(m, 'Plate to tube walls/2', 'Absorber plate/3');
goto(m, 'Tube walls/1', 'T_walls');
vector_link(m, 'Walls to water', [XL 690 XL+WL 760], 'gf', false);
from(m, 'T_walls', 'Walls to water/1');
from(m, 'T_water', 'Walls to water/2');
store_water(m, [XS 690 XS+WS 760]);
wire(m, 'Walls to water/1', 'Tube walls/2');
wire(m, 'Walls to water/1', 'Tube water/1');
from(m, 'T_external', 'Tube water/2');
goto(m, 'Tube water/1', 'T_water');

% Vessel + hoses (the pipe water's outlet feeds it; it feeds the trunk back via T_external)
store_external(m, [XR 690 XR+WS 760]);
wire(m, 'Tube water/2', 'External water/1');
goto(m, 'External water/1', 'T_external');
goto(m, 'External water/2', 'q_loop');

% Backing under the plate
store_backing(m, [XS 840 XS+WB 930]);
from(m, 'T_absorber', 'Backing (EPS + Trespa)/1');
goto(m, 'Backing (EPS + Trespa)/1', 'T_backing');
goto(m, 'Backing (EPS + Trespa)/2', 'q_plate_backing');
goto(m, 'Backing (EPS + Trespa)/3', 'q_underside');

% Outputs: energy ledger and the logged state vector (order of g.idx)
ledger(m, [XO 600 XO+200 740]);
tags = {'q_top_cover', 'q_top_absorber', 'q_edge', 'q_loop', 'q_underside'};
for k = 1:5
    from(m, tags{k}, sprintf('Energy ledger/%d', k));
end
add_block('simulink/Sinks/Out1', [m '/Energy (absorbed, lost)'], 'Position', [XO+260 660 XO+290 680]);
wire(m, 'Energy ledger/1', 'Energy (absorbed, lost)/1');
add_block('simulink/Signal Routing/Vector Concatenate', [m '/State vector'], 'NumInputs', '7', 'Position', [XO+60 90 XO+70 470]);
state = {'T_absorber', 'T_external', 'T_inner_cover', 'T_outer_cover', 'T_water', 'T_walls', 'T_backing'};
for k = 1:7
    from(m, state{k}, sprintf('State vector/%d', k));
end
add_block('simulink/Sinks/Out1', [m '/T (all states)'], 'Position', [XO+130 270 XO+160 290]);
wire(m, 'State vector/1', 'T (all states)/1');
% simulate_collector reads root output 1 as the temperatures and 2 as the ledger: fix the numbers,
% not the creation order.
set_param([m '/T (all states)'], 'Port', '1');
set_param([m '/Energy (absorbed, lost)'], 'Port', '2');
colour(m);
bottom = areas(m, { 'Cover (twinwall sheet)', {'Outer cover', 'Inner cover', 'Air gap, cover core, top loss'}, [0.93 0.96 1.00];
    'Absorber plate and pipes', {'Absorber plate', 'Plate to tube walls', 'Tube walls', 'Walls to water', 'Tube water'}, [1.00 0.96 0.92];
    'Vessel + hoses', {'External water'}, [0.92 0.97 0.98];
    'Backing: EPS + Trespa', {'Backing (EPS + Trespa)'}, [0.95 0.95 0.95];
    'Outputs: logged temperatures and energy ledger', {'State vector', 'T (all states)', 'Energy ledger', 'Energy (absorbed, lost)'}, [0.95 0.98 0.94]});

note(m, [40 bottom + 30], sprintf(['Leaf collector, plain Simulink model.  Each store integrates C dT/dt = heat in - heat out (W).\n' 'Inputs: collector_inputs.m.  Run: run_collector.  Physics formulas: +collector package (single source).\n' 'Temperatures travel by Goto/From tags [T_absorber], [T_walls], ...; heat flows are the wires.']));
port_labels(m);
set_param(m, 'ShowLineDimensions', 'on');   % vector wires show their width (224, 32) after Ctrl+D
save_system(m, fullfile(here, [name '.slx']));
close_system(m, 0);
fprintf('Built %s\n', fullfile(here, [name '.slx']));
end


%% Store builders
% Every store uses one template, left to right: heat inputs stacked on rows row(k), the Net heat
% sum sized so its input k sits on row k (every input wire is straight), then 1/C, the
% integrator and T. Feedback terms computed from T (edge loss, loop loss, layer conduction)
% run in a lane underneath, as in a control block diagram.
function y = row(k)
% y = row(k): k row number(s) (double) -> y (px), the centre height of that input row.
y = 50 + 50*(k - 1);
end

function b = block(s, lib, name, box, varargin)
% b = block(s, lib, name, box, ...): adds library block lib as s/name at box [left top right
% bottom] (px), with extra name-value parameters; b char, the block path.
b = [s '/' name];
add_block(lib, b, 'Position', round(box), varargin{:});   % whole pixels: no half-pixel jogs in wires
end

function b = column(s, lib, name, x, w, ys, varargin)
% b = column(s, lib, name, x, w, ys, ...): a multi-input block (Sum, Mux, Concatenate) at left
% edge x, width w (px), whose n = numel(ys) inputs land on the heights ys (px, equally spaced).
% Simulink spaces n ports at (k - 1/2)/n of the block height, so height = n*pitch and
% top = ys(1) - pitch/2 put port k exactly at ys(k).
if isscalar(ys)
    pitch = 30;
else
    pitch = ys(2) - ys(1);
end
n = numel(ys);
top = ys(1) - pitch/2;
b = block(s, lib, name, [x top x+w top+n*pitch], varargin{:});
end

function b = centred(s, lib, name, x, w, h, y, varargin)
% b = centred(s, lib, name, x, w, h, y, ...): block at left edge x, size w x h, centred on height y (px).
b = block(s, lib, name, [x y-h/2 x+w y+h/2], varargin{:});
end

function xr = gain(s, name, x, y, value, varargin)
% xr = gain(s, name, x, y, value, ...): Gain block with expression value (char) at left edge x,
% centred on height y (px). Its width follows the expression, about 7 px per character at the
% default font plus the triangle's margins, so Simulink shows the expression rather than -K-.
% xr (px) is the right edge.
w = max(50, 7*numel(value) + 24);
centred(s, 'simulink/Math Operations/Gain', name, x, w, 30, y, 'Gain', value, varargin{:});
xr = x + w;
end

function s = subsys(m, name, pos, desc, eq)
% s = subsys(m, name, pos, desc, eq): m model name, name/desc/eq char, pos 1x4 double (px) ->
% s char, path of a new empty subsystem whose icon shows the balance equation eq ('\n' breaks
% lines). port_labels(m) adds the port names to the icon once the ports exist.
s = [m '/' name];
add_block('simulink/Ports & Subsystems/Subsystem', s, 'Position', pos);
delete_line(s, 'In1/1', 'Out1/1');
delete_block([s '/In1']);
delete_block([s '/Out1']);
set_param(s, 'Description', desc);
mk = Simulink.Mask.create(s);                    % no mask parameters: P and LP still resolve
mk.Display = sprintf('disp(sprintf(''%s''));', eq);   % from the base workspace
end

function inport(s, name, k, y)
% inport(s, name, k, y): adds Inport number k (double) called name (char), centred on height y (px), in subsystem s (char).
centred(s, 'simulink/Sources/In1', name, 30, 30, 14, y, 'Port', num2str(k));
end

function outport(s, name, k, y, x, facing)
% outport(s, name, k, y, x, facing): adds Outport number k called name, left edge x, centred on
% height y (px); facing 'right' (default) or 'left' for an output taken off a feedback row.
if nargin < 6
    facing = 'right';
end
centred(s, 'simulink/Sinks/Out1', name, x, 30, 14, y, 'Port', num2str(k), 'Orientation', facing);
end

function source(s, name, value, y)
% source(s, name, value, y): Constant block (value char expression) on the input column at height y (px).
centred(s, 'simulink/Sources/Constant', name, 20, 130, 24, y, 'Value', value);
end

function yc = heat_sum(s, signs, rows_y, x)
% yc = heat_sum(s, signs, rows_y, x): the 'Net heat' Sum with signs (char), input k on height
% rows_y(k) (px), left edge x (default 230). yc (px) is its centre height, where 1/C and the
% integrator go.
if nargin < 4
    x = 230;
end
column(s, 'simulink/Math Operations/Sum', 'Net heat', x, 30, rows_y, 'Inputs', signs, 'IconShape', 'rectangular');
yc = port_xy(s, 'Net heat/1', 'Outport');
yc = yc(2);  % the output port as placed (after rounding)
end

function xr = integrate(s, invC, ic, yc, x)
% xr = integrate(s, invC, ic, yc, x): s subsystem path; invC, ic char expressions (1/C gain,
% initial temperature); yc centre height, x left edge of the 1/C gain (default 300) (px).
% Adds 'Net heat' -> Gain 1/C -> Integrator on one line; the caller adds the 'Net heat' Sum.
% xr (px) is the integrator's right edge, where T leaves.
if nargin < 5
    x = 300;
end
xg = gain(s, '1 over C', x, yc, invC, 'Multiplication', 'Element-wise(K.*u)');
centred(s, 'simulink/Continuous/Integrator', 'Integrator', xg + 40, 30, 30, yc, 'InitialCondition', ic);
add_line(s, 'Net heat/1', '1 over C/1');
add_line(s, '1 over C/1', 'Integrator/1');
xr = xg + 70;
end

function link(s, pairs)
% link(s, pairs): pairs n-by-2 cell of 'Block/port' char; adds a smart-routed line for each row.
for k = 1:size(pairs, 1)
    add_line(s, pairs{k, 1}, pairs{k, 2}, 'autorouting', 'smart');
end
end

function lane(s, src, dst, y)
% lane(s, src, dst, y): wires output src to input dst ('Block/port' char) along a horizontal
% lane at height y (px): out of src to the right, down or up to the lane, back left, then into
% dst from its left. For feedback, where the smart router otherwise loops over the diagram.
ps = port_xy(s, src, 'Outport');
pd = port_xy(s, dst, 'Inport');
add_line(s, [ps; ps(1)+15, ps(2); ps(1)+15, y; pd(1)-15, y; pd(1)-15, pd(2); pd]);
end

function store_cover(m, name, pos, which)
% store_cover(m, name, pos, which): which 'outer' or 'inner' (char). Builds the cover-sheet store subsystem.
if strcmp(which, 'outer')
    s = subsys(m, name, pos, 'Outer cover sheet: C dT/dt = q_core + q_cover/2 - q_top', 'C dT/dt = q_core\n+ light/2 - q_top');
    ins = {'q core', 'q top'};
    C = '1/P.C_cover_outer';
else
    s = subsys(m, name, pos, 'Inner cover sheet: C dT/dt = q_gap + q_cover/2 - q_core', 'C dT/dt = q_gap\n+ light/2 - q_core');
    ins = {'q gap', 'q core'};
    C = '1/P.C_cover_inner';
end
inport(s, ins{1}, 1, row(1));
source(s, 'Light absorbed (half)', 'P.q_cover/2', row(2));
inport(s, ins{2}, 2, row(3));
yc = heat_sum(s, '++-', row(1:3));
link(s, {[ins{1} '/1'], 'Net heat/1'; 'Light absorbed (half)/1', 'Net heat/2'; [ins{2} '/1'], 'Net heat/3'});
xr = integrate(s, C, 'P.T0', yc);
outport(s, 'T', 1, yc, xr + 60);
add_line(s, 'Integrator/1', 'T/1');
end

function store_absorber(m, pos)
% store_absorber(m, pos): builds the absorber-plate store (light, gap, top, walls, backing, edge loss).
s = subsys(m, 'Absorber plate', pos, ['Aluminium plate + tape + paint + tee fittings, one temperature. ' 'C dT/dt = (q_solar - q_tube) - q_gap - q_top(no cover) - sum q_plate->walls - q_plate->backing - edge loss'], 'C dT/dt = light - gap - top\n- walls - backing - edge');
source(s, 'Light on the plate', 'P.q_solar - P.q_tube', row(1));
names = {'q gap', 'q top (no cover)', 'q plate to walls', 'q plate to backing'};
for k = 1:4
    inport(s, names{k}, k, row(k + 1));
end
yc = heat_sum(s, '+-----', row(1:6));
link(s, {'Light on the plate/1', 'Net heat/1'});
for k = 1:4
    link(s, {[names{k} '/1'], sprintf('Net heat/%d', k + 1)});
end
xr = integrate(s, '1/P.C_absorber', 'P.T0', yc);
outport(s, 'T', 1, yc, xr + 60);
add_line(s, 'Integrator/1', 'T/1');
% Feedback row: edge loss = edge_ua (T - room), into Net heat input 6 and out as q edge.
yf = row(8);
column(s, 'simulink/Math Operations/Sum', 'T minus room', 360, 20, yf + [-15 15], 'Inputs', '+-', 'IconShape', 'rectangular', 'Orientation', 'left');
centred(s, 'simulink/Sources/Constant', 'Room', 410, 80, 24, yf + 15, 'Value', 'P.ambient_c', 'Orientation', 'left');
gain(s, 'Edge conductance', 260, yf, 'P.edge_ua', 'Orientation', 'left');
outport(s, 'q edge', 2, yf, 120, 'left');
link(s, {'Integrator/1', 'T minus room/1';
    'Room/1', 'T minus room/2';
    'T minus room/1', 'Edge conductance/1';
    'Edge conductance/1', 'Net heat/6';
    'Edge conductance/1', 'q edge/1'});
end

function store_walls(m, pos)
% store_walls(m, pos): builds the tube-wall store (vector of LP.nw cells).
s = subsys(m, 'Tube walls', pos, ['One LDPE wall cell per water cell. ' 'C dT/dt = ga(Ta - Tw) - gf(Tw - Tq) + light landing on the pipes (footprint share)'], 'C dT/dt = q_plate - q_water\n+ light (per cell)');
inport(s, 'q plate to walls', 1, row(1));
inport(s, 'q walls to water', 2, row(2));
source(s, 'Light on the pipes', 'P.q_tube*LP.share', row(3));
yc = heat_sum(s, '+-+', row(1:3));
link(s, {'q plate to walls/1', 'Net heat/1'; 'q walls to water/1', 'Net heat/2'; 'Light on the pipes/1', 'Net heat/3'});
xr = integrate(s, '1./LP.Cwall', 'P.T0*ones(LP.nw,1)', yc);
outport(s, 'T walls', 1, yc, xr + 60);
add_line(s, 'Integrator/1', 'T walls/1');
end

function store_water(m, pos)
% store_water(m, pos): builds the tube-water store with upwind transport (vector of LP.nw cells).
s = subsys(m, 'Tube water', pos, ['Water cells in flow order (supply tiers, then the mirrored return). ' 'C dT/dt = gf(Tw - Tq) + mcp (T_upstream - Tq); the first cell is fed from the external water.'], 'C dT/dt = q_walls\n+ mcp (T_upstream - T)');
% Row 1: heat from the walls. Row 3: transport, built left to right from the upstream
% temperatures [T_external; T(1:end-1)] minus each cell's own T; the cell temperatures come
% back from the integrator along a lane under the store.
ya = row(1);
yt = row(3);
inport(s, 'q walls to water', 1, ya);
inport(s, 'T external', 2, yt - 15);
centred(s, 'simulink/Signal Routing/Selector', 'Upstream cells', 90, 50, 26, yt + 15, 'IndexOptions', 'Index vector (dialog)', 'Indices', '1:LP.nw-1', 'InputPortWidth', 'LP.nw');
column(s, 'simulink/Signal Routing/Vector Concatenate', 'Upstream', 170, 6, yt + [-15 15], 'NumInputs', '2');
column(s, 'simulink/Math Operations/Sum', 'Upstream minus cell', 220, 20, yt + [0 30], 'Inputs', '+-', 'IconShape', 'rectangular');
xg = gain(s, 'Flow m c_p', 270, yt + 15, 'P.mcp');
yc = heat_sum(s, '++', [ya yt + 15], xg + 30);
xr = integrate(s, '1./LP.Cwat', 'P.T0*ones(LP.nw,1)', yc, xg + 100);
centred(s, 'simulink/Signal Routing/Selector', 'Last cell', xr + 40, 40, 26, ya, 'IndexOptions', 'Index vector (dialog)', 'Indices', 'LP.nw', 'InputPortWidth', 'LP.nw');
outport(s, 'T water cells', 1, yc, xr + 120);
outport(s, 'T outlet', 2, ya, xr + 120);
link(s, {'q walls to water/1', 'Net heat/1';
    'T external/1', 'Upstream/1';
    'Upstream cells/1', 'Upstream/2';
    'Upstream/1', 'Upstream minus cell/1';
    'Upstream minus cell/1', 'Flow m c_p/1';
    'Flow m c_p/1', 'Net heat/2';
    'Integrator/1', 'T water cells/1';
    'Integrator/1', 'Last cell/1';
    'Last cell/1', 'T outlet/1'});
lane(s, 'Integrator/1', 'Upstream cells/1', row(5));
lane(s, 'Integrator/1', 'Upstream minus cell/2', row(5));
end

function store_external(m, pos)
% store_external(m, pos): builds the vessel + hoses store (one mixed temperature, loop loss).
s = subsys(m, 'External water', pos, ['Vessel and hoses, one mixed temperature. ' 'C dT/dt = mcp (T_outlet - Te) - loop_ua (Te - T_room)'], 'C dT/dt = mcp (T_outlet - T)\n- loop loss');
ya = row(1);
inport(s, 'T outlet', 1, ya);
column(s, 'simulink/Math Operations/Sum', 'Outlet minus vessel', 100, 20, ya + [0 30], 'Inputs', '+-', 'IconShape', 'rectangular');
gain(s, 'Flow m c_p', 150, ya + 15, 'P.mcp');
yc = heat_sum(s, '+-', [ya + 15, row(3)]);
xr = integrate(s, '1/P.C_external', 'P.T0', yc);
outport(s, 'T', 1, yc, xr + 60);
% Feedback row: loop loss = loop_ua (T - room), into Net heat input 2 and out as q loop.
yf = row(5);
column(s, 'simulink/Math Operations/Sum', 'Vessel minus room', 360, 20, yf + [-15 15], 'Inputs', '+-', 'IconShape', 'rectangular', 'Orientation', 'left');
centred(s, 'simulink/Sources/Constant', 'Room', 410, 80, 24, yf + 15, 'Value', 'P.ambient_c', 'Orientation', 'left');
gain(s, 'Loop conductance', 260, yf, 'P.loop_ua', 'Orientation', 'left');
outport(s, 'q loop', 2, yf, 120, 'left');
link(s, {'T outlet/1', 'Outlet minus vessel/1';
    'Outlet minus vessel/1', 'Flow m c_p/1';
    'Flow m c_p/1', 'Net heat/1';
    'Integrator/1', 'T/1';
    'Integrator/1', 'Outlet minus vessel/2';
    'Integrator/1', 'Vessel minus room/1';
    'Room/1', 'Vessel minus room/2';
    'Vessel minus room/1', 'Loop conductance/1';
    'Loop conductance/1', 'Net heat/2';
    'Loop conductance/1', 'q loop/1'});
end

function store_backing(m, pos)
% store_backing(m, pos): builds the EPS + Trespa layer store (vector of LP.nb layers, matrix conduction).
s = subsys(m, 'Backing (EPS + Trespa)', pos, ['EPS then the cart Trespa plate, each split into layers that store heat. ' 'Conduction plate -> layer 1 -> ... -> last layer -> underside air. Heat into the layers = Ab*Tb + G1*Ta (first) + G_air*T_room (last).'], 'C dT/dt = Ab T\n+ G1 Ta (layer 1)\n+ G_air T_room (last)');
% Rows 1-3 feed the store: plate into layer 1, underside air, conduction between layers (fed
% back from the integrator along a lane under the store). Rows 6 and 8 report the two
% boundary flows; T absorber reaches row 6 down a lane at x = 70, left of the input column
% (Underside air starts at x = 90 to leave it free).
inport(s, 'T absorber', 1, row(1));
gain(s, 'Plate into layer 1', 110, row(1), 'LP.e1G', 'Multiplication', 'Element-wise(K.*u)');
centred(s, 'simulink/Sources/Constant', 'Underside air', 90, 70, 24, row(2), 'Value', 'LP.bamb');
gain(s, 'Layer conduction', 110, row(3) + 40, 'LP.Ab', 'Multiplication', 'Matrix(K*u)');
yc = heat_sum(s, '+++', row(1:3));
xr = integrate(s, '1./LP.Cb', 'P.T0*ones(LP.nb,1)', yc);
xo = xr + 280;                                   % common outport column
outport(s, 'T layers', 1, yc, xo);
link(s, {'T absorber/1', 'Plate into layer 1/1';
    'Plate into layer 1/1', 'Net heat/1';
    'Underside air/1', 'Net heat/2';
    'Layer conduction/1', 'Net heat/3';
    'Integrator/1', 'T layers/1'});
lane(s, 'Integrator/1', 'Layer conduction/1', row(4) + 30);
% Reported flows, right of the integrator so the layer temperatures reach them down the same
% trunk as the conduction feedback.
y1 = row(6);
y2 = row(8);
centred(s, 'simulink/Signal Routing/Selector', 'Layer 1', xr + 40, 40, 26, y1 + 30, 'IndexOptions', 'Index vector (dialog)', 'Indices', '1', 'InputPortWidth', 'LP.nb');
column(s, 'simulink/Math Operations/Sum', 'Plate minus layer 1', xr + 110, 20, y1 + [0 30], 'Inputs', '+-', 'IconShape', 'rectangular');
gain(s, 'G1', xr + 150, y1 + 15, 'LP.Gb(1)');
outport(s, 'q plate to backing', 2, y1 + 15, xo);
centred(s, 'simulink/Signal Routing/Selector', 'Last layer', xr + 40, 40, 26, y2, 'IndexOptions', 'Index vector (dialog)', 'Indices', 'LP.nb', 'InputPortWidth', 'LP.nb');
centred(s, 'simulink/Sources/Constant', 'Room', xr, 80, 24, y2 + 45, 'Value', 'P.ambient_c');
column(s, 'simulink/Math Operations/Sum', 'Layer minus room', xr + 110, 20, y2 + [0 30], 'Inputs', '+-', 'IconShape', 'rectangular');
gain(s, 'G air', xr + 150, y2 + 15, 'LP.Gb(end)');
outport(s, 'q underside', 3, y2 + 15, xo);
pa = port_xy(s, 'T absorber/1', 'Outport');
pm = port_xy(s, 'Plate minus layer 1/1', 'Inport');
add_line(s, [pa; 70, pa(2); 70, pm(2); pm]);
link(s, {'Integrator/1', 'Layer 1/1';
    'Layer 1/1', 'Plate minus layer 1/2';
    'Plate minus layer 1/1', 'G1/1';
    'G1/1', 'q plate to backing/1';
    'Integrator/1', 'Last layer/1';
    'Last layer/1', 'Layer minus room/1';
    'Room/1', 'Layer minus room/2';
    'Layer minus room/1', 'G air/1';
    'G air/1', 'q underside/1'});
end


%% Links
function surface_link(m, pos)
% surface_link(m, pos): MATLAB Function block calling collector.surface_heat_flows; parameter P tunable.
b = [m '/Air gap, cover core, top loss'];
add_block('simulink/User-Defined Functions/MATLAB Function', b, 'Position', pos);
set_param(b, 'Description', ['Nonlinear surface heat flows from collector.surface_heat_flows: gap convection (Hollands-type ' 'correlation) + radiation, twinwall core conduction, and top loss by convection + radiation.']);
ch = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', b);
ch.Script = sprintf(['function [q_gap, q_core, q_top_cover, q_top_abs] = f(T_absorber, T_inner, T_outer, P)\n' '%% Heat flows (W) above the absorber; formulas in +collector/surface_heat_flows.m\n' '[q_gap, q_core, q_top_cover, q_top_abs] = collector.surface_heat_flows(T_absorber, T_inner, T_outer, P);\n']);
% Tunable: new parameter VALUES reuse the generated code (non-tunable forced a ~3.6 s
% code rebuild on every run with changed inputs, which dominated the validation fit).
d = find(ch, '-isa', 'Stateflow.Data', 'Name', 'P');
d.Scope = 'Parameter';
d.Tunable = true;
% Every temperature in and heat flow out is a scalar: declare it, so the sizes do not depend on
% the order in which Simulink propagates dimensions through the Goto/From tags.
for v = find(ch, '-isa', 'Stateflow.Data')'
    if ~strcmp(v.Name, 'P')
        v.Props.Array.Size = '1';
        v.DataType = 'double';
    end
end
end

function vector_link(m, name, pos, gname, summed)
% vector_link(m, name, pos, gname, summed): per-cell link q = LP.(gname) .* (T1 - T2); summed (logical) adds a total output.
if summed
    a = 'T absorber';
    b = 'T walls';
    s = subsys(m, name, pos, 'q = ga .* (T_absorber - T_walls), per cell; also the total leaving the plate', 'q = ga .*\n(T_absorber - T_walls)');
else
    a = 'T walls';
    b = 'T water';
    s = subsys(m, name, pos, 'q = gf .* (T_walls - T_water), per cell', 'q = gf .*\n(T_walls - T_water)');
end
inport(s, a, 1, row(1));
inport(s, b, 2, row(2));
column(s, 'simulink/Math Operations/Sum', 'Difference', 120, 20, row(1:2), 'Inputs', '+-', 'IconShape', 'rectangular');
yc = mean(row(1:2));
xg = gain(s, 'Conductance', 170, yc, ['LP.' gname], 'Multiplication', 'Element-wise(K.*u)');
outport(s, 'q per cell', 1, yc, xg + 110);
link(s, {[a '/1'], 'Difference/1'; [b '/1'], 'Difference/2'; 'Difference/1', 'Conductance/1'; 'Conductance/1', 'q per cell/1'});
if summed
    centred(s, 'simulink/Math Operations/Sum', 'Total', xg + 40, 30, 30, row(3), 'Inputs', '+', 'CollapseMode', 'All dimensions', 'IconShape', 'rectangular');
    outport(s, 'q total', 2, row(3), xg + 110);
    link(s, {'Conductance/1', 'Total/1'; 'Total/1', 'q total/1'});
end
end

function ledger(m, pos)
% ledger(m, pos): integrates absorbed light and total losses; output E = [absorbed; lost] (J).
s = subsys(m, 'Energy ledger', pos, ['Energy absorbed (light) and lost (top, edges, loop, underside), ' 'integrated so that absorbed - lost - stored can be checked (should be ~0).'], 'E = [ integral of light,\n integral of losses ]');
% Row 1: absorbed light. Rows 2-6: the five losses, summed and integrated on the Losses centre line.
source(s, 'Absorbed light', 'P.q_solar + P.q_cover', row(1));
names = {'q top (cover)', 'q top (no cover)', 'q edge', 'q loop', 'q underside'};
for k = 1:5
    inport(s, names{k}, k, row(k + 1));
end
column(s, 'simulink/Math Operations/Sum', 'Losses', 180, 30, row(2:6), 'Inputs', '+++++', 'IconShape', 'rectangular');
ylost = mean(row([2 6]));
centred(s, 'simulink/Continuous/Integrator', 'Absorbed energy', 260, 30, 30, row(1), 'InitialCondition', '0');
centred(s, 'simulink/Continuous/Integrator', 'Lost energy', 260, 30, 30, ylost, 'InitialCondition', '0');
column(s, 'simulink/Signal Routing/Mux', 'Ledger', 340, 5, [row(1) ylost], 'Inputs', '2');
outport(s, 'E', 1, mean([row(1) ylost]), 400);
for k = 1:5
    link(s, {[names{k} '/1'], sprintf('Losses/%d', k)});
end
link(s, {'Absorbed light/1', 'Absorbed energy/1';
    'Losses/1', 'Lost energy/1';
    'Absorbed energy/1', 'Ledger/1';
    'Lost energy/1', 'Ledger/2';
    'Ledger/1', 'E/1'});
end


%% Helpers
function port_labels(m)
% port_labels(m): appends a port_label command for every Inport and Outport to the icon of each
% masked subsystem at the top level, so the equation icon keeps the port names a plain subsystem
% shows. Reads the names from the ports themselves, so it holds for any port set.
for s = find_system(m, 'SearchDepth', 1, 'Mask', 'on', 'BlockType', 'SubSystem')'
    mk = Simulink.Mask.get(s{1});
    cmd = mk.Display;
    for kind = {'Inport', 'input'; 'Outport', 'output'}'
        for p = find_system(s{1}, 'SearchDepth', 1, 'BlockType', kind{1})'
            cmd = sprintf('%s\nport_label(''%s'', %s, ''%s'');', cmd, kind{2}, get_param(p{1}, 'Port'), get_param(p{1}, 'Name'));
        end
    end
    mk.Display = cmd;
end
end

function wire(m, src, dst)
% wire(m, src, dst): src/dst 'Block/port' char. Adds a routed line in model m. Unlabelled:
% the subsystem port names already say what each wire carries at both ends.
add_line(m, src, dst, 'autorouting', 'smart');
end

function [w, h, gap] = tag_size()
% [w, h, gap] = tag_size(): Goto/From block width and height, and clearance to the port (px).
% 110 px fits the longest tag, [q_top_absorber], at the default font.
w = 110;
h = 22;
gap = 25;
end

function xy = port_xy(m, port, kind)
% xy = port_xy(m, port, kind): port 'Block/k' char, kind 'Inport' or 'Outport' -> 1x2 double,
% the port's position on the canvas (px).
cut = find(port == '/', 1, 'last');
ph = get_param([m '/' port(1:cut-1)], 'PortHandles');
xy = get_param(ph.(kind)(str2double(port(cut+1:end))), 'Position');
end

function goto(m, src, tag, xy)
% goto(m, src, tag, xy): broadcasts output port src ('Block/port') under the local Goto tag
% (char). By default the Goto sits right of the port, centred on it, so its wire is straight;
% xy (1x2 double, px, optional) gives the top-left corner instead, for a port whose own wire
% channel is already in use; that Goto faces left, so its input is on the side nearest the
% channel and the wire does not wrap around the block.
[w, h, gap] = tag_size();
facing = 'left';
if nargin < 4
    p = port_xy(m, src, 'Outport');
    xy = [p(1) + gap, p(2) - h/2];
    facing = 'right';
end
b = [m '/Goto ' tag];
add_block('simulink/Signal Routing/Goto', b, 'GotoTag', tag, 'TagVisibility', 'local', 'ShowName', 'off', 'Orientation', facing, 'Position', [xy xy + [w h]]);
wire(m, src, ['Goto ' tag '/1']);
end

function from(m, tag, dst)
% from(m, tag, dst): picks up the Goto tag (char) with a From block placed left of input port
% dst ('Block/port'), centred on it, so its wire is straight. Several From blocks may read the
% same tag.
[w, h, gap] = tag_size();
p = port_xy(m, dst, 'Inport');
k = 1;
while getSimulinkBlockHandle(sprintf('%s/From %s %d', m, tag, k)) > 0
    k = k + 1;
end
name = sprintf('From %s %d', tag, k);
add_block('simulink/Signal Routing/From', [m '/' name], 'GotoTag', tag, 'ShowName', 'off', 'Position', [p(1) - gap - w, p(2) - h/2, p(1) - gap, p(2) + h/2]);
wire(m, [name '/1'], dst);
end

function bottom = areas(m, spec)
% bottom = areas(m, spec): spec n-by-3 cell {title char, member block names cellstr, 1x3 RGB}.
% Adds a titled background area around each group: the bounding box of the members plus every
% Goto/From wired to them, padded, with room for the title on top. Areas are drawn behind the
% blocks. bottom (double, px) is the lowest area edge, for placing the note below.
pad = 15;
title = 30;
bottom = 0;
for k = 1:size(spec, 1)
    box = [inf inf -inf -inf];
    for b = spec{k, 2}
        blk = [m '/' b{1}];
        box = grow(box, get_param(blk, 'Position'));
        for c = get_param(blk, 'PortConnectivity')'
            for n = [c.SrcBlock(:); c.DstBlock(:)]'
                if n > 0 && any(strcmp(get_param(n, 'BlockType'), {'Goto', 'From'}))
                    box = grow(box, get_param(n, 'Position'));
                end
            end
        end
    end
    box = box + [-pad, -pad - title, pad, pad];
    h = add_block('built-in/Area', [m '/' spec{k, 1}], 'Position', box);
    set_param(h, 'BackgroundColor', sprintf('[%g %g %g]', spec{k, 3}), 'FontSize', '12', 'FontWeight', 'bold');
    bottom = max(bottom, box(4));
end
end

function box = grow(box, pos)
% box = grow(box, pos): box, pos 1x4 double [left top right bottom] (px) -> their union.
box = [min(box(1:2), pos(1:2)), max(box(3:4), pos(3:4))];
end

function colour(m)
% colour(m): block colours by component, matching the areas; the gap/top-loss link is pale yellow, the vector links stay white.
c = {'Outer cover', '[0.80 0.89 1.00]';
    'Inner cover', '[0.80 0.89 1.00]';
    'Absorber plate', '[1.00 0.84 0.70]';
    'Tube walls', '[1.00 0.90 0.80]';
    'Tube water', '[0.78 0.92 0.96]';
    'External water', '[0.78 0.92 0.96]';
    'Backing (EPS + Trespa)', '[0.88 0.88 0.88]';
    'Energy ledger', '[0.86 0.94 0.84]';
    'Air gap, cover core, top loss', '[1.00 0.98 0.85]'};
for k = 1:size(c, 1)
    set_param([m '/' c{k, 1}], 'BackgroundColor', c{k, 2});
end
end

function note(m, xy, txt)
% note(m, xy, txt): xy 1x2 double (px), txt char. Adds a text annotation to model m.
a = Simulink.Annotation([m '/' 'note']);
a.Text = txt;
a.Position = [xy xy + [900 60]];
end
