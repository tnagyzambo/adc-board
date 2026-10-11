// =============================================================================
//  GENERAL-PURPOSE CHANNEL  --  simplified functional schematics.
//
//  One drawing per configuration, after e003-gp-channel.kicad_sch.  The parts
//  that set the converter's accuracy are drawn as components; the excitation,
//  the sensor supply and the isolation are blocks; decoupling and
//  housekeeping parts are left out.
//
//  Drawn in millimetres, with the symbols in the proportions of the ECAD
//  library's KiCad symbols and, as in KiCad, one stroke for wires and symbols.
//
//      #figure(caption: [...], gp-channel("load-cell"))
//
//  Configurations: "load-cell", "current", "voltage".
// =============================================================================

#import "@local/eng-report:0.6.0": fletcher, fonts, size, track, rule, ink

#let cetz = fletcher.cetz

#let _s = (paint: ink.rule, thickness: rule.thin)
#let _zone = (paint: ink.rule, thickness: rule.hair, dash: "dashed")
#let _bus = (paint: ink.rule, thickness: rule.thin, dash: "dashed")
#let _arrow = (end: ">", fill: ink.rule, length: 1.6mm, width: 1.2mm)

// -- GEOMETRY ----------------------------------------------------------------

#let _len(a, b) = calc.sqrt(
  calc.pow(b.at(0) - a.at(0), 2) + calc.pow(b.at(1) - a.at(1), 2),
)

#let _mid(a, b) = ((a.at(0) + b.at(0)) / 2, (a.at(1) + b.at(1)) / 2)

// The point `t` along the line from `a` to `b`, offset `o` to its left.
#let _at(a, b, t, o) = {
  let l = _len(a, b)
  let (ux, uy) = ((b.at(0) - a.at(0)) / l, (b.at(1) - a.at(1)) / l)
  (a.at(0) + ux * t - uy * o, a.at(1) + uy * t + ux * o)
}

// A label `gap` clear of `c` to its "n", "e", "s" or "w".
#let _label(c, body, side, gap) = {
  import cetz.draw: content
  let (x, y) = c
  let (pos, anchor) = (
    n: ((x, y + gap), "south"),
    e: ((x + gap, y), "west"),
    s: ((x, y - gap), "north"),
    w: ((x - gap, y), "east"),
  ).at(side)
  content(pos, body, anchor: anchor)
}

// -- SYMBOLS -----------------------------------------------------------------

#let wire(..pts) = cetz.draw.line(..pts, stroke: _s)

// Junction.
#let dot(p) = cetz.draw.circle(p, radius: 0.45, fill: ink.rule, stroke: none)

// Connector contact.
#let pin(p) = cetz.draw.circle(p, radius: 0.6, fill: white, stroke: _s)

// Resistor between two points: the library's zigzag, 5 mm by 2 mm.
#let res(a, b, label: none, side: "n") = {
  import cetz.draw: line
  let (body, amp) = (5, 1)
  let s = (_len(a, b) - body) / 2
  let zig = ((0, 0), (0.1, -1), (0.3, 1), (0.5, -1), (0.7, 1), (0.9, -1), (1, 0))
  line(a, _at(a, b, s, 0), stroke: _s)
  line(..zig.map(((t, o)) => _at(a, b, s + t * body, o * amp)), stroke: _s)
  line(_at(a, b, s + body, 0), b, stroke: _s)
  if label != none { _label(_mid(a, b), label, side, amp + 0.6) }
}

// Capacitor between two points: plates 3.6 mm wide, 1.2 mm apart.
#let cap(a, b, label: none, side: "e") = {
  import cetz.draw: line
  let (gap, w) = (1.2, 3.6)
  let m = _len(a, b) / 2
  line(a, _at(a, b, m - gap / 2, 0), stroke: _s)
  line(_at(a, b, m + gap / 2, 0), b, stroke: _s)
  for t in (m - gap / 2, m + gap / 2) {
    line(_at(a, b, t, w / 2), _at(a, b, t, -w / 2), stroke: _s)
  }
  if label != none { _label(_mid(a, b), label, side, w / 2 + 0.6) }
}

