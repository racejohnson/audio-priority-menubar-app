// Art for round 3. Everything here is settled: the DJI Mic Mini glyph (Solid +
// clip), the Soft capsule and the Peaks app icon. One source for build.mjs
// (which writes ../svg/) and index.html (inlined with `export` stripped).
//
// Device glyphs are real SF Symbols, rendered by sf-export.swift into
// assets/sf.json as white-on-clear PNGs and used as masks.

let SF = {};
export function setSF(data) { SF = data; }
let uid = 0;
const nextId = (p) => `${p}${++uid}`;
const n2 = (v) => +v.toFixed(3);

// ---------------------------------------------------------------------------
// DJI Mic Mini transmitter on an 18 pt grid, after Race's reference drawing:
// a rounded-square body with three slots centred near the top, and a sliver
// of the magnetic clip behind the top-left corner. `small` is the cut for
// 15 pt and under: wider slots and a wider gap to the clip.
// ---------------------------------------------------------------------------
const rr = (x, y, w, h, r) =>
  `M${n2(x + r)} ${n2(y)}H${n2(x + w - r)}A${r} ${r} 0 0 1 ${n2(x + w)} ${n2(y + r)}V${n2(y + h - r)}A${r} ${r} 0 0 1 ${n2(x + w - r)} ${n2(y + h)}H${n2(x + r)}A${r} ${r} 0 0 1 ${n2(x)} ${n2(y + h - r)}V${n2(y + r)}A${r} ${r} 0 0 1 ${n2(x + r)} ${n2(y)}Z`;

function slots(cx, cy, small) {
  const w = small ? 1.3 : 0.95, h = small ? 3.0 : 2.5, gap = small ? 2.45 : 1.95;
  return [-1, 0, 1].map((i) => rr(cx + i * gap - w / 2, cy - h / 2, w, h, w / 2)).join("");
}

/** Inner SVG markup for the glyph in currentColor, 18 x 18 box. */
export function djiMarkup(small = false) {
  const id = nextId("k"), gap = small ? 1.15 : 0.9;
  return `<clipPath id="${id}"><path clip-rule="evenodd" d="M0 0H18V18H0Z${rr(3.9 - gap, 4.1 - gap, 12.1 + gap * 2, 11.9 + gap * 2, 3.5 + gap)}"/></clipPath>`
    + `<path d="${rr(1.9, 1.9, 12.1, 11.9, 3.5)}" fill="currentColor" clip-path="url(#${id})"/>`
    + `<path fill-rule="evenodd" d="${rr(3.9, 4.1, 12.1, 11.9, 3.5)}${slots(9.95, 6.6, small)}" fill="currentColor"/>`;
}

export function djiSVG({ size = 18, small = size <= 15, grid = false } = {}) {
  const guides = grid
    ? `<g stroke="#ff2d55" stroke-opacity=".35" stroke-width=".05" fill="none">${Array.from({ length: 19 }, (_, i) => `<path d="M${i} 0V18M0 ${i}H18"/>`).join("")}</g><rect x="1" y="1" width="16" height="16" fill="none" stroke="#0a84ff" stroke-opacity=".5" stroke-width=".08" stroke-dasharray=".3 .3"/>`
    : "";
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 18 18">${guides}${djiMarkup(small)}</svg>`;
}

// ---------------------------------------------------------------------------
// The Capsule (Soft finish): output on the left, input on the right, in one
// template image 48 x 18 pt. Auto on: a 16% fill with solid glyphs. Auto off:
// the fill goes solid and the glyphs are cut out of it.
// ---------------------------------------------------------------------------
const CAP_H = 18, SLOT = 17, PAD = 4.5, MID = 5, DJI_CAP = 15;
export const CAP_W = PAD * 2 + SLOT * 2 + MID;

