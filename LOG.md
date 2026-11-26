# LOG: thực hành ORFS tuần 1

Quy ước đọc nhật ký này:

- **Số đo** là con số lấy trực tiếp từ log hoặc report. **Giải thích** là suy luận, chưa kiểm chứng thêm.
- Lệnh ngày 5 và 6 được đánh số theo thứ tự thực tế (Bước 1 đến 65). Lệnh ngày 1 đến 4 lấy từ tài liệu hướng dẫn tuần 1; lệnh nào chưa có xác nhận đã chạy được đánh dấu *(theo hướng dẫn)*.
- Dự đoán viết trước khi chạy không được lưu lại nên nhật ký không có phần so sánh với dự đoán.
- Dấu nhắc `ubuntu@...:/OpenROAD-flow-scripts/flow$` là trong container; `user@...:~/OpenROAD-flow-scripts/flow$` là ngoài container. `make` phải chạy trong container; `grep`, `cp`, `wc` chạy được ở cả hai nơi vì thư mục dùng chung.

---

## Ngày 1: dựng môi trường

**Mục tiêu:** có Ubuntu với Docker chạy được và mở được container ORFS.

**Máy:** VMware, Ubuntu 26.04.1, RAM 12 GB, 4 CPU, ổ đĩa 60 GB.

**Lệnh**
```
nproc                                   # số nhân CPU (theo hướng dẫn)
free -h                                 # RAM (theo hướng dẫn)
df -h /                                 # dung lượng ổ đĩa (theo hướng dẫn)
sudo apt update
sudo apt install -y docker.io           # đã chạy
sudo usermod -aG docker $USER           # chạy Docker không cần sudo (theo hướng dẫn)
docker --version
docker run hello-world                  # đã chạy, thành công
sudo apt install -y git                 # đã chạy (lần đầu quên sudo nên lỗi quyền)
git --version
cd ~
git clone https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts.git
cd OpenROAD-flow-scripts
cat > runorfs.sh <<'EOF' ... EOF        # tạo script chạy container (xem file runorfs.sh trong repo)
chmod +x runorfs.sh
./runorfs.sh
cd flow
ls
```

**Ý nghĩa:** `docker.io` là Docker từ kho Ubuntu; `hello-world` kiểm tra Docker hoạt động; `git clone` (đầy đủ, không `--depth 1`) tải ORFS; `runorfs.sh` chạy `docker run` với thư mục `flow/` gắn từ máy vào container nên file kết quả nằm trên máy.

**Lỗi gặp:** quên `sudo` khi cài git; thêm `sudo` thì chạy được.

**Kết quả:** Docker `hello-world` chạy được.

---

## Ngày 2: chạy flow mặc định gcd trên nangate45

**Mục tiêu:** chạy RTL-to-GDS một lần và hiểu rằng flow chạy theo giai đoạn, `make` chỉ chạy phần thiếu.

**Lệnh** (trong container, thư mục `flow`)
```
./runorfs.sh
cd flow
time make 2>&1 | tee run1.log
ls results/nangate45/gcd/base
ls logs/nangate45/gcd/base              # (theo hướng dẫn)
ls reports/nangate45/gcd/base           # (theo hướng dẫn)
find results -name 6_final.gds
make clean_cts
make 2>&1 | tee run2.log
diff run1.log run2.log
make clean_all                          # giữ lại run1.log đầy đủ
```

**Ý nghĩa:** `make` không có `DESIGN_CONFIG` dùng cấu hình mặc định của ORFS (gcd trên nangate45). `2>&1 | tee` gộp lỗi vào đầu ra, in ra màn hình và lưu file. `clean_cts` xóa kết quả từ CTS trở đi.

**Kết quả**

| Hạng mục | Kết quả |
|---|---|
| Thời gian lần 1 | 2m5.919s |
| File GDS | `results/nangate45/gcd/base/6_final.gds` |
| Thời gian lần 2 (sau `clean_cts`) | 1m24.714s |

**Quan sát:** `run2.log` ngắn hơn vì make bỏ qua synthesis, floorplan, placement và chỉ chạy lại từ CTS. Thời gian lần 2 vẫn lớn vì routing và các bước sau CTS chiếm phần lớn thời gian.

**Đã hiểu:** flow chạy theo giai đoạn, giai đoạn sau đọc file của giai đoạn trước; make chỉ chạy lại phần bị xóa.

**Lỗi gặp:** không có.

**Câu tự kiểm tra:** vì sao `make` không chạy lại synthesis khi chỉ xóa từ CTS? Vì `make` so các file kết quả với nhau: file của synthesis, floorplan và placement vẫn còn và không cũ hơn file đầu vào của chúng, nên các bước đó coi như đã xong. Chỉ các file từ CTS trở đi bị xóa nên chỉ phần đó được làm lại.

---

## Ngày 3: đọc log và report từng giai đoạn

