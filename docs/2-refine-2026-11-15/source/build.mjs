// Builds ../index.html (self-contained) and ../svg/ from art.mjs + template.html.
// Run: node docs/2-refine-2026-11-15/source/build.mjs
// (Run sf-export.swift first if assets/sf.json is missing or the symbol list changed.)
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import * as A from "./art.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const svgDir = path.join(root, "svg");
const SF = JSON.parse(fs.readFileSync(path.join(here, "assets/sf.json"), "utf8"));
A.setSF(SF);
fs.rmSync(svgDir, { recursive: true, force: true });
const write = (rel, s) => {
  const p = path.join(svgDir, rel);
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, s + "\n");
};

// DJI glyph: each variant in its regular and small cut, plain and on the grid.
for (const o of A.DJI_OPTIONS)
  for (const small of [false, true]) {
    const cut = small ? "-small" : "";
    write(`dji/dji-${o.id}${cut}.svg`, A.djiSVG(o.id, { small }));
    write(`dji/dji-${o.id}${cut}-grid.svg`, A.djiSVG(o.id, { small, grid: true }));
  }

// Capsule: every finish in every combo. `in` has a glyph per input-side rule.
export const COMBOS = [
  { id: "desk", label: "MacBook speakers + DJI mic", out: "laptopcomputer", in: { mic: "dji", device: "dji" } },
  { id: "airpods", label: "AirPods + AirPods mic", out: "airpods.pro", in: { mic: "mic", device: "airpods.pro" } },
  { id: "airpods-dji", label: "AirPods + DJI mic", out: "airpods.pro", in: { mic: "dji", device: "dji" } },
  { id: "display", label: "Display speakers + MacBook mic", out: "display", in: { mic: "laptopcomputer", device: "laptopcomputer" } },
  { id: "macbook", label: "MacBook speakers + MacBook mic", out: "laptopcomputer", in: { mic: "mic", device: "laptopcomputer" } },
  { id: "manual", label: "Auto off: MacBook + DJI", out: "laptopcomputer", in: { mic: "dji", device: "dji" }, manual: true },
];
// The SVGs embed Apple's symbols as PNG masks: mock-ups, not app assets.
for (const o of A.CAPSULE_STYLES)
  for (const c of COMBOS) write(`menubar/capsule-${o.id}-${c.id}.svg`, A.capsule(o.id, c.out, c.in.mic, { manual: !!c.manual }).svg);

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
const reference = "data:image/png;base64," + fs.readFileSync(path.join(here, "assets/dji-reference.png")).toString("base64");
const data = `const SFDATA = ${JSON.stringify(SF)};\nconst FAMILY = ${JSON.stringify(family)};\nconst COMBOS = ${JSON.stringify(COMBOS)};\nconst REFERENCE = ${JSON.stringify(reference)};`;
const html = fs
  .readFileSync(path.join(here, "template.html"), "utf8")
  .replace("/*__ART__*/", () => art)
  .replace("/*__DATA__*/", () => data);
fs.writeFileSync(path.join(root, "index.html"), html);
const count = (d) => fs.readdirSync(d, { recursive: true }).filter((f) => f.endsWith(".svg")).length;
console.log(`index.html ${(html.length / 1024).toFixed(0)} KB, ${count(svgDir)} SVGs in svg/`);
