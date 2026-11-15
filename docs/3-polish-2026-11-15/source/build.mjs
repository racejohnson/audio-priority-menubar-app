// Builds ../index.html (self-contained) and ../svg/ from art.mjs, base.css and template.html.
// Run: node docs/3-polish-2026-11-15/source/build.mjs
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

// DJI glyph (Solid + clip): regular and small cut, plain and on the grid.
for (const small of [false, true]) {
  const cut = small ? "-small" : "";
  write(`dji/dji-mic-mini${cut}.svg`, A.djiSVG({ small }));
  write(`dji/dji-mic-mini${cut}-grid.svg`, A.djiSVG({ small, grid: true }));
}

// Capsule (Soft), each side showing the device that owns it.
export const COMBOS = [
  { id: "desk", label: "MacBook speakers + DJI mic", out: "laptopcomputer", in: "dji" },
  { id: "airpods", label: "AirPods + AirPods mic", out: "airpods.pro", in: "airpods.pro" },
  { id: "airpods-dji", label: "AirPods + DJI mic", out: "airpods.pro", in: "dji" },
  { id: "display", label: "Display speakers + MacBook mic", out: "display", in: "laptopcomputer" },
  { id: "macbook", label: "MacBook speakers + MacBook mic", out: "laptopcomputer", in: "laptopcomputer" },
  { id: "manual", label: "Auto off: MacBook + DJI", out: "laptopcomputer", in: "dji", manual: true },
];
// These embed Apple's symbols as PNG masks: mock-ups, not app assets.
for (const c of COMBOS) write(`menubar/capsule-${c.id}.svg`, A.capsule(c.out, c.in, { manual: !!c.manual }));

// App icon (Peaks): default, dark, tinted, and the 16/32 drawing in each.
for (const m of ["light", "dark", "tinted"]) {
  const suffix = m === "light" ? "" : `-${m}`;
  write(`app-icon/peaks${suffix}.svg`, A.appIcon(m));
  write(`app-icon/peaks-small${suffix}.svg`, A.appIconSmall(m));
}

// Page.
const read = (f) => fs.readFileSync(path.join(here, f), "utf8");
const asset = (f) => read(`assets/${f}`).trim();
const family = {
  daynight: "data:image/png;base64," + asset("daynight-menubar-app.b64"),
  mediakeys: "data:image/png;base64," + asset("mediakeys-for-spotify.b64"),
  screenshot: "data:image/png;base64," + asset("screenshot-pathname.b64"),
  polaris: "data:image/svg+xml;base64," + Buffer.from(asset("polaris.svg")).toString("base64"),
};
const data = `const SFDATA = ${JSON.stringify(SF)};\nconst FAMILY = ${JSON.stringify(family)};\nconst COMBOS = ${JSON.stringify(COMBOS)};`;
const html = read("template.html")
  .replace("/*__BASE__*/", () => read("base.css").trim())
  .replace("/*__ART__*/", () => read("art.mjs").replace(/^export /gm, ""))
  .replace("/*__DATA__*/", () => data);
fs.writeFileSync(path.join(root, "index.html"), html);
const count = (d) => fs.readdirSync(d, { recursive: true }).filter((f) => f.endsWith(".svg")).length;
console.log(`index.html ${(html.length / 1024).toFixed(0)} KB, ${count(svgDir)} SVGs in svg/`);