**Mục tiêu:** biết mỗi giai đoạn để lại file nào và mở log nào để xem nó đã làm gì.

**Lệnh** (theo hướng dẫn)
```
ls -l results/nangate45/gcd/base
ls -l logs/nangate45/gcd/base
ls -l reports/nangate45/gcd/base
less logs/nangate45/gcd/base/4_1_cts.log
less reports/nangate45/gcd/base/synth_stat.txt
grep -ci warning logs/nangate45/gcd/base/*.log
grep -ci error logs/nangate45/gcd/base/*.log
```
Các số ở cuối flow (TNS, WNS, DRC) lấy từ `6_finish.rpt` và `5_route_drc.rpt`; nguyên văn lệnh đọc các file này ở ngày 3 không còn lưu lại, cùng loại lệnh dùng lại từ ngày 5 (`grep -HE "^(tns|wns|worst slack)" ...`, `wc -l ...`).

### Thời gian từng giai đoạn (`logs/nangate45/gcd/base`)

| Giai đoạn | File log | Thời gian (giây) |
|---|---|---|
| Synthesis | 1_1_yosys_canonicalize.log, 1_2_yosys.log, 1_synth.log | 2 |
| Floorplan | 2_1_floorplan.log đến 2_4_floorplan_pdn.log | 13 |
| Placement | 3_1_place_gp_skip_io.log đến 3_5_place_dp.log | 8 (3_3: 5, 3_4: 2, 3_5: 1) |
| CTS | 4_1_cts.log | 0 trong bảng tóm tắt; log ghi `repair_timing` mất 18 giây |
| Routing | 5_1_grt.log, 5_2_route.log, 5_3_fillcell.log | 47 (5_1: 17, 5_2: 30) |
| Final | 6_1_fill.log, 6_1_merge.log, 6_report.log | 0 |

### Cảnh báo và lỗi
- Lỗi: 0 ở tất cả các log.
- Cảnh báo: tổng 78 dòng; nhiều nhất ở `5_1_grt.log` (23), `4_rsz_lec.log` và `6_final_lec.log` (16 mỗi file), `1_1_yosys_canonicalize.log` (9). Số này đếm dòng chứa chữ warning, không phải số cảnh báo khác nhau.
- `STA-0450`: clock ảo `vclk_core_clock` không lan truyền được (virtual clock cho input/output delay trong SDC, vô hại).
- `RSZ-0104` (nhiều dòng): các net `_487_`, `_486_`... chỉ có một chân.

### Synthesis (`reports/nangate45/gcd/base/synth_stat.txt`)
- 513 cell, diện tích 626.696 um^2.
- Flip-flop: 35 `DFF_X1`, 158.27 um^2, chiếm 25.25% (phần tuần tự).
- Cell nhiều nhất: `NAND2_X1` (161), `INV_X1` (78), `NAND3_X1` (41).
- 35 flip-flop khớp đúng 35 sink CTS báo ở bước sau.

### CTS (`4_1_cts.log`)
- Cây clock `clk`: 35 sink, H-tree, buffer `CLKBUF_X3`; tạo 5 buffer clock, 5 net clock, sâu 2 tầng; số buffer trên đường clock tối thiểu 2, tối đa 2.
- Độ dài dây trung bình tới sink 45.06 um; runtime CTS 0.94 giây. Log không in skew (muốn xem dùng `report_clock_skew`).
- `repair_timing` sau CTS: ban đầu 52 endpoint vi phạm setup (WNS -0.161, TNS -7.2); sau sửa còn 51 endpoint (WNS -0.156, TNS -6.9). Đã đổi kích thước 94 cell, chèn 6 buffer, đổi chân 13 cell, nhân bản 1 cell; diện tích tăng 10.1%. Cảnh báo `RSZ-0062`: không sửa hết vi phạm setup. Không có vi phạm hold.
- Diện tích sau CTS 878 um^2, mật độ 81% (trước sửa timing là 74%).

### Kết quả cuối flow
- Setup: TNS -7.22, WNS -0.17, worst slack -0.17 (ns). DRC: `5_route_drc.rpt` 0 dòng.
- So với sau CTS (WNS -0.156, TNS -6.9), slack xấu hơn một chút sau routing (giải thích: dây thật có điện trở và điện dung ký sinh).

### Điều rút ra
- Với cấu hình mặc định, gcd/nangate45 không đạt timing setup dù DRC sạch. Ngày 5 và 6 kiểm tra vì sao.

### Câu hỏi
- Vì sao diện tích tăng từ 626.7 (synthesis) lên 878 um^2 (sau CTS)? Đã trả lời ở ngày 4.
- Vì sao bảng tóm tắt ghi CTS 0 giây mà `repair_timing` mất 18 giây? Vẫn mở (có thể bảng chỉ đo bước dựng cây 0.94 s; chưa kiểm chứng).

---

