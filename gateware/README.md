# e003-adc-board bring-up gateware

A first VHDL design for the board's FPGA, a Lattice LCMXO2-4000HC-4QN84C
(U50), with just enough logic to show that a new board works:

- **Hello world.** A register interface on the host SPI lane (SPI0) returns
  an identifier (`E003`), a version, the git hash it was built from and the
  string `Hello, world! e003-adc-board gateware`.
- **Clocks.** It runs from the FPGA's internal oscillator and measures
  `SYNC_CLK` against it, so a missing or wrong stack clock shows up.
- **Converters.** When the host asks, it turns on the channel supply (the
  TPS25200 eFuse, U11), releases both ADS127L14s (U9, U45) from reset and
  reads their device ID and revision ID registers. The raw responses are kept
  next to the decoded IDs.
- **Raw access.** The host can send any frame of up to 24 bits to either
  converter and read the reply, so the converter's SPI protocol can be pinned
  down on the bench without rebuilding the gateware.

It does not configure the converters, start conversions, close any channel
switch, or use the golden-image flash or the user flash. The converters keep
their reset state, in which their GPIO pins are off, so every channel stays
off (GW-2). Those features, GW-1 to GW-15 in the design summary, come later.

## Workflow

Everything that builds runs in one Docker container; everything that touches
hardware or a screen runs natively on the Mac:

| Step | Tool | Where |
|---|---|---|
| Simulation | GHDL | Container |
| Synthesis | Lattice Diamond: LSE, or Synplify Pro | Container |
| Translate, map, place and route, timing | Lattice Diamond | Container |
| Bitstream (`.bit`, SRAM) and JEDEC (`.jed`, flash and feature row) | Lattice Diamond | Container |
| Waveform viewing | Surfer or GTKWave | Mac |
| Programming over JTAG, J-Link on the Tag-Connect (Z2) | openFPGALoader | Mac |
| Bench probe, FT232H as SPI master | Python and pyftdi | Mac |

