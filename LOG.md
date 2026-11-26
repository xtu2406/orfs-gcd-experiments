# LOG: ORFS hands-on, week 1

How to read this log:

- **Measurements** are numbers taken directly from a log or report. **Explanations** are reasoning that has not been verified further.
- Commands for days 5 and 6 are numbered in the order they were actually run (Step 1 to 65). Commands for days 1 to 4 come from the week 1 tutorial; any command not confirmed as run is marked *(per tutorial)*.
- Predictions written before running were not saved, so this log has no comparison against predictions.
- The prompt `ubuntu@...:/OpenROAD-flow-scripts/flow$` is inside the container; `user@...:~/OpenROAD-flow-scripts/flow$` is outside. `make` must run inside the container; `grep`, `cp` and `wc` work in both places because the directory is shared.

---

## Day 1: environment setup

**Goal:** Ubuntu with a working Docker, and the ORFS container opening.

**Machine:** VMware, Ubuntu 26.04.1, 12 GB RAM, 4 CPUs, 60 GB disk.

**Commands**
```
nproc                                   # CPU cores (per tutorial)
free -h                                 # RAM (per tutorial)
df -h /                                 # disk space (per tutorial)
sudo apt update
sudo apt install -y docker.io           # run
sudo usermod -aG docker $USER           # run Docker without sudo (per tutorial)
docker --version
docker run hello-world                  # run, succeeded
sudo apt install -y git                 # run (forgot sudo the first time, permission error)
git --version
cd ~
git clone https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts.git
cd OpenROAD-flow-scripts
cat > runorfs.sh <<'EOF' ... EOF        # create the container launch script (see runorfs.sh in the repo)
chmod +x runorfs.sh
./runorfs.sh
cd flow
ls
```

**Meaning:** `docker.io` is Docker from the Ubuntu repository; `hello-world` checks that Docker works; `git clone` (full, not `--depth 1`) downloads ORFS; `runorfs.sh` runs `docker run` with the host's `flow/` directory mounted into the container so result files stay on the host.

**Error:** forgot `sudo` when installing git; it worked with `sudo`.

**Result:** Docker `hello-world` runs.

---

## Day 2: default flow, gcd on nangate45

**Goal:** run RTL-to-GDS once and understand that the flow runs in stages and `make` only runs what is missing.

**Commands** (inside the container, `flow` directory)
```
./runorfs.sh
cd flow
time make 2>&1 | tee run1.log
ls results/nangate45/gcd/base
ls logs/nangate45/gcd/base              # (per tutorial)
ls reports/nangate45/gcd/base           # (per tutorial)
find results -name 6_final.gds
make clean_cts
make 2>&1 | tee run2.log
diff run1.log run2.log
make clean_all                          # keep the full run1.log
```

**Meaning:** `make` without `DESIGN_CONFIG` uses the ORFS default configuration (gcd on nangate45). `2>&1 | tee` merges errors into the output, prints it and saves it to a file. `clean_cts` deletes results from CTS onward.

**Results**

| Item | Result |
|---|---|
| Run 1 time | 2m5.919s |
| GDS file | `results/nangate45/gcd/base/6_final.gds` |
| Run 2 time (after `clean_cts`) | 1m24.714s |

**Observation:** `run2.log` is shorter because make skips synthesis, floorplan and placement and only re-runs from CTS. Run 2 still takes long because routing and the steps after CTS take most of the time.

**Understood:** the flow runs in stages, each stage reads the files of the previous one; make only re-runs what was deleted.

**Errors:** none.

**Self-check question:** why does `make` not re-run synthesis when only CTS onward is deleted? Because `make` compares result files with each other: the synthesis, floorplan and placement files still exist and are not older than their inputs, so those steps count as done. Only the files from CTS onward were deleted, so only that part is redone.

---

## Day 3: reading the log and report of each stage

**Goal:** know which files each stage leaves behind and which log to open to see what it did.

**Commands** (per tutorial)
```
ls -l results/nangate45/gcd/base
ls -l logs/nangate45/gcd/base
ls -l reports/nangate45/gcd/base
less logs/nangate45/gcd/base/4_1_cts.log
less reports/nangate45/gcd/base/synth_stat.txt
grep -ci warning logs/nangate45/gcd/base/*.log
grep -ci error logs/nangate45/gcd/base/*.log
```
The end-of-flow numbers (TNS, WNS, DRC) come from `6_finish.rpt` and `5_route_drc.rpt`; the exact commands used to read these files on day 3 were not kept, but the same kind of command was reused on day 5 (`grep -HE "^(tns|wns|worst slack)" ...`, `wc -l ...`).