## Ngày 4: mở GUI, đọc timing, cây clock, số cell

**Mục tiêu:** nhìn kết quả bằng mắt: đường setup/hold tệ nhất, cây clock, đếm cell theo loại.

### Sự cố mở GUI và cách sửa
**Lỗi:** `gui_final` đọc xong thiết kế nhưng không hiện cửa sổ; log có `Could not load the Qt platform plugin "xcb"`.

```
make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk gui_final     # lần đầu: lỗi xcb
echo $XDG_SESSION_TYPE $DISPLAY      # ngoài container: ra "wayland :0"
ls -ld ~/.Xauthority                 # chữ d đầu dòng: nó là thư mục thuộc root
ls /tmp/.X11-unix                    # có X0 và X1
sudo rmdir ~/.Xauthority
sed -i '/Xauthority/d' runorfs.sh
xhost +local:                        # ngoài container
./runorfs.sh                         # vào lại container
make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk gui_final     # GUI mở được
```

**Nguyên nhân:** `runorfs.sh` gắn `${HOME}/.Xauthority` vào container; file không tồn tại nên Docker tự tạo thành thư mục, container không kết nối được màn hình.
**Bài học:** dấu nhắc `ubuntu@...` là trong container; `xhost` và sửa script làm ngoài container.

### Thao tác trong GUI
- Timing Report tab Setup và Hold; Clock Tree Viewer.
- Tcl trong khung Scripting: `puts [llength [[ord::get_db_block] getInsts]]` (988 instance), `report_cell_usage`.
- `report_worst_slack`, `report_tns`, `report_wns`, `report_clock_skew` *(theo hướng dẫn; kết quả chưa ghi)*. Chưa chạy `report_clock_skew` nên chưa có số skew toàn cây; skew của đường tới hạn (0.001) lấy từ Timing Report.

### Tab Setup
- Đường setup tệ nhất: slack -0.166, required 0.291, arrival 0.457 (ns), skew chỉ 0.001; launch từ `dpath.a_reg.out[7]` (DFF_X1), qua `INV_X2`, `NAND2_X4`... đến flip-flop bắt dữ liệu; clock network delay 0.072.
- Skew gần 0 nên slack âm do đường dữ liệu quá chậm, không do clock lệch.

### Tab Hold
- Đường hold tệ nhất: slack +0.086 (không vi phạm), required 0.082, arrival 0.168, skew -0.072; từ cổng input `req_msg[13]` (qua `input5`, `BUF_X1`) vào `dpath.b_reg.out[13]`.
- Skew -0.072 vì cổng input không đi qua cây clock còn flip-flop nhận clock trễ 0.072.
- Với đường flip-flop sang flip-flop, hold không có số hạng chu kỳ nên không đổi theo chu kỳ; với đường từ cổng input, input delay bằng 20% chu kỳ nên hold slack có thể đổi.

### Clock Tree Viewer
- 1 nguồn, 1 buffer, rồi 4 buffer tầng dưới; tổng 5 buffer, 2 tầng, khớp log CTS; các nhóm sink quanh 0.07 ns, cây khá cân bằng.

### Số cell (988 instance, 1076.77 um^2)

| Loại cell | Số lượng | Diện tích (um^2) |
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

- Sequential vẫn 35 cell, 158.27 um^2, đúng bằng synthesis.
- Từ 513 cell (synthesis) lên 988 chủ yếu do fill (271), timing repair buffer (164), tap cell (46): trả lời câu hỏi diện tích ngày 3.
- Đoán chưa kiểm chứng: 3 clock inverter là dummy load của CTS.

### Câu hỏi mở
- 164 timing repair buffer đến từ bước nào (repair_timing, resizer hay buffer ở cổng IO)? Số liệu ngày 6 gợi ý phần lớn đến từ sửa timing (65 buffer ở chu kỳ nới so với 154 đến 178 ở chu kỳ chặt), chưa tách riêng.
- Trên đường setup tệ nhất (skew 0.001, slack -0.166) nên tác động vào đâu? Vì skew gần 0 nên hướng sửa nằm ở dữ liệu và chu kỳ, không ở clock. Hai cách cụ thể: (1) nới chu kỳ clock (thí nghiệm B cho thấy gcd đạt timing từ khoảng 0.45 ns); (2) rút ngắn đường dữ liệu bằng cách nâng kích thước hoặc đổi sang cell nhanh hơn, và chèn buffer; đây là việc `repair_timing` đã làm một phần nhưng chưa sửa hết ở chu kỳ 0.25 ns.

---

## Ngày 5: thí nghiệm A, quét CORE_UTILIZATION

**Mục tiêu:** đổi một tham số (`CORE_UTILIZATION`), giữ nguyên mọi thứ khác, đo ảnh hưởng lên diện tích, dây, timing, DRC, thời gian chạy.

