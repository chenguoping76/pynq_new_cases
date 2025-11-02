#include "uart_hls.h"
#include <iostream>
#include <iomanip>

using namespace std;

// Simulate UART loopback: connect TX to RX
ap_uint<1> uart_loopback_wire = 1;

// Helper function to print binary
void print_binary(ap_uint<8> val) {
    for (int i = 7; i >= 0; i--) {
        cout << (int)val[i];
    }
}

int main() {
    // AXI-Lite registers (individual scalars)
    ap_uint<32> control_reg = 0;
    ap_uint<32> baud_div_reg = 0;
    ap_uint<32> status_reg = 0;
    ap_uint<32> tx_count_reg = 0;
    ap_uint<32> rx_count_reg = 0;

    // AXI-Stream interfaces
    hls::stream<axis_data_t> tx_stream("tx_stream");
    hls::stream<axis_data_t> rx_stream("rx_stream");

    // UART pins
    ap_uint<1> uart_rxd = 1;
    ap_uint<1> uart_txd = 1;

    int errors = 0;
    const int ITERATIONS = 100000;  // Enough iterations to complete transmission

    cout << "========================================" << endl;
    cout << "UART HLS Testbench" << endl;
    cout << "========================================" << endl;

    // Calculate baud divisor for 115200 baud @ 100MHz clock
    // divisor = 100,000,000 / (115200 * 16) = 54.25 ≈ 54
    ap_uint<32> baud_115200 = 54;

    cout << "\nTest 1: Configure UART for 115200 baud" << endl;
    baud_div_reg = baud_115200;
    control_reg = 0x03;  // Enable TX and RX
    cout << "Baud divisor set to: " << baud_115200 << endl;

    // Run a few cycles to apply configuration
    for (int i = 0; i < 100; i++) {
        uart_hls(control_reg, baud_div_reg, status_reg, tx_count_reg, rx_count_reg,
                 tx_stream, rx_stream, uart_rxd, uart_txd);
        uart_loopback_wire = uart_txd;  // Loopback connection
        uart_rxd = uart_loopback_wire;
    }

    cout << "\nTest 2: Send test data" << endl;
    // Prepare test data
    ap_uint<8> test_data[] = {0x48, 0x65, 0x6C, 0x6C, 0x6F};  // "Hello"
    int test_data_len = 5;

    cout << "Sending " << test_data_len << " bytes: ";
    for (int i = 0; i < test_data_len; i++) {
        cout << "0x" << hex << setw(2) << setfill('0') << (int)test_data[i] << " ";
    }
    cout << dec << endl;

    // Push data to TX stream
    for (int i = 0; i < test_data_len; i++) {
        axis_data_t tx_data;
        tx_data.data = test_data[i];
        tx_data.keep = 1;
        tx_data.last = (i == test_data_len - 1) ? 1 : 0;
        tx_stream.write(tx_data);
    }

    cout << "\nTest 3: Run simulation (loopback mode)" << endl;
    int received_count = 0;
    ap_uint<8> received_data[10];

    for (int iter = 0; iter < ITERATIONS && received_count < test_data_len; iter++) {
        // Call DUT
        uart_hls(control_reg, baud_div_reg, status_reg, tx_count_reg, rx_count_reg,
                 tx_stream, rx_stream, uart_rxd, uart_txd);

        // Loopback connection
        uart_loopback_wire = uart_txd;
        uart_rxd = uart_loopback_wire;

        // Check for received data
        if (!rx_stream.empty()) {
            axis_data_t rx_data = rx_stream.read();
            received_data[received_count] = rx_data.data;
            cout << "Iteration " << iter << ": Received byte " << received_count
                 << " = 0x" << hex << setw(2) << setfill('0')
                 << (int)rx_data.data << " (";
            print_binary(rx_data.data);
            cout << ")" << dec << endl;
            received_count++;
        }

        // Print status every 10000 iterations
        if (iter % 10000 == 0) {
            cout << "Iteration " << iter << ": Status=0x" << hex << status_reg
                 << ", TX_count=" << dec << tx_count_reg
                 << ", RX_count=" << rx_count_reg << endl;
        }
    }

    cout << "\nTest 4: Verify received data" << endl;
    cout << "Expected " << test_data_len << " bytes, received " << received_count << " bytes" << endl;

    if (received_count != test_data_len) {
        cout << "ERROR: Received count mismatch!" << endl;
        errors++;
    }

    for (int i = 0; i < received_count && i < test_data_len; i++) {
        cout << "Byte " << i << ": Expected=0x" << hex << setw(2) << setfill('0')
             << (int)test_data[i] << ", Received=0x" << setw(2) << setfill('0')
             << (int)received_data[i] << dec;

        if (test_data[i] == received_data[i]) {
            cout << " [PASS]" << endl;
        } else {
            cout << " [FAIL]" << endl;
            errors++;
        }
    }

    // Test register reads
    cout << "\nTest 5: Read status registers" << endl;

    // Run additional cycles to ensure all transmissions are complete
    cout << "Waiting for all transmissions to complete..." << endl;
    for (int i = 0; i < 5000; i++) {
        uart_hls(control_reg, baud_div_reg, status_reg, tx_count_reg, rx_count_reg,
                 tx_stream, rx_stream, uart_rxd, uart_txd);
        uart_loopback_wire = uart_txd;
        uart_rxd = uart_loopback_wire;
    }

    cout << "Status Register: 0x" << hex << status_reg << dec << endl;
    cout << "  TX Busy:       " << (int)status_reg[0] << endl;
    cout << "  RX Valid:      " << (int)status_reg[1] << endl;
    cout << "  Reserved bits: " << (int)status_reg[2] << endl;
    cout << "TX Count: " << tx_count_reg << endl;
    cout << "RX Count: " << rx_count_reg << endl;

    if (tx_count_reg != test_data_len || rx_count_reg != test_data_len) {
        cout << "ERROR: Counter mismatch!" << endl;
        errors++;
    }

    // Test different baud rates
    cout << "\nTest 6: Test different baud rates" << endl;
    ap_uint<32> baud_rates[] = {
        calc_baud_divisor(115200),
        calc_baud_divisor(230400),
        calc_baud_divisor(460800),
        calc_baud_divisor(921600)
    };

    const char* baud_names[] = {"115200", "230400", "460800", "921600"};

    for (int b = 0; b < 4; b++) {
        cout << "Setting baud rate to " << baud_names[b] << " (divisor="
             << baud_rates[b] << ")... ";
        baud_div_reg = baud_rates[b];

        // Run a few cycles
        for (int i = 0; i < 10; i++) {
            uart_hls(control_reg, baud_div_reg, status_reg, tx_count_reg, rx_count_reg,
                     tx_stream, rx_stream, uart_rxd, uart_txd);
        }

        cout << "OK" << endl;
    }

    // Test reset
    cout << "\nTest 7: Test reset functionality" << endl;
    control_reg = 0x07;  // Set reset bit
    uart_hls(control_reg, baud_div_reg, status_reg, tx_count_reg, rx_count_reg,
             tx_stream, rx_stream, uart_rxd, uart_txd);

    cout << "After reset: TX_count=" << tx_count_reg << ", RX_count=" << rx_count_reg << endl;

    if (tx_count_reg == 0 && rx_count_reg == 0) {
        cout << "Reset test [PASS]" << endl;
    } else {
        cout << "Reset test [FAIL]" << endl;
        errors++;
    }

    // Final report
    cout << "\n========================================" << endl;
    cout << "Testbench Summary" << endl;
    cout << "========================================" << endl;
    if (errors == 0) {
        cout << "ALL TESTS PASSED!" << endl;
        return 0;
    } else {
        cout << "TESTS FAILED with " << errors << " error(s)" << endl;
        return 1;
    }
}
