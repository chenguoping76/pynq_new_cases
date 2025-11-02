"""
UART HLS Example Usage for PYNQ
Demonstrates how to use the UART HLS IP core on PYNQ
"""

from pynq import Overlay
from pynq.lib import DMA
from uart_hls_driver import UartHLS
import time


def example_basic_control():
    """Example 1: Basic control and status"""
    print("\n" + "=" * 60)
    print("Example 1: Basic Control and Status")
    print("=" * 60)

    # Load overlay (replace with your actual bitstream path)
    ol = Overlay('uart_hls.bit')

    # Get UART IP instance
    uart = ol.uart_hls_0

    # Configure baud rate to 115200
    uart.set_baud_rate(115200)

    # Enable TX and RX
    uart.enable(tx=True, rx=True)

    # Print status
    uart.print_status()


def example_loopback_test():
    """Example 2: Loopback test with DMA"""
    print("\n" + "=" * 60)
    print("Example 2: Loopback Test")
    print("=" * 60)

    # Load overlay
    ol = Overlay('uart_hls.bit')

    # Get UART and DMA instances
    uart = ol.uart_hls_0
    tx_dma = ol.axi_dma_tx
    rx_dma = ol.axi_dma_rx

    # Configure DMA
    uart.configure_dma(tx_dma, rx_dma)

    # Configure UART
    uart.reset()
    uart.set_baud_rate(115200)
    uart.enable(tx=True, rx=True)

    # Test data
    test_string = "Hello UART HLS!"
    print(f"Sending: {test_string}")

    # Send data
    uart.send_string(test_string)

    # Wait for transmission
    uart.wait_tx_done(timeout=2.0)

    # Receive data (in loopback mode)
    received = uart.receive_bytes(len(test_string), timeout=2.0)

    if received:
        print(f"Received: {received.decode('utf-8')}")

        if received.decode('utf-8') == test_string:
            print("✓ Loopback test PASSED!")
        else:
            print("✗ Loopback test FAILED!")
    else:
        print("✗ Receive timeout!")

    # Print final status
    uart.print_status()


def example_multiple_baud_rates():
    """Example 3: Test multiple baud rates"""
    print("\n" + "=" * 60)
    print("Example 3: Multiple Baud Rates")
    print("=" * 60)

    # Load overlay
    ol = Overlay('uart_hls.bit')
    uart = ol.uart_hls_0

    # Test different baud rates
    baud_rates = [115200, 230400, 460800, 921600]

    for baud in baud_rates:
        print(f"\nTesting baud rate: {baud}")
        uart.set_baud_rate(baud)
        uart.enable(tx=True, rx=True)

        # Print status
        status = uart.get_status()
        print(f"  Status: {status}")

        time.sleep(0.1)


def example_send_receive():
    """Example 4: Send and receive data"""
    print("\n" + "=" * 60)
    print("Example 4: Send and Receive Data")
    print("=" * 60)

    # Load overlay
    ol = Overlay('uart_hls.bit')

    # Get UART and DMA instances
    uart = ol.uart_hls_0
    tx_dma = ol.axi_dma_tx
    rx_dma = ol.axi_dma_rx

    # Configure
    uart.configure_dma(tx_dma, rx_dma)
    uart.reset()
    uart.set_baud_rate(115200)
    uart.enable(tx=True, rx=True)

    # Send multiple messages
    messages = [
        "Hello World!",
        "UART HLS test",
        "PYNQ is awesome!",
        "12345"
    ]

    for msg in messages:
        print(f"\nSending: '{msg}'")

        # Send
        uart.send_string(msg + "\n")
        uart.wait_tx_done(timeout=1.0)

        # Small delay
        time.sleep(0.1)

        # Check status
        status = uart.get_status()
        print(f"TX Count: {status['tx_count']}")


