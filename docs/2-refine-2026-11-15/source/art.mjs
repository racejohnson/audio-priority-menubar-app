// Art for round 2: the DJI Mic Mini glyph, the Capsule menu-bar glyph and the
// app icons. One source for build.mjs (which writes ../svg/) and index.html
// (build.mjs inlines this file with `export` stripped).
//
// Device glyphs are real SF Symbols, rendered by sf-export.swift into
// assets/sf.json as white-on-clear PNGs and used as masks. Only the DJI glyph
// is drawn here.

let SF = {};
export function setSF(data) { SF = data; }
let uid = 0;
const nextId = (p) => `${p}${++uid}`;
const n2 = (v) => +v.toFixed(3);

// ---------------------------------------------------------------------------
// DJI Mic Mini transmitter, on an 18 pt grid, after Race's reference drawing:
// a rounded-square body with three vertical slots centred near the top.
// Proportions measured from the reference's front unit: corner radius 0.27 of
// the width, slots centred at 0.2 of the height, 0.19 tall, 0.14 apart.
// `small` is the cut for 12 pt and under: wider, taller slots.
// ---------------------------------------------------------------------------
const rr = (x, y, w, h, r) =>
  `M${n2(x + r)} ${n2(y)}H${n2(x + w - r)}A${r} ${r} 0 0 1 ${n2(x + w)} ${n2(y + r)}V${n2(y + h - r)}A${r} ${r} 0 0 1 ${n2(x + w - r)} ${n2(y + h)}H${n2(x + r)}A${r} ${r} 0 0 1 ${n2(x)} ${n2(y + h - r)}V${n2(y + r)}A${r} ${r} 0 0 1 ${n2(x + r)} ${n2(y)}Z`;

function slots(cx, cy, small) {
  const w = small ? 1.3 : 0.95, h = small ? 3.0 : 2.5, gap = small ? 2.45 : 1.95;
  return [-1, 0, 1].map((i) => rr(cx + i * gap - w / 2, cy - h / 2, w, h, w / 2)).join("");
}

export const DJI_OPTIONS = [
  { id: "solid", name: "Solid", line: "Your reference's front unit on its own: a filled rounded square with three slots cut out. Sits with the filled symbols (airpods.pro, hifispeaker.fill)." },
  { id: "outline", name: "Outline", line: "The same body as a 1.4 pt outline with three solid slots. Matches the outline symbols beside it in the capsule (laptopcomputer, display, mic)." },
  { id: "clip", name: "Solid + clip", line: "Solid, with the magnetic clip showing as a sliver behind the top-left corner: the overlap in your reference, cut down to one unit. Less like an app tile." },
];

/** Inner SVG markup for the glyph in currentColor, 18 x 18 box. */
export function djiMarkup(variant = "solid", small = false) {
  const F = 'fill="currentColor"';
  if (variant === "outline") {
    const w = small ? 1.7 : 1.4;
    return `<path d="${rr(2.2 + w / 2, 2.4 + w / 2, 13.6 - w, 13.4 - w, 3.9 - w / 2)}" fill="none" stroke="currentColor" stroke-width="${w}"/><path d="${slots(9, 6.2, small)}" ${F}/>`;
  }
  if (variant === "clip") {
    const id = nextId("k"), gap = small ? 1.15 : 0.9;
    const front = rr(3.9, 4.1, 12.1, 11.9, 3.5);
    return `<clipPath id="${id}"><path clip-rule="evenodd" d="M0 0H18V18H0Z${rr(3.9 - gap, 4.1 - gap, 12.1 + gap * 2, 11.9 + gap * 2, 3.5 + gap)}"/></clipPath>`
      + `<path d="${rr(1.9, 1.9, 12.1, 11.9, 3.5)}" ${F} clip-path="url(#${id})"/>`
      + `<path fill-rule="evenodd" d="${front}${slots(9.95, 6.6, small)}" ${F}/>`;
  }
  return `<path fill-rule="evenodd" d="${rr(2.2, 2.4, 13.6, 13.4, 3.9)}${slots(9, 5.3, small)}" ${F}/>`;
}

export function djiSVG(variant = "solid", { size = 18, small = size <= 15, grid = false } = {}) {
  const guides = grid
    ? `<g stroke="#ff2d55" stroke-opacity=".35" stroke-width=".05" fill="none">${Array.from({ length: 19 }, (_, i) => `<path d="M${i} 0V18M0 ${i}H18"/>`).join("")}</g><rect x="1" y="1" width="16" height="16" fill="none" stroke="#0a84ff" stroke-opacity=".5" stroke-width=".08" stroke-dasharray=".3 .3"/>`
    : "";
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 18 18">${guides}${djiMarkup(variant, small)}</svg>`;
}

