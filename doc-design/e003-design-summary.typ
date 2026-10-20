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
    The ADC board is the analog data acquisition board of the ASRP ECU stack. Each board provides two general-purpose channels with a 2~kHz bandwidth, configurable for load cells, piezoresistive pressure transducers, #box[4–20~mA] transmitters and voltage transmitters. Both channels are referenced to the stack's ground. All converters in the stack sample synchronously, and an onboard FPGA collects, checks and buffers their data. Boards stack to scale the channel count, alongside the #ident("E004-TC-BOARD") for thermocouples, and connect to the ECU MCU board over a dedicated stacking interconnect that carries both power and data.
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

The #ident("E003-ADC-BOARD") is the analog data acquisition board of the ECU stack for the Advanced Small Rocket Project (ASRP). Each board carries two general-purpose channels, each configurable for a load cell, a piezoresistive pressure transducer, a #box[4–20~mA] transmitter or a voltage transmitter, and boards stack to reach the required channel count. The measurements are flight-critical, so a fault on a sensor or its cable must not affect the other channel, and a fault on one board must not affect the rest of the stack. Redundant sensors for a critical measurement can then be connected to different boards.

The boards connect to the ECU MCU board over #ident("ASRP-PCB-INTERCONNECT-2"), a stacking interconnect defined in this document (@sec-interfaces), which distributes the 24~V, 5~V and 3.3~V rails and carries the data of every board. The ECU MCU board configures each board, reads the data buffered by its FPGA and logs it to eMMC.

== Requirements

