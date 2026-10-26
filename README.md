# e003-adc-board

Analog data acquisition board for the ASRP ECU stack. Two general-purpose
channels, sampled simultaneously, configured through an onboard FPGA for load
cells, piezoresistive pressure transducers, 4-20 mA and voltage transmitters,
and referenced to the stack's ground. The thermocouple channels are
`e004-tc-board`. Boards stack to add channels on ASRP-PCB-INTERCONNECT-2,
defined in the design summary, which brings them power from `e001-power-board`
through the ECU MCU board and carries their data to it. The ECU MCU board logs
the data. 60 x 60 mm.

The schematic is drawn; the board has not yet been laid out.

## Documentation

`doc-design/e003-design-summary.typ` records the design intent and, once there
is a board, reviews it against that intent and the device datasheets, with the
schematic as an appendix.

The report builds with [`dcs`](../../../code/dcs). It is built twice:
`e003-design-summary-a4.pdf` to print single sided and keep loose leaf, and
`e003-design-summary-b5.pdf` to print duplex and file in a binder.

```
cd doc-design
dcs build            # or `dcs watch`, or `dcs clean`
dcs open             # editor, build and viewer in one zellij session
```

Everything generated lands in `doc-design/assets/` and is ignored. The footer
stamp names the last commit that touched the report: build after committing and
it names that commit, build mid-edit and it says so.

## Repository

Part of the ASRP ECU stack. Each board is its own repo, sitting side by
side under `ecad/projects/`: `e001-power-board`, `e002-mcu-board`,
`e003-adc-board`, `e004-tc-board`, `bus-interface`, `ecu-stack` and
`servo-board`. They are separate because they are drawn, revised, fabricated
and released one at a time. Nothing in the KiCad files crosses a board
boundary.

## Branches

- `main` — released revisions and nothing else. One commit per revision,
  squashed from `dev` at release, with the revision in the commit subject:
  `REV A`, `REV B`. `git log --oneline main` is the revision list.
- `dev` — everything in progress.

There are no tags. A revision is a commit on `main`.

This board has no revision yet, so `main` carries only its initial commit, an
empty README. Everything, this README included, lives on `dev`.
