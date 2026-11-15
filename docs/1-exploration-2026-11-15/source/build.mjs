// Builds ../index.html (self-contained) and ../svg/ from art.mjs + template.html.
// Run: node docs/1-exploration-2026-11-15/source/build.mjs
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import * as A from "./art.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const svgDir = path.join(root, "svg");
fs.rmSync(svgDir, { recursive: true, force: true });
const write = (rel, s) => {
  const p = path.join(svgDir, rel);
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, s + "\n");
};

// Device and DJI symbols, plus DJI symbols on the grid.
for (const key of Object.keys(A.SYMBOL)) {
  const dir = key.startsWith("dji-") ? "dji" : "devices";
  write(`${dir}/${key}.svg`, A.symbolSVG(key));
  if (dir === "dji") write(`dji/${key}-grid.svg`, A.symbolSVG(key, { grid: true }));
}

// Menu-bar glyphs: every option in the four combos from the brief.
export const COMBOS = [
  { id: "desk", label: "MacBook speakers + DJI mic", out: "laptop", in: "dji-puck" },
  { id: "airpods", label: "AirPods + AirPods mic", out: "airpods", in: "airpod" },
  { id: "studio", label: "Studio Display speakers + MacBook mic", out: "display", in: "mic" },
  { id: "manual", label: "Manual (auto off), MacBook speakers + DJI", out: "laptop", in: "dji-puck", manual: true },
];
for (const o of A.GLYPH_OPTIONS)
  for (const c of COMBOS) write(`menubar/${o.id}-${c.id}.svg`, A.composeGlyph(o.id, c.out, c.in, { manual: !!c.manual }).svg);

// App icons: default, dark, tinted, and the 16/32 drawing in each.
for (const o of A.ICON_OPTIONS)
  for (const m of ["light", "dark", "tinted"]) {
    const suffix = m === "light" ? "" : `-${m}`;
    write(`app-icon/${o.id}${suffix}.svg`, A.appIcon(o.id, m));
    write(`app-icon/${o.id}-small${suffix}.svg`, A.appIconSmall(o.id, m));
  }

// Page.
const art = fs.readFileSync(path.join(here, "art.mjs"), "utf8").replace(/^export /gm, "");
const asset = (f) => fs.readFileSync(path.join(here, "assets", f), "utf8").trim();
const family = {
  daynight: "data:image/png;base64," + asset("daynight-menubar-app.b64"),
  mediakeys: "data:image/png;base64," + asset("mediakeys-for-spotify.b64"),
  screenshot: "data:image/png;base64," + asset("screenshot-pathname.b64"),
  polaris: "data:image/svg+xml;base64," + Buffer.from(asset("polaris.svg")).toString("base64"),
};
const html = fs
  .readFileSync(path.join(here, "template.html"), "utf8")
  .replace("/*__ART__*/", () => art)
  .replace("/*__DATA__*/", () => `const FAMILY = ${JSON.stringify(family)};\nconst COMBOS = ${JSON.stringify(COMBOS)};`);
fs.writeFileSync(path.join(root, "index.html"), html);
const count = (d) => fs.readdirSync(d, { recursive: true }).filter((f) => f.endsWith(".svg")).length;
console.log(`index.html ${(html.length / 1024).toFixed(0)} KB, ${count(svgDir)} SVGs in svg/`);
