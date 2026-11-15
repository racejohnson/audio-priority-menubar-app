// Writes an option's three SVGs into ../svg/<slug>/ and renders review PNGs with rsvg-convert.
//
//   node render.mjs <slug> --out DIR    one option: review.png (everything on one sheet) plus each size
//   node render.mjs --sheet --out DIR   every option and the Peaks baseline side by side: sheet.png
//
// review.png shows: master 512, bleed under the macOS shape 256, 128, 64, true-size 32 and 16 on light
// and dark grounds, and the 16 and 32 cuts blown up with nearest-neighbour pixels (what macOS really shows).
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { execFileSync } from "node:child_process";
import { fileURLToPath, pathToFileURL } from "node:url";
import { TILE } from "./shape.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const repo = path.resolve(root, "../..");
const args = process.argv.slice(2);
const oi = args.indexOf("--out");
const out = oi >= 0 ? path.resolve(args[oi + 1]) : path.join(os.tmpdir(), "ap-icon-render");
fs.mkdirSync(out, { recursive: true });

export async function loadOption(slug) {
  if (slug === "peaks") {
    const r = (f) => fs.readFileSync(path.join(repo, "Icon", f), "utf8");
    return { meta: { slug: "peaks", name: "Peaks (today)", idea: "The shipping icon: a segmented stereo meter on a deep blue tile." },
      master: r("AppIcon.svg"), small: r("AppIcon-small.svg"), bleed: r("AppIcon-bleed.svg") };
  }
  const m = await import(pathToFileURL(path.join(here, "icons", `${slug}.mjs`)).href + `?t=${process.hrtime.bigint()}`);
  return { meta: m.meta, master: m.master(), small: m.small(), bleed: m.bleed() };
}
export function writeOption(o) {
  const d = path.join(root, "svg", o.meta.slug);
  fs.mkdirSync(d, { recursive: true });
  fs.writeFileSync(path.join(d, `${o.meta.slug}.svg`), o.master + "\n");
  fs.writeFileSync(path.join(d, `${o.meta.slug}-small.svg`), o.small + "\n");
  fs.writeFileSync(path.join(d, `${o.meta.slug}-bleed.svg`), o.bleed + "\n");
}
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "ap-r-"));
let n = 0;
export function png(svg, px) {
  const f = path.join(tmp, `${++n}.svg`), p = path.join(tmp, `${n}.png`);
  fs.writeFileSync(f, svg);
  execFileSync("rsvg-convert", ["-w", String(px), "-h", String(px), f, "-o", p]);
  return fs.readFileSync(p);
}
const uri = (buf, type = "image/png") => `data:${type};base64,${buf.toString("base64")}`;
/** The bleed art under the macOS shape, inset on the canvas like the master's tile (as the system pads it). */
export function masked(bleedSvg) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><clipPath id="m"><path d="${TILE}"/></clipPath><image clip-path="url(#m)" x="100" y="100" width="824" height="824" href="${uri(Buffer.from(bleedSvg), "image/svg+xml")}"/></svg>`;
}
const img = (buf, x, y, w, pix = false) => `<image x="${x}" y="${y}" width="${w}" height="${w}"${pix ? ' style="image-rendering:pixelated"' : ""} href="${uri(buf)}"/>`;
const label = (t, x, y, fill = "#86868b") => `<text x="${x}" y="${y}" font-family="Helvetica" font-size="13" fill="${fill}">${t}</text>`;

async function review(slug) {
  const o = await loadOption(slug);
  writeOption(o);
  const P = { m512: png(o.master, 512), b256: png(masked(o.bleed), 256), m128: png(o.master, 128), m64: png(o.master, 64), s32: png(o.small, 32), s16: png(o.small, 16) };
  for (const [k, v] of Object.entries(P)) fs.writeFileSync(path.join(out, `${slug}-${k}.png`), v);
  fs.writeFileSync(path.join(out, `${slug}-m1024.png`), png(o.master, 1024));
  const W = 1100, H = 900;
  let s = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}"><rect width="${W}" height="${H}" fill="#f5f5f7"/><rect x="560" y="0" width="${W - 560}" height="${H}" fill="#1c1c1e"/>`;
  s += img(P.m512, 24, 40, 512) + label(`${o.meta.name}: master at 512`, 24, 26);
  s += img(P.b256, 24, 600, 256) + label("bleed under the macOS shape", 24, 590);
  s += label("128 · 64 · 32 · 16, true size (light)", 300, 590) + img(P.m128, 300, 610, 128) + img(P.m64, 444, 642, 64) + img(P.s32, 300, 760, 32) + img(P.s16, 348, 768, 16);
  s += label("on dark", 584, 26, "#a1a1a6") + img(P.m128, 584, 40, 128) + img(P.m64, 728, 72, 64) + img(P.s32, 808, 88, 32) + img(P.s16, 856, 96, 16);
  s += label("16 px, each pixel blown up 16x", 584, 210, "#a1a1a6") + img(P.s16, 584, 220, 256, true);
  s += label("32 px, blown up 8x", 856, 210, "#a1a1a6") + img(P.s32, 856, 220, 224, true);
  const B32 = png(masked(o.bleed), 32), B16 = png(masked(o.bleed), 16);
  fs.writeFileSync(path.join(out, `${slug}-b16.png`), B16);
  s += label("macOS 26 really shows the bleed art (Assets.car):", 584, 500, "#a1a1a6") + label("32 · 16 true size, and 16 blown up 16x", 584, 516, "#a1a1a6");
  s += img(B32, 584, 540, 32) + img(B16, 628, 548, 16) + img(B16, 680, 530, 256, true);
  s += `</svg>`;
  const f = path.join(out, `${slug}-review.png`);
  execRender(s, f);
  console.log(`wrote svg/${slug}/ and ${f}`);
}
function execRender(svg, file) {
  const f = path.join(tmp, `${++n}.svg`);
  fs.writeFileSync(f, svg);
  execFileSync("rsvg-convert", [f, "-o", file]);
  return fs.readFileSync(file);
}