// ---------------------------------------------------------------------------
// The Capsule: output on the left, input on the right, in one template image.
// Auto on: an outlined (or softly filled) capsule with solid glyphs.
// Auto off (manual): the capsule fills and the glyphs are cut out of it.
// ---------------------------------------------------------------------------
export const CAPSULE_STYLES = [
  { id: "divided", name: "Divided", line: "Outline with a hairline between the two halves, as in round 1. The split between out and in is explicit." },
  { id: "clean", name: "Clean", line: "Outline only, no hairline, the halves 2 pt closer. Quieter and 3 pt narrower; position alone says which is which." },
  { id: "soft", name: "Soft", line: "No outline: a 16% fill, like the pill behind macOS's own status indicators. Lightest in the bar; the fill goes solid in manual." },
];
const CAP_H = 18, SLOT = 17, DJI_CAP = 15;

function capGlyph(key, x0, dji) {
  if (key === "dji") {
    const s = DJI_CAP / 18;
    return `<g transform="translate(${n2(x0 + (SLOT - DJI_CAP) / 2)} ${n2((CAP_H - DJI_CAP) / 2)}) scale(${n2(s)})">${djiMarkup(dji, true)}</g>`;
  }
  const e = SF[key].cap;
  return `<image href="${e.uri}" x="${n2(x0 + (SLOT - e.w) / 2)}" y="${n2((CAP_H - e.h) / 2)}" width="${e.w}" height="${e.h}"/>`;
}

/** Returns {svg, width}. out/inp are SF Symbol names or "dji". */
export function capsule(style, out, inp, { manual = false, dji = "solid" } = {}) {
  const pad = style === "clean" ? 4 : 4.5, mid = style === "clean" ? 3 : 5;
  const W = pad * 2 + SLOT * 2 + mid, H = CAP_H, id = nextId("c");
  const glyphs = `<g color="#fff">${capGlyph(out, pad, dji)}${capGlyph(inp, pad + SLOT + mid, dji)}</g>`;
  const dx = pad + SLOT + mid / 2;
  const box = `maskUnits="userSpaceOnUse" x="0" y="0" width="${W}" height="${H}"`;
  let body;
  if (manual) {
    const hair = style === "divided" ? `<path d="M${dx} 5V13" stroke="#000" stroke-width="1" stroke-linecap="round"/>` : "";
    body = `<filter id="${id}f" x="0" y="0" width="${W}" height="${H}" filterUnits="userSpaceOnUse"><feColorMatrix type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 1 0"/></filter>`
      + `<mask id="${id}" ${box}><rect width="${W}" height="${H}" fill="#fff"/><g filter="url(#${id}f)">${glyphs}</g>${hair}</mask>`
      + `<rect width="${W}" height="${H}" rx="${H / 2}" fill="currentColor" mask="url(#${id})"/>`;
  } else {
    const shell = style === "soft"
      ? `<rect width="${W}" height="${H}" rx="${H / 2}" fill="currentColor" fill-opacity=".16"/>`
      : `<rect x=".55" y=".55" width="${W - 1.1}" height="${H - 1.1}" rx="${(H - 1.1) / 2}" fill="none" stroke="currentColor" stroke-width="1.1"/>`;
    const hair = style === "divided" ? `<path d="M${dx} 5V13" stroke="currentColor" stroke-width="1" stroke-linecap="round" opacity=".4"/>` : "";
    body = `<mask id="${id}" ${box}>${glyphs}</mask>${shell}${hair}<rect width="${W}" height="${H}" fill="currentColor" mask="url(#${id})"/>`;
  }
  return { svg: `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${body}</svg>`, width: W };
}