### Lần chạy thử đầu (đã cất vào `exp_old_30_45_60`)
Chạy theo vòng lặp trong hướng dẫn với 30, 45, 60:
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
Số của util_45 sau CTS: WNS -0.16, TNS -7.14 (`head -20` cắt mất số cuối flow). Core của lần cũ: 2034.4 (30), 1348.6 (45), 989.0 (60) um^2, xác nhận `CORE_UTILIZATION` trên dòng lệnh ghi đè được `config.mk`.

### Chạy lại từng lệnh một

| Bước | Lệnh | Ghi chú |
|---|---|---|
| 1 | `cat designs/nangate45/gcd/config.mk` | `CORE_UTILIZATION ?= 55`, `PLACE_DENSITY_LB_ADDON = 0.20`, SDC ở `constraint.sdc` |
| 2 | (không có lệnh) | viết dự đoán |
| 3 | `mv -n exp exp_old_30_45_60` | cất kết quả cũ, không ghi đè |
| 4 | `mv -n exp_util_30.log exp_util_45.log exp_util_60.log exp_old_30_45_60/` | cất log cũ |
| 5 | `make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk clean_all` | dọn sạch |
| 6 | `make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk CORE_UTILIZATION=30 2>&1 \| tee exp_util_30.log` | chạy 27 s |
| 7 | `mkdir -p exp/util_30 && cp -r logs/nangate45/gcd/base exp/util_30/logs && cp -r reports/nangate45/gcd/base exp/util_30/reports && cp -r results/nangate45/gcd/base exp/util_30/results` | sao lưu |
| 8 | `grep -niE "core area\|die area\|utilization" exp/util_30/logs/2_1_floorplan.log` | core 2034.368 um^2 (chạy ngoài container) |
| 9 | `grep -HE "^(tns\|wns\|worst slack)" exp/util_30/reports/*.rpt` | WNS -0.16, TNS -6.92 |
| 10 | `wc -l exp/util_30/reports/5_route_drc.rpt` | 0 |
| 11 | `./runorfs.sh` (chạy ở thư mục chứa script) | vào lại container |
| 12 | `make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk clean_all` | dọn lần 30 |
| 13 | `make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk CORE_UTILIZATION=55 2>&1 \| tee exp_util_55.log` | chạy 110 s |
| 14 | `mkdir -p exp/util_55 && cp -r logs/nangate45/gcd/base exp/util_55/logs && cp -r reports/nangate45/gcd/base exp/util_55/reports && cp -r results/nangate45/gcd/base exp/util_55/results` | sao lưu |
| 15 | `grep -HE "^(tns\|wns\|worst slack)" exp/util_55/reports/*.rpt` | WNS -0.17, TNS -7.22 |
| 16 | `wc -l exp/util_55/reports/5_route_drc.rpt` | 0 |
| 17 | `make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk clean_all` | dọn lần 55 |
| 18 | `make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk CORE_UTILIZATION=70 2>&1 \| tee exp_util_70.log` | thất bại ở `4_1_cts` |
| 19 | `mkdir -p exp/util_70 && cp -r logs/nangate45/gcd/base exp/util_70/logs && cp -r reports/nangate45/gcd/base exp/util_70/reports` | chỉ log và report (không có results) |
| 20 | (không có lệnh) | viết kết luận thí nghiệm A |

Ghi chú: `grep` log floorplan (bước 8) chỉ chạy cho lần 30; core của lần 55 lấy từ báo cáo cuối flow.

### Kết quả (gcd, nangate45, chu kỳ 0.25 ns)

| CORE_UTILIZATION | Core (um^2) | Cell cuối (um^2) | WNS (ns) | TNS | DRC | Dây (um) | Via | Công suất | Thời gian |
|---|---|---|---|---|---|---|---|---|---|
| 30 | 2034.37 | 905 (44%) | -0.16 | -6.92 | 0 | 4172 | 3530 | 3.86 mW | 27 s |
| 55 | 1076.77 | 911 (85%) | -0.17 | -7.22 | 0 | 4421 | 3809 | 3.85 mW | 110 s |
| 70 | | | thất bại ở CTS | | | | | | |

**Quan sát (số đo)**
- Lần 30: effective utilization 0.308; diện tích cell cuối floorplan 664 um^2 (33%), cuối flow 905 um^2 (44%) vì flow thêm buffer.
- Diện tích cell cuối gần như bằng nhau (905 và 911); thứ khác nhau là kích thước core, nên utilization cuối lên 85% ở lần 55.
- Filler: 734 (lần 30), 271 (lần 55). Timing Repair Buffer: 165 và 164. Routing: 8 s và 45 s. Worst IR drop VDD: 4.56 mV và 7.47 mV.
- Slack ở floorplan đã là -0.15 ở cả hai lần, rồi chỉ xấu thêm 0.01 đến 0.02.
- Lần 70: `DPL-0033` ở `4_1_cts`. `repair_timing` thêm 4 buffer, nâng kích thước 90 cell, nhân bản 2 cell, diện tích tăng khoảng 9.5%; sau đó `DPL-0009` báo utilization 99.5%, legalize không hội tụ (`DPL-0701`, 14 cell sai), 7 cell chồng nhau; `RSZ-0062` (slack kẹt -0.156). Ngưỡng utilization nằm giữa 60 (chạy được ở lần cũ) và 70.

