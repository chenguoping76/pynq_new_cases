# HLS UART IP Core for PYNQ

A high-performance UART IP core designed with Xilinx Vitis HLS, featuring AXI4-Lite control interface and AXI4-Stream data interfaces. Ideal for PYNQ-based projects requiring serial communication.

## Features

- **Configurable Baud Rates**: 115200, 230400, 460800, 921600 bps
- **AXI4-Lite Interface**: Easy control and status monitoring
- **AXI4-Stream Interface**: Efficient data streaming for TX and RX
- **Hardware FIFOs**: Internal buffering for smooth data transfer
- **Full Python Support**: PYNQ driver class with examples
- **Loopback Testing**: Built-in testbench for verification

## Architecture

```
┌─────────────────────────────────────────┐
│         UART HLS IP Core                │
├─────────────────────────────────────────┤
│                                         │
│  AXI4-Lite ◄──► Control/Status Regs    │
│  (Control)      - Baud rate config      │
│                 - Enable TX/RX          │
│                 - Status flags          │
│                 - Counters              │
│                                         │
│  AXI4-Stream ──► TX State Machine       │
│  (TX Data)       - Start/Data/Stop bits │
│                  - Baud timing          │
│                                         │
│  AXI4-Stream ◄── RX State Machine       │
│  (RX Data)       - Frame detection      │
│                  - Data sampling        │
│                                         │
│  GPIO ◄──────────► UART Pins            │
│  (uart_txd/rxd)                         │
└─────────────────────────────────────────┘
```

## Register Map (AXI4-Lite)

| Offset | Name        | Access | Description                                    |
|--------|-------------|--------|------------------------------------------------|
| 0x00   | CONTROL     | R/W    | Bit[0]: TX Enable, Bit[1]: RX Enable, Bit[2]: Reset |
| 0x04   | STATUS      | R      | Bit[0]: TX Busy, Bit[1]: RX Valid, Bit[2]: TX FIFO Full, Bit[3]: RX FIFO Empty |
| 0x08   | BAUD_DIV    | R/W    | Baud rate divisor (CLK_FREQ / (baud * 16))    |
| 0x0C   | TX_COUNT    | R      | Number of bytes transmitted                    |
| 0x10   | RX_COUNT    | R      | Number of bytes received                       |

## File Structure

```
hls-uart-claude/
├── uart_hls.h              # Header file with definitions
├── uart_hls.cpp            # Main implementation (TX/RX state machines)
├── uart_hls_tb.cpp         # Testbench for C simulation
├── run_hls.tcl             # TCL script for automated HLS synthesis
├── uart_hls_driver.py      # PYNQ Python driver class
├── example_pynq.py         # PYNQ usage examples
└── README.md               # This file
```

## Quick Start

### 1. HLS Synthesis

**Option A: Using Vitis HLS GUI**

1. Open Vitis HLS
2. Create new project
3. Add `uart_hls.cpp` and `uart_hls.h` as source files
4. Add `uart_hls_tb.cpp` as testbench
5. Set top function to `uart_hls`
6. Run C Simulation
7. Run C Synthesis
8. Export as IP Catalog

**Option B: Using TCL Script (Recommended)**

```bash
# In Vitis HLS command prompt or terminal
vitis_hls -f run_hls.tcl
```

This will:
- Create project
- Run C simulation
- Synthesize to RTL
- Export IP core

### 2. Vivado Integration

1. Create Vivado project for your PYNQ board
2. Add generated IP to IP repository
3. Create block design:
   ```
   - Add UART HLS IP
   - Connect AXI4-Lite to PS (via AXI Interconnect)
   - Add two AXI DMA cores for TX and RX streams
   - Connect TX DMA M_AXIS to UART HLS tx_stream
   - Connect RX DMA S_AXIS to UART HLS rx_stream
   - Connect uart_rxd/txd to physical pins or loopback
   - Run connection automation
   ```
4. Generate bitstream
5. Export hardware platform (.xsa)

### 3. PYNQ Deployment

Copy files to PYNQ board:
```bash
scp uart_hls_driver.py xilinx@<pynq-ip>:/home/xilinx/
scp example_pynq.py xilinx@<pynq-ip>:/home/xilinx/
scp uart_hls.bit xilinx@<pynq-ip>:/home/xilinx/
scp uart_hls.hwh xilinx@<pynq-ip>:/home/xilinx/
```

### 4. Running Examples

On PYNQ board:
```python
from pynq import Overlay
from uart_hls_driver import UartHLS

# Load overlay
ol = Overlay('uart_hls.bit')

# Get UART instance
uart = ol.uart_hls_0

# Configure
uart.set_baud_rate(115200)
uart.enable(tx=True, rx=True)

# Print status
uart.print_status()
```

Or run the example script:
```bash
python3 example_pynq.py
```

## PYNQ Driver API

### Initialization
```python
uart = ol.uart_hls_0
uart.configure_dma(tx_dma, rx_dma)
```

