# Vivado项目快速参考指南

## 📁 文件说明

### 主要TCL脚本

| 文件名 | 说明 | 用途 |
|--------|------|------|
| `create_uart_project.tcl` | 项目创建脚本 | 创建包含HLS-UART和AXI-DMA的Block Design |
| `build_project.tcl` | 构建脚本 | 执行综合、实现和比特流生成 |
| `run_vivado.bat` | Windows批处理脚本 | Windows下的一键执行脚本 |
| `run_vivado.sh` | Linux/Mac Shell脚本 | Linux/Mac下的一键执行脚本 |

### 板卡文件

| 文件/目录 | 说明 |
|-----------|------|
| `BK_B220.xdc` | BKB220板卡完整约束文件 |
| `BKB220/` | Vivado板卡定义文件目录 |
| `BKB220/1.0/board.xml` | 板卡接口定义 |
| `BKB220/1.0/part0_pins.xml` | 引脚映射定义 |

### 文档

| 文件名 | 说明 |
|--------|------|
| `README_vivado.md` | 详细使用说明文档 |
| `QUICK_REFERENCE.md` | 本文件，快速参考 |

## 🚀 快速开始

### Windows用户

```batch
# 方法1: 双击运行
运行: run_vivado.bat
选择选项 4 (完整流程)

# 方法2: 命令行
cd hls-uart\vivado_src
run_vivado.bat
```

### Linux/Mac用户

```bash
# 首先添加执行权限
chmod +x run_vivado.sh

# 方法1: 交互式菜单
./run_vivado.sh

# 方法2: 直接运行TCL
source /tools/Xilinx/Vivado/2019.2/settings64.sh
vivado -mode batch -source create_uart_project.tcl
vivado -mode batch -source build_project.tcl
```

## 📋 常用命令速查

### 创建项目

```tcl
# 在Vivado TCL Console中
cd D:/temp_projs/M02/hls-uart-claude/hls-uart/vivado_src
source create_uart_project.tcl
```

### 构建项目

```tcl
# 完整构建流程
source build_project.tcl

# 或分步执行
open_project vivado_project/hls_uart_dma.xpr
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
```

### 打开项目GUI

```tcl
# Windows
vivado vivado_project\hls_uart_dma.xpr

# Linux/Mac
vivado vivado_project/hls_uart_dma.xpr &
```

### 查看Block Design

```tcl
open_project vivado_project/hls_uart_dma.xpr
open_bd_design [get_files uart_system.bd]
```

## 🔧 配置修改

### 修改UART波特率

在Python驱动中修改（不需要重新编译硬件）：

```python
# 100MHz时钟
baud_divisor = 100000000 // (baud_rate * 16)
uart.write(REG_BAUD_DIV, baud_divisor)
```

### 更改UART引脚

编辑生成的 `vivado_project/.../uart_pins.xdc`:

```tcl
# 使用不同的PMOD
# PMOD2: T11 (d0), T12 (d1)
set_property -dict {PACKAGE_PIN T11 IOSTANDARD LVCMOS33} [get_ports uart_txd]
set_property -dict {PACKAGE_PIN T12 IOSTANDARD LVCMOS33} [get_ports uart_rxd]
```

### 修改DMA缓冲区大小

编辑 `create_uart_project.tcl`:

```tcl
# 第86-95行左右
set_property -dict [list \
    CONFIG.c_m_axi_mm2s_data_width {64} \
    CONFIG.c_m_axis_mm2s_tdata_width {8} \
    CONFIG.c_mm2s_burst_size {32} \  # 改为32
] $axi_dma_tx
```

## 📊 输出文件位置

构建完成后，文件位于：

```
vivado_project/
├── output/
│   ├── uart_system.bit              # FPGA比特流
│   ├── uart_system_wrapper.xsa      # 硬件平台（PYNQ用）
│   └── uart_pins.xdc                # 引脚约束
├── post_synth_utilization.rpt       # 综合后资源报告
├── post_synth_timing.rpt            # 综合后时序报告
├── post_impl_utilization.rpt        # 实现后资源报告
├── post_impl_timing.rpt             # 实现后时序报告
├── post_impl_power.rpt              # 功耗报告
└── post_impl_drc.rpt                # 设计规则检查报告
```

