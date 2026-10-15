# Solar collector model

A MATLAB and Simulink model of a covered aluminium plate with branching LDPE pipes. Lamp energy heats the plate and pipe walls, heat passes into the circulating water, and the collector loses heat through its cover, backing and external water loop. The model calculates how each part warms during a test.

Developed for TU/e course 4CBLB00, group 8.

## Run the model

Use MATLAB R2025b with Simulink. This version does not require Simscape. Earlier MATLAB releases have not been checked.

Open the repository folder in MATLAB and run:

```matlab
run_collector
```

The run writes [results/summary.md](results/summary.md), temperature and energy histories, and six figures. It checks solver accuracy, spatial resolution and energy conservation before replacing the results.

![Temperatures during the heating test](results/temperatures.png)

To change the collector or test conditions, edit [collector_inputs.m](collector_inputs.m), then run `run_collector` again. The comments give the units and recorded source of each input.

For vector PDF figures as well as PNG files:

```matlab
run_collector(PDF=true)
```

## Follow the calculation

| File or folder | Purpose |
|---|---|
| [collector_inputs.m](collector_inputs.m) | Geometry, material properties, heat-transfer assumptions and test conditions. |
| [run_collector.m](run_collector.m) | Run the model, check numerical accuracy and save the results. |
| [simulink/solar_collector.slx](simulink/solar_collector.slx) | Block diagram with a temperature state for each heat store. |
| [simulink/simulate_collector.m](simulink/simulate_collector.m) | Pass the inputs into Simulink and read its outputs. |
| [+collector/prepare_model.m](+collector/prepare_model.m) | Calculate water volumes, heat capacities and heat-transfer conductances. |
| [+collector/tube_wall_heat_transfer.m](+collector/tube_wall_heat_transfer.m) | Heat path from the plate, through the contact and pipe wall, into the water. |
| [+collector/line_contact_conductance.m](+collector/line_contact_conductance.m) | Contact of a bare round tube on the flat plate: air and radiation from the plate, conduction around the wall to the water. |
| [+collector/water_heat_transfer.m](+collector/water_heat_transfer.m) | Water-side heat-transfer coefficient in each pipe. |
| [+collector/surface_heat_flows.m](+collector/surface_heat_flows.m) | Convection and radiation across the air gap and to the room. |
| [+collector/cover_view_factor.m](+collector/cover_view_factor.m) | Fraction of diffuse light that crosses the finite opening. |
| [+collector/loop_heat_loss.m](+collector/loop_heat_loss.m) | Vessel and hose heat loss from their dimensions and thermal resistances. |
| [+collector/calculate_history.m](+collector/calculate_history.m) | Temperatures, stored energies and heat flows at each output time. |
| [+collector/check_model_limits.m](+collector/check_model_limits.m) | Check material limits, flow regimes and correlation assumptions. |
| [results/summary.md](results/summary.md) | Results, numerical checks and warnings from the saved run. |

MATLAB uses the `+collector` folder as a package: for example, `collector.prepare_model(c)` calls the function in `+collector/prepare_model.m`, using the input struct `c`.

The absorber state includes the plate, its paint and the tee fittings. Each pipe-water cell has a matching pipe-wall state, so the wall stores heat as well as resisting heat transfer. The vessel and hoses share one mixed-water temperature. Separate layers represent heat storage and conduction through the EPS insulation and supporting plate.

## Geometry and assumptions

`prepare_model` recalculates pipe bores, water volumes, wall masses, contact areas, heat capacities and pressure losses from the entered dimensions on every run. Changing the number of numerical cells divides the same mass and conductance among more cells.

The aperture is the clear opening inside the rim. Its dimensions are separate inputs from the whole plate and lid dimensions: the current 714 × 664 mm lid with 24 mm rim rails gives a 666 × 616 mm opening. Update the opening dimensions when changing the rim.

The diffuse view factor is the fraction of uniformly diffuse light that reaches the opposite opening across the air gap. `cover_view_factor` derives it from the opening length, width and gap, assuming aligned parallel rectangles and no recovery of light hitting the side walls. `prepare_model` combines this fraction with the direct beam, assumed normal to the opening, then applies the cover transmittance. Removing the cover bypasses both corrections. Thermal radiation between the absorber and inner cover separately uses the large-parallel-surface approximation, with a view factor of one and no side-wall exchange.

The vessel and hose dimensions set both water inventory and external heat loss. The default `heat.loop_ua = []` calculates their combined conductance in W/K each run. An explicit number overrides that calculation, including zero to switch this heat-loss route off. The vessel side is insulated, its end caps are bare, and all hoses use the entered common wall thickness. Vessel and hose solids have no separate heat-storage states.

The bare black tubes lie on the plate. With `heat.bond_per_length = []` the contact is derived each run from the smallest air gap (`heat.contact_gap_mm`, an estimate): air conduction below the tube and radiation from the plate feed the tube wall, and conduction around the wall to the water is solved numerically. The gap and the optical properties remain assumptions. The light over each tube footprint lands on the black tube itself, so all of it enters the tube wall.

## Saved design and results