### Time per stage (`logs/nangate45/gcd/base`)

| Stage | Log files | Time (seconds) |
|---|---|---|
| Synthesis | 1_1_yosys_canonicalize.log, 1_2_yosys.log, 1_synth.log | 2 |
| Floorplan | 2_1_floorplan.log to 2_4_floorplan_pdn.log | 13 |
| Placement | 3_1_place_gp_skip_io.log to 3_5_place_dp.log | 8 (3_3: 5, 3_4: 2, 3_5: 1) |
| CTS | 4_1_cts.log | 0 in the summary table; the log says `repair_timing` took 18 seconds |
| Routing | 5_1_grt.log, 5_2_route.log, 5_3_fillcell.log | 47 (5_1: 17, 5_2: 30) |
| Final | 6_1_fill.log, 6_1_merge.log, 6_report.log | 0 |

### Warnings and errors
- Errors: 0 in every log.
- Warnings: 78 lines in total; most in `5_1_grt.log` (23), `4_rsz_lec.log` and `6_final_lec.log` (16 each), `1_1_yosys_canonicalize.log` (9). This counts lines containing the word warning, not distinct warnings.
- `STA-0450`: the virtual clock `vclk_core_clock` cannot be propagated (a virtual clock used for input/output delay in the SDC, harmless).
- `RSZ-0104` (many lines): nets `_487_`, `_486_`... have only one pin.

### Synthesis (`reports/nangate45/gcd/base/synth_stat.txt`)
- 513 cells, area 626.696 um^2.
- Flip-flops: 35 `DFF_X1`, 158.27 um^2, 25.25% (the sequential part).
- Most common cells: `NAND2_X1` (161), `INV_X1` (78), `NAND3_X1` (41).
- The 35 flip-flops match exactly the 35 CTS sinks reported later.

### CTS (`4_1_cts.log`)
- Clock tree `clk`: 35 sinks, H-tree, `CLKBUF_X3` buffers; 5 clock buffers, 5 clock nets, 2 levels deep; buffers on a clock path: minimum 2, maximum 2.
- Average wire length to sinks 45.06 um; CTS runtime 0.94 s. The log does not print skew (use `report_clock_skew` to see it).
- `repair_timing` after CTS: initially 52 endpoints violating setup (WNS -0.161, TNS -7.2); after repair 51 endpoints (WNS -0.156, TNS -6.9). 94 cells resized, 6 buffers inserted, 13 cells with pin swaps, 1 cell cloned; area up 10.1%. Warning `RSZ-0062`: setup violations not fully repaired. No hold violations.
- Area after CTS 878 um^2, density 81% (74% before timing repair).

### End-of-flow results
- Setup: TNS -7.22, WNS -0.17, worst slack -0.17 (ns). DRC: `5_route_drc.rpt` has 0 lines.
- Compared with after CTS (WNS -0.156, TNS -6.9), slack is slightly worse after routing (explanation: real wires have parasitic resistance and capacitance).

### Takeaway
- With the default configuration, gcd/nangate45 does not meet setup timing even though DRC is clean. Days 5 and 6 investigate why.

### Questions
- Why does area grow from 626.7 (synthesis) to 878 um^2 (after CTS)? Answered on day 4.
- Why does the summary table say CTS took 0 seconds while `repair_timing` took 18 seconds? Still open (the table may only measure the tree-building step, 0.94 s; not verified).

---

## Day 4: opening the GUI, reading timing, clock tree, cell counts

**Goal:** look at the result visually: worst setup/hold paths, the clock tree, and cell counts by type.

### GUI problem and fix
**Error:** `gui_final` read the design but showed no window; the log had `Could not load the Qt platform plugin "xcb"`.

