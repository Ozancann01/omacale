.pragma library

// The pure half of Settings › Display: hyprmoncfg's IPC (protocol v1,
// newline-delimited JSON over $XDG_RUNTIME_DIR/hyprmoncfgd.sock, as its own
// Omarchy plugin speaks it), its status document, hyprctl's monitors for when
// hyprmoncfg isn't there, and the arrangement canvas. Plain JS, so
// tests/test-display.js runs it under node.

var PROTOCOL = 1

function parseEnvelope(line) {
  var e
  try { e = JSON.parse(line) } catch (err) { return null }
  if (!e || e.protocol_version !== PROTOCOL) return null
  return e
}

function request(id, method, params) {
  return JSON.stringify({ type: "request", protocol_version: PROTOCOL, id: String(id), method: method, params: params || {} }) + "\n"
}

// Logical size: the mode over the scale, turned for a 90/270 degree transform
// (transforms 1, 3, 5, 7).
function logicalSize(m) {
  var s = m.scale > 0 ? m.scale : 1
  var w = Math.round(m.width / s), h = Math.round(m.height / s)
  return (m.transform % 2 === 1) ? { w: h, h: w } : { w: w, h: h }
}

function row(o) {
  var sz = logicalSize(o)
  return {
    key: o.key || o.name, name: o.name, label: o.label || o.name, make: o.make || "", model: o.model || "",
    width: o.width, height: o.height, refresh: Math.round((o.refresh || 0) * 100) / 100,
    x: o.x || 0, y: o.y || 0, scale: o.scale || 1, transform: o.transform || 0,
    lw: sz.w, lh: sz.h, internal: !!o.internal, focused: !!o.focused, enabled: o.enabled !== false,
    mirrorOf: o.mirrorOf || "", modes: o.modes || []
  }
}

// hyprmoncfg status --json / the "status" event's monitors.
function fromStatus(status) {
  var list = (status && status.monitors) || []
  return list.map(function (m) {
    return row({ key: m.key, name: m.name, label: m.description, make: m.make, model: m.model, width: m.width, height: m.height,
      refresh: m.refresh_rate, x: m.x, y: m.y, scale: m.scale, transform: m.transform, internal: m.internal,
      focused: m.focused, enabled: m.enabled, mirrorOf: m.mirror_of })
  })
}

// hyprctl monitors all -j, when hyprmoncfg isn't managing the displays.
function fromHypr(list) {
  return (list || []).map(function (m) {
    return row({ name: m.name, label: m.description, make: m.make, model: m.model, width: m.width, height: m.height,
      refresh: m.refreshRate, x: m.x, y: m.y, scale: m.scale, transform: m.transform,
      internal: /^(eDP|LVDS|DSI)/.test(m.name), focused: m.focused, enabled: !m.disabled,
      mirrorOf: m.mirrorOf && m.mirrorOf !== "none" ? m.mirrorOf : "", modes: m.availableModes })
  })
}

// Scale and offset that fit every enabled display's logical rect into a
// w x h canvas with `pad` around, centred.
function fit(monitors, w, h, pad) {
  var on = monitors.filter(function (m) { return m.enabled })
  if (!on.length) return { k: 1, ox: 0, oy: 0 }
  var x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity
  on.forEach(function (m) { x0 = Math.min(x0, m.x); y0 = Math.min(y0, m.y); x1 = Math.max(x1, m.x + m.lw); y1 = Math.max(y1, m.y + m.lh) })
  var bw = Math.max(1, x1 - x0), bh = Math.max(1, y1 - y0)
  var k = Math.min((w - pad * 2) / bw, (h - pad * 2) / bh)
  return { k: k, ox: (w - bw * k) / 2 - x0 * k, oy: (h - bh * k) / 2 - y0 * k }
}

function rects(monitors, f) {
  return monitors.filter(function (m) { return m.enabled }).map(function (m) {
    return { key: m.key, name: m.name, x: m.x * f.k + f.ox, y: m.y * f.k + f.oy, w: m.lw * f.k, h: m.lh * f.k }
  })
}

function scaleLabel(s) { return Math.round(s * 100) + "%" }