**Giải thích (chưa kiểm chứng thêm)**
- Slack gần như không đổi theo utilization; phần lớn slack âm có từ floorplan, nên nghi nguyên nhân chính là chu kỳ clock chặt (kiểm tra ở thí nghiệm B).
- Chênh WNS 0.01 ns sát độ phân giải báo cáo và mỗi mức chạy một lần nên chưa kết luận chắc.
- Dây dài hơn ở lần 55: giả thuyết core chật làm router đi vòng; chưa có số liệu congestion.

**Kết luận thí nghiệm A**
- Tăng utilization làm core nhỏ lại nhưng diện tích cell gần như không đổi, nên mật độ cuối cao hơn (44% lên 85%), routing chậm hơn (8 s lên 45 s) và dây dài hơn một chút; timing gần như không đổi vì do chu kỳ clock quyết định. Ở 70 flow thất bại vì core không còn chỗ cho buffer sửa timing.

**Câu hỏi mở:** vì sao dây dài hơn khi core chật hơn (xem congestion trong `5_1_grt.log`)? Ngưỡng chính xác giữa 60 và 70 (thử 65)? Cột thời gian CTS 0 s đo gì so với `repair_timing` 22 s ở lần 70?

---

## Ngày 6: thí nghiệm B, quét chu kỳ clock

**Mục tiêu:** đổi chu kỳ clock trong SDC, giữ `CORE_UTILIZATION` mặc định 55, đo timing, diện tích, dây, công suất, DRC.

**Thiết lập:** `designs/nangate45/gcd/constraint.sdc`: `set clk_period 0.25` (ns, 4 GHz), `clk_io_pct = 0.2`, độ trễ clock cố định 0.070 ns. Kế hoạch gốc là giảm chu kỳ (0.8, 0.6, 0.5 lần); vì slack đã âm ở 0.25 nên đổi thành 0.20, 0.35, 0.45 và dùng lần 0.25 (util 55) làm mốc.

### Lệnh

| Bước | Lệnh | Ghi chú |
|---|---|---|
| 21 | `cat designs/nangate45/gcd/constraint.sdc` | đọc SDC |
| 22 | `cp designs/nangate45/gcd/constraint.sdc designs/nangate45/gcd/constraint.sdc.orig` | sao lưu SDC gốc |
| 22b | `ls designs/nangate45/gcd` | kiểm tra `.orig` đã có |
| 23 | `make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk clean_all` | dọn lần 70 thất bại |
| 24 | `sed -i 's/^set clk_period 0.25$/set clk_period 0.20/' designs/nangate45/gcd/constraint.sdc` | đổi chu kỳ sang 0.20 |
| 25 | `grep -n "clk_period" designs/nangate45/gcd/constraint.sdc` | kiểm tra |
| 26 | `make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk 2>&1 \| tee exp_period_0.20.log` | chạy flow |
| 27 | `mkdir -p exp/period_0.20 && cp -r logs/nangate45/gcd/base exp/period_0.20/logs && cp -r reports/nangate45/gcd/base exp/period_0.20/reports && cp -r results/nangate45/gcd/base exp/period_0.20/results` | sao lưu |
| 28 | `grep -HE "^(tns\|wns\|worst slack)" exp/period_0.20/reports/*.rpt` | WNS -0.21, TNS -9.34 |
| 29 | `wc -l exp/period_0.20/reports/5_route_drc.rpt` | 0 |
| 30 | `make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk clean_all` | dọn |
| 31 | `sed -i 's/^set clk_period .*$/set clk_period 0.35/' designs/nangate45/gcd/constraint.sdc` | đổi sang 0.35 |
| 32 | `grep -n "set clk_period" designs/nangate45/gcd/constraint.sdc` | kiểm tra |
| 33 | `make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk 2>&1 \| tee exp_period_0.35.log` | chạy flow |
| 34 | `mkdir -p exp/period_0.35 && cp -r logs/nangate45/gcd/base exp/period_0.35/logs && cp -r reports/nangate45/gcd/base exp/period_0.35/reports && cp -r results/nangate45/gcd/base exp/period_0.35/results` | sao lưu |
| 35 | `grep -HE "^(tns\|wns\|worst slack)" exp/period_0.35/reports/*.rpt` | WNS -0.07, TNS -2.90 |
| 36 | `wc -l exp/period_0.35/reports/5_route_drc.rpt` | 0 |
| 37 | `make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk clean_all` | dọn |
| 38 | `sed -i 's/^set clk_period .*$/set clk_period 0.45/' designs/nangate45/gcd/constraint.sdc` | đổi sang 0.45 |
| 39 | `grep -n "set clk_period" designs/nangate45/gcd/constraint.sdc` | kiểm tra |
| 40 | `make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk 2>&1 \| tee exp_period_0.45.log` | chạy flow |
| 41 | `mkdir -p exp/period_0.45 && cp -r logs/nangate45/gcd/base exp/period_0.45/logs && cp -r reports/nangate45/gcd/base exp/period_0.45/reports && cp -r results/nangate45/gcd/base exp/period_0.45/results` | sao lưu |
| 42 | `grep -HE "^(tns\|wns\|worst slack)" exp/period_0.45/reports/*.rpt` | WNS 0.00, TNS 0.00 (đạt) |
| 43 | `wc -l exp/period_0.45/reports/5_route_drc.rpt` | 0 |
| 44 | `cp designs/nangate45/gcd/constraint.sdc.orig designs/nangate45/gcd/constraint.sdc` | khôi phục SDC gốc |
| 45 | `grep -n "set clk_period" designs/nangate45/gcd/constraint.sdc` | `5:set clk_period 0.25` |
| 46 | `make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk clean_all` | dọn sạch |

