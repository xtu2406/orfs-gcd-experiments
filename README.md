# ORFS gcd: khảo sát utilization và chu kỳ clock (Nangate45 và SKY130HD)

Dự án thực hành thiết kế vật lý chip số với OpenROAD-flow-scripts (ORFS): chạy trọn flow RTL-to-GDS cho thiết kế mẫu gcd, đọc log, report và GUI, rồi tự thay đổi một tham số mỗi lần (`CORE_UTILIZATION`, chu kỳ clock) để đo ảnh hưởng lên diện tích, dây, timing, công suất và DRC. Thực hiện trong sáu buổi làm việc bởi Ngọ Xuân Tú, sinh viên thiết kế vi mạch, FPT University.

Nhật ký chi tiết từng lệnh và số liệu nằm trong [`LOG.md`](LOG.md).

## Trạng thái

- Tuần 1 (xong): chạy gcd trên Nangate45 và SKY130HD, hai thí nghiệm quét utilization và chu kỳ clock.
- Tuần 2 trở đi (chưa làm): đưa một lõi CPU nhỏ vào cùng flow. Hiện repo chưa có CPU nào; mọi kết quả bên dưới là của gcd, một thiết kế mẫu có sẵn trong ORFS.

ORFS, thiết kế gcd và các thư viện Nangate45, SKY130HD là của các dự án mở khác. Phần của repo này là các lần chạy, số liệu và nhận xét.

## Kết quả chính

Mọi số liệu là kết quả một lần chạy cho mỗi điểm, nên chênh lệch rất nhỏ (ví dụ WNS 0.01 ns) chưa đủ để kết luận.

1. Slack gần như không phụ thuộc utilization. Với gcd/Nangate45 ở chu kỳ 0.25 ns, WNS là -0.16 ns (util 30) và -0.17 ns (util 55); slack đã âm ngay từ floorplan (-0.15 ns).
2. Slack do chu kỳ clock quyết định. Đường tới hạn của gcd trên Nangate45 khoảng 0.42 ns (chu kỳ trừ WNS); timing đóng được từ chu kỳ 0.45 ns.
3. Chu kỳ chặt hơn mức mạch đạt được làm tăng chi phí mà không đóng được timing. 0.25 ns so với 0.45 ns: diện tích cell cuối 911 so với 685 um^2, công suất 3.85 so với 1.67 mW, buffer sửa timing 154 đến 178 so với 65.
4. Utilization quá cao làm flow thất bại. Ở util 70, flow dừng ở `4_1_cts` với `DPL-0033`: `repair_timing` thêm buffer, core đầy 99.5%, legalization không hội tụ. Ngưỡng nằm giữa 60 và 70.
5. Cùng RTL, hai công nghệ cho kết quả rất khác. SKY130HD lớn hơn khoảng 3.7 lần sau synthesis và chu kỳ đạt được dài hơn khoảng 5 đến 6 lần so với Nangate45 (ước lượng thô, mỗi bên một lần chạy); timing của SKY130 đóng ở 2.5 ns.

### Thí nghiệm A: quét CORE_UTILIZATION (Nangate45, chu kỳ 0.25 ns)

| CORE_UTILIZATION | Core (um^2) | Cell cuối (um^2) | WNS (ns) | TNS | DRC | Dây (um) | Công suất | Thời gian |
|---|---|---|---|---|---|---|---|---|
| 30 | 2034.37 | 905 (44%) | -0.16 | -6.92 | 0 | 4172 | 3.86 mW | 27 s |
| 55 (mặc định) | 1076.77 | 911 (85%) | -0.17 | -7.22 | 0 | 4421 | 3.85 mW | 110 s |
| 70 | | | thất bại ở CTS (`DPL-0033`) | | | | | |

### Thí nghiệm B: quét chu kỳ clock (Nangate45, utilization 55)

| Chu kỳ (ns) | WNS (ns) | TNS | DRC | Cell cuối (um^2) | Dây (um) | Công suất (mW) | Thời gian |
|---|---|---|---|---|---|---|---|
| 0.20 | -0.21 | -9.34 | 0 | 875 (81%) | 4055 | 4.67 | chưa ghi |
| 0.25 | -0.17 | -7.22 | 0 | 911 (85%) | 4421 | 3.85 | 110 s |
| 0.35 | -0.07 | -2.90 | 0 | 913 (85%) | 4656 | 2.78 | 65 s |
| 0.45 | 0.00  | 0.00  | 0 | 685 (64%) | 3521 | 1.67 | 35 s |

