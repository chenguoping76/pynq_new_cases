# HLS-UART Vivado Project Setup Guide

本文档说明如何使用TCL脚本在Vivado中创建带有AXI-DMA的HLS-UART系统。

## 📋 前置要求

1. **Vivado** 2019.1 或更高版本
2. **HLS IP**: 已完成HLS综合的uart_hls IP
3. **板卡文件**: BKB220板卡定义文件（可选，但推荐）

## 🎯 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                     Zynq PS (ARM)                          │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐             │
│  │ M_AXI_GP0├────► AXI Inter├────►│  DMAs   │             │
│  └──────────┘    │  connect │    │ Control │             │
│                  └──────────┘    └──────────┘             │
│  ┌──────────┐                                              │
│  │S_AXI_HP0 ◄─── AXI Interconnect ◄─── DMA Data          │
│  └──────────┘                                              │
│                                                             │
│  ┌──────────┐                                              │
│  │  IRQ_F2P ◄─── Concat ◄─── DMA Interrupts              │
│  └──────────┘                                              │
└─────────────────────────────────────────────────────────────┘
                              ▼
        ┌────────────────────────────────────────┐
        │         AXI Stream Data Flow           │
        │                                        │
        │  DMA_TX ──(MM2S)──► UART_TX ──► PMOD1_d0 (Y7)
        │                                        │
        │  DMA_RX ◄─(S2MM)─── UART_RX ◄── PMOD1_d1 (Y9)
        └────────────────────────────────────────┘
```

## 🚀 快速开始

### 方法1: 使用TCL脚本自动创建

```bash
# 在vivado_src目录下运行
cd hls-uart/vivado_src

# 启动Vivado并运行TCL脚本
vivado -mode batch -source create_uart_project.tcl
```

### 方法2: 在Vivado GUI中运行

```tcl
# 打开Vivado
# Tcl Console中执行:
cd D:/temp_projs/M02/hls-uart-claude/hls-uart/vivado_src
source create_uart_project.tcl
```

## 📝 配置说明

### 1. UART引脚映射（PMOD1）

| 信号 | PMOD1引脚 | FPGA引脚 | 方向 | 说明 |
|------|----------|---------|------|------|
| uart_txd | pmod1_d0 | Y7 | Output | UART发送 |
| uart_rxd | pmod1_d1 | Y9 | Input | UART接收 |

### 2. 内存映射（默认地址）

运行脚本后，会自动分配以下地址（可在Address Editor中查看）：

```
AXI DMA TX Control:  0x4000_0000 - 0x4000_FFFF
AXI DMA RX Control:  0x4001_0000 - 0x4001_FFFF
UART HLS Control:    0x4002_0000 - 0x4002_FFFF
```

### 3. DMA配置

**TX DMA (Memory to Stream):**
- Data Width: 64-bit
- Stream Width: 8-bit
- Burst Size: 16
- Buffer Length: 可配置

**RX DMA (Stream to Memory):**
- Data Width: 64-bit
- Stream Width: 8-bit
- Burst Size: 16
- Buffer Length: 可配置

### 4. 中断配置

- IRQ 0: DMA TX完成中断
- IRQ 1: DMA RX完成中断

## 🔧 自定义配置

### 修改UART引脚

编辑 `uart_pins.xdc` 文件:

```tcl
# 使用PMOD2替代PMOD1
set_property -dict {PACKAGE_PIN T11 IOSTANDARD LVCMOS33} [get_ports uart_txd]
set_property -dict {PACKAGE_PIN T12 IOSTANDARD LVCMOS33} [get_ports uart_rxd]
```

### 修改HLS IP路径

编辑 `create_uart_project.tcl`:

```tcl
# 第10行修改HLS IP路径
set hls_ip_repo "../your_hls_path/solution1/impl/ip"
```

### 添加板卡文件

如果Vivado未识别BKB220板卡：

1. 下载板卡文件
2. 复制到: `<Vivado安装目录>/data/boards/board_files/`
3. 重启Vivado

## 🏗️ 构建流程

### 自动构建脚本

```bash
# 运行完整构建流程
vivado -mode batch -source build_project.tcl
```

### 手动构建步骤

```tcl
# 1. 打开项目
open_project vivado_project/hls_uart_dma.xpr

# 2. 综合
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# 3. 实现
launch_runs impl_1 -jobs 4
wait_on_run impl_1

# 4. 生成比特流
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# 5. 导出硬件（包含比特流）
write_hw_platform -fixed -include_bit -force \
    -file ./uart_system_wrapper.xsa
```

## 📊 资源使用估计

| 资源 | 使用量 | 可用量 | 使用率 |
|------|--------|--------|--------|
| LUT | ~3500 | 53200 | ~6.5% |
| FF | ~5000 | 106400 | ~4.7% |
| BRAM | ~10 | 140 | ~7% |
| DSP | 0 | 220 | 0% |

*实际使用量取决于HLS IP优化和DMA配置*

## 🐛 故障排除

### 问题1: HLS IP未找到

**错误信息:**
```
WARNING: Could not add HLS UART IP
```

**解决方法:**
1. 确认HLS已完成综合: `vivado_hls -f run_hls.tcl`
2. 检查IP路径是否正确
3. 手动添加IP仓库: Tools → Settings → IP → Repository

### 问题2: 板卡文件未找到

**错误信息:**
```
WARNING: Board part not found
```

**解决方法:**
1. 下载BKB220板卡文件
2. 安装到Vivado板卡目录
3. 或在脚本中使用 `-part xc7z020clg400-1` 代替板卡

### 问题3: 地址分配错误

**解决方法:**
1. 打开Block Design
2. 打开Address Editor
3. 手动验证/调整地址范围
4. 确保无地址重叠

### 问题4: AXI Stream连接错误

**检查项:**
- Stream数据宽度匹配 (都是8-bit)
- TDATA, TVALID, TREADY信号都已连接
- TKEEP, TLAST信号正确处理

## 📚 参考文档

1. **Vivado Design Suite User Guide - Designing with IP (UG896)**
2. **AXI DMA v7.1 Product Guide (PG021)**
3. **Zynq-7000 Technical Reference Manual (UG585)**
4. **Vivado Design Suite Tcl Command Reference Guide (UG835)**

## 🔗 相关文件

- `create_uart_project.tcl` - 项目创建脚本
- `build_project.tcl` - 构建脚本（待创建）
- `uart_pins.xdc` - 引脚约束文件（自动生成）
- `BK_B220.xdc` - BKB220完整约束文件

## 📞 技术支持

如有问题，请检查：
1. Vivado版本兼容性
2. HLS IP是否正确导出
3. 板卡文件是否正确安装
4. 约束文件引脚定义是否正确

---

**版本**: 1.0
**更新日期**: 2025-01-02
**适用平台**: BKB220 (Zynq 7020)
