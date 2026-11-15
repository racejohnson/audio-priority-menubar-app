import { wrapMaster, wrapBleed, wrapSmall, TILE, TILE_S, OUT, IN } from "../shape.mjs";

const slug = "night";

export const meta = {
  slug,
  name: "Night",
  idea: "Peaks on a black tile: four wide, flat, softly rounded meter segments a side instead of six thin glassy ones, filling most of the tile in bright blue (output, full) and violet (input, half), unlit input segments shown as dim violet like Tailscale's dots, and no glow or shine, so it reads at 16 px.",
};

// Geometry in 1024 space. Two columns, four rows, centred on 512.
const ROWS = 4;
const COL_W = 248, GAP_X = 64;
const SEG_H = 100, GAP_Y = 56, RX = 38;
const LEFT_LIT = 4, RIGHT_LIT = 2;

const glyphW = COL_W * 2 + GAP_X;
const glyphH = ROWS * SEG_H + (ROWS - 1) * GAP_Y;
const x0 = 512 - glyphW / 2;
const y0 = 512 - glyphH / 2;
const xL = x0, xR = x0 + COL_W + GAP_X;

const BLUE_HI = "#8cbcff", BLUE = "#4d94ff";
const VIOLET_HI = "#b7a3ff", VIOLET = "#977cff";
// Unlit segments: the column's own hue at low opacity (Tailscale-style dim dots), lifted enough to hold the meter frame at 16-32 px.
const DIM_OPACITY = 0.34;

function seg(x, row, fill, op = 1) {
  const y = y0 + row * (SEG_H + GAP_Y);
  const o = op < 1 ? ` fill-opacity="${op}"` : "";
  return `<rect x="${x}" y="${y}" width="${COL_W}" height="${SEG_H}" rx="${RX}" fill="${fill}"${o}/>`;
}

function column(x, lit, litFill, dimFill) {
  let s = "";
  for (let r = 0; r < ROWS; r++) s += r >= ROWS - lit ? seg(x, r, litFill) : seg(x, r, dimFill, DIM_OPACITY); // lit from the bottom up
  return s;
}

const defs = ``
  + `<linearGradient id="${slug}-bg" x1="0" y1="100" x2="0" y2="924" gradientUnits="userSpaceOnUse">`
  + `<stop offset="0" stop-color="#17181d"/><stop offset="1" stop-color="#050506"/></linearGradient>`
  + `<linearGradient id="${slug}-b" x1="0" y1="${y0}" x2="0" y2="${y0 + glyphH}" gradientUnits="userSpaceOnUse">`
  + `<stop offset="0" stop-color="${BLUE_HI}"/><stop offset="1" stop-color="${BLUE}"/></linearGradient>`
  + `<linearGradient id="${slug}-v" x1="0" y1="${y0}" x2="0" y2="${y0 + glyphH}" gradientUnits="userSpaceOnUse">`
  + `<stop offset="0" stop-color="${VIOLET_HI}"/><stop offset="1" stop-color="${VIOLET}"/></linearGradient>`;

const art = ``
  + `<rect x="100" y="100" width="824" height="824" fill="url(#${slug}-bg)"/>`
  + column(xL, LEFT_LIT, `url(#${slug}-b)`, BLUE)
  + column(xR, RIGHT_LIT, `url(#${slug}-v)`, VIOLET);

export function master() { return wrapMaster(slug, defs, art, { rimOpacity: 0.1 }); }
export function bleed() { return wrapBleed(slug, defs, art); }

// Small cut: 32 grid, three heavy rows a side, left full, right two lit.
const S = { cw: 9, gx: 2, h: 4, gy: 2, rows: 3, rx: 1.5 };
const sW = S.cw * 2 + S.gx, sH = S.rows * S.h + (S.rows - 1) * S.gy;
const sx0 = 16 - sW / 2, sy0 = 16 - sH / 2;
function sseg(x, r, fill) {
  return `<rect x="${x}" y="${sy0 + r * (S.h + S.gy)}" width="${S.cw}" height="${S.h}" rx="${S.rx}" fill="${fill}"/>`;
}
const smallDefs = ``;
let smallArt = `<rect x="0" y="0" width="32" height="32" fill="#0c0d10"/>`;
for (let r = 0; r < S.rows; r++) {
  smallArt += sseg(sx0, r, "#6aa6ff");
  smallArt += sseg(sx0 + S.cw + S.gx, r, r >= 1 ? "#a68cff" : "#3b3170");
}

export function small() { return wrapSmall(slug, smallDefs, smallArt); }