```
make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk gui_final     # first time: xcb error
echo $XDG_SESSION_TYPE $DISPLAY      # outside the container: prints "wayland :0"
ls -ld ~/.Xauthority                 # leading d: it is a directory owned by root
ls /tmp/.X11-unix                    # X0 and X1 exist
sudo rmdir ~/.Xauthority
sed -i '/Xauthority/d' runorfs.sh
xhost +local:                        # outside the container
./runorfs.sh                         # enter the container again
make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk gui_final     # GUI opens
```

**Cause:** `runorfs.sh` mounted `${HOME}/.Xauthority` into the container; the file did not exist, so Docker created it as a directory and the container could not connect to the display.
**Lesson:** the prompt `ubuntu@...` is inside the container; `xhost` and editing the script are done outside the container.

### GUI actions
- Timing Report, Setup and Hold tabs; Clock Tree Viewer.
- Tcl in the Scripting pane: `puts [llength [[ord::get_db_block] getInsts]]` (988 instances), `report_cell_usage`.
- `report_worst_slack`, `report_tns`, `report_wns`, `report_clock_skew` *(per tutorial; results not recorded)*. `report_clock_skew` was not run, so there is no whole-tree skew figure; the skew of the critical path (0.001) comes from the Timing Report.

### Setup tab
- Worst setup path: slack -0.166, required 0.291, arrival 0.457 (ns), skew only 0.001; launched from `dpath.a_reg.out[7]` (DFF_X1), through `INV_X2`, `NAND2_X4`... to the capturing flip-flop; clock network delay 0.072.
- Skew is near 0, so the negative slack comes from a data path that is too slow, not from clock skew.

### Hold tab
- Worst hold path: slack +0.086 (no violation), required 0.082, arrival 0.168, skew -0.072; from input port `req_msg[13]` (through `input5`, `BUF_X1`) into `dpath.b_reg.out[13]`.
- Skew is -0.072 because the input port does not go through the clock tree while the flip-flop receives its clock 0.072 late.
- For flip-flop to flip-flop paths, hold has no period term so it does not change with the period; for paths from input ports, the input delay is 20% of the period so hold slack can change.

### Clock Tree Viewer
- 1 source, 1 buffer, then 4 buffers at the lower level; 5 buffers in total, 2 levels, matching the CTS log; sink groups around 0.07 ns, so the tree is fairly balanced.

### Cell counts (988 instances, 1076.77 um^2)

| Cell type | Count | Area (um^2) |
|---|---|---|
| Fill cell | 271 | 165.98 |
| Tap cell | 46 | 12.24 |
| Clock buffer | 5 | 6.65 |
| Timing Repair Buffer | 164 | 160.66 |
| Inverter | 86 | 58.52 |
| Clock inverter | 3 | 2.13 |
| Timing Repair Inverter | 1 | 2.39 |
| Sequential cell | 35 | 158.27 |
| Multi-input combinational | 377 | 509.92 |

- Sequential cells are still 35, 158.27 um^2, exactly as in synthesis.
- The rise from 513 cells (synthesis) to 988 is mainly fill (271), timing repair buffers (164) and tap cells (46): this answers the area question from day 3.
- Unverified guess: the 3 clock inverters are CTS dummy loads.

### Open questions
- Which step do the 164 timing repair buffers come from (repair_timing, the resizer, or IO port buffers)? The day 6 numbers suggest most come from timing repair (65 buffers at a relaxed period versus 154 to 178 at a tight period), but this was not separated out.
- Where should one act on the worst setup path (skew 0.001, slack -0.166)? Since skew is near 0, the fix is in the data path and the period, not the clock. Two concrete options: (1) relax the clock period (experiment B shows gcd meets timing from about 0.45 ns); (2) shorten the data path by upsizing or swapping in faster cells and inserting buffers; `repair_timing` already did part of this but did not fix everything at a 0.25 ns period.

---

## Day 5: experiment A, CORE_UTILIZATION sweep

**Goal:** change one parameter (`CORE_UTILIZATION`), keep everything else fixed, and measure the effect on area, wirelength, timing, DRC and run time.

