// Builds ../index.html (self-contained) and ../svg/ from icons/*.mjs, the Peaks drawings as they shipped before
// this round (assets/peaks/), notes.json and template.html. The 16 and 32 px pixel views are rendered with rsvg-convert,
// so the page shows exactly what build-icon.sh would put in the .icns.
// Run: node docs/4-icon-elevate-2026-11-15/source/build.mjs   (needs rsvg-convert)
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { loadOption, writeOption, png, masked } from "./render.mjs";
import { TILE } from "./shape.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const read = (f) => fs.readFileSync(path.join(here, f), "utf8");
const notes = JSON.parse(read("notes.json"));

fs.rmSync(path.join(root, "svg"), { recursive: true, force: true });
const options = [];
for (const slug of ["peaks", ...notes.order]) {
  const o = await loadOption(slug);
  if (slug !== "peaks") writeOption(o);
  const n = notes.options[slug] || {};
  options.push({
    slug, name: n.name || o.meta.name, idea: n.idea || o.meta.idea, verdict: n.verdict || "", tag: n.tag || "",
    master: o.master, small: o.small, bleed: o.bleed,
    // What macOS 26 draws: the bleed art under the system shape (Assets.car), at 16 and 32 px.
    b16: "data:image/png;base64," + png(masked(o.bleed), 16).toString("base64"),
    b32: "data:image/png;base64," + png(masked(o.bleed), 32).toString("base64"),
    // The .icns fallback's 16 px small cut.
    s16: "data:image/png;base64," + png(o.small, 16).toString("base64"),
  });
}

const asset = (f) => read(`assets/${f}`).trim();
const family = [
  ["DayNight", "data:image/png;base64," + asset("daynight-menubar-app.b64")],
  ["MediaKeys", "data:image/png;base64," + asset("mediakeys-for-spotify.b64")],
  ["Screenshot Pathname", "data:image/png;base64," + asset("screenshot-pathname.b64")],
  ["Polaris", "data:image/svg+xml;base64," + Buffer.from(asset("polaris.svg")).toString("base64")],
];
const data = `const OPTIONS = ${JSON.stringify(options)};\nconst FAMILY = ${JSON.stringify(family)};\nconst NOTES = ${JSON.stringify({ recommendation: notes.recommendation, recommended: notes.recommended, ranking: notes.ranking })};\nconst TILE = ${JSON.stringify(TILE)};`;
const html = read("template.html").replace("/*__DATA__*/", () => data);
fs.writeFileSync(path.join(root, "index.html"), html);
const count = fs.readdirSync(path.join(root, "svg"), { recursive: true }).filter((f) => f.endsWith(".svg")).length;
console.log(`index.html ${(html.length / 1024).toFixed(0)} KB, ${count} SVGs in svg/`);
