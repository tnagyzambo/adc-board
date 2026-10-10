#import "@local/eng-report:0.6.0": *

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
    The ADC board is the analog data acquisition board of the ASRP ECU stack. Each board provides four general-purpose channels with a 2~kHz bandwidth, sampled simultaneously and configurable for load cells, #box[4–20~mA] transmitters and voltage transmitters, and four thermocouple channels with a 200~Hz bandwidth and their own cold-junction sensor. Each channel bank is isolated from the stack. Boards stack to scale the channel count. They connect to the ECU MCU board over a dedicated stacking interconnect, which brings them power from the power board and carries their data for logging. This draft sets out the requirements and architecture for REV A of the ADC board.
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

The #ident("E003-ADC-BOARD") is the analog data acquisition board of the ECU stack for the Advanced Small Rocket Project (ASRP). Each board carries four general-purpose channels, configurable for load cells, #box[4–20~mA] transmitters or voltage transmitters, and four thermocouple channels with their cold-junction compensation (CJC) sensor. Boards stack to reach the channel count a vehicle needs. The measurements are flight-critical, so the design confines the effect of any fault to as few channels as possible.

The boards connect to the ECU MCU board over #ident("ASRP-PCB-INTERCONNECT-2"), a stacking interconnect defined in this document (@sec-interfaces). It carries their data and the 5~V and 3.3~V rails of the #ident("E001-POWER-BOARD"), passed on by the ECU MCU board. The ECU MCU board configures and reads the converters and logs the data to eMMC.

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
    [Device must allow each general-purpose channel to be configured by component placement and jumpers for a full-bridge load cell, a #box[4–20~mA] transmitter or a voltage transmitter],
    [Local],
    [REQ-9],
    [Device must excite the load cells and measure them ratiometrically],
    [Local],
    [REQ-10],
    [Device should provide shunt calibration on each load-cell channel],
    [Local],
    [REQ-11],
    [Device must provide four thermocouple channels, each with a measurement bandwidth of 200~Hz],
    [Local],
    [REQ-12],
    [Device must measure the cold-junction temperature at its own thermocouple contacts],
    [Local],
    [REQ-13],
    [Device should galvanically isolate the general-purpose and thermocouple channels from the stack and from each other],
    [Local],
    [REQ-14],
    [Device must carry its channels, front ends, sensor connector and cold-junction sensor on a single board],
    [Local],
    [REQ-15],
    [Device must stack with further boards of the same design to increase the channel count],
    [Local],
  ),
)

= System Description

== Architecture

Each board carries four general-purpose channels and four thermocouple channels with their cold-junction sensor (@fig-arch). Everything for a channel lives on the board: connector, front end, converter and isolation (REQ-14). The board connects to the ECU MCU board and to further ADC boards over #ident("ASRP-PCB-INTERCONNECT-2"), which carries its power and data (@sec-interfaces).

#figure(
  caption: [Board Architecture],
  {
    let w = 3.6cm
    let h = 0.9cm
    let lane = 6pt // offset of a data and a power edge either side of a column's centre line
    let blk(pos, body, name, ..args) = node(pos, body, width: w, height: h, name: name, ..args)
    // A blank node holding one end of a box drawn round several columns: a
    // node centred on a column puts all of its width into that column.
    let end(pos, name) = node(pos, none, width: w, height: h, stroke: none, fill: none, name: name)
    // A data edge and a power edge side by side in column `col`, between a
    // node in row `top` and the node below it in row `bottom`.  Power flows up.
    let pair(col, top, bottom, upper, lower, data: none, power: none) = (
      edge(
        (rel: (-lane, 0pt), to: (col, bottom)),
        (rel: (-lane, 0pt), to: (col, top)),
        "<|-|>",
        data,
        label-side: left,
        snap-to: (lower, upper),
        ..wire.signal,
      ),
      edge(
        (rel: (lane, 0pt), to: (col, bottom)),
        (rel: (lane, 0pt), to: (col, top)),
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
        blk((0, 0), [Load cells,\ transmitters ×4], <gp-sens>, shape: shape.io),
        blk((1, 0), [Thermocouples ×4], <tc-sens>, shape: shape.io),
        blk((0, 1), [General-purpose\ bank, 4 channels], <gp>),
        blk((1, 1), [Thermocouple bank,\ 4 channels, CJC], <tc>),
        blk((0, 2), [Isolation barrier:\ data, supply], <gp-iso>),
        blk((1, 2), [Isolation barrier:\ data, supply], <tc-iso>),
        end((0, 3), <l0>),
        end((1, 3), <l2>),
        node(
          enclose: (<l0>, <l2>),
          [Stack side: slot select, bus buffers,\ current limits],
          inset: 0pt,
          name: <logic>,
        ),
        end((0, 4), <s0>),
        end((1, 4), <s2>),
        node(enclose: (<s0>, <s2>), [ASRP-PCB-INTERCONNECT-2], inset: 0pt, shape: shape.io, name: <stack>),

        edge(<gp-sens>, <gp>, "-|>"),
        edge(<tc-sens>, <tc>, "-|>"),
        ..pair(0, 1, 2, <gp>, <gp-iso>),
        ..pair(1, 1, 2, <tc>, <tc-iso>),
        ..pair(0, 2, 3, <gp-iso>, <logic>, data: [Data], power: [5~V]),
        ..pair(1, 2, 3, <tc-iso>, <logic>, data: [Data], power: [5~V]),
        ..pair(0.5, 3, 4, <logic>, <stack>, data: [2 × SPI, slot lines,\ clock, start, cal], power: [5~V, 3.3~V]),

        zone(<gp-sens>, <tc-sens>, label: [Engine]),
        zone(<gp>, <tc>, <logic>, label: [This board]),
      ),
    )
  },
) <fig-arch>

