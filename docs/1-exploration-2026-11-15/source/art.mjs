// Art for the audio-priority exploration: device glyphs, DJI Mic Mini symbols,
// menu-bar glyph composers and app icons. One source for both build.mjs (which
// writes ../svg/) and index.html (build.mjs inlines this file with `export`
// stripped). Every glyph is drawn in an 18x18 pt box in currentColor, the size
// of an NSStatusItem template image.

const F = 'fill="currentColor" stroke="none"';
let uid = 0;
const nextId = (p) => `${p}${++uid}`;

// ---------------------------------------------------------------------------
// Device glyphs. Stand-ins for the SF Symbols the app will use (laptopcomputer,
// display, mic, airpods, airpod.right, headphones, iphone, hifispeaker,
// speaker.wave.2); a web page can't draw real SF Symbols. `w` is the stroke in
// glyph units, so a glyph scaled down can keep a heavier line.
// ---------------------------------------------------------------------------
export const DEVICE = {
  laptop: (w) => `<rect x="3.3" y="3.7" width="11.4" height="8.1" rx="1.3" stroke-width="${w}"/><path d="M1.3 14.6H16.7" stroke-width="${w + 0.35}"/>`,
  display: (w) => `<rect x="2" y="2.6" width="14" height="9.7" rx="1.5" stroke-width="${w}"/><path d="M9 12.4V15.3M5.9 15.7H12.1" stroke-width="${w}"/>`,
  mic: (w) => `<rect x="6.3" y="1.5" width="5.4" height="8.8" rx="2.7" stroke-width="${w}"/><path d="M3.8 8.3a5.2 5.2 0 0 0 10.4 0M9 13.6V16.4M6.5 16.5H11.5" stroke-width="${w}"/>`,
  airpods: (w) => `<circle cx="5.1" cy="5" r="2.75" ${F}/><circle cx="12.9" cy="5" r="2.75" ${F}/><path d="M7.05 6.7V15.7M10.95 6.7V15.7" stroke-width="${w + 0.9}"/>`,
  airpod: (w) => `<circle cx="7.6" cy="5" r="2.9" ${F}/><path d="M9.75 6.8V15.8" stroke-width="${w + 1}"/>`,
  headphones: (w) => `<path d="M2.9 11.6V9.4a6.1 6.1 0 0 1 12.2 0v2.2" stroke-width="${w}"/><rect x="1.9" y="10.3" width="3.6" height="5.9" rx="1.3" ${F}/><rect x="12.5" y="10.3" width="3.6" height="5.9" rx="1.3" ${F}/>`,
  iphone: (w) => `<rect x="5.1" y="1.4" width="7.8" height="15.2" rx="2.1" stroke-width="${w}"/><path d="M8 3.7H10" stroke-width="${w}"/>`,
  hifispeaker: (w) => `<rect x="4" y="1.4" width="10" height="15.2" rx="2.2" stroke-width="${w}"/><circle cx="9" cy="11.2" r="2.7" stroke-width="${w}"/><circle cx="9" cy="5.2" r="1.15" ${F}/>`,
  speaker: (w) => `<path d="M2.4 7.1H5L8.7 4.1V13.9L5 10.9H2.4Z" fill="currentColor" stroke-width="${w}"/><path d="M11.3 6.6a3.4 3.4 0 0 1 0 4.8M13.6 4.4a6.5 6.5 0 0 1 0 9.2" stroke-width="${w}"/>`,
};