### First trial run (moved to `exp_old_30_45_60`)
Run with the loop from the tutorial using 30, 45, 60:
```
CFG=./designs/nangate45/gcd/config.mk
for u in 30 45 60; do
  make DESIGN_CONFIG=$CFG clean_all
  time make DESIGN_CONFIG=$CFG CORE_UTILIZATION=$u 2>&1 | tee exp_util_$u.log
  mkdir -p exp/util_$u
  cp -r logs/nangate45/gcd/base exp/util_$u/logs
  cp -r reports/nangate45/gcd/base exp/util_$u/reports
  cp -r results/nangate45/gcd/base exp/util_$u/results
done
grep -rniE "wns|tns|worst slack" exp/util_45/reports exp/util_45/logs | head -20
```
util_45 numbers after CTS: WNS -0.16, TNS -7.14 (`head -20` cut off the end-of-flow numbers). Core of the old runs: 2034.4 (30), 1348.6 (45), 989.0 (60) um^2, confirming that `CORE_UTILIZATION` on the command line overrides `config.mk`.

### Re-running one command at a time

| Step | Command | Note |
|---|---|---|
| 1 | `cat designs/nangate45/gcd/config.mk` | `CORE_UTILIZATION ?= 55`, `PLACE_DENSITY_LB_ADDON = 0.20`, SDC in `constraint.sdc` |
| 2 | (no command) | wrote predictions |
| 3 | `mv -n exp exp_old_30_45_60` | move old results aside, no overwrite |
| 4 | `mv -n exp_util_30.log exp_util_45.log exp_util_60.log exp_old_30_45_60/` | move old logs aside |
| 5 | `make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk clean_all` | clean up |
| 6 | `make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk CORE_UTILIZATION=30 2>&1 \| tee exp_util_30.log` | ran 27 s |
| 7 | `mkdir -p exp/util_30 && cp -r logs/nangate45/gcd/base exp/util_30/logs && cp -r reports/nangate45/gcd/base exp/util_30/reports && cp -r results/nangate45/gcd/base exp/util_30/results` | backup |
| 8 | `grep -niE "core area\|die area\|utilization" exp/util_30/logs/2_1_floorplan.log` | core 2034.368 um^2 (run outside the container) |
| 9 | `grep -HE "^(tns\|wns\|worst slack)" exp/util_30/reports/*.rpt` | WNS -0.16, TNS -6.92 |
| 10 | `wc -l exp/util_30/reports/5_route_drc.rpt` | 0 |
| 11 | `./runorfs.sh` (run in the directory containing the script) | back into the container |
| 12 | `make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk clean_all` | clean up the 30 run |
| 13 | `make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk CORE_UTILIZATION=55 2>&1 \| tee exp_util_55.log` | ran 110 s |
| 14 | `mkdir -p exp/util_55 && cp -r logs/nangate45/gcd/base exp/util_55/logs && cp -r reports/nangate45/gcd/base exp/util_55/reports && cp -r results/nangate45/gcd/base exp/util_55/results` | backup |
| 15 | `grep -HE "^(tns\|wns\|worst slack)" exp/util_55/reports/*.rpt` | WNS -0.17, TNS -7.22 |
| 16 | `wc -l exp/util_55/reports/5_route_drc.rpt` | 0 |
| 17 | `make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk clean_all` | clean up the 55 run |
| 18 | `make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk CORE_UTILIZATION=70 2>&1 \| tee exp_util_70.log` | failed at `4_1_cts` |
| 19 | `mkdir -p exp/util_70 && cp -r logs/nangate45/gcd/base exp/util_70/logs && cp -r reports/nangate45/gcd/base exp/util_70/reports` | logs and reports only (no results) |
| 20 | (no command) | wrote the conclusion of experiment A |

Note: the floorplan log `grep` (step 8) was only run for the 30 run; the core of the 55 run comes from the end-of-flow report.

### Results (gcd, nangate45, 0.25 ns period)

| CORE_UTILIZATION | Core (um^2) | Final cells (um^2) | WNS (ns) | TNS | DRC | Wire (um) | Vias | Power | Run time |
|---|---|---|---|---|---|---|---|---|---|
| 30 | 2034.37 | 905 (44%) | -0.16 | -6.92 | 0 | 4172 | 3530 | 3.86 mW | 27 s |
| 55 | 1076.77 | 911 (85%) | -0.17 | -7.22 | 0 | 4421 | 3809 | 3.85 mW | 110 s |
| 70 | | | failed at CTS | | | | | | |

