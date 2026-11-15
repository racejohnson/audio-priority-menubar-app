// Daylight: Peaks on a bright tile. Four pill-shaped LEDs a side, output (blue) full,
// input (violet) lit to three of four; unlit LEDs are the column's own colour at low opacity.
import { wrapMaster, wrapBleed, wrapSmall, TILE, TILE_S, OUT, IN } from "../shape.mjs";

const slug = "daylight";
export const meta = {
  slug,
  name: "Daylight",
  idea: "Today's Peaks meter redrawn large and flat on a white tile: four fat pill LEDs a side, blue output full beside violet input lit three of four, so the rows and the full-versus-lower silhouette hold at 16 px.",
};

// Glyph geometry in 1024 space (tile 100..924, centre 512).
// Four rows with gaps almost as tall as the pills, and a wide gutter between the
// columns, so rows and columns stay apart when macOS scales the bleed to 16 px.
const N = 4, H = 88, G = 66;            // segments a side, pill height, gap between rows
const W = 258, CG = 104;                // pill length, gutter between columns
const R = H / 2;                        // fully round ends
const TOTAL_H = N * H + (N - 1) * G;    // 550
const Y0 = 512 - TOTAL_H / 2;
const XL = 512 - CG / 2 - W, XR = 512 + CG / 2;
const LIT_IN = 3;
const DIM = 0.3;

const defs =
  `<linearGradient id="${slug}-bg" x1="0" y1="100" x2="0" y2="924" gradientUnits="userSpaceOnUse">`
  + `<stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#d6e3f7"/></linearGradient>`;

function seg(x, y, fill, op = 1) {
  return `<rect x="${x}" y="${y}" width="${W}" height="${H}" rx="${R}" fill="${fill}"${op < 1 ? ` fill-opacity="${op}"` : ""}/>`;
}
let segs = "";
for (let i = 0; i < N; i++) {
  const y = Y0 + i * (H + G);
  segs += seg(XL, y, OUT.light);
  segs += i >= N - LIT_IN ? seg(XR, y, IN.light) : seg(XR, y, IN.light, DIM);
}
const art = `<rect x="100" y="100" width="824" height="824" fill="url(#${slug}-bg)"/>` + segs;

// Small cut: 32 grid, tile 2..30, three pills a side on whole pixels, input lit 2 of 3.
const smallDefs =
  `<linearGradient id="${slug}-sbg" x1="0" y1="2" x2="0" y2="30" gradientUnits="userSpaceOnUse">`
  + `<stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#d6e3f7"/></linearGradient>`;
const sY = [9, 14, 19], sH = 3, sW = 8;
let sSegs = "";
sY.forEach((y, i) => {
  sSegs += `<rect x="7" y="${y}" width="${sW}" height="${sH}" rx="${sH / 2}" fill="${OUT.light}"/>`;
  sSegs += `<rect x="17" y="${y}" width="${sW}" height="${sH}" rx="${sH / 2}" fill="${IN.light}"${i === 0 ? ` fill-opacity="${DIM}"` : ""}/>`;
});
const smallArt = `<rect x="0" y="0" width="32" height="32" fill="url(#${slug}-sbg)"/>` + sSegs;

export function master() { return wrapMaster(slug, defs, art, { rim: "#000", rimOpacity: 0.08 }); }
export function bleed() { return wrapBleed(slug, defs, art); }
export function small() { return wrapSmall(slug, smallDefs, smallArt); }
