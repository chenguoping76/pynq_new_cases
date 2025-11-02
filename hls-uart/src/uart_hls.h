#ifndef UART_HLS_H
#define UART_HLS_H

#include "ap_int.h"
#include "ap_axi_sdata.h"
#include "hls_stream.h"

// AXI4-Lite Register Map (for reference - actual registers are individual ports)
// control_reg bits: Bit 0: Enable TX, Bit 1: Enable RX, Bit 2: Reset
// status_reg bits:  Bit 0: TX Busy, Bit 1: RX Data Valid, Bit 2-3: Reserved (always 0)
// baud_div_reg:     Baud rate divisor value
// tx_count_reg:     Number of bytes transmitted
// rx_count_reg:     Number of bytes received

// AXI4-Stream data type
typedef ap_axis<8, 0, 0, 0> axis_data_t;

// UART Configuration
struct uart_config_t {
    ap_uint<32> baud_div;      // Baud rate divisor
    ap_uint<1>  tx_enable;     // Transmit enable
    ap_uint<1>  rx_enable;     // Receive enable
    ap_uint<1>  reset;         // Reset signal
};

// UART Status
struct uart_status_t {
    ap_uint<1> tx_busy;        // Transmitter busy
    ap_uint<1> rx_valid;       // Receiver data valid
    ap_uint<32> tx_count;      // Transmitted byte count
    ap_uint<32> rx_count;      // Received byte count
};

// Calculate baud divisor from baud rate
// Formula: divisor = CLK_FREQ / (baud_rate * oversampling)
// Assuming 100MHz clock and 16x oversampling
inline ap_uint<32> calc_baud_divisor(ap_uint<32> baud_rate) {
    const ap_uint<32> CLK_FREQ = 100000000; // 100 MHz
    const ap_uint<8> OVERSAMPLE = 16;
    return CLK_FREQ / (baud_rate * OVERSAMPLE);
}

// Top function declaration
void uart_hls(
    // AXI4-Lite control registers
    ap_uint<32> control_reg,
    ap_uint<32> baud_div_reg,
    ap_uint<32> &status_reg,
    ap_uint<32> &tx_count_reg,
    ap_uint<32> &rx_count_reg,
    // AXI4-Stream TX data input
    hls::stream<axis_data_t> &tx_stream,
    // AXI4-Stream RX data output
    hls::stream<axis_data_t> &rx_stream,
    // UART physical pins
    ap_uint<1> uart_rxd,
    ap_uint<1> &uart_txd
);

#endif // UART_HLS_H