## 🔍 内存映射

| 外设 | 基地址 | 大小 | 说明 |
|------|---------|------|------|
| AXI DMA TX | 0x40000000 | 64KB | DMA TX控制寄存器 |
| AXI DMA RX | 0x40010000 | 64KB | DMA RX控制寄存器 |
| UART HLS | 0x40020000 | 64KB | UART控制和状态寄存器 |

### UART寄存器映射

| 寄存器 | 偏移 | 访问 | 说明 |
|--------|------|------|------|
| control_reg | 0x00 | R/W | 控制寄存器 [2:0] = {reset, rx_en, tx_en} |
| baud_div_reg | 0x04 | R/W | 波特率分频值 |
| status_reg | 0x08 | RO | 状态寄存器 [1:0] = {rx_valid, tx_busy} |
| tx_count_reg | 0x0C | RO | 发送字节计数 |
| rx_count_reg | 0x10 | RO | 接收字节计数 |

### DMA寄存器映射（示例）

| 寄存器 | TX偏移 | RX偏移 | 说明 |
|--------|--------|--------|------|
| MM2S_DMACR / S2MM_DMACR | 0x00 | 0x30 | DMA控制寄存器 |
| MM2S_DMASR / S2MM_DMASR | 0x04 | 0x34 | DMA状态寄存器 |
| MM2S_SA / S2MM_DA | 0x18 | 0x48 | 源/目标地址 |
| MM2S_LENGTH / S2MM_LENGTH | 0x28 | 0x58 | 传输长度 |

## 🐛 常见问题

### Q1: "Board part not found"

**解答**: 这是警告，不影响功能。可以：
1. 安装BKB220板卡文件到Vivado
2. 或忽略此警告，使用器件型号继续

### Q2: "HLS IP not found"

**解答**:
1. 先运行HLS综合: `vivado_hls -f run_hls.tcl`
2. 确认IP路径正确
3. 或在Vivado GUI中手动添加IP仓库

### Q3: 时序不满足

**解答**:
1. 查看 `post_impl_timing.rpt`
2. 降低时钟频率
3. 添加流水线寄存器
4. 调整布局布线策略

### Q4: PMOD引脚不工作

**解答**:
1. 检查约束文件中的引脚号
2. 确认IOSTANDARD为LVCMOS33
3. 使用万用表/示波器验证物理连接
4. 检查PMOD板是否需要上拉电阻

## 📞 技术支持资源

### Xilinx官方文档

- [UG896: Vivado Design with IP](https://www.xilinx.com/support/documentation/sw_manuals/xilinx2019_2/ug896-vivado-ip.pdf)
- [PG021: AXI DMA](https://www.xilinx.com/support/documentation/ip_documentation/axi_dma/v7_1/pg021_axi_dma.pdf)
- [UG585: Zynq-7000 TRM](https://www.xilinx.com/support/documentation/user_guides/ug585-Zynq-7000-TRM.pdf)

### 在线资源

- [Vivado Design Hub](https://www.xilinx.com/support/documentation-navigation/design-hubs/dh0014-vivado-design-hub.html)
- [Xilinx Forums](https://forums.xilinx.com/)
- [PYNQ Documentation](http://pynq.readthedocs.io/)

## 📝 命令速查表

| 操作 | 命令 |
|------|------|
| 创建项目 | `vivado -mode batch -source create_uart_project.tcl` |
| 构建项目 | `vivado -mode batch -source build_project.tcl` |
| 打开GUI | `vivado vivado_project/hls_uart_dma.xpr` |
| 仅综合 | `launch_runs synth_1 -jobs 4` |
| 仅实现 | `launch_runs impl_1 -jobs 4` |
| 生成比特流 | `launch_runs impl_1 -to_step write_bitstream` |
| 导出硬件 | `write_hw_platform -include_bit -file uart.xsa` |
| 查看报告 | `open_run impl_1` 然后 `report_timing_summary` |

---

**最后更新**: 2025-01-02
**Vivado版本**: 2019.1+
**目标板卡**: BKB220 (Zynq 7020)
