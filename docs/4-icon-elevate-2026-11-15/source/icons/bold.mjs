// "Bold": Peaks distilled. Four chunky rounded segments a side in two clearly
// separate columns, flat with unlit ones dimmed, on one smooth navy gradient.
import { wrapMaster, wrapBleed, wrapSmall, TILE, TILE_S, OUT, IN } from "../shape.mjs";

const slug = "bold";
export const meta = {
  slug,
  name: "Bold",
  idea: "Today's Peaks with nothing extra and everything bigger: four chunky segments a side instead of six thin glassy ones, two clearly separate columns (output in ice, input in white) with unlit segments simply dimmed to a faint 20%, filling about 60% of the tile so the glyph and its lit/unlit split still read at 16 px.",
};

const DIM = 0.2;

// 1024 space. Glyph 512 wide, centred; columns rows-tight with a wide channel.
const COL_W = 204, COL_GAP = 108, ROW_H = 84, ROW_GAP = 40, ROWS = 4, RX = 26;
const glyphW = COL_W * 2 + COL_GAP;
const glyphH = ROWS * ROW_H + (ROWS - 1) * ROW_GAP;
const X0 = 512 - glyphW / 2, Y0 = 512 - glyphH / 2;

function column(x, lit, fill) {
  let s = "";
  for (let i = 0; i < ROWS; i++) {
    const y = Y0 + i * (ROW_H + ROW_GAP);
    const on = i >= ROWS - lit; // lit from the bottom
    s += `<rect x="${x}" y="${y}" width="${COL_W}" height="${ROW_H}" rx="${RX}" fill="${on ? fill : "#fff"}"${on ? "" : ` opacity="${DIM}"`}/>`;
  }
  return s;
}

const defs =
  `<linearGradient id="${slug}-bg" x1="0" y1="100" x2="0" y2="924" gradientUnits="userSpaceOnUse">`
  + `<stop offset="0" stop-color="#3a72e8"/><stop offset=".5" stop-color="#1b3fa8"/><stop offset="1" stop-color="#0e2566"/></linearGradient>`
  + `<radialGradient id="${slug}-sh" cx="512" cy="100" r="620" gradientUnits="userSpaceOnUse">`
  + `<stop offset="0" stop-color="#fff" stop-opacity=".1"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>`
  // One gradient across the whole output column: blue-ice at the bottom to white at the top.
  + `<linearGradient id="${slug}-out" x1="0" y1="${Y0 + glyphH}" x2="0" y2="${Y0}" gradientUnits="userSpaceOnUse">`
  + `<stop offset="0" stop-color="#c4dbff"/><stop offset="1" stop-color="#ffffff"/></linearGradient>`;

const art =
  `<rect x="100" y="100" width="824" height="824" fill="url(#${slug}-bg)"/>`
  + `<rect x="100" y="100" width="824" height="824" fill="url(#${slug}-sh)"/>`
  + column(X0, 4, `url(#${slug}-out)`)
  + column(X0 + COL_W + COL_GAP, 2, "#fff");

export function master() { return wrapMaster(slug, defs, art); }
export function bleed() { return wrapBleed(slug, defs, art); }

// 32 grid: three segments a side, on whole pixels, 4 px channel.
const smallDefs =
  `<linearGradient id="${slug}-sbg" x1="0" y1="2" x2="0" y2="30" gradientUnits="userSpaceOnUse">`
  + `<stop offset="0" stop-color="#3a72e8"/><stop offset=".5" stop-color="#1b3fa8"/><stop offset="1" stop-color="#0e2566"/></linearGradient>`
  + `<linearGradient id="${slug}-sout" x1="0" y1="24" x2="0" y2="8" gradientUnits="userSpaceOnUse">`
  + `<stop offset="0" stop-color="#c4dbff"/><stop offset="1" stop-color="#ffffff"/></linearGradient>`;

function smallCol(x, lit, fill) {
  let s = "";
  for (let i = 0; i < 3; i++) {
    const y = 8 + i * 6;
    const on = i >= 3 - lit;
    s += `<rect x="${x}" y="${y}" width="7" height="4" rx="1.25" fill="${on ? fill : "#fff"}"${on ? "" : ` opacity="${(DIM + 0.04).toFixed(2)}"`}/>`;
  }
  return s;
}
const smallArt = `<rect x="0" y="0" width="32" height="32" fill="url(#${slug}-sbg)"/>`
  + smallCol(7, 3, `url(#${slug}-sout)`) + smallCol(18, 1, "#fff");

export function small() { return wrapSmall(slug, smallDefs, smallArt); }
