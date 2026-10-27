# GP channel DC fault sweep

An ngspice model of both GP channels and the channel supplies, generated from
the KiCad netlist, which applies faults to channel 1's five contacts and
checks every part against its absolute maximum ratings.

It runs on the ngspice library bundled with KiCad; nothing needs installing.

```
python3 gen_deck.py     # netlist -> board.cir, board.json (rerun after schematic edits)
python3 validate.py     # the model against the design summary's own fault figures
python3 sweep.py        # every case -> results.json (about 35 min on 10 processes)
python3 report.py       # results.json -> report.md
```

| File | What it holds |
|---|---|
| `parts.lib` | Behavioural DC models of every part type, from the datasheets |
| `gen_deck.py` | Exports the netlist and writes `board.cir`, one line per part |
| `scenarios.py` | Power states, configurations, sensors, fault sources and the deck around `board.cir` |
| `limits.py` | The limits table: each part's ratings, with the datasheet section they come from |
| `sweep.py` | Runs every case in parallel and records each limit exceeded |
| `report.py` | Groups the violations by fault type into `report.md` |
| `ngspice.py` | A ctypes wrapper for KiCad's `libngspice` |

## Cases

- **Power:** running; 24 V rail absent; channel supply off (eFuse disabled, 24 V up); whole stack off.
- **Configurations:** every row of the switch-code table, with S11 open and closed.
- **Sensors:** none, a 350 Ω load cell, a 3.5 kΩ piezoresistive bridge, a two-wire 4–20 mA transmitter at 21 mA with the CBL-1 link, a three-wire 0–10 V transmitter at 10 V.
- **Faults:** each contact swept to +28 V and to −28 V, from a source limited to 30 mA (another channel's sensor supply) and from one limited to 5 A (a low-impedance supply behind its fuse). Every pair of contacts shorted while running.

## Limits of the model

- DC only. ESD, fast transients and PTC trip are out of scope.
- Each operating point comes from a slow transient: the supplies ramp up, the
  switch lines come up at 1.4 ms, then the fault ramps at 1 V/ms. The
  board's capacitors are left out, so the ramp is quasi-static.
- The ICs are behavioural: clamp diodes, source-only regulators, supply
  currents gated on their supply. How far an unpowered rail is back-powered
  depends on how loads behave below their minimum supply, which the
  datasheets do not give; treat those voltages as indicative.
- The TLP3475S ratings (0.4 A, LED 30 mA, VR 5 V) are from memory; no
  datasheet is in the library.
- Parts are not damaged in the model. Past a rating, a part keeps behaving as
  modelled, so the currents downstream of the first failure are not real.