### Configuration
```python
uart.set_baud_rate(115200)    # Set baud rate
uart.enable(tx=True, rx=True)  # Enable TX/RX
uart.reset()                   # Reset IP core
```

### Data Transfer
```python
# Send data
uart.send_string("Hello World!")
uart.send_bytes([0x48, 0x65, 0x6C, 0x6C, 0x6F])

# Receive data
data = uart.receive_bytes(count=10, timeout=1.0)

# Wait for transmission
uart.wait_tx_done(timeout=1.0)
```

### Status Monitoring
```python
status = uart.get_status()
# Returns: {'tx_busy': bool, 'rx_valid': bool,
#           'tx_fifo_full': bool, 'rx_fifo_empty': bool,
#           'tx_count': int, 'rx_count': int}

uart.print_status()  # Pretty print status
```

## Timing Specifications

### Baud Rate Calculation

```
Baud Divisor = CLK_FREQ / (Baud_Rate × Oversampling)
```

For 100 MHz system clock and 16× oversampling:

| Baud Rate | Divisor | Actual Rate | Error   |
|-----------|---------|-------------|---------|
| 115200    | 54      | 115740      | 0.47%   |
| 230400    | 27      | 231481      | 0.47%   |
| 460800    | 14      | 446428      | 3.12%   |
| 921600    | 7       | 892857      | 3.12%   |

### Frame Format

```
  Start  D0  D1  D2  D3  D4  D5  D6  D7  Stop
┌─┐ ┌──┬──┬──┬──┬──┬──┬──┬──┬─────┐
│ │ │  │  │  │  │  │  │  │  │     │
└─┘ └──┴──┴──┴──┴──┴──┴──┴──┘     └─────
 0   LSB                   MSB      1

- 1 start bit (0)
- 8 data bits (LSB first)
- 1 stop bit (1)
- No parity
```

## Performance

- **Throughput**: Up to 921600 bps
- **Latency**: ~11 clock cycles per bit at configured baud rate
- **Resource Usage** (xc7z020):
  - LUTs: ~200-300
  - FFs: ~150-250
  - DSPs: 0
  - BRAMs: 0

## Testbench

The included testbench (`uart_hls_tb.cpp`) performs comprehensive testing:

1. ✓ Configuration test (baud rate setting)
2. ✓ Loopback data transmission
3. ✓ Data integrity verification
4. ✓ Multiple baud rate testing
5. ✓ Reset functionality
6. ✓ Status register verification

Run testbench:
```bash
# From HLS project directory
vitis_hls -f run_hls.tcl
# or
# In HLS GUI: Project → Run C Simulation
```

## Troubleshooting

### HLS Synthesis Issues

**Problem**: Synthesis fails with interface errors

**Solution**: Ensure pragma directives are correct in `uart_hls.cpp`:
```cpp
#pragma HLS INTERFACE s_axilite port=axi_lite bundle=control
#pragma HLS INTERFACE axis port=tx_stream
#pragma HLS INTERFACE axis port=rx_stream
```

### PYNQ Runtime Issues

**Problem**: `AttributeError: uart_hls_0 not found`

**Solution**:
- Check IP name in Vivado block design matches code
- Verify .hwh file matches bitstream
- Try: `print(dir(ol))` to see available IPs

**Problem**: DMA transfer timeout

**Solution**:
- Verify AXI4-Stream connections in block design
- Check DMA interrupt connections
- Increase timeout value
- Enable DMA in block design

**Problem**: No data received in loopback

**Solution**:
- Verify uart_txd connected to uart_rxd in block design
- Check TX/RX enable bits are set
- Verify baud rate configured correctly
- Check DMA alignment (transfers must be word-aligned)

## Advanced Usage

### Custom Baud Rates

To use custom baud rates, calculate the divisor manually:

```python
# For 57600 baud with 100 MHz clock
custom_divisor = 100_000_000 // (57600 * 16)  # = 108
uart.write(uart.REG_BAUD_DIV, custom_divisor)
```

### Interrupt Handling

The IP can be extended to support interrupts:
1. Add interrupt output port in HLS
2. Connect to PS interrupt controller in Vivado
3. Use Python `asyncio` or interrupts library in PYNQ

### Multiple UART Instances

To use multiple UART cores:
```python
uart0 = ol.uart_hls_0
uart1 = ol.uart_hls_1

uart0.set_baud_rate(115200)
uart1.set_baud_rate(921600)
```

## License

This project is provided as-is for educational and research purposes.

## References

- [Vitis HLS User Guide (UG1399)](https://docs.xilinx.com/r/en-US/ug1399-vitis-hls)
- [PYNQ Documentation](https://pynq.readthedocs.io/)
- [AXI4-Stream Protocol](https://docs.xilinx.com/r/en-US/ug1399-vitis-hls/AXI4-Stream-Interfaces)

## Contributing

Contributions welcome! Please test with both C simulation and hardware before submitting.

## Support

For issues and questions:
- Check testbench output for functional verification
- Review synthesis reports for timing/resource issues
- Verify block design connections in Vivado
- Test with known-good loopback configuration first