**Observations (measurements)**
- Run 30: effective utilization 0.308; cell area at end of floorplan 664 um^2 (33%), end of flow 905 um^2 (44%) because the flow adds buffers.
- Final cell area is almost the same (905 and 911); what differs is the core size, so final utilization reaches 85% in the 55 run.
- Fillers: 734 (run 30), 271 (run 55). Timing Repair Buffers: 165 and 164. Routing: 8 s and 45 s. Worst IR drop VDD: 4.56 mV and 7.47 mV.
- Slack at floorplan is already -0.15 in both runs, and only gets 0.01 to 0.02 worse afterwards.
- Run 70: `DPL-0033` at `4_1_cts`. `repair_timing` adds 4 buffers, upsizes 90 cells, clones 2 cells, area up about 9.5%; then `DPL-0009` reports 99.5% utilization, legalization does not converge (`DPL-0701`, 14 cells wrong), 7 cells overlap; `RSZ-0062` (slack stuck at -0.156). The utilization limit lies between 60 (which ran in the earlier trial) and 70.

**Explanation (not verified further)**
- Slack barely changes with utilization; most of the negative slack is already there at floorplan, so the main suspect is the tight clock period (checked in experiment B).
- A WNS difference of 0.01 ns is close to the report resolution and each level was run once, so no firm conclusion.
- Longer wires in the 55 run: hypothesis is that a tight core makes the router detour; no congestion data yet.

**Conclusion of experiment A**
- Raising utilization shrinks the core but leaves cell area almost unchanged, so final density is higher (44% to 85%), routing is slower (8 s to 45 s) and wires are slightly longer; timing is almost unchanged because it is set by the clock period. At 70 the flow fails because the core has no room left for timing-repair buffers.

**Open questions:** why are wires longer when the core is tighter (check congestion in `5_1_grt.log`)? The exact limit between 60 and 70 (try 65)? What does the CTS time of 0 s measure, compared with `repair_timing` at 22 s in the 70 run?

---

## Day 6: experiment B, clock period sweep

**Goal:** change the clock period in the SDC, keep `CORE_UTILIZATION` at the default 55, and measure timing, area, wirelength, power and DRC.

**Setup:** `designs/nangate45/gcd/constraint.sdc`: `set clk_period 0.25` (ns, 4 GHz), `clk_io_pct = 0.2`, fixed clock latency 0.070 ns. The original plan was to shrink the period (0.8, 0.6, 0.5 times); since slack is already negative at 0.25, it was changed to 0.20, 0.35, 0.45, with the 0.25 run (util 55) as the baseline.

### Commands

| Step | Command | Note |
|---|---|---|
| 21 | `cat designs/nangate45/gcd/constraint.sdc` | read the SDC |
| 22 | `cp designs/nangate45/gcd/constraint.sdc designs/nangate45/gcd/constraint.sdc.orig` | back up the original SDC |
| 22b | `ls designs/nangate45/gcd` | check `.orig` exists |
| 23 | `make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk clean_all` | clean up the failed 70 run |
| 24 | `sed -i 's/^set clk_period 0.25$/set clk_period 0.20/' designs/nangate45/gcd/constraint.sdc` | change period to 0.20 |
| 25 | `grep -n "clk_period" designs/nangate45/gcd/constraint.sdc` | check |
| 26 | `make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk 2>&1 \| tee exp_period_0.20.log` | run the flow |
| 27 | `mkdir -p exp/period_0.20 && cp -r logs/nangate45/gcd/base exp/period_0.20/logs && cp -r reports/nangate45/gcd/base exp/period_0.20/reports && cp -r results/nangate45/gcd/base exp/period_0.20/results` | backup |
| 28 | `grep -HE "^(tns\|wns\|worst slack)" exp/period_0.20/reports/*.rpt` | WNS -0.21, TNS -9.34 |
| 29 | `wc -l exp/period_0.20/reports/5_route_drc.rpt` | 0 |
| 30 | `make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk clean_all` | clean up |
| 31 | `sed -i 's/^set clk_period .*$/set clk_period 0.35/' designs/nangate45/gcd/constraint.sdc` | change to 0.35 |
| 32 | `grep -n "set clk_period" designs/nangate45/gcd/constraint.sdc` | check |
| 33 | `make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk 2>&1 \| tee exp_period_0.35.log` | run the flow |
| 34 | `mkdir -p exp/period_0.35 && cp -r logs/nangate45/gcd/base exp/period_0.35/logs && cp -r reports/nangate45/gcd/base exp/period_0.35/reports && cp -r results/nangate45/gcd/base exp/period_0.35/results` | backup |
| 35 | `grep -HE "^(tns\|wns\|worst slack)" exp/period_0.35/reports/*.rpt` | WNS -0.07, TNS -2.90 |
| 36 | `wc -l exp/period_0.35/reports/5_route_drc.rpt` | 0 |
| 37 | `make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk clean_all` | clean up |
| 38 | `sed -i 's/^set clk_period .*$/set clk_period 0.45/' designs/nangate45/gcd/constraint.sdc` | change to 0.45 |
| 39 | `grep -n "set clk_period" designs/nangate45/gcd/constraint.sdc` | check |
| 40 | `make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk 2>&1 \| tee exp_period_0.45.log` | run the flow |
| 41 | `mkdir -p exp/period_0.45 && cp -r logs/nangate45/gcd/base exp/period_0.45/logs && cp -r reports/nangate45/gcd/base exp/period_0.45/reports && cp -r results/nangate45/gcd/base exp/period_0.45/results` | backup |
| 42 | `grep -HE "^(tns\|wns\|worst slack)" exp/period_0.45/reports/*.rpt` | WNS 0.00, TNS 0.00 (met) |
| 43 | `wc -l exp/period_0.45/reports/5_route_drc.rpt` | 0 |
| 44 | `cp designs/nangate45/gcd/constraint.sdc.orig designs/nangate45/gcd/constraint.sdc` | restore the original SDC |
| 45 | `grep -n "set clk_period" designs/nangate45/gcd/constraint.sdc` | `5:set clk_period 0.25` |
| 46 | `make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk clean_all` | clean up |

