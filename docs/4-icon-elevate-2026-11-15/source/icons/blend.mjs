// "Blend": the colour moves from the meter to the tile. One diagonal sweep from
// output blue to input violet, and a plain white Peaks meter on top, the way
// Claude puts one white glyph on one vivid tile.
import { wrapMaster, wrapBleed, wrapSmall } from "../shape.mjs";

const slug = "blend";
export const meta = {
  slug,
  name: "Blend",
  idea: "The colour moves to the tile: one sweep from output blue to input violet, with a plain white four-segment meter on top, output full and input at half.",
};

const DIM = 0.26;
// 1024 space. Pill-ended segments; the glyph is 520 wide.
const COL_W = 210, COL_GAP = 100, ROW_H = 80, ROW_GAP = 42, ROWS = 4, RX = 40;
const glyphW = COL_W * 2 + COL_GAP, glyphH = ROWS * ROW_H + (ROWS - 1) * ROW_GAP;
const X0 = 512 - glyphW / 2, Y0 = 512 - glyphH / 2;

const column = (x, lit) => Array.from({ length: ROWS }, (_, i) => {
  const on = i >= ROWS - lit;
  return `<rect x="${x}" y="${Y0 + i * (ROW_H + ROW_GAP)}" width="${COL_W}" height="${ROW_H}" rx="${RX}" fill="#fff"${on ? "" : ` fill-opacity="${DIM}"`}/>`;
}).join("");

const tile = (id, x1, y1, x2, y2) =>
  `<linearGradient id="${id}" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" gradientUnits="userSpaceOnUse">`
  + `<stop offset="0" stop-color="#3f86f5"/><stop offset=".55" stop-color="#4a5fe0"/><stop offset="1" stop-color="#6b45d2"/></linearGradient>`;

const defs = tile(`${slug}-bg`, 140, 100, 884, 924)
  + `<radialGradient id="${slug}-sh" cx="300" cy="140" r="700" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#fff" stop-opacity=".16"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>`
  + `<filter id="${slug}-gs" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="18"/></filter>`;

const glyph = column(X0, 4) + column(X0 + COL_W + COL_GAP, 2);
const art = `<rect x="100" y="100" width="824" height="824" fill="url(#${slug}-bg)"/>`
  + `<rect x="100" y="100" width="824" height="824" fill="url(#${slug}-sh)"/>`
  // A very soft shadow under the glyph so the white lifts off the colour.
  + `<g transform="translate(0 10)" opacity=".18" filter="url(#${slug}-gs)"><g fill="#1a1060">${glyph.replace(/fill="#fff"/g, 'fill="#1a1060"')}</g></g>`
  + glyph;

export function master() { return wrapMaster(slug, defs, art); }
export function bleed() { return wrapBleed(slug, defs, art); }

// 32 grid: three pills a side on whole pixels.
const smallCol = (x, lit) => [0, 1, 2].map((i) => {
  const on = i >= 3 - lit;
  return `<rect x="${x}" y="${8 + i * 6}" width="7" height="4" rx="2" fill="#fff"${on ? "" : ` fill-opacity="${DIM + 0.06}"`}/>`;
}).join("");
const smallDefs = tile(`${slug}-sbg`, 3, 2, 29, 30);
const smallArt = `<rect width="32" height="32" fill="url(#${slug}-sbg)"/>` + smallCol(7, 3) + smallCol(18, 1);
export function small() { return wrapSmall(slug, smallDefs, smallArt); }