Requirements phrased "must" are mandatory, and those phrased "should" are design goals.

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
    [Device must draw power only from the 24~V, 5~V and 3.3~V rails of #ident("ASRP-PCB-INTERCONNECT-2")],
    [Local],
    [REQ-4],
    [Device must be configured and read by the ECU MCU board over #ident("ASRP-PCB-INTERCONNECT-2")],
    [Local],
    [REQ-5],
    [Device must provide two general-purpose analog input channels],
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
    [Device must reference its general-purpose channels to the ground of #ident("ASRP-PCB-INTERCONNECT-2"), in one domain with the stack],
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

Each board carries two identical general-purpose channels and an FPGA (@fig-arch). Each channel comprises a front end, a converter and an excitation source. The FPGA configures the channels, collects their data and supplies it to the rest of the stack over #ident("ASRP-PCB-INTERCONNECT-2").

#figure(
  caption: [Board Architecture],
  board-arch(),
) <fig-arch>

Both channels share the stack's ground and run from the stack's 5~V rail through an FPGA-controlled current limit. Each channel limits the current draw of its sensor and cabling. The sensor is powered from the stack's 24~V rail through the channel's current source, which caps its current at 30~mA. The signal contacts reach the front end through 10~kΩ series resistors, and the excitation bus amplifier limits its output to ±65~mA. A shorted sensor or cable therefore draws a bounded current from each supply, and the other channel continues to operate. A fault in the channel circuitry, by contrast, can trip the current limit and remove power from both channels, so redundant sensors for one measurement belong on different boards.

Because the channels are referenced to the stack's ground, a sensor whose circuit is bonded to the vehicle would connect the vehicle structure to that ground through its cable. SEN-1 therefore requires every sensor's circuit to be insulated from its case.

Within each channel, the current source excites the sensor, and a ±2.048~V excitation bus, set by the channel's own reference, serves as the return for a bridge and as the reference for a transmitter. Ten switches configure the channel for its sensor (@sec-gp-switches). The sensor signal is buffered and digitized by the first of the four converters in the channel's #ident("ADS127L14"), while the other three monitor the excitation (@sec-gp-monitor). A transient suppressor on every sensor contact absorbs discharges and fast transients, and the parts behind it withstand a sustained 28~V fault (REQ-15, @sec-protection). A few paths from a contact into the channel are low-impedance by design, and these withstand the fault only from a current-limited source (OI-5).

The FPGA configures the channels and gathers their data. It checks every sample, applies the calibration and packs the data into numbered packets, which it buffers until the ECU MCU board reads them (@sec-fpga). When a channel's monitor reports a fault, the FPGA turns that channel off within one sample.

Boards stack to add channels and share one SPI lane to the ECU MCU board. A single clock and a single start signal reach every board, so every converter in the stack samples at the same instant (@sec-stacking). Each supply input of the board is current-limited or fused, so a failure on one board cannot pull down the rails that the stack shares.

In the block diagrams, heavy lines carry power, dashed lines carry digital data and thin lines carry analog signals.

== Operations Concept

TBD

== Interfaces <sec-interfaces>

The board has two external interfaces (@tab-interfaces). #ident("ASRP-PCB-INTERCONNECT-2") connects it to the ECU MCU board and to the other boards of the stack, and the sensor connector connects it to its two sensors. The board does not use #ident("ASRP-PCB-INTERCONNECT-1").

#figure(
  caption: [External Interfaces and Signals],
  datatable(
    columns: (auto, auto, 1fr),
    align: (left, left, left),
    header: ("Interface", "Part", "Signals"),
    ident("ASRP-PCB-INTERCONNECT-2"),
    [TBD, 32-way],
    [24V ×2, 5V ×4, 3V3 ×2, GND ×8, SYNC_CLK, SYNC_START, two SPI lanes with four chip selects each],
    [Sensor connector],
    [#ident("M80-5001242"), 12-way],
    [EXC±, SIG± for two general-purpose channels, a shield pair],
  ),
) <tab-interfaces>

#ident("ASRP-PCB-INTERCONNECT-2") is a stacking interconnect defined in this document. It connects one SPI master to up to eight peripheral boards, each of which passes every contact through to the next. It carries 24~V, 5~V and 3.3~V power, two independent SPI lanes with four chip selects each, and a clock and a start signal that synchronize sampling across the stack (@tab-interconnect-pinout, @tab-interconnect-signals). The definition is generic: it does not assume which boards act as the master and the peripherals.

In the ECU stack the ECU MCU board is the master. The ADC boards share SPI0 and the #ident("E004-TC-BOARD") share SPI1, so each lane serves up to four boards of one kind. Every converter in the stack runs from #ident("SYNC_CLK") and starts on the same edge of it, so all boards sample at the same instant. Because each ADC board numbers its samples from the last start (GW-6), the master can align the data of every board regardless of the order and timing of its reads.

#figure(
  caption: [#ident("ASRP-PCB-INTERCONNECT-2") Pinout],
  datatable(
    columns: (auto, 1fr, auto, 1fr),
    align: (center, left, center, left),
    header: ("Pin", "Signal", "Pin", "Signal"),
    [1],
    ident("24V"),
    [2],
    ident("24V"),
    [3],
    ident("GND"),
    [4],
    ident("GND"),
    [5],
    ident("5V"),
    [6],
    ident("5V"),
    [7],
    ident("5V"),
    [8],
    ident("5V"),
    [9],
    ident("3V3"),
    [10],
    ident("3V3"),
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
    ident("24V"),
    [2],
    [Supply],
    [24~V sensor power, up to 0.3~A in total (INT-2).],
    ident("5V"),
    [4],
    [Supply],
    [5~V power, up to 4.5~A in total (INT-2).],
    ident("3V3"),
    [2],
    [Supply],
    [3.3~V power, up to 0.6~A in total (INT-2).],
    ident("GND"),
    [8],
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

The pinout places a ground contact opposite every clock line and groups the power contacts at one end, away from the signals. A ground pair separates the 24~V contacts at the end of the connector from the 5~V contacts, so that the 24~V rail lies furthest from every logic line.

#requirement(
  "INT-1",
  [Every contact of #ident("ASRP-PCB-INTERCONNECT-2") shall pass straight through each board, so that boards stack in any order. Each peripheral shall respond to exactly one chip select, and no two peripherals shall share a chip select.],
  note: [A peripheral is addressed only by its chip select, so its position in the stack has no meaning. Each board selects its own chip select, for example with a jumper.],
)

#requirement(
  "INT-2",
  [#ident("ASRP-PCB-INTERCONNECT-2") shall be capable of supplying 24~V at up to 0.3~A, 5~V at up to 4.5~A and 3.3~V at up to 0.6~A, each within ±5~% at the contacts of every board.],
  note: [The currents are sized for the largest intended stack: four ADC boards on SPI0 with a transmitter on every channel, and four #ident("E004-TC-BOARD") on SPI1. Each ADC board draws up to 0.09~A at 3.3~V, and up to 0.06~A at 24~V for its two transmitters at their 30~mA limit. At 5~V it draws up to 0.15~A with both channels on load cells or voltage transmitters, the heaviest configurations. This is a datasheet maximum at the converter's full clock rate, and overstates the draw at the 8.192~MHz clock in use. Each #ident("E004-TC-BOARD") draws up to 0.04~A from each of 5~V and 3.3~V. The full stack therefore draws 0.76~A at 5~V, 0.52~A at 3.3~V and 0.24~A at 24~V. The requirement of 4.5~A at 5~V dates from an earlier four-channel board that generated its own 24~V, and is retained as margin. The #ident("E001-POWER-BOARD") supplies 2~A at 5~V for the whole ECU stack, which covers this load, but it must also provide the 24~V (OI-1).],
)

#requirement(
  "INT-3",
  [Each contact shall be rated for at least 2~A, and each power rail and its return shall be carried on at least two contacts.],
  note: [Carrying each rail on several contacts makes the power path redundant, so that a single open contact cannot cut power to the stack. The pinout carries 24~V on two contacts, 5~V on four, 3.3~V on two and the return on eight. With any one contact open, the remaining contacts of each rail still carry its full current (INT-2) within their rating; the three remaining 5~V contacts, for example, carry 1.5~A each.],
)

#requirement(
  "INT-4",
  [Signals shall be 3.3~V LVCMOS referenced to #ident("GND") and series-terminated at their driver. Each chip select shall idle high when no board drives it. A peripheral shall drive the MISO line of its lane only while its own chip select is low, and an unpowered board shall leave every line at high impedance.],
  note: [A chip select that idles high keeps every peripheral deselected while the master is unpowered or in reset. A peripheral whose chip select enables its MISO driver directly, rather than through its logic, cannot hold the shared line if that logic fails.],
)

#requirement(
  "INT-5",
  [#ident("SYNC_CLK") shall run at 8.192~MHz ±50~ppm or better and shall have exactly one driver in the stack. Every peripheral that samples shall clock its converters from #ident("SYNC_CLK") and from no other source.],
  note: [A single source places every converter in the stack on one time base. The frequency suits both converters in the ECU stack: the #ident("ADS127L14") of the ADC boards derives 8~kSPS from it, and the #ident("ADS131M06") of the #ident("E004-TC-BOARD") 4~kSPS. The single source makes the clock a single point of failure for sampling, in the same way that the master is for the data.],
)

#requirement(
  "INT-6",
  [#ident("SYNC_START") shall idle high and shall have exactly one driver in the stack. A start or resynchronization shall be a low pulse lasting at least one and fewer than 2048 cycles of #ident("SYNC_CLK"). Both edges of the pulse shall fall at least 30~ns from any rising edge of #ident("SYNC_CLK") at every board. Each peripheral shall sample #ident("SYNC_START") on the rising edges of #ident("SYNC_CLK") and start all of its converters on the same edge.],
  note: [Every converter in the stack then starts on the same edge of #ident("SYNC_CLK"), so all converters sample at the same instant to within the skew of the clock across the stack, a few tens of nanoseconds or 0.01° of phase at 2~kHz. The 30~ns margin gives every board a clean sample of the pulse within the 122~ns period of #ident("SYNC_CLK"). The 2048-cycle limit protects converters such as the #ident("ADS131M06"), which reset rather than resynchronize when their SYNC/RESET input is held low for longer.],
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
  note: [The SAM V71 streams words back to back under DMA, so a read runs at the full 18.75~MHz of INT-7; the 20~% margin to 15~Mbit/s covers the chip-select set-up, the command that opens each read and the DMA set-up between reads. The peripherals on a lane share its 15~Mbit/s, so one, two, three or four ADC boards on SPI0 may each average up to 15, 7.5, 5.0 or 3.75~Mbit/s. An ADC board sends all eight readings of every sample, 192~bits, plus about 0.1~Mbit/s of packet overhead (GW-5). From the 8.192~MHz of #ident("SYNC_CLK") the wideband filter offers 8, 16, 32, 64 or 128~kSPS, which require 1.6, 3.2, 6.2, 12.4 and 24.7~Mbit/s. The lane would therefore allow one board to sample at up to 64~kSPS, two at up to 32~kSPS each, and three or four at up to 16~kSPS. The board itself fixes the rate at the 8~kSPS of GW-5; its 20~ms buffer (INT-10) would allow 16~kSPS but not 32~kSPS (@sec-fpga).],
)

#requirement(
  "INT-10",
  [Each peripheral shall buffer at least 20~ms of the data it produces, and shall report in every read how much data it still holds.],
  note: [The master can then read the peripherals one at a time, in any order and in bursts, and can pause for up to 20~ms without losing data, for example while it writes its log. The interconnect has no interrupt or data-ready lines. The master instead learns from each read how much data remains, and schedules its next read from that.],
)

The sensors connect through a Harwin Datamate #ident("M80-5001242") (@tab-sensor-pinout). It carries four contacts for each channel, two for the cable shields and two spares. Each pair of contacts occupies one column of the connector, so the two wires of a twisted pair land side by side.

#figure(
  caption: [Sensor Connector #ident("M80-5001242") Pinout],
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
    ident("GP_SHLD"),
    [10],
    ident("GP_SHLD"),
    [11],
    [—],
    [12],
    [—],
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

The function of each contact depends on the configuration that the FPGA sets (@tab-sensor-config). In both transmitter configurations, S4 ties #ident("EXC−") to the channel common, where it serves as the transmitter's supply return. The loop current of a #box[4–20~mA] transmitter must return there too, so its cable links #ident("SIG−") to #ident("EXC−"); a voltage transmitter with an isolated output needs the same link to reference its output (CBL-1).

#ident("GP_SHLD") terminates the cable shields. If the shields are to be grounded at the board, a solder jumper connects #ident("GP_SHLD") to the channel common, which is the stack's ground (@sec-gp-supply); if they are grounded at the vehicle, the jumper is left open.

Two requirements apply outside the board, one to the sensor cables and one to the sensors.

#requirement(
  "CBL-1",
  [The cable of a #box[4–20~mA] transmitter, or of a voltage transmitter with an isolated output, shall link #ident("SIG−") to #ident("EXC−") at the sensor connector. No other cable shall link them.],
  note: [The link returns the loop current, or references an isolated output, to the channel common through S4, which saves a further switch on the board. A three-wire voltage transmitter already joins its supply and signal returns internally, and a second join in the cable would divert part of its supply current into #ident("SIG−") and so into the reading. On a bridge sensor the link would short half of the bridge, which the excitation monitor detects at 1~mA as a gross fault (@sec-gp-monitor).],
)

#requirement(
  "SEN-1",
  [A sensor connected to a general-purpose channel shall have its circuit insulated from its case and from the vehicle structure.],
  note: [Because the channels are referenced to the stack's ground, a sensor whose circuit is bonded to the vehicle would connect the vehicle structure to that ground through its cable. Any voltage between the vehicle and the stack's ground would then appear across the sensor's contacts and drive current into its channel's clamps (OI-3). Flight pressure transducers and load cells normally insulate their circuits from their cases; a sensor that does not must be connected through its own isolator.],
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
  [The FPGA shall set each channel's switches through six GPIO pins of its #ident("ADS127L14"), in a single register write and only in the combinations of @tab-gp-code, and shall read the pins back before using the channel's data. It shall always pass through off when changing a channel's configuration. It shall raise a channel's current above 1~mA only after the excitation monitor has measured the sensor at 1~mA with the channel off. It shall set a load-cell configuration only after confirming, with the channel off, that #ident("EXC−") is held to the bus and not to the channel common.],
  note: [No hardware prevents a mixture of configurations, so the gateware must (@sec-gp-switches). Passing through off lets the switches of one configuration open before those of the next close. The read-back detects a stuck line or a corrupted write at the next read, after the switches have acted on it (@sec-gp-control). The check at 1~mA identifies the sensor before it receives a current that could damage it: the 30~mA branch would destroy a piezoresistive transducer rated for 3~mA. The check before a load-cell configuration guards against a shorted S4, which would hold #ident("EXC−") at the channel common and short the bus once S3 closed.],
)

#requirement(
  "GW-3",
  [The FPGA shall check the status and CRC of every packet and the switch read-back of every channel. It shall turn a channel off within one sample when the channel's converter reports a reset or an error, when its switch lines read back wrong, or when its excitation monitor leaves the limits set for its configuration. It shall report each such event in its status (GW-6).],
  note: [Checking at the converter's 8~kSPS lets the FPGA catch an open or shorted sensor, a collapsed bus or a current above a sensor's rating within one sample, rather than at the rate at which the ECU MCU board reads the board.],
)

#requirement(
  "GW-4",
  [The FPGA shall apply to every channel the gain and offset correction stored in it by the ECU MCU board.],
  note: [The corrections come from calibration at test (FW-2).],
)

#requirement(
  "GW-5",
  [The FPGA shall pass on all four readings of every channel at 8~kSPS.],
  note: [A channel that is off keeps its place in the frame, with its status marked off, so the ECU MCU board parses every frame the same way. A board produces about 1.6~Mbit/s in 1~ms packets, within its smallest share of SPI0 (INT-9).],
)

#requirement(
  "GW-6",
  [The FPGA shall number its samples from the last start, and shall return its data in packets that carry the number of the first sample in the packet, the board's status and a CRC.],
  note: [By matching sample numbers, the ECU MCU board aligns the samples that every board took at one instant, regardless of the order and timing of its reads. A gap in the numbers, or a number that stops advancing, indicates a lost packet or a stopped board (FW-1).],
)

#requirement(
  "GW-7",
  [The FPGA's registers shall be the only means of configuring the board, and shall hold each channel's configuration, converter settings, calibration and protective limits. Every register write shall carry a CRC, and the FPGA shall act on a write only if its CRC is correct.],
  note: [Because only the FPGA drives the converters and the channel switches, a fault on the bus can reach a channel only as a write that the FPGA has already checked.],
)

#requirement(
  "GW-8",
  [The board shall configure its FPGA from non-volatile memory on the board within 100~ms of power-up, without the ECU MCU board. It shall accept a new configuration over its SPI lane while the FPGA runs, shall keep a golden configuration that can be overwritten only by a two-step process, in which one command unlocks it and a second writes it, and shall fall back to the golden configuration if a new one fails to load.],
  note: [Every channel starts off and stays off until the ECU MCU board configures it, and a channel keeps its configuration if the ECU MCU board restarts. The #ident("LCMXO2-4000HC") programs its internal flash in the background through a hardened configuration port, which every image keeps enabled, and falls back to a golden image held in an SPI flash beside it. An interrupted or faulty update therefore leaves a board that still boots and accepts another update (FW-4). Because the golden image can be overwritten only by two separate commands, no single write, faulty or not, can replace it.],
)

#requirement(
  "GW-9",
  [The board shall reconfigure its FPGA from non-volatile memory on a command from the ECU MCU board, without relying on the configuration that the FPGA is running.],
  note: [The command is the REFRESH command of the FPGA's configuration logic, sent to the slave SPI port (GW-8). The configuration logic is hardened, and the setting that keeps the port enabled is held in the feature row in flash, so neither a hung design nor an upset can block the command or disable the port. The ECU MCU board can therefore recover a hung FPGA without power-cycling the stack or disturbing the other boards. It must leave the board deselected for the 2.4~ms that the reload takes, because an access to the port during that time aborts the reload (@sec-fpga).],
)

#requirement(
  "GW-10",
  [The FPGA shall count #ident("SYNC_CLK") against its internal oscillator, and shall report in its status a clock that stops or leaves 8.192~MHz by more than 10~%, within 1~ms.],
  note: [Sampling runs from #ident("SYNC_CLK"), so without this check a lost clock would show only as sample numbers that stop advancing (FW-1). Because the internal oscillator keeps the check and the SPI interface running, the board can still report why it has stopped. The oscillator is accurate only to ±5.5~%, which sets the 10~% threshold.],
)

#requirement(
  "GW-11",
  [The FPGA shall run its soft-error detection continuously and shall report a detected upset of its configuration in its status.],
  note: [An upset can change any part of the gateware, including the interlocks of GW-2 and GW-3. When the FPGA reports an upset, the ECU MCU board reloads it by command (GW-9).],
)

#requirement(
  "GW-12",
  [The FPGA shall report in its status the fault flag of the channels' supply limit.],
  note: [A tripped channel supply turns both channels off, and the flag tells the ECU MCU board why: overcurrent, an overvoltage at the limit's input, or overtemperature. The 3.3~V input limit has no flag at the FPGA, because the FPGA itself loses power when that limit trips.],
)

#requirement(
  "GW-13",
  [Every frame that the ECU MCU board sends to the FPGA's user SPI shall begin with a byte that the FPGA's configuration logic does not accept as a command.],
  note: [The board has a single chip select, which selects both the user SPI and the configuration port (@sec-fpga). The configuration logic interprets the first byte of every frame as a command, so a frame that began with REFRESH (0x79) would reload the FPGA. Lattice lists the commands in FPGA-TN-02163 (OI-9).],
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
  note: [Offset drift dominates the error of a load-cell channel (@tab-gp-budget), and a tare before each test removes the drift accumulated since calibration.],
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
    [Two general-purpose, on the stack's ground],
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
    [After calibration, per 10~°C and summed as root sum square: 0.16~% of full scale for a load cell, 0.021~% for a piezoresistive transducer, 0.009~% for #box[4–20~mA] and 0.012~% for 0–10~V],
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
    [Up to four ADC boards on SPI0 at up to 20~MHz, each producing about 1.6~Mbit/s of the lane's 15~Mbit/s],
    [@sec-stacking],
    [Sensor supply],
    [The stack's 24~V through a 0.2~A resettable fuse, and a current source in each channel that excites a bridge or limits a transmitter to 30~mA],
    [INT-2, #ident("LT3092")],
    [Input protection],
    [A 28~V fault on any contact, current-limited where a configuration closes a low-impedance path (OI-5), ±8~kV contact discharge and ±1~kV fast transients],
    [REQ-14, REQ-15, @sec-protection],
    [Input power],
    [About 0.9~W per board with both channels on, plus up to 0.3~W per load-cell channel and 0.8~W per transmitter channel, the sensors' share from 24~V],
    [Estimate],
  ),
)

= Functional Blocks

== General-Purpose Channels <sec-gp>

The two general-purpose channels are identical. In each channel, a current source excites a bridge sensor or supplies a transmitter, and a ±2.048~V excitation bus serves as the return for a bridge's excitation current and as the converter reference for a transmitter. The channel's #ident("ADS127L14") reads the sensor through a precision buffer on its first converter and monitors the excitation on the other three (@sec-gp-monitor).

The FPGA configures a channel for its sensor by closing the switches that the configuration needs, through six of the converter's GPIO pins (@sec-gp-switches), and by setting up the converter to match (@tab-adc-config). @tab-channel-config lists the four configurations. Each keeps the signal within ±2.0~V of the channel common, inside the input ranges of both the buffer and the converter.

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

@fig-gp-load-cell, @fig-gp-piezo, @fig-gp-current and @fig-gp-voltage show the channel in each configuration. Closed switches and the parts in use are drawn in black; open switches and the parts they leave idle are drawn in grey. The parts that set the accuracy are drawn as components, and the excitation bus and the sensor supply as blocks. The drawings omit the switch drive and the decoupling.

=== Signal Chain <sec-gp-chain>

Each channel has its own #ident("ADS127L14"), which contains four simultaneously sampling converters: the first reads the sensor and the other three monitor the channel (@sec-gp-monitor). Every converter in the stack runs from the 8.192~MHz #ident("SYNC_CLK") and starts on the same edge of it, so all of them sample at the same instant (REQ-6, INT-5, INT-6). The converter runs in high-speed mode with the wideband filter at an oversampling ratio of 512, which gives 8~kSPS (@tab-adc-config). The filter is flat to 3.2~kHz and attenuates by 106~dB above 4~kHz, which covers the 2~kHz bandwidth (REQ-7). The converter's noise of 2.55~µV~rms rises to 2.81~µV~rms with the buffers and protection, or 0.044~% of full scale for a 2~mV/V load cell (@sec-gp-budget).

An #ident("OPA2189") buffers the two signal inputs. Without it, the converter's input precharge buffers, which draw up to ±1.5~µA at their rated clock, would produce errors of millivolts through a 350~Ω bridge and the protection resistors; the #ident("OPA2189") draws under 300~pA. Because its input range ends 2.5~V below its positive rail, it runs from the ±5~V rails rather than from the converter's ±2.5~V.

Each signal input is protected by a 10~kΩ series resistor, in 0805 to dissipate the 78~mW of a 28~V fault, followed by 110~pF across the pair. Behind the resistor, the buffer's own input diodes clamp a fault to the ±5~V rails. They are rated for 10~mA, and a 28~V fault drives only 2.3~mA into them, or about 5.5~mA at the suppressor's 60~V first peak, so no external clamp is needed. The resistor on #ident("SIG+") is 0.05~%, 5~ppm/°C thin film, because it also forms the top of the voltage transmitter's divider.

Each converter input and reference pin is fed through 237~Ω. Because the buffers and the excitation run from the ±5~V rails, they can drive these pins before the converter's ±2.5~V rails are up, and beyond those rails in a fault; the 237~Ω holds the resulting clamp current below the converter's 10~mA rating. Together with 3.3~nF across the inputs and 330~pF from each input to AVSS, the 237~Ω resistors also form the converter's anti-alias filter, with a differential pole at 97~kHz. The common-mode capacitors are a tenth of the differential capacitor, as the converter datasheet recommends; they supply the common-mode part of each sample's charge and return it to AVSS, which powers the converter's sampling switches.

The converter's reference spans the excitation of the sensor. REFN comes from the negative side of the excitation bus, and REFP from one of three points selected by S5, S6 or S7: the top of a load cell, the top of a piezoresistive bridge's current-sense resistor, or the positive side of the bus for a transmitter. All four converters of the channel share this reference. A bridge's REFP stays below the 1.8~V input limit of the converter's REFP precharge buffer, but the bus does not, so a bridge channel turns the buffer on and a transmitter channel leaves it off (@tab-adc-config). Unbuffered, a reference pin with four converters behind it draws about 240~µA per volt at the 8.192~MHz clock, which lowers the reference by about 6~% through 237~Ω; buffered, REFP draws at most ±4~µA. Both are fixed gain errors that calibration removes (GW-4). The low buffered current allows a load cell's REFP to be fed through 10~kΩ rather than 237~Ω, so that a cell unplugged from a running current source drives no more than 2~mA into the converter's clamp.

=== Excitation and Sensor Supply <sec-gp-excitation>

Each channel's #ident("REF5020") sets its own ±2.048~V excitation bus. One half of an #ident("OPA2189") follows the reference and the other half inverts it, and each half drives one side of the bus. The reference sees only the follower's input and the inverter's 10~kΩ input resistor, a load of 0.2~mA, so a fault on the bus cannot reach it, and a failed reference affects only its own channel. The bus carries at most a load cell's 9.0~mA plus the converters' reference current, and the amplifier's ±65~mA output limit bounds the current into a short.

Each amplifier drives its side of the bus without an isolating resistor, into 1~nF on the negative side, the reference capacitors behind 237~Ω and, for a load cell, the capacitance of the excitation wire through S3. Its stability with this load remains to be confirmed (OI-8).

The sensors are powered from the stack's 24~V rail (INT-2), which enters the board through a resettable fuse and a suppressor (@sec-stacking). Each channel feeds its sensor through an #ident("LT3092"), a two-terminal current source whose current is set by a single output resistor. The #ident("LT3092") passes its 10~µA set current through 30.1~kΩ and holds the resulting 0.3~V across the output resistor. A permanent 301~Ω sets 1.0~mA, which excites a piezoresistive transducer. S1 adds 37.4~Ω in parallel for 9.0~mA, which excites a load cell, and S2 adds 10.2~Ω for 30~mA, which limits the supply of a transmitter. In every configuration, a shorted sensor or cable draws no more than this setting.

S1 and S2 are photorelays, whose on-resistance of up to 1.5~Ω adds to the branch resistance and can lower the currents to 8.7 and 26.7~mA. This affects no reading, because every bridge is read ratiometrically and S2 only sets a limit. For the same reason the output resistors need only 1~% tolerance.

=== Channel Supply <sec-gp-supply>

The channels run from the stack's 5~V rail through a #ident("TPS25200") eFuse, set to 0.65~A, which the FPGA can switch off (@sec-stacking). The eFuse output is the channels' +5~V rail, from which an #ident("LM2776") charge pump generates the −5~V rail. From these two rails, a #ident("TPS7A39") derives the converters' ±2.5~V, with both outputs rising together, and a #ident("TPS709") derives 1.8~V for the converters' I/O and for the two FPGA banks that face them.

Because the sensors are powered from 24~V, the +5~V rail carries only the channels' own circuits, at most 0.15~A, under a quarter of the eFuse limit. Of this, up to 0.09~A passes through the charge pump: mostly the converters' modulator and analog current on the −2.5~V rail, a load cell's 9.0~mA returning through the negative side of the bus, and 5~mA for each closed photorelay LED. The pump's 2.5~Ω output resistance then holds the −5~V rail near −4.8~V, or near −4.4~V with the stack's 5~V at its lower limit, which leaves ample headroom for the buffers and for the negative output of the #ident("TPS7A39"). At that lower limit, 5~% below nominal, the +5~V rail is about 4.65~V. This keeps the buffers' input range 0.15~V above the 2.0~V that the signals reach, and meets the 4.5~V minimum supply of the #ident("TMUX6212").

The converter's AVDD2 is tied to the channel common, the lowest level that the #ident("ADS127L14") allows with ±2.5~V supplies, which halves the modulators' supply power and keeps their current off the +2.5~V rail. The charge pump switches at 2~MHz, a thousand times the signal bandwidth, and the supply rejection of the #ident("TPS7A39") and of the buffers keeps its ripple out of the readings.

The +2.5~V rail needs a shunt clamp, because a buffer driven beyond its input range pushes about 8~mA through 237~Ω into the converter's input clamp, and so into the rail, while the rail's regulator can only source current. Without the clamp, that current would lift the rail toward the converter's absolute maximum of 6.5~V across its supplies. A two-wire transmitter on a channel that is off does exactly this, because #ident("SIG+") then has no return path, as do a broken #ident("EXC−") wire and a shorted loop. The clamp holds the rail below 2.7~V and sinks up to 35~mA, enough for all four signal buffers of both channels at once.

The channel common is the stack's ground, joined to #ident("GND") on the board (REQ-11). #ident("GP_SHLD") connects the cable shields to it through the shield jumper (@sec-protection, OI-3).

=== Converter Configuration <sec-gp-adc>

The FPGA configures each #ident("ADS127L14") over a dedicated SPI bus with the settings of @tab-adc-config (GW-1). Only two settings depend on the sensor: the REFP precharge buffer and the reference range.

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
      [At a given clock, mid-speed mode would double the drift of the input current (@sec-gp-budget).],
      [Digital filter],
      [Wideband, oversampling ratio 512, on all four converters],
      [8~kSPS, flat to 3.2~kHz, which covers the 2~kHz bandwidth (REQ-7).],
      [START],
      [Synchronized control mode],
      [Every converter starts on the edge to which the FPGA retimes #ident("SYNC_START") (INT-6).],
      [Data port],
      [Frame-sync, one data lane, DCLK at #ident("SYNC_CLK"), 8.192~MHz],
      [Each converter sends its four packets to the FPGA on a line of its own (@sec-gp-control). At the full clock they occupy 160 of the 1024 bit periods of each sample.],
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
      [Six pins as outputs, GPIO0 to GPIO5, driving the channel's switches],
      [GPIO2 and GPIO3 share their pins with the unused data lanes DOUT2 and DOUT3. The FPGA reads the pins back through the GPIO read register (GW-2, @sec-gp-switches).],
    ),
  ) <tab-adc-config>
]

=== Bridge Sensors

A bridge sensor is excited by its channel's current source. The current enters the bridge at #ident("EXC+"), leaves at #ident("EXC−") and returns into the negative side of the excitation bus. Returning it to −2.048~V rather than to the channel common centres the bridge on the channel common, which places its outputs within the input ranges of the buffers and the converter and its top within the converter's reference range. Where the converter takes its reference depends on how the sensor is specified.

#figure(
  caption: [General-Purpose Channel, Load Cell],
  gp-channel("load-cell"),
) <fig-gp-load-cell>

A load cell is specified in millivolts per volt: its output is a fixed fraction of the voltage across it, and compensation resistors inside the cell, in series with the excitation, hold that fraction constant over temperature. The converter's reference is therefore taken across the bridge, with REFP from #ident("EXC+") through 10~kΩ and REFN from the bus, to which S3 returns #ident("EXC−") through under 0.1~Ω, and the converter reads the cell's ratio directly (REQ-9). Because the ratio is a property of the bridge network, it is the same whether a voltage or a current sets the voltage across the bridge; the value and drift of the excitation current cancel, and the cell's compensation works as designed. The 9.0~mA excitation keeps REFP within the precharge buffer's limit for cells of up to 410~Ω, where it reaches 1.66~V. A 350~Ω cell has 3.2~V across it and gives ±6.3~mV at 2~mV/V.

#figure(
  caption: [General-Purpose Channel, Piezoresistive Transducer],
  gp-channel("piezo"),
) <fig-gp-piezo>

A piezoresistive transducer such as the Keller 7L is characterised and compensated for a constant current of 1~mA. Its bridge resistance rises by 1800 to 3000~ppm/°C, and under constant current that rise lifts the bridge voltage and cancels most of the fall in its sensitivity; at a fixed voltage the span would instead drift by −0.12 to −0.36~% per °C. The excitation therefore returns through a 1.00~kΩ current-sense resistor (0.1~%, 15~ppm/°C typical), and the converter takes its reference across that resistor, with REFP from its top. The converter then reads the output as a fraction of the current, so the tolerance and drift of the current cancel. At 100~bar a 7L typically gives 160~mV against the 1.0~V reference, so the channel noise of 2.81~µV~rms corresponds to about 1.8~mbar. Keller's zero-compensation resistors, and the join of the transducer's two lower bridge pins, belong at the sensor end.

The current-sense resistor is fitted in every configuration. A load cell bypasses it through S3. In a transmitter channel #ident("EXC−") is held at the channel common, so the resistor passes 2~mA from the bus. With no sensor connected, it holds #ident("EXC−") at the bus.

Shunt calibration connects a resistor chosen for the sensor across the #ident("SIG+") to #ident("EXC−") arm of the bridge through S10 (REQ-10). The resulting step in the reading checks the gain of the whole channel, so it also serves as a built-in test. The FPGA closes S10 through the channel's #ident("CAL_EN") line when the ECU MCU board commands it (@tab-gp-code).

=== #box[4–20~mA] Transmitter

#figure(
  caption: [General-Purpose Channel, #box[4–20~mA] Transmitter],
  gp-channel("current"),
) <fig-gp-current>

S2 sets the channel's current source to 30~mA. The source does not regulate below that limit, so the transmitter sets its own loop current while the source caps what a shorted transmitter or cable can draw. A two-wire transmitter takes its loop supply from #ident("EXC+") and returns the loop current on #ident("SIG+"). S8 connects the 100~Ω precision shunt between #ident("SIG+") and #ident("SIG−"), which converts 4–20~mA to 0.4–2.0~V. The cable links #ident("SIG−") to #ident("EXC−"), and S4 ties #ident("EXC−") to the channel common, which closes the loop on the board (CBL-1). S4 lies outside the measured span, so its on-resistance does not affect the reading. S8 lies inside it, but its 27.5~mΩ maximum adds only 0.028~% to the reading, which calibration removes, and drifts by under 1.4~ppm/°C.

=== Voltage Transmitter

#figure(
  caption: [General-Purpose Channel, Voltage Transmitter],
  gp-channel("voltage"),
) <fig-gp-voltage>

A voltage transmitter is supplied as in the #box[4–20~mA] configuration and returns its supply current on #ident("EXC−"), which S4 ties to the channel common. S9 connects a 2.49~kΩ resistor from the input of the SIG+ buffer to #ident("SIG−") at the connector, so that the 10.0~kΩ series resistor becomes the top of a 5:1 divider for 0–10~V, which loads the transmitter with 12.5~kΩ. The SIG− buffer reads #ident("SIG−") through its own 10~kΩ, so the divider measures between the two signal contacts and keeps a three-wire transmitter's supply current in #ident("EXC−") out of the reading. The bottom resistor is a 1206 part, to dissipate the 0.2~W of a 28~V fault on #ident("SIG−") while S9 is closed; the SIG+ buffer's input clamp then carries 9~mA.

A transmitter with an isolated output would float without a reference, so its cable links #ident("SIG−") to #ident("EXC−") (CBL-1). A three-wire transmitter needs no link, because its returns already meet inside it. Because the output is unipolar, a reading below zero by more than the channel's offset indicates a transmitter wired in reverse.

=== Configuration Switches <sec-gp-switches>

Ten switches configure a channel for its sensor (@tab-gp-switches). Each is the simplest part that meets the voltage, current and leakage of its position, which leads to three types. A switch whose terminals both stay within the channel's ±5~V rails is a #ident("TMUX6212") analog switch, which conducts in both directions with a flat on-resistance and nanoamperes of leakage, closes on 1.8~V logic and comes four to a package. A switch with a terminal on a sensor contact must withstand a 28~V fault; where it must also add only milliohms or clamp the contact, it is a MOSFET. Each MOSFET is oriented to block the one polarity it sees in use, and a #ident("TMUX6212") channel drives its gate from the rails. A switch that floats with the sensor supply, or that must block both polarities at a high-impedance node with nanoamperes of leakage, is a photorelay, because its LED drive is isolated from its contacts.

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
      ident("TLP3475S"),
      [Photorelay],
      x,
      o,
      o,
      o,
      [S2],
      [30~mA branch of the current source],
      ident("TLP3475S"),
      [Photorelay],
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
      ident("DMTH6016LFDFWQ"),
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
  requirements: [Both terminals float with #ident("EXC+"), from 1~V below the channel common to 24~V above it. The voltage across an open switch is at most the 0.3~V set voltage of the #ident("LT3092"). When closed, S1 carries 8~mA and S2 29~mA.],
  type: [Photorelay, because both terminals float with #ident("EXC+") and the LED needs no drive that follows them. The on-resistance of the #ident("TLP3475S"), at most 1.5~Ω, adds to the branch resistor and can lower the current by 4~% in S1 and by 13~% in S2, which affects no reading (@sec-gp-excitation). The LED runs from #ident("LC_G") or #ident("TX_G"), the ±5~V drive lines of #ident("LC_EN") and #ident("TX_EN"), to the −5~V rail through 1.57~kΩ, and draws about 5~mA when the switch is closed. The 60~V rating covers a discharge that reaches the relay from #ident("EXC+") through the branch resistor.],
)

#switch-entry(
  [S3 returns #ident("EXC−") straight to the negative side of the bus for a load cell, bypassing the current-sense resistor.],
  requirements: [S3 carries the cell's 9.0~mA when closed. It lies inside the cell's reference, which runs from #ident("EXC+") to the bus, so its on-resistance and the drift of that resistance appear in the reading. When open, it must block #ident("EXC−") held at the channel common in the transmitter configurations, 2.05~V above the bus. Its drain is on a sensor contact: S4's body diode clamps a positive fault on #ident("EXC−"), but S3 must withstand the full 28~V if that clamp fails.],
  type: [N-channel MOSFET, because a power MOSFET combines an on-resistance of a tenth of an ohm with a rating above 28~V. Its source is on the bus, so its body diode carries a negative fault on #ident("EXC−") into the bus (@sec-protection). The #ident("DMN6075S") is rated 60~V, with 85~mΩ at 10~V. Driven to 7~V above its source at −2.048~V, its 0.1~Ω adds 0.9~mV to the reference, a fixed 0.03~% with a drift of 1.4~ppm/°C.],
)

#switch-entry(
  [S4 ties #ident("EXC−") to the channel common in the transmitter configurations. It returns a transmitter's supply current, and the current of a #box[4–20~mA] loop through the cable link (CBL-1).],
  requirements: [S4 carries up to the 30~mA limit when closed. The current flows outside the measured span, so its on-resistance only lifts #ident("EXC−"). When open, S4 blocks #ident("EXC−") held on the bus, 2.05~V below the common, and #ident("EXC−") never rises above the common in use.],
  type: [N-channel MOSFET, because with its source on #ident("EXC−") it blocks the only polarity it sees in use. Its body diode also clamps a positive fault on #ident("EXC−") to about 0.7~V above the common (@sec-protection). The #ident("BSS138W") is rated 50~V and 200~mA. Its current rating also bounds the fault that its body diode survives, which makes S4 the weakest switch against a low-impedance fault (OI-5); a larger MOSFET would raise that bound at no cost to the reading.],
)

#switch-entry(
  [S5 takes REFP from #ident("EXC+") through 10~kΩ for a load cell.],
  requirements: [S5 carries only the buffered REFP current of at most ±4~µA behind 10~kΩ, so its on-resistance is immaterial. When open, it isolates the REFP node from #ident("EXC+"), which reaches 24~V on a transmitter channel or with an open sensor, while the REFP node stays within the rails.],
  type: [N-channel MOSFET, because with its source on the REFP side it blocks the only polarity it sees.],
)

#switch-entry(
  [S6 and S7 select REFP. S6 takes it from #ident("EXC−") for a piezoresistive transducer, and S7 from the positive side of the bus for a transmitter.],
  requirements: [Every terminal of S6 and S7 stays within the rails, because the body diodes of S3 and S4 hold #ident("EXC−") within 0.7~V of the bus or the common. S6 carries the buffered REFP current of ±4~µA. S7 carries the unbuffered reference current of four converters, about 1~mA, and its on-resistance lies in a transmitter's reference. When open, S6 leaks into a piezoresistive transducer's #ident("EXC−"), between the bridge and its current-sense resistor.],
  type: [Analog switch, because every terminal stays within the rails. The #ident("TMUX6212") has at most 7.6~Ω up to 85~°C at ±5~V. In S7 this lowers the reference by 0.19~%, which calibration removes, and its drift of 0.015~Ω/°C is 3.7~ppm/°C of the reference. In S6 the same resistance is a fixed 30~ppm, and the leakage of at most 2~nA is 2~ppm of a piezoresistive transducer's current.],
)

#switch-entry(
  [S8 connects the 100~Ω shunt across the signal contacts for a #box[4–20~mA] transmitter.],
  requirements: [S8 lies inside the measured span: the converter reads the shunt and S8 in series, so S8's on-resistance and its drift add to the shunt's. When closed it carries up to 30~mA, and when open it must block a 0–10~V transmitter's output in the voltage configuration. Both of its terminals are on sensor contacts and must withstand a 28~V fault.],
  type: [N-channel MOSFET, because a power MOSFET offers milliohms of on-resistance at the voltage rating that a contact needs. With its source on #ident("SIG−") it blocks the one polarity a transmitter presents. Its gate is held at #ident("EXC_N"), at least 1.6~V below #ident("SIG−"), when open, and at +5~V when closed. The #ident("DMTH6016LFDFWQ") has at most 27.5~mΩ at 4.5~V in a 2 × 2~mm package, which adds at most 0.028~% to the reading; calibration removes this. Its on-resistance rises by roughly 0.5~%/°C, so S8 drifts by under 1.4~ppm/°C and the shunt's own 5~ppm/°C remains the dominant term. Its 60~V rating matches the suppressors' clamp at the first peak of a discharge, and every part is avalanche-tested in production (@sec-protection). Its gate is rated ±20~V, so a 16~V Zener diode, as on S4, protects it against a 28~V fault on #ident("SIG−"). At the 3~V of reverse bias that the Zener sees in use, it typically leaks well under 1~nA into #ident("SIG−"), or 0.2~µV through a load cell.],
)

#switch-entry(
  [S9 connects the 2.49~kΩ divider bottom from the SIG+ buffer's input to #ident("SIG−") for a voltage transmitter.],
  requirements: [Open in the #box[4–20~mA] configuration, S9 has up to 2~V across it at the buffer's input. That node sits behind 10~kΩ, so the switch's leakage appears as an error. When closed, S9 carries at most 0.8~mA and its on-resistance adds to the divider's bottom. It must block both polarities, because #ident("SIG−") may lie above or below the buffer's input, and its #ident("SIG−") terminal is on a sensor contact and must withstand a 28~V fault.],
  type: [Photorelay, because its back-to-back MOSFETs block both polarities and its LED drive leaves the switch floating. A #ident("TMUX6212") channel drives the LED from the +5~V rail through 680~Ω to the channel common, at about 5~mA. The #ident("TLP3475S") guarantees an off-state leakage of at most 1~nA at 50~V and 25~°C, which through 10~kΩ is 10~µV, where a MOSFET's guaranteed 1~µA would give 10~mV. Its 1.5~Ω adds 0.06~% to the divider's bottom, which calibration removes, and drifts by 1.9~ppm/°C.],
)

#switch-entry(
  [S10 places the shunt-calibration resistor across a bridge's SIG+ to #ident("EXC−") arm.],
  requirements: [One terminal of S10 is on #ident("EXC−"), within the rails. The other sees #ident("SIG+") only through the calibration resistor of tens of kilohms, which limits a fault on #ident("SIG+") to a fraction of a milliampere. When closed, S10's on-resistance adds to the calibration resistor; when open, its leakage flows into the bridge output.],
  type: [Analog switch, because the calibration resistor keeps both terminals within the rails. The #ident("TMUX6212")'s 7.6~Ω is 0.01~% of the fitted 87.6~kΩ calibration resistor, which simulates about 1~mV/V on a 350~Ω cell. Its leakage of at most 2~nA gives less than 1~µV across the bridge, an offset that a tare removes.],
)

Six logic lines set a channel's switches, one for each group of switches that closes together (@tab-gp-code). #ident("LC_EN") closes the load cell's S1, S3 and S5, #ident("PRT_EN") the piezoresistive transducer's S6, and #ident("TX_EN") the transmitter's S2, S4 and S7. #ident("CAL_EN") closes S10 for shunt calibration on either bridge, and #ident("S8_EN") or #ident("S9_EN") gives a transmitter its #box[4–20~mA] shunt or its voltage divider.

#figure(
  caption: [Switch Lines by Configuration],
  datatable(
    columns: (auto, auto, 1fr),
    align: (left, left, left),
    header: ("Configuration", "Lines high", "Closed"),
    [Off],
    [None],
    [None],
    [Load cell],
    [#ident("LC_EN")],
    [S1, S3, S5],
    [Load cell, shunt calibration],
    [#ident("LC_EN"), #ident("CAL_EN")],
    [S1, S3, S5, S10],
    [Piezoresistive],
    [#ident("PRT_EN")],
    [S6],
    [Piezoresistive, shunt calibration],
    [#ident("PRT_EN"), #ident("CAL_EN")],
    [S6, S10],
    [#box[4–20~mA] transmitter],
    [#ident("TX_EN"), #ident("S8_EN")],
    [S2, S4, S7, S8],
    [Voltage transmitter],
    [#ident("TX_EN"), #ident("S9_EN")],
    [S2, S4, S7, S9],
  ),
) <tab-gp-code>

The lines are GPIO0 to GPIO5 of the channel's #ident("ADS127L14"), carrying 1.8~V logic referenced to the channel common (@sec-gp-control). A single data lane leaves the converter eight GPIO pins, so no logic is needed between the converter and the switches. The two #ident("TMUX6212") provide S6, S7 and S10, and their remaining channels translate the lines to the ±5~V drive of the MOSFET gates and the photorelay LEDs. A closed channel takes its output to +5~V, and a pull-down holds it at −5~V or at #ident("EXC_N") while the channel is open. The LEDs of S1 and S2 return to the −5~V rail and that of S9 to the channel common, so an open channel leaves them dark. The drives of S4 and S8 each pass through 10~kΩ, which limits the current that a fault clamped by their gate Zeners drives back into the #ident("TMUX6212").

No hardware prevents a mixture of configurations; the gateware ensures that only the combinations of @tab-gp-code are written (GW-2). Two mixtures would short the channel's bus. A load cell's S3 together with a transmitter's S4 would short the negative side of the bus to the channel common through a #ident("BSS138W") rated for 200~mA, and a piezoresistive bridge's S6 together with a transmitter's S7 and S4 would short the positive side through two #ident("TMUX6212") channels rated for 160~mA at 85~°C. Either short would hold the bus amplifier at its ±65~mA limit, which is within the switches' ratings, and the channel would lose its excitation until the FPGA turned it off (GW-3). #ident("LC_EN") and #ident("TX_EN") must likewise never be set together, because that would close both current branches.

When all six lines are low, every switch is open. The converter's GPIO pins are disabled at power-up and after a reset, and the internal pull-downs of the #ident("TMUX6212"), about 4~MΩ, then hold each line low. These pull-downs are limited to about 1~µA, far more than the nanoamperes that the converter's disabled pins leak in practice, although the converter's datasheet allows up to 5~µA. With every switch open, the channel delivers 1~mA through the permanent output resistor, a current that is safe for any sensor and too small to start a transmitter.

One register write sets all six lines together, so a channel never passes through a mixture on its way to the next configuration. The FPGA nevertheless moves a channel through off between configurations (GW-2), because the switches do not all change at the same speed: going directly from a load cell to a transmitter, S4 could close before S3 had opened and short the bus momentarily.

No setting of the lines can prevent a configuration that is wrong for the connected sensor; the 30~mA branch, for example, would destroy a 7L rated for 3~mA. The FPGA therefore raises the current only after the excitation monitor has measured the sensor at 1~mA with the channel off (GW-2, @sec-gp-monitor).

Once placed, the switches and their drive occupy about 2.2~cm² per channel: two #ident("TMUX6212"), four MOSFETs, three photorelays, two Zener diodes and their resistors (@sec-physical).

=== Control <sec-gp-control>

The FPGA drives each converter directly, on dedicated lines (@sec-fpga). The converter's I/O operates only at 1.8~V, so each converter connects to its own FPGA bank at 1.8~V, bank 1 for the first channel and bank 4 for the second, both powered from the channels' 1.8~V rail. Nine lines connect the FPGA to each converter (@tab-gp-barrier), and a 62~Ω resistor at the FPGA series-terminates each of the five fast outputs.

#[
  #set par(justify: false)
  #figure(
    caption: [Converter Lines],
    datatable(
      columns: (auto, auto, auto, 1fr),
      align: (left, left, left, left),
      header: ("Signal", "Direction", "Rate", "Use"),
      [CLK],
      [Out],
      [8.192~MHz],
      [#ident("SYNC_CLK"), forwarded by the FPGA as the converters' clock],
      [START],
      [Out],
      [Per start],
      [#ident("SYNC_START"), retimed by the FPGA to an edge of #ident("SYNC_CLK")],
      [SCLK],
      [Out],
      [4~MHz],
      [SPI clock],
      [SDI],
      [Out],
      [4~MHz],
      [Writes to the converter's registers and to its GPIO pins, which drive the switches],
      [CS],
      [Out],
      [Per transfer],
      [Frames each transfer],
      [SDO],
      [In],
      [4~MHz],
      [Read-back of the converter's registers and switch lines],
      [DOUT],
      [In],
      [8.192~Mbit/s],
      [Frame-sync data: four packets per sample],
      [FSYNC],
      [In],
      [8~kHz],
      [Marks the first packet of each sample],
      [RESET],
      [Out],
      [On command],
      [Resets the converter. While the FPGA configures, its I/O pull-down holds the converter in reset, and the channels' supply is off],
    ),
  ) <tab-gp-barrier>
]

Because the FPGA banks and the converters' I/O share one supply, they power down together when the FPGA switches the channel supply off, so neither drives the other while unpowered. The FPGA drives both converters' CLK and START from one internal clock and one retimed start (INT-6), so the two converters of a board sample together to within the skew between the FPGA's outputs, about a nanosecond. Between boards, the FPGAs' clock-to-output delays differ by a few nanoseconds, which sets how closely the boards sample together. The 62~Ω resistors damp ringing on the 8.192~MHz clock and limit the current into a converter's inputs while its supply rises.

Each converter has its own SPI bus at 4~MHz. A transfer is one 24-bit word with CRC and takes 6~µs; between transfers the converter releases SDO, and a pull-down in the FPGA's input holds the line. The converter sends the four packets of every sample on its own DOUT line, framed by its own FSYNC, at the full 8.192~MHz of #ident("SYNC_CLK"), so they occupy 160 of the 1024 bit periods in each 125~µs sample period. One line could therefore carry the four 40-bit packets at up to 51.2~kSPS, well above the 8~kSPS of GW-5. The FPGA samples DOUT with its own copy of the clock, so DCLK is not routed; the converter's output delay is a small part of each 122~ns bit. The daisy-chain input DIN0 is tied low.

The FPGA writes a channel's six switch lines into the converter's GPIO output register in a single write, and reads the pins back through the GPIO read register before it uses the channel's data (GW-2). Because the read-back reflects the pins as they drive the switches, a stuck line or a corrupted write appears at the next read. The converter disables its GPIO pins at power-up and after a reset, so a channel always starts off.

A converter that fails outright, or that holds one of its lines, affects only its own channel: the FPGA sees its packets missing or its switch lines reading back wrong and turns that channel off (GW-3), while the other channel continues. The FPGA can then reset that converter alone through its RESET line, without switching off the shared channel supply. A converter that resets spontaneously turns its channel off and reports the reset in the status header of its next packet, and the FPGA then reconfigures it (GW-3).



== General-Purpose Error Budget <sec-gp-budget>

The budget covers the path from the sensor contacts to the converter output at 8~kSPS for each configuration of @tab-channel-config; the sensor and its cable are excluded. Full scale is 6.33~mV for a 2~mV/V load cell on a 350~Ω bridge excited at 9.0~mA, 160~mV for a 100~bar Keller 7L at 1~mA, 20~mA for a #box[4–20~mA] transmitter and 10~V for a voltage transmitter. Each term is a datasheet maximum, except where marked typical because the datasheet gives no maximum.

Calibration at test (FW-2, GW-4) and shunt calibration (REQ-10) remove the offset and gain error present at the calibration temperature, which leaves noise, nonlinearity and drift (@tab-gp-budget). The board's temperature range is not yet set, so drift is stated per 10~°C of departure from the calibration temperature.

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
    [Current-sense resistor, 15~ppm/°C typical],
    [—],
    [0.015],
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
    [0.021],
    [0.009],
    [0.012],
    [Drift, worst-case sum],
    [0.27],
    [0.039],
    [0.021],
    [0.026],
  ),
) <tab-gp-budget>

The buffers and protection add 20~nV/√Hz to the converter's noise, mostly the thermal noise of the two 10~kΩ resistors. Over the wideband filter's noise bandwidth of about 3.5~kHz this amounts to 1.19~µV~rms, which raises the channel noise from 2.55 to 2.81~µV~rms.

Offset drift dominates the error for a load cell. Gain calibration cannot remove it, but a tare before each test does (FW-3). Two terms account for most of it. The first is the converter's input current through the 237~Ω pair. The datasheet gives this current and its drift only as typical values, ±1.5~µA and 5~nA/°C at the 25.6~MHz clock of high-speed mode, which the budget scales to 8.192~MHz; mid-speed mode specifies the same figures at 12.8~MHz, which would double the term (@tab-adc-config). The second term is the buffers' bias current through the 10~kΩ protection resistors. For it the budget takes the change allowed between the 0.3~nA maximum at 25~°C and the 1.5~nA maximum at 85~°C, spread over that span; the typical bias current is 70~pA at 25~°C. For a piezoresistive transducer, whose signal is more than twenty times larger, the same terms amount to about 0.01~%.

A bridge's reference is taken at the connector, so for a load cell the excitation wires lie inside it. A resistance of 1~Ω in each wire lowers a 350~Ω cell's reading by 0.57~%, and copper's coefficient of 0.39~%/°C turns that into 0.02~% per 10~°C. Shunt calibration removes both at the time it is applied. A piezoresistive transducer is referenced to the current through it, which its wires cannot change, so its reading does not depend on them.

The excitation monitor adds no term (@sec-gp-monitor): the current its dividers draw from #ident("EXC+") leaves before the sensor, and at a piezoresistive channel's #ident("EXC−") its buffer's bias current changes the current-sense resistor's share of the current by under 0.04~ppm/°C.

The configuration switches add at most 0.006~% per 10~°C (@sec-gp-switches). On-resistance drift dominates: S3's 1.4~ppm/°C in a load cell's reference, S9's 1.9~ppm/°C in the divider's bottom and S7's 3.7~ppm/°C in a transmitter's reference, which carries the reference current of four converters. The remainder is leakage from S8's gate clamp into #ident("SIG−") and from the open MOSFETs at #ident("EXC−"), at most a few nanoamperes when hot. These leakage figures are typical, because the datasheets guarantee a MOSFET's leakage only at its full rated voltage, where it can reach 1~µA.

A bridge's REFP precharge buffer serves all four converters. It draws up to ±4~µA, and its drift of about 13~nA/°C at this clock sets the reference term for bridge sensors: through a load cell's 10~kΩ it is 40~ppm/°C of the 3.2~V reference, and from a piezoresistive transducer's current-sense resistor 13~ppm/°C of the 1~mA.

Transmitters are measured against the excitation bus rather than ratiometrically, so their drift is that of the shunt or divider and of the excitation. The shunt, the divider and the inverter pair are 5~ppm/°C thin film, so no term exceeds 0.008~% per 10~°C. The #ident("REF5020") adds up to 70~ppm of thermal hysteresis after a temperature cycle and 22~ppm over its first 1000~hours, both of which recalibration removes; because each channel has its own reference, the two channels drift independently. At 20~mA the shunt dissipates 40~mW, and each 10~°C that it rises above the board adds 0.005~% at 20~mA, and less at lower currents. This self-heating bends the transfer curve in a way that a gain and offset correction cannot remove.

Before calibration, the load-cell offset can reach 0.43~mV, or 7~% of full scale: the converter's ±200~µV plus its input current through the 237~Ω pair, typically ±230~µV. The bridge gains are about 7~% high by design, because the four converters' reference currents flow through the resistors in the reference path, and the converter adds up to ±0.25~% of gain error.

== Excitation Monitor <sec-gp-monitor>

A channel's signal converter reads its sensor against a reference derived from the excitation, so the excitation drops out of the result. This makes the channel ratiometric, but it also hides the excitation from the signal converter. The other three converters of the channel's #ident("ADS127L14") therefore measure the excitation directly, at the same instant and rate as the signal and against the same reference (@tab-gp-monitor, @fig-gp-monitor). Each reads one node against the channel common: the excitation input reads #ident("EXC+") divided by 25, the return input #ident("EXC−") divided by 2, and the bus input the positive side of the bus divided by 4.

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

The monitor readings serve four purposes.

The first is to measure the temperature of a piezoresistive transducer. The transducer's reference is the voltage across the current-sense resistor, so the excitation reading minus the return reading, each scaled by its divider, is directly the ratio of the bridge resistance to the 1.00~kΩ current-sense resistor. The bridge resistance rises with temperature by 1800 to 3000~ppm/°C, so the ratio indicates the transducer's temperature. Keller specifies the 7L's span to within 0.06~%/°C and its compensated zero to within 0.025~% of full scale per °C. Given the transducer's characterisation, the measured temperature lets the ECU MCU board correct the residual error. A temperature known to within a third of a degree holds the correction's own error near 0.02~% of full scale, which requires the ratio to remain stable within about 600~ppm for each 10~°C of board temperature.

The second is to measure the supply of a transmitter. The bus reading, fixed at 2.048~V, converts the excitation reading into volts, which reveals a supply sagging under load or a loop held at its 30~mA limit.

The third is to detect faults in every configuration. An open or unplugged bridge lets its current source drive #ident("EXC+") up to the sensor supply, and a shorted bridge or cable collapses the bridge voltage. A damaged cable appears as a change of a few per cent in the bridge voltage, which the bus reading expresses in volts. Detecting these faults needs an accuracy of only about 1~%.

The fourth is to drive the interlocks. The FPGA compares every reading with limits set for the channel's configuration and turns the channel off within one sample when a reading crosses its limit (GW-3).

The three monitor inputs sample together with the signal, from the same clock and against the same reference. The ratio of any two readings is therefore independent of the reference, and every reading aligns with the signal sample taken at the same instant. The FPGA passes the readings to the ECU MCU board at the full 8~kSPS (GW-5), each with the converter's 2.55~µV~rms of noise.

Dividers to the channel common bring every node within the converter's input range in every configuration. The narrowest case is the ±1.0~V allowed under a piezoresistive transducer's 1.0~V reference, where the excitation input sees 0.96~V when an open sensor lets its current source rise to the 24~V supply.

The converter's inputs draw up to about 0.5~µA at this clock and drift by 1.6~nA/°C. Through the 9.6~kΩ of the ÷25 divider this would produce 5~mV and 15~µV/°C, too much for the 600~ppm budget, so one half of a second #ident("OPA2189") buffers the divided excitation input. The return and bus dividers present under 1~kΩ to the converter, so its input current moves their readings by under 0.1~%. The bus divider loads the bus amplifier with 0.5~mA.

A piezoresistive transducer's #ident("EXC−") lies between its bridge and its current-sense resistor. Current drawn at that node would pass through one and not the other, causing a gain error in the channel's own reading. The other half of the second #ident("OPA2189") therefore buffers #ident("EXC−") before its divider, through 10~kΩ that limits a fault's current into the amplifier's input. The amplifier's input bias current, at most 1.5~nA up to 85~°C, is 1.5~ppm of the excitation current, and through the 10~kΩ it adds at most 15~µV, or 15~ppm of the current-sense voltage. An unused #ident("EXC−"), as on a channel with nothing connected, is held to the negative side of the bus by the current-sense resistor.

The converter's own errors are small compared with its readings: offset drift of 35~nV/°C, nonlinearity of 2.8~ppm of its range and gain drift of 1~ppm/°C, all maximum, and the gain drift cancels in a ratio. Calibration at test removes its offset, so no zeroing is needed in use, and the dividers set the stability. Because any channel may carry a piezoresistive transducer, every divider is 0.1~%, 5~ppm/°C thin film. Opposing drift in the excitation and return dividers moves the resistance ratio by at most about 100~ppm per 10~°C, and the drift of the reference current through the 237~Ω at the reference pins adds about 60~ppm. Together they remain within the 600~ppm.

== Input Protection <sec-protection>

Every sensor contact leaves the board through the vehicle harness, where it can meet a fault from another circuit, an electrostatic discharge during handling, and transients coupled from the igniter and the valves. The board must survive all three. REQ-14 sets the discharge and transient levels, and REQ-15 sets the fault at 28~V, the highest voltage in the harness.

Each of the eight sensor contacts has a bidirectional suppressor to the channel common at the connector pin, a Littelfuse #ident("SD36C-01FTG") in SOD-323. Its stand-off voltage of 36~V lies above 28~V, so neither the 24~V sensor supply nor a 28~V fault makes it conduct, and the parts behind it must withstand the fault. The suppressor must be bidirectional because #ident("EXC−") and the signal contacts sit up to 2~V below the channel common in use, where a unidirectional part would conduct. It is an avalanche part rated for ±30~kV contact discharge and 40~A fast transients. It breaks down at 40~V and clamps through about 0.68~Ω beyond that: at about 51~V for the 16~A that an 8~kV contact discharge delivers 30~ns into its pulse, and at about 60~V for the 30~A of the first peak, which lasts about a nanosecond.

The parts on the contacts are rated to match. S8 is rated 60~V and avalanche-tested in production. S3 and the photorelays are rated 60~V, S9 behind 2.49~kΩ and S1 and S2 behind the branch resistors, and S5 sits behind 10~kΩ. S4 is rated only 50~V, but its own body diode and that of S3 clamp #ident("EXC−") well below that, as follows.

On #ident("EXC−") the body diodes of S3 and S4 conduct before the suppressor does, S4's to the channel common and S3's to the bus. They hold #ident("EXC−") within about 0.7~V of those nodes, so the current-sense resistor and the switch terminals on #ident("EXC−"), those of S6 and S10, never see more than a few volts. The two MOSFETs then carry part of a discharge, and they are to be tested at the REQ-14 levels on the first boards. If needed, a few ohms in series with S4, which carries only a transmitter's supply return, would relieve it.

The #ident("LT3092") on #ident("EXC+") withstands only ±40~V between its input and its output, and a discharge reaches its output almost unattenuated through the current source's output resistor. A 100~nF capacitor from #ident("EXC+") to the channel common therefore absorbs the discharge's charge first. An 8~kV discharge from the standard's 150~pF carries 1.2~µC, which moves the capacitor by about 12~V, or by about 27~V where a transmitter's 24~V supply has halved its capacitance. The suppressor then does not conduct, and the current source's input-to-output voltage stays within about 35~V. A fast transient couples far less charge per pulse, but with no sensor connected a burst could pump the capacitor until the suppressor conducts, which is to be tested on the first boards. The capacitor sits ahead of the bridge and the current-sense resistor, so its leakage changes no reading, and it delays a bridge's excitation by at most 0.35~ms at turn-on.

A suppressor returns a discharge to the channel common, which is the stack's ground, and the discharge leaves through the stack's own connection to the vehicle (OI-3). The board's ground must carry it past the FPGA and the interconnect without disturbing them (@sec-physical). A sustained fault from a contact to the vehicle likewise drives current through the channel's clamps into the stack's ground; the clamps and series resistors limit that current on most paths (@tab-protection).

At the few volts that a measured contact sees in use, a suppressor leaks far less than its rating at stand-off. The #ident("SD36C-01FTG") is rated 1~µA at 36~V and is expected to leak under 10~nA at 2.5~V. On #ident("EXC+") the leakage leaves before both the bridge and the current-sense resistor, so no reading changes. On #ident("EXC−") it is a ratio error in a piezoresistive channel, 1~ppm per nanoampere. On #ident("SIG+") and #ident("SIG−") the two suppressors sit at nearly the same voltage, so their leakage largely cancels; the difference flows through the bridge's output resistance and gives 0.18~µV, or 0.003~% of full scale, per nanoampere for a 350~Ω load cell. The chosen part must hold that difference near a nanoampere, which is to be measured on the first boards.

REQ-14 does not include surge immunity to IEC~61000-4-5, because the harness is assumed to be shorter than 30~m, with no connection to mains or to lines exposed to lightning. A surge rating would call for suppressors several times the size.

#figure(
  caption: [Behaviour under a 28~V Fault],
  datatable(
    columns: (auto, auto, 1fr),
    align: (left, left, left),
    header: ("Contact", "In use", "A 28 V fault"),
    ident("EXC+"),
    [−1 to 24~V],
    [Lifts the output of the #ident("LT3092") above its input, which it blocks; under 1~mA flows back. S5 sits behind 10~kΩ and the monitor behind 240~kΩ.],
    ident("EXC−"),
    [−2.05 to 0~V],
    [Flows into the bus through S3 where it is closed, and otherwise to the channel common through S4's body diode, 0.7~V above it. The current-sense resistor then carries at most 2.8~mA.],
    [#ident("SIG+"), #ident("SIG−")],
    [±2~V; #ident("SIG+") to 10~V for a voltage transmitter],
    [Reaches the buffers through 10~kΩ and drives 2.3~mA into their input clamps. S8 and S9, both rated 60~V, block it while open; where the configuration closes them, it flows through the shunt or the divider to the channel common.],
  ),
) <tab-protection>

Most of these paths survive a fault from any source, but three are low-impedance by design: S3 into the bus in the load-cell configuration, S4's body diode, and the shunt with S8 in the #box[4–20~mA] configuration, which returns through the cable link and S4. These three survive a current-limited fault indefinitely; another channel's sensor supply at 30~mA, for example, dissipates 21~mW in S4's diode and 90~mW in the shunt. A low-impedance source such as a valve supply would destroy S4 or the shunt, and through S3 it would hold the channel's bus at its amplifier's ±65~mA limit and remove the channel's excitation while it lasted. Such a fault damages only its own channel, or both channels of the board if it trips the channel supply, but while it lasts its current returns through the stack's ground and can disturb the other boards (OI-5).

== Data Collection <sec-fpga>

The FPGA is the board's only connection to its SPI lane (@sec-interfaces). It runs from #ident("SYNC_CLK") and from the 3.3~V input, and its two banks that face the converters run from the channels' 1.8~V rail (@sec-gp-control).

The FPGA configures each #ident("ADS127L14") over a dedicated SPI bus, sets each channel's switch lines, and reads both back (GW-1, GW-2). It forwards #ident("SYNC_CLK") to each converter as its clock, retimes #ident("SYNC_START") to an edge of it, and starts both converters on that edge, so that they sample at the same instant as every other converter in the stack (INT-6). It receives each converter's frame-sync data on a dedicated line and checks the status and CRC of every packet. When a channel's converter, switch read-back or excitation monitor shows a fault, the FPGA turns that channel off within one sample (GW-3). It can also switch the channel supply off and on through the enable of its eFuse, which turns off both channels, and it reads the eFuse's fault flag (@sec-gp-supply, GW-12).

The FPGA applies each channel's calibration (GW-4) and gathers all eight readings of each sample into a frame of fixed format (GW-5). It numbers every frame from the last start, packs eight frames into a 1~ms packet with a CRC, and buffers 20~ms of packets (GW-6, INT-10). It serves the packets and its registers to the ECU MCU board as a peripheral on SPI0, reports in every read how much data it still holds (INT-10), and acts on a register write only if the write's CRC is correct (GW-7).

The FPGA is a Lattice #ident("LCMXO2-4000HC-4QN84C"), with 4320 LUTs, 92~kbit of block RAM, two PLLs and 68 I/O in a 7 × 7~mm QFN-84. It is the commercial temperature grade, with a junction range of 0 to 85~°C, and the slowest speed grade, which suffices because the gateware's clocks run at 20~MHz and below. As an HC device it runs from the 3.3~V input alone, with no core regulator. #ident("SYNC_CLK") enters on a primary clock pin of bank 0, from which a PLL can take it. Banks 1 and 4 run at 1.8~V, one for each converter, and banks 0 and 2 at 3.3~V. The FPGA checks its own configuration for upsets (GW-11) and checks #ident("SYNC_CLK") against its internal oscillator (GW-10).

The FPGA configures itself from its internal flash at power-up (GW-8). The ECU MCU board writes a new configuration into that flash in the background through the slave SPI port on bank 2, a hardened configuration port that every image keeps enabled and to which the bus buffer brings SPI0. If the new configuration fails to load, the FPGA falls back to a golden image held in a #ident("W25Q16JV") SPI flash beside it (FW-4), which it writes only after a separate unlock command (GW-8). The flash is on the master SPI pins, which share their clock and data with the slave port, so the bus buffer releases those pins whenever the board is deselected (@sec-stacking). Pull-ups from the configuration guide hold them: 1~kΩ on the clock, as dual boot requires, and 10~kΩ on the data input and on both chip selects.

The slave SPI port also accepts the configuration logic's REFRESH command, which reloads the FPGA from its flash regardless of what the design is doing, so the ECU MCU board can recover a hung FPGA without power-cycling the stack (GW-9). Whether the port stays enabled is set in the feature row in flash, which no upset of the running configuration can change. PROGRAMN is therefore left unconnected, with its internal weak pull-up in a blank device.

The gateware's own SPI interface, which carries the board's commands and data, uses the same clock and data pins through the FPGA's hardened user SPI. Its chip select is a separate input, PB7B, which the board's chip select also drives. The configuration logic therefore sees every frame and interprets its first byte as a command, so no frame of the board's own protocol may begin with a configuration command (GW-13, OI-9). JTAG is brought out to four test points, with TCK held low by 4.7~kΩ.

The FPGA uses 28 of its 68 I/O, besides its four JTAG pins. The converters take eighteen, nine each on banks 1 and 4 at 1.8~V: CLK, START, SCLK, SDI and the chip select out through 62~Ω, RESET out, and SDO, DOUT and FSYNC in. The SPI lane, #ident("SYNC_CLK") and #ident("SYNC_START") take six, the user SPI's chip select one, the channel supply's enable and fault flag two, and the flash's chip select one. The 20~ms buffer occupies about 32~kbit, 35~% of the block RAM. At 16~kSPS it would occupy about 64~kbit, which would fit, and at 32~kSPS about 125~kbit, which would not.

The FPGA, the channel supply, the current limits, the input suppressors and the bus buffer are the board's single points of failure. A failed converter or reference costs only its own channel, because each serves one channel. A failed FPGA or channel supply costs both channels of the board but no other board, because the buffer isolates the board from every shared signal line and the fuse isolates it from the stack's 24~V (@sec-stacking); only a failed buffer could hold a shared line. An input suppressor that failed short would load the stack's rail ahead of the board's limit, but its rating against the rail's own current makes this unlikely. Because the board's ground is the stack's ground, a fault that drives current into it can also disturb the other boards while it lasts (@sec-protection).

== Stacking <sec-stacking>

Boards stack on #ident("ASRP-PCB-INTERCONNECT-2") together with the #ident("E004-TC-BOARD"). The ADC boards share SPI0 to the ECU MCU board, and SPI1, which serves the #ident("E004-TC-BOARD"), passes through them unused (@tab-interconnect-signals). Four solder jumpers connect each board to one of the four chip selects of SPI0. Closing one at assembly sets the board's address, so every board is built the same (INT-1), and no shunt can work loose under vibration. A 100~kΩ pull-up holds the chip select high on a board with no jumper closed.

An #ident("SN74LVC244A") octal buffer stands between the board and the interconnect. Its two groups of four buffers have separate output enables. The first group is always enabled and carries the chip select, #ident("SYNC_CLK") and #ident("SYNC_START"). The buffered chip select enables the second group, which carries the SPI clock and data inputs, each through 100~Ω, and drives #ident("SPI0_MISO") through 62~Ω of series termination, so the board drives that line only while it is selected (INT-4). Each group has one spare buffer.

When the board is deselected, the second group also releases the FPGA's configuration SPI pins, so that a golden-image boot can drive them, and pull-ups hold the FPGA's SPI clock and data inputs high (@sec-fpga). If the master selects the board during such a boot, the 100~Ω resistors limit the clash. The buffer's partial-power-down protection limits the leakage into any pin of an unpowered board to 10~µA, and the chip select's pull-up adds at most 33~µA, so an unpowered board leaves every line at high impedance (INT-4). The buffer also keeps a failed FPGA input off the shared lines. #ident("SYNC_CLK") passes through the buffer to the FPGA, which forwards it to the converters (@sec-gp-control).

The read path passes through the buffer only. The FPGA answers within about 15~ns of an SCLK edge, and the buffer adds at most 5.9~ns on the way in and again on the way out, so #ident("SPI0_MISO") is valid at the connector within about 28~ns, including about 1~ns from the 100~Ω on SCLK. This meets the 30~ns of INT-8, so the lane runs at up to 20~MHz. The buffer enables its output within about 13~ns of the chip select falling, well inside the delay that the master leaves before its first clock edge. Each board produces about 1.6~Mbit/s, so four boards use 6.4~Mbit/s of the 15~Mbit/s that SPI0 carries (INT-9). The ECU MCU board reads the boards one at a time, in any order, and aligns their samples by number (GW-6).

One source drives #ident("SYNC_CLK") and #ident("SYNC_START") to every board, so all boards of both kinds sample in step (REQ-6, INT-5, INT-6). In the ECU stack that source is the ECU MCU board, on which every board already depends.

Each supply input of the board is limited or fused, so that a board that fails short is held off the stack's rails. A #ident("TPS2553") current-limited switch on the 3.3~V input is set to 0.15~A. The 5~V rail feeds only the channels, so it goes directly to the channel supply's #ident("TPS25200") eFuse, which is set to 0.65~A, about four times the channels' maximum draw, and reports its faults to the FPGA (GW-12). The 24~V input passes through an #ident("MF-NSMF020X") resettable fuse, which holds 0.20~A, or 0.10~A at 85~°C, and trips at 0.40~A. The two channels draw at most 60~mA from it, so a short on the board's 24~V trips the fuse rather than loading the stack's rail.

A suppressor on each input clamps transients from the stack's rails. On 5~V, a #ident("TVS0500") breaks down at 7.5 to 8.4~V and clamps at 9.2~V at 43~A. No suppressor that leaves a 5~V rail undisturbed can clamp below the 7~V absolute maximum of an ordinary current-limited switch such as the #ident("TPS2553"), which is why the 5~V input uses an eFuse: its input withstands 20~V. The eFuse also turns off while its input exceeds 7.6~V and clamps its output at 5.4~V, so neither a transient nor a sustained overvoltage on the stack's 5~V reaches the channels. On 3.3~V, an #ident("SD03C") breaks down above 4.0~V and clamps at 5.0~V at 1~A and 5.7~V at 10~A, within the 7~V absolute maximum of the #ident("TPS2553"). No suppressor that leaves 3.3~V undisturbed can clamp below the FPGA's 3.75~V absolute maximum, so the FPGA relies on the limit and the capacitance on its rail for what passes the suppressor. On 24~V, a #ident("TVS2700") clamps a transient below 34~V, under the 40~V rating of the #ident("LT3092").

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
      [2 × #ident("ADS127L14")],
      [One per channel. Four simultaneous converters against one reference: the signal and three monitor inputs. Wideband filter flat to 0.4 of the data rate with 106~dB stop band. 2.55~µV~rms at 8~kSPS in high-speed mode. Offset drift 35~nV/°C, gain drift 1~ppm/°C, nonlinearity 2.8~ppm, all maximum in high-speed mode. GPIO pins that drive the switches, a frame-sync data port, 1.8~V I/O. 7 × 7~mm VQFN-56.],
      [Buffers and excitation drivers],
      [6 × #ident("OPA2189")],
      [Zero-drift, 5.2~nV/√Hz, input bias 300~pA maximum, offset drift 0.006~µV/°C typical, ±65~mA output limit. Three per channel: the signal inputs, the two sides of the excitation bus, and the monitor's excitation and return inputs.],
      [Excitation reference],
      [2 × #ident("REF5020")],
      [2.048~V, 3~ppm/°C maximum (high grade). One per channel, driving its bus amplifiers. VSSOP-8.],
      [Precision resistors],
      [Vishay TNPU e3],
      [Thin film, 5~ppm/°C. At 0.05~%: the #box[4–20~mA] shunt, the 10.0~kΩ SIG+ series resistor and the excitation inverter pair in 0805, and the 2.49~kΩ divider bottom in 1206. At 0.1~%: the excitation monitor's dividers in 0402, except the 240~kΩ, which is above the 0402 range and so in 0805, and the 87.6~kΩ shunt-calibration resistor in 0805.],
      [Current-sense resistor],
      [2 × #ident("PHP01206E1001BST5")],
      [Vishay Dale thin film, 1.00~kΩ, 0.1~%, 1~W, 1206. ±25~ppm/°C maximum and ±15~ppm/°C typical; the error budget uses the typical value. The reference of a piezoresistive bridge (@sec-gp-budget).],
      [Negative rail],
      [#ident("LM2776")],
      [Switched-capacitor inverter, 2.7 to 5.5~V in, 200~mA, 2.5~Ω output resistance, 2~MHz, SOT-23-6. Inverts the channels' +5~V for their −5~V rail, about −4.8~V at their 0.09~A.],
      [Channel regulators],
      [#ident("TPS7A39"), #ident("TPS709")],
      [Dual positive and negative LDO for ±2.5~V: 150~mA each, ±3.3 to ±33~V in, outputs track at start-up, 21~µV~rms. 150~mA LDO for 1.8~V (#ident("TPS70918")), 30~V maximum input, 2 × 2~mm WSON: the two converters' I/O and the FPGA's two banks that face them.],
      [Rail clamp],
      [#ident("TLV431B"), #ident("MMST3906")],
      [Shunt clamp on the channels' +2.5~V rail at about 2.7~V, sinking up to 35~mA, enough for the four signal buffers of both channels driven beyond their input range at once: a 0.5~% shunt reference, set by 118~kΩ over 100~kΩ, driving a 40~V, 200~mA PNP transistor in SOT-323. Draws nothing in normal operation (@sec-gp-supply).],
      [Sensor supply protection],
      [#ident("MF-NSMF020X"), #ident("TVS2700")],
      [Resettable fuse, 0.20~A hold (0.10~A at 85~°C), 0.40~A trip, 30~V, 1206, AEC-Q200, ahead of a flat-clamp suppressor: 27~V working, 29.3 to 33.9~V breakdown, 33.9~V at 40~A, 2 × 2~mm WSON. On the board's 24~V input (@sec-stacking).],
      [Sensor current sources],
      [2 × #ident("LT3092")],
      [2-terminal current source, 0.5 to 200~mA, 1.2 to 40~V, thermal limit, set by its output resistor, which S1 and S2 switch: 1.0~mA for a piezoresistive transducer, 9.0~mA for a load cell, 30~mA for a transmitter. 3 × 3~mm DFN.],
      [FPGA],
      ident("LCMXO2-4000HC-4QN84C"),
      [4320 LUTs, 92~kbit of block RAM, two PLLs from 7~MHz, 68 I/O of which 28 are used, eighteen of them on banks 1 and 4 at 1.8~V for the converters. Internal flash programmed in the background through a hardened SPI port, dual boot with a golden image in an external SPI flash, soft-error detection, single 3.3~V supply. Commercial temperature grade, junction 0 to 85~°C, and speed grade −4. 7 × 7~mm QFN-84 with two rows of pads (@sec-fpga).],
      [Golden image],
      [#ident("W25Q16JVUXIQ")],
      [16~Mbit SPI NOR flash, 2.7 to 3.6~V, 2 × 3~mm USON-8. Holds the FPGA's golden configuration on its master SPI pins (GW-8).],
      [Contact suppressors],
      [8 × #ident("SD36C-01FTG")],
      [Bidirectional avalanche, 36~V stand-off, 40~V at 1~mA, 50~V at 1~A and 60~V at 4~A (8/20~µs), 0.68~Ω dynamic resistance, ±30~kV contact discharge, 40~A fast transients, 1~µA at 36~V, 30~pF, AEC-Q101. One per sensor contact (@sec-protection). SOD-323 (OI-4).],
      [Configuration switches within the rails],
      [4 × #ident("TMUX6212")],
      [Four SPST channels, each closed by logic high, with internal pull-downs so that all open by default. ±4.5 to ±18~V supply, 1.8~V logic. At ±5~V, 7.6~Ω and 2~nA leakage maximum to 85~°C, 0.015~Ω/°C drift. S6, S7 and S10, and the ±5~V drive of the MOSFETs' gates and of the photorelays' LEDs; two per channel. 4 × 4~mm WQFN.],
      [Load-cell return switch],
      [2 × #ident("DMN6075S")],
      [N-channel, 60~V, ±20~V gate. 85~mΩ at 10~V, 120~mΩ at 4.5~V. S3. SOT-23.],
      [Shunt switch],
      [2 × #ident("DMTH6016LFDFWQ")],
      [N-channel, 60~V, ±20~V gate. 27.5~mΩ maximum at 4.5~V. Avalanche-tested in production, 11.7~mJ. AEC-Q101. S8. 2 × 2~mm DFN.],
      [Small-signal switches],
      [4 × #ident("BSS138W")],
      [N-channel, 50~V, ±20~V gate. 3.5~Ω at 10~V, leakage 0.5~µA maximum at 50~V. S4 and S5. SOT-323.],
      [Photorelays],
      [6 × #ident("TLP3475S")],
      [60~V, 0.4~A, 1.5~Ω. Off-state leakage 1~nA maximum at 50~V, 25~°C. 500~V~rms input to output. S1, S2 and S9. 2.0 × 1.45~mm.],
      [Gate clamps],
      [#ident("MMSZ5246BS")],
      [Zener, 16~V, for S4 and S8. Leakage 0.1~µA maximum at 12~V. SOD-323.],
      [Bus buffer],
      [#ident("SN74LVC244ARKSR")],
      [Octal 3-state buffer in two groups of four with separate enables. 5.9~ns maximum at 3.3~V, 7.6~ns to enable, partial-power-down protection with 10~µA maximum leakage while unpowered, 4~pF input. One group takes the chip select, #ident("SYNC_CLK") and #ident("SYNC_START"). The other, enabled by the chip select, takes the SPI clock and data in and drives #ident("SPI0_MISO"), with one buffer spare in each group (@sec-stacking). 4.5 × 2.5~mm VQFN-20.],
      [Converter line termination],
      [10 × 62~Ω],
      [0402, at the FPGA's CLK, START, SCLK, SDI and chip-select outputs to each converter; the same value as the #ident("SPI0_MISO") termination (@sec-gp-control).],
      [Chip-select and shield jumpers],
      [5 solder jumpers],
      [Two pads each, closed with solder at assembly. Four pick one of the chip selects of SPI0, and one ties #ident("GP_SHLD") to the stack's ground.],
      [Sensor connector],
      ident("M80-5001242"),
      [Harwin Datamate J-Tek, 12-way, 2~mm pitch, vertical through-hole, M2 jackscrews, −55 to 125~°C. 800~V working between contacts.],
      [Stack connector],
      [TBD],
      [#ident("ASRP-PCB-INTERCONNECT-2"), 32-way, pass-through (INT-1, INT-3).],
      [Input suppressors],
      [#ident("TVS0500"), #ident("SD03C")],
      [On the board's 5~V, ahead of the channels' supply limit, a flat-clamp suppressor: 5~V working, 7.5 to 8.4~V breakdown, 9.2~V at 43~A, within the limit's 20~V input rating, 2 × 2~mm WSON. On its 3.3~V, ahead of that input's limit, a bidirectional avalanche suppressor: 3.3~V stand-off, 4.0~V minimum breakdown, 5.0~V at 1~A, 5.7~V at 10~A and 11~V at 55~A (8/20~µs), 1~µA at 3.3~V, SOD-323.],
      [Current limits],
      [#ident("TPS2553"), #ident("TPS25200")],
      [On the board's 3.3~V, a current-limited switch, 2.5 to 6.5~V, set to 0.15~A. On the channels' supply, which takes the stack's 5~V directly, a 5~V eFuse in the same 2 × 2~mm WSON and pinout: input rated to 20~V, output clamped at 5.25 to 5.55~V, off while its input is above 6.8 to 8.45~V, 90~mΩ maximum, set by 150~kΩ to 0.59 to 0.71~A.],
    ),
  ) <tab-components>
]

= Physical Implementation <sec-physical>

Appendix A draws the board as this summary describes it: two instances of the channel sheet, the shared supply sheet, the stack sheet and the FPGA sheet. No board has yet been laid out, so the following estimates set the budget for REV A.

#params(
  cols: 4,
  ("Board", raw("e003-adc-board")),
  ("Revision", [—]),
  ("Board Area", [60 × 60~mm, 72~cm² on two sides]),
  ("Stack-up", [TBD]),
  ("Placement Area", [20~cm²]),
  ("Sensor Connector", [#ident("M80-5001242")]),
  ("Stack Connector", [TBD, 32-way]),
  ("Input Power", [0.9 to 2.5~W, estimated]),
)

The estimate sums the courtyards of the footprints in the schematic and allows 1.6 times that area for placement, which leaves about 40~% of the area under the parts for vias, routing and test access. The outline provides 72~cm² over its two sides (REQ-2), of which the connectors, the four M3 mounting holes and the board edge take a part. The parts must fit in what remains (@tab-area).

#figure(
  caption: [Board Area Estimate],
  datatable(
    columns: (1fr, auto),
    align: (left, right),
    header: ("Item", "Area"),
    [Two channels: front ends, current sources and switches],
    [8.4~cm²],
    [Channel supply: limit, negative rail, regulators and clamp],
    [1.9~cm²],
    [Two channels: converters and monitors],
    [3.8~cm²],
    [Two channels: references and excitation buses],
    [2.2~cm²],
    [Stack side: FPGA, flash, buffer, input protection and current limit],
    [3.4~cm²],
    table.hline(stroke: (paint: ink.rule, thickness: rule.hair)),
    [Parts, placed],
    [20~cm²],
    [Connectors, holes and edge, both sides],
    [14~cm²],
    [Left for parts, both sides],
    [58~cm²],
    [Use of what is left],
    [34~%],
  ),
) <tab-area>

The parts take about a third of the available area, and between placement allowances of 1.4 and 1.8 the use ranges from 30 to 38~%. A channel occupies 7.2~cm² once placed, including its reference; the shared channel supply occupies 1.9~cm², and the stack side 3.4~cm², including its input protection and the converters' series resistors. The fit is to be confirmed by the layout (OI-6).

Input power is about 0.9~W per board with both channels on, plus up to 0.3~W for each channel configured for a load cell and 0.8~W for each configured for a transmitter, the sensors' share drawn from the stack's 24~V rail, for a total of 0.9 to 2.5~W.

The layout must observe two constraints. Because the board has one ground, the channels' analog parts must sit apart from the FPGA and the interconnect, and the suppressors' return path to the stack's ground must pass neither. Each channel's contacts are grouped on the sensor connector (@tab-sensor-pinout), and each channel's front end must sit behind its own pin group.

= Open Issues <sec-open-issues>

The following issues are known at this revision and remain unresolved.

#show figure.where(kind: table): set par(justify: false)

#figure(
  caption: [Open Issues],
  datatable(
    columns: (auto, 2fr, 3fr),
    align: (left, left, left),
    header: ("Item", "Issue", "Disposition"),
    ident("OI-1"),
    [24~V on the stack interconnect],
    [The board takes its sensors' 24~V from #ident("ASRP-PCB-INTERCONNECT-2") on pins 1 and 2, which were previously ground (@tab-interconnect-pinout, INT-2). A full stack then draws 0.76~A at 5~V, within the 2~A of the #ident("E001-POWER-BOARD"), and 0.24~A at 24~V. The #ident("E001-POWER-BOARD") must provide that 24~V, and the #ident("E004-TC-BOARD") must pass pins 1 and 2 through rather than tie them to ground.],

    ident("OI-2"),
    [Stack connector and library additions],
    [Every part on the board has a record in the parts library except the stack connector, which remains TBD until the 32-way part of #ident("ASRP-PCB-INTERCONNECT-2") is chosen. The sensor and stack connectors use board-specific symbols that name their contacts. The records, symbols and footprints added to the library for this board are to be checked against their datasheets, and given their distributor numbers, before the library is committed. The two rows of pads of the QFN-84 lie 0.15~mm apart, which the board's fabrication rules must allow.],

    ident("OI-3"),
    [Ground return through the stack],
    [The channels share the stack's ground, so a suppressor's discharge and a fault current from a contact return to the vehicle wherever the stack's ground meets it, through the stack's power board. Where that is, and whether the shields terminate at the board, depend on the vehicle grounding scheme and are TBD (@sec-protection, SEN-1).],

    ident("OI-4"),
    [Suppressor sourcing],
    [The contact suppressor is the Littelfuse #ident("SD36C-01FTG"), an avalanche part in SOD-323. It clamps at about 60~V at the first peak of an 8~kV discharge, which is why S8 is a 60~V part and #ident("EXC+") carries 100~nF (@sec-protection). Whether S8, the photorelays and the #ident("LT3092") survive the REQ-14 levels is to be tested on the first boards. Distributors show the #ident("SD36C-01FTG") with long lead times, and one lists it as being discontinued; Bourns' #ident("CDSOD323-T36SC") is the second source, with the same stand-off voltage and package. The #ident("E004-TC-BOARD") still uses TI's #ident("TVS3301"), and its suppressors are to be brought into line.],

    ident("OI-5"),
    [Low-impedance faults on the excitation and current-loop paths],
    [These paths meet REQ-15 only against a current-limited source. A low-impedance 28~V source on #ident("EXC−"), or on #ident("SIG+") in the #box[4–20~mA] configuration, can destroy S4 or the shunt, or hold the channel's bus at its amplifier's limit (@tab-protection). The damage stays within that channel, but without isolation the fault current returns through the stack's ground and can disturb the other boards while it lasts. This is acceptable if no such source in the harness can reach these contacts; otherwise those paths need a fuse or current limit, which on #ident("EXC−") would cost precision.],

    ident("OI-6"),
    [Board area to be confirmed by layout],
    [The parts need 20~cm² once placed, against 58~cm² available on the 60 × 60~mm outline: 34~% (@tab-area), or 38~% at a placement allowance of 1.8. The estimate rests on courtyard areas and a placement allowance, and is to be confirmed by the layout.],

    ident("OI-7"),
    [Gateware],
    [The FPGA's gateware, its verification and its update procedure are to be written to GW-1 to GW-13. The gateware carries the configuration interlocks (@sec-gw).],

    ident("OI-8"),
    [Stability of the excitation bus],
    [Each half of a channel's bus amplifier drives its side of the bus without an isolating resistor. Its load is 1~nF on the negative side, the converter's reference capacitors behind 237~Ω and, in a load-cell channel, the capacitance of the excitation wire through S3 (@sec-gp-excitation). The #ident("OPA2189") datasheet characterises capacitive loading only with a typical overshoot curve, so the bus's stability is to be confirmed on the first boards with the longest harness. If the bus rings, a small resistor inside each amplifier's feedback loop will isolate the load.],

    ident("OI-9"),
    [One chip select for the FPGA's configuration port and its user SPI],
    [The board has one chip select, which drives both the SN input of the slave SPI port and the user SPI's chip select on PB7B (@sec-fpga). Lattice describes the two as separate selects on a shared clock and data bus (FPGA-TN-02162). With one select, the configuration logic sees every frame of the board's own protocol, and GW-13 keeps the first byte of each frame out of its command set. It remains to be confirmed on the first board that the configuration logic then leaves SO to the user SPI, and that background programming and REFRESH work alongside the user SPI. If they do not, the board needs a second chip select, or a timer of five parts that pulls PROGRAMN low when the chip select is held low.],
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