### Results (utilization 55)

| Period (ns) | WNS (ns) | TNS | DRC | Final cells (um^2) | Wire (um) | Power (mW) | Run time |
|---|---|---|---|---|---|---|---|
| 0.20 | -0.21 | -9.34 | 0 | 875 (81%) | 4055 | 4.67 | routing 38 s (total not recorded) |
| 0.25 | -0.17 | -7.22 | 0 | 911 (85%) | 4421 | 3.85 | 110 s |
| 0.35 | -0.07 | -2.90 | 0 | 913 (85%) | 4656 | 2.78 | 65 s |
| 0.45 | 0.00 | 0.00 | 0 | 685 (64%) | 3521 | 1.67 | 35 s |

The 0.25 row is the util 55 run from day 5. The core is fixed at 1076.77 um^2 in all four runs.

**Observations (measurements)**
- Slack at floorplan: -0.20 (0.20), -0.15 (0.25), -0.05 (0.35), +0.04 (0.45); afterwards it only changes by another 0.01 to 0.02.
- Period minus WNS: 0.41, 0.42, 0.42: the critical path delay is nearly constant (about 0.42 ns); timing closes from 0.45 ns.
- At 0.45: Timing Repair Buffers 65 cells (53 um^2) versus 154 to 178 cells (150 to 173 um^2) in the tighter runs; combinational logic about 405 versus about 510 um^2.
- Power drops as the period grows: 4.67, 3.85, 2.78, 1.67 mW.
- Routing: 60 to 68 violations in the first iteration for 0.35 and 0.45, down to 0 in the last.
- The netlist hash of `1_2_yosys.v` (`6a8e3d96c6`) is identical in all four runs: the area differences come from the post-synthesis steps (resize/repair), not from Yosys.

**Explanation (not verified further)**
- A 0.25 ns period is tighter than the circuit can achieve (about 0.42 ns), so slack is always negative.
- A tight period brings more buffers and larger cells, so area, wirelength and power are all higher.
- Power is close to proportional to frequency from 0.20 to 0.35 but drops more from 0.35 to 0.45 (1.66x versus 1.29x for frequency); hypothesis: fewer buffers means less capacitance.
- Area is not monotonic (875 at 0.20 is lower than 911 at 0.25), and each level was run once; cause unknown.

**Conclusion of experiment B**
- As the period shrinks, slack gets worse almost one for one, and area and power rise because the flow adds buffers and upsizes cells; gcd/nangate45 meets timing from about 0.45 ns, and 0.25 ns is not achievable.