### Kết quả (utilization 55)

| Chu kỳ (ns) | WNS (ns) | TNS | DRC | Cell cuối (um^2) | Dây (um) | Công suất (mW) | Thời gian |
|---|---|---|---|---|---|---|---|
| 0.20 | -0.21 | -9.34 | 0 | 875 (81%) | 4055 | 4.67 | routing 38 s (tổng chưa ghi) |
| 0.25 | -0.17 | -7.22 | 0 | 911 (85%) | 4421 | 3.85 | 110 s |
| 0.35 | -0.07 | -2.90 | 0 | 913 (85%) | 4656 | 2.78 | 65 s |
| 0.45 | 0.00 | 0.00 | 0 | 685 (64%) | 3521 | 1.67 | 35 s |

Dòng 0.25 là lần util 55 của ngày 5. Core cố định 1076.77 um^2 ở cả bốn lần.

**Quan sát (số đo)**
- Slack ở floorplan: -0.20 (0.20), -0.15 (0.25), -0.05 (0.35), +0.04 (0.45); sau đó chỉ đổi thêm 0.01 đến 0.02.
- Chu kỳ trừ WNS: 0.41, 0.42, 0.42: độ trễ đường tới hạn gần cố định (khoảng 0.42 ns); timing đóng từ 0.45 ns.
- Ở 0.45: Timing Repair Buffer 65 cell (53 um^2) so với 154 đến 178 cell (150 đến 173 um^2) ở các lần chặt hơn; logic tổ hợp khoảng 405 so với khoảng 510 um^2.
- Công suất giảm khi chu kỳ tăng: 4.67, 3.85, 2.78, 1.67 mW.
- Routing: 60 đến 68 vi phạm ở vòng đầu ở lần 0.35 và 0.45, về 0 ở vòng cuối.
- Hash netlist `1_2_yosys.v` (`6a8e3d96c6`) giống hệt ở cả bốn lần: chênh diện tích đến từ các bước sau tổng hợp (resize/repair), không phải do Yosys.

**Giải thích (chưa kiểm chứng thêm)**
- Chu kỳ 0.25 ns chặt hơn mức mạch đạt được (khoảng 0.42 ns) nên slack luôn âm.
- Chu kỳ chặt kéo theo nhiều buffer và cell lớn hơn nên diện tích, dây, công suất đều cao hơn.
- Công suất tỉ lệ gần với tần số ở 0.20 đến 0.35 nhưng giảm nhiều hơn từ 0.35 sang 0.45 (1.66 lần so với 1.29 lần của tần số); giả thuyết ít buffer nên điện dung nhỏ hơn.
- Diện tích không đơn điệu (875 ở 0.20 thấp hơn 911 ở 0.25), mỗi mức chạy một lần; nguyên nhân chưa rõ.

**Kết luận thí nghiệm B**
- Giảm chu kỳ thì slack xấu đi gần một đổi một, diện tích và công suất tăng vì flow thêm buffer và nâng kích thước cell; gcd/nangate45 đạt timing từ khoảng 0.45 ns, còn 0.25 ns là không đạt được.

**Câu tự kiểm tra: setup và hold slack đổi thế nào khi giảm chu kỳ?**
- Setup: slack đổi gần một đổi một theo chu kỳ (đã có số liệu).
- Hold: chưa đo (báo cáo `*.rpt` chỉ có `max`). Đường flip-flop sang flip-flop không có số hạng chu kỳ nên về lý thuyết không đổi; đường từ cổng input có input delay bằng 20% chu kỳ nên có thể đổi. Muốn có số: `report_worst_slack -min` trên từng bản `.odb` đã sao lưu.