// ---------------------------------------------------------------------------
// App icons. Fresh drawings with an audio-level feel, none of them the
// five-bar equalizer. Race's family construction: 824 pt tile on a 1024
// canvas (DayNight's tile path), one bold glyph, a separate heavier drawing
// for 16/32 px, dark and tinted renditions.
// ---------------------------------------------------------------------------
const TILE = "M382.8,100 L641.2,100 C722.63,100 763.34,100 807.17,113.86 C855.03,131.28 892.72,168.97 910.14,216.83 C924,260.66 924,301.37 924,382.8 L924,641.2 C924,722.63 924,763.34 910.14,807.17 C892.72,855.03 855.03,892.72 807.17,910.14 C763.34,924 722.63,924 641.2,924 L382.8,924 C301.37,924 260.66,924 216.83,910.14 C168.97,892.72 131.28,855.03 113.86,807.17 C100,763.34 100,722.63 100,641.2 L100,382.8 C100,301.37 100,260.66 113.86,216.83 C131.28,168.97 168.97,131.28 216.83,113.86 C260.66,100 301.37,100 382.8,100 Z";
const TILE_S = "M11.63,2 L20.37,2 C23.14,2 24.53,2 26.02,2.47 C27.65,3.07 28.93,4.35 29.53,5.98 C30,7.47 30,8.86 30,11.63 L30,20.37 C30,23.14 30,24.53 29.53,26.02 C28.93,27.65 27.65,28.93 26.02,29.53 C24.53,30 23.14,30 20.37,30 L11.63,30 C8.86,30 7.47,30 5.98,29.53 C4.35,28.93 3.07,27.65 2.47,26.02 C2,24.53 2,23.14 2,20.37 L2,11.63 C2,8.86 2,7.47 2.47,5.98 C3.07,4.35 4.35,3.07 5.98,2.47 C7.47,2 8.86,2 11.63,2 Z";

const PAL = {
  light: { tile: ["#2a5fdc", "#0a1a52"], lit: ["#b4dcff", "#3f8bff"], ice: ["#ffffff", "#cfe6ff"], dim: "rgba(214,230,255,.28)", ink: "#0a1a52", glow: "#4f9bff" },
  dark: { tile: ["#16337f", "#040b22"], lit: ["#96caff", "#2f74f0"], ice: ["#f2f8ff", "#b4d4ff"], dim: "rgba(170,200,255,.24)", ink: "#040b22", glow: "#3d86ff" },
  tinted: { tile: ["#4a4a4e", "#1f1f22"], lit: ["#ffffff", "#e9e9e9"], ice: ["#ffffff", "#f4f4f4"], dim: "rgba(255,255,255,.4)", ink: "#2a2a2d", glow: null },
};

export const ICON_OPTIONS = [
  { id: "selector", name: "Selector", line: "A source-selector knob pointing at the lit top position: pick the first available. One bold glyph, hi-fi rather than equalizer." },
  { id: "faders", name: "Faders", line: "Two channel strips, output in blue and input in ice, each at its own level. The in/out pair the menu-bar capsule shows." },
  { id: "needle", name: "Needle", line: "A VU meter: lit scale, needle and hub. The most 'audio level' of the set without a single bar." },
  { id: "capsule", name: "Capsule", line: "The menu-bar capsule itself, speaker on the left and microphone on the right. The icon and the status item become one mark." },
  { id: "peaks", name: "Peaks", line: "A segmented stereo meter, one channel full and one part-way. Closest in spirit to the icon you liked, but its own drawing." },
];

const lg = (id, [a, b], x2 = 0, y2 = 1) => `<linearGradient id="${id}" x1="0" y1="0" x2="${x2}" y2="${y2}"><stop offset="0" stop-color="${a}"/><stop offset="1" stop-color="${b}"/></linearGradient>`;
const polar = (cx, cy, r, deg) => [n2(cx + r * Math.sin((deg * Math.PI) / 180)), n2(cy - r * Math.cos((deg * Math.PI) / 180))];
const arc = (cx, cy, r, a0, a1) => { const [x0, y0] = polar(cx, cy, r, a0), [x1, y1] = polar(cx, cy, r, a1); return `M${x0} ${y0}A${r} ${r} 0 ${Math.abs(a1 - a0) > 180 ? 1 : 0} 1 ${x1} ${y1}`; };

