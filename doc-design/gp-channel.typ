// =============================================================================
//  GENERAL-PURPOSE CHANNEL  --  simplified functional schematics.
//
//  One circuit, configured by firmware through switches S1 to S10.  Each
//  drawing shows the same channel set up for one sensor: closed switches and
//  the parts and paths in use are drawn in black, open switches and the parts
//  they leave idle in grey.  The parts that set the converter's accuracy are
//  drawn as components; the excitation, the sensor supply and the gate drive
//  are left out or drawn as blocks, and so is decoupling.
//
//  Drawn in millimetres, with the symbols in the proportions of the ECAD
//  library's KiCad symbols and, as in KiCad, one stroke for wires and symbols.
//
//      #figure(caption: [...], gp-channel("load-cell"))
//
//  Configurations: "load-cell", "piezo" (a piezoresistive bridge), "current"
//  (a 4–20 mA transmitter), "voltage" (a 0–10 V transmitter).
// =============================================================================

#import "@local/eng-report:0.6.0": fletcher, fonts, size, track, rule, ink

#let cetz = fletcher.cetz

// Parts and paths that a configuration leaves idle.
#let idle = luma(175)

#let _st(paint) = (paint: paint, thickness: rule.thin)
#let _s = _st(ink.rule)
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
#let _label(c, body, side, gap, paint: ink.text) = {
  import cetz.draw: content
  let (x, y) = c
  let (pos, anchor) = (
    n: ((x, y + gap), "south"),
    e: ((x + gap, y), "west"),
    s: ((x, y - gap), "north"),
    w: ((x - gap, y), "east"),
  ).at(side)
  content(pos, text(fill: paint, body), anchor: anchor)
}

// Text at a point, in the paint of the part it names.
#let _text(p, body, anchor: "center", paint: ink.text) = {
  cetz.draw.content(p, text(fill: paint, body), anchor: anchor)
}

// -- SYMBOLS -----------------------------------------------------------------

#let wire(..pts, paint: ink.rule) = cetz.draw.line(..pts, stroke: _st(paint))

// Junction.
#let dot(p, paint: ink.rule) = cetz.draw.circle(p, radius: 0.45, fill: paint, stroke: none)

// Connector contact.
#let pin(p) = cetz.draw.circle(p, radius: 0.6, fill: white, stroke: _s)

// Resistor between two points: the library's zigzag, 5 mm by 2 mm.
#let res(a, b, label: none, side: "n", paint: ink.rule) = {
  import cetz.draw: line
  let (body, amp) = (5, 1)
  let s = (_len(a, b) - body) / 2
  let zig = ((0, 0), (0.1, -1), (0.3, 1), (0.5, -1), (0.7, 1), (0.9, -1), (1, 0))
  line(a, _at(a, b, s, 0), stroke: _st(paint))
  line(..zig.map(((t, o)) => _at(a, b, s + t * body, o * amp)), stroke: _st(paint))
  line(_at(a, b, s + body, 0), b, stroke: _st(paint))
  if label != none { _label(_mid(a, b), label, side, amp + 0.6, paint: paint) }
}

// Capacitor between two points: plates 3.6 mm wide, 1.2 mm apart.
#let cap(a, b, label: none, side: "e", paint: ink.rule) = {
  import cetz.draw: line
  let (gap, w) = (1.2, 3.6)
  let m = _len(a, b) / 2
  line(a, _at(a, b, m - gap / 2, 0), stroke: _st(paint))
  line(_at(a, b, m + gap / 2, 0), b, stroke: _st(paint))
  for t in (m - gap / 2, m + gap / 2) {
    line(_at(a, b, t, w / 2), _at(a, b, t, -w / 2), stroke: _st(paint))
  }
  if label != none { _label(_mid(a, b), label, side, w / 2 + 0.6, paint: paint) }
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
#let gnd(p, label: none, paint: ink.rule) = {
  import cetz.draw: line
  let (x, y) = p
  line((x, y), (x, y - 1.6), stroke: _st(paint))
  line((x - 1.3, y - 1.6), (x + 1.3, y - 1.6), (x, y - 2.9), close: true, stroke: _st(paint))
  if label != none { _label((x + 1.3, y - 2.2), label, "e", 0.5, paint: paint) }
}