async function sheet() {
  const slugs = ["peaks", ...fs.readdirSync(path.join(here, "icons")).filter((f) => f.endsWith(".mjs")).map((f) => f.slice(0, -4)).sort()];
  const opts = [];
  for (const s of slugs) opts.push(await loadOption(s));
  const RH = 170, W = 1180, H = 40 + RH * opts.length;
  let s = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}"><rect width="${W}" height="${H}" fill="#f5f5f7"/><rect x="600" width="${W - 600}" height="${H}" fill="#1c1c1e"/>`;
  s += label("128 · 64 · 32 · 16 (light) · bleed under shape 128 · 16 blown up", 20, 24) + label("dark: 128 · 64 · 32 · 16 · bleed at 16 blown up (what macOS 26 shows)", 620, 24, "#a1a1a6");
  opts.forEach((o, i) => {
    const y = 40 + i * RH, m128 = png(o.master, 128), m64 = png(o.master, 64), s32 = png(o.small, 32), s16 = png(o.small, 16), b = png(masked(o.bleed), 128);
    s += label(o.meta.slug, 20, y + 150, "#1d1d1f");
    s += img(m128, 20, y, 128) + img(m64, 160, y + 32, 64) + img(s32, 236, y + 48, 32) + img(s16, 280, y + 56, 16) + img(b, 308, y, 128) + img(s16, 448, y, 128, true);
    const b16 = png(masked(o.bleed), 16);
    s += img(m128, 620, y, 128) + img(m64, 760, y + 32, 64) + img(s32, 836, y + 48, 32) + img(s16, 880, y + 56, 16) + img(b16, 910, y, 128, true) + label("bleed 16", 1045, y + 140, "#a1a1a6");
  });
  s += `</svg>`;
  const f = path.join(out, "sheet.png");
  execRender(s, f);
  console.log(`wrote ${f}`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  if (args.includes("--sheet")) await sheet();
  else if (args[0] && !args[0].startsWith("--")) await review(args[0]);
  else { console.error("usage: node render.mjs <slug> --out DIR | --sheet --out DIR"); process.exit(1); }
}
