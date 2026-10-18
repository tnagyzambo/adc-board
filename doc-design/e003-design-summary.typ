#import "@local/eng-report:0.6.0": *
#import "gp-channel.typ": board-arch, gp-channel, gp-monitor

// Written by `dcs` from the last commit that touched this file.  It is not
// tracked, so building never dirties the tree and a clean stamp stays true.
#let source-revision = json("assets/git-info.json").display

// A dashed zone round part of a block diagram, titled above its top left
// corner as the template's `group` is.  The title is drawn on a white ground
// above the edges, so an edge entering the zone passes behind it instead of
// through it.  The outer box only stops the title wrapping to the width of the
// zone.
#let zone(..nodes, label: none, inset: 5pt) = node(
  enclose: nodes.pos(),
  place(
    top + left,
    dx: -inset - 2pt,
    dy: -inset - 1.4em,
    box(
      width: 8cm,
      align(
        left,
        box(
          fill: white,
          inset: (x: 2pt, y: 1pt),
          text(fill: ink.mute, label),
        ),
      ),
    ),
  ),
  inset: inset,
  stroke: (paint: ink.rule, thickness: rule.hair, dash: "dashed"),
  fill: none,
  shape: fletcher.shapes.rect,
  snap: false,
  layer: 1,
)

// A configuration switch: what it does, then its requirements, and the type
// and part chosen with the reasons for them.  Each label sits in a column of
// its own, so that the requirements and the choice read apart.
#let switch-entry(function, requirements: none, type: none) = {
  let label(it) = grid.cell(
    inset: (top: 1.6pt),
    caps(it, size: size.tiny, tracking: track.label, fill: ink.mute),
  )
  block(width: 100%, above: gap.block, below: gap.block)[
    #function
    #v(0.9em, weak: true)
    #grid(
      columns: (auto, 1fr),
      column-gutter: 1em,
      row-gutter: 1.1em,
      label("Requirements"), requirements,
      label("Type"), type,
    )
  ]
}

#show: report.with(
  title: [Design Summary],
  subtitle: [ASRP ADC Board],
  number: "e003-adc-board",
  revision: "-",
  date: "2026-10-03",
  organization: "Nonplus",
  foot-note: none,
  authors: (("T. Nagy Zambo", "Design and review"),),
  source-revision: source-revision,
  summary: [
    The ADC board is the analog data acquisition board of the ASRP ECU stack. Each board provides four general-purpose channels with a 2~kHz bandwidth, configurable for load cells, piezoresistive pressure transducers, #box[4–20~mA] transmitters and voltage transmitters. Each channel is isolated from the stack and from eachother. All converters are syncrosized, ensuring each channel is sampled at the same instant. An onboard FPGA collects, processes and buffers the data. Boards can stack to scale the channel count, alongside the #ident("E004-TC-BOARD"), which provides interfaces for thermocouples. Boars to a master ECU MCU board over a dedicated stacking interconnect, which brings power and data paths.
  ],
)

// =============================================================================
//  FRONT MATTER
// =============================================================================

#revision-record((
  "-",
  "2026-10-03",
  [Initial draft.],
  "T. Nagy Zambo",
))

#contents()

#v(gap.section)

#grid(
  columns: (1fr, 1fr),
  column-gutter: 20pt,
  list-of-figures(), list-of-tables(),
)

// =============================================================================
//  BODY
// =============================================================================

= Introduction

== Purpose

The #ident("E003-ADC-BOARD") is the analog data acquisition board of the ECU stack for the Advanced Small Rocket Project (ASRP). Each board carries four general-purpose channels, configurable for load cells, piezoresistive pressure transducers, #box[4–20~mA] transmitters or voltage transmitters. Boards stack to reach the required channel count. The measurements are flight-critical, so the design confines the effect of any fault to as few channels as possible.

The boards connect to the ECU MCU board over #ident("ASRP-PCB-INTERCONNECT-2"), a stacking interconnect defined in this document (@sec-interfaces). It carries the data of all boards in the stack provides and 5~V and 3.3~V rails. This boards is configured by the ECU MCU board which also reads the FPGA's buffered data, and logs it to eMMC.

== Requirements