### So sánh Nangate45 và SKY130HD

| Chỉ số | Nangate45 (0.25 ns) | SKY130HD (1.1 ns) | SKY130HD (2.5 ns) |
|---|---|---|---|
| CORE_UTILIZATION | 55 | 38 | 38 |
| Diện tích sau synthesis (um^2) | 626.70 | 2313.47 | 2313.47 |
| Cell cuối (um^2) | 911 (85%) | 4380 (74%) | 3744 (64%) |
| WNS / TNS | -0.17 / -7.22 | -1.26 / -56.04 | 0.00 / 0.00 |
| DRC | 0 | 0 | 0 |
| Công suất | 3.85 mW | 5.52 mW (1.8 V) | 2.10 mW |
| Chu kỳ đạt được ước lượng | khoảng 0.42 ns | khoảng 2.36 ns | đạt ở 2.5 ns |

## Môi trường

- VMware, Ubuntu 26.04.1 (RAM 12 GB, 4 CPU, ổ 60 GB), Docker (`docker.io`), image `openroad/orfs`.
- ORFS tải từ https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts (clone đầy đủ).
- Thiết kế: `gcd` trên `nangate45` và `sky130hd` (có sẵn trong `flow/designs`).

## Dựng môi trường

```bash
sudo apt update
sudo apt install -y docker.io git
sudo usermod -aG docker $USER      # đăng xuất rồi đăng nhập lại
docker run hello-world

cd ~
git clone https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts.git
cd OpenROAD-flow-scripts
```

Script `runorfs.sh` nằm trong repo này. Nó chạy container ORFS với thư mục `flow/` gắn từ máy vào, nên file kết quả nằm trên máy. Đặt nó ở thư mục gốc của bản ORFS vừa clone. Bản này đã bỏ dòng gắn `${HOME}/.Xauthority` của hướng dẫn gốc: trên Ubuntu chạy Wayland file đó không tồn tại, Docker tự tạo nó thành thư mục và GUI báo lỗi `xcb`.

```bash
chmod +x runorfs.sh
xhost +local:        # ngoài container, chỉ cần khi mở GUI
./runorfs.sh         # vào container
cd flow
```

## Chạy lại các thí nghiệm

Chạy trong container, thư mục `flow`. `make` chỉ chạy trong container; `grep`, `cp`, `wc` chạy được cả ngoài container vì thư mục dùng chung.

### Flow mặc định (gcd trên nangate45)

```bash
time make 2>&1 | tee run1.log
find results -name 6_final.gds
make clean_cts                       # xóa từ CTS trở đi
make 2>&1 | tee run2.log             # chỉ chạy lại từ CTS
diff run1.log run2.log
make clean_all
```

### Quét CORE_UTILIZATION (thay 30 bằng 55, 70)

```bash
CFG=./designs/nangate45/gcd/config.mk
make DESIGN_CONFIG=$CFG clean_all
make DESIGN_CONFIG=$CFG CORE_UTILIZATION=30 2>&1 | tee exp_util_30.log
mkdir -p exp/util_30 && cp -r logs/nangate45/gcd/base exp/util_30/logs && cp -r reports/nangate45/gcd/base exp/util_30/reports && cp -r results/nangate45/gcd/base exp/util_30/results
grep -niE "core area|die area|utilization" exp/util_30/logs/2_1_floorplan.log
grep -HE "^(tns|wns|worst slack)" exp/util_30/reports/*.rpt
wc -l exp/util_30/reports/5_route_drc.rpt        # 0 = không lỗi DRC
```

`CORE_UTILIZATION ?= 55` trong `config.mk` nên đặt trên dòng lệnh ghi đè được. Ở 70 flow dừng ở CTS nên chỉ sao lưu logs và reports.

### Quét chu kỳ clock (thay 0.35 bằng 0.20, 0.45)