The container is `linux/amd64`, because Diamond is x86-64 Linux software. On
Apple silicon, Docker Desktop runs it under Rosetta. It holds Diamond and
GHDL (Ubuntu's package) and nothing else. The Makefile starts it for you: on
the Mac, `make sim` and `make build` run `docker/run make ...`, which mounts
the repository into the container, so results land in `gateware/build/` where
the native tools pick them up. The build ID comes from git inside the
container, so a build always names the commit it was built from.

Diamond's licence does not allow redistribution, so the image is built on
each machine from that machine's own copy of the installer, and must never
be pushed to a public registry.

## Status: what has and has not been checked

This version was written without Diamond, GHDL or the converter's datasheet
to hand, so it has **not** yet been simulated or built. Run `make sim` and
`make build` first and expect to fix small things. Each fact below was taken
from something other than a primary source and is marked `VERIFY` where it
sits:

| What | Assumed | Where | How to check |
|---|---|---|---|
| ADS127L14 register-read command | `0x80 \| address` in byte 0, any byte 1 | `C_ADC_CMD_RREG` in `rtl/e003_pkg.vhd` | Datasheet, "SPI commands"; `e003_probe.py scan` on hardware |
| ADS127L14 SPI frame | 16 bits after reset (CRC off); 24 bits with CRC-8 (poly 0x07, seed 0xFF) once enabled | `C_ADC_CRC_*`; `CTRL.ADC_CRC` | Datasheet, CRC section; `scan` tries both |
| Where read data comes back | First byte of the **next** frame | `C_ADC_RESP_BYTE`; all raw bytes are kept | Raw responses at 0x20 and 0x30 |
| ADS127L14 ID addresses | DEV_ID at 0x00, REV_ID at 0x01 | `C_ADC_REG_DEV_ID`, `C_ADC_REG_REV_ID` | Datasheet, register map |
| ADS127L14 register access without CLKIN | Works, from the internal oscillator after reset | — | If IDs read as 00 or FF without `SYNC_CLK`, supply 8.192 MHz |
| ADS127L14 SPI mode | Mode 1 (TI E2E answer for this part) | `rtl/adc_spi_master.vhd` | Datasheet, timing diagram |
| Host command bytes 0xA5 and 0x5A | Not MachXO2 sysCONFIG commands (GW-13) | `C_HOST_CMD_*` | FPGA-TN-02155, command table |
| Diamond batch commands | `prj_project new … -synthesis … -lpf …`, `prj_run Synthesis/Translate/Map/PAR/Export` | `diamond/build.tcl` | First `make build`; Diamond's Tcl reference |
| `SYSCONFIG` and `BLOCK` keywords | As written | `constraints/e003_top.lpf` | First `make build`; Diamond's preference reference |
| Diamond's libraries in Ubuntu 22.04 | The packages in the Dockerfile | `docker/Dockerfile` | `make image` prints any library still missing |
| openFPGALoader drives a J-Link | Yes, as cable `jlink` | `Makefile` | `openFPGALoader --list-cables` |
| Tag-Connect TC2030-IDC-NL | Pad *n* lands on pin *n* of its 6-pin IDC socket | [Wiring](#wiring-the-j-link-to-the-tag-connect-cable) | Continuity meter, before first use |

The pinout is not in this list: it was taken from the pad nets of U50 in
`e003-adc-board.kicad_pcb`, so it matches the schematic as drawn.

## Contents

```
gateware/
├── Makefile                  container targets (sim, build) and native ones (prog, wave, ...)
├── constraints/
│   ├── e003_top.lpf          Diamond preferences: sysCONFIG, banks, timing, pins
│   └── e003_top.ldc          clocks for LSE, which does not read the LPF
├── diamond/build.tcl         Diamond batch flow, run by `make build`
├── docker/
│   ├── Dockerfile            the build image: Diamond and GHDL
│   ├── entrypoint.sh         puts Diamond on the PATH
│   ├── install-diamond.sh    installs Diamond from a .run or .rpm, at image build
│   ├── carve-7z.py           cuts the component archives out of a Qt installer
│   ├── run                   runs a command in the container
│   ├── installer/            put the Diamond for Linux installer here (not in git)
│   └── license/              put the Diamond licence here (not in git)
├── rtl/
│   ├── e003_pkg.vhd          constants (including every VERIFY item), CRC-8, hello string
│   ├── e003_top.vhd          top level and register file
│   ├── host_spi_slave.vhd    host SPI peripheral, SPI mode 0, runs on SCLK
│   ├── adc_ctrl.vhd          channel supply, converter reset, ID read, raw frames
│   ├── adc_spi_master.vhd    SPI controller for one ADS127L14, SPI mode 1
│   └── clk_meter.vhd         SYNC_CLK frequency in kHz
├── sim/
│   ├── tb_e003_top.vhd       self-checking testbench (VHDL-2008)
│   ├── adc_model.vhd         behavioural ADS127L14 register port
│   └── lattice_prims.vhd     stand-ins for the MachXO2 primitives (OSCH, GSR)
└── tools/e003_probe.py       bench probe: FT232H as SPI master, via pyftdi
```

The RTL keeps to VHDL-93, so both of Diamond's synthesis engines read it
without a language switch; the testbench uses VHDL-2008, which only GHDL
reads.

## Setting up a Mac (once)

### 1. Docker Desktop

Install [Docker Desktop](https://www.docker.com/products/docker-desktop/).
On Apple silicon, open Settings → General and turn on **Use Rosetta for
x86_64/amd64 emulation on Apple Silicon**: Diamond is x86-64 software, and
without Rosetta Docker falls back to QEMU, which is many times slower and
not something Diamond is known to survive. Under Settings → Resources, give
it at least 4 GB of memory and 20 GB of disk; the image is several GB.

### 2. Lattice Diamond for Linux

1. Make an account at [latticesemi.com](https://www.latticesemi.com), then
   download **Lattice Diamond for Linux** from the Diamond software page:
   3.14 is a `.run` installer (`3.14.0.75.2_Diamond_lin.run`), earlier
   releases an `.rpm`; either works. The Linux build is the one wanted even on
   a Mac: it runs in the container.
2. Put the installer, and only that one, in `gateware/docker/installer/`, as
   the file itself rather than a symbolic link. Not `gateware/diamond/`,
   which holds the build script. Git ignores installers anywhere in the
   repository.

### 3. The Diamond licence

Diamond's free licence is node-locked to a network MAC address. The
container has its own network interface, so lock the licence to a MAC that
belongs to the container rather than to the Mac: then the same licence works
on any machine that builds the image.

1. Make up a locally administered MAC address, which can never clash with a
   real network card:

   ```bash
   printf '02%s\n' "$(openssl rand -hex 5)"
   ```

   This prints twelve hex digits starting with `02`, for example
   `02a3f19c0e7b`.

2. On the Lattice website, request a free Diamond licence (Licensing → Diamond
   free licence) and give those twelve digits as the host ID. Lattice emails
   `license.dat`.
3. Save it in `gateware/docker/license/`, as `license.dat` or under any
   name ending `.dat` or `.lic` if it is the only file there. Git ignores it.

`docker/run` reads the `HOSTID=` from the licence and starts the container
with that MAC address. To keep the licence elsewhere, set `DIAMOND_LICENSE`
to its path; to override the MAC, set `DIAMOND_MAC=02:a3:f1:9c:0e:7b`.

### 4. The build image

From `gateware/`:

```bash
make image
```

This installs Diamond into a `linux/amd64` Ubuntu 22.04 image and adds GHDL.
It takes ten minutes or more, mostly unpacking, during which the installer
can print nothing for minutes at a time. For every line of output instead
of Docker's usual display, saved to a log as well:

```bash
make image PROGRESS=plain 2>&1 | tee image.log
``` The installer is mounted for
the build only, so it does not end up as a layer of the image.
`docker/install-diamond.sh` unpacks an `.rpm` without running its scripts.
Diamond 3.14's `.run` is built with Qt Installer Framework 2.0, which cannot
install without a display, so the script cuts the component archives out of
the file (`docker/carve-7z.py`) and unpacks them with 7-Zip into the image,
which is all that installer's own install step does. It leaves out the
QuestaSim component, since simulation uses GHDL; build with
`DIAMOND_KEEP_QUESTA=1` set in the Dockerfile's install step to keep it.
Other `.run` installers (makeself, InstallBuilder, install4j) are run
unattended with their own options. If it reports `Unrecognised installer`,
or the install fails, run

```bash
make installer-info
```

which describes the installer and prints its own `--help`, without
installing anything, and send the output: the right options then go into
`install-diamond.sh`. If the build
prints `warning: … not found` for a library, note it: it matters only if
`make build` later fails with "error while loading shared libraries", and
the fix is to add the package that provides it to `docker/Dockerfile`.

A new Diamond release means its installer in `docker/installer/` in place of
the old one, and `make image` again.

### 5. Native tools

From [Homebrew](https://brew.sh):

```bash
brew install openfpgaloader libusb
```

For waveforms, install [Surfer](https://surfer-project.org) (the default
`WAVE_VIEWER`) or GTKWave; both read the `.fst` files the simulation writes.
With GTKWave, use `make wave WAVE_VIEWER=gtkwave`.

For the bench probe, a Python environment with pyftdi:

```bash
python3 -m venv ~/.venvs/e003 && ~/.venvs/e003/bin/pip install pyftdi
```

Check that openFPGALoader knows the J-Link:

```bash
openFPGALoader --list-cables | grep -i jlink
```

If the cable's name is not `jlink`, pass the name it shows as `CABLE=...` to
the programming targets.

## Building

From `gateware/`. Both commands start the container themselves.

```bash
make sim
```

Analyses the RTL and the testbench with GHDL and runs the simulation, about
5 ms of simulated time. The testbench reads every register the bring-up uses,
measures `SYNC_CLK`, turns the supply on and checks the IDs that two model
converters return, in 16-bit and 24-bit CRC frames, then a raw transfer and
the fault flag. It ends with:

```
tb_e003_top: PASS
```

or stops at the first failed check with what it got and what it expected.
The model converters implement the protocol that `e003_pkg.vhd` assumes, so a
pass shows that the gateware does what the package says, not that the
package is right about the ADS127L14. View the waveforms natively:

```bash
make wave
```

```bash
make build
```

Runs Diamond's whole flow in batch, from a project created afresh in
`build/diamond/` by `diamond/build.tcl`: synthesis with LSE, translate, map,
place and route, timing analysis, then the bitstream and the JEDEC file. The
results are:

| File | Contents |
|---|---|
| `build/e003_top.bit` | SRAM bitstream, for `make prog` |
| `build/e003_top.jed` | Flash image, including the feature row, for `make prog-flash` |
| `build/reports/*.mrp` | Map report: resources used, of 4320 LUTs |
| `build/reports/*.par` | Place-and-route report |
| `build/reports/*.twr` | Timing report: every constraint must be met |
| `build/diamond.log` | Diamond's full output |

The build ends with a summary of the resources used and of the routed
design's timing, both read from Diamond's reports; `Timing errors: 0 (setup),
0 (hold)` is what to look for. The first image used 1263 of 4320 LUTs and
met timing with 28 ns of slack. Neither synthesis nor map should report
using a signal as the global set/reset (GSR): the design has no asynchronous
reset, and holds its GSR instance inactive.

A few warnings are expected and harmless:

- *The SN pin is not available for use as a general purpose I/O pin when the
  SLAVE_SPI_PORT attribute is enabled.* The slave SPI port is enabled on
  purpose (GW-8), and the board's chip select drives SN.
- *Bit 0 of Register u_meter/khz_q is stuck at Zero.* The SYNC_CLK
  measurement counts in steps of 2 kHz.
- *The following clock signals will be routed by using generic routing
  resource*, for `SYNC_CLK`. Only the frequency counter uses it as a clock
  here, so skew does not matter. It will once the converters run from it
  (OI-7). To use Synplify Pro instead of LSE:

```bash
make build SYNTH=synplify
```

The build ID changes only with a commit, so commit before building an image
you intend to keep. A build from uncommitted changes sets bit 28 of the build
ID, and the probe reports it.

For anything else in the container, such as Diamond's own tools or a shell to
look around:

```bash
make shell
```

## Programming

The FPGA has two places to hold a design: SRAM, which runs the design at
once and loses it at power-off, and internal flash, from which it configures
itself at every power-up. Use SRAM while bringing the board up; it cannot
leave the board in a state worse than blank.

### Wiring the J-Link to the Tag-Connect cable

Z2 is a Tag-Connect TC2030 footprint, reached by a **TC2030-IDC-NL** cable,
which ends in a 6-way 0.1" IDC socket. The J-Link PLUS Compact has a 10-way
0.05" Cortex-M connector. They need an adapter: either a 0.05" to 0.1"
breakout board on the J-Link side with six jumper wires, or a short
hand-made harness.

| TC2030 pad / IDC pin | Board net | Signal | J-Link 10-pin 0.05" |
|---|---|---|---|
| 1 | `3V3_LIM` | VTref, target reference | 1 VTref |
| 2 | `/fpga/TMS` | TMS | 2 SWDIO/TMS |
| 3 | `/fpga/TDI` | TDI | 8 TDI |
| 4 | `/fpga/TCK` | TCK, 4.7 kΩ to GND on the board | 4 SWCLK/TCK |
| 5 | `GND` | Ground | 3 GND (or 5, or 9) |
| 6 | `/fpga/TDO` | TDO | 6 SWO/TDO |
| — | — | — | 7 key, 10 nRESET: not connected |

Before connecting the board for the first time, check every wire with a
continuity meter from J-Link pin to the matching Tag-Connect pogo pin. Do not
use a TC2030-**CTX** cable: it follows the Cortex-M pinout, which puts pad 3
on nRESET (pin 10) and leaves TDI unconnected. The footprint's pad names in
the PCB (`SWDIO`, `~{RESET}`, `SWCLK`, `SWO`) come from that Cortex-M
pattern; the signals on them are the JTAG ones in the table.

The J-Link senses the board's 3.3 V on VTref and drives its outputs at that
level. It does not power the board.

### Bench setup for the first power-up

The stack connector is still to be chosen (OI-2), so until it is fitted, wire
to the nets below on the board. Each line enters through the SN74LVC244A
buffer U22.

| Interconnect signal | Board net | Connect to |
|---|---|---|
| 3V3 | `3V3` | Bench supply, 3.3 V, current limit about 200 mA (the board limits its own draw to 150 mA in U21, a TPS2553) |
| 5V | `5V` | Bench supply, 5.0 V, current limit about 300 mA; feeds only the channels, through U11 |
| 24V | `24V` | **Leave off** for the first power-up. Only the sensors' excitation uses it |
| GND | `GND` | Supplies, J-Link (through Z2) and SPI master |
| SPI0_CSx | `/INT_CS0` … `/INT_CS3` | SPI master CS, on the position whose 0 Ω is fitted (R14 = CS0, R15 = CS1, R16 = CS2, R30 = CS3), **with a 10 kΩ pull-up to 3.3 V** |
| SPI0_SCLK | `/INT_SCLK` | SPI master SCLK |
| SPI0_MOSI | `/INT_MOSI` | SPI master MOSI |
| SPI0_MISO | `/INT_MISO` | SPI master MISO (through R70, 62 Ω) |
| SYNC_START | `/INT_START` | 3.3 V through 10 kΩ: it idles high |
| SYNC_CLK | `/INT_CLK` | 8.192 MHz, 3.3 V CMOS, if available; otherwise GND, so the buffer input does not float |

The pull-up on the chip select matters. The board's reconfiguration timer
(GW-9) pulls the FPGA's PROGRAMN low whenever the chip select stays low for
0.2 to 0.9 s, and holds the FPGA in reset until the chip select has been high
for about 6 ms. A chip select that floats or sits low therefore keeps the
FPGA from ever configuring, and if it goes low for a second later on, the
FPGA reloads from its (still empty) flash and the design loaded into SRAM is
gone. The pull-up keeps it high before the SPI master starts driving.

The bench probe uses an FTDI FT232H board (for example Adafruit 2264) as SPI
master: AD0 to SCLK, AD1 to MOSI, AD2 to MISO, AD3 to CS, GND to GND. Any
other SPI master works too: see [Host SPI protocol](#host-spi-protocol).

### Loading the design

1. Power the board: 3.3 V first, then 5 V. With the gateware not yet loaded,
   the 3.3 V supply should draw a few mA.
2. Connect the J-Link to the Mac by USB, and the Tag-Connect cable to Z2.
   The cable's legs click into the three holes around the footprint and hold
   it; press the plain NL version on by hand while programming.
3. Check the JTAG chain:

   ```bash
   make detect
   ```

   It must report IDCODE `0x012BC043`, the LCMXO2-4000HC. Nothing, or all
   ones or all zeros, means a wiring, VTref or power problem. A device that
   answers but will not configure usually means PROGRAMN is low: check the
   chip select.

4. Load the design into SRAM:

   ```bash
   make prog
   ```

   The design starts as soon as the load completes.

5. Once the bring-up below passes, write it to the internal flash so it
   survives a power cycle:

   ```bash
   make prog-flash
   ```

   This erases and rewrites the configuration flash and the feature row,
   which takes the `SYSCONFIG` settings of the LPF: JTAG and PROGRAMN
   enabled, the slave SPI port enabled, the master SPI port and I2C
   disabled. JTAG stays enabled in every image, so a bad image can always be
   replaced over the Tag-Connect. The golden image (GW-8) is not part of this
   yet.

`make prog JTAG_HZ=6000000` and so on raises the JTAG clock once the 1 MHz
default has proved reliable. Neither programming step needs SEGGER's own
software, but quit J-Link Commander or J-Flash if they are open, since only
one program can hold the probe.

## Bring-up procedure

With the design loaded and the FT232H connected, from `tools/`:

```bash
~/.venvs/e003/bin/python e003_probe.py info
```

1. **Hello world.** `magic 'E003'`, version 0.1, the build hash and the hello
   string prove the host SPI lane, the bus buffer and the FPGA's I/O in both
   directions, and `scratch ok` proves that writes arrive. All zeros or all
   ones point at MISO, the chip select or a wrong SPI mode; this interface is
   SPI mode 0. The probe defaults to 1 MHz; try `--freq 10e6` and then
   `--freq 18.75e6` (the master's rate, INT-7) once it works.
2. **Clock.** With 8.192 MHz on `SYNC_CLK`, `SYNC_CLK` reads 8192 kHz to within
   the internal oscillator's ±5.5 %, and the status shows `SYNC_CLK_OK`. With
   no clock it reads 0.
3. **Channel supply.** Measure the channels' rails, then:

   ```bash
   ~/.venvs/e003/bin/python e003_probe.py power on
   ```

   `ADC_EN` goes high, the 5 V draw rises by the channels' quiescent current,
   and `+1V8_CH`, `+2V5_CH` and `-2V5_CH` come up. The status shows
   `SUPPLY_EN` and no `SUPPLY_FAULT`; `FAULT_STICKY` means the eFuse reported
   a fault at some point since the last clear.
4. **Converter IDs.** About 30 ms after the supply comes on, the gateware has
   read both converters:

   ```bash
   ~/.venvs/e003/bin/python e003_probe.py ids
   ```

   prints each converter's DEV_ID and REV_ID, and the three raw response
   frames they were taken from. The two converters should return the same
   values, and they should match the datasheet's reset values for the
   ADS127L14. If they read 00 or FF, or differ from the datasheet:

   ```bash
   ~/.venvs/e003/bin/python e003_probe.py scan
   ```

   sends register reads of addresses 0x00 and 0x01 with each plausible
   command encoding, with and without CRC, and prints what comes back. The
   encoding whose responses show the datasheet's ID values is the right one;
   set `C_ADC_CMD_RREG` and, if needed, `C_ADC_RESP_BYTE` to match, and
   update `sim/adc_model.vhd` with them. `raw` sends any single frame:

   ```bash
   ~/.venvs/e003/bin/python e003_probe.py raw 1 80 00 --crc
   ```

5. **Supply off** before disconnecting: `e003_probe.py power off`.

### Troubleshooting

| Symptom | Likely cause |
|---|---|
| `make detect` finds nothing | VTref unpowered, Tag-Connect not seated, TDI/TDO swapped, cable not `jlink` |
| IDCODE right, `make prog` fails or design never starts | PROGRAMN low: chip select floating or low |
| Probe reads all 0xFF | MISO not driven: chip select not reaching U22 pin 2, or R70 open |
| Probe reads all 0x00 or shifted data | Wrong SPI mode (must be 0), or SCLK/MOSI swapped |
| `scratch FAILED`, reads fine | MOSI not arriving: U22 group 2 disabled, or R206 open |
| `SYNC_CLK` 0 with a clock applied | U22 pin 4 to pin 16 path, or clock not 3.3 V CMOS |
| `SUPPLY_FAULT` at power on | Short on the channel 5 V, or a channel regulator in trouble; turn the supply off |
| IDs 00 with SDO stuck low in `pins` | Converter not powered or still in reset; check `+1V8_CH` and the RESET line |
| Design vanishes after a while | Chip select held low for ~1 s, which reloads the FPGA from flash |

And for the build container:

| Symptom | Likely cause |
|---|---|
| `make image`: "Put exactly one Diamond for Linux installer" | No `.run` or `.rpm`, or more than one, in `docker/installer/`; `make image` names any it finds elsewhere |
| `make image`: "Unrecognised installer", or the install step fails | Run `make installer-info` and send the output |
| `make sim`/`build`: "image 'e003-gateware' not found" | Run `make image` first |
| Diamond: licence or "invalid host" errors | Licence not in `docker/license/`, or its HOSTID is not the MAC the container got; check `DIAMOND_MAC` |
| Diamond: "error while loading shared libraries" | A library missing from the image: add its Ubuntu package to `docker/Dockerfile`, `make image` |
| Very slow builds or crashes on Apple silicon | Rosetta emulation off in Docker Desktop, so QEMU is in use |
| Diamond rejects a preference | A `SYSCONFIG` or `BLOCK` keyword this Diamond version spells differently; see its preference reference |

## Host SPI protocol

The board is an SPI peripheral in **mode 0** (SCLK idles low, data sampled on
the rising edge), MSB first, up to 20 MHz. Each frame starts with the chip
select falling and ends with it rising.

```
Read:   CS↓  0xA5  addr  dummy  [data(addr)]  [data(addr+1)]  ...  CS↑
Write:  CS↓  0x5A  addr  data(addr)  data(addr+1)  ...             CS↑
```

The address increments after every data byte. The board returns zeros during
the command, address and dummy bytes. Byte 0 is never a MachXO2 sysCONFIG
command, because the configuration port shares the chip select (GW-13).
Multi-byte values are big-endian; a value that the board may be changing
(`SYNC_KHZ`, the raw responses during a transfer) can be torn by a read, so
read it twice and compare.

## Register map

| Address | Name | Access | Contents |
|---|---|---|---|
| 0x00–0x03 | MAGIC | R | `E003` in ASCII |
| 0x04 | VERSION_MAJOR | R | 0 |
| 0x05 | VERSION_MINOR | R | 1 |
| 0x06 | STATUS | R | bit 0 SUPPLY_EN, 1 SUPPLY_FAULT (eFuse fault now), 2 FAULT_STICKY, 3 ID_VALID, 4 RAW_BUSY, 5 RAW_DONE, 6 SYNC_CLK_OK (within ±10 % of 8.192 MHz), 7 ADC_READY |
| 0x07 | CTRL | R/W | bit 0 SUPPLY_EN: channel supply on. bit 1 ADC_CRC: 24-bit frames with CRC for the ID read, else 16-bit. Write-only: bit 2 ID_READ re-reads the IDs, bit 3 clears FAULT_STICKY |
| 0x08–0x09 | SYNC_KHZ | R | `SYNC_CLK` in kHz, updated every 1 ms, 0 if absent |
| 0x0A | SCRATCH | R/W | Free; for testing writes |
| 0x0B | PINS | R | Live levels: bit 0 SYNC_START, 1 ADC1 FSYNC, 2 ADC1 DOUT, 3 ADC1 SDO, 4 ADC2 FSYNC, 5 ADC2 DOUT, 6 ADC2 SDO, 7 ADC_FLT (high = no fault) |
| 0x0C–0x0F | BUILD_ID | R | Bits 27 to 0: short git hash of the build, 0 if built outside git. Bit 28: built with uncommitted changes in `gateware/` |
| 0x10 | ADC_STATE | R | 0 off, 1 powering, 2 reset released, 3 reading IDs, 4 ready, 5 raw transfer |
| 0x11 | ADC1_DEV_ID | R | Byte `C_ADC_RESP_BYTE` of ADC1's response to frame 1 |
| 0x12 | ADC1_REV_ID | R | … of its response to frame 2 |
| 0x13 | ADC2_DEV_ID | R | As 0x11, for ADC2 |
| 0x14 | ADC2_REV_ID | R | As 0x12, for ADC2 |
| 0x17 | RAW_GO | W | Any write sends RAW_TX to the converter in RAW_SEL. Ignored unless ADC_READY |
| 0x18 | RAW_SEL | R/W | 0 ADC1, 1 ADC2 |
| 0x19 | RAW_LEN | R/W | Frame length in bits, 1 to 24; 0 means 24. Reset value 24 |
| 0x1A–0x1C | RAW_TX | R/W | Frame to send, first bit is bit 7 of 0x1A |
| 0x1D–0x1F | RAW_RX | R | What SDO returned during that frame, first bit in bit 7 of 0x1D |
| 0x20–0x28 | ADC1_ID_RESP | R | ADC1's responses to the three ID frames, three bytes each |
| 0x30–0x38 | ADC2_ID_RESP | R | The same for ADC2 |
| 0x40–0x7F | HELLO | R | `Hello, world! e003-adc-board gateware`, NUL padded |

All other addresses read as 0 and ignore writes.

The ID read sends each converter three register reads: DEV_ID, REV_ID and
REV_ID again. If, as assumed, a read's data arrives in the next frame, frame
1's response carries DEV_ID and frame 2's carries REV_ID; if it arrives in
the same frame, frames 0 and 1 carry them instead. Both cases are visible in
the raw responses.

The converter frames run at about 1 MHz, a quarter of the 4 MHz the design
summary plans, for margin at bring-up (`C_ADC_SPI_HALF_CYCLES`).

## Design notes

- **Host SPI pins.** The lane reaches the FPGA twice: on the configuration
  port's dedicated pins (SN, SI, SO, CCLK) and on general-purpose pins (PB7B
  chip select, PB13A clock, PB13B MOSI, PB20A MISO). The slave SPI port stays
  enabled, as GW-8 requires, and owns the dedicated pins; the design serves
  the lane on the second copy with its own SPI logic, and drives MISO only
  while its chip select is low (INT-4). The configuration port also sees
  every frame, so the command bytes 0xA5 and 0x5A are chosen not to be
  configuration commands (GW-13), and it should ignore them and leave SO
  undriven. Whether it does is one of the points OI-9 asks the first board to
  confirm. If the probe reads garbage that the design cannot explain, set
  `SLAVE_SPI_PORT=DISABLE` in the LPF and rebuild: that is the fallback OI-9
  describes. Moving to Diamond also makes the hardened SPI block (the EFB)
  available for a later image.
- **Clocks.** The design runs from OSCH at 24.18 MHz. The host SPI logic runs
  on the host's SCLK, so it needs no oversampling and keeps up at 18.75 MHz.
  `SYNC_CLK` enters on PCLKT0_1 and is forwarded to both converters' CLKIN.
  START stays low, so neither converter converts.
- **Converter lines.** Banks 1 and 4 run from `+1V8_CH`, which is off until
  the supply is on. The gateware holds every converter output idle (CS high,
  SCLK low, RESET low) whenever the supply is off, so nothing is driven into
  a converter as it powers up.
- **Pins left alone.** The golden-image flash's chip select (CSSPIN, held
  high by R208), JTAGENB, INITN and DONE are not used. PROGRAMN keeps its
  configuration function for the reconfiguration timer (GW-9).
