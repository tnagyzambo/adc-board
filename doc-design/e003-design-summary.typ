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
    TBD
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

TBD

== Requirements

TBD

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
