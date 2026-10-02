#import "@local/eng-report:0.6.0": *

// Written by `dcs` from the last commit that touched this file.  It is not
// tracked, so building never dirties the tree and a clean stamp stays true.
#let source-revision = json("assets/git-info.json").display

#show: report.with(
  title: [Design Summary],
  subtitle: [ASRP ADC Board],
  number: "e003-adc-board",
  revision: "-",
  date: "2026-10-02",
  organization: "Nonplus",
  foot-note: none,
  authors: (("T. Nagy Zambo", "Design and review"),),
  source-revision: source-revision,
  summary: [
    The ADC board is the analog data acquisition board of the ASRP ECU stack. It provides eight general-purpose channels, sampled simultaneously at 2~kSPS and configurable for load cells, 4–20~mA transmitters and voltage transmitters, and seven thermocouple channels sampled at 200~Hz. Both channel banks are isolated from the stack. The board is powered by the power board and read by the ECU MCU board, which logs the data. This draft sets out the requirements for REV A of the ADC board.
  ],
)

// =============================================================================
//  FRONT MATTER
// =============================================================================

#revision-record(
  (
    "-",
    "2026-10-02",
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

The #ident("E003-ADC-BOARD") is the analog data acquisition board of the ECU stack for the Advanced Small Rocket Project (ASRP). It carries eight general-purpose channels, each configurable for a load cell, a 4–20~mA transmitter or a voltage transmitter, and seven thermocouple channels. Its measurement quality is intended to approach that of National Instruments data acquisition hardware.

The board mates with the #ident("E001-POWER-BOARD"), which supplies its 5~V and 3.3~V rails. The ECU MCU board configures and reads the converters and logs the data to eMMC.

== Requirements

Requirements stated with "must" are mandatory. Those stated with "should" are design goals.

#figure(
  caption: [Key Requirements],
  datatable(
    columns: (auto, 1fr, auto),
    align: (left, left, left),
    header: ("Identifier", "Requirement", "Source"),
    [REQ-1],
    [Device must be compatible with #ident("ASRP-PCB-INTERCONNECT-1")],
    [TBD],
    [REQ-2],
    [Device must fit the 60 × 60~mm ECU stack outline],
    [TBD],
    [REQ-3],
    [Device must draw power only from the 5~V and 3.3~V rails of #ident("ASRP-PCB-INTERCONNECT-1")],
    [Local],
    [REQ-4],
    [Device must be configured and read by the ECU MCU board according to #ident("TBD")],
    [TBD],
    [REQ-5],
    [Device must provide eight general-purpose analog input channels],
    [Local],
    [REQ-6],
    [Device should sample the general-purpose channels simultaneously],
    [Local],
    [REQ-7],
    [Device must deliver each general-purpose channel at 2~kSPS],
    [Local],
    [REQ-8],
    [Device must allow each general-purpose channel to be configured by component placement and jumpers for a full-bridge load cell, a 4–20~mA transmitter or a voltage transmitter],
    [Local],
    [REQ-9],
    [Device must excite the load cells and measure them ratiometrically],
    [Local],
    [REQ-10],
    [Device should provide shunt calibration on each load cell channel],
    [Local],
    [REQ-11],
    [Device must provide seven thermocouple channels, each sampled at 200~Hz or more],
    [Local],
    [REQ-12],
    [Device must compensate the thermocouple channels for cold-junction temperature],
    [Local],
    [REQ-13],
    [Device should galvanically isolate the general-purpose and thermocouple channels from the stack and from each other],
    [Local],
    [REQ-14],
    [Device should approach the measurement performance of comparable National Instruments modules],
    [Local],
  ),
)

= System Description

== Architecture

TBD

== Operations Concept

TBD

== Interfaces

TBD

== Firmware Requirements

TBD

== Key Parameters

TBD

= Functional Blocks

TBD

= Physical Implementation

TBD

// =============================================================================
//  APPENDIX
//
//  `assets/` is written by `dcs`, which re-plots the schematic only when a
//  .kicad_sch is newer than the export and re-prices the BOM when a sheet
//  changes.  Compiling this file never invokes KiCad or plm; it only reads
//  what the build left behind.
//
//  There is no KiCad project yet.  The Bill of Materials and Schematics
//  appendices go here, as in e001-power-board, once the [schematic] and [bom]
//  tables in dcs.toml are enabled.
// =============================================================================