**Câu hỏi mở:** vì sao diện tích 0.20 nhỏ hơn 0.25? Vì sao dây dài hơn ở lần 55 và 0.35 trong khi 0.45 ngắn nhất? Hold slack theo chu kỳ?

---

## Ngày 6 bổ sung: gcd trên SKY130 và so với Nangate45

**Mục tiêu:** chạy cùng thiết kế trên sky130hd (PDK mở thật) và so với Nangate45.

**Thiết lập:** `designs/sky130hd/gcd/config.mk`: `CORE_UTILIZATION = 38`, `OPENROAD_HIERARCHICAL = 1`, `SETUP_REPAIR_PHASES = PARALLEL_EVAL`, `SWAP_ARITH_OPERATORS = 1`; SDC: chu kỳ 1.1 ns, độ trễ clock 0.290 ns, `clk_io_pct = 0.2`.

### Lệnh

| Bước | Lệnh | Ghi chú |
|---|---|---|
| 47 | `ls designs/sky130hd` | có `gcd` |
| 48 | `cat designs/sky130hd/gcd/config.mk designs/sky130hd/gcd/constraint.sdc` | đọc cấu hình và SDC |
| 49 | `make DESIGN_CONFIG=./designs/sky130hd/gcd/config.mk 2>&1 \| tee run_sky130.log` | chạy 53 s |
| 50 | `mkdir -p exp/sky130_default && cp -r logs/sky130hd/gcd/base exp/sky130_default/logs && cp -r reports/sky130hd/gcd/base exp/sky130_default/reports && cp -r results/sky130hd/gcd/base exp/sky130_default/results` | sao lưu |
| 51 | `grep -HE "^(tns\|wns\|worst slack)" exp/sky130_default/reports/*.rpt` | WNS -1.26, TNS -56.04 |
| 52 | `wc -l exp/sky130_default/reports/5_route_drc.rpt` | 0 |
| 53 | `tail -n 25 exp/sky130_default/reports/synth_stat.txt` | thống kê tổng hợp |
| 54 | `grep -HiE "number of cells\|chip area\|sequential" exp/util_55/reports/synth_stat.txt exp/sky130_default/reports/synth_stat.txt` | so hai nền tảng |
| 55 | `cp designs/sky130hd/gcd/constraint.sdc designs/sky130hd/gcd/constraint.sdc.orig` | sao lưu SDC gốc |
| 56 | `make DESIGN_CONFIG=./designs/sky130hd/gcd/config.mk clean_all` | dọn |
| 57 | `sed -i 's/^set clk_period .*$/set clk_period 2.5/' designs/sky130hd/gcd/constraint.sdc` | nới chu kỳ lên 2.5 |
| 58 | `grep -n "set clk_period" designs/sky130hd/gcd/constraint.sdc` | kiểm tra |
| 59 | `make DESIGN_CONFIG=./designs/sky130hd/gcd/config.mk 2>&1 \| tee run_sky130_2.5.log` | chạy 46 s |
| 60 | `mkdir -p exp/sky130_2.5 && cp -r logs/sky130hd/gcd/base exp/sky130_2.5/logs && cp -r reports/sky130hd/gcd/base exp/sky130_2.5/reports && cp -r results/sky130hd/gcd/base exp/sky130_2.5/results` | sao lưu |
| 61 | `grep -HE "^(tns\|wns\|worst slack)" exp/sky130_2.5/reports/*.rpt` | slack +0.06, -0.12, -0.04, -0.02, 0.00 |
| 62 | `wc -l exp/sky130_2.5/reports/5_route_drc.rpt` | 0 |
| 63 | `cp designs/sky130hd/gcd/constraint.sdc.orig designs/sky130hd/gcd/constraint.sdc` | khôi phục SDC |
| 64 | `grep -n "set clk_period" designs/sky130hd/gcd/constraint.sdc` | `5:set clk_period 1.1` |
| 65 | `make DESIGN_CONFIG=./designs/sky130hd/gcd/config.mk clean_all` | dọn sạch |

### Bảng so sánh

| Chỉ số | Nangate45 (0.25 ns) | sky130hd (1.1 ns) | sky130hd (2.5 ns) |
|---|---|---|---|
| CORE_UTILIZATION | 55 | 38 | 38 |
| Diện tích sau synthesis (um^2) | 626.70 | 2313.47 | 2313.47 (netlist không đổi, hash `d829478367`) |
| Phần tuần tự (um^2) | 158.27 (25%) | 1020.98 (44%) | |
| Core (um^2) | 1076.77 | 5885.64 | |
| Cell cuối (um^2) | 911 (85%) | 4380 (74%) | 3744 (64%) |
| WNS / TNS | -0.17 / -7.22 | -1.26 / -56.04 | 0.00 / 0.00 (đạt) |
| DRC | 0 | 0 | 0 |
| Dây (um) | 4421 | 7186 | 7002 |
| Công suất | 3.85 mW | 5.52 mW (1.8 V) | 2.10 mW |
| Timing Repair Buffer | 154 đến 178 | 166 (1156 um^2) | 124 (785 um^2) |
| Logic tổ hợp (um^2) | khoảng 510 | 1969 | 1725 |
| Thời gian chạy | 110 s | 53 s | 46 s |
| Chu kỳ đạt được ước lượng | khoảng 0.42 ns | khoảng 2.36 ns | đạt ở 2.5 ns |

