import os
import struct
from pathlib import Path
import numpy as np
from .xrt_device import XrtDevice, XrtMemory


DEFAULT_XCLBIN = (Path(__file__).parent / 'default.xclbin').read_bytes()


def _unify_dictionaries(hwh_parser, xclbin_parser):
    """Merges the XRT specific info from the xclbin file into
    the HWH parser

    """
    mem_by_address = {v['base_address']: v
                      for k, v in xclbin_parser.mem_dict.items()}
    for k, v in hwh_parser.mem_dict.items():
        if v.get('phys_addr', None) in mem_by_address:
            hwh_parser.mem_dict[k].update(mem_by_address[v['phys_addr']])
            del mem_by_address[v['phys_addr']]
    for v in mem_by_address.values():
        hwh_parser.mem_dict[v['tag']] = v


def parse_bit_header(bit_data):
    """The method to parse the header of a bitstream.

    The returned dictionary has the following keys:
    "design": str, the Vivado project name that generated the bitstream;
    "version": str, the Vivado tool version that generated the bitstream;
    "part": str, the Xilinx part name that the bitstream targets;
    "date": str, the date the bitstream was compiled on;
    "time": str, the time the bitstream finished compilation;
    "length": int, total length of the bitstream (in bytes);
    "data": binary, binary data in .bit file format

    Returns
    -------
    Dict
        A dictionary containing the header information.

    Note
    ----
    Implemented based on: https://blog.aeste.my/?p=2892

    """
    finished = False
    offset = 0
    contents = bit_data
    bit_dict = {}

    # Strip the (2+n)-byte first field (2-bit length, n-bit data)
    length = struct.unpack('>h', contents[offset:offset + 2])[0]
    offset += 2 + length

    # Strip a two-byte unknown field (usually 1)
    offset += 2

    # Strip the remaining headers. 0x65 signals the bit data field
    while not finished:
        desc = contents[offset]
        offset += 1

        if desc != 0x65:
            length = struct.unpack('>h',
                                   contents[offset:offset + 2])[0]
            offset += 2
            fmt = ">{}s".format(length)
            data = struct.unpack(fmt,
                                 contents[offset:offset + length])[0]
            data = data.decode('ascii')[:-1]
            offset += length

        if desc == 0x61:
            s = data.split(";")
            bit_dict['design'] = s[0]
            bit_dict['version'] = s[-1]
        elif desc == 0x62:
            bit_dict['part'] = data
        elif desc == 0x63:
            bit_dict['date'] = data
        elif desc == 0x64:
            bit_dict['time'] = data
        elif desc == 0x65:
            finished = True
            length = struct.unpack('>i',
                                   contents[offset:offset + 4])[0]
            offset += 4
            # Expected length values can be verified in the chip TRM
            bit_dict['length'] = str(length)
            if length + offset != len(contents):
                raise RuntimeError("Invalid length found")
            bit_dict['data'] = contents[offset:offset + length]
        else:
            raise RuntimeError("Unknown field: {}".format(hex(desc)))
    return bit_dict


def bit2bin(bit_data):
    """Convert an in-memory .bit file to .bin data for fpga_manager

    """
    bit_dict = parse_bit_header(bit_data)
    bit_buffer = np.frombuffer(bit_dict['data'], 'i4')
    bin_buffer = bit_buffer.byteswap()
    return bytes(bin_buffer)


def _preload_binfile(bitstream, parser):
    """Dump the data from a parser into a binary file in firmware

    """
    bin_data = getattr(parser, 'bin_data', None)
    if bin_data is None:
        bin_data = _get_bitstream_handler(
            bitstream.bitfile_name).get_bin_data()
    bitstream.binfile_name = Path(bitstream.bitfile_name).stem + ".bin"
    bitstream.firmware_path = Path('/lib/firmware') / bitstream.binfile_name
    bitstream.firmware_path.write_bytes(bin_data)