def example_continuous_operation():
    """Example 5: Continuous operation"""
    print("\n" + "=" * 60)
    print("Example 5: Continuous Operation")
    print("=" * 60)

    # Load overlay
    ol = Overlay('uart_hls.bit')

    uart = ol.uart_hls_0
    tx_dma = ol.axi_dma_tx
    rx_dma = ol.axi_dma_rx

    uart.configure_dma(tx_dma, rx_dma)
    uart.reset()
    uart.set_baud_rate(115200)
    uart.enable(tx=True, rx=True)

    print("Sending continuous data stream for 10 seconds...")
    print("Press Ctrl+C to stop")

    start_time = time.time()
    packet_count = 0

    try:
        while (time.time() - start_time) < 10:
            # Send packet
            packet = f"Packet #{packet_count:04d}\n"
            uart.send_string(packet)
            uart.wait_tx_done(timeout=0.5)

            packet_count += 1

            # Print status every 100 packets
            if packet_count % 100 == 0:
                status = uart.get_status()
                print(f"Packets sent: {packet_count}, TX count: {status['tx_count']}")

            time.sleep(0.01)  # 10ms delay

    except KeyboardInterrupt:
        print("\nStopped by user")

    print(f"\nTotal packets sent: {packet_count}")
    uart.print_status()


def example_register_access():
    """Example 6: Direct register access"""
    print("\n" + "=" * 60)
    print("Example 6: Direct Register Access")
    print("=" * 60)

    # Load overlay
    ol = Overlay('uart_hls.bit')
    uart = ol.uart_hls_0

    print("Reading all registers:")
    print(f"CONTROL (0x00):   0x{uart.read(uart.REG_CONTROL):08X}")
    print(f"STATUS (0x04):    0x{uart.read(uart.REG_STATUS):08X}")
    print(f"BAUD_DIV (0x08):  0x{uart.read(uart.REG_BAUD_DIV):08X}")
    print(f"TX_COUNT (0x0C):  0x{uart.read(uart.REG_TX_COUNT):08X}")
    print(f"RX_COUNT (0x10):  0x{uart.read(uart.REG_RX_COUNT):08X}")

    # Write control register
    print("\nSetting control register...")
    uart.write(uart.REG_CONTROL, uart.CTRL_TX_ENABLE | uart.CTRL_RX_ENABLE)

    # Write baud divisor
    print("Setting baud divisor to 54 (115200 @ 100MHz)...")
    uart.write(uart.REG_BAUD_DIV, 54)

    # Read back
    print("\nReading after write:")
    print(f"CONTROL:   0x{uart.read(uart.REG_CONTROL):08X}")
    print(f"BAUD_DIV:  0x{uart.read(uart.REG_BAUD_DIV):08X}")


if __name__ == "__main__":
    """Main function - run all examples"""

    print("\n" + "=" * 60)
    print("UART HLS PYNQ Examples")
    print("=" * 60)

    # Note: These examples assume you have:
    # 1. Generated bitstream from HLS
    # 2. Loaded the overlay on PYNQ
    # 3. Connected DMA blocks to AXI4-Stream interfaces
    # 4. Optionally connected TX to RX for loopback testing

    try:
        # Run examples (comment out ones you don't want to run)

        # Example 1: Basic control
        example_basic_control()

        # Example 2: Loopback test
        # example_loopback_test()

        # Example 3: Multiple baud rates
        # example_multiple_baud_rates()

        # Example 4: Send and receive
        # example_send_receive()

        # Example 5: Continuous operation
        # example_continuous_operation()

        # Example 6: Register access
        example_register_access()

    except Exception as e:
        print(f"\nError: {e}")
        print("\nNote: Make sure to:")
        print("  1. Update 'uart_hls.bit' path to your bitstream")
        print("  2. Verify IP names match your block design")
        print("  3. Connect DMA blocks for AXI4-Stream interfaces")

    print("\n" + "=" * 60)
    print("Examples completed")
    print("=" * 60)
