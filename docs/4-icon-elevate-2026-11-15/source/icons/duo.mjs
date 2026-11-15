// Duo: today's Peaks meter, cut to three flat segments a side, each channel in its own colour
// (output blue left, input violet right) on a deep indigo-blue tile from the Peaks family.
import { wrapMaster, wrapBleed, wrapSmall, TILE, TILE_S, OUT, IN } from "../shape.mjs";

const slug = "duo";
export const meta = {
  slug,
  name: "Duo",
  idea: "Peaks on its own deep navy tile, cut to three wide flat segments a side in bright output blue (full) and input violet (two of three), so the two channel colours stand off the tile and the full-versus-partial silhouette still reads at 16 px.",
};

// Geometry in 1024 space: flat meter segments, tight row gap, two wide columns.
const ROWS = 3;
const SEG_H = 124;
const ROW_GAP = 84;
const COL_W = 252;
const COL_GAP = 76;
const RX = 46;
const IN_LIT = 2;             // input lit to two of three: Peaks' six-and-four, simplified
const glyphH = ROWS * SEG_H + (ROWS - 1) * ROW_GAP;   // 528
const top = 512 - glyphH / 2;
const leftX = 512 - COL_GAP / 2 - COL_W;
const rightX = 512 + COL_GAP / 2;

const C = {
  tileTop: "#1d2c72",
  tileBot: "#0c1340",
  outTop: "#b4d2ff",         // ice
  outBot: "#6aa0ff",
  inTop: "#cbbdff",
  inBot: "#a58cff",
};
const DIM = 0.26;

function column(x, lit, grad, dim) {
  let s = "";
  for (let i = 0; i < ROWS; i++) {
    const y = top + i * (SEG_H + ROW_GAP);
    const on = ROWS - 1 - i < lit; // lit from the bottom up
    s += `<rect x="${x}" y="${y}" width="${COL_W}" height="${SEG_H}" rx="${RX}" fill="${on ? `url(#${grad})` : dim}"${on ? "" : ` fill-opacity="${DIM}"`}/>`;
  }
  return s;
}

const gradY = (id, a, b) =>
  `<linearGradient id="${id}" gradientUnits="userSpaceOnUse" x1="0" y1="${top}" x2="0" y2="${top + glyphH}"><stop offset="0" stop-color="${a}"/><stop offset="1" stop-color="${b}"/></linearGradient>`;

const defs =
  `<linearGradient id="${slug}-bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${C.tileTop}"/><stop offset="1" stop-color="${C.tileBot}"/></linearGradient>`
  + gradY(`${slug}-out`, C.outTop, C.outBot)
  + gradY(`${slug}-in`, C.inTop, C.inBot);

const art =
  `<rect x="100" y="100" width="824" height="824" fill="url(#${slug}-bg)"/>`
  + column(leftX, ROWS, `${slug}-out`, C.outBot)
  + column(rightX, IN_LIT, `${slug}-in`, C.inBot);

export function master() { return wrapMaster(slug, defs, art, { rimOpacity: 0.1 }); }
export function bleed() { return wrapBleed(slug, defs, art); }

// Small cut, 32 grid (tile 2..30): three heavy segments a side, input lit two of three, matching the main art.
function smallCol(x, lit, fill, n = 3) {
  let s = "";
  for (let i = 0; i < n; i++) {
    const y = 8 + i * 6;
    const on = n - 1 - i < lit;
    s += `<rect x="${x}" y="${y}" width="7" height="4" rx="1.6" fill="${fill}"${on ? "" : ` fill-opacity=".3"`}/>`;
  }
  return s;
}
const smallDefs =
  `<linearGradient id="${slug}-sbg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${C.tileTop}"/><stop offset="1" stop-color="${C.tileBot}"/></linearGradient>`;
const smallArt =
  `<rect width="32" height="32" fill="url(#${slug}-sbg)"/>`
  + smallCol(7.5, 3, "#8ab6ff") + smallCol(17.5, 2, "#b4a0ff");

export function small() { return wrapSmall(slug, smallDefs, smallArt); }