class BitstreamHandler:
    """Base class for handling various formats of bitstreams

    For a bitstream at least one of get_xclbin_data and get_hwh_data
    should return valid data in order for the bitstream to be used
    the Overlay class. If the bitstream is going to be used with
    the Bitstream class then only get_bin_data is required.

    """

    def __init__(self, filepath):
        self._filepath = Path(filepath)

    def get_bin_data(self):
        """Get the binary data of the bitstream in a form suitable
        for passing to FPGA manager

        """
        return None

    def get_xclbin_data(self):
        """Return the xclbin data for the bitstream

        Should be None if no data exists

        """
        xclbin_file = self._filepath.with_suffix('.xclbin')
        if xclbin_file.exists():
            return xclbin_file.read_bytes()
        return None

    def get_dtbo_data(self):
        """Return the device tree overlay for the bitstream

        Should be None if no device tree overlay is present

        """
        dtbo_file = self._filepath.with_suffix('.dtbo')
        if dtbo_file.exists():
            return dtbo_file.read_bytes()
        return None

    def get_hwh_data(self):
        """Return the hardware handoff file for the bitstream

        Should be None if no HWH data is available

        """
        hwh_file = self._filepath.with_suffix('.hwh')
        if hwh_file.exists():
            return hwh_file.read_text()
        return None

    def get_parser(self):
        """Returns a parser object for the bitstream

        The returned object contains all of the data that
        was processed from both the HWH and Xclbin metadata
        attached to the object. Note that the parser may
        contain synthetic xclbin data where that is necessary

        """
        from .xclbin_parser import XclBin
        from .hwh_parser import HWH
        hwh_data = self.get_hwh_data()
        xclbin_data = self.get_xclbin_data()
        if hwh_data is not None:
            parser = HWH(hwh_data=hwh_data)
            if xclbin_data is None:
                xclbin_data = _create_xclbin(parser.mem_dict)
            xclbin_parser = XclBin(xclbin_data=xclbin_data)
            _unify_dictionaries(parser, xclbin_parser)
        elif xclbin_data is not None:
            parser = XclBin(xclbin_data=xclbin_data)
        else:
            return None
        parser.bin_data = self.get_bin_data()
        parser.xclbin_data = xclbin_data
        parser.dtbo_data = self.get_dtbo_data()
        return parser


class BitfileHandler(BitstreamHandler):
    def get_bin_data(self):
        bit_data = self._filepath.read_bytes()
        return bit2bin(bit_data)


class BinfileHandler(BitstreamHandler):
    def get_bin_data(self):
        return self._filepath.read_bytes()


class XclbinHandler(BitstreamHandler):
    def __init__(self, filepath):
        from .xclbin_parser import parse_xclbin_header
        super().__init__(filepath)
        self._data = self._filepath.read_bytes()
        self._sections, _ = parse_xclbin_header(self._data)

    def get_bin_data(self):
        from pynq._3rdparty.xclbin import AXLF_SECTION_KIND
        if AXLF_SECTION_KIND.BITSTREAM in self._sections:
            return bit2bin(self._sections[AXLF_SECTION_KIND.BITSTREAM])
        return None

    def get_xclbin_data(self):
        return self._data


_bitstream_handlers = {
    '.bit': BitfileHandler,
    '.bin': BinfileHandler,
    '.xclbin': XclbinHandler
}


def _get_bitstream_handler(bitfile_name):
    filetype = Path(bitfile_name).suffix
    if filetype not in _bitstream_handlers:
        raise RuntimeError("Unknown file format")
    return _bitstream_handlers[filetype](bitfile_name)