**Self-check question: how do setup and hold slack change when the period shrinks?**
- Setup: slack changes almost one for one with the period (data available).
- Hold: not measured (the `*.rpt` reports only contain `max`). Flip-flop to flip-flop paths have no period term so in theory they do not change; paths from input ports have an input delay of 20% of the period so they may change. To get numbers: `report_worst_slack -min` on each backed-up `.odb`.

**Open questions:** why is the 0.20 area smaller than 0.25? Why are wires longer in the 55 and 0.35 runs while 0.45 is shortest? Hold slack versus period?

---

## Day 6 addendum: gcd on SKY130 and comparison with Nangate45

**Goal:** run the same design on sky130hd (a real open PDK) and compare with Nangate45.

**Setup:** `designs/sky130hd/gcd/config.mk`: `CORE_UTILIZATION = 38`, `OPENROAD_HIERARCHICAL = 1`, `SETUP_REPAIR_PHASES = PARALLEL_EVAL`, `SWAP_ARITH_OPERATORS = 1`; SDC: period 1.1 ns, clock latency 0.290 ns, `clk_io_pct = 0.2`.

### Commands

| Step | Command | Note |
|---|---|---|
| 47 | `ls designs/sky130hd` | `gcd` is there |
| 48 | `cat designs/sky130hd/gcd/config.mk designs/sky130hd/gcd/constraint.sdc` | read the config and SDC |
| 49 | `make DESIGN_CONFIG=./designs/sky130hd/gcd/config.mk 2>&1 \| tee run_sky130.log` | ran 53 s |
| 50 | `mkdir -p exp/sky130_default && cp -r logs/sky130hd/gcd/base exp/sky130_default/logs && cp -r reports/sky130hd/gcd/base exp/sky130_default/reports && cp -r results/sky130hd/gcd/base exp/sky130_default/results` | backup |
| 51 | `grep -HE "^(tns\|wns\|worst slack)" exp/sky130_default/reports/*.rpt` | WNS -1.26, TNS -56.04 |
| 52 | `wc -l exp/sky130_default/reports/5_route_drc.rpt` | 0 |
| 53 | `tail -n 25 exp/sky130_default/reports/synth_stat.txt` | synthesis statistics |
| 54 | `grep -HiE "number of cells\|chip area\|sequential" exp/util_55/reports/synth_stat.txt exp/sky130_default/reports/synth_stat.txt` | compare the two platforms |
| 55 | `cp designs/sky130hd/gcd/constraint.sdc designs/sky130hd/gcd/constraint.sdc.orig` | back up the original SDC |
| 56 | `make DESIGN_CONFIG=./designs/sky130hd/gcd/config.mk clean_all` | clean up |
| 57 | `sed -i 's/^set clk_period .*$/set clk_period 2.5/' designs/sky130hd/gcd/constraint.sdc` | relax period to 2.5 |
| 58 | `grep -n "set clk_period" designs/sky130hd/gcd/constraint.sdc` | check |
| 59 | `make DESIGN_CONFIG=./designs/sky130hd/gcd/config.mk 2>&1 \| tee run_sky130_2.5.log` | ran 46 s |
| 60 | `mkdir -p exp/sky130_2.5 && cp -r logs/sky130hd/gcd/base exp/sky130_2.5/logs && cp -r reports/sky130hd/gcd/base exp/sky130_2.5/reports && cp -r results/sky130hd/gcd/base exp/sky130_2.5/results` | backup |
| 61 | `grep -HE "^(tns\|wns\|worst slack)" exp/sky130_2.5/reports/*.rpt` | slack +0.06, -0.12, -0.04, -0.02, 0.00 |
| 62 | `wc -l exp/sky130_2.5/reports/5_route_drc.rpt` | 0 |
| 63 | `cp designs/sky130hd/gcd/constraint.sdc.orig designs/sky130hd/gcd/constraint.sdc` | restore the SDC |
| 64 | `grep -n "set clk_period" designs/sky130hd/gcd/constraint.sdc` | `5:set clk_period 1.1` |
| 65 | `make DESIGN_CONFIG=./designs/sky130hd/gcd/config.mk clean_all` | clean up |

### Comparison table