- The two channel banks are separate isolated domains, isolated from the stack and from each other (REQ-13). A sensor fault therefore costs at most the four channels of one bank.
- Each bank has its own isolated supply and data isolators. The stack side drives the shared buses and limits the current the board can draw from the 5~V and 3.3~V rails.
- Every input has series protection and clamps rated for the highest voltage in the engine harness. A foreign voltage on one input stops at its channel.
- Each bank is tied to the engine at one point, through a resistor. A fault then moves the potential of the bank instead of driving current through its ground.
- Boards stack to add channels, sharing two SPI buses to the ECU MCU board (@sec-stacking).
- In the diagrams, heavy lines carry power and dashed lines carry digital data.

== Operations Concept

TBD

== Interfaces <sec-interfaces>

The board has two external interfaces (@tab-interfaces): #ident("ASRP-PCB-INTERCONNECT-2") to the ECU MCU board and further ADC boards, and a single sensor connector.

#figure(
  caption: [External Interfaces and Signals],
  datatable(
    columns: (auto, auto, 1fr),
    align: (left, left, left),
    header: ("Interface", "Part", "Signals"),
    ident("ASRP-PCB-INTERCONNECT-2"),
    [TBD, 32-way],
    [5V ×2, 3V3 ×2, GND ×7, two SPI buses with three chip selects and three data-ready lines each, ADC_CLK, ADC_START, SHUNT_CAL],
    [Sensor connector],
    [#ident("M80-5002842"), 28-way],
    [EXC±, SIG± for four general-purpose channels, TC± for four thermocouples, two shield pairs],
  ),
) <tab-interfaces>

The ADC boards do not use #ident("ASRP-PCB-INTERCONNECT-1"). #ident("ASRP-PCB-INTERCONNECT-2"), defined here, is a stacking bus: the ECU MCU board at one end and up to three ADC boards stacked on it, each passing every contact through to the next. It carries the two SPI buses with a chip select and data-ready line per slot, the converter clock and START, shunt calibration and the 5~V and 3.3~V rails (@tab-interconnect-pinout, @tab-interconnect-signals).

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
    [9], ident("ADC_START"), [10], ident("SHUNT_CAL"),
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
    [31], ident("GND"), [32], ident("GND"),
  ),
) <tab-interconnect-pinout>