export function appIcon(option, mode = "light") {
  const p = nextId("i"), c = PAL[mode];
  const LIT = `url(#${p}l)`, ICE = `url(#${p}e)`;
  const blur = (shape, o = 0.55) => (c.glow ? `<g filter="url(#${p}b)" opacity="${o}">${shape}</g>` : "");
  let glow = "", glyph = "";
  switch (option) {
    case "selector": {
      const cy = 566, dots = [-52, 0, 52].map((a) => polar(512, cy, 300, a));
      glow = blur(`<circle cx="${dots[1][0]}" cy="${dots[1][1]}" r="60" fill="${c.glow}"/>`, 0.9) + blur(`<circle cx="512" cy="${cy}" r="190" fill="${c.glow}"/>`, 0.45);
      glyph = dots.map(([x, y], i) => `<circle cx="${x}" cy="${y}" r="${i === 1 ? 38 : 32}" fill="${i === 1 ? ICE : c.dim}"/>`).join("")
        + `<circle cx="512" cy="${cy}" r="198" fill="${LIT}"/><circle cx="512" cy="${cy}" r="198" fill="none" stroke="#fff" stroke-opacity=".28" stroke-width="6"/>`
        + `<path d="M512 ${cy - 62}V${cy - 150}" stroke="${c.ink}" stroke-width="42" stroke-linecap="round"/>`;
      break;
    }
    case "faders": {
      const strip = (x, ky, fill, gl) => {
        glow += blur(`<rect x="${x - 88}" y="${ky - 48}" width="176" height="96" rx="30" fill="${gl}"/>`, 0.6);
        return `<rect x="${x - 22}" y="262" width="44" height="500" rx="22" fill="${c.dim}"/>`
          + `<rect x="${x - 22}" y="${ky}" width="44" height="${762 - ky}" rx="22" fill="${fill}" opacity=".7"/>`
          + `<rect x="${x - 88}" y="${ky - 48}" width="176" height="96" rx="30" fill="${fill}"/>`
          + `<rect x="${x - 46}" y="${ky - 6}" width="92" height="12" rx="6" fill="${c.ink}" opacity=".5"/>`;
      };
      glyph = strip(392, 384, LIT, c.glow) + strip(632, 588, ICE, "#cfe6ff");
      break;
    }
    case "needle": {
      const cx = 512, cy = 668, r = 330, [tx, ty] = polar(cx, cy, 316, 22);
      glow = blur(`<path d="${arc(cx, cy, r, -58, 22)}" fill="none" stroke="${c.glow}" stroke-width="70" stroke-linecap="round"/>`, 0.6);
      glyph = `<path d="${arc(cx, cy, r, -58, 58)}" fill="none" stroke="${c.dim}" stroke-width="62" stroke-linecap="round"/>`
        + `<path d="${arc(cx, cy, r, -58, 22)}" fill="none" stroke="${LIT}" stroke-width="62" stroke-linecap="round"/>`
        + `<path d="M${cx} ${cy}L${tx} ${ty}" stroke="${ICE}" stroke-width="36" stroke-linecap="round"/>`
        + `<circle cx="${cx}" cy="${cy}" r="58" fill="${ICE}"/><circle cx="${cx}" cy="${cy}" r="21" fill="${c.ink}"/>`;
      break;
    }
    case "capsule": {
      glow = blur(`<rect x="182" y="352" width="660" height="320" rx="160" fill="none" stroke="${c.glow}" stroke-width="50"/>`, 0.5);
      glyph = `<rect x="182" y="352" width="660" height="320" rx="160" fill="#fff" fill-opacity=".07" stroke="${ICE}" stroke-width="40"/>`
        + `<path d="M512 424V600" stroke="${c.dim}" stroke-width="14" stroke-linecap="round"/>`
        // speaker: cone and two waves
        + `<path d="M296 480H336L394 432V592L336 544H296Z" fill="${LIT}" stroke="${LIT}" stroke-width="18" stroke-linejoin="round"/>`
        + `<path d="${arc(398, 512, 52, 38, 142)}M${polar(398, 512, 100, 40).join(" ")}A100 100 0 0 1 ${polar(398, 512, 100, 140).join(" ")}" fill="none" stroke="${LIT}" stroke-width="24" stroke-linecap="round"/>`
        // microphone: capsule, cradle, stem, foot
        + `<rect x="626" y="412" width="68" height="126" rx="34" fill="${ICE}"/>`
        + `<path d="M600 510A60 60 0 0 0 720 510M660 572V612M626 614H694" fill="none" stroke="${ICE}" stroke-width="22" stroke-linecap="round"/>`;
      break;
    }
    case "peaks": {
      const seg = (x, i, fill, o = 1) => `<rect x="${x}" y="${693 - i * 84}" width="190" height="58" rx="20" fill="${fill}" opacity="${o}"/>`;
      const shade = (i) => (mode === "tinted" ? "#fff" : ["#2f74f0", "#3f86fb", "#5a9dff", "#7db5ff", "#a3ceff", "#d5e9ff"][i]);
      let l = "", r = "";
      for (let i = 0; i < 6; i++) { l += seg(302, i, shade(i)); r += i < 3 ? seg(532, i, mode === "tinted" ? "#fff" : ["#dfeeff", "#eaf4ff", "#ffffff"][i], 0.95) : seg(532, i, c.dim); }
      glow = blur(`<rect x="302" y="273" width="190" height="478" rx="30" fill="${c.glow}"/>`, 0.5);
      glyph = l + r;
      break;
    }
  }
  const defs = lg(`${p}t`, c.tile) + lg(`${p}l`, c.lit) + lg(`${p}e`, c.ice)
    + `<clipPath id="${p}c"><path d="${TILE}"/></clipPath>`
    + `<filter id="${p}b" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="46"/></filter>`
    + `<filter id="${p}s" x="-10%" y="-10%" width="120%" height="120%"><feGaussianBlur stdDeviation="14"/></filter>`
    + `<linearGradient id="${p}h" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".1"/><stop offset=".45" stop-color="#fff" stop-opacity="0"/></linearGradient>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><defs>${defs}</defs>`
    + `<path d="${TILE}" transform="translate(0,12)" fill="#000" opacity=".28" filter="url(#${p}s)"/>`
    + `<g clip-path="url(#${p}c)"><rect x="100" y="100" width="824" height="824" fill="url(#${p}t)"/>${glow}${glyph}<rect x="100" y="100" width="824" height="824" fill="url(#${p}h)"/></g></svg>`;
}

