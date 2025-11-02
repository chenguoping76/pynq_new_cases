#include "uart_hls.h"

// UART Transmitter
void uart_tx(
    hls::stream<axis_data_t> &tx_stream,
    ap_uint<1> &uart_txd,
    ap_uint<32> baud_div,
    ap_uint<1> tx_enable,
    ap_uint<1> &tx_busy,
    ap_uint<32> &tx_count
) {
    static enum {TX_IDLE, TX_START, TX_DATA, TX_STOP} tx_state = TX_IDLE;
    static ap_uint<8> tx_data = 0;
    static ap_uint<3> tx_bit_cnt = 0;
    static ap_uint<32> tx_clk_cnt = 0;

    switch(tx_state) {
        case TX_IDLE:
            uart_txd = 1;  // Idle high
            tx_busy = 0;
            if (tx_enable && !tx_stream.empty()) {
                axis_data_t temp = tx_stream.read();
                tx_data = temp.data;
                tx_state = TX_START;
                tx_clk_cnt = 0;
                tx_busy = 1;
            }
            break;

        case TX_START:
            uart_txd = 0;  // Start bit (low)
            if (tx_clk_cnt >= baud_div - 1) {
                tx_clk_cnt = 0;
                tx_bit_cnt = 0;
                tx_state = TX_DATA;
            } else {
                tx_clk_cnt++;
            }
            break;

        case TX_DATA:
            uart_txd = tx_data[tx_bit_cnt];
            if (tx_clk_cnt >= baud_div - 1) {
                tx_clk_cnt = 0;
                if (tx_bit_cnt == 7) {
                    tx_state = TX_STOP;
                } else {
                    tx_bit_cnt++;
                }
            } else {
                tx_clk_cnt++;
            }
            break;

        case TX_STOP:
            uart_txd = 1;  // Stop bit (high)
            if (tx_clk_cnt >= baud_div - 1) {
                tx_clk_cnt = 0;
                tx_count++;
                tx_state = TX_IDLE;
            } else {
                tx_clk_cnt++;
            }
            break;
    }
}

// UART Receiver
void uart_rx(
    ap_uint<1> uart_rxd,
    hls::stream<axis_data_t> &rx_stream,
    ap_uint<32> baud_div,
    ap_uint<1> rx_enable,
    ap_uint<1> &rx_valid,
    ap_uint<32> &rx_count
) {
    static enum {RX_IDLE, RX_START, RX_DATA, RX_STOP} rx_state = RX_IDLE;
    static ap_uint<8> rx_data = 0;
    static ap_uint<3> rx_bit_cnt = 0;
    static ap_uint<32> rx_clk_cnt = 0;
    static ap_uint<1> rxd_sync[3] = {1, 1, 1};  // Synchronizer

    // Synchronize input
    rxd_sync[0] = uart_rxd;
    rxd_sync[1] = rxd_sync[0];
    rxd_sync[2] = rxd_sync[1];
    ap_uint<1> rxd = rxd_sync[2];

    rx_valid = 0;

    switch(rx_state) {
        case RX_IDLE:
            if (rx_enable && rxd == 0) {  // Detect start bit
                rx_state = RX_START;
                rx_clk_cnt = 0;
            }
            break;

        case RX_START:
            // Sample at middle of start bit
            if (rx_clk_cnt >= (baud_div >> 1)) {
                if (rxd == 0) {  // Valid start bit
                    rx_clk_cnt = 0;
                    rx_bit_cnt = 0;
                    rx_state = RX_DATA;
                } else {
                    rx_state = RX_IDLE;  // False start
                }
            } else {
                rx_clk_cnt++;
            }
            break;

        case RX_DATA:
            if (rx_clk_cnt >= baud_div - 1) {
                rx_data[rx_bit_cnt] = rxd;
                rx_clk_cnt = 0;
                if (rx_bit_cnt == 7) {
                    rx_state = RX_STOP;
                } else {
                    rx_bit_cnt++;
                }
            } else {
                rx_clk_cnt++;
            }
            break;

        case RX_STOP:
            if (rx_clk_cnt >= baud_div - 1) {
                if (rxd == 1) {  // Valid stop bit
                    axis_data_t out;
                    out.data = rx_data;
                    out.keep = 1;
                    out.last = 0;
                    if (!rx_stream.full()) {
                        rx_stream.write(out);
                        rx_valid = 1;
                        rx_count++;
                    }
                }
                rx_state = RX_IDLE;
                rx_clk_cnt = 0;
            } else {
                rx_clk_cnt++;
            }
            break;
    }
}

// Top function with AXI interfaces
void uart_hls(
    ap_uint<32> control_reg,
    ap_uint<32> baud_div_reg,
    ap_uint<32> &status_reg,
    ap_uint<32> &tx_count_reg,
    ap_uint<32> &rx_count_reg,
    hls::stream<axis_data_t> &tx_stream,
    hls::stream<axis_data_t> &rx_stream,
    ap_uint<1> uart_rxd,
    ap_uint<1> &uart_txd
) {
    #pragma HLS INTERFACE s_axilite port=control_reg bundle=control
    #pragma HLS INTERFACE s_axilite port=baud_div_reg bundle=control
    #pragma HLS INTERFACE s_axilite port=status_reg bundle=control
    #pragma HLS INTERFACE s_axilite port=tx_count_reg bundle=control
    #pragma HLS INTERFACE s_axilite port=rx_count_reg bundle=control
    #pragma HLS INTERFACE axis port=tx_stream
    #pragma HLS INTERFACE axis port=rx_stream
    #pragma HLS INTERFACE ap_none port=uart_rxd
    #pragma HLS INTERFACE ap_none port=uart_txd
    #pragma HLS INTERFACE s_axilite port=return bundle=control

    // Static variables to maintain state between calls
    static uart_config_t config = {54, 0, 0, 0};  // Default: 115200 baud @ 100MHz
    static ap_uint<1> tx_busy = 0;
    static ap_uint<1> rx_valid = 0;
    static ap_uint<32> tx_count = 0;
    static ap_uint<32> rx_count = 0;

    // Parse control register
    config.tx_enable = control_reg[0];
    config.rx_enable = control_reg[1];
    config.reset = control_reg[2];

    // Update baud divisor
    if (baud_div_reg > 0) {
        config.baud_div = baud_div_reg;
    }

    // Reset logic
    if (config.reset) {
        tx_count = 0;
        rx_count = 0;
        uart_txd = 1;
        tx_busy = 0;
        rx_valid = 0;
    } else {
        // Call TX and RX functions
        uart_tx(tx_stream, uart_txd, config.baud_div, config.tx_enable,
                tx_busy, tx_count);
        uart_rx(uart_rxd, rx_stream, config.baud_div, config.rx_enable,
                rx_valid, rx_count);
    }

    // Write status registers
    status_reg = 0;
    status_reg[0] = tx_busy;
    status_reg[1] = rx_valid;
    // Note: tx_stream.full() and rx_stream.empty() cannot be checked here
    // as they would cause bidirectional access on the stream interfaces
    status_reg[2] = 0;  // TX stream full status not available
    status_reg[3] = 0;  // RX stream empty status not available

    tx_count_reg = tx_count;
    rx_count_reg = rx_count;
}