// Op amp from the end of its + pin: inputs 5 mm apart with + above, as in the
// library symbol, and the output pin ending 14 mm along, level between them.
#let opamp(p, name: none) = {
  import cetz.draw: line, content
  let (x, y) = p
  line((x, y), (x + 2, y), stroke: _s)
  line((x, y - 5), (x + 2, y - 5), stroke: _s)
  line(
    (x + 2, y + 2.5),
    (x + 12, y - 2.5),
    (x + 2, y - 7.5),
    close: true,
    stroke: _s,
    fill: white,
  )
  line((x + 12, y - 2.5), (x + 14, y - 2.5), stroke: _s)
  content((x + 3.6, y), [+])
  content((x + 3.6, y - 5), [−])
  if name != none { content((x + 2, y + 3.1), name, anchor: "south-west") }
}

// Ground or supply return: an open triangle, labelled to its right.
#let gnd(p, label: none) = {
  import cetz.draw: line
  let (x, y) = p
  line((x, y), (x, y - 1.6), stroke: _s)
  line((x - 1.3, y - 1.6), (x + 1.3, y - 1.6), (x, y - 2.9), close: true, stroke: _s)
  if label != none { _label((x + 1.3, y - 2.2), label, "e", 0.5) }
}

// Switch on a vertical from `a` down to `b`, drawn open: contacts 3 mm apart.
#let switch(a, b, label: none) = {
  import cetz.draw: line, circle
  let (x, ya) = a
  let m = (ya + b.at(1)) / 2
  line(a, (x, m + 1.5), stroke: _s)
  line((x, m - 1.5), b, stroke: _s)
  line((x, m - 1.5), (x + 1.8, m + 1.3), stroke: _s)
  for y in (m + 1.5, m - 1.5) {
    circle((x, y), radius: 0.35, fill: white, stroke: _s)
  }
  if label != none { _label((x, m), label, "e", 2.4) }
}

#let _source(a, b) = {
  import cetz.draw: line, circle
  let (r, m) = (2.8, _len(a, b) / 2)
  line(a, _at(a, b, m - r, 0), stroke: _s)
  line(_at(a, b, m + r, 0), b, stroke: _s)
  circle(_mid(a, b), radius: r, stroke: _s, fill: white)
}

// Current source from `a` to `b`, the arrow in the direction of the current.
#let isource(a, b, label: none, side: "e") = {
  import cetz.draw: line
  let m = _len(a, b) / 2
  _source(a, b)
  line(_at(a, b, m - 1.8, 0), _at(a, b, m + 1.8, 0), stroke: _s, mark: _arrow)
  if label != none { _label(_mid(a, b), label, side, 3.4) }
}

// Voltage source from + at `a` to − at `b`.
#let vsource(a, b, label: none, side: "e") = {
  import cetz.draw: content
  let m = _len(a, b) / 2
  _source(a, b)
  content(_at(a, b, m - 1.3, 0), [+])
  content(_at(a, b, m + 1.3, 0), [−])
  if label != none { _label(_mid(a, b), label, side, 3.4) }
}

// Functional block: corners `a` and `b`, its text centred.
#let blk(a, b, body) = {
  import cetz.draw: rect, content
  rect(a, b, stroke: (paint: ink.rule, thickness: rule.hair), fill: white)
  content(_mid(a, b), align(center, body))
}

// Domain: a dashed outline from bottom left `a` to top right `b`, titled above
// its top left corner as the template's `group` is.
#let domain(a, b, label) = {
  import cetz.draw: rect, content
  rect(a, b, stroke: _zone)
  content((a.at(0), b.at(1) + 1), text(fill: ink.mute, upper(label)), anchor: "south-west")
}