The supplied inputs describe the built geometry: tubes with a 13 mm bore and an assumed 1 mm wall (15 mm outside diameter; the product weight, 2200 g per 50 m, gives about 1.1 mm), and a 28 mm plate-to-cover gap. The test uses 1000 W/m² irradiance and 1 L/min total flow for 30 minutes, starting at 20 °C.

The leaf starts at the first branches: the hoses go straight onto the two root tees, so no 60 mm trunk pieces were fitted (build photos, 10 Oct). The saved primary-model run gives an energy-weighted mean water temperature of **36.05 °C** after 30 minutes, so the vessel does not reach 40 °C. The plate reaches 74.3 °C: the bare-tube contact (0.84 to 0.96 W/(m·K), 2.70 W/K for all 3.04 m of tube) cannot carry its heat to the water. The mean includes water in the collector, hoses and vessel.

The first-branch Reynolds number is about 1023, so every tier is laminar. Every pipe is much shorter than its thermal entry length, and each tee mixes the water, so the film uses the Hausen developing-flow correlation (Nu 6.8 to 13.3).

The finish is the course plate's own black paint; its heat capacity and optical values in `collector_inputs.m` are estimates. Tee fittings retain a 4 g mass estimate and a polyolefin heat-capacity proxy, although the current fittings are printed PLA.

## Reference measurements

The [Intex temperature measurements](validation/data/intex_2024-07-03_temperatures.csv) contain elapsed time in seconds and inlet/outlet temperatures in °C. The [flow measurements](validation/data/intex_2024-07-03_flow_60s.csv) contain 60-second bin centres, mean flow in L/min and sample counts. Both files retain their source and extraction notes in their headers.

These measurements describe the Intex reference system on 3 July 2024. The files in `results/` are simulated results for the branching collector.

## Final test replay (13 October 2026)

[`validation/data/final_test_2026-10-13.txt`](validation/data/final_test_2026-10-13.txt) is the course recording of the built collector: inlet, outlet and vessel temperature (°C) and flow (L/min) at 1 Hz for 43.6 minutes, read at the cart sensors. The lamp was on from the first sample. All 2 L of water started in the vessel, with the collector and hoses empty. The joints at the printed tees leaked heavily, the first refill was pumped until the vessel ran dry, and later refills were topped up during the run. Steam from the leaked water fogged the covers.

The design model predicts a dry, sealed collector at a steady 1 L/min, which the test was not. The replay runs the same equations with the conditions of the test instead. The measured inlet temperature and flow drive the collector, through the hose between each sensor and the collector (about 118 mL and 0.68 W/K per side). The modelled outlet is compared with the outlet sensor. The vessel is not modelled, because the loop leaked. Three test conditions are added, and none is fitted:

- **Leak flow.** The first refill pumped 4.52 L until the vessel ran dry. The loop was empty at the start, and the air drawn in by the starving pump emptied it again at the end, so all 2 L was lost at the joints. That leaves 1 − 2.00/4.52 = 0.56 of the metered flow crossing the plate. The same share is assumed for the whole test.
- **Cart glass.** The test cart's glass cover above the lid has an energy transmittance of 0.87, the AGC datasheet value for 4 mm reduced-iron float glass (Planibel Clearlite). The thickness is unknown; ordinary to low-iron float spans 0.83–0.90.
- **Fogged covers.** Three surfaces in the light path carried condensed droplets: the underside and top of the polycarbonate lid, and the underside of the cart glass. The room side of the glass stayed dry. Zhu et al. (2017) give the transmittance of a window with droplets on its back as a function of the droplet contact angle and coverage (their Fig. 7a). Uncoated polycarbonate has a contact angle of about 74° (Karabulut et al. 2025), which gives 0.77 of the dry value at 60 % droplet coverage. Unclean glass, at about 51° (Briscoe and Galvin, reviewed by Zhu et al.), gives 0.92 at the same coverage. Clean glass, on which water spreads flat, loses only 1–9 % (Pollet et al. 1999). The beaded droplets seen on the cart glass after the test point to the unclean case.

The light reaching the plate is then 0.87 × 0.77² × 0.92 = 0.48 of the design value. With these conditions, the model reproduces the measured outlet within 2.3 K RMS and ends 0.8 K above it. At 90 % droplet coverage (polycarbonate 0.66, glass 0.88), it ends about 5 K below it. From minute 19 onwards, the measured outlet lies between the two. With the design inputs, the model misses by 13.9 K. Leakage at the printed tees and the fogging it caused explain the test result. The design prediction for a dry, sealed collector was not tested.

The replay script is kept with the local verification work, like the Intex fit.

## Change the block diagram

The block diagram is generated from [simulink/build_collector_model.m](simulink/build_collector_model.m). Edit that file when changing the model structure, then rebuild:

```matlab
addpath simulink
build_collector_model
```

Changing values in `collector_inputs.m` does not require rebuilding the diagram.

## Numerical checks

`run_collector` repeats the calculation with a tenfold tighter solver tolerance, then with twice as many pipe-water cells and backing layers. Each refinement must change the checked temperatures by less than 0.01 K. The difference between absorbed, lost and stored energy must be less than one millionth of the absorbed energy.

These checks establish numerical consistency. The operating-limit checks separately report when a material limit or heat-transfer assumption is exceeded.
