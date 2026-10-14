#import "@local/eng-report:0.6.0": *
#import "gp-channel.typ": gp-channel, gp-monitor

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
    box(width: 8cm, align(left, box(
      fill: white,
      inset: (x: 2pt, y: 1pt),
      text(fill: ink.mute, label),
    ))),
  ),
  inset: inset,
  stroke: (paint: ink.rule, thickness: rule.hair, dash: "dashed"),
  fill: none,
  shape: fletcher.shapes.rect,
  snap: false,
  layer: 1,
)

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
    The ADC board is the analog data acquisition board of the ASRP ECU stack. Each board provides four general-purpose channels with a 2~kHz bandwidth, sampled simultaneously and configurable for load cells, piezoresistive pressure transducers, #box[4–20~mA] transmitters and voltage transmitters, and isolated from the stack. Boards stack to scale the channel count, alongside the #ident("E004-TC-BOARD"), which carries the thermocouples. They connect to the ECU MCU board over a dedicated stacking interconnect, which brings them power from the power board and carries their data for logging. This draft sets out the requirements and architecture for REV A of the ADC board.
  ],
)

// =============================================================================
//  FRONT MATTER
// =============================================================================

#revision-record(
  (
    "-",
    "2026-10-03",
    [Initial draft.],
    "T. Nagy Zambo",
  ),
)

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

The #ident("E003-ADC-BOARD") is the analog data acquisition board of the ECU stack for the Advanced Small Rocket Project (ASRP). Each board carries four general-purpose channels, configurable for load cells, piezoresistive pressure transducers, #box[4–20~mA] transmitters or voltage transmitters. Boards stack to reach the channel count a vehicle needs. The thermocouple channels, first a second bank of this board, moved to the #ident("E004-TC-BOARD") when the two banks together outgrew the 60 × 60~mm outline. The measurements are flight-critical, so the design confines the effect of any fault to as few channels as possible.

The boards connect to the ECU MCU board over #ident("ASRP-PCB-INTERCONNECT-2"), a stacking interconnect defined in this document (@sec-interfaces). It also serves the #ident("E004-TC-BOARD"), and carries the data of both and the 5~V and 3.3~V rails of the #ident("E001-POWER-BOARD"), passed on by the ECU MCU board. The ECU MCU board configures and reads the converters and logs the data to eMMC.

== Requirements

Requirements stated with "must" are mandatory. Those stated with "should" are design goals.

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
    [Device should sample its general-purpose channels simultaneously with those of every other board in the stack],
    [Local],
    [REQ-7],
    [Device must provide each general-purpose channel with a measurement bandwidth of 2~kHz],
    [Local],
    [REQ-8],
    [Device must allow firmware to configure each general-purpose channel for a full-bridge load cell, a piezoresistive pressure transducer, a #box[4–20~mA] transmitter or a voltage transmitter],
    [Local],
    [REQ-9],
    [Device must excite bridge sensors and measure them ratiometrically],
    [Local],
    [REQ-10],
    [Device should provide shunt calibration on each bridge-sensor channel],
    [Local],
    [REQ-11],
    [Device should galvanically isolate the general-purpose channels from the stack],
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
  ),
)

= System Description

== Architecture

Each board carries four general-purpose channels (@fig-arch). Everything for a channel lives on the board: connector, front end, converter and isolation (REQ-12). The board connects to the ECU MCU board and to further boards over #ident("ASRP-PCB-INTERCONNECT-2"), which carries its power and data (@sec-interfaces).

#figure(
  caption: [Board Architecture],
  {
    let w = 5.2cm
    let h = 0.9cm
    let lane = 6pt // offset of a data and a power edge either side of the column's centre line
    let blk(pos, body, name, ..args) = node(pos, body, width: w, height: h, name: name, ..args)
    // A data edge and a power edge side by side, between a node in row
    // `top` and the node below it in row `bottom`.  Power flows up.
    let pair(top, bottom, upper, lower, data: none, power: none) = (
      edge(
        (rel: (-lane, 0pt), to: (0, bottom)),
        (rel: (-lane, 0pt), to: (0, top)),
        "<|-|>",
        data,
        label-side: left,
        snap-to: (lower, upper),
        ..wire.signal,
      ),
      edge(
        (rel: (lane, 0pt), to: (0, bottom)),
        (rel: (lane, 0pt), to: (0, top)),
        "-|>",
        power,
        label-side: right,
        snap-to: (lower, upper),
        ..wire.power,
      ),
    )
    pad(
      top: 1.4em,
      diagram(
        ..lattice(w, row-gap: 30pt),
        blk((0, 0), [Bridge sensors,\ transmitters ×4], <gp-sens>, shape: shape.io),
        blk((0, 1), [General-purpose\ bank, 4 channels], <gp>),
        blk((0, 2), [Isolation barrier:\ data, supply], <gp-iso>),
        blk((0, 3), [Stack side: slot select,\ bus buffer, current limits], <logic>),
        blk((0, 4), [ASRP-PCB-INTERCONNECT-2], <stack>, shape: shape.io),

        edge(<gp-sens>, <gp>, "-|>"),
        ..pair(1, 2, <gp>, <gp-iso>),
        ..pair(2, 3, <gp-iso>, <logic>, data: [Data], power: [5~V]),
        ..pair(3, 4, <logic>, <stack>, data: [SPI, slot lines,\ clock, start, select], power: [5~V, 3.3~V]),

        zone(<gp-sens>, label: [Engine]),
        zone(<gp>, <logic>, label: [This board]),
      ),
    )
  },
) <fig-arch>

- The general-purpose bank is an isolated domain, isolated from the stack (REQ-11), and from the thermocouple bank of every #ident("E004-TC-BOARD"). A sensor fault therefore costs at most the four channels of one board.
- The bank has its own isolated supply and data isolators. The stack side drives the shared bus and limits the current the board can draw from the 5~V and 3.3~V rails.
- Every sensor contact has a transient suppressor, and the parts behind it withstand a 28~V fault, the highest voltage in the engine harness (@sec-protection). Where a configuration closes a low-impedance path into the bank, the fault must come from a current-limited source (OI-5).
- The bank is tied to the engine at one point, through a resistor. A fault then moves the potential of the bank instead of driving current through its ground.
- Boards stack to add channels, sharing the general-purpose SPI bus to the ECU MCU board (@sec-stacking).
- In the diagrams, heavy lines carry power and dashed lines carry digital data.

== Operations Concept

TBD

== Interfaces <sec-interfaces>

The board has two external interfaces (@tab-interfaces): #ident("ASRP-PCB-INTERCONNECT-2") to the ECU MCU board and further boards, and a sensor connector.

#figure(
  caption: [External Interfaces and Signals],
  datatable(
    columns: (auto, auto, 1fr),
    align: (left, left, left),
    header: ("Interface", "Part", "Signals"),
    ident("ASRP-PCB-INTERCONNECT-2"),
    [TBD, 32-way],
    [5V ×2, 3V3 ×2, GND ×6, two SPI buses with three chip selects and three data-ready lines each, two general-purpose select lines, ADC_CLK, ADC_START],
    [Sensor connector],
    [#ident("M80-5001842"), 18-way],
    [EXC±, SIG± for four general-purpose channels, a shield pair],
  ),
) <tab-interfaces>

The ADC boards do not use #ident("ASRP-PCB-INTERCONNECT-1"). #ident("ASRP-PCB-INTERCONNECT-2"), defined here, is a stacking bus: the ECU MCU board at one end, with up to three ADC boards on its general-purpose bus and up to three #ident("E004-TC-BOARD") on its thermocouple bus stacked on it, each passing every contact through to the next. It carries the two SPI buses with a chip select and data-ready line per slot, two select lines for the general-purpose bus, the converter clock and START, and the 5~V and 3.3~V rails (@tab-interconnect-pinout, @tab-interconnect-signals).

#figure(
  caption: [#ident("ASRP-PCB-INTERCONNECT-2") Pinout],
  datatable(
    columns: (auto, 1fr, auto, 1fr),
    align: (center, left, center, left),
    header: ("Pin", "Signal", "Pin", "Signal"),
    [1], ident("5V"), [2], ident("5V"),
    [3], ident("GND"), [4], ident("GND"),
    [5], ident("3V3"), [6], ident("3V3"),
    [7], ident("ADC_CLK"), [8], ident("GND"),
    [9], ident("ADC_START"), [10], ident("GP_SEL0"),
    [11], ident("GP_SCLK"), [12], ident("GND"),
    [13], ident("GP_SDI"), [14], ident("GP_SDO"),
    [15], ident("GP_CS0"), [16], ident("GP_CS1"),
    [17], ident("GP_CS2"), [18], ident("GP_DRDY0"),
    [19], ident("GP_DRDY1"), [20], ident("GP_DRDY2"),
    [21], ident("TC_SCLK"), [22], ident("GND"),
    [23], ident("TC_SDI"), [24], ident("TC_SDO"),
    [25], ident("TC_CS0"), [26], ident("TC_CS1"),
    [27], ident("TC_CS2"), [28], ident("TC_DRDY0"),
    [29], ident("TC_DRDY1"), [30], ident("TC_DRDY2"),
    [31], ident("GP_SEL1"), [32], ident("GND"),
  ),
) <tab-interconnect-pinout>

