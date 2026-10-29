#!/usr/bin/env python3
"""Bring-up probe for the e003-adc-board gateware.

Talks to the board's register interface on SPI0 through an FTDI FT232H (or
FT2232H/FT4232H) used as SPI master, via pyftdi, which runs on macOS:

    python3 -m pip install pyftdi
    brew install libusb

    ./e003_probe.py info              identity, hello string, clocks, status
    ./e003_probe.py power on|off      switch the channel supply
    ./e003_probe.py ids               read both converters' ID registers
    ./e003_probe.py raw ADC HEX...    send one frame to ADC 1 or 2, twice
    ./e003_probe.py scan              try the plausible read encodings
    ./e003_probe.py dump              hex dump of registers 0x00 to 0x7F

FT232H wiring: AD0 = SCLK, AD1 = MOSI, AD2 = MISO, AD3 = CS, and GND.
See ../README.md for the register map and the bring-up procedure.
"""

import argparse
import sys
import time

CMD_READ = 0xA5
CMD_WRITE = 0x5A

REG_STATUS = 0x06
REG_CTRL = 0x07
REG_SYNC_KHZ = 0x08
REG_PINS = 0x0B
REG_ADC_STATE = 0x10
REG_IDS = 0x11
REG_RAW_GO = 0x17
REG_RAW_SEL = 0x18
REG_RAW_RX = 0x1D
REG_ID_RESP = (0x20, 0x30)
REG_HELLO = 0x40

CTRL_SUPPLY = 0x01
CTRL_CRC = 0x02
CTRL_ID_READ = 0x04
CTRL_CLEAR_FAULT = 0x08

STATUS_BITS = [
    "SUPPLY_EN", "SUPPLY_FAULT", "FAULT_STICKY", "ID_VALID",
    "RAW_BUSY", "RAW_DONE", "SYNC_CLK_OK", "ADC_READY",
]
PIN_BITS = [
    "SYNC_START", "ADC1_FSYNC", "ADC1_DOUT", "ADC1_SDO",
    "ADC2_FSYNC", "ADC2_DOUT", "ADC2_SDO", "ADC_FLT_N",
]
ADC_STATES = ["OFF", "POWER", "RESET", "ID", "READY", "RAW"]


def crc8(data, poly=0x07, init=0xFF):
    """CRC-8 as e003_pkg.crc8 computes it."""
    crc = init
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = ((crc << 1) ^ poly) & 0xFF if crc & 0x80 else (crc << 1) & 0xFF
    return crc


def flags(value, names):
    return " ".join(name for i, name in enumerate(names) if value >> i & 1) or "-"


class Board:
    def __init__(self, url, freq):
        from pyftdi.spi import SpiController

        self._ctrl = SpiController()
        self._ctrl.configure(url)
        self._port = self._ctrl.get_port(cs=0, freq=freq, mode=0)

    def read(self, addr, n):
        out = bytes([CMD_READ, addr, 0x00]) + bytes(n)
        return bytes(self._port.exchange(out, duplex=True))[3:]

    def write(self, addr, data):
        self._port.exchange(bytes([CMD_WRITE, addr]) + bytes(data), duplex=True)

    def read1(self, addr):
        return self.read(addr, 1)[0]

    def wait_status(self, mask, timeout=1.0):
        t0 = time.monotonic()
        while True:
            status = self.read1(REG_STATUS)
            if status & mask == mask:
                return status
            if time.monotonic() - t0 > timeout:
                raise TimeoutError(f"STATUS = 0x{status:02X} ({flags(status, STATUS_BITS)})")
            time.sleep(0.005)

    def raw(self, adc, frame, nbits):
        """Send one frame to ADC 1 or 2 and return the 3 bytes clocked out of SDO."""
        tx = (bytes(frame) + bytes(3))[:3]
        self.write(REG_RAW_SEL, bytes([adc - 1, nbits]) + tx)
        self.write(REG_RAW_GO, b"\x00")
        self.wait_status(0xA0)
        return self.read(REG_RAW_RX, 3)


def cmd_info(board, _args):
    ident = board.read(0x00, 16)
    magic = ident[0:4].decode("ascii", "replace")
    build = int.from_bytes(ident[12:16], "big")
    hello = board.read(REG_HELLO, 64).split(b"\x00")[0].decode("ascii", "replace")
    khz = int.from_bytes(ident[8:10], "big")
    print(f"magic      {magic!r}  ({'ok' if magic == 'E003' else 'WRONG: check wiring and SPI mode 0'})")
    print(f"version    {ident[4]}.{ident[5]}")
    dirty = " (uncommitted changes)" if build >> 28 & 1 else ""
    print(f"build      {build & 0x0FFFFFFF:07x}{dirty}")
    print(f"hello      {hello!r}")
    print(f"SYNC_CLK   {khz} kHz (nominal 8192, +-5.5 % from the FPGA's oscillator)")
    print(f"status     0x{ident[6]:02X}  {flags(ident[6], STATUS_BITS)}")
    print(f"ctrl       0x{ident[7]:02X}")
    print(f"pins       0x{ident[11]:02X}  high: {flags(ident[11], PIN_BITS)}")
    state = board.read1(REG_ADC_STATE)
    print(f"adc state  {ADC_STATES[state] if state < len(ADC_STATES) else state}")
    board.write(0x0A, b"\x5A")
    scratch = board.read1(0x0A)
    board.write(0x0A, b"\xA5")
    scratch2 = board.read1(0x0A)
    print(f"scratch    {'ok' if (scratch, scratch2) == (0x5A, 0xA5) else 'FAILED: writes do not arrive'}")