// ---------------------------------------------------------------------------
// DJI Mic Mini. TX is 26.55 x 26.06 x 15.96 mm (near-square front, thick
// body), RX is 46.50 x 29.61 x 19.32 mm (DJI spec page, 15 Nov 2026).
// ---------------------------------------------------------------------------
export const DJI = {
  // Front of the transmitter: a rounded square (the spec's near-square face),
  // the magnet clip's tab on top, and the mic port.
  puck: (w) => `<path d="M7 3.9V2.3H11V3.9" stroke-width="${w}"/><rect x="2.9" y="3.9" width="12.2" height="12" rx="4.2" stroke-width="${w}"/><circle cx="9" cy="8.6" r="1.75" ${F}/>`,
  // Side view: the thick body with grille slots near the top and the
  // magnetic clip hooked over the back, the way it sits on a collar.
  clip: (w) => `<rect x="6.9" y="2.3" width="8" height="13.6" rx="3" stroke-width="${w}"/><path d="M6.9 4.6H5.3A1.8 1.8 0 0 0 3.5 6.4V13" stroke-width="${w}"/><path d="M9.7 5.6H12.1M9.7 7.8H12.1" stroke-width="${w * 0.9}"/>`,
  // Front with its furry windscreen on, the silhouette most people know.
  fuzzy: (w) => `<path d="M3.2 9.2C2.3 7.6 3.4 5.6 5.2 5.9C5.4 3.9 7.7 3 9.1 4.2C10.4 2.9 12.9 3.6 12.9 5.6C14.8 5.4 15.9 7.6 14.8 9.2Z" ${F}/><path d="M3.6 9.6V12.3A3.9 3.9 0 0 0 7.5 16.2H10.5A3.9 3.9 0 0 0 14.4 12.3V9.6" stroke-width="${w}"/>`,
  // The receiver, the device macOS names "Wireless Mic Rx": a tall body
  // (46.5 x 29.6 mm) with a USB-C plug at the bottom and a status light.
  rx: (w) => `<rect x="5" y="1.3" width="8" height="12.4" rx="2" stroke-width="${w}"/><path d="M7.4 13.8V16.6H10.6V13.8" stroke-width="${w}"/><circle cx="9" cy="4.5" r="0.95" ${F}/>`,
};

export const SYMBOL = { ...DEVICE, ...Object.fromEntries(Object.entries(DJI).map(([k, v]) => [`dji-${k}`, v])) };

/** One symbol at `size` pt placed at (x, y), stroke `pt` in final points. */
export function place(key, x, y, size = 18, pt = 1.4) {
  const s = size / 18;
  return `<g transform="translate(${x} ${y}) scale(${+s.toFixed(4)})">${SYMBOL[key](+(pt / s).toFixed(3))}</g>`;
}

const STROKE = 'fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round"';

export function symbolSVG(key, { size = 18, pt = 1.4, grid = false } = {}) {
  const guides = grid
    ? `<g stroke="#ff2d55" stroke-opacity=".35" stroke-width=".05" fill="none">${Array.from({ length: 19 }, (_, i) => `<path d="M${i} 0V18M0 ${i}H18"/>`).join("")}</g><rect x="1" y="1" width="16" height="16" fill="none" stroke="#0a84ff" stroke-opacity=".5" stroke-width=".08" stroke-dasharray=".3 .3"/>`
    : "";
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 18 18">${guides}<g ${STROKE}>${SYMBOL[key](pt)}</g></svg>`;
}

// ---------------------------------------------------------------------------
// Menu-bar glyphs that show the current output and input together.
// ---------------------------------------------------------------------------
export const GLYPH_OPTIONS = [
  { id: "pair", name: "Pair", width: 39, line: "Output then input, both full size, 3 pt apart. Reads like two status items." },
  { id: "divided", name: "Divided", width: 43, line: "Output | input with a hairline between, so the two never read as one device." },
  { id: "badge", name: "Badge", width: 20, line: "Output at 16 pt with the input as a 9 pt badge at bottom right. Narrowest that still shows both." },
  { id: "lead", name: "Lead", width: 32, line: "Output full size, input at 12 pt beside it. When both are the same device (AirPods), only one glyph shows." },
  { id: "capsule", name: "Capsule", width: 44, line: "Both at 12 pt inside an outlined capsule. Manual mode fills the capsule, the strongest state change." },
  { id: "stack", name: "Stack", width: 10, line: "Output above input, 9 pt each. Cheapest, but the glyphs get hard to read." },
];

const sameDevice = (out, inp) => out === "airpods" && inp === "airpod";

function dot(cx, cy, w, h) {
  const id = nextId("m");
  return {
    mask: `<mask id="${id}" maskUnits="userSpaceOnUse" x="-2" y="-2" width="${w + 4}" height="${h + 4}"><rect x="-2" y="-2" width="${w + 4}" height="${h + 4}" fill="#fff"/><circle cx="${cx}" cy="${cy}" r="3.5" fill="#000"/></mask>`,
    id,
    dot: `<circle cx="${cx}" cy="${cy}" r="2.2" fill="currentColor"/>`,
  };
}