**Quan sát (số đo)**
- Cả hai có 35 cell tuần tự, nhưng diện tích tuần tự khác nhau 6.5 lần; SKY130 có 32 cell `edfxtp_1` (960.9 um^2) và 3 cell `dfxtp_1`.
- SKY130 có submodule bộ cộng Han-Carlson (690.66 um^2); các kiến trúc đã thử trong tổng hợp: Brent-Kung 658, Sklansky 727, Kogge-Stone 1002, Han-Carlson 690.66 um^2.
- Cả hai đều tăng diện tích đáng kể sau synthesis: Nangate45 626.70 lên 911, SKY130 2313.47 lên 4380 um^2 (buffer sửa timing, cell clock, tap cell, nâng kích thước cell).
- Slack âm ngay từ floorplan ở cả hai (-0.15 Nangate45, -1.10 SKY130) và gần như không đổi sau đó.
- SKY130 ở 2.5 ns: slack +0.06 (floorplan), -0.12 (detailed place), -0.04 (CTS), -0.02 (global route), 0.00 (cuối); diện tích cell cuối giảm khoảng 15%; công suất giảm 2.63 lần khi tần số giảm 2.27 lần.

**Giải thích (chưa kiểm chứng thêm)**
- gcd chạy chậm hơn khoảng 5.6 lần trên SKY130 (2.36 so với 0.42 ns), hợp lý về chiều hướng vì 130 nm so với 45 nm. Chu kỳ nhỏ nhất của SKY130 nằm giữa 2.36 và 2.5 ns (chưa quét mịn).
- Hai bên khác chu kỳ và utilization nên so chu kỳ đạt được, không so slack trực tiếp.

**Kết luận**
- Cùng một thiết kế, SKY130 lớn hơn khoảng 3.7 lần sau synthesis và chu kỳ đạt được dài hơn khoảng 5 đến 6 lần so với Nangate45 (ước lượng thô, mỗi bên một lần chạy). So hai công nghệ phải so ở chu kỳ đạt timing. Đặt chu kỳ chặt hơn mức mạch đạt được làm tăng diện tích và công suất mà vẫn không đóng được timing.

**Câu hỏi mở:** chu kỳ nhỏ nhất đạt được trên SKY130 (thử 2.2, 2.4)? Vì sao Yosys chọn Han-Carlson thay vì Brent-Kung (nhỏ hơn)? Số cell sau synthesis của SKY130 (chưa lấy).

---

## Tổng kết tuần 1

**Ba điều chắc nhất từ số liệu**
1. Slack hầu như không đổi theo utilization; nó do chu kỳ clock quyết định (đường tới hạn gcd/nangate45 khoảng 0.42 ns, đóng timing từ 0.45 ns).
2. Chu kỳ chặt hơn mức mạch đạt được làm tăng buffer, diện tích và công suất (0.25 so với 0.45 ns: 911 so với 685 um^2, 3.85 so với 1.67 mW).
3. Utilization quá cao (70) làm flow thất bại ở CTS vì core không còn chỗ cho buffer sửa timing (`DPL-0033`); ngưỡng nằm giữa 60 và 70.

**Chưa chắc hoặc cần kiểm tra tiếp:** mỗi điểm chỉ chạy một lần; hold slack theo chu kỳ chưa đo; congestion chưa xem; ngưỡng utilization chính xác chưa thu hẹp; chu kỳ nhỏ nhất của SKY130 chưa quét mịn; vì sao Yosys chọn Han-Carlson; CTS 0 giây trong bảng tóm tắt đo gì.

**Câu hỏi nên chuẩn bị khi phỏng vấn:** vì sao nới chu kỳ giảm diện tích và công suất? Vì sao flow thất bại ở util 70 chứ không phải ở floorplan? Slack âm 0.166 với skew 0.001 thì sửa bằng cách nào? Vì sao slack xấu hơn sau routing so với sau CTS?

**Lỗi gặp trong tuần**
- Ngày 1: quên `sudo` khi cài git.
- Ngày 4: GUI không hiện (`xcb`) vì `.Xauthority` bị Docker tạo thành thư mục; sửa bằng `rmdir`, xóa dòng trong `runorfs.sh`, `xhost +local:`.
- Ngày 5: util 70 thất bại `DPL-0033` (không phải lỗi thao tác, là kết quả cần ghi).