| Metric | Nangate45 (0.25 ns) | sky130hd (1.1 ns) | sky130hd (2.5 ns) |
|---|---|---|---|
| CORE_UTILIZATION | 55 | 38 | 38 |
| Area after synthesis (um^2) | 626.70 | 2313.47 | 2313.47 (netlist unchanged, hash `d829478367`) |
| Sequential part (um^2) | 158.27 (25%) | 1020.98 (44%) | |
| Core (um^2) | 1076.77 | 5885.64 | |
| Final cells (um^2) | 911 (85%) | 4380 (74%) | 3744 (64%) |
| WNS / TNS | -0.17 / -7.22 | -1.26 / -56.04 | 0.00 / 0.00 (met) |
| DRC | 0 | 0 | 0 |
| Wire (um) | 4421 | 7186 | 7002 |
| Power | 3.85 mW | 5.52 mW (1.8 V) | 2.10 mW |
| Timing Repair Buffers | 154 to 178 | 166 (1156 um^2) | 124 (785 um^2) |
| Combinational logic (um^2) | about 510 | 1969 | 1725 |
| Run time | 110 s | 53 s | 46 s |
| Estimated achievable period | about 0.42 ns | about 2.36 ns | met at 2.5 ns |

**Observations (measurements)**
- Both have 35 sequential cells, but the sequential area differs by 6.5x; SKY130 has 32 `edfxtp_1` cells (960.9 um^2) and 3 `dfxtp_1` cells.
- SKY130 has a Han-Carlson adder submodule (690.66 um^2); architectures tried during synthesis: Brent-Kung 658, Sklansky 727, Kogge-Stone 1002, Han-Carlson 690.66 um^2.
- Both grow considerably after synthesis: Nangate45 626.70 to 911, SKY130 2313.47 to 4380 um^2 (timing-repair buffers, clock cells, tap cells, upsized cells).
- Slack is already negative at floorplan in both (-0.15 Nangate45, -1.10 SKY130) and barely changes afterwards.
- SKY130 at 2.5 ns: slack +0.06 (floorplan), -0.12 (detailed place), -0.04 (CTS), -0.02 (global route), 0.00 (final); final cell area about 15% lower; power drops 2.63x while frequency drops 2.27x.

**Explanation (not verified further)**
- gcd runs about 5.6 times slower on SKY130 (2.36 vs 0.42 ns), plausible in direction since 130 nm versus 45 nm. The smallest SKY130 period lies between 2.36 and 2.5 ns (not swept finely).
- The two sides differ in period and utilization, so compare achievable periods, not slack directly.

**Conclusion**
- For the same design, SKY130 is about 3.7x larger after synthesis and its achievable period is about 5 to 6 times longer than Nangate45 (rough estimate, one run each). Compare the two technologies at the period where timing is met. Setting a period tighter than the circuit can achieve raises area and power and still does not close timing.

**Open questions:** what is the smallest achievable period on SKY130 (try 2.2, 2.4)? Why did Yosys pick Han-Carlson instead of the smaller Brent-Kung? Cell count after synthesis for SKY130 (not collected).

---

## Week 1 summary

**Three points the data supports most firmly**
1. Slack barely changes with utilization; it is set by the clock period (the gcd/nangate45 critical path is about 0.42 ns, timing closes from 0.45 ns).
2. A period tighter than the circuit can achieve increases buffers, area and power (0.25 vs 0.45 ns: 911 vs 685 um^2, 3.85 vs 1.67 mW).
3. Too high a utilization (70) makes the flow fail at CTS because the core has no room left for timing-repair buffers (`DPL-0033`); the limit lies between 60 and 70.

**Uncertain or to check next:** each point was run once; hold slack versus period not measured; congestion not examined; exact utilization limit not narrowed; smallest SKY130 period not swept finely; why Yosys chose Han-Carlson; what the 0 s CTS time in the summary table measures.

**Questions to prepare for interviews:** why does relaxing the period reduce area and power? Why does the flow fail at util 70 and not at floorplan? With a negative slack of 0.166 and a skew of 0.001, how would you fix it? Why is slack worse after routing than after CTS?

**Errors during the week**
- Day 1: forgot `sudo` when installing git.
- Day 4: the GUI did not appear (`xcb`) because Docker created `.Xauthority` as a directory; fixed with `rmdir`, deleting the line in `runorfs.sh`, and `xhost +local:`.
- Day 5: util 70 failed with `DPL-0033` (not an operating mistake, but a result worth recording).