/** Compose a menu-bar glyph. out/inp are SYMBOL keys. Returns {svg, width}. */
export function composeGlyph(option, out, inp, { manual = false } = {}) {
  let w = 18, body = "", h = 18;
  const H = 18;
  switch (option) {
    case "pair":
      w = 39; body = place(out, 0, 0) + place(inp, 21, 0); break;
    case "divided":
      w = 43; body = place(out, 0, 0) + `<path d="M21.5 3.5V14.5" stroke-width="1" opacity=".45"/>` + place(inp, 25, 0); break;
    case "badge": {
      w = 20;
      const id = nextId("b");
      body = `<mask id="${id}" maskUnits="userSpaceOnUse" x="0" y="0" width="20" height="18"><rect width="20" height="18" fill="#fff"/><circle cx="15.5" cy="13.5" r="6.3" fill="#000"/></mask>`
        + `<g mask="url(#${id})">${place(out, 0, 0.5, 16, 1.4)}</g>` + place(inp, 11, 9, 9, 1.15);
      break;
    }
    case "lead":
      if (sameDevice(out, inp)) { w = 18; body = place(out, 0, 0); }
      else { w = 32; body = place(out, 0, 0) + place(inp, 20, 3, 12, 1.25); }
      break;
    case "capsule": {
      w = 44;
      const glyphs = place(out, 6, 3, 12, 1.25) + place(inp, 26, 3, 12, 1.25);
      if (manual) {
        const id = nextId("c");
        body = `<mask id="${id}" maskUnits="userSpaceOnUse" x="0" y="0" width="44" height="18"><rect width="44" height="18" fill="#fff"/><g fill="none" stroke="#000" stroke-linecap="round" stroke-linejoin="round" color="#000">${glyphs}<path d="M22 5.5V12.5" stroke-width="1"/></g></mask>`
          + `<rect x=".5" y=".5" width="43" height="17" rx="8.5" fill="currentColor" stroke="none" mask="url(#${id})"/>`;
        return { svg: wrap(body, w, H), width: w };
      }
      body = `<rect x=".6" y=".6" width="42.8" height="16.8" rx="8.4" stroke-width="1.1"/>` + glyphs + `<path d="M22 5.5V12.5" stroke-width="1" opacity=".45"/>`;
      break;
    }
    case "stack":
      w = 10; body = place(out, 0.5, 0, 9, 1.05) + place(inp, 0.5, 9, 9, 1.05);
      if (manual) { w = 14; body += `<circle cx="12" cy="3" r="1.8" fill="currentColor" stroke="none"/>`; return { svg: wrap(body, w, H), width: w }; }
      break;
  }
  if (manual) {
    const d = dot(w - 2.2, 2.4, w, H);
    body = d.mask + `<g mask="url(#${d.id})">${body}</g>` + d.dot;
  }
  return { svg: wrap(body, w, h), width: w };
}

function wrap(body, w, h) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" overflow="hidden"><g ${STROKE}>${body}</g></svg>`;
}

// ---------------------------------------------------------------------------
// App icons, in the direction of mateusbadalotti/audio-priority's blue
// equalizer, on Race's deep Icon Composer tile (824 pt tile on 1024).
// ---------------------------------------------------------------------------
const TILE = "M382.8,100 L641.2,100 C722.63,100 763.34,100 807.17,113.86 C855.03,131.28 892.72,168.97 910.14,216.83 C924,260.66 924,301.37 924,382.8 L924,641.2 C924,722.63 924,763.34 910.14,807.17 C892.72,855.03 855.03,892.72 807.17,910.14 C763.34,924 722.63,924 641.2,924 L382.8,924 C301.37,924 260.66,924 216.83,910.14 C168.97,892.72 131.28,855.03 113.86,807.17 C100,763.34 100,722.63 100,641.2 L100,382.8 C100,301.37 100,260.66 113.86,216.83 C131.28,168.97 168.97,131.28 216.83,113.86 C260.66,100 301.37,100 382.8,100 Z";
const TILE_S = "M11.63,2 L20.37,2 C23.14,2 24.53,2 26.02,2.47 C27.65,3.07 28.93,4.35 29.53,5.98 C30,7.47 30,8.86 30,11.63 L30,20.37 C30,23.14 30,24.53 29.53,26.02 C28.93,27.65 27.65,28.93 26.02,29.53 C24.53,30 23.14,30 20.37,30 L11.63,30 C8.86,30 7.47,30 5.98,29.53 C4.35,28.93 3.07,27.65 2.47,26.02 C2,24.53 2,23.14 2,20.37 L2,11.63 C2,8.86 2,7.47 2.47,5.98 C3.07,4.35 4.35,3.07 5.98,2.47 C7.47,2 8.86,2 11.63,2 Z";

const DEEP = { light: ["#2459d6", "#0b1c55"], dark: ["#16337f", "#040b22"], tinted: ["#4a4a4e", "#1f1f22"] };
const LIT = { light: ["#a9d6ff", "#3f8bff"], dark: ["#8cc4ff", "#2f74f0"], tinted: ["#ffffff", "#f2f2f2"] };