BLANK_METADATA = r"""<?xml version="1.0" encoding="UTF-8"?>
<project name="binary_container_1">
  <platform vendor="xilinx" boardid="zcu111" name="name" featureRomTime="0">
    <version major="0" minor="1"/>
    <description/>
    <board name="xilinx.com:zcu111:1.4"
            vendor="xilinx.com" fpga="xczu28dr-ffvg1517-2-e">
      <interfaces/>
      <memories>
        <memory name="ddr4_0" type="ddr4" size="4GB"/>
        <memory name="ddr4_0" type="ddr4" size="4GB"/>
        <memory name="ddr4_0" type="ddr4" size="4GB"/>
        <memory name="ddr4_0" type="ddr4" size="4GB"/>
        <memory name="ddr4_0" type="ddr4" size="4GB"/>
        <memory name="ddr4_0" type="ddr4" size="4GB"/>
        <memory name="ddr4_0" type="ddr4" size="4GB"/>
        <memory name="ddr4_0" type="ddr4" size="4GB"/>
      </memories>
      <images>
        <image name="zcu111_board.jpeg" type="HDPI"/>
        <image name="" type="MDPI"/>
        <image name="" type="LDPI"/>
      </images>
      <id>
        <vendor/>
        <device/>
        <subsystem/>
      </id>
    </board>
    <build_flow/>
    <host architecture="unknown"/>
    <device name="fpga0" fpgaDevice="zynquplusRFSOC:xczu28dr:ffvg1517:-2:e"
            addrWidth="0">
      <core name="OCL_REGION_0" target="bitstream" type="clc_region"
            clockFreq="0MHz" numComputeUnits="60">
        <kernelClocks>
          <clock port="KERNEL_CLK" frequency="333.250000MHz"/>
          <clock port="DATA_CLK" frequency="99.999001MHz"/>
        </kernelClocks>
      </core>
    </device>
  </platform>
</project>
"""


def _ip_to_topology(mem_dict):
    topology = {'m_mem_data': [
        {'m_type': 'MEM_DDR4',
         'm_used': 1,
         'm_sizeKB': 256 * 1024,
         'm_tag': 'PSDDR',
         'm_base_address': 0}
    ]}
    for k, v in mem_dict.items():
        v['xrt_mem_idx'] = len(topology['m_mem_data'])
        topology['m_mem_data'].append(
            {'m_type': 'MEM_DDR4',
             'm_used': 1,
             'm_sizeKB': v['addr_range'] // 1024,
             'm_tag': f'MIG{len(topology["m_mem_data"])}',
             'm_base_address': v['phys_addr']}
        )
    topology['m_count'] = len(topology['m_mem_data'])
    return {'mem_topology': topology}


def _as_str(obj):
    if type(obj) is bytes:
        return obj.decode()
    return obj