/** The 16/32 px drawing: the same idea with fewer, heavier parts. */
export function appIconSmall(option, mode = "light") {
  const p = nextId("s"), c = PAL[mode];
  const LIT = `url(#${p}l)`, ICE = `url(#${p}e)`;
  let g = "";
  switch (option) {
    case "selector":
      g = `<circle cx="16" cy="6.6" r="2.5" fill="${ICE}"/><circle cx="7" cy="10.4" r="2" fill="${c.dim}"/><circle cx="25" cy="10.4" r="2" fill="${c.dim}"/>`
        + `<circle cx="16" cy="18.6" r="7.6" fill="${LIT}"/><path d="M16 16.6V13.4" stroke="${c.ink}" stroke-width="2.6" stroke-linecap="round"/>`;
      break;
    case "faders":
      g = `<rect x="9" y="6.5" width="3" height="19" rx="1.5" fill="${c.dim}"/><rect x="20" y="6.5" width="3" height="19" rx="1.5" fill="${c.dim}"/>`
        + `<rect x="5.5" y="8.5" width="10" height="6" rx="2.2" fill="${LIT}"/><rect x="16.5" y="16.5" width="10" height="6" rx="2.2" fill="${ICE}"/>`;
      break;
    case "needle":
      g = `<path d="${arc(16, 21.5, 11, -58, 58)}" fill="none" stroke="${c.dim}" stroke-width="3.4" stroke-linecap="round"/>`
        + `<path d="${arc(16, 21.5, 11, -58, 22)}" fill="none" stroke="${LIT}" stroke-width="3.4" stroke-linecap="round"/>`
        + `<path d="M16 21.5L${polar(16, 21.5, 10.5, 22).join(" ")}" stroke="${ICE}" stroke-width="2.4" stroke-linecap="round"/><circle cx="16" cy="21.5" r="3" fill="${ICE}"/>`;
      break;
    case "capsule":
      g = `<path d="M15.2 10H11A6 6 0 0 0 11 22H15.2Z" fill="${LIT}"/><path d="M16.8 10H21A6 6 0 0 1 21 22H16.8Z" fill="${ICE}"/>`;
      break;
    case "peaks":
      g = [0, 1, 2].map((i) => `<rect x="7" y="${19.6 - i * 5.6}" width="8" height="4" rx="1.5" fill="${mode === "tinted" ? "#fff" : ["#3f86fb", "#7db5ff", "#d5e9ff"][i]}"/>`).join("")
        + [0, 1, 2].map((i) => `<rect x="17" y="${19.6 - i * 5.6}" width="8" height="4" rx="1.5" fill="${i < 2 ? ICE : c.dim}"/>`).join("");
      break;
  }
  const defs = lg(`${p}t`, c.tile) + lg(`${p}l`, c.lit) + lg(`${p}e`, c.ice) + `<clipPath id="${p}c"><path d="${TILE_S}"/></clipPath>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><defs>${defs}</defs><g clip-path="url(#${p}c)"><rect width="32" height="32" fill="url(#${p}t)"/>${g}</g></svg>`;
}
