"""
UART HLS Driver for PYNQ
Provides Python interface to control the HLS-based UART IP core
"""

from pynq import DefaultIP
from pynq import allocate
import numpy as np
import time


class UartHLS(DefaultIP):
    """Driver for HLS UART IP with AXI4-Lite control and AXI4-Stream data interfaces

    This driver provides methods to:
    - Configure baud rate (115200 to 921600)
    - Send and receive data via AXI4-Stream
    - Monitor status and statistics
    """

    # Register offsets
    REG_CONTROL = 0x00
    REG_STATUS = 0x04
    REG_BAUD_DIV = 0x08
    REG_TX_COUNT = 0x0C
    REG_RX_COUNT = 0x10

    # Control register bits
    CTRL_TX_ENABLE = 0x01
    CTRL_RX_ENABLE = 0x02
    CTRL_RESET = 0x04

    # Status register bits
    STATUS_TX_BUSY = 0x01
    STATUS_RX_VALID = 0x02
    STATUS_TX_FIFO_FULL = 0x04
    STATUS_RX_FIFO_EMPTY = 0x08

    # Clock frequency (Hz) - adjust based on your design
    CLK_FREQ = 100_000_000  # 100 MHz
    OVERSAMPLE = 16

    def __init__(self, description):
        """Initialize the UART HLS driver

        Parameters
        ----------
        description : dict
            IP description from the overlay
        """
        super().__init__(description=description)

        # Reset the IP
        self.reset()

    def bindto(classname):
        """Specify which IP cores this driver should bind to"""
        return ['xilinx.com:hls:uart_hls:1.0']

    def reset(self):
        """Reset the UART IP core"""
        self.write(self.REG_CONTROL, self.CTRL_RESET)
        time.sleep(0.001)  # Wait 1ms
        self.write(self.REG_CONTROL, 0)

    def set_baud_rate(self, baud_rate):
        """Set the UART baud rate

        Parameters
        ----------
        baud_rate : int
            Desired baud rate (115200, 230400, 460800, 921600)

        Returns
        -------
        int
            Actual baud divisor value set
        """
        valid_rates = [115200, 230400, 460800, 921600]
        if baud_rate not in valid_rates:
            raise ValueError(f"Baud rate must be one of {valid_rates}")

        # Calculate divisor: CLK_FREQ / (baud_rate * OVERSAMPLE)
        divisor = self.CLK_FREQ // (baud_rate * self.OVERSAMPLE)

        self.write(self.REG_BAUD_DIV, divisor)

        # Verify
        actual_divisor = self.read(self.REG_BAUD_DIV)
        actual_baud = self.CLK_FREQ // (actual_divisor * self.OVERSAMPLE)

        print(f"Baud rate set to {actual_baud} (divisor={actual_divisor})")

        return divisor

    def enable_tx(self, enable=True):
        """Enable or disable UART transmitter

        Parameters
        ----------
        enable : bool
            True to enable, False to disable
        """
        control = self.read(self.REG_CONTROL)
        if enable:
            control |= self.CTRL_TX_ENABLE
        else:
            control &= ~self.CTRL_TX_ENABLE
        self.write(self.REG_CONTROL, control)

    def enable_rx(self, enable=True):
        """Enable or disable UART receiver

        Parameters
        ----------
        enable : bool
            True to enable, False to disable
        """
        control = self.read(self.REG_CONTROL)
        if enable:
            control |= self.CTRL_RX_ENABLE
        else:
            control &= ~self.CTRL_RX_ENABLE
        self.write(self.REG_CONTROL, control)

    def enable(self, tx=True, rx=True):
        """Enable UART transmitter and/or receiver

        Parameters
        ----------
        tx : bool
            Enable transmitter
        rx : bool
            Enable receiver
        """
        control = 0
        if tx:
            control |= self.CTRL_TX_ENABLE
        if rx:
            control |= self.CTRL_RX_ENABLE
        self.write(self.REG_CONTROL, control)

    def get_status(self):
        """Get current UART status

        Returns
        -------
        dict
            Dictionary containing status flags and counters
        """
        status_reg = self.read(self.REG_STATUS)

        return {
            'tx_busy': bool(status_reg & self.STATUS_TX_BUSY),
            'rx_valid': bool(status_reg & self.STATUS_RX_VALID),
            'tx_fifo_full': bool(status_reg & self.STATUS_TX_FIFO_FULL),
            'rx_fifo_empty': bool(status_reg & self.STATUS_RX_FIFO_EMPTY),
            'tx_count': self.read(self.REG_TX_COUNT),
            'rx_count': self.read(self.REG_RX_COUNT)
        }

    def is_tx_busy(self):
        """Check if transmitter is busy

        Returns
        -------
        bool
            True if transmitter is busy
        """
        status = self.read(self.REG_STATUS)
        return bool(status & self.STATUS_TX_BUSY)

    def wait_tx_done(self, timeout=1.0):
        """Wait for transmission to complete

        Parameters
        ----------
        timeout : float
            Timeout in seconds

        Returns
        -------
        bool
            True if completed, False if timeout
        """
        start_time = time.time()
        while self.is_tx_busy():
            if time.time() - start_time > timeout:
                return False
            time.sleep(0.001)
        return True

    def send_byte(self, data):
        """Send a single byte via UART (using TX stream DMA if available)

        Note: This is a placeholder. Actual implementation requires
        AXI4-Stream DMA configuration.

        Parameters
        ----------
        data : int
            Byte to send (0-255)
        """
        if not hasattr(self, 'tx_dma'):
            raise NotImplementedError(
                "TX DMA not configured. Use configure_dma() first."
            )

        # Allocate buffer and send via DMA
        buffer = allocate(shape=(1,), dtype=np.uint8)
        buffer[0] = data & 0xFF

        self.tx_dma.sendchannel.transfer(buffer)
        self.tx_dma.sendchannel.wait()

        buffer.freebuffer()

    def send_bytes(self, data):
        """Send multiple bytes via UART

        Parameters
        ----------
        data : bytes, bytearray, or list of int
            Data to send
        """
        if not hasattr(self, 'tx_dma'):
            raise NotImplementedError(
                "TX DMA not configured. Use configure_dma() first."
            )

        # Convert to numpy array
        data_array = np.array(list(data), dtype=np.uint8)

        # Allocate buffer
        buffer = allocate(shape=(len(data_array),), dtype=np.uint8)
        buffer[:] = data_array

        # Transfer via DMA
        self.tx_dma.sendchannel.transfer(buffer)
        self.tx_dma.sendchannel.wait()

        buffer.freebuffer()

    def send_string(self, text):
        """Send a text string via UART

        Parameters
        ----------
        text : str
            Text string to send
        """
        self.send_bytes(text.encode('utf-8'))

    def receive_bytes(self, count, timeout=1.0):
        """Receive bytes via UART

        Parameters
        ----------
        count : int
            Number of bytes to receive
        timeout : float
            Timeout in seconds

        Returns
        -------
        bytes
            Received data, or None if timeout
        """
        if not hasattr(self, 'rx_dma'):
            raise NotImplementedError(
                "RX DMA not configured. Use configure_dma() first."
            )

        # Allocate receive buffer
        buffer = allocate(shape=(count,), dtype=np.uint8)

        # Start DMA transfer
        self.rx_dma.recvchannel.transfer(buffer)

        # Wait for completion with timeout
        start_time = time.time()
        while not self.rx_dma.recvchannel.idle:
            if time.time() - start_time > timeout:
                buffer.freebuffer()
                return None
            time.sleep(0.001)

        # Copy data
        result = bytes(buffer)
        buffer.freebuffer()

        return result

    def configure_dma(self, tx_dma, rx_dma):
        """Configure DMA engines for TX and RX streams

        Parameters
        ----------
        tx_dma : pynq.lib.dma.DMA
            DMA instance for TX stream
        rx_dma : pynq.lib.dma.DMA
            DMA instance for RX stream
        """
        self.tx_dma = tx_dma
        self.rx_dma = rx_dma

    def print_status(self):
        """Print current UART status"""
        status = self.get_status()

        print("=" * 50)
        print("UART HLS Status")
        print("=" * 50)
        print(f"TX Busy:          {status['tx_busy']}")
        print(f"RX Valid:         {status['rx_valid']}")
        print(f"TX FIFO Full:     {status['tx_fifo_full']}")
        print(f"RX FIFO Empty:    {status['rx_fifo_empty']}")
        print(f"TX Byte Count:    {status['tx_count']}")
        print(f"RX Byte Count:    {status['rx_count']}")
        print("=" * 50)


# Register the driver with PYNQ
# This allows automatic binding when an overlay is loaded
bindto = ['xilinx.com:hls:uart_hls:1.0']