#figure(
  caption: [#ident("ASRP-PCB-INTERCONNECT-2") Signals],
  datatable(
    columns: (auto, auto, auto, auto, 1fr),
    align: (left, center, left, left, left),
    header: ("Signal", "Pins", "Direction", "Boards", "Use"),
    ident("5V"), [2], [From MCU], [All], [5~V rail from #ident("E001-POWER-BOARD"). Supplies the isolated domains through each board's current limit.],
    ident("3V3"), [2], [From MCU], [All], [3.3~V rail from #ident("E001-POWER-BOARD"). Supplies the stack side of the barriers.],
    ident("GND"), [7], [—], [All], [Power return and signal reference.],
    ident("ADC_CLK"), [1], [From MCU], [All], [Converter clock, 8.192~MHz.],
    ident("ADC_START"), [1], [From MCU], [All], [Idles high. A short low pulse starts conversion on every board (INT-7).],
    ident("SHUNT_CAL"), [1], [From MCU], [All], [Switches in the shunt-calibration resistors.],
    ident("GP_SCLK"), [1], [From MCU], [All], [SPI clock, 5~MHz.],
    ident("GP_SDI"), [1], [From MCU], [All], [SPI data into the converter chain of the selected board.],
    ident("GP_SDO"), [1], [To MCU], [Selected], [SPI data out of the converter chain.],
    ident("GP_DRDY0…2"), [3], [To MCU], [One per slot], [Data ready from one board's general-purpose bank, 8~kHz, driven continuously.],
    ident("GP_CS0…2"), [3], [From MCU], [One per slot], [Selects the general-purpose bank of one board.],
    ident("TC_SCLK"), [1], [From MCU], [All], [SPI clock, 5~MHz.],
    ident("TC_SDI"), [1], [From MCU], [All], [SPI data into the converter of the selected board.],
    ident("TC_SDO"), [1], [To MCU], [Selected], [SPI data: conversion results and register read-back.],
    ident("TC_DRDY0…2"), [3], [To MCU], [One per slot], [Data ready from one board's thermocouple bank, 4~kHz, driven continuously.],
    ident("TC_CS0…2"), [3], [From MCU], [One per slot], [Selects the thermocouple bank of one board.],
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
  [The ECU MCU board shall supply #ident("ASRP-PCB-INTERCONNECT-2") with 5~V and 3.3~V, taken from the rails of #ident("ASRP-PCB-INTERCONNECT-1"). Each ADC board draws up to 0.22~A at 5~V, plus 0.14~A for each general-purpose channel set up for a transmitter, and up to 0.04~A at 3.3~V.],
  note: [The 5~V rail of the #ident("E001-POWER-BOARD") is rated 2~A for the whole ECU stack. Three boards without transmitters take 0.7~A of it. Three boards with a transmitter on every channel would take 2.3~A, so the number of transmitter channels in a stack is limited by that rail (OI-1, @tab-open-issues).],
)

#requirement(
  "INT-3",
  [Each contact shall be rated for at least 2~A. Each power rail and its return shall be carried on at least two contacts.],
  note: [One contact then carries the full 2~A of the #ident("E001-POWER-BOARD") 5~V rail, so a single open contact leaves every board powered.],
)

#requirement(
  "INT-4",
  [Signals shall be 3.3~V LVCMOS referenced to #ident("GND") and series-terminated at their driver. An ADC board shall drive #ident("GP_SDO") and #ident("TC_SDO") only while selected, shall drive the data-ready lines of its own slot continuously, and shall leave every line at high impedance when unpowered.],
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
  note: [#ident("ADC_START") drives the #ident("ADS131M06") SYNC/RESET input, which resets the converter when held low for longer. The #ident("ADS127L11") restarts on the rising edge in its synchronized control mode (FW-5).],
)

The sensors connect through a single Harwin Datamate #ident("M80-5002842"), which carries all eight channels and their shields (@tab-sensor-pinout). The general-purpose channels take four contacts each and the thermocouples two. The connector is rated 800~V working between adjacent contacts, far above any voltage in the engine harness, so the two isolated banks sit side by side. Their shield contacts meet at the boundary, so a strand, bent contact or debris bridging the banks can only join one shield to another, never a signal to the other bank.

#figure(
  caption: [Sensor Connector #ident("M80-5002842") Pinout],
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
    [19], ident("TC_SHLD"), [20], ident("TC_SHLD"),
    [21], ident("TC1+"), [22], ident("TC1−"),
    [23], ident("TC2+"), [24], ident("TC2−"),
    [25], ident("TC3+"), [26], ident("TC3−"),
    [27], ident("TC4+"), [28], ident("TC4−"),
  ),
) <tab-sensor-pinout>

#figure(
  caption: [General-Purpose Contact Use by Configuration],
  datatable(
    columns: (auto, 1fr, 1fr, 1fr),
    align: (left, left, left, left),
    header: ("Contact", "Load cell", "4–20 mA transmitter", "Voltage transmitter"),
    ident("EXC+"), [Excitation +], [Loop supply, 24~V], [Transmitter supply, 24~V],
    ident("EXC−"), [Excitation −], [Not used], [Supply return],
    ident("SIG+"), [Signal +], [Loop current in], [Signal],
    ident("SIG−"), [Signal −], [Loop current out], [Signal return],
  ),
) <tab-sensor-config>

- The four contacts of a channel take their function from the components placed for its configuration (@tab-channel-config). In the transmitter configurations, #ident("SIG−") is tied to the bank common, and so is #ident("EXC−") where it is used as a supply return.
- Each pair of a channel sits in the same column of the connector, so the wires of a twisted pair land side by side.
- Thermocouple extension wire is crimped directly into the gold-plated contacts. The cold-junction RTD sits on the board beside pins 21 to 28, so the cold-junction temperature is measured where the thermocouple metals end.
- #ident("GP_SHLD") and #ident("TC_SHLD") take the cable shields. A jumper ties each to its bank common, or leaves it open where the shield is terminated at the engine.

== Firmware Requirements

These requirements apply to the firmware on the ECU MCU board that reads this board.

#requirement(
  "FW-1",
  [Each thermocouple channel shall be filtered by a linear-phase low-pass filter that passes 0–200~Hz, attenuates 500~Hz and above by at least 80~dB and corrects the droop of the converter and input filter, and shall then be decimated to the logging rate.],
  note: [The logging rate is 1~kSPS. The filter then needs only a few tens of taps per channel.],
)

#requirement(
  "FW-2",
  [Firmware shall flag a bank whose data-ready does not arrive within one conversion period of its expected time, and shall stop using its data until it recovers.],
  note: [Every board signals a fixed number of #ident("ADC_CLK") cycles after START, so a missing or late data-ready marks a failed board or a lost clock.],
)

#requirement(
  "FW-3",
  [Firmware shall apply a stored gain and offset correction to every channel.],
  note: [The corrections come from calibration at test. For a thermocouple channel the gain correction also removes the error of the converter's input current through the protection resistors.],
)

#requirement(
  "FW-4",
  [Firmware shall compute each bank's cold-junction temperature from the ratio of its RTD and reference-resistor readings in the same conversion, and shall compensate that bank's thermocouples with it.],
)

#requirement(
  "FW-5",
  [Firmware shall configure each #ident("ADS127L11") for data-output-only SDO, START in synchronized control mode, the wideband filter at an oversampling ratio of 512, the input precharge buffers on and the REFP precharge buffer off.],
  note: [The daisy chain needs data-output-only SDO. The REFP precharge buffer accepts REFP only up to AVDD1 − 0.7~V, 1.8~V here, below the 2.048~V excitation.],
)

== Key Parameters

#figure(
  caption: [Key Design Parameters],
  datatable(
    columns: (auto, 1fr, auto),
    align: (left, left, left),
    header: ("Item", "Value", "Source"),
    [Channels per board],
    [Four general-purpose, four thermocouple, one cold junction],
    [REQ-5, REQ-11, REQ-12],
    [General-purpose bandwidth],
    [2~kHz. 8~kSPS, simultaneous across the stack, flat to 3.2~kHz],
    [#ident("ADS127L11") wideband filter],
    [General-purpose range],
    [Within ±2.0~V at the converter: load cell ±7.4~mV at 2~mV/V, #box[4–20~mA] as 0.4–2.0~V, ±10~V through 5:1],
    [@tab-channel-config],
    [General-purpose noise],
    [2.58~µV~rms at 8~kSPS],
    [#ident("ADS127L11") Table 7-1],
    [Excitation],
    [4.096~V (±2.048~V) per bank, up to 50~mA, also the converter reference],
    [#ident("REF5020")],
    [Thermocouple bandwidth],
    [200~Hz, logged at 1~kSPS],
    [FW-1],
    [Thermocouple range],
    [±75~mV at gain 16: types K, J, N and T],
    [#ident("ADS131M06")],
    [Thermocouple noise],
    [0.8~µV~rms in 200~Hz, about 0.02~°C for type K],
    [#ident("ADS131M06") Table 7-1, FW-1],
    [Converter clock],
    [8.192~MHz from the ECU MCU board (INT-6)],
    [@sec-stacking],
    [Stack],
    [Up to three boards on two SPI buses at 5~MHz],
    [@sec-stacking],
    [Sensor supply],
    [24~V for transmitters, 30~mA limit per channel, 15~V by placement],
    [#ident("TPS61170"), #ident("LT3092")],
    [Input power],
    [About 1.2~W per board, plus about 0.7~W per transmitter channel],
    [Estimate],
  ),
)

= Functional Blocks

== General-Purpose Channels <sec-gp>

Each general-purpose channel has its own converter behind a precision buffer (@fig-gp-chain). The four channels of a bank share one excitation, which is also their converter reference. A channel is set up for its sensor by component placement and jumpers (@tab-channel-config).

#figure(
  caption: [General-Purpose Signal Chain],
  {
    let w = 2.9cm
    let h = 0.9cm
    let lane = 5pt // offset of the signal and excitation either side of the sensor cable's centre line
    let blk(pos, body, name, ..args) = node(pos, body, width: w, height: h, name: name, ..args)
    pad(
      top: 1.4em,
      diagram(
        ..lattice(w, row-gap: 30pt),
        blk((0, 0), [Load cell or\ transmitter], <sens>, shape: shape.io),
        blk((1, 0), [Connector,\ configuration], <cfg>),
        blk((2, 0), [Protection,\ RC filter], <prot>),
        blk((3, 0), [OPA2189\ buffer], <buf>),
        blk((1, 1), [Excitation,\ 24~V supply], <exc>),
        blk((3, 1), [ADS127L11\ 8~kSPS], <adc>),
        blk((3, 2), [Isolator], <iso>),
        blk((2, 2), [Log, 8~kSPS], <log>, shape: shape.io),

        // The sensor cable: signal in above, excitation out below.
        edge(
          (rel: (0pt, lane), to: (0, 0)),
          (rel: (0pt, lane), to: (1, 0)),
          "-|>",
          snap-to: (<sens>, <cfg>),
        ),
        edge(
          (rel: (0pt, -lane), to: (1, 0)),
          (rel: (0pt, -lane), to: (0, 0)),
          "-|>",
          snap-to: (<cfg>, <sens>),
        ),
        edge(<cfg>, <prot>, "-|>"),
        edge(<prot>, <buf>, "-|>"),
        edge(<buf>, <adc>, "-|>"),
        edge(<exc>, <adc>, "-|>", [Ref]),
        edge(<exc>, <cfg>, "-|>", [Exc, 24~V]),
        edge(<adc>, <iso>, "-|>", ..wire.signal),
        edge(<iso>, <log>, "-|>", ..wire.signal),

        zone(<sens>, label: [Engine]),
        zone(<cfg>, <prot>, <buf>, <exc>, <adc>, label: [General-purpose bank, isolated]),
        zone(<log>, label: [ECU MCU board]),
      ),
    )
  },
) <fig-gp-chain>

#figure(
  caption: [General-Purpose Channel Configurations],
  datatable(
    columns: (auto, 1fr, auto),
    align: (left, left, left),
    header: ("Configuration", "Fitted", "At the converter"),
    [Load cell],
    [4-wire full bridge, 350~Ω typical. Excitation to the connector, shunt-calibration resistor and switch.],
    [±7.4~mV at 2~mV/V, ratiometric],
    [#box[4–20~mA] transmitter],
    [100~Ω precision shunt and loop protection. 24~V loop supply through a 30~mA current limit.],
    [0.4–2.0~V],
    [Voltage transmitter],
    [5:1 precision divider for ±10~V. 24~V transmitter supply through a 30~mA current limit.],
    [±2.0~V],
  ),
) <tab-channel-config>

Every configuration keeps the signal within ±2.0~V of the bank common, inside the input ranges of both the buffer and the converter.

- Each channel has its own #ident("ADS127L11"). The four share one clock and one START, so they sample simultaneously (REQ-6), and are daisy-chained on one SPI line.
- They run in high-speed mode from the 8.192~MHz stack clock. The wideband filter at an oversampling ratio of 512 gives 8~kSPS, flat to 3.2~kHz with 106~dB of rejection from 4~kHz, which covers the 2~kHz bandwidth (REQ-7). Noise is 2.58~µV~rms, 0.035~% of full scale for a 2~mV/V load cell.
- An #ident("OPA2189") buffers the two inputs of each channel. The converter's precharge buffers draw up to ±3~µA, which through a 350~Ω bridge and the protection would give errors of a millivolt or more. The #ident("OPA2189") draws under 300~pA. Its input range ends 2.5~V below its positive rail, so it runs from the ±5~V rails while the converters run from ±2.5~V.
- #ident("REF5020") sets a ±2.048~V excitation. One half of an #ident("OPA2189") follows it and the other inverts it, each driving the excitation bus through a #ident("BUF634A"). The precision amplifier sets the voltage and the buffer supplies up to 250~mA. Load cells see the excitation and are measured ratiometrically against it (REQ-9).
- 20~Ω in each excitation leg limits a cable short to about 100~mA, which the drivers carry without disturbing the other channels. The resistors lower the bridge excitation by about 10~%, a fixed gain term removed by shunt calibration.
- Transmitters are powered from a 24~V sensor supply, boosted from the +5~V rail by a #ident("TPS61170"). Each channel takes it through an #ident("LT3092") set to 30~mA, so a shorted transmitter or cable loses only its own channel. A different feedback resistor sets 15~V where the transmitters allow it, which saves power.
- Shunt calibration places a resistor chosen for the load cell across its SIG+ to EXC− arm, through an SPST analog switch driven by #ident("SHUNT_CAL") from the ECU MCU board. It doubles as a built-in test of each load-cell channel (REQ-10).
- An #ident("SN6505B") drives a Würth #ident("750315371") transformer. A bridge rectifier on its centre-tapped secondary gives unregulated ±5~V rails. A #ident("TPS7A39") derives the converters' ±2.5~V from them, its two outputs rising together, and a #ident("TLV704") derives 3.3~V for the converters' I/O and the bank side of the isolators. Two #ident("ISO7741") carry SCLK, SDI and CS in and data out, and the clock, START and calibration lines in and data-ready out.
- Each input carries 10~kΩ of series protection, 0805 for the 78~mW of a 28~V fault, with low-leakage clamps to the ±5~V rails and 110~pF across the pair. In the voltage configuration the SIG+ resistor becomes the 40.2~kΩ top of the 5:1 divider.
- The buffers and the excitation run from the ±5~V rails and are up before the ±2.5~V. 237~Ω at each converter input and reference pin holds the current into its clamps below their 10~mA rating meanwhile, and in a fault. With 3.3~nF across the inputs it is also the converter's input filter.
- The REFP precharge buffer stays off, since REFP is above its 1.8~V limit (FW-5). Unbuffered, the reference draws about 0.25~mA at the 8.192~MHz clock, which through the two 237~Ω resistors lowers it by about 3~%. That is a fixed gain term, removed by calibration (FW-3).

== Thermocouple Channels <sec-tc>

The thermocouple channels deliver a 200~Hz bandwidth (REQ-11) that is free of aliasing and immune to the interference on the engine. This requires every thermocouple to be converted continuously. The multiplexed #ident("AD7124-8") of the first selection cannot do this. Cycling four thermocouples and the cold junction, it settles at most 649 conversions per channel per second (sinc4, FS~=~1, 308~µs each), at its noisiest setting: 4.4~µV~rms at gain 32. Each conversion also responds to signals up to 4.4~kHz, and everything above half the per-channel rate aliases into the result unfiltered. The #ident("ADS131M06") instead converts every input continuously at 4~kSPS, and the firmware filters each to 200~Hz (@fig-tc-chain).

#figure(
  caption: [Thermocouple Signal Chain],
  {
    let w = 2.9cm
    let h = 0.9cm
    let blk(pos, body, name, ..args) = node(pos, body, width: w, height: h, name: name, ..args)
    pad(
      top: 1.4em,
      diagram(
        ..lattice(w, row-gap: 30pt),
        blk((0, 0), [Thermocouple], <tc>, shape: shape.io),
        blk((1, 0), [M80 connector,\ CJC RTD], <block>),
        blk((2, 0), [Protection\ 2 × 1~kΩ, clamps], <prot>),
        blk((3, 0), [RC filter\ 1.6~kHz], <rc>),
        blk((3, 1), [ADS131M06\ 4~kSPS], <adc>),
        blk((3, 2), [Isolator], <iso>),
        blk((2, 2), [Firmware filter\ 200~Hz (FW-1)], <fir>),
        blk((1, 2), [Log, 1~kSPS], <log>, shape: shape.io),

        edge(<tc>, <block>, "-|>"),
        edge(<block>, <prot>, "-|>"),
        edge(<prot>, <rc>, "-|>"),
        edge(<rc>, <adc>, "-|>"),
        edge(<adc>, <iso>, "-|>", ..wire.signal),
        edge(<iso>, <fir>, "-|>", ..wire.signal),
        edge(<fir>, <log>, "-|>", ..wire.signal),

        zone(<tc>, label: [Engine]),
        zone(<block>, <prot>, <rc>, <adc>, label: [Thermocouple bank, isolated]),
        zone(<fir>, <log>, label: [ECU MCU board]),
      ),
    )
  },
) <fig-tc-chain>

- #ident("ADS131M06") converts six channels simultaneously and continuously: the four thermocouples, the cold-junction RTD and a reference resistor in series with it (REQ-11, REQ-12).
- The RTD and the reference resistor carry the same current and are sampled together, so the cold junction is measured as their ratio (FW-4). Neither the excitation nor the converter reference enters the result.
- Each leg carries 1~kΩ of series protection, a 0.1~% 1206 part rated 1~W that carries a 28~V fault, with clamps to the rails of the bank (OI-2). The two resistors add 0.08~µV~rms of thermal noise in 200~Hz.
- The series resistors and 47~nF across the inputs set a differential pole at 1.6~kHz, 0.07~dB down at 200~Hz. Common-mode capacitors of 4.7~nF put the common-mode pole an order of magnitude higher, so their mismatch converts little common-mode interference into a differential error.
- The converter runs at 4~kSPS from the 8.192~MHz stack clock, with a gain of 16 (±75~mV, covering types K, J, N and T over their ranges). Interference reaches the band only from within 200~Hz of a multiple of 4~kSPS. There the converter's sinc3 filter and the RC filter together reject it by at least 85~dB.
- The firmware filter passes 0–200~Hz, rejects 500~Hz and above by at least 80~dB and decimates to 1~kSPS (FW-1). It lowers the noise from 1.82~µV~rms to 0.8~µV~rms, about 0.02~°C~rms for type K.
- The converter draws 1~µA per volt of input. Through the protection resistors that is a 0.2~% gain error, removed by calibration together with the converter's own gain error of ±0.3~% (FW-3).
- The converter's integrated negative charge pump lets its inputs swing to 1.3~V below ground, so the thermocouples are referenced directly to the bank's 0~V, which is also the tie to the engine. A jumper per channel biases an ungrounded junction to it. A grounded junction is left unbiased and takes its reference from the engine.
- An #ident("ISOW7741") supplies the bank at 3.3~V through a ferrite and carries SCLK, SDI and CS in and data out. Its EN/FLT pin is held high through 10~kΩ, so a fault indication cannot short the stack 3.3~V. An #ident("ISO7742") carries the clock and START in and data-ready out.

#figure(
  caption: [Thermocouple Interference and Mitigation],
  datatable(
    columns: (auto, auto, 1fr),
    align: (left, left, left),
    header: ("Source", "Path", "Mitigation"),
    [Engine potential, ignition and valve transients],
    [Common mode on the leads],
    [Galvanic isolation, differential inputs, one resistive engine tie per bank.],
    [Fields around the engine],
    [Pickup on the leads],
    [Twisted, shielded extension wire. Shield terminated at one end: the engine for a grounded junction, the bank common for an ungrounded one.],
    [RF from the igniter and switching converters],
    [Rectification at the inputs],
    [RC filter with matched common-mode capacitors.],
    [Interference above 200~Hz],
    [Aliasing into the band],
    [Continuous conversion at 4~kSPS, converter filter, firmware filter.],
    [Mains, 50 or 60~Hz],
    [Inside the band],
    [Not filtered. Kept out by isolation, differential measurement and cabling. A firmware notch can be added for test-stand use.],
    [Connector junctions],
    [Thermal EMF],
    [Extension wire is crimped into the gold-plated contacts of the sensor connector, with the cold-junction RTD on the board beside the thermocouple pins.],
    [Open thermocouple],
    [Floating input],
    [A high-value pull-up drives the reading out of range.],
  ),
)

The 200~Hz bandwidth is that of the electronics. A junction responds at 200~Hz only if its time constant is below 0.8~ms, which in practice means a fine-wire exposed junction.

== Stacking <sec-stacking>

Boards stack on #ident("ASRP-PCB-INTERCONNECT-2") and share two SPI buses to the ECU MCU board, one for the general-purpose banks and one for the thermocouple banks (@tab-interconnect-signals).

- Each bus has one chip select and one data-ready line per board slot. A 2 × 12 header on each board picks its slot with four shunts, one per line, so every board is built the same. A 10~kΩ pull-up holds the chip selects of an unjumpered board inactive.
- A board drives the shared data lines only while it is selected, through #ident("SN74LVC2G125") 3-state buffers with 62~Ω series termination (INT-4). It drives its own data-ready lines all the time, through the same buffers. Their partial-power-down protection keeps an unpowered board off every line.
- The ECU MCU board supplies the 8.192~MHz converter clock and START to every board, so all boards sample in step (REQ-6, INT-6). Every board already depends on the ECU MCU board, so this adds no new single point of failure.
- Each board takes every line into its isolators through 1~kΩ. A board whose input fails short, or whose 3.3~V input switch has opened, then loads the line with 3.3~mA at most, and the other boards keep their clock and data. On #ident("ADC_CLK") the resistor adds about 5~ns to the edges, against a 122~ns clock period.
- Every data-ready line is visible to the ECU MCU board at all times, so any board can trigger a read. All boards signal together and are read in one burst.
- Data-ready falls a fixed number of #ident("ADC_CLK") cycles after START. Firmware can therefore schedule reads from a timer counting #ident("ADC_CLK") and use the data-ready lines to confirm that every board kept pace (FW-2).
- The isolators add at most 17~ns each way and the bus buffers 4.3~ns, so data returns within about 70~ns of the clock edge. Both buses run at 5~MHz.
- Per board, the general-purpose bank puts 128 bits on its bus every 125~µs and the thermocouple bank 192 bits every 250~µs. Three boards load the buses to about 65~% and 48~%. The interconnect provides three slots: 12 general-purpose and 12 thermocouple channels.
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
      [Thermocouple converter],
      ident("ADS131M06"),
      [Six simultaneous channels: four thermocouples, the cold-junction RTD and its reference resistor. Gain to 128. Integrated negative charge pump: inputs to 1.3~V below ground. 1.82~µV~rms at 4~kSPS, gain 16. Sinc3 filter. SPI with CRC and data-ready. 4.9~mW. 4 × 4~mm WQFN.],
      [Excitation reference],
      ident("REF5020"),
      [2.048~V, 3~ppm/°C maximum (high grade).],
      [Excitation drivers],
      [#ident("OPA2189"), 2 × #ident("BUF634A")],
      [Precision amplifier with a 250~mA buffer in its loop, one per polarity. ±2.25 to ±18~V supply, internal current limit, thermal shutdown.],
      [Excitation current limit],
      [8 × 20~Ω],
      [One per excitation leg. 1206 or larger for 0.2~W in a short.],
      [General-purpose isolated supply],
      [#ident("SN6505B"), #ident("750315371")],
      [1~A push-pull driver at 420~kHz. Würth 1:1.1 centre-tapped transformer, 2500~V~rms, 1~A rated at 5~V. Four 30~V 1~A Schottky diodes (TBD) as the bridge for ±5~V.],
      [General-purpose regulators],
      [#ident("TPS7A39"), #ident("TLV704")],
      [Dual positive and negative LDO for ±2.5~V: 150~mA each, ±3.3 to ±33~V in, outputs track at start-up, 21~µV~rms. 150~mA LDO for 3.3~V, 2.5 to 24~V in. Both tolerate the rectified rails at light load. Loads about 22 and 37~mA on ±2.5~V, 25~mA on 3.3~V.],
      [Sensor supply],
      [#ident("TPS61170")],
      [Boost from +5~V to 24~V. 1.2~A switch, 38~V output maximum, 1.2~MHz, 2 × 2~mm QFN. 10~µH inductor and 40~V Schottky (TBD).],
      [Sensor supply current limit],
      [4 × #ident("LT3092")],
      [2-terminal current source set to 30~mA. 0.5 to 200~mA, 1.2 to 40~V, thermal limit. 3 × 3~mm DFN.],
      [General-purpose isolation],
      [2 × #ident("ISO7741")],
      [Three forward and one reverse channel each, 17~ns maximum delay. 4.9 × 6~mm QSOP.],
      [Thermocouple supply and data isolation],
      ident("ISOW7741"),
      [550~mW isolated supply with three forward and one reverse channel, 15.7~ns maximum delay.],
      [Thermocouple control isolation],
      ident("ISO7742"),
      [Two forward and two reverse channels. 4.9 × 6~mm QSOP.],
      [Cold-junction sensor],
      [Pt1000 (TBD), 1~kΩ 0.1~%],
      [Thin-film RTD, class A, in series with the reference resistor and 4.7~kΩ from 3.3~V: 0.49~mA. Both on #ident("ADS131M06") channels.],
      [Input clamps],
      [BAV199 class (TBD)],
      [Low-leakage series pair to the bank rails, one per input.],
      [Shunt-calibration switch],
      [TBD],
      [SPST, ±5~V supply, 3.3~V logic, on-resistance under 100~Ω, leakage under 1~nA. One per channel.],
      [Bus buffers],
      [2 × #ident("SN74LVC2G125")],
      [Dual 3-state buffer, 4.3~ns maximum at 3.3~V, partial-power-down protection.],
      [Input resistors],
      [1~kΩ],
      [In series with every line into the isolators, #ident("ADC_CLK") included.],
      [Slot select],
      [2 × 12 header (TBD)],
      [2~mm pitch, Harwin M22 family. Four shunts pick the slot.],
      [Sensor connector],
      ident("M80-5002842"),
      [Harwin Datamate J-Tek, 28-way, 2~mm pitch, vertical through-hole, M2 jackscrews, −55 to 125~°C. 800~V working between contacts. 38 × 6~mm.],
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
  ("Board Area", [60 × 60~mm]),
  ("Stack-up", [TBD]),
  ("Placement Area", [26~cm² before connectors]),
  ("Sensor Connector", [#ident("M80-5002842")]),
  ("Stack Connector", [TBD, 32-way]),
  ("Input Power", [1.2 to 4.0~W, estimated]),
)

The parts need about 26~cm² of placement area, against 36~cm² on each side of the outline (REQ-2). With the sensor and stack connectors and the mounting holes, about 32~cm² of one side is used. The back side takes the overflow. Input power is about 1.2~W per board, plus about 0.7~W for each channel set up for a transmitter, so 1.2 to 4.0~W.

- The two isolated banks and the stack side are kept apart on every layer, with the isolators and isolated supplies straddling the gaps.
- The thermocouple contacts and the cold-junction RTD sit together, away from the isolated supplies, so that the connector stays isothermal.

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
    [Three boards draw 0.7~A at 5~V without transmitters and 2.3~A with a transmitter on every general-purpose channel (INT-2), against 2~A for the whole ECU stack. Not resolved in this revision. The number of transmitter channels in a stack is held to what the rail can spare.],

    ident("OI-2"),
    [A thermocouple fault can raise the 3.3~V of its bank],
    [A 28~V fault on a thermocouple input drives about 25~mA through its 1~kΩ and clamp into 3V3_TC, more than the bank draws, so the rail can rise past the #ident("ADS131M06") 3.9~V maximum. To be resolved before layout: a clamp on the rail, or more series resistance at a cost in noise.],

    ident("OI-3"),
    [Parts without a library record],
    [The schematic carries placeholders, marked \*, for the sensor and stack connectors, the transformer, the bridge and boost diodes, the boost inductor, the input clamps, the shunt-calibration switch, the RTD, the slot header and the precision and odd-value resistors. Each names its required value and rating. Every IC footprint is TODO in the library.],

    ident("OI-4"),
    [Engine-tie resistance],
    [Each bank ties to the engine through a resistor behind its shield jumper. The value depends on the engine grounding scheme and is TBD.],
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
