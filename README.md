# ORFS gcd: exploring core utilization and clock period (Nangate45 and SKY130HD)

A hands-on physical design project with OpenROAD-flow-scripts (ORFS): run the full RTL-to-GDS flow on the sample design gcd, read the logs, reports and GUI, then change one parameter at a time (`CORE_UTILIZATION`, clock period) to measure the effect on area, wirelength, timing, power and DRC. Done over six working sessions 

A detailed log of every command and measurement is in [`LOG.md`](LOG.md).

## Status

- Week 1 (done): gcd on Nangate45 and SKY130HD, with two sweeps (core utilization and clock period).
- Week 2 onward (not started): put a small CPU core through the same flow. The repo currently contains no CPU; every result below is for gcd, a sample design shipped with ORFS.

ORFS, the gcd design, and the Nangate45 and SKY130HD libraries belong to other open projects. What this repo adds is the runs, the measurements and the notes.

## Main results

Every number is a single run per data point, so very small differences (for example 0.01 ns of WNS) are not enough to draw conclusions.

1. Slack barely depends on utilization. For gcd/Nangate45 at a 0.25 ns period, WNS is -0.16 ns (util 30) and -0.17 ns (util 55); slack is already negative at floorplan (-0.15 ns).
2. Slack is set by the clock period. The critical path of gcd on Nangate45 is about 0.42 ns (period minus WNS); timing closes from a 0.45 ns period.
3. A period tighter than the circuit can achieve raises cost without closing timing. 0.25 ns vs 0.45 ns: final cell area 911 vs 685 um^2, power 3.85 vs 1.67 mW, timing-repair buffers 154 to 178 vs 65.
4. Too high a utilization makes the flow fail. At util 70 the flow stops at `4_1_cts` with `DPL-0033`: `repair_timing` adds buffers, the core is 99.5% full, and legalization does not converge. The limit lies between 60 and 70.
5. The same RTL gives very different results in the two technologies. SKY130HD is about 3.7x larger after synthesis and its achievable period is about 5 to 6 times longer than Nangate45 (rough estimate, one run each); SKY130 closes timing at 2.5 ns.

### Experiment A: CORE_UTILIZATION sweep (Nangate45, 0.25 ns period)

| CORE_UTILIZATION | Core (um^2) | Final cells (um^2) | WNS (ns) | TNS | DRC | Wire (um) | Power | Run time |
|---|---|---|---|---|---|---|---|---|
| 30 | 2034.37 | 905 (44%) | -0.16 | -6.92 | 0 | 4172 | 3.86 mW | 27 s |
| 55 (default) | 1076.77 | 911 (85%) | -0.17 | -7.22 | 0 | 4421 | 3.85 mW | 110 s |
| 70 | | | failed at CTS (`DPL-0033`) | | | | | |

### Experiment B: clock period sweep (Nangate45, utilization 55)

| Period (ns) | WNS (ns) | TNS | DRC | Final cells (um^2) | Wire (um) | Power (mW) | Run time |
|---|---|---|---|---|---|---|---|
| 0.20 | -0.21 | -9.34 | 0 | 875 (81%) | 4055 | 4.67 | not recorded |
| 0.25 | -0.17 | -7.22 | 0 | 911 (85%) | 4421 | 3.85 | 110 s |
| 0.35 | -0.07 | -2.90 | 0 | 913 (85%) | 4656 | 2.78 | 65 s |
| 0.45 | 0.00 | 0.00 | 0 | 685 (64%) | 3521 | 1.67 | 35 s |

### Nangate45 vs SKY130HD

| Metric | Nangate45 (0.25 ns) | SKY130HD (1.1 ns) | SKY130HD (2.5 ns) |
|---|---|---|---|
| CORE_UTILIZATION | 55 | 38 | 38 |
| Area after synthesis (um^2) | 626.70 | 2313.47 | 2313.47 |
| Final cells (um^2) | 911 (85%) | 4380 (74%) | 3744 (64%) |
| WNS / TNS | -0.17 / -7.22 | -1.26 / -56.04 | 0.00 / 0.00 |
| DRC | 0 | 0 | 0 |
| Power | 3.85 mW | 5.52 mW (1.8 V) | 2.10 mW |
| Estimated achievable period | about 0.42 ns | about 2.36 ns | met at 2.5 ns |

## Environment

- VMware, Ubuntu 26.04.1 (12 GB RAM, 4 CPUs, 60 GB disk), Docker (`docker.io`), image `openroad/orfs`.
- ORFS cloned from https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts (full clone).
- Designs: `gcd` on `nangate45` and `sky130hd` (both shipped in `flow/designs`).

## Setting up the environment

```bash
sudo apt update
sudo apt install -y docker.io git
sudo usermod -aG docker $USER      # log out and back in
docker run hello-world

cd ~
git clone https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts.git
cd OpenROAD-flow-scripts
```

The script `runorfs.sh` is in this repo. It starts the ORFS container with the host's `flow/` directory mounted, so result files stay on the host. Put it in the root of the ORFS clone. This version drops the line from the original tutorial that mounts `${HOME}/.Xauthority`: on Ubuntu running Wayland that file does not exist, Docker creates it as a directory, and the GUI fails with an `xcb` error.