function capGlyph(key, x0) {
  if (key === "dji") {
    const s = DJI_CAP / 18;
    return `<g transform="translate(${n2(x0 + (SLOT - DJI_CAP) / 2)} ${n2((CAP_H - DJI_CAP) / 2)}) scale(${n2(s)})">${djiMarkup(true)}</g>`;
  }
  const e = SF[key].cap;
  return `<image href="${e.uri}" x="${n2(x0 + (SLOT - e.w) / 2)}" y="${n2((CAP_H - e.h) / 2)}" width="${e.w}" height="${e.h}"/>`;
}

/** Returns the capsule as an SVG string. out/inp are SF Symbol names or "dji". */
export function capsule(out, inp, { manual = false } = {}) {
  const W = CAP_W, H = CAP_H, id = nextId("c");
  const glyphs = `<g color="#fff">${capGlyph(out, PAD)}${capGlyph(inp, PAD + SLOT + MID)}</g>`;
  const box = `maskUnits="userSpaceOnUse" x="0" y="0" width="${W}" height="${H}"`;
  const body = manual
    ? `<filter id="${id}f" x="0" y="0" width="${W}" height="${H}" filterUnits="userSpaceOnUse"><feColorMatrix type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 1 0"/></filter>`
      + `<mask id="${id}" ${box}><rect width="${W}" height="${H}" fill="#fff"/><g filter="url(#${id}f)">${glyphs}</g></mask>`
      + `<rect width="${W}" height="${H}" rx="${H / 2}" fill="currentColor" mask="url(#${id})"/>`
    : `<mask id="${id}" ${box}>${glyphs}</mask><rect width="${W}" height="${H}" rx="${H / 2}" fill="currentColor" fill-opacity=".16"/><rect width="${W}" height="${H}" fill="currentColor" mask="url(#${id})"/>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${body}</svg>`;
}

// ---------------------------------------------------------------------------
// App icon: Peaks, a segmented stereo meter. Race's family construction: an
// 824 pt tile on a 1024 canvas (DayNight's tile path), one bold glyph, a
// separate heavier drawing for 16/32 px, dark and tinted renditions.
// Left channel (output) is full and runs blue to ice; right channel (input)
// sits at four of six in ice.
// ---------------------------------------------------------------------------
const TILE = "M382.8,100 L641.2,100 C722.63,100 763.34,100 807.17,113.86 C855.03,131.28 892.72,168.97 910.14,216.83 C924,260.66 924,301.37 924,382.8 L924,641.2 C924,722.63 924,763.34 910.14,807.17 C892.72,855.03 855.03,892.72 807.17,910.14 C763.34,924 722.63,924 641.2,924 L382.8,924 C301.37,924 260.66,924 216.83,910.14 C168.97,892.72 131.28,855.03 113.86,807.17 C100,763.34 100,722.63 100,641.2 L100,382.8 C100,301.37 100,260.66 113.86,216.83 C131.28,168.97 168.97,131.28 216.83,113.86 C260.66,100 301.37,100 382.8,100 Z";
const TILE_S = "M11.63,2 L20.37,2 C23.14,2 24.53,2 26.02,2.47 C27.65,3.07 28.93,4.35 29.53,5.98 C30,7.47 30,8.86 30,11.63 L30,20.37 C30,23.14 30,24.53 29.53,26.02 C28.93,27.65 27.65,28.93 26.02,29.53 C24.53,30 23.14,30 20.37,30 L11.63,30 C8.86,30 7.47,30 5.98,29.53 C4.35,28.93 3.07,27.65 2.47,26.02 C2,24.53 2,23.14 2,20.37 L2,11.63 C2,8.86 2,7.47 2.47,5.98 C3.07,4.35 4.35,3.07 5.98,2.47 C7.47,2 8.86,2 11.63,2 Z";