// Drawing scaled down to the text width where the page is narrower than it.
#let _fit(body) = layout(region => {
  let w = measure(body).width
  if w <= region.width { body } else {
    scale(region.width / w * 100%, reflow: true, body)
  }
})

// -- CHANNEL -----------------------------------------------------------------

// Rows of the four sensor contacts, the converter's inputs and its reference.
#let _y = (ep: 54, sp: 41, en: 28, sn: 15, inp: 38.5, inn: 12.5, rp: -3, rn: -9)

#let gp-channel(config) = {
  assert(
    config in ("load-cell", "current", "voltage"),
    message: "no configuration " + repr(config),
  )
  let y = _y
  // Columns: the sensor contacts on the edge of the bank, the tap for shunt
  // calibration or the shunt, the series resistors, the buffers' inputs and
  // outputs, the converter's input filter and the converter.
  let (xc, xt, r0, r1) = (26, 35, 37, 49)
  let (x701, xop, xo, x702, x718, xa) = (64, 69, 86, 100, 104, 115)

  set text(font: fonts.display, size: size.tiny, tracking: track.label)
  _fit(cetz.canvas(length: 1mm, {
    import cetz.draw: line, content

    domain((-2, 9), (20, 60), [Engine])
    domain((xc, -16), (141, 60), [General-purpose bank, isolated])

    // -- Sensor -----------------------------------------------------------
    if config == "load-cell" {
      let (t, r, b, l) = ((9, y.ep), (17, y.sp), (9, y.en), (1, y.sp))
      res(t, r)
      res(r, b)
      res(b, l)
      res(l, t)
      content((9, y.sp), [350~Ω])
      for p in (t, r, b, l) { dot(p) }
      wire(t, (xc, y.ep))
      wire(r, (xc, y.sp))
      wire(b, (xc, y.en))
      wire(l, (1, y.sn), (xc, y.sn))
    } else if config == "current" {
      wire((xc, y.ep), (4, y.ep))
      isource((4, y.ep), (4, y.sp), label: [4–20~mA])
      wire((4, y.sp), (xc, y.sp))
    } else {
      cetz.draw.rect((0, 11), (18, 50), stroke: _s)
      content((9, 48.6), [Transmitter], anchor: "north")
      wire((xc, y.ep), (9, y.ep), (9, 50))
      vsource((5, y.sp - 3), (5, y.en + 1), label: [±10~V])
      wire((5, y.sp - 3), (5, y.sp), (xc, y.sp))
      wire((5, y.en + 1), (5, 21), (14, 21))
      wire((xc, y.en), (14, y.en), (14, y.sn), (xc, y.sn))
      dot((14, 21))
    }

    // -- Connector side ---------------------------------------------------
    if config == "load-cell" {
      for (row, side, net) in ((y.ep, "n", [EXC_P]), (y.en, "s", [EXC_N])) {
        wire((xc, row), (r0, row))
        res((r0, row), (r1, row), label: [20~Ω], side: side)
        wire((r1, row), (51, row))
        content((51.5, row), net, anchor: "west")
      }
      // Shunt calibration across the SIG+ to EXC− arm.
      res((xt, y.sp), (xt, y.sp - 6.5), label: [RCAL], side: "e")
      switch((xt, y.sp - 6.5), (xt, y.en), label: [ADG1402])
      dot((xt, y.sp))
      dot((xt, y.en))
    } else {
      wire((xc, y.ep), (xt, y.ep))
      blk((xt, 50.5), (r1, 57.5), [LT3092\ 30~mA])
      wire((r1, y.ep), (54, y.ep))
      blk((54, 50.5), (72, 57.5), [Sensor supply\ 24~V])
    }
    if config == "current" {
      res((xt, y.sp), (xt, y.sn), label: [100~Ω], side: "e")
      wire((xt, y.sn), (xt, y.sn - 5))
      gnd((xt, y.sn - 5), label: [COM])
      dot((xt, y.sp))
      dot((xt, y.sn))
    }
    if config == "voltage" {
      wire((xc, y.en), (xt, y.en))
      gnd((xt, y.en), label: [COM])
    }

    // Series protection, or in the voltage configuration the 5:1 divider
    // returned to SIG− at the connector.  Set further along beside the
    // 4–20 mA shunt, clear of its label.
    let (s0, s1) = if config == "current" { (44, 56) } else { (r0, r1) }
    wire((xc, y.sp), (s0, y.sp))
    if config == "voltage" {
      res((r0, y.sp), (r1, y.sp), label: [40.2~kΩ])
      wire((r1, y.sp), (xop, y.sp))
      res((52, y.sp), (52, y.sn), label: [10~kΩ], side: "e")
      dot((52, y.sp))
      dot((52, y.sn))
      wire((xc, y.sn), (52, y.sn))
      res((52, y.sn), (62, y.sn), label: [10~kΩ])
      wire((62, y.sn), (xop, y.sn))
    } else {
      res((s0, y.sp), (s1, y.sp), label: [10~kΩ])
      wire((s1, y.sp), (xop, y.sp))
      wire((xc, y.sn), (s0, y.sn))
      res((s0, y.sn), (s1, y.sn), label: [10~kΩ])
      wire((s1, y.sn), (xop, y.sn))
    }

    for (row, name) in ((y.ep, [EXC+]), (y.sp, [SIG+]), (y.en, [EXC−]), (y.sn, [SIG−])) {
      pin((xc, row))
      content((xc + 0.9, row + 0.5), name, anchor: "south-west")
    }

    // -- Buffers and converter input filter -------------------------------
    cap((x701, y.sp), (x701, y.sn), label: [110~pF])
    dot((x701, y.sp))
    dot((x701, y.sn))

    for (y0, yo) in ((y.sp, y.inp), (y.sn, y.inn)) {
      opamp((xop, y0), name: [OPA2189])
      wire((xop + 14, yo), (xo, yo))
      wire((xo, yo), (xo, y0 - 9), (xop - 2, y0 - 9), (xop - 2, y0 - 5), (xop, y0 - 5))
      dot((xo, yo))
      res((xo, yo), (xo + 12, yo), label: [237~Ω])
      wire((xo + 12, yo), (xa, yo))
      dot((x702, yo))
      dot((x718, yo))
      cap((x718, yo), (x718, yo - 6.5), label: [330~pF])
      gnd((x718, yo - 6.5), label: [AVSS])
    }
    cap((x702, y.inp), (x702, y.inn), label: [3.3~nF], side: "w")

    // -- Reference --------------------------------------------------------
    blk((30, -14), (56, 0), [Excitation ±2.048~V\ REF5020, OPA2189,\ 2 × BUF634A])
    for (row, name, side) in ((y.rp, [EXC_P], "n"), (y.rn, [EXC_N], "s")) {
      wire((56, row), (xo, row))
      content((57.5, row + 0.4), name, anchor: "south-west")
      res((xo, row), (xo + 12, row), label: [237~Ω], side: side)
      wire((xo + 12, row), (xa, row))
      dot((x702 + 2, row))
    }
    cap((x702 + 2, y.rp), (x702 + 2, y.rn), label: [1.1~µF])

    // -- Converter and isolation ------------------------------------------
    cetz.draw.rect((xa, -13), (xa + 16, 44), stroke: _s, fill: white)
    content((xa + 8, (y.inp + y.inn) / 2), [ADS127L11])
    for (row, name) in ((y.inp, [AINP]), (y.inn, [AINN]), (y.rp, [REFP]), (y.rn, [REFN])) {
      content((xa + 1, row), name, anchor: "west")
    }
    line((xa + 16, 15), (135, 15), stroke: _bus, mark: _arrow)
    blk((135, 10), (147, 20), [Isolator])
    line((147, 15), (153, 15), stroke: _bus, mark: _arrow)
    content((153.8, 15), align(left)[ECU MCU\ board], anchor: "west")
  }))
}