```bash
chmod +x runorfs.sh
xhost +local:        # outside the container, only needed to open the GUI
./runorfs.sh         # enter the container
cd flow
```

## Re-running the experiments

Run inside the container, in the `flow` directory. `make` only works inside the container; `grep`, `cp` and `wc` also work outside because the directory is shared.

### Default flow (gcd on nangate45)

```bash
time make 2>&1 | tee run1.log
find results -name 6_final.gds
make clean_cts                       # delete everything from CTS onward
make 2>&1 | tee run2.log             # re-runs from CTS only
diff run1.log run2.log
make clean_all
```

### CORE_UTILIZATION sweep (replace 30 with 55, 70)

```bash
CFG=./designs/nangate45/gcd/config.mk
make DESIGN_CONFIG=$CFG clean_all
make DESIGN_CONFIG=$CFG CORE_UTILIZATION=30 2>&1 | tee exp_util_30.log
mkdir -p exp/util_30 && cp -r logs/nangate45/gcd/base exp/util_30/logs && cp -r reports/nangate45/gcd/base exp/util_30/reports && cp -r results/nangate45/gcd/base exp/util_30/results
grep -niE "core area|die area|utilization" exp/util_30/logs/2_1_floorplan.log
grep -HE "^(tns|wns|worst slack)" exp/util_30/reports/*.rpt
wc -l exp/util_30/reports/5_route_drc.rpt        # 0 = no DRC violations
```

`config.mk` has `CORE_UTILIZATION ?= 55`, so a value on the command line overrides it. At 70 the flow stops at CTS, so only logs and reports are backed up.

### Clock period sweep (replace 0.35 with 0.20, 0.45)

```bash
SDC=designs/nangate45/gcd/constraint.sdc
cp $SDC $SDC.orig                                         # do this once
sed -i 's/^set clk_period .*$/set clk_period 0.35/' $SDC
grep -n "set clk_period" $SDC                             # check the change
make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk 2>&1 | tee exp_period_0.35.log
mkdir -p exp/period_0.35 && cp -r logs/nangate45/gcd/base exp/period_0.35/logs && cp -r reports/nangate45/gcd/base exp/period_0.35/reports && cp -r results/nangate45/gcd/base exp/period_0.35/results
grep -HE "^(tns|wns|worst slack)" exp/period_0.35/reports/*.rpt
wc -l exp/period_0.35/reports/5_route_drc.rpt
make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk clean_all
# when all runs are done: cp $SDC.orig $SDC
```

### SKY130HD (default period 1.1 ns, then 2.5 ns)

```bash
make DESIGN_CONFIG=./designs/sky130hd/gcd/config.mk 2>&1 | tee run_sky130.log
mkdir -p exp/sky130_default && cp -r logs/sky130hd/gcd/base exp/sky130_default/logs && cp -r reports/sky130hd/gcd/base exp/sky130_default/reports && cp -r results/sky130hd/gcd/base exp/sky130_default/results
grep -HE "^(tns|wns|worst slack)" exp/sky130_default/reports/*.rpt
tail -n 25 exp/sky130_default/reports/synth_stat.txt     # synthesis statistics
# change the period to 2.5 with the same sed command as above, on designs/sky130hd/gcd/constraint.sdc
```

### GUI

```bash
make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk gui_final
```

In the GUI: Timing Report (Setup, Hold), Clock Tree Viewer, and the Tcl scripting pane (`report_cell_usage`, `puts [llength [[ord::get_db_block] getInsts]]`).

## Repository layout

```
.
├── README.md
├── LOG.md                  per-day log with every command and measurement
├── runorfs.sh              container launch script
├── exp_*.log, run_*.log    logs of the flow runs
└── exp/
    ├── util_30, util_55, util_70
    ├── period_0.20, period_0.35, period_0.45
    └── sky130_default, sky130_2.5
```

Each `exp/<name>` directory holds a copy of `logs/` and `reports/` from the matching run. The 0.25 ns run is `exp/util_55`. Heavy files (`*.odb`, `*.gds`, the `results/` and `objects/` directories) can be regenerated, so they are not in the repo (see `.gitignore`). Data from the first trial runs (util 30, 45, 60) is not in the repo; the 30 and 55 runs were redone and are in `exp/`.

## Limitations

- Each data point was run once; run-to-run variation was not measured.
- Hold slack versus period was not measured (the `*.rpt` reports only contain setup slack).
- Congestion was not examined, so why wires get longer in a tighter core is not explained yet.
- The utilization limit between 60 and 70 was not narrowed; the smallest achievable period on SKY130 (between 2.36 and 2.5 ns) was not swept finely.
- Not explained yet: why area at 0.20 ns is smaller than at 0.25 ns, and why Yosys picked the Han-Carlson adder instead of the smaller Brent-Kung on SKY130.

## Future work

- Run each point several times and sweep more finely (util 60 to 70, SKY130 period 2.2 to 2.5 ns).
- Measure hold slack versus period with `report_worst_slack -min`.
- Put a design of my own (for example a small CPU) through ORFS using the same procedure.

## References

- OpenROAD-flow-scripts: https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts
- ORFS documentation: https://openroad-flow-scripts.readthedocs.io