const PAL = {
  light: { tile: ["#2c62e0", "#0a1a52"], left: ["#2f74f0", "#4186fb", "#5b9dff", "#7db5ff", "#a6d0ff", "#d8eaff"], right: "#eef6ff", dim: "rgba(214,230,255,.22)", glow: "#4f9bff" },
  dark: { tile: ["#16337f", "#040b22"], left: ["#2a66dc", "#3a78ec", "#538ffa", "#74a9ff", "#9cc6ff", "#cfe3ff"], right: "#e2eeff", dim: "rgba(170,200,255,.18)", glow: "#3d86ff" },
  tinted: { tile: ["#4a4a4e", "#1f1f22"], left: Array(6).fill("#ffffff"), right: "#ffffff", dim: "rgba(255,255,255,.3)", glow: null },
};
const lg = (id, [a, b]) => `<linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${a}"/><stop offset="1" stop-color="${b}"/></linearGradient>`;

export function appIcon(mode = "light") {
  const p = nextId("i"), c = PAL[mode];
  const W = 196, Hs = 60, step = 84, x1 = 512 - 20 - W, x2 = 512 + 20, y0 = 512 + (5 * step + Hs) / 2 - Hs;
  const seg = (x, i, fill) => `<rect x="${x}" y="${y0 - i * step}" width="${W}" height="${Hs}" rx="21" fill="${fill}"/>`;
  // A soft top-light on each lit segment, so they read as glass and not flat bars.
  const shine = (x, i) => (mode === "tinted" ? "" : `<rect x="${x + 6}" y="${y0 - i * step + 5}" width="${W - 12}" height="${Hs / 2 - 4}" rx="15" fill="url(#${p}g)"/>`);
  let segs = "", glow = "";
  for (let i = 0; i < 6; i++) {
    segs += seg(x1, i, c.left[i]) + shine(x1, i);
    segs += i < 4 ? seg(x2, i, c.right) + shine(x2, i) : seg(x2, i, c.dim);
  }
  if (c.glow) glow = `<g filter="url(#${p}b)"><rect x="${x1}" y="${y0 - 5 * step}" width="${W}" height="${5 * step + Hs}" rx="30" fill="${c.glow}" opacity=".5"/><rect x="${x2}" y="${y0 - 3 * step}" width="${W}" height="${3 * step + Hs}" rx="30" fill="#bcd9ff" opacity=".22"/></g>`;
  const defs = lg(`${p}t`, c.tile)
    + `<linearGradient id="${p}g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".38"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>`
    + `<clipPath id="${p}c"><path d="${TILE}"/></clipPath>`
    + `<filter id="${p}b" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="46"/></filter>`
    + `<filter id="${p}s" x="-10%" y="-10%" width="120%" height="120%"><feGaussianBlur stdDeviation="14"/></filter>`
    + `<linearGradient id="${p}h" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".12"/><stop offset=".45" stop-color="#fff" stop-opacity="0"/></linearGradient>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><defs>${defs}</defs>`
    + `<path d="${TILE}" transform="translate(0,12)" fill="#000" opacity=".28" filter="url(#${p}s)"/>`
    + `<g clip-path="url(#${p}c)"><rect x="100" y="100" width="824" height="824" fill="url(#${p}t)"/>${glow}${segs}<rect x="100" y="100" width="824" height="824" fill="url(#${p}h)"/></g>`
    + `<path d="${TILE}" fill="none" stroke="#fff" stroke-opacity=".14" stroke-width="3"/></svg>`;
}

/** The 16/32 px drawing: three heavy segments a side, not a downscale. */
export function appIconSmall(mode = "light") {
  const p = nextId("s"), c = PAL[mode];
  const seg = (x, i, fill) => `<rect x="${x}" y="${19.7 - i * 5.7}" width="8.4" height="4.1" rx="1.5" fill="${fill}"/>`;
  const g = [0, 1, 2].map((i) => seg(6.8, i, c.left[[0, 3, 5][i]]) + seg(16.8, i, i < 2 ? c.right : c.dim)).join("");
  return `<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><defs>${lg(`${p}t`, c.tile)}<clipPath id="${p}c"><path d="${TILE_S}"/></clipPath></defs><g clip-path="url(#${p}c)"><rect width="32" height="32" fill="url(#${p}t)"/>${g}</g></svg>`;
}