// ---------------------------------------------------------------- editing
// hyprmoncfg's editor_state: `profile.outputs` is the layout being edited
// (the daemon snaps and reflows it in edit_profile, so nothing here does
// geometry rules), `displays` the per-display facts (modes, sharp scales,
// physical size). Rows look like fromStatus's, plus what the editor needs.
function fromEditor(doc) {
  var outs = (doc && doc.profile && doc.profile.outputs) || []
  var meta = {}
  ;((doc && doc.displays) || []).forEach(function (d) { meta[d.key] = d })
  return outs.map(function (o) {
    var d = meta[o.key] || {}
    var r = row({ key: o.key, name: o.name, label: o.description, make: o.make, model: o.model, width: o.width, height: o.height,
      refresh: o.refresh, x: o.x, y: o.y, scale: o.scale, transform: o.transform, internal: d.internal,
      focused: d.focused, enabled: o.enabled, mirrorOf: o.mirror_of, modes: d.available_modes || [] })
    r.mode = o.mode || ""
    r.vrr = o.vrr || 0
    r.bitdepth = o.bitdepth || 8
    r.cm = o.cm || ""
    r.scaleOptions = (d.scale_options || []).map(Number)
    r.physicalWidth = d.physical_width || 0
    return r
  })
}

function parseMode(mode) {
  var m = /^(\d+)x(\d+)@([\d.]+)Hz$/.exec(String(mode || ""))
  return m ? { w: Number(m[1]), h: Number(m[2]), hz: Number(m[3]), res: m[1] + "x" + m[2], mode: mode } : null
}

// Resolutions, most pixels first, each with its refresh rates, fastest first.
function modeGroups(modes) {
  var by = {}, out = []
  ;(modes || []).forEach(function (s) {
    var p = parseMode(s)
    if (!p) return
    if (!by[p.res]) { by[p.res] = { res: p.res, w: p.w, h: p.h, rates: [] }; out.push(by[p.res]) }
    if (!by[p.res].rates.some(function (r) { return r.mode === s })) by[p.res].rates.push({ mode: s, hz: p.hz })
  })
  out.forEach(function (g) { g.rates.sort(function (a, b) { return b.hz - a.hz }) })
  return out.sort(function (a, b) { return b.w * b.h - a.w * a.h || b.w - a.w })
}

// The mode at `res` whose refresh is nearest `hz` ("" if `res` has none).
function modeFor(modes, res, hz) {
  var g = modeGroups(modes).find(function (x) { return x.res === res })
  if (!g) return ""
  var best = g.rates[0]
  g.rates.forEach(function (r) { if (Math.abs(r.hz - hz) < Math.abs(best.hz - hz)) best = r })
  return best.mode
}

function refreshLabel(hz) { return (Math.round(hz * 100) / 100).toString().replace(/\.0+$/, "") + " Hz" }

// hyprmoncfg has no "auto" scale, only the scales that come out sharp on the
// display. Recommend the sharp one nearest the display's density over a
// comfortable one (a laptop sits closer, so it gets a little more), never
// under 1. Without a physical size, 1.
function recommendedScale(d) {
  var opts = (d.scaleOptions || []).filter(function (v) { return v >= 1 })
  if (!d.physicalWidth || !opts.length) return 1
  var ppi = d.width / (d.physicalWidth / 25.4)
  var want = Math.max(1, ppi / (d.internal ? 115 : 110))
  var best = opts[0]
  opts.forEach(function (v) { if (Math.abs(v - want) < Math.abs(best - want)) best = v })
  return best
}

// Hyprland transforms: 0-3 turn by 90 degrees, 4-7 are the same flipped.
function transformOf(rotation, flipped) { return (rotation % 4) + (flipped ? 4 : 0) }
function rotationOf(t) { return (t || 0) % 4 }
function flippedOf(t) { return (t || 0) >= 4 }

// A profile's layout as a string that ignores key order (dirty checks).
function signature(profile) {
  var keys = ["key", "enabled", "mode", "x", "y", "scale", "transform", "mirror_of", "vrr", "bitdepth", "cm"]
  return JSON.stringify(((profile && profile.outputs) || []).map(function (o) {
    return keys.map(function (k) { return o[k] === undefined ? null : o[k] })
  }))
}

function secondsLeft(deadline, now) {
  var at = Date.parse(deadline)
  return isFinite(at) ? Math.max(0, Math.ceil((at - now) / 1000)) : 0
}

// A preview is Omacale's to confirm only if Omacale started it (its id is in
// the runtime file); hyprmoncfg's own panel confirms its own and the
// "reclaimable" ones, so both never ask about the same preview.
function ownsPreview(pending, id) {
  return !!(pending && id && String(pending.transaction_id || "") === id)
}

function canDisable(rows, key) {
  return rows.some(function (m) { return m.enabled && m.key !== key })
}

// Canvas point (a box's top-left) back to layout coordinates.
function toLayout(x, y, f) {
  return { x: Math.round((x - f.ox) / f.k), y: Math.round((y - f.oy) / f.k) }
}