def cmd_power(board, args):
    ctrl = board.read1(REG_CTRL)
    if args.state == "on":
        board.write(REG_CTRL, bytes([ctrl | CTRL_SUPPLY | CTRL_CLEAR_FAULT]))
        print("channel supply on; converters leave reset after 20 ms and are read after 30 ms")
    else:
        board.write(REG_CTRL, bytes([ctrl & ~CTRL_SUPPLY & 0xFF]))
        print("channel supply off")


def cmd_ids(board, args):
    ctrl = board.read1(REG_CTRL)
    if not ctrl & CTRL_SUPPLY:
        print("channel supply is off: run `power on` first", file=sys.stderr)
        return 1
    ctrl = (ctrl | CTRL_ID_READ) & ~CTRL_CRC & 0xFF
    if args.crc:
        ctrl |= CTRL_CRC
    board.write(REG_CTRL, bytes([ctrl]))
    time.sleep(0.01)
    board.wait_status(0x88)
    ids = board.read(REG_IDS, 4)
    for adc in (1, 2):
        resp = board.read(REG_ID_RESP[adc - 1], 9)
        frames = " | ".join(resp[i:i + 3].hex(" ") for i in (0, 3, 6))
        print(f"ADC{adc}: DEV_ID 0x{ids[2 * adc - 2]:02X}  REV_ID 0x{ids[2 * adc - 1]:02X}"
              f"   raw frames 0..2: {frames}")
    status = board.read1(REG_STATUS)
    print(f"status 0x{status:02X}  {flags(status, STATUS_BITS)}")
    return 0


def cmd_raw(board, args):
    frame = bytes.fromhex("".join(args.hex))
    if args.crc:
        frame = frame[:2] + bytes([crc8(frame[:2])])
    nbits = args.bits or 8 * len(frame)
    print(f"ADC{args.adc} tx {frame.hex(' ')} ({nbits} bits)")
    for i in range(2):
        rx = board.raw(args.adc, frame, nbits)
        print(f"  frame {i}: rx {rx.hex(' ')}")


def cmd_scan(board, args):
    """Read DEV_ID and REV_ID with each plausible command encoding."""
    encodings = {
        "0x80|addr (gateware default)": lambda a: 0x80 | a,
        "0x40|addr (ADS127L11 style)": lambda a: 0x40 | a,
        "0x00|addr": lambda a: a,
    }
    for adc in args.adcs:
        print(f"ADC{adc}")
        for name, enc in encodings.items():
            for crc in (False, True):
                rows = []
                for addr in (0x00, 0x01):
                    frame = bytes([enc(addr), 0x00])
                    if crc:
                        frame += bytes([crc8(frame)])
                    nbits = 8 * len(frame)
                    board.raw(adc, frame, nbits)
                    rx = board.raw(adc, frame, nbits)
                    rows.append(f"reg {addr:02X} -> {rx.hex(' ')}")
                print(f"  {name:32s} {'crc' if crc else '16b'}:  " + "   ".join(rows))


def cmd_dump(board, _args):
    data = board.read(0x00, 0x80)
    for base in range(0, 0x80, 16):
        row = data[base:base + 16]
        text = "".join(chr(b) if 32 <= b < 127 else "." for b in row)
        print(f"{base:02X}: {row.hex(' ')}  {text}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--url", default="ftdi://ftdi:232h/1", help="pyftdi device URL")
    parser.add_argument("--freq", type=float, default=1e6, help="SPI clock in Hz (default 1 MHz)")
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("info")
    p = sub.add_parser("power")
    p.add_argument("state", choices=("on", "off"))
    p = sub.add_parser("ids")
    p.add_argument("--crc", action="store_true", help="24-bit frames with CRC")
    p = sub.add_parser("raw")
    p.add_argument("adc", type=int, choices=(1, 2))
    p.add_argument("hex", nargs="+", help="frame bytes, e.g. 80 00")
    p.add_argument("--bits", type=int, help="frame length, default 8 per byte")
    p.add_argument("--crc", action="store_true", help="append the CRC of the first two bytes")
    p = sub.add_parser("scan")
    p.add_argument("adcs", type=int, nargs="*", default=[1, 2])
    sub.add_parser("dump")
    args = parser.parse_args()

    board = Board(args.url, args.freq)
    handler = {
        "info": cmd_info, "power": cmd_power, "ids": cmd_ids,
        "raw": cmd_raw, "scan": cmd_scan, "dump": cmd_dump,
    }[args.cmd]
    return handler(board, args) or 0


if __name__ == "__main__":
    sys.exit(main())