// Bars as [x, y, width, height]; the mateusbadalotti layout (five 70 pt bars).
const EQ = [[257, 392, 70, 240], [367, 312, 70, 400], [477, 362, 70, 300], [587, 232, 70, 560], [697, 342, 70, 340]];

export const ICON_OPTIONS = [
  { id: "deep-eq", name: "Deep EQ", line: "mateusbadalotti's five bars, one lit, moved onto a deep blue tile. The most direct adaptation." },
  { id: "ranked", name: "Ranked", line: "The bars step down from left to right and the first one is lit: the top-ranked device wins." },
  { id: "in-out", name: "In & Out", line: "Two lit bars, ice for input and blue for output, the same idea as the menu-bar glyph." },
  { id: "list", name: "List", line: "The bars turned on their side into a ranked list with the top row picked. Less equalizer, more priority." },
  { id: "bright", name: "Bright", line: "Closest to the original: pale tile, blue bar. Kept as the baseline; it breaks the family's deep tiles." },
  { id: "glow", name: "Glow", line: "Near-black tile, outlined bars and one bar that glows. Moodiest, and the furthest from the original." },
];

function grad(id, [a, b], x1 = 0, y1 = 0, x2 = 0, y2 = 1) {
  return `<linearGradient id="${id}" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}"><stop offset="0" stop-color="${a}"/><stop offset="1" stop-color="${b}"/></linearGradient>`;
}
const bar = ([x, y, w, h], fill, extra = "") => `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${Math.min(w, h) / 2}" fill="${fill}" ${extra}/>`;