#figure(
  caption: [Key Requirements],
  datatable(
    columns: (auto, 1fr, auto),
    align: (left, left, left),
    header: ("Identifier", "Requirement", "Source"),
    [REQ-1],
    [Device must be compatible with #ident("ASRP-PCB-INTERCONNECT-2")],
    [Local],
    [REQ-2],
    [Device must fit the 60 × 60~mm ECU stack outline],
    [TBD],
    [REQ-3],
    [Device must draw power only from the 5~V and 3.3~V rails of #ident("ASRP-PCB-INTERCONNECT-2")],
    [Local],
    [REQ-4],
    [Device must be configured and read by the ECU MCU board over #ident("ASRP-PCB-INTERCONNECT-2")],
    [Local],
    [REQ-5],
    [Device must provide four general-purpose analog input channels],
    [Local],
    [REQ-6],
    [Device must sample its general-purpose channels at the same instant as every other converter in the stack],
    [Local],
    [REQ-7],
    [Device must provide each general-purpose channel with a measurement bandwidth of 2~kHz],
    [Local],
    [REQ-8],
    [Device must allow the ECU MCU board to configure each general-purpose channel for a full-bridge load cell, a piezoresistive pressure transducer, a #box[4–20~mA] transmitter or a voltage transmitter],
    [Local],
    [REQ-9],
    [Device must excite bridge sensors and measure them ratiometrically],
    [Local],
    [REQ-10],
    [Device should provide shunt calibration on each bridge-sensor channel],
    [Local],
    [REQ-11],
    [Device must galvanically isolate each general-purpose channel from the stack and from the other channels],
    [Local],
    [REQ-12],
    [Device must carry its channels, front ends and sensor connector on a single board],
    [Local],
    [REQ-13],
    [Device must stack with further boards of the same design, and with #ident("E004-TC-BOARD"), to increase the channel count],
    [Local],
    [REQ-14],
    [Device should withstand, on every sensor contact, ±8~kV contact discharge to IEC~61000-4-2 and ±1~kV fast transients to IEC~61000-4-4],
    [Local],
    [REQ-15],
    [Device must withstand a sustained fault of up to 28~V on any sensor contact],
    [Local],
  ),
)

= System Description

== Architecture

Each board has four identical general-purpose channels. The board architecture can be seen in @fig-arch. Each channel comprises of a front end, converter, power supply, excitation source, and isolation. An FPGA on the stack side of the barriers collects the channels' data, processes it, and supplies it to the broader stack over #ident("ASRP-PCB-INTERCONNECT-2").

#figure(
  caption: [Board Architecture],
  board-arch(),
) <fig-arch>

Each channel is a separate isolated domain. Its barrier separates it from the stack and from the other three channels. A fault on a sensor, on its cable or in the channel's own circuits is therefore confined to that channel. Each channel is also tied to the vehicle at a single point through a resistor. A fault to the vehicle then moves the potential of the whole channel rather than driving current through its circuits, and a sensor bonded to the vehicle references only its own channel.

Within a channel, an isolated supply powers the front end, a ±2.048~V excitation bus and a 24~V sensor supply. Ten switches set the front end up for its sensor (@sec-gp-switches). The sensor's signal goes to the first of the four converters in the channel's #ident("ADS127L14"), and the other three monitor the channel's excitation (@sec-gp-monitor). Every sensor contact has a transient suppressor, and the parts behind it withstand a 28~V fault (REQ-15, @sec-protection). Where a configuration closes a low-impedance path into the channel, the fault must come from a current-limited source (OI-5).

On the stack side of the barriers, the FPGA configures the channels and gathers their data. It checks every sample, applies calibration, and packages the data into numbered packets that it buffers until the ECU MCU board reads them (@sec-fpga). When a channel's monitor shows a fault, the FPGA turns that channel off within one sample. The stack side also limits the current that the board and each of its channels can draw from the 5~V and 3.3~V rails, so that a short in one channel cannot take down the others or the rails of the stack.

Boards stack to add channels and share an SPI lane to the ECU MCU board. A single clock and start signal reach every board, so every converter in the stack samples at the same instant (@sec-stacking).

In the block diagrams, heavy lines carry power, dashed lines carry digital data and thin lines carry analog signals.

== Operations Concept

TBD

== Interfaces <sec-interfaces>

The board has two external interfaces (@tab-interfaces). #ident("ASRP-PCB-INTERCONNECT-2") connects it to the ECU MCU board and to the other boards of the stack, and the sensor connector connects it to its four sensors.

#figure(
  caption: [External Interfaces and Signals],
  datatable(
    columns: (auto, auto, 1fr),
    align: (left, left, left),
    header: ("Interface", "Part", "Signals"),
    ident("ASRP-PCB-INTERCONNECT-2"),
    [TBD, 32-way],
    [5V ×4, 3V3 ×2, GND ×10, SYNC_CLK, SYNC_START, two SPI lanes with four chip selects each],
    [Sensor connector],
    [#ident("M80-5001842"), 18-way],
    [EXC±, SIG± for four general-purpose channels, a shield pair],
  ),
) <tab-interfaces>

#ident("ASRP-PCB-INTERCONNECT-2") is a stacking interconnect defined in this document. It connects one SPI master to as many as eight peripheral boards, and every board passes each contact through to the next. The interconnect carries 5~V and 3.3~V power, two independent SPI lanes with four chip selects each, and a clock and start signal that synchronize sampling across the stack (@tab-interconnect-pinout, @tab-interconnect-signals). It does not depend on which boards fill these roles.

In the ECU stack the master is the ECU MCU board. The ADC boards share SPI0 and the #ident("E004-TC-BOARD") share SPI1, so each lane carries up to four boards of one kind. Every converter in the stack runs from #ident("SYNC_CLK") and starts on the same edge of it, so all boards sample at the same instant. The ADC boards number their samples from the last start (GW-6), so the master can align the data of every board whatever the order and timing of its reads. The ADC boards do not use #ident("ASRP-PCB-INTERCONNECT-1").

#figure(
  caption: [#ident("ASRP-PCB-INTERCONNECT-2") Pinout],
  datatable(
    columns: (auto, 1fr, auto, 1fr),
    align: (center, left, center, left),
    header: ("Pin", "Signal", "Pin", "Signal"),
    [1],
    ident("5V"),
    [2],
    ident("5V"),
    [3],
    ident("5V"),
    [4],
    ident("5V"),
    [5],
    ident("GND"),
    [6],
    ident("GND"),
    [7],
    ident("3V3"),
    [8],
    ident("3V3"),
    [9],
    ident("GND"),
    [10],
    ident("GND"),
    [11],
    ident("SYNC_CLK"),
    [12],
    ident("GND"),
    [13],
    ident("SYNC_START"),
    [14],
    ident("GND"),
    [15],
    ident("SPI0_SCLK"),
    [16],
    ident("GND"),
    [17],
    ident("SPI0_MOSI"),
    [18],
    ident("SPI0_MISO"),
    [19],
    ident("SPI0_CS0"),
    [20],
    ident("SPI0_CS1"),
    [21],
    ident("SPI0_CS2"),
    [22],
    ident("SPI0_CS3"),
    [23],
    ident("SPI1_SCLK"),
    [24],
    ident("GND"),
    [25],
    ident("SPI1_MOSI"),
    [26],
    ident("SPI1_MISO"),
    [27],
    ident("SPI1_CS0"),
    [28],
    ident("SPI1_CS1"),
    [29],
    ident("SPI1_CS2"),
    [30],
    ident("SPI1_CS3"),
    [31],
    ident("GND"),
    [32],
    ident("GND"),
  ),
) <tab-interconnect-pinout>

#figure(
  caption: [#ident("ASRP-PCB-INTERCONNECT-2") Signals],
  datatable(
    columns: (auto, auto, auto, 1fr),
    align: (left, center, left, left),
    header: ("Signal", "Pins", "Driven by", "Use"),
    ident("5V"),
    [4],
    [Supply],
    [5~V power, up to 4.5~A in total (INT-2).],
    ident("3V3"),
    [2],
    [Supply],
    [3.3~V power, up to 0.6~A in total (INT-2).],
    ident("GND"),
    [10],
    [—],
    [Power return and signal reference.],
    ident("SYNC_CLK"),
    [1],
    [One source],
    [Sample clock, 8.192~MHz (INT-5).],
    ident("SYNC_START"),
    [1],
    [One source],
    [Idles high. A low pulse starts or resynchronizes sampling (INT-6).],
    ident("SPIx_SCLK"),
    [2],
    [Master],
    [SPI clock of each lane, up to 20~MHz (INT-7).],
    ident("SPIx_MOSI"),
    [2],
    [Master],
    [Data from the master to the selected peripheral.],
    ident("SPIx_MISO"),
    [2],
    [Selected peripheral],
    [Data from the selected peripheral to the master (INT-8).],
    ident("SPIx_CS0…3"),
    [8],
    [Master],
    [Chip selects, active low, four for each lane. Each selects one peripheral (INT-1).],
  ),
) <tab-interconnect-signals>

The pinout places a ground opposite every clock line and keeps the power contacts together at one end, away from the signals.

#requirement(
  "INT-1",
  [Every contact of #ident("ASRP-PCB-INTERCONNECT-2") shall pass straight through each board, so that boards stack in any order. Each peripheral shall respond to exactly one chip select, and no two peripherals shall share a chip select.],
  note: [A peripheral is addressed only by its chip select. Its position in the stack has no meaning, and each board sets its own chip select, for example with a jumper.],
)

#requirement(
  "INT-2",
  [#ident("ASRP-PCB-INTERCONNECT-2") shall be capable of supplying 5~V at up to 4.5~A and 3.3~V at up to 0.6~A, each within ±5~% at the contacts of every board.],
  note: [The currents are sized for the largest intended stack: four ADC boards on SPI0 with a transmitter on every channel, and four #ident("E004-TC-BOARD") on SPI1. An ADC board draws up to 0.09~A at 3.3~V. At 5~V it draws up to 0.25~A with its channels off or on piezoresistive transducers, plus 0.06~A for each load-cell channel and 0.2~A for each transmitter channel, which comes to 1.05~A with a transmitter on all four. An #ident("E004-TC-BOARD") draws up to 0.04~A from each rail. The stack then draws 4.36~A at 5~V and 0.52~A at 3.3~V. These are estimates, with a transmitter channel counted at its 30~mA limit. The 5~V current is more than twice the 2~A that the #ident("E001-POWER-BOARD") provides for the whole ECU stack (OI-1).],
)

#requirement(
  "INT-3",
  [Each contact shall be rated for at least 2~A, and each power rail and its return shall be carried on at least two contacts.],
  note: [Carrying each rail on several contacts makes the power path redundant, so that a single open contact does not cut power to the stack. The pinout puts 5~V on four contacts, 3.3~V on two and the return on ten. With any one contact open, each rail still delivers its full current (INT-2) within the contact rating: the three remaining 5~V contacts then carry 1.5~A each.],
)

#requirement(
  "INT-4",
  [Signals shall be 3.3~V LVCMOS referenced to #ident("GND") and series-terminated at their driver. Each chip select shall idle high when no board drives it. A peripheral shall drive the MISO line of its lane only while its own chip select is low, and an unpowered board shall leave every line at high impedance.],
  note: [A peripheral whose chip select enables its MISO driver directly, rather than through its logic, cannot hold the shared line when that logic fails. A chip select that idles high keeps every peripheral deselected while the master is unpowered or in reset.],
)

#requirement(
  "INT-5",
  [#ident("SYNC_CLK") shall run at 8.192~MHz ±50~ppm or better and shall have exactly one driver in the stack. Every peripheral that samples shall clock its converters from #ident("SYNC_CLK") and from no other source.],
  note: [A single source puts every converter in the stack on one time base. The frequency suits both converters in the ECU stack: the #ident("ADS127L14") of the ADC boards produce 8~kSPS from it, and the #ident("ADS131M06") of the #ident("E004-TC-BOARD") 4~kSPS. The clock is a single point of failure for sampling, as the master already is for the data.],
)

#requirement(
  "INT-6",
  [#ident("SYNC_START") shall idle high and shall have exactly one driver in the stack. A start or resynchronization shall be a low pulse lasting at least one and fewer than 2048 cycles of #ident("SYNC_CLK"). Both edges of the pulse shall fall at least 30~ns from any rising edge of #ident("SYNC_CLK") at every board. Each peripheral shall sample #ident("SYNC_START") on the rising edges of #ident("SYNC_CLK") and start all of its converters on the same edge.],
  note: [Every converter in the stack then starts on one edge of #ident("SYNC_CLK") and samples at the same instant, to within the skew of the clock across the stack. That skew is a few tens of nanoseconds, or 0.01° at 2~kHz. The 30~ns margin gives every board a clean sample of the pulse within the 122~ns period of #ident("SYNC_CLK"). The 2048-cycle limit protects converters such as the #ident("ADS131M06"), which reset rather than resynchronize when their SYNC/RESET input is held low for longer.],
)

#requirement(
  "INT-7",
  [Each SPI lane shall operate at any SCLK frequency up to 20~MHz. The two lanes shall operate independently and at the same time.],
  note: [The lanes mirror the two SPI controllers of the SAM V71 intended as the master, each of which has four chip selects and its own DMA channels. The SAM V71 divides SCLK from its 150~MHz peripheral clock by an integer, so it runs a lane at 18.75~MHz. It sets the SPI mode separately for each chip select, so the peripherals on a lane may use different modes.],
)

#requirement(
  "INT-8",
  [A peripheral's MISO output shall be valid at the connector within 30~ns of the SCLK edge on which the peripheral changes it.],
  note: [The SAM V71 samples MISO on the same SCLK edge on which it changes MOSI, so a peripheral's data has a full SCLK period to return. The SAM V71 needs 12.4~ns of setup at 3.3~V, which leaves 37.6~ns of a 50~ns period at 20~MHz. The peripheral takes 30~ns of this, and the remaining 7.6~ns covers the clock's path across the stack and the data's path back.],
)

#requirement(
  "INT-9",
  [Each SPI lane shall carry at least 15~Mbit/s from its peripherals to the master, averaged over any 20~ms, with both lanes running at once. The peripherals on a lane shall together produce no more than 15~Mbit/s, packet overhead included.],
  note: [The SAM V71's SPI streams words back to back under DMA, so a read runs at the full 18.75~MHz of INT-7. The 20~% that remains covers the chip-select set-up, the command that opens each read and the DMA set-up between reads. The peripherals on a lane share its 15~Mbit/s, so one, two, three or four ADC boards on SPI0 may each average up to 15, 7.5, 5.0 or 3.75~Mbit/s. An ADC board sends all sixteen of its readings, 384~bits, for every sample (GW-5), and packets of 1~ms add about 0.1~Mbit/s. From the 8.192~MHz of #ident("SYNC_CLK") the wideband filter offers 8, 16, 32, 64 or 128~kSPS, which need 3.2, 6.3, 12.4, 24.7 and 49.3~Mbit/s. A single board on the lane can therefore sample at up to 32~kSPS, two boards at up to 16~kSPS each, and three or four boards at up to 8~kSPS. The board itself holds every configuration to 8~kSPS: at 16~kSPS the 20~ms buffer of INT-10 would need 125~kbit, more than the 92~kbit of block RAM in its FPGA (@sec-fpga).],
)

#requirement(
  "INT-10",
  [Each peripheral shall buffer at least 20~ms of the data it produces, and shall report in every read how much data it still holds.],
  note: [The master can then read the peripherals one at a time, in any order and in bursts, and can pause for up to 20~ms without losing data, for example while it writes its log. The interconnect has no interrupt or data-ready lines. The master instead learns from each read how much data remains, and schedules its next read from that.],
)

The sensors connect through a Harwin Datamate #ident("M80-5001842"), which carries four contacts for each of the four channels and two for their shields (@tab-sensor-pinout). Each pair occupies one column of the connector, so the two wires of a twisted pair land side by side.

#figure(
  caption: [Sensor Connector #ident("M80-5001842") Pinout],
  datatable(
    columns: (auto, 1fr, auto, 1fr),
    align: (center, left, center, left),
    header: ("Pin", "Signal", "Pin", "Signal"),
    [1],
    ident("GP1_EXC+"),
    [2],
    ident("GP1_EXC−"),
    [3],
    ident("GP1_SIG+"),
    [4],
    ident("GP1_SIG−"),
    [5],
    ident("GP2_EXC+"),
    [6],
    ident("GP2_EXC−"),
    [7],
    ident("GP2_SIG+"),
    [8],
    ident("GP2_SIG−"),
    [9],
    ident("GP3_EXC+"),
    [10],
    ident("GP3_EXC−"),
    [11],
    ident("GP3_SIG+"),
    [12],
    ident("GP3_SIG−"),
    [13],
    ident("GP4_EXC+"),
    [14],
    ident("GP4_EXC−"),
    [15],
    ident("GP4_SIG+"),
    [16],
    ident("GP4_SIG−"),
    [17],
    ident("GP_SHLD"),
    [18],
    ident("GP_SHLD"),
  ),
) <tab-sensor-pinout>

#figure(
  caption: [General-Purpose Contact Use by Configuration],
  datatable(
    columns: (auto, 1fr, 1fr, 1fr),
    align: (left, left, left, left),
    header: (
      "Contact",
      "Bridge sensor",
      "4–20 mA transmitter",
      "Voltage transmitter",
    ),
    ident("EXC+"),
    [Excitation current in, 9.0~mA or 1.0~mA],
    [Loop supply, 24~V, 30~mA limit],
    [Transmitter supply, 24~V, 30~mA limit],
    ident("EXC−"),
    [Excitation current out],
    [Loop return through the link to #ident("SIG−") (CBL-1), tied to the channel common],
    [Supply return, tied to the channel common],
    ident("SIG+"),
    [Signal +],
    [Loop current in, to the 100~Ω shunt],
    [Signal, 0–10~V],
    ident("SIG−"),
    [Signal −],
    [Low side of the shunt, linked to #ident("EXC−") (CBL-1)],
    [Signal return, measured at the contact. Linked to #ident("EXC−") for an isolated output (CBL-1)],
  ),
) <tab-sensor-config>

The function of each contact depends on the configuration that the FPGA sets (@tab-sensor-config). In both transmitter configurations S4 ties #ident("EXC−") to the channel common, where it serves as the supply return. The cable of a #box[4–20~mA] transmitter links #ident("SIG−") to #ident("EXC−") so that the loop current returns there too, and the cable of a voltage transmitter with an isolated output does the same (CBL-1).

#ident("GP_SHLD") takes the cable shields. Where the shields are terminated at the board, a jumper connects #ident("GP_SHLD") to the vehicle tie of each channel, a resistor with a capacitor across it to the channel common (@sec-gp-control). Where they are terminated at the vehicle instead, the jumper is left open.

The sensor cables must also meet one requirement of their own.

#requirement(
  "CBL-1",
  [The cable of a #box[4–20~mA] transmitter, or of a voltage transmitter with an isolated output, shall link #ident("SIG−") to #ident("EXC−") at the sensor connector. No other cable shall link them.],
  note: [The link returns the loop current, or references an isolated output, through S4 to the channel common, and so replaces a switch on the board. A three-wire voltage transmitter already joins its supply and signal returns internally. A second join in the cable would divert part of its supply current into #ident("SIG−"), and so into the reading. On a bridge sensor the link would short half the bridge, which the excitation monitor detects at 1~mA as a gross fault (@sec-gp-monitor).],
)

== Gateware and Firmware Requirements <sec-gw>

The gateware requirements apply to the FPGA on this board and to the parts that configure it. The firmware requirements apply to the ECU MCU board, which configures the FPGA and reads its data.

#requirement(
  "GW-1",
  [The FPGA shall be able to write and read back every configuration register of each channel's #ident("ADS127L14").],
  note: [The FPGA applies the settings of @tab-adc-config (@sec-gp-adc).],
)

#requirement(
  "GW-2",
  [The FPGA shall set each channel's configuration code through the GPIO pins of its #ident("ADS127L14"), and shall read the pins back before using the channel's data. It shall always pass through off when changing a channel's configuration. It shall raise a channel's current above 1~mA only after the excitation monitor has measured the sensor at 1~mA with the channel off. It shall set a load-cell configuration only after confirming, with the channel off, that #ident("EXC−") is held to the bus and not to the channel common.],
  note: [The read-back catches a stuck line or a corrupted write before a switch acts on it (@sec-gp-control). Passing through off lets the switches of one configuration open before those of the next close. The 30~mA branch would destroy a piezoresistive transducer rated for 3~mA, and only the reading at 1~mA shows which sensor is connected (@sec-gp-switches). #ident("EXC−") held to the channel common indicates a shorted S4, which would short the bus in a load-cell configuration.],
)

#requirement(
  "GW-3",
  [The FPGA shall check the status and CRC of every packet and the code read-back of every channel. It shall turn a channel off within one sample when the channel's converter reports a reset or an error, when its code reads back wrong, or when its excitation monitor leaves the limits set for its configuration. It shall report each such event in its status (GW-6).],
  note: [The FPGA therefore catches an open or shorted sensor, a collapsed bus or a current above a sensor's rating at the converter's 8~kSPS, rather than at the rate at which the ECU MCU board reads the board.],
)

#requirement(
  "GW-4",
  [The FPGA shall apply to every channel the gain and offset correction stored in it by the ECU MCU board.],
  note: [The corrections come from calibration at test (FW-2).],
)

#requirement(
  "GW-5",
  [The FPGA shall pass on all four readings of every channel at 8~kSPS.],
  note: [A channel that is off keeps its place in the frame, and its status marks it off. The ECU MCU board then parses every frame the same way. A board produces about 3.2~Mbit/s in packets of 1~ms, within its smallest share of SPI0 (INT-9).],
)

#requirement(
  "GW-6",
  [The FPGA shall number its samples from the last start, and shall return its data in packets that carry the number of the first sample in the packet, the board's status and a CRC.],
  note: [The ECU MCU board matches the samples that every board took at one instant by their numbers, whatever the order and timing of its reads. A gap in the numbers, or a number that stops advancing, marks a lost packet or a stopped board (FW-1).],
)

#requirement(
  "GW-7",
  [The FPGA's registers shall be the only means of configuring the board, and shall hold each channel's configuration, converter settings, calibration and protective limits. Every register write shall carry a CRC, and the FPGA shall act on a write only if its CRC is correct.],
  note: [Only the FPGA drives the converters and the channel switches, so a fault on the bus can reach a channel only as a write that the FPGA has already checked.],
)

#requirement(
  "GW-8",
  [The board shall configure its FPGA from non-volatile memory on the board within 100~ms of power-up, without the ECU MCU board. It shall accept a new configuration over its SPI lane while the FPGA runs, shall keep a golden configuration that can be overwritten only by a two-step process, in which one command unlocks it and a second writes it, and shall fall back to the golden configuration if a new one fails to load.],
  note: [Every channel starts off and remains off until the ECU MCU board configures it, and a channel keeps its configuration if the ECU MCU board restarts. An interrupted or faulty update leaves a board that still boots and accepts another update (FW-4). No single write, faulty or not, can replace the golden configuration. The #ident("LCMXO2-4000HC") programs its internal flash in the background through a hardened configuration port, which every image keeps enabled, and falls back to a golden image held in an SPI flash beside it.],
)

#requirement(
  "GW-9",
  [The board shall reconfigure its FPGA from non-volatile memory when its chip select is held low for more than 200~ms, without relying on the configuration that the FPGA is running.],
  note: [No transfer holds a chip select low for that long. The ECU MCU board can then recover a hung FPGA without a power cycle of the stack and without disturbing any other board. A timer on the board pulls the FPGA's PROGRAMN input low (@sec-fpga).],
)

#requirement(
  "FW-1",
  [Firmware shall flag a board whose sample numbers skip or stop advancing, and shall stop using that board's data until it recovers.],
  note: [Every board numbers its samples from the same start (GW-6), so a gap or a stalled number indicates a lost packet, a failed board or a lost clock.],
)

#requirement(
  "FW-2",
  [Firmware shall store each channel's gain and offset correction in the FPGA of its board.],
  note: [The corrections come from calibration at test, and the FPGA applies them (GW-4).],
)

#requirement(
  "FW-3",
  [Firmware shall tare each load-cell channel on command by storing its reading under no load and subtracting it from subsequent readings.],
  note: [Offset drift sets the accuracy of a load-cell channel (@tab-gp-budget). A tare before each test removes the drift accumulated since calibration.],
)

#requirement(
  "FW-4",
  [Firmware shall verify a new FPGA configuration after writing it and before making the board load it. It shall overwrite the golden configuration only on an explicit command, never as part of an update.],
  note: [If the board fails to load the new configuration, it falls back to the golden one (GW-8).],
)

== Key Parameters

#figure(
  caption: [Key Design Parameters],
  datatable(
    columns: (auto, 1fr, auto),
    align: (left, left, left),
    header: ("Item", "Value", "Source"),
    [Channels per board],
    [Four general-purpose, each isolated from the stack and from the others],
    [REQ-5, REQ-11],
    [General-purpose bandwidth],
    [2~kHz, sampled at 8~kSPS simultaneously across the stack and flat to 3.2~kHz],
    [#ident("ADS127L14") wideband filter],
    [General-purpose range],
    [Within ±2.0~V at the converter: ±6.3~mV from a load cell at 2~mV/V, typically 160~mV from a piezoresistive transducer, 0.4–2.0~V from a #box[4–20~mA] loop across its shunt and 0–2.0~V from a 0–10~V transmitter through a 5:1 divider],
    [@tab-channel-config],
    [General-purpose noise],
    [2.81~µV~rms at 8~kSPS, of which the converter contributes 2.55~µV~rms],
    [@sec-gp-budget],
    [General-purpose drift],
    [After calibration, per 10~°C and summed as root sum square: 0.16~% of full scale for a load cell, 0.015~% for a piezoresistive transducer, 0.009~% for #box[4–20~mA] and 0.012~% for 0–10~V],
    [@tab-gp-budget],
    [Bridge excitation],
    [Constant current per channel: 9.0~mA for a load cell, 1.0~mA for a piezoresistive transducer],
    [#ident("LT3092")],
    [Excitation bus],
    [±2.048~V per channel: the converter reference for transmitters, the return for bridge excitation],
    [#ident("REF5020")],
    [Excitation monitor],
    [The converter's other three inputs read #ident("EXC+"), #ident("EXC−") and the bus at 8~kSPS, alongside the signal],
    [@sec-gp-monitor],
    [Converter clock],
    [#ident("SYNC_CLK"), 8.192~MHz, shared by every board in the stack],
    [INT-5],
    [Data collection],
    [An FPGA on the stack side configures the channels, runs the interlocks, applies calibration and buffers 20~ms of numbered packets],
    [@sec-fpga],
    [Stack],
    [Up to four ADC boards on SPI0 at up to 20~MHz, each producing about 3.2~Mbit/s of the lane's 15~Mbit/s],
    [@sec-stacking],
    [Sensor supply],
    [24~V, or 15~V by a placement option, through a current source in each channel that excites a bridge or limits a transmitter to 30~mA],
    [#ident("TPS61170"), #ident("LT3092")],
    [Input protection],
    [A 28~V fault on any contact, current-limited where a configuration closes a low-impedance path (OI-5), ±8~kV contact discharge and ±1~kV fast transients],
    [REQ-14, REQ-15, @sec-protection],
    [Input power],
    [About 1.5~W per board, plus about 0.3~W per load-cell channel and 1.0~W per transmitter channel],
    [Estimate],
  ),
)

= Functional Blocks

== General-Purpose Channels <sec-gp>

The four general-purpose channels are identical, and each is an isolated domain with its own supply. A current source in each channel excites a bridge sensor or limits the supply of a transmitter. A ±2.048~V excitation bus serves as the converter reference of a transmitter and as the return for a bridge's excitation current. The channel's #ident("ADS127L14") reads the sensor through a precision buffer on its first converter, and monitors the excitation on the other three (@sec-gp-monitor).

The FPGA sets a channel up for its sensor in two ways. A three-bit code on the converter's GPIO pins closes the switches that the configuration needs, out of the ten switches S1 to S10 (@sec-gp-switches). The FPGA also sets the converter to match (@tab-adc-config). @tab-channel-config lists the four configurations, each of which keeps the signal within ±2.0~V of the channel common, inside the input ranges of both the buffer and the converter.

#figure(
  caption: [General-Purpose Channel Configurations],
  datatable(
    columns: (auto, 1fr, auto),
    align: (left, left, left),
    header: ("Configuration", "Set by the FPGA", "At the converter"),
    [Load cell],
    [4-wire full bridge, 350~Ω typical. 9.0~mA (S1). #ident("EXC−") straight to the bus (S3). REFP from #ident("EXC+") through 10~kΩ (S5). Shunt calibration (S10).],
    [±6.3~mV at 2~mV/V, ratiometric to the bridge voltage],
    [Piezoresistive transducer],
    [Bridge such as the Keller 7L, 3.5~kΩ typical. 1.0~mA. #ident("EXC−") through the 1.00~kΩ current-sense resistor. REFP from #ident("EXC−") (S6). Shunt calibration (S10).],
    [160~mV typical at full scale, ratiometric to the current],
    [#box[4–20~mA] transmitter],
    [24~V loop supply through a 30~mA limit (S2). 100~Ω shunt across the signal contacts (S8). #ident("EXC−") to the channel common (S4), and #ident("SIG−") to it through a link in the cable (CBL-1). REFP from the bus (S7).],
    [0.4–2.0~V],
    [Voltage transmitter],
    [0–10~V output. 24~V supply through a 30~mA limit (S2). #ident("EXC−") to the channel common (S4). 2.49~kΩ divider bottom to #ident("SIG−") (S9). An isolated output's cable links #ident("SIG−") to #ident("EXC−") (CBL-1). REFP from the bus (S7).],
    [0–2.0~V],
  ),
) <tab-channel-config>

The signal chain, the sensor supply and the switches are the same in every configuration (@sec-gp-chain, @sec-gp-switches). @fig-gp-load-cell, @fig-gp-piezo, @fig-gp-current and @fig-gp-voltage show the channel set up for each sensor. Closed switches and the parts in use are drawn in black, and open switches and the parts they leave idle in grey. The parts that set the accuracy are drawn as components, and the excitation bus and sensor supply as blocks. The drawings leave out the switches' gate drive and the decoupling.

=== Signal Chain and Sensor Supply <sec-gp-chain>

Each channel has its own #ident("ADS127L14"). Its first converter reads the sensor, and the other three monitor the channel (@sec-gp-monitor). Every converter in the stack runs from the 8.192~MHz of #ident("SYNC_CLK") and starts on the same edge of it, so all of them sample at the same instant (REQ-6, INT-5, INT-6). The converter runs in high-speed mode, where the wideband filter at an oversampling ratio of 512 gives 8~kSPS (@tab-adc-config). The filter is flat to 3.2~kHz and rejects by 106~dB from 4~kHz, which covers the 2~kHz bandwidth (REQ-7). The converter's noise is 2.55~µV~rms. The buffers and protection raise the channel's noise to 2.81~µV~rms, which is 0.044~% of full scale for a 2~mV/V load cell (@sec-gp-budget).

An #ident("OPA2189") buffers the two signal inputs. The converter's precharge buffers draw up to ±1.5~µA at their rated clock, and through a 350~Ω bridge and the protection that current would give errors of millivolts. The #ident("OPA2189") draws under 300~pA. Its input range ends 2.5~V below its positive rail, so it runs from the ±5~V rails while the converter runs from ±2.5~V.

Each signal input carries 10~kΩ of series protection, in 0805 to take the 78~mW of a 28~V fault, followed by low-leakage clamps to the ±5~V rails and 110~pF across the pair. The resistor on SIG+ is 0.05~%, 5~ppm/°C thin film, because it is also the top of the voltage transmitter's divider. The buffers and the excitation run from the ±5~V rails, so they are up before the converter's ±2.5~V. Until then, and in a fault, 237~Ω at each converter input and reference pin holds the current into the converter's clamps below their 10~mA rating. A load cell's REFP uses 10~kΩ instead. With 3.3~nF across the inputs and 330~pF from each to AVSS, the 237~Ω resistors also form the converter's input filter, with a differential pole at 97~kHz. The common-mode capacitors are a tenth of the differential one, as the converter datasheet recommends. They supply the common-mode part of each sample's charge and return it to AVSS, which powers the converter's sampling switches.

A #ident("REF5020") sets the channel's ±2.048~V excitation bus. One half of an #ident("OPA2189") follows it and the other half inverts it, and each half drives one side of the bus directly. The bus carries at most a load cell's 9.0~mA and the converter's reference current, and the amplifier's ±65~mA output limit bounds a short on it. The bus is the converter reference of a transmitter, and its negative side takes the excitation current of a bridge.

The converter takes REFN from the negative side of the bus. It takes REFP from one of three points, selected by S5, S6 or S7: the top of a load cell, the top of a piezoresistive bridge's current-sense resistor, or the positive side of the bus for a transmitter. All four converters share that reference. The bus lies above the 1.8~V limit of the converter's REFP precharge buffer, so a transmitter channel leaves the buffer off while a bridge channel turns it on (@tab-adc-config). With the buffer on, a load cell's REFP comes through 10~kΩ instead of 237~Ω, so that a cell unplugged from its running current source drives no more than 2~mA into the converter's clamp. Unbuffered, a reference pin with four converters behind it draws about 240~µA per volt at the 8.192~MHz clock, which lowers the reference by about 6~% through 237~Ω. Buffered, REFP draws at most ±4~µA. Both are fixed gain errors, which calibration removes (GW-4).

A shunt clamp holds the +2.5~V rail below 2.7~V. The rail's regulator can only source current, yet a buffer driven past its input range pushes about 8~mA through 237~Ω into the converter's clamp. Without the shunt clamp, that current would lift the rail toward the converter's absolute maximum of 6.5~V across its supplies. A two-wire transmitter on a channel that is off does exactly this, because #ident("SIG+") then has no return, and so do a broken #ident("EXC−") wire and a shorted loop.

The sensor draws on a 24~V supply through an #ident("LT3092"), and a #ident("TPS61170") boosts that supply from the channel's +5~V rail. The #ident("LT3092") is a two-terminal current source. It passes its 10~µA set current through 30.1~kΩ, and holds the resulting 0.3~V across its output resistor. A permanent 301~Ω gives 1.0~mA, which excites a piezoresistive transducer. S1 adds 37.4~Ω in parallel for 9.0~mA, which excites a load cell, and S2 adds 10.2~Ω for 30~mA, the limit on a transmitter's supply. A shorted sensor or cable therefore draws no more than its channel's setting. Where the sensors allow it, a different feedback resistor sets the supply to 15~V, which saves power.

An #ident("SN6505B") on the stack side drives the channel's transformer, and a bridge rectifier on the centre-tapped secondary gives the channel's unregulated ±5~V rails. A #ident("TPS7A39") derives the converter's ±2.5~V from these rails, with its two outputs rising together. A #ident("TLV704") derives 1.8~V for the converter's I/O and GPIO, the code decoders and the channel side of the isolators. The converter's AVDD2 is tied to the channel common, the lowest level that the #ident("ADS127L14") allows with ±2.5~V supplies. This halves the modulators' supply power and keeps their current off the +2.5~V rail. The FPGA clocks the four #ident("SN6505B") from #ident("SYNC_CLK"), so they switch together at 512~kHz and their ripple cannot beat into the 2~kHz band (@sec-fpga). Each driver has its own current limit on the stack side, so a failed channel supply cannot pull down the board's 5~V input (@sec-stacking).

=== Converter Configuration <sec-gp-adc>

The FPGA sets up each channel's #ident("ADS127L14") over the channel's own SPI, with the settings of @tab-adc-config (GW-1). Most settings are the same in every configuration. Only the REFP precharge buffer and the reference range depend on the sensor.

#[
  #set par(justify: false)
  #figure(
    caption: [Converter Settings],
    datatable(
      columns: (auto, 1fr, 1.6fr),
      align: (left, left, left),
      header: ("Setting", "Value", "Reason"),
      [Clock],
      [External, from #ident("SYNC_CLK") at 8.192~MHz, divided by 1],
      [Every converter in the stack samples on one clock (INT-5). A divided clock would start with an unknown phase and lose the synchronization.],
      [Speed mode],
      [High speed],
      [At 8.192~MHz it holds the drift of the input current to that of the #ident("ADS127L11"). Mid-speed mode would double it (@sec-gp-budget).],
      [Digital filter],
      [Wideband, oversampling ratio 512, on all four converters],
      [8~kSPS, flat to 3.2~kHz, which covers the 2~kHz bandwidth (REQ-7).],
      [START],
      [Synchronized control mode],
      [Every converter starts on the edge to which the FPGA retimes #ident("SYNC_START") (INT-6).],
      [Data port],
      [Frame-sync, one data lane, DCLK at a quarter of #ident("SYNC_CLK"), 2.048~MHz],
      [One isolated line carries the packets of all four converters (@sec-gp-control).],
      [Data packet],
      [40~bits: status header, 24-bit reading and CRC],
      [The FPGA checks the status and CRC of every packet (GW-3).],
      [Input precharge buffers],
      [On],
      [The monitor's dividers rely on the buffered input current of about 0.5~µA at this clock (@sec-gp-monitor).],
      [REFP precharge buffer],
      [On for a bridge sensor, off for a transmitter],
      [The buffer accepts REFP only up to AVDD1 − 0.7~V, which is 1.8~V here. A transmitter's REFP is the 2.048~V bus. A load cell's REFP reaches at most 1.66~V, for a 410~Ω cell at 9.0~mA, and a piezoresistive transducer's sits near −1.05~V.],
      [Reference range],
      [Low for a piezoresistive transducer, high for every other configuration],
      [The low range covers 0.5 to 2.75~V and the high range 1~V to the supply. A piezoresistive transducer's reference of 1.0~V sits at the bottom of the high range. A load cell's is 3.2 to 3.7~V and a transmitter's 4.096~V.],
      [GPIO],
      [Three pins as outputs, driving the channel's configuration code],
      [The code sets the switches, and the FPGA reads it back through the GPIO read register (GW-2, @sec-gp-switches).],
    ),
  ) <tab-adc-config>
]

=== Bridge Sensors

A bridge sensor is excited by its channel's current source. The current enters the bridge at #ident("EXC+"), leaves at #ident("EXC−") and returns into the negative side of the excitation bus. Returning it to −2.048~V rather than to the channel common centres the bridge on the channel common. The bridge's outputs then lie within the input ranges of the buffers and the converter, and its top lies within the range of the converter's reference input. What the converter takes as its reference depends on how the sensor is specified.

#figure(
  caption: [General-Purpose Channel, Load Cell],
  gp-channel("load-cell"),
) <fig-gp-load-cell>

A load cell is specified in millivolts per volt: its output is a fixed fraction of the voltage across it. Its span compensation, made of resistors inside the cell in series with the excitation, holds that fraction constant over temperature. The converter's reference is therefore taken across the bridge, with REFP from #ident("EXC+") through 10~kΩ and REFN from the bus, to which S3 returns #ident("EXC−") through under 0.1~Ω. The converter then reads the cell's ratio directly (REQ-9). The ratio is a property of the bridge network, and it is the same whether a voltage or a current sets the voltage across the bridge. The value and drift of the current therefore cancel, and the cell's compensation works as designed. The current is 9.0~mA, which keeps REFP within the precharge buffer's limit for cells of up to 410~Ω, where it reaches 1.66~V. A 350~Ω cell then has 3.2~V across it and gives ±6.3~mV at 2~mV/V.

#figure(
  caption: [General-Purpose Channel, Piezoresistive Transducer],
  gp-channel("piezo"),
) <fig-gp-piezo>

A piezoresistive transducer such as the Keller 7L is characterised and compensated for a constant current of 1~mA. Its bridge resistance rises by 1800 to 3000~ppm/°C. Under a constant current this rise lifts the bridge voltage and cancels most of the fall in its piezoresistive sensitivity, whereas at a fixed voltage the span would drift by −0.12 to −0.36~% per °C. The excitation therefore returns through a 1.00~kΩ, 5~ppm/°C current-sense resistor, and the converter takes its reference across that resistor, with REFP from its top. The converter then reads the output as a fraction of the current, so the tolerance and drift of the current cancel. At 100~bar a 7L typically gives 160~mV against the 1.0~V reference, and the channel's noise of 2.9~µV~rms corresponds to about 1.8~mbar. Keller's resistors that compensate the transducer's zero, and the join of its two lower bridge pins, belong at the sensor end.

The current-sense resistor is fitted in every configuration. A load cell bypasses it through S3. In a transmitter channel #ident("EXC−") sits on the channel common, so the resistor passes 2~mA from the bus. It also holds an unused #ident("EXC−") to the bus.

Shunt calibration places a resistor chosen for the sensor across its SIG+ to #ident("EXC−") arm, through S10 (REQ-10). It also serves as a built-in test of each bridge channel. The FPGA closes S10 through the channel's code when the ECU MCU board commands it (@tab-gp-code).

=== #box[4–20~mA] Transmitter

#figure(
  caption: [General-Purpose Channel, #box[4–20~mA] Transmitter],
  gp-channel("current"),
) <fig-gp-current>

S2 sets the channel's current source to 30~mA. The source does not regulate below that limit, so the transmitter sets its own loop current, but the source limits what a shorted transmitter or cable can draw. A two-wire transmitter takes its loop supply from #ident("EXC+") and returns the loop current on #ident("SIG+"). S8 connects the 100~Ω precision shunt between #ident("SIG+") and #ident("SIG−"), which turns 4–20~mA into 0.4–2.0~V. The cable links #ident("SIG−") to #ident("EXC−"), and S4 ties #ident("EXC−") to the channel common, so the loop closes on the board (CBL-1). S4's few ohms carry the loop current outside the shunt's reading. S8 lies inside it, but its 18~mΩ maximum adds only 0.018~% to the reading, which calibration removes, and drifts by under 0.8~ppm/°C.

=== Voltage Transmitter

#figure(
  caption: [General-Purpose Channel, Voltage Transmitter],
  gp-channel("voltage"),
) <fig-gp-voltage>

The transmitter is supplied as in the #box[4–20~mA] configuration, and it returns its supply current on #ident("EXC−"), which S4 ties to the channel common. S9 switches a 2.49~kΩ resistor from the SIG+ buffer's input to #ident("SIG−") at the connector. The 10.0~kΩ series resistor then becomes the top of a 5:1 divider for 0–10~V, which loads the transmitter with 12.5~kΩ. The SIG− buffer reads #ident("SIG−") through its own 10~kΩ, so the divider measures between the two signal contacts, and a three-wire transmitter's supply current in #ident("EXC−") stays out of the reading. The bottom resistor is 1206 to take the 0.2~W of a 28~V fault on #ident("SIG−") while S9 is closed, and the clamp at the SIG+ buffer's input then takes 9~mA.

A transmitter with an isolated output would otherwise float, so its cable links #ident("SIG−") to #ident("EXC−") (CBL-1). A three-wire transmitter's cable carries no link, because its returns already meet inside it. The output is unipolar, so a reading that falls below zero by more than the channel's offset marks a transmitter wired in reverse.

=== Configuration Switches <sec-gp-switches>

Ten switches set a channel up for its sensor (@tab-gp-switches). Each is the simplest part that meets the voltages, currents and leakage of its position, and three kinds are used. Where both terminals stay within the channel's ±5~V rails, the switch is a #ident("TMUX6212") analog switch. It conducts in both directions with a flat on-resistance and nanoamperes of leakage, closes on 1.8~V logic and comes four to a package. Where a terminal floats with the sensor supply or sits on a contact that can see a 28~V fault, the switch is a MOSFET. Each MOSFET is placed so that it blocks only one polarity, and its gate is driven from the rails through a #ident("TMUX6212") channel or a #ident("BSS138W"). Where a switch must block both polarities at a high-impedance node with nanoamperes of leakage, it is a photorelay.

#figure(
  caption: [General-Purpose Channel Switches],
  {
    // Eight columns: narrower padding than the template's, and ragged text,
    // so that the function still has room on a B5 page.
    set table.cell(inset: (x: 4pt, y: 5pt))
    set par(justify: false)
    let head(h) = caps(h, size: size.tiny, tracking: track.label)
    let (x, o) = ([Closed], text(fill: ink.mute)[Open])
    datatable(
      columns: (auto, 1fr, auto, auto, auto, auto, auto, auto),
      align: (left, left, left, left, center, center, center, center),
      table.header(
        ..([Switch], [Function], [Part], [Type]).map(h => table.cell(
          rowspan: 2,
          align: left + bottom,
          head(h),
        )),
        table.cell(colspan: 4, head[State]),
        ..(
          [Load cell],
          [Piezo-\ resistive],
          [4–20 mA],
          [Voltage],
        ).map(h => table.cell(align: center + bottom, head(h))),
        table.hline(
          y: 1,
          start: 4,
          stroke: (paint: ink.rule, thickness: rule.hair),
        ),
      ),
      table.hline(stroke: (paint: ink.rule, thickness: rule.hair)),
      [S1],
      [9.0~mA branch of the current source],
      ident("DMP3099L"),
      [P-MOSFET],
      x,
      o,
      o,
      o,
      [S2],
      [30~mA branch of the current source],
      ident("DMP3099L"),
      [P-MOSFET],
      o,
      o,
      x,
      x,
      [S3],
      [#ident("EXC−") straight to the bus],
      ident("DMN6075S"),
      [N-MOSFET],
      x,
      o,
      o,
      o,
      [S4],
      [#ident("EXC−") to the channel common],
      ident("BSS138W"),
      [N-MOSFET],
      o,
      o,
      x,
      x,
      [S5],
      [REFP from #ident("EXC+") through 10~kΩ],
      ident("BSS138W"),
      [N-MOSFET],
      x,
      o,
      o,
      o,
      [S6],
      [REFP from #ident("EXC−")],
      ident("TMUX6212"),
      [Analog\ switch],
      o,
      x,
      o,
      o,
      [S7],
      [REFP from the bus],
      ident("TMUX6212"),
      [Analog\ switch],
      o,
      o,
      x,
      x,
      [S8],
      [100~Ω current shunt],
      ident("DMTH4008LFDFWQ"),
      [N-MOSFET],
      o,
      o,
      x,
      o,
      [S9],
      [2.49~kΩ divider bottom to #ident("SIG−")],
      ident("TLP3475S"),
      [Photorelay],
      o,
      o,
      o,
      x,
      [S10],
      [Shunt calibration],
      ident("TMUX6212"),
      [Analog\ switch],
      [On\ command],
      [On\ command],
      o,
      o,
    )
  },
) <tab-gp-switches>

#switch-entry(
  [S1 and S2 switch the branches of the current source: 37.4~Ω for 9.0~mA and 10.2~Ω for 30~mA, each in parallel with the permanent 301~Ω.],
  requirements: [Both terminals float with #ident("EXC+") from 1~V below the channel common to 24~V above it. The maximum voltage differential across an open switch is the #ident("LT3092")'s 0.3~V set voltage. S1 carries 8~mA and S2 29~mA when closed.],
  type: [P-channel MOSFET, because a switch whose source floats up to 24~V needs gate drive that follows it. With its source toward the #ident("LT3092") the MOSFET turns on when its gate is pulled down. A #ident("BSS138W") pulls the gate toward the −5~V rail through a divider.],
)

#switch-entry(
  [S3 returns #ident("EXC−") straight to the negative side of the bus for a load cell, bypassing the current-sense resistor.],
  requirements: [S3 carries the cell's 9.0~mA when closed. It lies inside the cell's reference, which runs from #ident("EXC+") to the bus, so its on-resistance and the drift of that resistance appear in the reading. When open it blocks #ident("EXC−") at the channel common in the transmitter configurations, 2.05~V above the bus. Its drain is on a sensor contact. S4's body diode clamps a positive fault on #ident("EXC−"), but S3 must withstand the full 28~V if that clamp fails.],
  type: [N-channel MOSFET, because a power MOSFET combines a tenth of an ohm with a rating above 28~V. Its source sits on the bus, so its body diode carries a negative fault on #ident("EXC−") into the bus (@sec-protection). The #ident("DMN6075S") is rated 60~V with 85~mΩ at 10~V. Driven to 7~V from its source at −2.048~V, its 0.1~Ω adds 0.9~mV to the reference. That is a fixed 0.03~% with a drift of 1.4~ppm/°C.],
)

#switch-entry(
  [S4 ties #ident("EXC−") to the channel common in the transmitter configurations. It returns a transmitter's supply current, and the current of a #box[4–20~mA] loop through the cable link (CBL-1).],
  requirements: [S4 carries up to the 30~mA limit when closed. The current flows outside the measured span, so its on-resistance only lifts #ident("EXC−"). When open it blocks #ident("EXC−") on the bus, 2.05~V below the common. #ident("EXC−") never rises above the common in use.],
  type: [N-channel MOSFET, because with its source on #ident("EXC−") it blocks the only polarity it sees in use. Its body diode also clamps a positive fault on #ident("EXC−") to about 0.7~V above the common (@sec-protection). The #ident("BSS138W") is rated 50~V and 200~mA. Its current rating also bounds the fault that its body diode survives, which makes S4 the weakest switch against a low-impedance fault (OI-5). A larger MOSFET would raise that bound at no cost to the reading.],
)

#switch-entry(
  [S5 takes REFP from #ident("EXC+") through 10~kΩ for a load cell.],
  requirements: [S5 carries only the buffered REFP current of at most ±4~µA behind 10~kΩ, so its on-resistance does not matter. When open it blocks #ident("EXC+") from the REFP node. #ident("EXC+") reaches 24~V on a transmitter channel or with an open sensor, while the REFP node stays within the rails.],
  type: [N-channel MOSFET, because with its source on the REFP side it blocks the only polarity it sees.],
)

#switch-entry(
  [S6 and S7 select REFP. S6 takes it from #ident("EXC−") for a piezoresistive transducer, and S7 from the positive side of the bus for a transmitter.],
  requirements: [Every terminal of S6 and S7 stays within the rails, because S3's and S4's body diodes hold #ident("EXC−") within 0.7~V of the bus or the common. S6 carries the buffered REFP current of ±4~µA. S7 carries the unbuffered reference current of four converters, about 1~mA, and its on-resistance lies in a transmitter's reference. When open, S6 leaks into a piezoresistive transducer's #ident("EXC−") between the bridge and its current-sense resistor.],
  type: [Analog switch, because every terminal stays within the rails. The #ident("TMUX6212") has at most 7.6~Ω to 85~°C at ±5~V. In S7 this lowers the reference by 0.19~%, which calibration removes, and its drift of 0.015~Ω/°C is 3.7~ppm/°C of the reference. In S6 the same resistance is a fixed 30~ppm. Its leakage of at most 2~nA is 2~ppm of a piezoresistive transducer's current.],
)

#switch-entry(
  [S8 connects the 100~Ω shunt across the signal contacts for a #box[4–20~mA] transmitter.],
  requirements: [S8 lies inside the measured span. The converter reads the shunt and S8 in series, so S8's on-resistance and its drift add to the shunt's. Closed, it carries up to 30~mA. Open, it blocks a 0–10~V transmitter's output in the voltage configuration. Both of its terminals are on sensor contacts and must withstand a 28~V fault.],
  type: [N-channel MOSFET, because a power MOSFET has milliohms of on-resistance at a contact's voltage. With its source on #ident("SIG−") it blocks the one polarity a transmitter presents. Its gate is held at #ident("EXC_N") when open, at least 1.6~V below #ident("SIG−"), and at +5~V when closed. The #ident("DMTH4008LFDFWQ") has at most 18~mΩ at 4.5~V in a 2 × 2~mm package. This adds at most 0.018~% to the reading, which calibration removes. Its on-resistance rises by about 0.4~%/°C, so S8 drifts by less than 0.8~ppm/°C and the shunt's own 5~ppm/°C remains the dominant term. Its 40~V rating makes it the lowest-rated part on a contact and sets the suppressors' clamping voltage (@sec-protection). Its gate is rated ±20~V, so the 16~V Zener of S1, S2 and S4 protects it against a 28~V fault on #ident("SIG−"). At the 3~V of reverse bias it sees in use the Zener leaks typically well under 1~nA into #ident("SIG−"), which is 0.2~µV through a load cell.],
)

#switch-entry(
  [S9 connects the 2.49~kΩ divider bottom from the SIG+ buffer's input to #ident("SIG−") for a voltage transmitter.],
  requirements: [Open in the #box[4–20~mA] configuration, S9 has up to 2~V across it at the buffer's input. That node sits behind 10~kΩ, so the switch's leakage appears as an error. Closed, it carries at most 0.8~mA and its on-resistance adds to the divider's bottom. It must block both polarities, because #ident("SIG−") may sit above or below the buffer's input. Its #ident("SIG−") terminal is on a sensor contact and must withstand a 28~V fault.],
  type: [Photorelay, because its back-to-back MOSFETs block both polarities and its LED drive leaves the switch floating. A #ident("BSS138W") drives the LED from the +5~V rail. The #ident("TLP3475S") guarantees an off-state leakage of at most 1~nA at 50~V and 25~°C. Through 10~kΩ this is 10~µV, where a MOSFET's guaranteed 1~µA would give 10~mV. Its 1.5~Ω adds 0.06~% to the divider's bottom, which calibration removes, and drifts by 1.9~ppm/°C.],
)

#switch-entry(
  [S10 places the shunt-calibration resistor across a bridge's SIG+ to #ident("EXC−") arm.],
  requirements: [One terminal of S10 is on #ident("EXC−") within the rails. The other sees #ident("SIG+") only through the calibration resistor of tens of kilohms, which holds a fault on #ident("SIG+") to a fraction of a milliampere. Closed, its on-resistance adds to the calibration resistor. Open, its leakage flows into the bridge's output.],
  type: [Analog switch, because the calibration resistor keeps both terminals within the rails. The #ident("TMUX6212")'s 7.6~Ω is 0.01~% of an 87~kΩ calibration resistor, the value that simulates 1~mV/V on a 350~Ω cell. Its leakage of at most 2~nA gives less than 1~µV across the bridge, an offset that a tare removes.],
)

Three logic lines set a channel's switches. They carry a code that logic in the channel decodes into the switches' drive (@tab-gp-code). #ident("CFG1") and #ident("CFG0") select the configuration: off, load cell, piezoresistive or transmitter. #ident("OPT") selects the variant. On a bridge it closes S10 for shunt calibration, and on a transmitter it selects a voltage output in place of #box[4–20~mA]. In the table, a dash marks a line that the code ignores.

#figure(
  caption: [General-Purpose Channel Configuration Code],
  datatable(
    columns: (auto, auto, auto, auto, 1fr),
    align: (center, center, center, left, left),
    header: ("CFG1", "CFG0", "OPT", "Configuration", "Closed"),
    [0],
    [0],
    [—],
    [Off],
    [None],
    [0],
    [1],
    [0],
    [Load cell],
    [S1, S3, S5],
    [0],
    [1],
    [1],
    [Load cell, shunt calibration],
    [S1, S3, S5, S10],
    [1],
    [0],
    [0],
    [Piezoresistive],
    [S6],
    [1],
    [0],
    [1],
    [Piezoresistive, shunt calibration],
    [S6, S10],
    [1],
    [1],
    [0],
    [#box[4–20~mA] transmitter],
    [S2, S4, S7, S8],
    [1],
    [1],
    [1],
    [Voltage transmitter],
    [S2, S4, S7, S9],
  ),
) <tab-gp-code>

The lines are three GPIO pins of the channel's #ident("ADS127L14"), carrying 1.8~V logic referenced to the channel common (@sec-gp-control). Two #ident("TMUX6212") provide S6, S7 and S10, and they also translate the decoded signals to the ±5~V gate drive of the MOSFETs. A closed channel takes a gate to +5~V, and a pull-down holds it at −5~V or at #ident("EXC_N") while the channel is open. The gate drives of S4 and S8 each pass through 10~kΩ, which limits the current that a fault clamped by their Zener diodes drives back into the #ident("TMUX6212").

Decoding makes the configurations exclusive, so that no gateware or bus fault can mix them. Two mixtures would short the channel's bus. A load cell's S3 together with a transmitter's S4 would short the negative side of the bus to the channel common through a #ident("BSS138W") rated for 200~mA. A piezoresistive bridge's S6 together with a transmitter's S7 and S4 would short the positive side through two #ident("TMUX6212") channels rated for 160~mA at 85~°C. Either mixture would drive the bus amplifier into its ±65~mA limit, which is within the switches' ratings, and the channel would lose its excitation until the FPGA turned it off (GW-3). For the same reason the two current branches never close together.

With all three lines low, the code is off and every switch is open. The converter's GPIO pins are disabled at power-up and after a reset, and pull-downs on each line, inside the #ident("TMUX6212") and on every MOSFET and LED-driver gate make an undriven line read as off. The channel then delivers 1~mA through the base resistor, with every link open and REFP undriven. That current is safe for any sensor and too small to start a transmitter.

One register write sets all three lines together, so a channel never passes through a third code on its way to the next. The FPGA still moves a channel between configurations through off (GW-2), so that the old configuration's switches open before the new configuration's switches close. Going straight from a load cell to a transmitter, S4 could close before S3 had opened and short the bus for a moment.

The code cannot stop a configuration that is wrong for the connected sensor. The 30~mA branch, for example, would destroy a 7L, which is rated for 3~mA. The FPGA therefore raises the current only after the excitation monitor has measured the sensor at 1~mA with the channel off (GW-2, @sec-gp-monitor).

Once placed, the switches and their decoding take about 3.4~cm² of board per channel: two #ident("TMUX6212"), nine MOSFETs, a photorelay, four Zeners, a few logic gates and their resistors (@sec-physical).

=== Isolation and Control <sec-gp-control>

Each channel is an isolated domain, separated by its barrier from the stack side and from the other three channels. Four dual isolators carry the channel's data across the barrier, and the transformer of its #ident("SN6505B") carries its power. On the stack side the FPGA drives the channel (@sec-fpga). Eight signals cross the barrier (@tab-gp-barrier).

#[
  #set par(justify: false)
  #figure(
    caption: [Isolated Signals of a Channel],
    datatable(
      columns: (auto, auto, auto, auto, auto, 1fr),
      align: (left, left, left, left, left, left),
      header: ("Signal", "Direction", "Isolator", "Rate", "Unpowered", "Use"),
      [CLK],
      [In],
      [#ident("ISO6720B")],
      [8.192~MHz],
      [High],
      [#ident("SYNC_CLK"), the converter's clock],
      [START],
      [In],
      [#ident("ISO6720B")],
      [Per start],
      [High, idle],
      [#ident("SYNC_START"), retimed by the FPGA to an edge of #ident("SYNC_CLK")],
      [SCLK],
      [In],
      [#ident("ISO6721B") 1],
      [4~MHz],
      [High],
      [SPI clock],
      [SDO],
      [Out],
      [#ident("ISO6721B") 1],
      [4~MHz],
      [High],
      [Read-back of the converter's registers and of the code lines],
      [SDI],
      [In],
      [#ident("ISO6721B") 2],
      [4~MHz],
      [High],
      [Writes to the converter's registers and to its GPIO pins, which drive the configuration code],
      [DOUT],
      [Out],
      [#ident("ISO6721B") 2],
      [2.048~Mbit/s],
      [High],
      [Frame-sync data: four packets per sample, the signal's and the monitor's],
      [CS],
      [In],
      [#ident("ISO6721B") 3],
      [Per transfer],
      [High, deselected],
      [Selects the converter],
      [FSYNC],
      [Out],
      [#ident("ISO6721B") 3],
      [8~kHz],
      [High],
      [Marks the first packet of each sample],
    ),
  ) <tab-gp-barrier>
]

An #ident("ISO6720B"), with two forward channels, and three #ident("ISO6721B"), with one channel in each direction, carry the eight signals. Their channel side runs from the converter's 1.8~V I/O supply, which is below the 2.25~V minimum of the #ident("ISO7741") family. Each isolator delays a signal by 11 to 18~ns. CLK and START share the #ident("ISO6720B"), so their delays match to within its 6~ns skew between channels. Each #ident("ISO6721B") pairs a signal into the channel with one out of it. An isolator drives its outputs high when its input side loses power. A channel that loses the stack side therefore sees its converter deselected and START idle, and the FPGA sees FSYNC stop when a channel loses its own supply.

The SPI to the converter runs at 4~MHz. Its round trip through two isolators and the converter's 20~ns output delay is at most 56~ns, well inside the 125~ns half cycle. The data port runs at a quarter of #ident("SYNC_CLK"), 2.048~MHz, and one lane carries the packets of the four converters in turn, using 160 of the 256 bits in each 125~µs. The FPGA samples DOUT from its own copy of the clock, so DCLK does not cross the barrier. A bit lasts 488~ns, of which the barrier's round trip of about 40~ns is a small part. At the full #ident("SYNC_CLK") a bit would last 122~ns, which still leaves room for the round trip. The lane could then carry the four converters' 40-bit packets at up to 51.2~kSPS, enough for the wideband filter's 32~kSPS but not for its 64~kSPS.

The FPGA writes a channel's code into the converter's GPIO output register in a single write, and reads the pins back through the GPIO read register before it uses the channel's data (GW-2). The read-back sees the lines as they drive the decoders, so a stuck line or a corrupted write shows before a switch acts on it. The converter's GPIO pins are disabled at power-up and after a reset, so a channel starts off. A converter that resets in service turns its channel off and reports the event in the status header of its next packet, and the FPGA then reconfigures it (GW-3).

#ident("SYNC_CLK") reaches each channel from the board's bus buffer through its own 1~kΩ and isolator channel, so a failed channel cannot load the clock of the others (@sec-stacking). The FPGA retimes #ident("SYNC_START") and sends it to the four channels on one edge (INT-6). The isolators' delays differ by a few nanoseconds between channels, and this sets how closely the channels sample together.

Each channel's common is tied to #ident("GP_SHLD") by its own resistor with a capacitor across it, through the shield jumper, and from there to the vehicle through the cable shields (@sec-protection, OI-3). Two channels are then joined only through two ties in series. Between channels the barrier has to withstand only the harness's faults and transients, so 2~mm of spacing suffices there, while the barrier to the stack side keeps its 3~mm (@sec-physical).

== General-Purpose Error Budget <sec-gp-budget>

The budget runs from the sensor contacts to the converter output at 8~kSPS, for each configuration of @tab-channel-config. The sensor and its cable are outside it. Full scale is 6.33~mV for a 2~mV/V load cell on a 350~Ω bridge excited at 9.0~mA, 160~mV for a 100~bar Keller 7L at 1~mA, 20~mA for a #box[4–20~mA] transmitter and 10~V for a voltage transmitter. Each term is a datasheet maximum, except those marked typical, for which the datasheets give no maximum.

Calibration at test (FW-2, GW-4) and shunt calibration (REQ-10) remove the offset and gain present at the calibration temperature. What remains is noise, nonlinearity and drift (@tab-gp-budget). The board's temperature range is not yet set, so drift is given per 10~°C away from the calibration temperature.

#figure(
  caption: [General-Purpose Error Budget after Calibration, % of Full Scale],
  datatable(
    columns: (1fr, auto, auto, auto, auto),
    align: (left, right, right, right, right),
    header: ("Source", "Load cell", "Piezoresistive", "4–20 mA", "Voltage"),
    table.cell(
      colspan: 5,
      caps(
        [At the calibration temperature],
        size: size.tiny,
        tracking: track.label,
      ),
    ),
    [Noise, rms: converter 2.55~µV, buffers, protection and bridge 1.2~µV],
    [0.044],
    [0.002],
    [\<~0.001],
    [\<~0.001],
    [Converter nonlinearity, 2.8~ppm of its range],
    [\<~0.001],
    [\<~0.001],
    [0.001],
    [0.001],
    table.hline(stroke: (paint: ink.rule, thickness: rule.hair)),
    table.cell(
      colspan: 5,
      caps([Drift per 10~°C], size: size.tiny, tracking: track.label),
    ),
    [Converter offset, 0.035~µV/°C],
    [0.006],
    [\<~0.001],
    [\<~0.001],
    [\<~0.001],
    [Converter input current through 2 × 237~Ω, 0.76~µV/°C typical],
    [0.120],
    [0.005],
    [\<~0.001],
    [\<~0.001],
    [Buffer offset, 2 × 0.015~µV/°C],
    [0.005],
    [\<~0.001],
    [\<~0.001],
    [\<~0.001],
    [Buffer bias current through 2 × 10~kΩ and the bridge, 0.61~µV/°C],
    [0.097],
    [0.004],
    [\<~0.001],
    [\<~0.001],
    [Converter gain, 1.0~ppm/°C],
    [0.001],
    [0.001],
    [0.001],
    [0.001],
    [Reference resistors and the reference current of four converters],
    [0.040],
    [0.013],
    [0.003],
    [0.003],
    [Current-sense resistor, 5~ppm/°C],
    [—],
    [0.005],
    [—],
    [—],
    [#ident("REF5020"), 3~ppm/°C],
    [—],
    [—],
    [0.003],
    [0.003],
    [Excitation inverter resistors, 2 × 5~ppm/°C],
    [—],
    [—],
    [0.005],
    [0.005],
    [Shunt, 5~ppm/°C],
    [—],
    [—],
    [0.005],
    [—],
    [Divider, 2 × 5~ppm/°C],
    [—],
    [—],
    [—],
    [0.008],
    [Configuration switches: on-resistance, and leakage typical],
    [0.003],
    [0.001],
    [0.004],
    [0.006],
    table.hline(stroke: (paint: ink.rule, thickness: rule.hair)),
    [Drift, root sum square],
    [0.16],
    [0.015],
    [0.009],
    [0.012],
    [Drift, worst-case sum],
    [0.27],
    [0.029],
    [0.021],
    [0.026],
  ),
) <tab-gp-budget>

The buffers and protection add 20~nV/√Hz to the converter's noise, mostly the thermal noise of the two 10~kΩ resistors. In the wideband filter's noise bandwidth of about 3.5~kHz this is 1.19~µV~rms, which raises the channel noise from 2.55 to 2.81~µV~rms.

Offset drift sets the result for a load cell. A gain calibration cannot remove it, but a tare before each test resets it (FW-3). Two terms make up most of the drift. The first is the converter's input current through the 237~Ω pair. The datasheet gives that current and its drift only as typical values, ±1.5~µA and 5~nA/°C at the 25.6~MHz clock of high-speed mode, which are scaled here to 8.192~MHz. Mid-speed mode gives the same figures at 12.8~MHz, which would double the term, so the converter runs in high-speed mode (@tab-adc-config). The second term is the buffers' bias current through the 10~kΩ protection. The budget takes the change allowed between the 0.3~nA maximum at 25~°C and the 1.5~nA maximum at 85~°C, spread over that span. The typical bias current is 70~pA at 25~°C. For a piezoresistive transducer, whose signal is more than twenty times larger, the same terms come to about 0.01~%.

A bridge's reference is taken at the connector, so for a load cell the excitation wires sit inside it. A resistance of 1~Ω in each wire lowers a 350~Ω cell's reading by 0.57~%, and copper's 0.39~%/°C turns that into 0.02~% per 10~°C. Shunt calibration removes both at the time it is applied. A piezoresistive transducer is referenced to the current through it, which its wires cannot change, so its reading does not depend on them.

The excitation monitor adds no term (@sec-gp-monitor). What its dividers draw from #ident("EXC+") leaves before the sensor. At a piezoresistive channel's #ident("EXC−"), its buffer's bias current moves the current-sense resistor's share of the current by under 0.04~ppm/°C.

The configuration switches add at most 0.006~% per 10~°C (@sec-gp-switches). On-resistance drift dominates: S3's 1.4~ppm/°C in a load cell's reference, S9's 1.9~ppm/°C in the divider's bottom and S7's 3.7~ppm/°C in a transmitter's reference, which carries the reference current of four converters. The rest is leakage from S8's gate clamp into #ident("SIG−") and from the open MOSFETs at #ident("EXC−"), at most a few nanoamperes when hot. These leakage figures are typical, because the datasheets guarantee a MOSFET's leakage only at its full rated voltage, where it can reach 1~µA.

A bridge's REFP precharge buffer serves all four converters. It draws up to ±4~µA, and its drift of about 13~nA/°C at this clock sets the reference term for bridge sensors. Through a load cell's 10~kΩ that drift is 40~ppm/°C of the 3.2~V reference, and from a piezoresistive transducer's current-sense resistor it is 13~ppm/°C of the 1~mA.

Transmitters are measured against the excitation rather than ratiometrically, so their drift is that of the shunt or divider and of the excitation. The shunt, the divider and the inverter pair are 5~ppm/°C thin film, so no term exceeds 0.008~% per 10~°C. The #ident("REF5020") adds up to 70~ppm of thermal hysteresis after a temperature cycle and 22~ppm over its first 1000~hours, both of which recalibration removes. At 20~mA the shunt dissipates 40~mW. Each 10~°C that it rises above the board adds 0.005~% at 20~mA, and less at lower currents. Self-heating therefore bends the transfer curve, which a gain and offset correction does not remove.

Before calibration, the load-cell offset can reach 0.43~mV, 7~% of full scale: the converter's ±200~µV plus its input current through the 237~Ω pair, typically ±230~µV. The bridge gains are about 7~% high by design, because the four converters' reference currents flow through the resistors in the reference path, and the converter adds up to ±0.25~% of gain error.

== Excitation Monitor <sec-gp-monitor>

A channel's signal converter reads its sensor against a reference taken from the excitation, so the excitation drops out of the result. This makes the channel ratiometric, but it also hides the excitation from the signal converter. The other three converters of the channel's #ident("ADS127L14") therefore measure the excitation directly, at the same instant and rate as the signal and against the same reference (@tab-gp-monitor, @fig-gp-monitor). Each reads one node against the channel common. The excitation input reads #ident("EXC+") divided by 25, the return input reads #ident("EXC−") divided by 2, and the bus input reads the positive side of the bus divided by 4.

#[
  #set par(justify: false)
  #figure(
    caption: [Excitation Monitor Inputs],
    datatable(
      columns: (auto, 1fr, 1fr, 1fr, 1fr),
      align: (left, left, left, left, left),
      header: ("Input", "Load cell", "Piezoresistive", "4–20 mA", "Voltage"),
      [Reference],
      [Bridge voltage, 3.2~V],
      [Sense voltage, 1.0~V],
      [Bus, 4.096~V],
      [Bus, 4.096~V],
      [Excitation, from #ident("EXC+"), ÷25],
      [Bridge top, 1.1~V],
      [Bridge top, 2.5~V],
      [Loop supply, 23~V],
      [Supply, 23~V],
      [Return, from #ident("EXC−"), ÷2],
      [Bus, −2.05~V: #ident("EXC−") is on the bus],
      [Sense resistor top, −1.05~V],
      [Channel common, 0~V],
      [Channel common, 0~V],
      [Bus, from the bus, ÷4],
      table.cell(colspan: 4)[2.048~V in every configuration, fixed by the #ident("REF5020")],
    ),
  ) <tab-gp-monitor>
]

#figure(
  caption: [Excitation Monitor],
  gp-monitor(),
) <fig-gp-monitor>

Every reading is a fraction of the channel's reference, and the readings serve four purposes.

The first is to measure the temperature of a piezoresistive transducer. The transducer's reference is the voltage across the current-sense resistor, so the excitation reading less the return reading, each scaled by its divider, is directly the ratio of the bridge resistance to the 1.00~kΩ current-sense resistor. The bridge resistance rises with temperature by 1800 to 3000~ppm/°C, so the ratio gives the transducer's temperature. Keller specifies the 7L's span to within 0.06~%/°C and its compensated zero to within 0.025~% of full scale per °C. Given the transducer's characterisation, the measured temperature lets the ECU MCU board correct what remains. A temperature known to a third of a degree holds the correction's own error near 0.02~% of full scale, which requires the ratio to stay within about 600~ppm for each 10~°C of board temperature.

The second is to measure the supply of a transmitter. The bus reading, fixed at 2.048~V, turns the excitation reading into volts, which shows a supply sagging under load or a loop held at its 30~mA limit.

The third is to detect faults in every configuration. An open or unplugged bridge lets its current source drive #ident("EXC+") up to the sensor supply, and a shorted bridge or cable collapses the bridge voltage. A damaged cable shows as a change of a few per cent in the bridge voltage, which the bus reading puts in volts. Detecting these faults needs an accuracy of only about 1~%.

The fourth is to drive the interlocks. The FPGA compares every reading with limits set for the channel's configuration, and turns the channel off within one sample when a reading crosses its limit (GW-3).

The three monitor inputs sample with the signal, from the same clock and against the same reference. The ratio of any two readings therefore does not depend on the reference, and every reading lines up with the signal sample taken at the same instant. The FPGA passes the readings to the ECU MCU board at the full 8~kSPS (GW-5), each with the converter's 2.55~µV~rms of noise.

Dividers to the channel common bring every node within the converter's input range in every configuration. The narrowest case is the ±1.0~V allowed under a piezoresistive transducer's reference. The excitation input sees 0.96~V when an open sensor lets its current source rise to the 24~V supply.

The converter's inputs draw up to about 0.5~µA at this clock, drifting by 1.6~nA/°C. Through the 9.6~kΩ of the ÷25 divider this would be 5~mV and 15~µV/°C, too much for the 600~ppm, so one half of a second #ident("OPA2189") buffers the divided excitation input. The return and bus dividers present under 1~kΩ to the converter, so its input current moves their readings by under 0.1~%. The bus divider loads the bus amplifier with 0.5~mA.

A piezoresistive transducer's #ident("EXC−") lies between its bridge and its current-sense resistor. Current drawn there would pass through one and not the other, which would be a gain error in the channel's own reading. The other half of that #ident("OPA2189") therefore buffers #ident("EXC−") before its divider, through 10~kΩ that limits a fault's current into the amplifier's input. The amplifier's input bias current, at most 1.5~nA to 85~°C, is 1.5~ppm of the excitation current, and through the 10~kΩ it adds at most 15~µV, 15~ppm of the current-sense voltage. An unused #ident("EXC−"), as on a channel with nothing connected, is held to the negative side of the bus by the 1.00~kΩ current-sense resistor, which is fitted in every configuration.

The converter's own errors are small beside its readings. Its offset drift is 35~nV/°C, its nonlinearity 2.8~ppm of its range and its gain drift 1~ppm/°C, all maximum, and the gain drift cancels in a ratio. Calibration at test removes its offset, and no zeroing is needed in use. The dividers therefore set the stability. Any channel may carry a piezoresistive transducer, so every divider is 0.1~%, 5~ppm/°C thin film. Opposing drift in the excitation and return dividers moves the resistance ratio by at most about 100~ppm per 10~°C, and the drift of the reference current through the 237~Ω at the reference pins adds about 60~ppm more. Together they stay within the 600~ppm.

== Input Protection <sec-protection>

Every sensor contact leaves the board through the vehicle harness. There it can meet a fault from another circuit, a discharge during handling, and transients coupled from the igniter and valves. The board must survive all three. REQ-14 sets the levels of discharge and transient, and REQ-15 sets the fault at 28~V, the highest voltage in the harness.

Each of the 16 sensor contacts has a bidirectional suppressor to the channel common, at the connector pin. Its breakdown lies above 28~V, so neither the 24~V sensor supply nor a 28~V fault makes it conduct, and the fault is left to the parts behind it. The suppressor must be bidirectional, because #ident("EXC−") and the signal contacts sit up to 2~V below the channel common in use, where a unidirectional part would conduct. Its clamping voltage at the test currents must stay below 40~V, the drain rating of S8, which is the lowest-rated part on a contact. A flat-clamp suppressor holds that, whereas an avalanche diode of the same breakdown rises well above it. The other parts on the contacts are rated higher: S4 at 50~V, and S3 and the photorelay at 60~V. S1, S2 and S5 sit behind series resistors.

On #ident("EXC−") the body diodes of S3 and S4 conduct before the suppressor does, S4's to the channel common and S3's to the bus. They hold #ident("EXC−") within about 0.7~V of those, so the current-sense resistor and the switch terminals on #ident("EXC−"), S6's and S10's, never see more than a few volts. The two MOSFETs then carry part of a discharge, and they are to be tested at the REQ-14 levels on the first boards. If needed, a few ohms in series with S4, which carries only a transmitter's supply return, would relieve it.

A suppressor returns a discharge to its channel's common, which must hand it to the vehicle without crossing the isolation barrier. The capacitor across that channel's vehicle-tie resistor does that (OI-3). Because each channel has its own common, a sensor bonded to the vehicle references only its own channel, and a fault on another channel's contacts finds no path through it.

At the few volts a measured contact sees in use, a suppressor leaks far less than its rating at stand-off. A part rated 1~µA at 30~V is expected to leak under 10~nA at 2.5~V. On #ident("EXC+") the leakage leaves before both the bridge and the current-sense resistor, so no reading changes. On #ident("EXC−") it is a ratio error in a piezoresistive channel, 1~ppm per nanoampere. On #ident("SIG+") and #ident("SIG−") the two suppressors sit at nearly the same voltage, so their leakage largely cancels. The difference flows through the bridge's output resistance and gives 0.18~µV, or 0.003~% of full scale, per nanoampere for a 350~Ω load cell. The part chosen must hold that difference near a nanoampere, which is to be measured on the first boards.

Surge to IEC~61000-4-5 is not required. The harness is taken to be shorter than 30~m, with no connection to mains or to lines exposed to lightning. A surge rating would call for suppressors several times the size.

#figure(
  caption: [Behaviour under a 28~V Fault],
  datatable(
    columns: (auto, auto, 1fr),
    align: (left, left, left),
    header: ("Contact", "In use", "A 28 V fault"),
    ident("EXC+"),
    [−1 to 24~V],
    [Lifts the #ident("LT3092")'s output above its input, which it blocks: under 1~mA flows back. S5 sits behind 10~kΩ and the monitor behind 240~kΩ.],
    ident("EXC−"),
    [−2.05 to 0~V],
    [Flows into the bus through S3 where it is closed, and otherwise to the channel common through S4's body diode, 0.7~V above it. The current-sense resistor then carries at most 2.8~mA.],
    [#ident("SIG+"), #ident("SIG−")],
    [±2~V; #ident("SIG+") to 10~V for a voltage transmitter],
    [Reaches the buffers through 10~kΩ: 2.3~mA into their clamps. S8 blocks it while open, rated 40~V, and S9, rated 60~V. Where the configuration closes them it flows through the shunt or the divider to the channel common.],
  ),
) <tab-protection>

Most of these paths survive a fault from any source, but three are low-impedance by design: S3 into the bus in the load-cell configuration, S4's body diode, and the shunt with S8 in the #box[4–20~mA] configuration, which returns through the cable link and S4. These three survive a current-limited fault indefinitely. Another channel's sensor supply at 30~mA, for example, dissipates 21~mW in S4's diode and 90~mW in the shunt. A low-impedance source such as a valve supply would destroy S4 or the shunt. Through S3 it would instead hold the channel's bus at its amplifier's ±65~mA limit and take the channel's excitation while it lasts (OI-5). In every case the damage stays within the faulted channel.

== Data Collection <sec-fpga>

The FPGA on the stack side of the barriers is the board's only connection to its SPI lane (@sec-interfaces). It runs from #ident("SYNC_CLK") and from the 3.3~V input.

The FPGA configures each channel's #ident("ADS127L14") over the channel's own SPI, sets the channel's configuration code, and reads both back (GW-1, GW-2). It retimes #ident("SYNC_START") to an edge of #ident("SYNC_CLK") and starts the four converters on that edge, so that they sample at the same instant as every other converter in the stack (INT-6). It receives the four channels' frame-sync data ports in parallel and checks the status and CRC of every packet. When a channel's converter, code read-back or excitation monitor shows a fault, the FPGA turns that channel off within one sample (GW-3). It can also switch a channel's supply off and on through the enable of that supply's current limit, and it reads the limit's fault flag. Finally, it clocks the four channels' #ident("SN6505B") at 1.024~MHz, an eighth of #ident("SYNC_CLK"), which they divide by two (@sec-gp-chain).

The FPGA applies each channel's calibration (GW-4) and gathers all sixteen readings of each sample into a frame of fixed format (GW-5). It numbers every frame from the last start, packs eight frames into a packet of 1~ms with a CRC, and buffers 20~ms of packets (GW-6, INT-10). It serves the packets and its registers to the ECU MCU board as a peripheral on SPI0, and reports in every read how much data it still holds (INT-10). It acts on a register write only if the write's CRC is correct (GW-7).

The FPGA is a Lattice #ident("LCMXO2-4000HC-4QN84C"). It has 4320 LUTs, 92~kbit of block RAM, two PLLs and 68 I/O in a 7 × 7~mm QFN-84. It is the commercial temperature grade, with a junction range of 0 to 85~°C, and the slowest speed grade, which suffices because the gateware's clocks run at 20~MHz and below. Its PLL accepts the 8.192~MHz of #ident("SYNC_CLK"), and as an HC device it runs from the 3.3~V input alone, with no core regulator.

The FPGA configures itself from its internal flash at power-up (GW-8). The ECU MCU board writes a new configuration into that flash in the background, through a hardened SPI configuration port that every image keeps enabled. If the new configuration fails to load, the FPGA falls back to a golden image held in an SPI flash beside it (FW-4). The FPGA writes the golden image only after a separate unlock command (GW-8). A timer on the board pulls the FPGA's PROGRAMN input low when the board's chip select is held low for more than 200~ms, so the ECU MCU board can make a hung FPGA reconfigure without a power cycle of the stack (GW-9).

The FPGA uses 46 of its 68 I/O. Each channel has seven of its own, so that a failed isolator input in one channel cannot load another: SCLK, SDI, CS and START out, and SDO, DOUT and FSYNC in. The SPI lane, #ident("SYNC_CLK") and #ident("SYNC_START") take six I/O, the channels' supply enables and fault flags eight, the supply clock one, and the configuration flash and PROGRAMN three. The 20~ms buffer takes about 64~kbit, 69~% of the block RAM. At 16~kSPS it would take 125~kbit, which would not fit.

The FPGA, the current limits and the bus buffer are the board's single points of failure. A failed FPGA costs its board's four channels but no other board, because the buffer stands between it and every shared line (@sec-stacking). Only a failed buffer could hold a shared line.

== Stacking <sec-stacking>

Boards stack on #ident("ASRP-PCB-INTERCONNECT-2") together with the #ident("E004-TC-BOARD"). The ADC boards share SPI0 to the ECU MCU board, and SPI1, which serves the #ident("E004-TC-BOARD"), passes through them unused (@tab-interconnect-signals). A 2 × 4 header connects each board to one of the four chip selects of SPI0 with a single shunt, so every board is built the same (INT-1). A 100~kΩ pull-up holds the chip select of an unjumpered board high.

An #ident("SN74LVC244A") octal buffer stands between the board and the interconnect. Its two groups of four buffers have separate output enables. The first group is always enabled and takes the chip select, #ident("SYNC_CLK"), #ident("SYNC_START") and the SPI clock. The buffered chip select enables the second group, which takes the SPI data in and drives #ident("SPI0_MISO") through 62~Ω series termination, so the board drives that line only while it is selected (INT-4). The second group's other two buffers are spare. While the board is deselected, a pull-up inside the FPGA holds the data input high. The buffer's partial-power-down protection limits the leakage into any pin of an unpowered board to 10~µA, and the chip select's pull-up adds at most 33~µA, so an unpowered board leaves every line at high impedance (INT-4). The buffer also keeps a failed FPGA or isolator input off the shared lines. #ident("SYNC_CLK") goes from the buffer to the FPGA directly and to each channel's isolator through its own 1~kΩ, so a failed isolator input loads the buffer with at most 3.3~mA and the other channels keep their clock.

The read path has no isolator in it. The FPGA answers within about 15~ns of an SCLK edge, and the buffer adds at most 5.9~ns on the way in and again on the way out, so #ident("SPI0_MISO") is valid at the connector within about 27~ns. That meets the 30~ns of INT-8, so the lane runs at up to 20~MHz. The buffer enables its output within about 13~ns of the chip select falling, well inside the delay that the master leaves before its first clock edge. Each board produces about 3.2~Mbit/s, so four boards use 12.7~Mbit/s, within the 15~Mbit/s that SPI0 carries (INT-9). The ECU MCU board reads the boards one at a time, in any order, and aligns their samples by number (GW-6).

One source drives #ident("SYNC_CLK") and #ident("SYNC_START") to every board, so all boards of both kinds sample in step (REQ-6, INT-5, INT-6). In the ECU stack that source is the ECU MCU board, on which every board already depends.

A #ident("TPS2553") current-limited switch on each of the board's 5~V and 3.3~V inputs, set to 1.2~A and 0.15~A, holds a board that fails short off the stack rails. A further #ident("TPS2553") on each channel's supply, set to 0.3~A, keeps a failed channel supply from tripping the board's limit. Redundant sensors for a critical measurement belong on different boards, so that no single board fault takes out both.

== Component Selection

#[
  // The table runs over more than one page, with its header repeated.
  #show figure: set block(breakable: true)
  #figure(
    caption: [Component Selection],
    datatable(
      columns: (auto, auto, 1fr),
      align: (left, left, left),
      header: ("Function", "Part", "Basis"),
      [General-purpose converter],
      [4 × #ident("ADS127L14")],
      [One per channel. Four simultaneous converters against one reference: the signal and three monitor inputs. Wideband filter flat to 0.4 of the data rate with 106~dB stop band. 2.55~µV~rms at 8~kSPS in high-speed mode. Offset drift 35~nV/°C, gain drift 1~ppm/°C, nonlinearity 2.8~ppm, all maximum in high-speed mode. GPIO pins for the configuration code, a frame-sync data port, 1.8~V I/O. 7 × 7~mm VQFN-56.],
      [Buffers and excitation drivers],
      [12 × #ident("OPA2189")],
      [Zero-drift, 5.2~nV/√Hz, input bias 300~pA maximum, offset drift 0.006~µV/°C typical, ±65~mA output limit. Three per channel: the signal inputs, the two sides of the excitation bus, and the monitor's excitation and return inputs.],
      [Excitation reference],
      [4 × #ident("REF5020")],
      [2.048~V, 3~ppm/°C maximum (high grade). One per channel.],
      [Precision resistors],
      [Vishay TNPU e3],
      [Thin film, 0.05~%, 5~ppm/°C: the #box[4–20~mA] shunt, the 10.0~kΩ SIG+ series resistor and the excitation inverter pair in 0805, and the 2.49~kΩ divider bottom and the 1.00~kΩ current-sense resistor in 1206. Also the excitation monitor's dividers.],
      [Channel isolated supply],
      [4 × #ident("SN6505B"), 4 × transformer (TBD)],
      [1~A push-pull driver, clocked by the FPGA to switch at 512~kHz, with a 1.7~A internal limit. A 1:1.1 centre-tapped transformer of about 1~W, 2500~V~rms, per channel (TBD). Four 30~V 1~A Schottky diodes per channel (TBD) as the bridge for ±5~V.],
      [Channel regulators],
      [4 × #ident("TPS7A39"), 4 × #ident("TLV704")],
      [Dual positive and negative LDO for ±2.5~V: 150~mA each, ±3.3 to ±33~V in, outputs track at start-up, 21~µV~rms. 150~mA LDO for 1.8~V (#ident("TLV70418")): the converter's I/O, the code decoders and the isolators' channel side. Both tolerate the rectified rails at light load.],
      [Rail clamps],
      [4 × #ident("TLV431B"), 4 × PNP (TBD)],
      [Shunt clamp on each +2.5~V rail at about 2.7~V, sinking up to 25~mA: a 0.5~% shunt reference, set by 118~kΩ over 100~kΩ, driving a PNP transistor. Draws nothing in normal operation (@sec-gp-chain).],
      [Sensor supply],
      [4 × #ident("TPS61170")],
      [Boost from the channel's +5~V to 24~V. 1.2~A switch, 38~V output maximum, 1.2~MHz, 2 × 2~mm QFN. Inductor and 40~V Schottky (TBD).],
      [Sensor current sources],
      [4 × #ident("LT3092")],
      [2-terminal current source, 0.5 to 200~mA, 1.2 to 40~V, thermal limit, set by its output resistor, which S1 and S2 switch: 1.0~mA for a piezoresistive transducer, 9.0~mA for a load cell, 30~mA for a transmitter. 3 × 3~mm DFN.],
      [Channel isolation],
      [4 × #ident("ISO6720B"), 12 × #ident("ISO6721B")],
      [Dual isolators, 50~Mbps, 3000~V~rms basic, 1.71 to 5.5~V on either side, so the channel side runs at the converter's 1.8~V. Two forward channels, and one each way: five lines into each channel and three out (@tab-gp-barrier). Default output high. Narrow SOIC-8.],
      [FPGA],
      ident("LCMXO2-4000HC-4QN84C"),
      [4320 LUTs, 92~kbit of block RAM, two PLLs from 7~MHz, 68 I/O of which 46 are used. Internal flash programmed in the background through a hardened SPI port, dual boot with a golden image in an external SPI flash, soft-error detection, single 3.3~V supply. Commercial temperature grade, junction 0 to 85~°C, and speed grade −4. 7 × 7~mm QFN-84 with two rows of pads (@sec-fpga).],
      [Golden image],
      [SPI flash (TBD)],
      [Holds the FPGA's golden configuration (GW-8).],
      [Reconfiguration timer],
      [TBD],
      [Schmitt-trigger gate and RC: pulls PROGRAMN low after the board's chip select has been low for 200~ms (GW-9).],
      [Code decoders],
      [4 × #ident("SN74LVC138A"), #ident("SN74LVC00A"), #ident("SN74LVC2G04")],
      [Per channel a 3-to-8 decoder, four NAND gates and two inverters from the 1.8~V rail: the configuration code to active-high enables for the #ident("TMUX6212") select inputs (@sec-gp-switches).],
      [Input clamps],
      [BAV199 class (TBD)],
      [Low-leakage series pair to the channel's ±5~V rails, one per input.],
      [Contact suppressors],
      [16 × TBD],
      [Bidirectional flat-clamp, breakdown above 28~V, clamping below 40~V at the REQ-14 test currents, low leakage at a few volts. One per sensor contact, the same part as on the #ident("E004-TC-BOARD") (@sec-protection). TI's #ident("TVS3301") is the candidate, 3 × 3~mm SON (OI-4).],
      [Configuration switches within the rails],
      [8 × #ident("TMUX6212")],
      [Four SPST channels, each closed by logic high, with internal pull-downs so that all open by default. ±4.5 to ±18~V supply, 1.8~V logic. At ±5~V, 7.6~Ω and 2~nA leakage maximum to 85~°C, 0.015~Ω/°C drift. S6, S7 and S10, and the ±5~V gate drive of the MOSFET switches; two per channel. 4 × 4~mm WQFN.],
      [Current-branch switches],
      [8 × #ident("DMP3099L")],
      [P-channel, −30~V, ±20~V gate. 99~mΩ at −4.5~V, threshold −1.0 to −2.1~V. S1 and S2. SOT-23.],
      [Load-cell return switch],
      [4 × #ident("DMN6075S")],
      [N-channel, 60~V, ±20~V gate. 85~mΩ at 10~V, 120~mΩ at 4.5~V. S3. SOT-23.],
      [Shunt switch],
      [4 × #ident("DMTH4008LFDFWQ")],
      [N-channel, 40~V, ±20~V gate, logic level. 18~mΩ maximum at 4.5~V, rising about 0.4~%/°C. S8. 2 × 2~mm DFN.],
      [Small-signal switches and drivers],
      [20 × #ident("BSS138W")],
      [N-channel, 50~V, ±20~V gate. 3.5~Ω at 10~V, leakage 0.5~µA maximum at 50~V. S4 and S5, the current-branch gate drivers and the photorelay LED driver. SOT-323.],
      [Photorelays],
      [4 × #ident("TLP3475S")],
      [60~V, 0.4~A, 1.5~Ω. Off-state leakage 1~nA maximum at 50~V, 25~°C. 500~V~rms input to output. S9. 2.0 × 1.45~mm.],
      [Gate clamps],
      [#ident("MMSZ5246B")],
      [Zener, 16~V, for S1, S2, S4 and S8. Leakage 0.1~µA maximum at 12~V. SOD-123.],
      [Bus buffer],
      [#ident("SN74LVC244ARKSR")],
      [Octal 3-state buffer in two groups of four with separate enables. 5.9~ns maximum at 3.3~V, 7.6~ns to enable, partial-power-down protection with 10~µA maximum leakage while unpowered, 4~pF input. One group takes the chip select, the clock lines and #ident("SYNC_START"). The other, enabled by the chip select, takes the SPI data in and drives #ident("SPI0_MISO"), with two buffers spare (@sec-stacking). 4.5 × 2.5~mm VQFN-20.],
      [Clock resistors],
      [4 × 1~kΩ],
      [In series with #ident("SYNC_CLK") from its buffer to each channel's isolator.],
      [Chip-select jumper],
      [2 × 4 header (TBD)],
      [2~mm pitch, Harwin M22 family. One shunt picks one of the four chip selects of SPI0.],
      [Sensor connector],
      ident("M80-5001842"),
      [Harwin Datamate J-Tek, 18-way, 2~mm pitch, vertical through-hole, M2 jackscrews, −55 to 125~°C. 800~V working between contacts. Part number to be confirmed.],
      [Stack connector],
      [TBD],
      [#ident("ASRP-PCB-INTERCONNECT-2"), 32-way, pass-through (INT-1, INT-3).],
      [Input current limits],
      [6 × #ident("TPS2553")],
      [Current-limited switch, 2.5 to 6.5~V, limit set from 75~mA to 1.7~A. 1.2~A on the board's 5~V and 0.15~A on its 3.3~V, and 0.3~A on each channel's supply.],
    ),
  ) <tab-components>
]

= Physical Implementation <sec-physical>

Appendix A draws the general-purpose channel as this summary describes it. The board carries four instances of that sheet, of which only the first is placed while it is laid out. The stack sheet and the interconnect still draw the earlier design (OI-2). No board has been laid out, so these estimates set the budget for REV A.

#params(
  cols: 4,
  ("Board", raw("e003-adc-board")),
  ("Revision", [—]),
  ("Board Area", [60 × 60~mm, 72~cm² on two sides]),
  ("Stack-up", [TBD]),
  ("Placement Area", [69~cm²]),
  ("Sensor Connector", [#ident("M80-5001842")]),
  ("Stack Connector", [TBD, 32-way]),
  ("Input Power", [1.5 to 5.5~W, estimated]),
)

The estimate sums the parts' courtyards and allows 1.6 times that for placement, which leaves about 40~% of the area under the parts for vias, routing and test access. The outline gives 72~cm² over its two sides (REQ-2). The connectors, the four M3 mounting holes, the board edge and the isolation gaps take part of each side: 3~mm between the channels and the stack side, and 2~mm between neighbouring channels. The parts must fit in what remains (@tab-area).

#figure(
  caption: [Board Area Estimate],
  datatable(
    columns: (1fr, auto),
    align: (left, right),
    header: ("Item", "Area"),
    [Four channels: front ends, current sources and switches],
    [24.0~cm²],
    [Four channels: isolated supplies, sensor supplies and clamps],
    [18.3~cm²],
    [Four channels: isolators and vehicle ties],
    [10.2~cm²],
    [Four channels: converters and monitors],
    [8.6~cm²],
    [Four channels: excitation],
    [4.6~cm²],
    [Stack side: FPGA, flash, buffer and current limits],
    [3.4~cm²],
    table.hline(stroke: (paint: ink.rule, thickness: rule.hair)),
    [Parts, placed],
    [69~cm²],
    [Connectors, holes, isolation gaps and edge, both sides],
    [22~cm²],
    [Left for parts, both sides],
    [50~cm²],
    [Use of what is left],
    [139~%],
  ),
) <tab-area>

The parts need about 40~% more area than the outline leaves them. Between placement allowances of 1.4 and 1.8 the use runs from 122 to 156~%. A channel takes 16.5~cm² once placed, of which its own supply and isolation take 7.1~cm²: those are the cost of isolating each channel on its own. The overrun is recorded as OI-6.

Input power is about 1.5~W per board, plus about 0.3~W for each channel set up for a load cell and 1.0~W for each set up for a transmitter, so 1.5 to 5.5~W.

- Each channel is laid out as an island of its own, with its isolators and its transformer straddling the gap to the stack side, and nothing but the barrier between it and its neighbours.
- A channel's contacts sit together on the sensor connector (@tab-sensor-pinout), so the gaps between the islands run between pin groups at the connector.

= Open Issues <sec-open-issues>

Issues known at this revision and not resolved in it.

#show figure.where(kind: table): set par(justify: false)

#figure(
  caption: [Open Issues],
  datatable(
    columns: (auto, 2fr, 3fr),
    align: (left, left, left),
    header: ("Item", "Issue", "Disposition"),
    ident("OI-1"),
    [5~V current of a full stack exceeds the #ident("E001-POWER-BOARD") rail],
    [Four ADC boards with a transmitter on every channel and four #ident("E004-TC-BOARD") draw 4.36~A at 5~V, so INT-2 requires 4.5~A against the 2~A that the rail provides for the whole ECU stack. The rail must be redesigned to meet it. Not resolved in this revision. The number of transmitter channels in a stack is held to what the rail can spare. Isolating each channel on its own added about 0.5~W per board in supply losses and isolators.],

    ident("OI-2"),
    [Stack side of the schematic predates the FPGA],
    [The general-purpose channel in Appendix A is drawn as this summary describes it. The stack sheet and the interconnect still draw the earlier design, with no FPGA, the earlier bus buffer and the earlier interconnect pinout, and are to be redrawn with the FPGA. Until then the channels' lines to the FPGA end at the gp sheet. Parts without a library record are placeholders, marked \*: the new ICs, held as symbols in the project library, and the transformers, diodes, inductors, suppressors, the PNP of the rail clamp, the converters' 330~pF common-mode capacitors and the precision and odd-value resistors. The 18-way connector's part number is to be confirmed, and its footprint extends the 12-way #ident("M80-5001242") to 18 ways. Every part of a channel has a footprint. Those of the parts not yet chosen assume a package: TI's 3 × 3~mm SON for the suppressors, the Würth #ident("750315371") for the transformer, SOD-123 for the Schottky diodes, SOT-23 for the rail clamp's PNP and 4 × 4~mm for the boost inductor.],

    ident("OI-3"),
    [Vehicle-tie resistance],
    [Each channel ties to the vehicle through a resistor behind the shield jumper, with a capacitor across it that returns transient current to the vehicle (@sec-protection). Both values depend on the vehicle grounding scheme and are TBD.],

    ident("OI-4"),
    [Transformers, logic and suppressors not chosen],
    [The FPGA's golden-image flash, the reconfiguration timer, the channels' transformers and the PNP of each rail clamp, and the 16 contact suppressors are specified by function (@sec-fpga, @sec-gp-chain, @sec-protection) but not chosen. The suppressor is to be the same part as on the #ident("E004-TC-BOARD"). It needs a breakdown above 28~V, a clamp below 40~V and low leakage at a few volts. TI's #ident("TVS3301") is the candidate the schematic carries: bidirectional, with a breakdown of 34.4~V minimum and 2.5~nA typical leakage at 33~V. It clamps at 40~V typical and 42.5~V maximum at 27~A, which reaches S8's rating, so whether it protects S8 at the REQ-14 test currents is still to be shown. TI's other bidirectional flat-clamp parts share its package, so the footprint stands whichever of them is chosen.],

    ident("OI-5"),
    [Low-impedance faults on the excitation and current-loop paths],
    [These paths meet REQ-15 only against a current-limited source. A low-impedance 28~V source on #ident("EXC−"), or on #ident("SIG+") in the #box[4–20~mA] configuration, can destroy S4 or the shunt, or hold the channel's bus at its amplifier's limit (@tab-protection). The damage stays in that channel. Acceptable if no such source in the harness can reach these contacts. Otherwise those paths need a fuse or current limit, which on #ident("EXC−") costs precision.],

    ident("OI-6"),
    [Parts exceed the board area],
    [The parts need 69~cm² once placed against 50~cm² left on the 60 × 60~mm outline, 139~% (@tab-area). Deferred: isolating each channel was chosen first, and the area is to be recovered later, by a larger outline, fewer channels per board, smaller parts or denser placement.],

    ident("OI-7"),
    [Gateware],
    [The FPGA's gateware, its verification and its update procedure are to be written to GW-1 to GW-9. It carries the configuration interlocks that firmware carried before (@sec-gw).],
  ),
) <tab-open-issues>

// =============================================================================
//  APPENDIX
//
//  `assets/` is written by `dcs`, which re-plots the schematic only when a
//  .kicad_sch is newer than the export and re-prices the BOM when a sheet
//  changes.  Compiling this file never invokes KiCad or plm; it only reads
//  what the build left behind.
//
//  There is no board yet, so no Bill of Materials: its appendix goes before
//  the Schematics, as in e001-power-board, once the [bom] table in dcs.toml
//  is enabled.
// =============================================================================

#let schematics = json("assets/manifest.json")

#pdf-appendix(
  read(schematics.pdf, encoding: none),
  sheets: schematics.sheets,
  title: [Schematics],
  index-caption: [Schematic Sheet Index],
)