#figure(
  caption: [#ident("ASRP-PCB-INTERCONNECT-2") Signals],
  datatable(
    columns: (auto, auto, auto, auto, 1fr),
    align: (left, center, left, left, left),
    header: ("Signal", "Pins", "Direction", "Boards", "Use"),
    ident("5V"), [2], [From MCU], [All], [5~V rail from #ident("E001-POWER-BOARD"). Supplies the isolated domains through each board's current limit.],
    ident("3V3"), [2], [From MCU], [All], [3.3~V rail from #ident("E001-POWER-BOARD"). Supplies the stack side of the barriers and the bus buffers.],
    ident("GND"), [6], [—], [All], [Power return and signal reference.],
    ident("ADC_CLK"), [1], [From MCU], [All], [Converter clock, 8.192~MHz.],
    ident("ADC_START"), [1], [From MCU], [All], [Idles high. A short low pulse starts conversion on every board (INT-7).],
    ident("GP_SCLK"), [1], [From MCU], [All], [SPI clock, 5~MHz.],
    ident("GP_SDI"), [1], [From MCU], [All], [SPI data into the converter chain of the selected board.],
    ident("GP_SDO"), [1], [To MCU], [Selected], [SPI data out of the converter chain.],
    ident("GP_DRDY0…2"), [3], [To MCU], [One per slot], [Data ready from one board's general-purpose bank, 8~kHz, driven continuously.],
    ident("GP_CS0…2"), [3], [From MCU], [One per slot], [Selects the general-purpose bank of one board.],
    ident("GP_SEL0…1"), [2], [From MCU], [All], [Choose the converter chain, the excitation monitor or the configuration latch of the selected general-purpose bank (@tab-gp-select). Set before its chip select falls.],
    ident("TC_SCLK"), [1], [From MCU], [All], [SPI clock, 5~MHz.],
    ident("TC_SDI"), [1], [From MCU], [All], [SPI data into the converter of the selected #ident("E004-TC-BOARD").],
    ident("TC_SDO"), [1], [To MCU], [Selected], [SPI data: conversion results and register read-back.],
    ident("TC_DRDY0…2"), [3], [To MCU], [One per slot], [Data ready from one #ident("E004-TC-BOARD"), 4~kHz, driven continuously.],
    ident("TC_CS0…2"), [3], [From MCU], [One per slot], [Selects one #ident("E004-TC-BOARD").],
  ),
) <tab-interconnect-signals>

Each clock line faces a ground across the rows, and the power pins sit at one end, apart from the signals.

#requirement(
  "INT-1",
  [Every contact of #ident("ASRP-PCB-INTERCONNECT-2") shall pass through each ADC board, so boards stack in any order and every position is wired the same.],
  note: [A board takes its slot from its jumper, not from its position in the stack.],
)

#requirement(
  "INT-2",
  [The ECU MCU board shall supply #ident("ASRP-PCB-INTERCONNECT-2") with 5~V and 3.3~V, taken from the rails of #ident("ASRP-PCB-INTERCONNECT-1"). Each ADC board draws up to 0.18~A at 5~V, plus 0.14~A for each general-purpose channel set up for a transmitter, and up to 0.04~A at 3.3~V. Each #ident("E004-TC-BOARD") draws up to 0.04~A at 5~V and 0.04~A at 3.3~V.],
  note: [The 5~V rail of the #ident("E001-POWER-BOARD") is rated 2~A for the whole ECU stack. Three ADC boards without transmitters take 0.54~A of it, and three thermocouple boards 0.12~A. Three ADC boards with a transmitter on every channel would take 2.2~A, so the number of transmitter channels in a stack is limited by that rail (OI-1, @tab-open-issues).],
)

#requirement(
  "INT-3",
  [Each contact shall be rated for at least 2~A. Each power rail and its return shall be carried on at least two contacts.],
  note: [One contact then carries the full 2~A of the #ident("E001-POWER-BOARD") 5~V rail, so a single open contact leaves every board powered.],
)

#requirement(
  "INT-4",
  [Signals shall be 3.3~V LVCMOS referenced to #ident("GND") and series-terminated at their driver. A board shall drive #ident("GP_SDO") or #ident("TC_SDO") only while selected, shall drive the data-ready lines of its own slot continuously, and shall leave every line at high impedance when unpowered.],
  note: [The ECU MCU board pulls each data-ready line to its inactive level, so an empty slot or an unpowered board never signals data ready.],
)

#requirement(
  "INT-5",
  [The #ident("ASRP-PCB-INTERCONNECT-2") connector shall be retained against launch vibration and shock.],
  note: [Connector part, pitch and stack height are TBD.],
)

#requirement(
  "INT-6",
  [The ECU MCU board shall drive #ident("ADC_CLK") at 8.192~MHz, ±50~ppm or better, from a dedicated oscillator.],
  note: [A MEMS oscillator such as the #ident("SIT8918"), rated −40 to 125~°C, meets this. Every ADC board depends on this one clock.],
)

#requirement(
  "INT-7",
  [#ident("ADC_START") shall idle high. The ECU MCU board shall start or resynchronize conversion with a low pulse shorter than 2048 #ident("ADC_CLK") cycles, 250~µs.],
  note: [#ident("ADC_START") drives the SYNC/RESET input of the #ident("ADS131M08") excitation monitor here and of the #ident("ADS131M06") on the #ident("E004-TC-BOARD"), which resets the converter when held low for longer. The #ident("ADS127L11") restarts on the rising edge in its synchronized control mode (FW-3).],
)

The sensors connect through a Harwin Datamate #ident("M80-5001842"), which carries the four channels, four contacts each, and their shields (@tab-sensor-pinout).

#figure(
  caption: [Sensor Connector #ident("M80-5001842") Pinout],
  datatable(
    columns: (auto, 1fr, auto, 1fr),
    align: (center, left, center, left),
    header: ("Pin", "Signal", "Pin", "Signal"),
    [1], ident("GP1_EXC+"), [2], ident("GP1_EXC−"),
    [3], ident("GP1_SIG+"), [4], ident("GP1_SIG−"),
    [5], ident("GP2_EXC+"), [6], ident("GP2_EXC−"),
    [7], ident("GP2_SIG+"), [8], ident("GP2_SIG−"),
    [9], ident("GP3_EXC+"), [10], ident("GP3_EXC−"),
    [11], ident("GP3_SIG+"), [12], ident("GP3_SIG−"),
    [13], ident("GP4_EXC+"), [14], ident("GP4_EXC−"),
    [15], ident("GP4_SIG+"), [16], ident("GP4_SIG−"),
    [17], ident("GP_SHLD"), [18], ident("GP_SHLD"),
  ),
) <tab-sensor-pinout>

#figure(
  caption: [General-Purpose Contact Use by Configuration],
  datatable(
    columns: (auto, 1fr, 1fr, 1fr),
    align: (left, left, left, left),
    header: ("Contact", "Bridge sensor", "4–20 mA transmitter", "Voltage transmitter"),
    ident("EXC+"), [Excitation current in, 9.0~mA or 1.0~mA], [Loop supply, 24~V, 30~mA limit], [Transmitter supply, 24~V, 30~mA limit],
    ident("EXC−"), [Excitation current out], [Loop return through the link to #ident("SIG−") (CBL-1), tied to the bank common], [Supply return, tied to the bank common],
    ident("SIG+"), [Signal +], [Loop current in, to the 100~Ω shunt], [Signal, 0–10~V],
    ident("SIG−"), [Signal −], [Low side of the shunt, linked to #ident("EXC−") (CBL-1)], [Signal return, measured at the contact. Linked to #ident("EXC−") for an isolated output (CBL-1)],
  ),
) <tab-sensor-config>

- The four contacts of a channel take their function from the configuration that firmware sets (@tab-channel-config). In both transmitter configurations S4 ties #ident("EXC−") to the bank common as the supply return. The cable of a #box[4–20~mA] transmitter links #ident("SIG−") to it, so that the loop returns there, and so does the cable of a voltage transmitter with an isolated output (CBL-1).
- Each pair of a channel sits in the same column of the connector, so the wires of a twisted pair land side by side.
- #ident("GP_SHLD") takes the cable shields. A jumper ties it to the bank common, or leaves it open where the shield is terminated at the engine.

A sensor's cable carries one rule beyond its pinout.

#requirement(
  "CBL-1",
  [The cable of a #box[4–20~mA] transmitter, and of a voltage transmitter with an isolated output, shall link #ident("SIG−") to #ident("EXC−") at the sensor connector. No other cable shall link them.],
  note: [The link returns the loop, or references an isolated output, through S4 to the bank common, in place of a switch on the board. A three-wire voltage transmitter already joins its supply and signal returns inside it, and a second join in the cable would put part of its supply current into #ident("SIG−") and into the reading. On a bridge sensor the link would short half the bridge, which the excitation monitor sees at 1~mA as a gross fault (@sec-gp-monitor).],
)

== Firmware Requirements

These requirements apply to the firmware on the ECU MCU board that reads this board.

#requirement(
  "FW-1",
  [Firmware shall flag a board whose data-ready does not arrive within one conversion period of its expected time, and shall stop using its data until it recovers.],
  note: [Every board signals a fixed number of #ident("ADC_CLK") cycles after START, so a missing or late data-ready marks a failed board or a lost clock.],
)

#requirement(
  "FW-2",
  [Firmware shall apply a stored gain and offset correction to every channel.],
  note: [The corrections come from calibration at test.],
)

#requirement(
  "FW-3",
  [Firmware shall configure each #ident("ADS127L11") for data-output-only SDO, START in synchronized control mode, the wideband filter at an oversampling ratio of 512 and the input precharge buffers on. It shall turn the REFP precharge buffer on for a channel set up for a bridge sensor and off for a transmitter, and shall set the low-reference range for a piezoresistive transducer and the high-reference range for every other channel.],
  note: [The daisy chain needs data-output-only SDO. The REFP precharge buffer accepts REFP only up to AVDD1 − 0.7~V, 1.8~V here. A transmitter channel's REFP is the 2.048~V bus, above that limit. A load cell's reaches 1.66~V for a 410~Ω cell at 9.0~mA, and a piezoresistive transducer's sits near −1.05~V under its 1.0~V reference.],
)

#requirement(
  "FW-4",
  [Firmware shall configure the general-purpose channels through the configuration latch: it shall shift the four channels' codes in twice, check that the first copy returns, and only then commit them. It shall move a channel between configurations through off, and shall raise a channel's current above 1~mA only after the excitation monitor has measured its sensor at 1~mA.],
  note: [The check catches a corrupted transfer before it reaches a switch (@sec-gp-latch). Passing through off lets one configuration's switches open before the next one's close. The 30~mA branch would destroy a piezoresistive transducer rated for 3~mA, and only the reading at 1~mA shows which sensor is connected (@sec-gp-switches).],
)

#requirement(
  "FW-5",
  [Firmware shall tare each load-cell channel on command, storing its reading under no load and subtracting it from the readings that follow.],
  note: [Offset drift sets the accuracy of a load-cell channel (@tab-gp-budget). A tare before each test removes the drift accumulated since calibration.],
)

== Key Parameters

#figure(
  caption: [Key Design Parameters],
  datatable(
    columns: (auto, 1fr, auto),
    align: (left, left, left),
    header: ("Item", "Value", "Source"),
    [Channels per board],
    [Four general-purpose],
    [REQ-5],
    [General-purpose bandwidth],
    [2~kHz. 8~kSPS, simultaneous across the stack, flat to 3.2~kHz],
    [#ident("ADS127L11") wideband filter],
    [General-purpose range],
    [Within ±2.0~V at the converter: load cell ±6.3~mV at 2~mV/V, piezoresistive transducer 160~mV typical, #box[4–20~mA] as 0.4–2.0~V, 0–10~V through 5:1],
    [@tab-channel-config],
    [General-purpose noise],
    [2.84~µV~rms at 8~kSPS, of which the converter 2.58~µV~rms],
    [@sec-gp-budget],
    [General-purpose drift],
    [After calibration, per 10~°C: 0.16~% of full scale for a load cell, 0.009~% for a piezoresistive transducer, 0.008~% for #box[4–20~mA], 0.010~% for 0–10~V (root sum square)],
    [@tab-gp-budget],
    [Bridge excitation],
    [Constant current per channel: 9.0~mA for a load cell, 1.0~mA for a piezoresistive transducer],
    [#ident("LT3092")],
    [Excitation bus],
    [±2.048~V per bank: the converter reference for transmitters, the return for bridge excitation],
    [#ident("REF5020")],
    [Converter clock],
    [8.192~MHz from the ECU MCU board (INT-6)],
    [@sec-stacking],
    [Stack],
    [Up to three boards on the general-purpose SPI bus at 5~MHz],
    [@sec-stacking],
    [Sensor supply],
    [24~V, or 15~V by placement, through a current source per channel: a 30~mA limit for a transmitter, the excitation of a bridge],
    [#ident("TPS61170"), #ident("LT3092")],
    [Input protection],
    [A 28~V fault on any contact, current-limited where a configuration closes a low-impedance path (OI-5). ±8~kV contact discharge and ±1~kV fast transients],
    [REQ-14, @sec-protection],
    [Input power],
    [About 1.0~W per board, plus about 0.7~W per transmitter channel],
    [Estimate],
  ),
)

= Functional Blocks

== General-Purpose Channels <sec-gp>

Each general-purpose channel has its own converter behind a precision buffer, and its own current source, which excites a bridge sensor or limits a transmitter's supply. The four channels of a bank share one isolated supply and a ±2.048~V excitation bus, which is the converter reference of a transmitter channel and the return for a bridge's excitation current. Every channel is built the same. Firmware sets it up for its sensor with a three-bit code, held in the bank's configuration latch, that closes some of ten switches, S1 to S10 (@tab-channel-config, @sec-gp-switches, @sec-gp-latch), and sets its converter to match (FW-3). Every configuration keeps the signal within ±2.0~V of the bank common, inside the input ranges of both the buffer and the converter. A ninth converter, shared by the four channels, monitors their excitation (@sec-gp-monitor).

#figure(
  caption: [General-Purpose Channel Configurations],
  datatable(
    columns: (auto, 1fr, auto),
    align: (left, left, left),
    header: ("Configuration", "Set by firmware", "At the converter"),
    [Load cell],
    [4-wire full bridge, 350~Ω typical. 9.0~mA (S1). #ident("EXC−") straight to the bus (S3). REFP from #ident("EXC+") through 10~kΩ (S5). Shunt calibration (S10).],
    [±6.3~mV at 2~mV/V, ratiometric to the bridge voltage],
    [Piezoresistive transducer],
    [Bridge such as the Keller 7L, 3.5~kΩ typical. 1.0~mA. #ident("EXC−") through the 1.00~kΩ current-sense resistor. REFP from #ident("EXC−") (S6). Shunt calibration (S10).],
    [160~mV typical at full scale, ratiometric to the current],
    [#box[4–20~mA] transmitter],
    [24~V loop supply through a 30~mA limit (S2). 100~Ω shunt across the signal contacts (S8). #ident("EXC−") to the bank common (S4), and #ident("SIG−") to it through a link in the cable (CBL-1). REFP from the bus (S7).],
    [0.4–2.0~V],
    [Voltage transmitter],
    [0–10~V output. 24~V supply through a 30~mA limit (S2). #ident("EXC−") to the bank common (S4). 2.49~kΩ divider bottom to #ident("SIG−") (S9). An isolated output's cable links #ident("SIG−") to #ident("EXC−") (CBL-1). REFP from the bus (S7).],
    [0–2.0~V],
  ),
) <tab-channel-config>

The signal chain from the series protection to the converter, the sensor supply and the switches are the same in every configuration (@sec-gp-chain, @sec-gp-switches). @fig-gp-load-cell, @fig-gp-piezo, @fig-gp-current and @fig-gp-voltage draw the one channel set up for each sensor: closed switches and the parts in use in black, open switches and the parts they leave idle in grey. The parts that set the converter's accuracy are drawn as components, and the excitation bus and sensor supply as blocks. The switches' gate drive and decoupling are left out.

=== Signal Chain and Sensor Supply <sec-gp-chain>

- Each channel has its own #ident("ADS127L11"). The four share one clock and one START, so they sample simultaneously (REQ-6), and are daisy-chained on one SPI line.
- They run in high-speed mode from the 8.192~MHz stack clock. The wideband filter at an oversampling ratio of 512 gives 8~kSPS, flat to 3.2~kHz with 106~dB of rejection from 4~kHz, which covers the 2~kHz bandwidth (REQ-7). The converter's noise is 2.58~µV~rms, and the channel's 2.84~µV~rms with the buffers and protection, 0.045~% of full scale for a 2~mV/V load cell (@sec-gp-budget).
- An #ident("OPA2189") buffers the two inputs of each channel. The converter's precharge buffers draw up to ±3~µA, which through a 350~Ω bridge and the protection would give errors of a millivolt or more. The #ident("OPA2189") draws under 300~pA. Its input range ends 2.5~V below its positive rail, so it runs from the ±5~V rails while the converters run from ±2.5~V.
- Each input carries 10~kΩ of series protection, 0805 for the 78~mW of a 28~V fault, with low-leakage clamps to the ±5~V rails and 110~pF across the pair. On SIG+ it is 0.05~%, 5~ppm/°C thin film, because it is also the top of the voltage transmitter's divider.
- #ident("REF5020") sets a ±2.048~V excitation bus. One half of an #ident("OPA2189") follows it and the other inverts it, each driving one side of the bus through a #ident("BUF634A"). The precision amplifier sets the voltage and the buffer supplies up to 250~mA. The bus is the converter reference of a transmitter channel, and its negative side takes the excitation current of a bridge.
- The buffers and the excitation run from the ±5~V rails and are up before the ±2.5~V. 237~Ω at each converter input and reference pin, or 10~kΩ at a load cell's REFP, holds the current into its clamps below their 10~mA rating meanwhile, and in a fault. With 3.3~nF across the inputs and 330~pF from each to AVSS it is also the converter's input filter, with a differential pole at 97~kHz. The common-mode capacitors, a tenth of the differential one as the converter datasheet recommends, supply the common-mode part of each sample's charge and return it to AVSS, which powers the converter's sampling switches.
- Each converter takes REFN from the negative side of the bus, and REFP from one of three points, selected by S5, S6 or S7: the top of a load cell, the top of a piezoresistive bridge's current-sense resistor, or the positive side of the bus for a transmitter. The bus lies above the 1.8~V limit of the converter's REFP precharge buffer, so a transmitter channel leaves the buffer off, while a bridge channel turns it on (FW-3). With the buffer on, a load cell's REFP comes through 10~kΩ instead of 237~Ω, so that a cell unplugged from its running current source drives no more than 2~mA into the converter's clamp. Unbuffered, a reference pin draws about 61~µA per volt at the 8.192~MHz clock, which through 237~Ω lowers the reference by about 1.4~%; buffered, REFP draws at most ±2~µA. Both are fixed gain terms, removed by calibration (FW-2).
- The sensors draw on a 24~V supply, boosted from the +5~V rail by a #ident("TPS61170"), through an #ident("LT3092") in each channel. The #ident("LT3092") is a two-terminal current source: it holds its 10~µA set current through 30.1~kΩ across its output resistor. A permanent 301~Ω gives 1.0~mA, which excites a piezoresistive transducer. S1 adds 37.4~Ω in parallel for 9.0~mA, which excites a load cell, and S2 adds 10.2~Ω for 30~mA, the limit on a transmitter's supply. A shorted sensor or cable therefore draws no more than its channel's setting, and loses only that channel. A different feedback resistor sets the supply to 15~V where the sensors allow it, which saves power.
- An #ident("SN6505B") drives a Würth #ident("750315371") transformer. A bridge rectifier on its centre-tapped secondary gives unregulated ±5~V rails. A #ident("TPS7A39") derives the converters' ±2.5~V from them, its two outputs rising together, and a #ident("TLV704") derives 3.3~V for the converters' I/O and the bank side of the isolators. Each converter's AVDD2 is tied to the bank common, the lowest level the #ident("ADS127L11") allows on ±2.5~V supplies. That halves the modulator's supply power and keeps its current off the +2.5~V rail. An #ident("ISO7741") and a six-channel isolator carry SCLK, SDI, CS, the two select lines, the clock and START in, and data and data-ready out (@sec-gp-latch).

=== Bridge Sensors

A bridge sensor is excited by its channel's current source. The current enters the bridge at #ident("EXC+"), leaves at #ident("EXC−") and returns into the negative side of the excitation bus. Returning it to −2.048~V rather than the bank common centres the bridge on the bank common, so that its outputs lie within the input ranges of the buffers and the converter, and its top within the range of the converter's reference input. What the converter takes as its reference depends on how the sensor is specified.

#figure(
  caption: [General-Purpose Channel, Load Cell],
  gp-channel("load-cell"),
) <fig-gp-load-cell>

A load cell is specified in millivolts per volt: its output is a fixed fraction of the voltage across it. Its span compensation, resistors inside the cell in series with the excitation, holds that fraction constant over temperature. The converter's reference is therefore taken across the bridge, with REFP from #ident("EXC+") through 10~kΩ and REFN from the bus, to which S3 returns #ident("EXC−") through under 0.1~Ω. The converter then reads the cell's ratio directly (REQ-9). The ratio is a property of the bridge network, the same whether the voltage across the bridge is set by a voltage or by a current. The current's value and drift cancel, and the cell's compensation works as designed. The current is set to 9.0~mA so that REFP stays within the precharge buffer's limit for cells of up to 410~Ω, reaching 1.66~V. A 350~Ω cell then has 3.2~V across it and gives ±6.3~mV at 2~mV/V.

#figure(
  caption: [General-Purpose Channel, Piezoresistive Transducer],
  gp-channel("piezo"),
) <fig-gp-piezo>

A piezoresistive transducer such as the Keller 7L is characterised and compensated for a constant current of 1~mA. Its bridge resistance rises by 1800–3000~ppm/°C. Under constant current that rise lifts the bridge voltage and cancels most of the fall in its piezoresistive sensitivity; at a fixed voltage the span would drift by −0.12 to −0.36~% per °C. The excitation returns through a 1.00~kΩ, 5~ppm/°C current-sense resistor, and the converter's reference is taken across it, with REFP from its top. The converter then reads the output as a fraction of the current, whose tolerance and drift cancel. At 100~bar a 7L gives typically 160~mV against a 1.0~V reference, and the channel's noise of 2.9~µV~rms is about 1.8~mbar. Keller's compensation resistors for the transducer's zero, and the join of its two lower bridge pins, belong at the sensor end.

The current-sense resistor is fitted in every configuration. A load cell bypasses it through S3, and a transmitter channel, with #ident("EXC−") on the bank common, passes 2~mA through it from the bus. It also holds an unused #ident("EXC−") to the bus.

Shunt calibration places a resistor chosen for the sensor across its SIG+ to #ident("EXC−") arm, through S10. It doubles as a built-in test of each bridge channel (REQ-10). Firmware closes S10 for one channel at a time.

=== #box[4–20~mA] Transmitter

#figure(
  caption: [General-Purpose Channel, #box[4–20~mA] Transmitter],
  gp-channel("current"),
) <fig-gp-current>

- S2 sets the channel's current source to 30~mA. Below that it does not regulate, so the transmitter sets its own loop current, but it limits what a shorted transmitter or cable can draw.
- A two-wire transmitter takes its loop supply from #ident("EXC+") and returns the loop current on #ident("SIG+"). S8 connects the 100~Ω precision shunt between #ident("SIG+") and #ident("SIG−"), which turns 4–20~mA into 0.4–2.0~V. The cable links #ident("SIG−") to #ident("EXC−"), which S4 ties to the bank common, so the loop closes on the board (CBL-1). S4's few ohms lie outside the shunt's reading.
- S8 lies inside the measured span. Its 4.25~mΩ adds 0.004~% to the reading, removed by calibration, and drifts by under 0.3~ppm/°C.

=== Voltage Transmitter

#figure(
  caption: [General-Purpose Channel, Voltage Transmitter],
  gp-channel("voltage"),
) <fig-gp-voltage>

- The transmitter is supplied as in the #box[4–20~mA] configuration and returns its supply current on #ident("EXC−"), which S4 ties to the bank common.
- S9 switches a 2.49~kΩ bottom from the SIG+ buffer's input to #ident("SIG−") at the connector. The 10.0~kΩ series resistor becomes the top of a 5:1 divider for 0–10~V, which loads the transmitter with 12.5~kΩ. The SIG− buffer reads #ident("SIG−") through its own 10~kΩ, so the divider measures between the two signal contacts, and a three-wire transmitter's supply current in #ident("EXC−") stays out of the reading.
- The bottom resistor is 1206 for the 0.2~W of a 28~V fault on #ident("SIG−") while S9 is closed. The clamp at the SIG+ buffer's input then takes 9~mA.
- A transmitter with an isolated output, which would otherwise float, has #ident("SIG−") linked to #ident("EXC−") in its cable (CBL-1). A three-wire transmitter's cable carries no link: its returns already meet inside it.
- The output is unipolar. A reading below zero by more than the channel's offset therefore marks a transmitter wired in reverse.

=== Configuration Switches <sec-gp-switches>

Each switch is the simplest part that meets the voltages and currents of its position (@tab-gp-switches).

- Where both terminals stay within the ±5~V rails, a #ident("TMUX6212") channel switches.
- Where a terminal floats with the sensor supply, or sits on a contact that can see a 28~V fault, a MOSFET switches. It is placed so that it only ever has to block one polarity, and its gate is driven from the rails through a #ident("TMUX6212") channel.
- One position takes a #ident("TLP3475S") photorelay: S9, because in the #box[4–20~mA] configuration it is open with up to 2~V across it, at the SIG+ buffer's input. There its guaranteed leakage of at most 1~nA would cost 10~µV. A MOSFET's guaranteed maximum of 1~µA would cost 10~mV.

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
        ..([Switch], [Function], [Part], [Type]).map(h => table.cell(rowspan: 2, align: left + bottom, head(h))),
        table.cell(colspan: 4, head[State]),
        ..([Load cell], [Piezo-\ resistive], [4–20 mA], [Voltage]).map(h => table.cell(align: center + bottom, head(h))),
        table.hline(y: 1, start: 4, stroke: (paint: ink.rule, thickness: rule.hair)),
      ),
      table.hline(stroke: (paint: ink.rule, thickness: rule.hair)),
      [S1], [9.0~mA branch of the current source], ident("DMP3099L"), [P-MOSFET], x, o, o, o,
      [S2], [30~mA branch of the current source], ident("DMP3099L"), [P-MOSFET], o, o, x, x,
      [S3], [#ident("EXC−") straight to the bus], ident("DMN6075S"), [N-MOSFET], x, o, o, o,
      [S4], [#ident("EXC−") to the bank common], ident("BSS138W"), [N-MOSFET], o, o, x, x,
      [S5], [REFP from #ident("EXC+") through 10~kΩ], ident("BSS138W"), [N-MOSFET], x, o, o, o,
      [S6], [REFP from #ident("EXC−")], ident("TMUX6212"), [Analog\ switch], o, x, o, o,
      [S7], [REFP from the bus], ident("TMUX6212"), [Analog\ switch], o, o, x, x,
      [S8], [100~Ω current shunt], ident("IAUCN04S7L028"), [N-MOSFET], o, o, x, o,
      [S9], [2.49~kΩ divider bottom to #ident("SIG−")], ident("TLP3475S"), [Photorelay], o, o, o, x,
      [S10], [Shunt calibration], ident("TMUX6212"), [Analog\ switch], [On\ command], [On\ command], o, o,
    )
  },
) <tab-gp-switches>

- S1 and S2 sit between the #ident("LT3092")'s output and #ident("EXC+").
  - They float with the sensor, from 1~V below the bank common to 24~V above it, but have only the 0.3~V set voltage across them.
  - Each #ident("DMP3099L") has its gate pulled toward the −5~V rail by a #ident("BSS138W") through a divider. The divider gives 5.3~V of drive with a 350~Ω cell, and 6.9~V on a transmitter channel. A 16~V Zener protects the gate.
  - Their 0.1~Ω shifts the current by 0.3~% in the load-cell branch and 1~% in the transmitter branch. The bridge channels are ratiometric and do not see it.
- S3 and S4 return #ident("EXC−").
  - S3's source sits on the bus. S4's sits on #ident("EXC−"), which never rises above the bank common in normal operation. So each blocks the only polarity it sees in use. A positive fault on #ident("EXC−") reverse-biases S3 but forward-biases S4's body diode, which holds #ident("EXC−") about 0.7~V above the bank common and returns the fault current there (@sec-protection).
  - S3 is driven to 7~V. At that drive its 0.1~Ω adds 0.9~mV, a fixed 0.03~%, to a load cell's reference and drifts by 1.4~ppm/°C.
  - S4 carries a transmitter's supply return, and a #box[4–20~mA] loop through the cable link (CBL-1), outside the measured span. A 16~V Zener protects its gate.
- S5 to S7 select REFP.
  - S6 and S7 stay within the rails. S7 carries a transmitter channel's unbuffered reference current, about 250~µA. Its 7.6~Ω maximum to 85~°C lowers the reference by 0.05~%, removed by calibration, and its 0.015~Ω/°C drift adds 0.9~ppm/°C.
  - S5 must block #ident("EXC+"), up to 24~V on a transmitter channel. It is a #ident("BSS138W") with its source on the REFP side, carrying only the buffered REFP's ±2~µA.
- S8 has its source on #ident("SIG−").
  - With a 0–10~V transmitter, #ident("SIG+") never falls below #ident("SIG−"), so S8 too blocks one polarity. In the bridge configurations it has only the bridge's millivolts across it.
  - Its gate is held at #ident("EXC_N") when open, at least 1.6~V below #ident("SIG−"), so it stays off well below its threshold. When closed the gate is at +5~V.
  - A 15~V Zener protects the gate, rated ±16~V, against a 28~V fault on #ident("SIG−"). In normal operation the Zener sits under 3~V of reverse bias, where its leakage into #ident("SIG−") is typically well under 1~nA: 0.2~µV through a load cell.
- S9 is switched by a #ident("BSS138W"), which draws 5.4–8.7~mA of LED current from the +5~V rail through 620~Ω, and only in the voltage configuration.
Three logic lines per channel set the switches, 12 for the bank. They carry a code (@tab-gp-code), which logic on the channel decodes into the switches' drive. #ident("CFG1") and #ident("CFG0") select the configuration: off, load cell, piezoresistive or transmitter. #ident("OPT") chooses the variant: on a bridge it closes S10 for shunt calibration, and on a transmitter it selects a voltage output over #box[4–20~mA]. A dash marks a line that the code ignores.

#figure(
  caption: [General-Purpose Channel Configuration Code],
  datatable(
    columns: (auto, auto, auto, auto, 1fr),
    align: (center, center, center, left, left),
    header: ("CFG1", "CFG0", "OPT", "Configuration", "Closed"),
    [0], [0], [—], [Off], [None],
    [0], [1], [0], [Load cell], [S1, S3, S5],
    [0], [1], [1], [Load cell, shunt calibration], [S1, S3, S5, S10],
    [1], [0], [0], [Piezoresistive], [S6],
    [1], [0], [1], [Piezoresistive, shunt calibration], [S6, S10],
    [1], [1], [0], [#box[4–20~mA] transmitter], [S2, S4, S7, S8],
    [1], [1], [1], [Voltage transmitter], [S2, S4, S7, S9],
  ),
) <tab-gp-code>

- The lines come from the bank's configuration latch as 3.3~V logic referenced to the bank common (@sec-gp-latch). Two #ident("TMUX6212") per channel provide S6, S7 and S10, and translate the decoded signals to the ±5~V gate drive of the MOSFETs.
- Decoding makes the configurations exclusive, so no firmware fault can mix them. Two mixtures would damage the bank:
  - a load cell's S3 with a transmitter's S4 shorts the negative side of the excitation bus to the bank common, through a #ident("BSS138W") rated for 200~mA, and drives the bus buffer into its current limit;
  - a piezoresistive bridge's S6 with a transmitter's S7 and S4 shorts the positive side, with up to about 250~mA through two #ident("TMUX6212") channels rated for 160~mA at 85~°C.

  Either would take the excitation away from all four channels. For the same reason, the two current branches never close together.
- With all three lines low, the code is off and every switch is open. The latch clears its outputs when the bank powers up. Each line also has a pull-down at the channel, the #ident("TMUX6212") has internal pull-downs, and every MOSFET and LED-driver gate has its own, so an undriven line also reads off. The channel then delivers 1~mA through the base resistor, every link is open and REFP is undriven. That is safe for any sensor, and too little to start a transmitter.
- The latch commits all twelve lines on one edge, so a channel never passes through a third code on its way to the next. Firmware still moves a channel between configurations through off, 00 (FW-4). The old configuration's switches then open before the new one's close: straight from a load cell to a transmitter, S4 could close before S3 had opened and short the bus for a moment.
- The code cannot stop firmware choosing the wrong configuration for the connected sensor: the 30~mA branch would destroy a 7L, which is rated for 3~mA. Firmware therefore raises the current only after the excitation monitor has measured the sensor at 1~mA, with the channel off (FW-4, @sec-gp-monitor).
- S10 replaces the shunt-calibration switch that the stack's calibration line drove. That line's contact and isolator channel now carry #ident("GP_SEL0") (@sec-gp-latch).
- The switches and their decoding take about 3.4~cm² of board per channel once placed: two #ident("TMUX6212"), nine MOSFETs, a photorelay, four Zeners, a few logic gates and their resistors (@sec-physical).

=== Configuration Latch <sec-gp-latch>

The board has no processor. The ECU MCU board writes the configuration codes over the general-purpose SPI bus into a latch on the isolated side of the bank (REQ-4), whose twelve outputs are the code lines of the four channels.

#figure(
  caption: [General-Purpose Bank Selection],
  datatable(
    columns: (auto, auto, 1fr),
    align: (center, center, left),
    header: ("GP_SEL1", "GP_SEL0", "Addressed while the board's chip select is low"),
    [0], [0], [Converter chain],
    [0], [1], [Excitation monitor],
    [1], [0], [Latch shift register: write, and read back what it held],
    [1], [1], [Latch outputs: commit on the rising edge of the chip select],
  ),
) <tab-gp-select>

- #ident("GP_SCLK") and #ident("GP_SDI") reach every board in the stack, so the latch is reached through the board's own chip select. Two shared lines, #ident("GP_SEL0") and #ident("GP_SEL1"), steer that chip select to one of four devices (@tab-gp-select). A 2-to-4 decoder in the bank, enabled by the chip select, gives each its own select. The ECU MCU board sets the select lines before it lowers the chip select and holds them until it has raised it, so the decoder's outputs never glitch.
- The latch is a 12-bit shift register with a separate output register, each with its own clear. Firmware shifts the four codes in, then shifts them in a second time, and checks that the first copy returns on #ident("GP_SDO") through a 3-state buffer that the latch's select enables. Only then does it commit them (FW-4). A corrupted transfer is caught before it reaches a switch, and the decoders hold anything that slips through to a valid configuration.
- Both registers clear when the bank powers up, so every channel starts off. The latch then holds its code while the stack side is unpowered or the ECU MCU board restarts. The channels keep measuring, and a restarted ECU MCU board rewrites the configuration it intends, which leaves an unchanged channel undisturbed.
- The isolators' bank-side outputs default high when the stack side is unpowered. The chip select then reads inactive, so nothing is selected and nothing is committed.
- The barrier carries seven lines into the bank: #ident("GP_SCLK"), #ident("GP_SDI"), the board's chip select, #ident("GP_SEL0"), #ident("GP_SEL1"), #ident("ADC_CLK") and #ident("ADC_START"). Two come out: data and data-ready. An #ident("ISO7741"), with three forward channels and one reverse, and a six-channel isolator with four forward and two reverse carry them, with one reverse channel to spare.

== General-Purpose Error Budget <sec-gp-budget>

The budget runs from the sensor contacts to the converter output at 8~kSPS, for each configuration of @tab-channel-config. The sensor and its cable are outside it. Full scale is 6.33~mV for a 2~mV/V load cell on a 350~Ω bridge excited at 9.0~mA, 160~mV for a 100~bar Keller 7L at 1~mA, 20~mA for a #box[4–20~mA] transmitter and 10~V for a voltage transmitter. Each term is a datasheet maximum, except those marked typical, for which the datasheets give no maximum.

Calibration at test (FW-2) and shunt calibration (REQ-10) remove the offset and gain present at the calibration temperature. What remains is noise, nonlinearity and drift (@tab-gp-budget). The board's temperature range is not yet set, so drift is given per 10~°C away from the calibration temperature.

#figure(
  caption: [General-Purpose Error Budget after Calibration, % of Full Scale],
  datatable(
    columns: (1fr, auto, auto, auto, auto),
    align: (left, right, right, right, right),
    header: ("Source", "Load cell", "Piezoresistive", "4–20 mA", "Voltage"),
    table.cell(colspan: 5, caps([At the calibration temperature], size: size.tiny, tracking: track.label)),
    [Noise, rms: converter 2.58~µV, buffers, protection and bridge 1.2~µV], [0.045], [0.002], [\<~0.001], [\<~0.001],
    [Converter nonlinearity, 4~ppm of its range], [\<~0.001], [\<~0.001], [0.002], [0.002],
    table.hline(stroke: (paint: ink.rule, thickness: rule.hair)),
    table.cell(colspan: 5, caps([Drift per 10~°C], size: size.tiny, tracking: track.label)),
    [Converter offset, 0.2~µV/°C], [0.032], [0.001], [\<~0.001], [\<~0.001],
    [Converter input current through 2 × 237~Ω, 0.76~µV/°C typical], [0.120], [0.005], [\<~0.001], [\<~0.001],
    [Buffer offset, 2 × 0.015~µV/°C], [0.005], [\<~0.001], [\<~0.001], [\<~0.001],
    [Buffer bias current through 2 × 10~kΩ and the bridge, 0.61~µV/°C], [0.097], [0.004], [\<~0.001], [\<~0.001],
    [Converter gain, 1.9~ppm/°C], [0.002], [0.002], [0.002], [0.002],
    [Reference resistors and reference current], [0.010], [0.004], [0.001], [0.001],
    [Current-sense resistor, 5~ppm/°C], [—], [0.005], [—], [—],
    [#ident("REF5020"), 3~ppm/°C], [—], [—], [0.003], [0.003],
    [Excitation inverter resistors, 2 × 5~ppm/°C], [—], [—], [0.005], [0.005],
    [Shunt, 5~ppm/°C], [—], [—], [0.005], [—],
    [Divider, 2 × 5~ppm/°C], [—], [—], [—], [0.008],
    [Configuration switches: on-resistance, and leakage typical], [0.003], [0.001], [0.001], [0.003],
    table.hline(stroke: (paint: ink.rule, thickness: rule.hair)),
    [Drift, root sum square], [0.16], [0.009], [0.008], [0.010],
    [Drift, worst-case sum], [0.27], [0.022], [0.018], [0.022],
  ),
) <tab-gp-budget>

- The buffers and protection add 20~nV/√Hz to the converter's noise, mostly the thermal noise of the two 10~kΩ resistors. In the wideband filter's noise bandwidth of about 3.5~kHz that is 1.19~µV~rms, which raises the channel noise from 2.58 to 2.84~µV~rms.
- Offset drift sets the load-cell result, and a gain calibration cannot remove it. A tare before each test resets it (FW-5). Two terms make up most of it. The first is the converter's input current through the 237~Ω pair. The datasheet gives that current and its drift only as typical values, ±3~µA and 5~nA/°C at the 12.8~MHz modulator rate, scaled here to 4.096~MHz. The second is the buffers' bias current through the 10~kΩ protection: the change allowed by its 0.3~nA maximum at 25~°C and 1.5~nA at 85~°C, spread over that span. The typical bias current is 70~pA at 25~°C. For a piezoresistive transducer, whose signal is more than twenty times larger, the same terms come to about 0.01~%.
- A bridge's reference is taken at the connector. For a load cell the excitation wires therefore sit inside it: 1~Ω in each lowers a 350~Ω cell's reading by 0.57~%, and copper's 0.39~%/°C turns that into 0.02~% per 10~°C. Shunt calibration removes both at the time it is applied. A piezoresistive transducer is referenced to the current through it, which its wires cannot change, so its reading does not depend on them.
- The excitation monitor (@sec-gp-monitor) adds no term. What its dividers draw from #ident("EXC+") leaves before the sensor, and at a piezoresistive channel's #ident("EXC−") its buffer's bias current moves the current-sense resistor's share of the current by under 0.04~ppm/°C.
- The configuration switches add at most 0.003~% per 10~°C (@sec-gp-switches). On-resistance drift dominates: S3's 1.4~ppm/°C in a load cell's reference, S9's 1.9~ppm/°C in the divider's bottom and S7's 0.9~ppm/°C in a transmitter's reference. The rest is leakage: S8's gate clamp into #ident("SIG−") and the open MOSFETs at #ident("EXC−"), a few nanoamps at most when hot. These leakage figures are typical, because the datasheets guarantee a MOSFET's leakage only at its full rated voltage, where it can reach 1~µA.
- A bridge's REFP precharge buffer draws up to ±2~µA, and its drift of about 3~nA/°C at this clock sets that column's reference term. Through a load cell's 10~kΩ it is 10~ppm/°C of the 3.2~V reference; from a piezoresistive transducer's current-sense resistor it is 3~ppm/°C of the 1~mA.
- Transmitters are measured against the excitation, not ratiometrically, so their drift is that of the shunt or divider and of the excitation. The shunt, the divider and the inverter pair are 5~ppm/°C thin film, so no term exceeds 0.008~% per 10~°C. The #ident("REF5020") adds up to 70~ppm of thermal hysteresis after a temperature cycle and 22~ppm over its first 1000~hours, both removed by recalibration.
- At 20~mA the shunt dissipates 40~mW. Each 10~°C it rises above the board adds 0.005~% at 20~mA and less at lower currents, so self-heating bends the transfer curve, and a gain and offset correction does not remove it.
- Before calibration the load-cell offset can reach 0.72~mV, 11~% of full scale: the converter's ±250~µV and its input current through the 237~Ω pair, ±455~µV typical. The bridge gains are about 2~% high by design, from the reference currents through the resistors in the reference path, with up to ±0.2~% of converter gain error on top.

== Excitation Monitor <sec-gp-monitor>

Each channel's converter reads its sensor against a reference taken from the excitation, so the excitation drops out of its result. That is what makes the channels ratiometric, but it also hides the excitation from them. An #ident("ADS131M08") shared by the four channels measures it directly. Each channel has two of its eight inputs, both read against the negative side of the bus: an excitation input from #ident("EXC+") and a return input from #ident("EXC−") (@tab-gp-monitor, @fig-gp-monitor).

#figure(
  caption: [Excitation Monitor Inputs],
  datatable(
    columns: (auto, 1fr, 1fr, 1fr, 1fr),
    align: (left, left, left, left, left),
    header: ("Input", "Load cell", "Piezoresistive", "4–20 mA", "Voltage"),
    [Excitation, from #ident("EXC+"), ÷25],
    [Bridge voltage, 3.2~V],
    [Bridge and current-sense voltages, 4.5~V],
    [Loop supply + 2.048~V],
    [Supply + 2.048~V],
    [Return, from #ident("EXC−"), ÷2],
    [Zero: #ident("EXC−") is on the bus],
    [Sense voltage, 1.0~V],
    [Zero: #ident("EXC−") is held to the bus],
    [Bus, 2.048~V: #ident("EXC−") is on the bank common],
  ),
) <tab-gp-monitor>

#figure(
  caption: [Excitation Monitor],
  gp-monitor(),
) <fig-gp-monitor>

The readings serve three purposes.

- The temperature of a piezoresistive transducer. Its excitation reading less its return reading is the bridge voltage, and the ratio of that to the return reading is the ratio of the bridge resistance to the 1.00~kΩ current-sense resistor. The bridge resistance rises with temperature by 1800–3000~ppm/°C, so the ratio gives the transducer's temperature. Keller specifies the 7L's span to within 0.06~%/°C and its compensated zero to within 0.025~% of full scale per °C. The measured temperature lets firmware correct what remains, given the transducer's characterisation. Known to a third of a degree, it holds that correction's own error near 0.02~% of full scale, which requires the ratio to stay within about 600~ppm for each 10~°C of board temperature.
- The supply of a transmitter. The excitation reading gives it against the bus, which shows a supply sagging under load or a loop held at its 30~mA limit.
- Faults in every configuration. An open or unplugged bridge lets its current source drive #ident("EXC+") up to the sensor supply, and a shorted bridge or cable collapses the bridge voltage. A damaged cable shows as a change of a few per cent in the bridge voltage. These need only about 1~%.

The converter and its inputs:

- It samples its eight inputs at the same instant against one reference, so the ratio of a channel's two readings does not depend on that reference. The reference is the positive side of the bus, divided to 1.25~V, so every reading is also a ratio to the bus.
- It runs from #ident("ADC_CLK") and is resynchronised by #ident("ADC_START"), as the converter of the #ident("E004-TC-BOARD") is (INT-7). At an oversampling ratio of 16384 it gives 250~SPS with 1.9~µV~rms of noise. It is the eight-channel member of the #ident("ADS131M06") family, with the same commands, registers and frame format, so one firmware driver serves both boards. It draws 7.2~mA from the bank's 3.3~V.
- Dividers to the bank common bring every node into its input range, from 1.3~V below the bank common to 3.3~V, with ±1.2~V full scale. They divide by 25 on the excitation inputs, which see 26~V when an open sensor lets its current source rise to the supply, and by 2 on the return inputs. The negative side of the bus feeds one shared divider for each kind of input. 10~nF across each pair, with the dividers' source resistance, filters the converter's input. What the excitation dividers draw from #ident("EXC+") leaves before the sensor, so a bridge's reading, a ratio to the voltage across it or the current through it, is unchanged.
- A piezoresistive transducer's #ident("EXC−") lies between its bridge and its current-sense resistor. Current drawn there would pass through one and not the other, a gain error in the channel's own reading. Each #ident("EXC−") is therefore buffered by one section of an #ident("OPA4189") before its divider, through 10~kΩ that limits a fault's current into the amplifier's input. Its input bias current, at most 2~nA to 85~°C, is 2~ppm of the excitation current. Through the 10~kΩ it adds at most 20~µV, and with the amplifier's 5~µV of offset that is 25~ppm of the current-sense voltage. An unused #ident("EXC−"), as on a channel with nothing connected, is held to the negative bus by the 1.00~kΩ current-sense resistor, which is fitted in every configuration.
- The converter's own errors are small beside its readings: offset drift 215~nV/°C, nonlinearity 7.5~ppm of its range, and gain drift 5~ppm/°C typical. Calibration at test removes its offset, and no zeroing is needed in use.
- The dividers set the stability. For a piezoresistive channel they are 5~ppm/°C thin film. With the converter's gain drift they move the resistance ratio by about 250~ppm per 10~°C root sum square, or 450~ppm worst case, within the 600~ppm. The return dividers contribute most, because the 1.0~V they measure sits 1 to 2~V below the bank common. Where the monitor only diagnoses, 0.1~%, 25~ppm/°C parts suffice.
- Its data output, like that of the #ident("ADS127L11") chain, is high-impedance while its chip select is high. The two therefore share the bank's data-return channel, as well as SCLK and SDI. Its data-ready is not carried: it converts at a fixed rate from the stack clock, so its reads can be scheduled. Each frame is ten 24-bit words every 4~ms, 60~kbit/s per board.
- It takes its own select from the bank's select decoder, addressed by the board's chip select with #ident("GP_SEL0") high (@tab-gp-select).

== Input Protection <sec-protection>

Every sensor contact leaves the board through the engine harness. There it can meet a fault from another circuit, a discharge during handling, and transients coupled from the igniter and valves. The board must survive all three (REQ-14).

- Each of the 16 sensor contacts has a bidirectional suppressor to the bank common, at the connector pin. Its breakdown lies above 28~V, so neither the 24~V sensor supply nor a 28~V fault makes it conduct, and the fault is left to the parts behind it. It must be bidirectional: #ident("EXC−") and the signal contacts sit up to 2~V below the bank common in use, where a unidirectional part would conduct.
- Its clamping voltage at the test currents must stay below 40~V, the drain rating of S8, the lowest-rated part on a contact. A flat-clamp suppressor holds that; an avalanche diode of the same breakdown rises well above it. The other parts on the contacts are rated higher: S4 50~V, and S3 and the photorelay 60~V. S1, S2 and S5 sit behind series resistors.
- On #ident("EXC−") the body diodes of S3 and S4 conduct before the suppressor does, S4's to the bank common and S3's to the bus. They hold #ident("EXC−") within about 0.7~V of those, so the current-sense resistor and the switch terminals on #ident("EXC−"), S6's and S10's, never see more than a few volts. The two MOSFETs then carry part of a discharge, and are to be tested at the REQ-14 levels on the first boards. A few ohms in series with S4, which carries only a transmitter's supply return, would relieve it if needed.
- A suppressor returns a discharge to the bank common, which must hand it to the engine without crossing the isolation barrier. A capacitor across the engine-tie resistor does that (OI-3).
- At the few volts a measured contact sees in use, a suppressor leaks far less than its rating at stand-off: a part rated 1~µA at 30~V is expected to leak under 10~nA at 2.5~V. On #ident("EXC+") the leakage leaves before both the bridge and the current-sense resistor, so no reading changes. On #ident("EXC−") it is a ratio error in a piezoresistive channel, 1~ppm per nanoamp. On #ident("SIG+") and #ident("SIG−") the two suppressors sit at nearly the same voltage, so their leakage largely cancels. The difference flows through the bridge's output resistance: 0.18~µV, 0.003~% of full scale, per nanoamp for a 350~Ω load cell. The part chosen must hold that difference near a nanoamp, to be measured on the first boards.
- Surge to IEC~61000-4-5 is not required. The harness is taken to be shorter than 30~m, with no connection to mains or to lines exposed to lightning. A surge rating would call for suppressors several times the size.

#figure(
  caption: [Behaviour under a 28~V Fault],
  datatable(
    columns: (auto, auto, 1fr),
    align: (left, left, left),
    header: ("Contact", "In use", "A 28 V fault"),
    ident("EXC+"), [−1 to 24~V], [Lifts the #ident("LT3092")'s output above its input, which it blocks: under 1~mA flows back. S5 sits behind 10~kΩ and the monitor behind 240~kΩ.],
    ident("EXC−"), [−2.05 to 0~V], [Flows into the bus through S3 where it is closed, and otherwise to the bank common through S4's body diode, 0.7~V above it. The current-sense resistor then carries at most 2.8~mA.],
    [#ident("SIG+"), #ident("SIG−")], [±2~V; #ident("SIG+") to 10~V for a voltage transmitter], [Reaches the buffers through 10~kΩ: 2.3~mA into their clamps. S8 blocks it while open, rated 40~V, and S9, rated 60~V. Where the configuration closes them it flows through the shunt or the divider to the bank common.],
  ),
) <tab-protection>

Most of these paths survive a fault from any source. Three are low-impedance by design: S3 into the bus in the load-cell configuration, S4's body diode, and the shunt with S8 in the #box[4–20~mA] configuration, which returns through the cable link and S4. They survive a current-limited fault indefinitely, such as another channel's sensor supply at 30~mA: S4's diode then dissipates 21~mW and the shunt 90~mW. A low-impedance source such as a valve supply would destroy S4 or the shunt, or, through S3, hold the bus at its buffer's current limit of about 375~mA and take the excitation from the whole bank while it lasts (OI-5).

== Stacking <sec-stacking>

Boards stack on #ident("ASRP-PCB-INTERCONNECT-2") together with the #ident("E004-TC-BOARD"). ADC boards share the general-purpose SPI bus to the ECU MCU board, and the thermocouple bus passes through them unused (@tab-interconnect-signals).

- The bus has one chip select and one data-ready line per board slot. A 2 × 6 header on each board picks its slot with two shunts, one per line, so every board is built the same. A 10~kΩ pull-up holds the chip select of an unjumpered board inactive.
- Two shared lines, #ident("GP_SEL0") and #ident("GP_SEL1"), choose which device of a board's general-purpose bank its chip select addresses: the converter chain, the excitation monitor or the configuration latch (@sec-gp-latch).
- A board drives the shared data line only while it is selected, through an #ident("SN74LVC2G125") 3-state buffer with 62~Ω series termination (INT-4). It drives its own data-ready line all the time, through the same buffer. Its partial-power-down protection keeps an unpowered board off every line.
- The ECU MCU board supplies the 8.192~MHz converter clock and START to every board, so all boards, of both kinds, sample in step (REQ-6, INT-6). Every board already depends on the ECU MCU board, so this adds no new single point of failure.
- Each board takes every line into its isolators through 1~kΩ. A board whose input fails short, or whose 3.3~V input switch has opened, then loads the line with 3.3~mA at most, and the other boards keep their clock and data. On #ident("ADC_CLK") the resistor adds about 5~ns to the edges, against a 122~ns clock period.
- Every data-ready line is visible to the ECU MCU board at all times, so any board can trigger a read. All boards signal together and are read in one burst.
- Data-ready falls a fixed number of #ident("ADC_CLK") cycles after START. Firmware can therefore schedule reads from a timer counting #ident("ADC_CLK") and use the data-ready lines to confirm that every board kept pace (FW-1).
- The isolators add at most 17~ns each way and the bus buffer 4.3~ns, so data returns within about 70~ns of the clock edge. The bus runs at 5~MHz.
- Each board puts 128 bits on the bus every 125~µs. Three boards load it to about 65~%, which gives 12 general-purpose channels.
- A #ident("TPS2553") current-limited switch on each of the board's 5~V and 3.3~V inputs, set to 1~A and 0.15~A, holds a board that fails short off the stack rails.
- Redundant sensors for a critical measurement belong on different boards, so that no single board fault takes out both.

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
      [4 × #ident("ADS127L11")],
      [One per channel, simultaneous from a shared clock, daisy-chained on SPI. Wideband filter flat to 0.4 of the data rate with 106~dB stop band. 2.58~µV~rms at 8~kSPS. Offset drift 50~nV/°C, gain drift 0.6~ppm/°C typical.],
      [Input buffers],
      [4 × #ident("OPA2189")],
      [Zero-drift, 5.2~nV/√Hz, input bias 300~pA maximum, offset drift 0.006~µV/°C typical.],
      [Excitation monitor],
      ident("ADS131M08"),
      [Eight simultaneous channels, two per general-purpose channel. External reference 1.1–1.3~V. Inputs to 1.3~V below ground, 330~kΩ at unity gain. Nonlinearity 7.5~ppm of range, offset drift 215~nV/°C, gain drift 5~ppm/°C typical. 1.9~µV~rms at 250~SPS. Same commands and frame as the #ident("ADS131M06"). 21.5~mW.],
      [Monitor buffers],
      ident("OPA4189"),
      [Quad of the input buffers' family. 4.5 to 36~V supply, so it runs from the unregulated ±5~V rails. Inputs to 0.1~V below its negative rail, offset 5~µV, input bias 2~nA maximum to 85~°C. 1.3~mA per amplifier, about 55~mW for the four. 5 × 4.4~mm TSSOP.],
      [Excitation reference],
      ident("REF5020"),
      [2.048~V, 3~ppm/°C maximum (high grade).],
      [Excitation drivers],
      [#ident("OPA2189"), 2 × #ident("BUF634A")],
      [Precision amplifier with a 250~mA buffer in its loop, one per polarity. ±2.25 to ±18~V supply, internal current limit, thermal shutdown.],
      [Precision resistors],
      [Vishay TNPU e3],
      [Thin film, 0.05~%, 5~ppm/°C: the #box[4–20~mA] shunt, the 10.0~kΩ SIG+ series resistor and the excitation inverter pair in 0805, and the 2.49~kΩ divider bottom and the 1.00~kΩ current-sense resistor in 1206. Also the excitation monitor's reference and bus dividers, and its dividers for a piezoresistive channel.],
      [General-purpose isolated supply],
      [#ident("SN6505B"), #ident("750315371")],
      [1~A push-pull driver at 420~kHz. Würth 1:1.1 centre-tapped transformer, 2500~V~rms, 1~A rated at 5~V. Four 30~V 1~A Schottky diodes (TBD) as the bridge for ±5~V.],
      [General-purpose regulators],
      [#ident("TPS7A39"), #ident("TLV704")],
      [Dual positive and negative LDO for ±2.5~V: 150~mA each, ±3.3 to ±33~V in, outputs track at start-up, 21~µV~rms. 150~mA LDO for 3.3~V, 2.5 to 24~V in. Both tolerate the rectified rails at light load. Loads about 22 and 37~mA on ±2.5~V, 32~mA on 3.3~V.],
      [Sensor supply],
      [#ident("TPS61170")],
      [Boost from +5~V to 24~V. 1.2~A switch, 38~V output maximum, 1.2~MHz, 2 × 2~mm QFN. 10~µH inductor and 40~V Schottky (TBD).],
      [Sensor current sources],
      [4 × #ident("LT3092")],
      [2-terminal current source, 0.5 to 200~mA, 1.2 to 40~V, thermal limit, set by its output resistor, which S1 and S2 switch: 1.0~mA for a piezoresistive transducer, 9.0~mA for a load cell, 30~mA for a transmitter. 3 × 3~mm DFN.],
      [General-purpose isolation],
      [#ident("ISO7741"), six-channel isolator (TBD)],
      [Three forward and one reverse channel, 17~ns maximum delay, 4.9 × 6~mm QSOP. Four forward and two reverse channels, bank-side outputs high by default (@sec-gp-latch).],
      [Configuration logic],
      [TBD],
      [12-bit shift register with a separate output register and a clear for each, 2-to-4 select decoder with enable, 3-state read-back buffer, and the four channels' code decoders (@sec-gp-latch, @sec-gp-switches).],
      [Input clamps],
      [BAV199 class (TBD)],
      [Low-leakage series pair to the bank rails, one per input.],
      [Contact suppressors],
      [16 × TBD],
      [Bidirectional flat-clamp, breakdown above 28~V, clamping below 40~V at the REQ-14 test currents, low leakage at a few volts. One per sensor contact, the same part as on the #ident("E004-TC-BOARD") (@sec-protection).],
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
      [4 × #ident("IAUCN04S7L028")],
      [N-channel, 40~V, ±16~V gate, logic level. 4.25~mΩ at 4.5~V. S8. 3.3 × 3.3~mm TDSON.],
      [Small-signal switches and drivers],
      [20 × #ident("BSS138W")],
      [N-channel, 50~V, ±20~V gate. 3.5~Ω at 10~V, leakage 0.5~µA maximum at 50~V. S4 and S5, the current-branch gate drivers and the photorelay LED driver. SOT-323.],
      [Photorelays],
      [4 × #ident("TLP3475S")],
      [60~V, 0.4~A, 1.5~Ω. Off-state leakage 1~nA maximum at 50~V, 25~°C. 500~V~rms input to output. S9. 2.0 × 1.45~mm.],
      [Gate clamps],
      [#ident("MMSZ5246B"), #ident("MMSZ5245B")],
      [Zener, 16~V for S1, S2 and S4, and 15~V for S8, whose gate is rated ±16~V. Leakage 0.1~µA maximum at 12 and 11~V. SOD-123.],
      [Bus buffers],
      [#ident("SN74LVC2G125")],
      [Dual 3-state buffer, 4.3~ns maximum at 3.3~V, partial-power-down protection. Data and data-ready.],
      [Input resistors],
      [1~kΩ],
      [In series with every line into the isolators, #ident("ADC_CLK") included.],
      [Slot select],
      [2 × 6 header (TBD)],
      [2~mm pitch, Harwin M22 family. Two shunts pick the slot.],
      [Sensor connector],
      ident("M80-5001842"),
      [Harwin Datamate J-Tek, 18-way, 2~mm pitch, vertical through-hole, M2 jackscrews, −55 to 125~°C. 800~V working between contacts. Part number to be confirmed.],
      [Stack connector],
      [TBD],
      [#ident("ASRP-PCB-INTERCONNECT-2"), 32-way, pass-through (INT-1, INT-3, INT-5).],
      [Input current limits],
      [2 × #ident("TPS2553")],
      [Current-limited switch, 2.5 to 6.5~V, limit set from 75~mA to 1.7~A. 1~A on 5~V, 0.15~A on 3.3~V.],
    ),
  ) <tab-components>
]


= Physical Implementation <sec-physical>

The schematic is drawn (Appendix A). No board has been, so these estimates set the budget for REV A.

#params(
  cols: 4,
  ("Board", raw("e003-adc-board")),
  ("Revision", [—]),
  ("Board Area", [60 × 60~mm, 72~cm² on two sides]),
  ("Stack-up", [TBD]),
  ("Placement Area", [41~cm²]),
  ("Sensor Connector", [#ident("M80-5001842")]),
  ("Stack Connector", [TBD, 32-way]),
  ("Input Power", [1.0 to 3.8~W, estimated]),
)

The estimate sums the parts' courtyards and allows 1.6 times that for placement, which leaves about 40~% of the area under the parts for vias, routing and test access. The outline gives 72~cm² over its two sides (REQ-2). The connectors, the four M3 mounting holes, a 3~mm gap at the isolation barrier and the board edge take part of each side, and the parts must fit in what remains (@tab-area).

#figure(
  caption: [Board Area Estimate],
  datatable(
    columns: (1fr, auto),
    align: (left, right),
    header: ("Item", "Area"),
    [Four general-purpose channels], [25.6~cm²],
    [Excitation bus and monitor], [5.6~cm²],
    [General-purpose supplies], [5.3~cm²],
    [Isolation and configuration latch], [2.6~cm²],
    [Stack side], [1.7~cm²],
    table.hline(stroke: (paint: ink.rule, thickness: rule.hair)),
    [Parts, placed], [41~cm²],
    [Connectors, holes, isolation gap and edge, both sides], [18~cm²],
    [Left for parts, both sides], [54~cm²],
    [Use of what is left], [75~%],
  ),
) <tab-area>

The board is about three quarters full, which leaves room for the parts not yet chosen and for layout. Between placement allowances of 1.4 and 1.8 the use runs from 66 to 85~%. With the thermocouple bank as well, the parts needed all the area there was, which is why that bank moved to the #ident("E004-TC-BOARD").

Input power is about 1.0~W per board, plus about 0.7~W for each channel set up for a transmitter, so 1.0 to 3.8~W.

- The isolated bank and the stack side are kept apart on every layer, with the isolators and the isolated supply straddling the gap.

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
    [Three ADC boards draw 0.54~A at 5~V without transmitters and 2.2~A with a transmitter on every general-purpose channel, and three #ident("E004-TC-BOARD") a further 0.12~A (INT-2), against 2~A for the whole ECU stack. Not resolved in this revision. The number of transmitter channels in a stack is held to what the rail can spare. Bridge sensors now take their excitation from the sensor supply instead of the ±5~V rails: about 0.31~W per load-cell channel from the 5~V input with the supply at 24~V, or 0.22~W at 15~V, against 0.13~W before. INT-2 and the input-power estimate are to be revised with the power budget.],

    ident("OI-2"),
    [Parts without a library record],
    [The schematic carries placeholders, marked \*, for the sensor and stack connectors, the transformer, the bridge and boost diodes, the boost inductor, the input clamps, the converters' 330~pF common-mode capacitors, the slot header and the precision and odd-value resistors. The 18-way connector's part number is to be confirmed. Each names its required value and rating. Every IC footprint is TODO in the library.],

    ident("OI-3"),
    [Engine-tie resistance],
    [The bank ties to the engine through a resistor behind its shield jumper, with a capacitor across it that returns transient current to the engine (@sec-protection). Both values depend on the engine grounding scheme and are TBD.],

    ident("OI-4"),
    [Configuration logic, isolator and suppressors not chosen],
    [The latch, its select decoder and read-back buffer, the channels' code decoders, the six-channel isolator and the 16 contact suppressors are specified by function (@sec-gp-latch, @sec-protection) but not chosen. The suppressor is to be the same part as on the #ident("E004-TC-BOARD"). The suppressor needs a breakdown above 28~V, a clamp below 40~V and low leakage at a few volts. None in the library qualifies: those it holds are unidirectional or rated below 28~V.],

    ident("OI-5"),
    [Low-impedance faults on the excitation and current-loop paths],
    [A low-impedance 28~V source on #ident("EXC−"), or on #ident("SIG+") in the #box[4–20~mA] configuration, can destroy S4 or the shunt, or hold the bank's bus at its current limit (@tab-protection). Acceptable if no such source in the harness can reach these contacts. Otherwise those paths need a fuse or current limit, which on #ident("EXC−") costs precision.],
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
