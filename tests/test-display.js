// node tests/test-display.js -- unit tests for services/DisplayModel.js, the
// pure half of Settings › Display: hyprmoncfg's IPC envelopes and status,
// hyprctl's monitors, and the arrangement canvas geometry. Fixtures in
// tests/fixtures/display come from a real two-display machine (serial scrubbed).
const fs = require("fs"), vm = require("vm"), path = require("path"), assert = require("assert")
const src = fs.readFileSync(path.join(__dirname, "../services/DisplayModel.js"), "utf8").replace(/^\.pragma.*$/m, "")
const ctx = {}
vm.runInNewContext(src + "\nthis.D = { parseEnvelope, request, fromStatus, fromHypr, logicalSize, fit, rects, scaleLabel }", ctx)
const D = ctx.D
const fx = n => JSON.parse(fs.readFileSync(path.join(__dirname, "fixtures/display", n), "utf8"))
let failed = 0
function test(name, fn) {
  try { fn(); console.log("  PASS", name) } catch (e) { failed++; console.log("  FAIL", name, "\n   ", e.message) }
}
const plain = v => JSON.parse(JSON.stringify(v))

test("a response envelope is read", () => {
  const e = D.parseEnvelope('{"type":"response","protocol_version":1,"id":"3","result":{"ok":true}}')
  assert.strictEqual(e.type, "response"); assert.strictEqual(e.id, "3"); assert.strictEqual(e.result.ok, true)
})
test("an event envelope is read", () => {
  const e = D.parseEnvelope('{"type":"event","protocol_version":1,"event":"status","data":{"x":1}}')
  assert.strictEqual(e.event, "status"); assert.strictEqual(e.data.x, 1)
})
test("another protocol version or junk is ignored", () => {
  assert.strictEqual(D.parseEnvelope('{"type":"response","protocol_version":2,"id":"1","result":{}}'), null)
  assert.strictEqual(D.parseEnvelope("not json"), null)
})
test("a request is one line of JSON", () => {
  const line = D.request("7", "status", {})
  assert.ok(line.endsWith("\n")); assert.deepStrictEqual(plain(JSON.parse(line)), { type: "request", protocol_version: 1, id: "7", method: "status", params: {} })
})
test("monitors from hyprmoncfg's status", () => {
  const m = D.fromStatus(fx("status.json"))
  assert.strictEqual(m.length, 2)
  const e = m.find(x => x.name === "eDP-1")
  assert.strictEqual(e.label, "BOE 0x0910"); assert.strictEqual(e.refresh, 144); assert.strictEqual(e.scale, 1.25)
  assert.strictEqual(e.lw, 1536); assert.strictEqual(e.lh, 864); assert.strictEqual(e.internal, true)
})
test("monitors from hyprctl (no hyprmoncfg)", () => {
  const m = D.fromHypr(fx("hyprctl-monitors.json"))
  assert.strictEqual(m.length, 2)
  const h = m.find(x => x.name === "HDMI-A-1")
  assert.strictEqual(h.lw, 1536); assert.strictEqual(h.refresh, 60); assert.strictEqual(h.enabled, true)
  assert.ok(h.modes.length >= 1)
})
test("a turned display swaps its logical width and height", () => {
  assert.deepStrictEqual(plain(D.logicalSize({ width: 1920, height: 1080, scale: 1, transform: 1 })), { w: 1080, h: 1920 })
  assert.deepStrictEqual(plain(D.logicalSize({ width: 1920, height: 1080, scale: 2, transform: 6 })), { w: 960, h: 540 })
})
test("the arrangement fits the canvas, centred", () => {
  const m = D.fromStatus(fx("status.json"))
  const f = D.fit(m, 600, 300, 20)
  const r = D.rects(m, f)
  const minX = Math.min(...r.map(x => x.x)), maxX = Math.max(...r.map(x => x.x + x.w))
  assert.ok(minX >= 20 - 0.5 && maxX <= 580 + 0.5, "inside the padding")
  assert.ok(Math.abs((minX + maxX) / 2 - 300) < 1, "centred")
  const hdmi = r.find(x => x.name === "HDMI-A-1"), edp = r.find(x => x.name === "eDP-1")
  assert.ok(hdmi.x < edp.x, "HDMI is left of the laptop, as configured")
})
test("scale labels", () => {
  assert.strictEqual(D.scaleLabel(1.25), "125%"); assert.strictEqual(D.scaleLabel(1.33333), "133%"); assert.strictEqual(D.scaleLabel(2), "200%")
})

console.log(failed ? `${failed} failed` : "all passed")
process.exit(failed ? 1 : 0)