// Switch from `a` to `b`, in any direction: contacts 3 mm apart, the blade
// lifted to the left of the direction of travel when open.
#let switch(a, b, label: none, side: "e", closed: false, paint: ink.rule) = {
  import cetz.draw: line, circle
  let m = _len(a, b) / 2
  let (c0, c1) = (_at(a, b, m - 1.5, 0), _at(a, b, m + 1.5, 0))
  line(a, c0, stroke: _st(paint))
  line(c1, b, stroke: _st(paint))
  if closed {
    line(c0, c1, stroke: _st(paint))
  } else {
    line(c1, _at(a, b, m - 1.3, 1.8), stroke: _st(paint))
  }
  for c in (c0, c1) { circle(c, radius: 0.35, fill: white, stroke: _st(paint)) }
  if label != none { _label(_mid(a, b), label, side, 2.4, paint: paint) }
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

// Rows of the four sensor contacts, the converter's inputs, the three REFP
// sources and REFN.
#let _y = (
  ep: 54, sp: 41, en: 28, sn: 15, inp: 38.5, inn: 12.5,
  r1: -2, r2: -8, r3: -14, rn: -20,
)

#let gp-channel(config) = {
  assert(
    config in ("load-cell", "piezo", "current", "voltage"),
    message: "no configuration " + repr(config),
  )
  let y = _y
  let bridge = config in ("load-cell", "piezo")
  let tx = not bridge
  // Closed switches, and the parts each configuration uses.
  let on = (
    s1: config == "load-cell",
    s2: tx,
    s3: config == "load-cell",
    s4: tx,
    s5: config == "load-cell",
    s6: config == "piezo",
    s7: tx,
    s8: config == "current",
    s9: config == "voltage",
  )
  let sense = config != "load-cell"
  let exc-n = true
  let c(b) = if b { ink.rule } else { idle }
  // Columns: the contacts, the current source's branches, the return of
  // EXC−, shunt calibration, the shunt, the divider, the buffers and the
  // converter's input filter, the converter.
  let xc = 26
  let (b0, b1, b2) = (34, 45, 56)
  let (xs, x3, xcal, x4) = (31, 43, 50, 55)
  let (xsh, xdv) = (63, 82)
  let (sp0, sp1, sn0, sn1) = (67, 79, 85, 95)
  let (xk, xop, xo, x702, x718, xa) = (98, 101, 118, 132, 136, 147)
  // REFP sources: resistor, switch and the bus that joins them.
  let (rr0, rr1, rs0, rs1, xb) = (64, 76, 78, 86, 90)

  set text(font: fonts.display, size: size.tiny, tracking: track.label)
  _fit(cetz.canvas(length: 1mm, {
    import cetz.draw: line, content

    domain((-2, 9), (20, 60), [Engine])
    domain((xc, -28), (166, 75), [General-purpose bank, isolated])

    // -- Sensor -----------------------------------------------------------
    if bridge {
      let (t, r, b, l) = ((9, y.ep), (17, y.sp), (9, y.en), (1, y.sp))
      res(t, r)
      res(r, b)
      res(b, l)
      res(l, t)
      content((9, y.sp), if config == "piezo" { [3.5~kΩ] } else { [350~Ω] })
      for p in (t, r, b, l) { dot(p) }
      wire(t, (xc, y.ep))
      wire(r, (xc, y.sp))
      wire(b, (xc, y.en))
      wire(l, (1, y.sn), (xc, y.sn))
    } else if config == "current" {
      wire((xc, y.ep), (4, y.ep))
      isource((4, y.ep), (4, y.sp), label: [4–20~mA])
      wire((4, y.sp), (xc, y.sp))
      // SIG− linked to EXC− in the cable (CBL-1), so the loop returns
      // through S4.
      wire((xc, y.en), (23, y.en), (23, y.sn), (xc, y.sn))
      content((21.8, (y.en + y.sn) / 2), [Link], angle: 90deg)
    } else {
      cetz.draw.rect((0, 11), (18, 50), stroke: _s)
      content((9, 48.6), [Transmitter], anchor: "north")
      wire((xc, y.ep), (9, y.ep), (9, 50))
      vsource((5, y.sp - 3), (5, y.en + 1), label: [0–10~V])
      wire((5, y.sp - 3), (5, y.sp), (xc, y.sp))
      wire((5, y.en + 1), (5, 21), (14, 21))
      wire((xc, y.en), (14, y.en), (14, y.sn), (xc, y.sn))
      dot((14, 21))
    }

    // -- Current source: 1 mA always, 9 mA with S1, 30 mA with S2 ---------
    let current = (load-cell: [9.0~mA], piezo: [1.0~mA]).at(config, default: [30~mA limit])
    // The LT3092 feeds the branches from the east; its output resistor is
    // the parallel combination of the branches switched in.
    let yo = 67.5
    blk((64, yo - 3.5), (80, yo + 3.5), [LT3092\ #current])
    blk((85, yo - 3.5), (103, yo + 3.5), [Sensor supply\ 24~V])
    wire((80, yo), (85, yo))
    wire((b0, yo), (64, yo))
    dot((b1, yo))
    dot((b2, yo))
    res((b0, yo), (b0, y.ep), label: [301~Ω], side: "e")
    for (x, s, r, name) in ((b1, on.s1, [37.4~Ω], [S1]), (b2, on.s2, [10.2~Ω], [S2])) {
      switch((x, yo), (x, yo - 6.5), label: name, closed: s, paint: c(s))
      res((x, yo - 6.5), (x, y.ep), label: r, side: "e", paint: c(s))
    }
    wire((xc, y.ep), (b0, y.ep))
    wire((b0, y.ep), (b1, y.ep), paint: c(on.s1 or on.s2))
    wire((b1, y.ep), (b2, y.ep), paint: c(on.s2))
    dot((b0, y.ep))
    dot((b1, y.ep), paint: c(on.s1 or on.s2))

    // -- EXC−: returned to the bus through the 1.00 kΩ current-sense
    // resistor, or straight by S3; to the bank common by S4 ---------------
    let en = ink.rule
    wire((xc, y.en), (x4, y.en), paint: en)
    let yr = 21.5
    res((xs, y.en), (xs, yr), label: [1.00~kΩ], side: "e", paint: c(sense))
    switch((x3, y.en), (x3, yr), label: [S3], closed: on.s3, paint: c(on.s3))
    wire((xs, yr), (x3, yr), paint: c(exc-n))
    _text(((xs + x3) / 2, yr - 0.4), [EXC_N], anchor: "north", paint: c(exc-n))
    switch((x4, y.en), (x4, 22), label: [S4], closed: on.s4, paint: c(on.s4))
    gnd((x4, 22), label: [COM], paint: c(on.s4))
    for x in (xs, x3, xcal) { dot((x, y.en), paint: en) }

    // Shunt calibration across the SIG+ to EXC− arm, for a bridge.
    res((xcal, y.sp), (xcal, 34.5), label: [RCAL], side: "e", paint: c(bridge))
    switch((xcal, 34.5), (xcal, y.en), label: [S10], paint: c(bridge))
    dot((xcal, y.sp), paint: c(bridge))

    // -- Signal contacts ----------------------------------------------------
    // The 4–20 mA shunt across the signal contacts, closed by S8.
    res((xsh, y.sp), (xsh, 32), label: [100~Ω], side: "e", paint: c(on.s8))
    switch((xsh, 32), (xsh, 22), label: [S8], closed: on.s8, paint: c(on.s8))
    wire((xsh, 22), (xsh, y.sn), paint: c(on.s8))
    dot((xsh, y.sp), paint: c(on.s8))
    dot((xsh, y.sn), paint: c(on.s8))

    // The 10.0 kΩ series resistor; with the 2.49 kΩ bottom switched in by
    // S9 it is the top of a 5:1 divider, returned to SIG− at the contact.
    wire((xc, y.sp), (sp0, y.sp))
    res((sp0, y.sp), (sp1, y.sp), label: [10.0~kΩ])
    wire((sp1, y.sp), (xop, y.sp))
    res((xdv, y.sp), (xdv, 30), label: [2.49~kΩ], side: "e", paint: c(on.s9))
    switch((xdv, 30), (xdv, 20), label: [S9], closed: on.s9, paint: c(on.s9))
    wire((xdv, 20), (xdv, y.sn), paint: c(on.s9))
    dot((xdv, y.sp), paint: c(on.s9))
    dot((xdv, y.sn), paint: c(on.s9))
    wire((xc, y.sn), (sn0, y.sn))
    res((sn0, y.sn), (sn1, y.sn), label: [10~kΩ])
    wire((sn1, y.sn), (xop, y.sn))

    for (row, name) in ((y.ep, [EXC+]), (y.sp, [SIG+]), (y.en, [EXC−]), (y.sn, [SIG−])) {
      pin((xc, row))
      content((xc + 0.9, row + 0.5), name, anchor: "south-west")
    }

    // -- Buffers and converter input filter -------------------------------
    cap((xk, y.sp), (xk, y.sn), label: [110~pF], side: "w")
    dot((xk, y.sp))
    dot((xk, y.sn))
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

    // -- Reference: REFP from EXC+ (S5), EXC− (S6) or the bus (S7) --------
    blk((30, -24), (56, -10), [Excitation ±2.048~V\ REF5020, OPA2189,\ 2 × BUF634A])
    for (row, net, r, s, name) in (
      (y.r1, [EXC+], [10~kΩ], on.s5, [S5]),
      (y.r2, [EXC−], [237~Ω], on.s6, [S6]),
      (y.r3, none, [237~Ω], on.s7, [S7]),
    ) {
      if net == none {
        wire((56, row), (rr0, row), paint: c(s))
      } else {
        wire((58, row), (rr0, row), paint: c(s))
        _text((58.5, row + 0.4), net, anchor: "south-west", paint: c(s))
      }
      res((rr0, row), (rr1, row), label: r, paint: c(s))
      wire((rr1, row), (rs0, row), paint: c(s))
      switch((rs0, row), (rs1, row), label: name, side: "n", closed: s, paint: c(s))
      wire((rs1, row), (xb, row), paint: c(s))
      dot((xb, row), paint: c(s))
    }
    _text((57.5, y.r3 + 0.4), [EXC_P], anchor: "south-west", paint: c(on.s7))
    wire((xb, y.r1), (xb, y.r2), paint: c(on.s5))
    wire((xb, y.r2), (xb, y.r3), paint: c(on.s7))
    wire((xb, y.r2), (xa, y.r2))
    wire((56, y.rn), (rr0, y.rn))
    _text((57.5, y.rn + 0.4), [EXC_N], anchor: "south-west")
    res((rr0, y.rn), (rr1, y.rn), label: [237~Ω], side: "s")
    wire((rr1, y.rn), (xa, y.rn))
    cap((138, y.r2), (138, y.rn), label: [1.1~µF], side: "w")
    dot((138, y.r2))
    dot((138, y.rn))

    // -- Converter ----------------------------------------------------------
    cetz.draw.rect((xa, -24), (xa + 16, 44), stroke: _s, fill: white)
    content((xa + 8, (y.inp + y.inn) / 2), [ADS127L11])
    for (row, name) in ((y.inp, [AINP]), (y.inn, [AINN]), (y.r2, [REFP]), (y.rn, [REFN])) {
      content((xa + 1, row), name, anchor: "west")
    }
  }))
}

// -- EXCITATION MONITOR ------------------------------------------------------

// One channel's connection to the excitation monitor.  The dividers on the
// negative bus and the reference divider are shared by the four channels.
#let gp-monitor() = {
  // Rows: EXC+ and the excitation input's positive side, its negative side,
  // EXC− at the buffer, the return input's two sides, and REFIN.
  let (ye, yen, yb, ybp, ybn, yr) = (52, 38, 22.5, 20, 6, -10)
  // Columns: the contacts, the buffer, the dividers' series resistors, their
  // shunts on the positive and negative sides, the input capacitors and the
  // converter.
  let (xc, xop, xo) = (26, 60, 76)
  let (d0, d1, xp, xn, xk, xa) = (78, 90, 94, 104, 112, 118)

  set text(font: fonts.display, size: size.tiny, tracking: track.label)
  _fit(cetz.canvas(length: 1mm, {
    import cetz.draw: line, content

    domain((-2, 17), (20, 58), [Engine])
    domain((xc, -28), (149, 68), [General-purpose bank, isolated])

    // -- Sensor -----------------------------------------------------------
    res((9, ye), (9, yb), label: [Bridge\ 3.5~kΩ], side: "e")
    wire((9, ye), (xc, ye))
    wire((9, yb), (xc, yb))

    // -- Excitation -------------------------------------------------------
    blk((30, 57), (44, 64), [LT3092\ 1~mA])
    blk((49, 57), (65, 64), [Sensor supply\ 24~V])
    wire((44, 60.5), (49, 60.5))
    wire((xc, ye), (37, ye))
    wire((37, 57), (37, ye))
    dot((37, ye))

    for (row, name) in ((ye, [EXC+]), (yb, [EXC−])) {
      pin((xc, row))
      content((xc + 0.9, row + 0.5), name, anchor: "south-west")
    }

    // -- Buffer -----------------------------------------------------------
    wire((xc, yb), (50, yb))
    res((50, yb), (xop, yb), label: [10~kΩ])
    opamp((xop, yb), name: [¼ OPA4189])
    wire((xop + 14, ybp), (xo, ybp))
    wire((xo, ybp), (xo, yb - 9), (xop - 2, yb - 9), (xop - 2, yb - 5), (xop, yb - 5))
    dot((xo, ybp))

    // -- Dividers ---------------------------------------------------------
    // Positive sides: EXC+ divided by 25, the buffered EXC− by 2.
    wire((37, ye), (d0, ye))
    wire((xo, ybp), (d0, ybp))
    for (row, top, bot) in ((ye, [240~kΩ], [10.0~kΩ]), (ybp, [10.0~kΩ], [10.0~kΩ])) {
      res((d0, row), (d1, row), label: top)
      wire((d1, row), (xa, row))
      res((xp, row), (xp, row - 7), label: bot, side: "e")
      gnd((xp, row - 7))
      dot((xp, row))
    }
    // Negative sides and the reference, from the bus: shared.
    for (row, net, top, bot) in (
      (yen, [EXC_N], [24.0~kΩ], [1.00~kΩ]),
      (ybn, [EXC_N], [1.00~kΩ], [1.00~kΩ]),
      (yr, [EXC_P], [6.34~kΩ], [10.0~kΩ]),
    ) {
      wire((71, row), (d0, row))
      content((71.5, row + 0.4), net, anchor: "south-west")
      res((d0, row), (d1, row), label: top, side: "s")
      wire((d1, row), (xa, row))
      res((xn, row), (xn, row - 7), label: bot, side: "e")
      gnd((xn, row - 7))
      dot((xn, row))
    }
    content((71, yr - 10.5), align(left)[Bus and reference dividers\ shared by the four channels], anchor: "north-west")

    // Input filter capacitors across each pair.
    for (p, n) in ((ye, yen), (ybp, ybn)) {
      cap((xk, p), (xk, n), label: [10~nF], side: "w")
      dot((xk, p))
      dot((xk, n))
    }

    // -- Reference block ----------------------------------------------------
    blk((30, -24), (56, -10), [Excitation ±2.048~V\ REF5020, OPA2189,\ 2 × BUF634A])
    for (row, name) in ((-14, [EXC_P]), (-20, [EXC_N])) {
      wire((56, row), (59, row))
      content((59.5, row), name, anchor: "west")
    }

    // -- Converter and isolation --------------------------------------------
    cetz.draw.rect((xa, -15), (xa + 22, 56), stroke: _s, fill: white)
    content((xa + 12, 29), [ADS131M08])
    for (row, name) in ((ye, [AIN0P]), (yen, [AIN0N]), (ybp, [AIN1P]), (ybn, [AIN1N]), (yr, [REFIN])) {
      content((xa + 1, row), name, anchor: "west")
    }
    line((xa + 22, 21), (144, 21), stroke: _bus, mark: _arrow)
    blk((144, 16), (154, 26), [Isolator])
    line((154, 21), (159, 21), stroke: _bus, mark: _arrow)
    content((159.8, 21), align(left)[ECU MCU\ board], anchor: "west")
  }))
}