```bash
SDC=designs/nangate45/gcd/constraint.sdc
cp $SDC $SDC.orig                                         # chỉ làm một lần
sed -i 's/^set clk_period .*$/set clk_period 0.35/' $SDC
grep -n "set clk_period" $SDC                             # kiểm tra đã đổi
make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk 2>&1 | tee exp_period_0.35.log
mkdir -p exp/period_0.35 && cp -r logs/nangate45/gcd/base exp/period_0.35/logs && cp -r reports/nangate45/gcd/base exp/period_0.35/reports && cp -r results/nangate45/gcd/base exp/period_0.35/results
grep -HE "^(tns|wns|worst slack)" exp/period_0.35/reports/*.rpt
wc -l exp/period_0.35/reports/5_route_drc.rpt
make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk clean_all
# khi xong tất cả: cp $SDC.orig $SDC
```

### SKY130HD (chu kỳ mặc định 1.1 ns, rồi 2.5 ns)

```bash
make DESIGN_CONFIG=./designs/sky130hd/gcd/config.mk 2>&1 | tee run_sky130.log
mkdir -p exp/sky130_default && cp -r logs/sky130hd/gcd/base exp/sky130_default/logs && cp -r reports/sky130hd/gcd/base exp/sky130_default/reports && cp -r results/sky130hd/gcd/base exp/sky130_default/results
grep -HE "^(tns|wns|worst slack)" exp/sky130_default/reports/*.rpt
tail -n 25 exp/sky130_default/reports/synth_stat.txt     # thống kê tổng hợp
# đổi chu kỳ sang 2.5 bằng cùng cách sed như trên, trên designs/sky130hd/gcd/constraint.sdc
```

### GUI

```bash
make DESIGN_CONFIG=./designs/nangate45/gcd/config.mk gui_final
```

Trong GUI: Timing Report (Setup, Hold), Clock Tree Viewer, và khung Scripting Tcl (`report_cell_usage`, `puts [llength [[ord::get_db_block] getInsts]]`).

## Cấu trúc thư mục dự án

```
.
├── README.md
├── LOG.md                  nhật ký từng ngày, từng lệnh, số liệu
├── runorfs.sh              script khởi động container
├── exp_*.log, run_*.log    log các lần chạy
└── exp/
    ├── util_30, util_55, util_70
    ├── period_0.20, period_0.35, period_0.45
    └── sky130_default, sky130_2.5
```

Mỗi thư mục `exp/<tên>` giữ bản sao `logs/` và `reports/` của lần chạy tương ứng. Lần chạy 0.25 ns là `exp/util_55`. File nặng (`*.odb`, `*.gds`, thư mục `results/` và `objects/`) sinh lại được nên không đưa lên repo (xem `.gitignore`). Dữ liệu các lần thử đầu (util 30, 45, 60) không đưa lên repo; các lần chạy 30 và 55 được chạy lại và có trong `exp/`.

## Hạn chế

- Mỗi điểm chỉ chạy một lần; chưa đo độ biến thiên giữa các lần chạy.
- Hold slack theo chu kỳ chưa đo (báo cáo `*.rpt` chỉ có slack setup).
- Chưa xem congestion nên chưa giải thích được vì sao dây dài hơn khi core chật hơn.
- Ngưỡng utilization giữa 60 và 70 chưa thu hẹp; chu kỳ nhỏ nhất đạt được trên SKY130 (giữa 2.36 và 2.5 ns) chưa quét mịn.
- Chưa giải thích được vì sao diện tích ở 0.20 ns nhỏ hơn ở 0.25 ns, và vì sao Yosys chọn bộ cộng Han-Carlson thay vì Brent-Kung (nhỏ hơn) trên SKY130.

## Hướng phát triển

- Chạy mỗi điểm nhiều lần, quét mịn hơn (util 60 đến 70, chu kỳ SKY130 2.2 đến 2.5 ns).
- Đo hold slack theo chu kỳ bằng `report_worst_slack -min`.
- Đưa thiết kế riêng (ví dụ một CPU nhỏ) vào ORFS theo cùng quy trình.

## Tài liệu tham khảo

- OpenROAD-flow-scripts: https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts
- Tài liệu ORFS: https://openroad-flow-scripts.readthedocs.io