def _create_xclbin(mem_dict):
    """Create an XCLBIN file containing the specified memories

    """
    import tempfile
    import subprocess
    import json
    with tempfile.TemporaryDirectory() as td:
        td = Path(td)
        (td / 'metadata.xml').write_text(BLANK_METADATA)
        (td / 'mem.json').write_text(json.dumps(_ip_to_topology(mem_dict)))
        completion = subprocess.run(
            ['xclbinutil', '--add-section=EMBEDDED_METADATA:RAW:metadata.xml',
             '--add-section=MEM_TOPOLOGY:JSON:mem.json', '--output',
             't.xclbin', '--skip-bank-grouping'],
            cwd=td, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if completion.returncode != 0:
            raise RuntimeError("xclbinutil failed: " +
                               _as_str(completion.stdout))
        return (td / 't.xclbin').read_bytes()


ZU_FPD_SLCR_REG = {
    'C_MAXIGP0_DATA_WIDTH': {
        'FPD_SLCR.AXI_FS.DW_SS0_SEL': {
            'addr': 0xFD615000,
            'field': [9, 8]
        }
    },
    'C_MAXIGP1_DATA_WIDTH': {
        'FPD_SLCR.AXI_FS.DW_SS1_SEL': {
            'addr': 0xFD615000,
            'field': [11, 10]
        }
    },
    'C_MAXIGP2_DATA_WIDTH': {
        'LPD_SLCR.AXI_FS.DW_SS2_SEL': {
            'addr': 0xFF419000,
            'field': [9, 8]
        }
    }
}

ZU_FPD_SLCR_VALUE = {
    '32': 0,
    '64': 1,
    '128': 2
}

ZU_AXIFM_REG = {
    'C_SAXIGP0_DATA_WIDTH': {
        'AFIFM0.AFIFM_RDCTRL.FABRIC_WIDTH': {
            'addr': 0xFD360000,
            'field': [1, 0]
        },
        'AFIFM0.AFIFM_WRCTRL.FABRIC_WIDTH': {
            'addr': 0xFD360014,
            'field': [1, 0]
        }
    },
    'C_SAXIGP1_DATA_WIDTH': {
        'AFIFM1.AFIFM_RDCTRL.FABRIC_WIDTH': {
            'addr': 0xFD370000,
            'field': [1, 0]
        },
        'AFIFM1.AFIFM_WRCTRL.FABRIC_WIDTH': {
            'addr': 0xFD370014,
            'field': [1, 0]
        }
    },
    'C_SAXIGP2_DATA_WIDTH': {
        'AFIFM2.AFIFM_RDCTRL.FABRIC_WIDTH': {
            'addr': 0xFD380000,
            'field': [1, 0]
        },
        'AFIFM2.AFIFM_WRCTRL.FABRIC_WIDTH': {
            'addr': 0xFD380014,
            'field': [1, 0]
        }
    },
    'C_SAXIGP3_DATA_WIDTH': {
        'AFIFM3.AFIFM_RDCTRL.FABRIC_WIDTH': {
            'addr': 0xFD390000,
            'field': [1, 0]
        },
        'AFIFM3.AFIFM_WRCTRL.FABRIC_WIDTH': {
            'addr': 0xFD390014,
            'field': [1, 0]
        }
    },
    'C_SAXIGP4_DATA_WIDTH': {
        'AFIFM4.AFIFM_RDCTRL.FABRIC_WIDTH': {
            'addr': 0xFD3A0000,
            'field': [1, 0]
        },
        'AFIFM4.AFIFM_WRCTRL.FABRIC_WIDTH': {
            'addr': 0xFD3A0014,
            'field': [1, 0]
        }
    },
    'C_SAXIGP5_DATA_WIDTH': {
        'AFIFM5.AFIFM_RDCTRL.FABRIC_WIDTH': {
            'addr': 0xFD3B0000,
            'field': [1, 0]
        },
        'AFIFM5.AFIFM_WRCTRL.FABRIC_WIDTH': {
            'addr': 0xFD3B0014,
            'field': [1, 0]
        }
    },
    'C_SAXIGP6_DATA_WIDTH': {
        'AFIFM6.AFIFM_RDCTRL.FABRIC_WIDTH': {
            'addr': 0xFF9B0000,
            'field': [1, 0]
        },
        'AFIFM6.AFIFM_WRCTRL.FABRIC_WIDTH': {
            'addr': 0xFF9B0014,
            'field': [1, 0]
        }
    }
}

ZU_AXIFM_VALUE = {
    '32': 2,
    '64': 1,
    '128': 0
}


class EmbeddedXrtMemory(XrtMemory):
    def __init__(self, device, desc):
        super().__init__(device, desc)
        self._mmio = None

    def read(self, address):
        return self.mmio.read(address)

    def write(self, address, value):
        return self.mmio.write(address, value)

    @property
    def mmio(self):
        if self._mmio is None:
            import pynq
            self._mmio = pynq.MMIO(self.base_address, self.size)
        return self._mmio


class EmbeddedDevice(XrtDevice):
    """Device for interacting with Zynq-7000 and Zynq US+ logic

    For Zynq and Zynq US+ a hybrid approach is taken whereby FPGA
    manager is used to program the device, /dev/mem is used to
    interact with IP in the programmable logic and XRT is used to
    allocate memory.

    The device can take multiple forms of bitstream and metadata files:

     * .bit/.bin file with HWH metadata
     * .bit/.bin file with XclBin metadata
     * .bit/.bin file with both HWH and Xclbin metadata
     * Xclbin file containing a bitstream
     * XSA file containing a bitstream

    In situations where an xclbin file isn't provided a temporary one
    will be created so that all memories in the design can be allocated
    with XRT.

    Note that a bitstream will need to be loaded before any allocation
    can occur.

    """
    BS_FPGA_MAN = "/sys/class/fpga_manager/fpga0/firmware"
    BS_FPGA_MAN_FLAGS = "/sys/class/fpga_manager/fpga0/flags"

    _probe_priority_ = 50

    @classmethod
    def _probe_(cls):
        if Path(EmbeddedDevice.BS_FPGA_MAN).exists():
            return [EmbeddedDevice()]
        else:
            return []

    @property
    def default_memory(self):
        if not self.mem_dict:
            raise RuntimeError("Overlay is not downloaded")

        for k, v in self.mem_dict.items():
            if v['base_address'] == 0:
                return self.get_memory(v)
        raise RuntimeError("XRT design does not contain PS memory")

    def __init__(self):
        super().__init__(0, "embedded_xrt{}")
        self.capabilities['REGISTER_RW'] = False
        self.capabilities['MEMORY_MAPPED'] = True
        self.capabilities['CALLABLE'] = True

    def get_memory(self, description):
        return EmbeddedXrtMemory(self, description)

    def mmap(self, base_addr, length):
        import mmap
        euid = os.geteuid()
        if euid != 0:
            raise EnvironmentError('Root permissions required.')

        # Align the base address with the pages
        virt_base = base_addr & ~(mmap.PAGESIZE - 1)

        # Calculate base address offset w.r.t the base address
        virt_offset = base_addr - virt_base

        # Open file and mmap
        mmap_file = os.open('/dev/mem', os.O_RDWR | os.O_SYNC)
        mem = mmap.mmap(mmap_file, length + virt_offset,
                        mmap.MAP_SHARED,
                        mmap.PROT_READ | mmap.PROT_WRITE,
                        offset=virt_base)
        os.close(mmap_file)
        array = np.frombuffer(mem, np.uint32, length >> 2, virt_offset)
        return array

    def set_axi_port_width(self, parser):
        """This method will set the AXI port width.

        This is useful to resolve discrepancy between the PS configurations
        during boot and the PS configurations required by the bitstream. It
        is usually to be resolved for full bitstream reconfiguration.

        Check https://www.xilinx.com/support/answers/66295.html for more
        information on the meaning of register values.

        Currently only zynq ultrascale devices support data width changes.

        """
        from pynq.registers import Register
        if not hasattr(parser, 'ps_name'):
            # Setting port widths not supported for xclbin-only designs
            return
        parameter_dict = parser.ip_dict[parser.ps_name]['parameters']
        if parser.family_ps == 'zynq_ultra_ps_e':
            for para in ZU_FPD_SLCR_REG:
                if para in parameter_dict:
                    width = parameter_dict[para]
                    for reg_name in ZU_FPD_SLCR_REG[para]:
                        addr = ZU_FPD_SLCR_REG[para][reg_name]['addr']
                        f = ZU_FPD_SLCR_REG[para][reg_name]['field']
                        Register(addr)[f[0]:f[1]] = ZU_FPD_SLCR_VALUE[width]
            for para in ZU_AXIFM_REG:
                if para in parameter_dict:
                    width = parameter_dict[para]
                    for reg_name in ZU_AXIFM_REG[para]:
                        addr = ZU_AXIFM_REG[para][reg_name]['addr']
                        f = ZU_AXIFM_REG[para][reg_name]['field']
                        Register(addr)[f[0]:f[1]] = ZU_AXIFM_VALUE[width]

    def download(self, bitstream, parser=None):
        if parser is None:
            from .xclbin_parser import XclBin
            parser = XclBin(xclbin_data=DEFAULT_XCLBIN)

        if not bitstream.binfile_name:
            _preload_binfile(bitstream, parser)

        if not bitstream.partial:
            self.shutdown()
            flag = 0
        else:
            flag = 1

        with open(self.BS_FPGA_MAN_FLAGS, 'w') as fd:
            fd.write(str(flag))
        with open(self.BS_FPGA_MAN, 'w') as fd:
            fd.write(bitstream.binfile_name)

        self.set_axi_port_width(parser)

        self._xrt_download(parser.xclbin_data)
        super().post_download(bitstream, parser)

    def get_bitfile_metadata(self, bitfile_name):
        parser = _get_bitstream_handler(bitfile_name).get_parser()
        if parser is None:
            raise RuntimeError("Unable to find metadata for bitstream")
        return parser
