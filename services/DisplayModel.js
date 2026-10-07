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