export function appIcon(option, mode = "light") {
  const p = nextId(`i${option.replace(/[^a-z]/g, "")}`);
  const tinted = mode === "tinted";
  let tile = DEEP[mode], lit = LIT[mode], dim = tinted ? "rgba(255,255,255,.42)" : "rgba(214,230,255,.30)";
  let defs = "", glyph = "", glow = "";
  const litFill = `url(#${p}l)`;
  defs += grad(`${p}l`, lit);
  if (option === "bright") {
    tile = { light: ["#f8fbff", "#dce7fa"], dark: ["#26304a", "#0d1220"], tinted: DEEP.tinted }[mode];
    dim = { light: "#c7d6f2", dark: "rgba(140,170,230,.35)", tinted: "rgba(255,255,255,.42)" }[mode];
    if (mode !== "tinted") defs = grad(`${p}l`, mode === "light" ? ["#5aa2ff", "#1b55d9"] : ["#8cc4ff", "#2f74f0"]);
  }
  if (option === "glow") tile = { light: ["#131a33", "#03050d"], dark: ["#0c1126", "#010208"], tinted: DEEP.tinted }[mode];
  defs += grad(`${p}t`, tile);
  defs += `<clipPath id="${p}c"><path d="${TILE}"/></clipPath><filter id="${p}b" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="46"/></filter><filter id="${p}s" x="-10%" y="-10%" width="120%" height="120%"><feGaussianBlur stdDeviation="14"/></filter>`;
  defs += `<linearGradient id="${p}h" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity="${option === "bright" && mode === "light" ? 0 : 0.09}"/><stop offset=".45" stop-color="#fff" stop-opacity="0"/></linearGradient>`;
  const glowAt = (x, y, w, h, c, o = 0.5) => (tinted ? "" : `<rect x="${x - 30}" y="${y + 20}" width="${w + 60}" height="${h - 40}" rx="${(w + 60) / 2}" fill="${c}" opacity="${o}" filter="url(#${p}b)"/>`);

  switch (option) {
    case "deep-eq":
    case "bright":
      EQ.forEach((b, i) => { glyph += bar(b, i === 3 ? litFill : dim); });
      if (option === "deep-eq") glow = glowAt(...EQ[3], "#4f9bff", 0.55);
      break;
    case "ranked": {
      const hs = [600, 470, 370, 290, 220];
      hs.forEach((h, i) => { const b = [257 + i * 110, 512 - h / 2, 70, h]; glyph += bar(b, i === 0 ? litFill : dim); if (i === 0) glow = glowAt(...b, "#4f9bff", 0.55); });
      break;
    }
    case "in-out": {
      defs += grad(`${p}i`, tinted ? ["#ffffff", "#e8e8e8"] : ["#ffffff", "#bfe0ff"]);
      EQ.forEach((b, i) => { glyph += bar(b, i === 3 ? litFill : i === 1 ? `url(#${p}i)` : dim); });
      glow = glowAt(...EQ[3], "#4f9bff", 0.5) + glowAt(...EQ[1], "#cfe6ff", 0.3);
      break;
    }
    case "list": {
      const rows = [[262, 300, 500], [262, 420, 400], [262, 540, 320], [262, 660, 240]];
      rows.forEach(([x, y, len], i) => {
        const b = [x, y, len, 74];
        glyph += bar(b, i === 0 ? litFill : dim);
        if (i === 0) { glow = `<rect x="${x - 20}" y="${y - 10}" width="${len + 40}" height="94" rx="47" fill="#4f9bff" opacity=".5" filter="url(#${p}b)"/>`; glyph += `<circle cx="${x + 37}" cy="${y + 37}" r="19" fill="${tinted ? "#3a3a3d" : "#0b1c55"}" opacity=".85"/>`; }
      });
      break;
    }
    case "glow":
      EQ.forEach((b, i) => {
        if (i === 3) glyph += bar(b, litFill);
        else glyph += `<rect x="${b[0] + 4}" y="${b[1] + 4}" width="${b[2] - 8}" height="${b[3] - 8}" rx="${(b[2] - 8) / 2}" fill="none" stroke="${tinted ? "rgba(255,255,255,.5)" : "rgba(150,190,255,.45)"}" stroke-width="8"/>`;
      });
      glow = tinted ? "" : glowAt(...EQ[3], "#3d8bff", 0.9) + glowAt(...EQ[3], "#7fb8ff", 0.4);
      break;
  }
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><defs>${defs}</defs>`
    + `<path d="${TILE}" transform="translate(0,12)" fill="#000" opacity=".28" filter="url(#${p}s)"/>`
    + `<g clip-path="url(#${p}c)"><rect x="100" y="100" width="824" height="824" fill="url(#${p}t)"/>${glow}${glyph}<rect x="100" y="100" width="824" height="824" fill="url(#${p}h)"/></g></svg>`;
}

/** The 16/32 px drawing: three heavy bars, not a downscale. */
export function appIconSmall(option, mode = "light") {
  const p = nextId(`s${option.replace(/[^a-z]/g, "")}`);
  const tinted = mode === "tinted";
  let tile = DEEP[mode], dim = tinted ? "rgba(255,255,255,.5)" : "rgba(214,230,255,.38)", lit = LIT[mode];
  if (option === "bright") { tile = { light: ["#f8fbff", "#dce7fa"], dark: ["#26304a", "#0d1220"], tinted: DEEP.tinted }[mode]; dim = mode === "light" ? "#bccdee" : dim; lit = mode === "light" ? ["#5aa2ff", "#1b55d9"] : lit; }
  if (option === "glow") tile = { light: ["#131a33", "#03050d"], dark: ["#0c1126", "#010208"], tinted: DEEP.tinted }[mode];
  const defs = grad(`${p}t`, tile) + grad(`${p}l`, lit) + `<clipPath id="${p}c"><path d="${TILE_S}"/></clipPath>`;
  const L = `url(#${p}l)`;
  let g = "";
  const v = (x, h, f) => `<rect x="${x}" y="${16 - h / 2}" width="4.6" height="${h}" rx="2.3" fill="${f}"/>`;
  switch (option) {
    case "ranked": g = v(8.2, 19, L) + v(13.7, 13, dim) + v(19.2, 9, dim); break;
    case "in-out": g = v(8.2, 11, tinted ? "#fff" : "#e6f2ff") + v(13.7, 8, dim) + v(19.2, 19, L); break;
    case "list": g = [[8, 9.6, 16], [8, 15.3, 12], [8, 21, 8]].map(([x, y, l], i) => `<rect x="${x}" y="${y - 2.3}" width="${l}" height="4.6" rx="2.3" fill="${i ? dim : L}"/>`).join(""); break;
    case "glow": g = `<rect x="9" y="11.3" width="3" height="9.4" rx="1.5" fill="none" stroke="${tinted ? "rgba(255,255,255,.55)" : "rgba(150,190,255,.6)"}" stroke-width="1.2"/>` + v(13.7, 19, L) + `<rect x="20" y="12.8" width="3" height="6.4" rx="1.5" fill="none" stroke="${tinted ? "rgba(255,255,255,.55)" : "rgba(150,190,255,.6)"}" stroke-width="1.2"/>`; break;
    default: g = v(8.2, 11, dim) + v(13.7, 19, L) + v(19.2, 13, dim);
  }
  return `<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><defs>${defs}</defs><g clip-path="url(#${p}c)"><rect width="32" height="32" fill="url(#${p}t)"/>${g}</g></svg>`;
}
