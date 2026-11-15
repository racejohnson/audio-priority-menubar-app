// Shared frame for every option in round 4. Each option draws its art in 1024
// space inside the 824 pt tile (100..924); these wrappers turn that art into
// the three files Icon/build-icon.sh expects:
//
//   master()  AppIcon.svg        1024 canvas: drop shadow, tile clip, hairline rim
//   small()   AppIcon-small.svg  a separate drawing on a 32 grid (tile 2..30)
//   bleed()   AppIcon-bleed.svg  the same art, no shadow/clip/rim, viewBox 100 100 824 824,
//                                so it fills the canvas edge to edge and macOS 26 applies the shape
//
// The tile is DayNight's (and Peaks') path, so the family construction holds.
export const TILE = "M382.8,100 L641.2,100 C722.63,100 763.34,100 807.17,113.86 C855.03,131.28 892.72,168.97 910.14,216.83 C924,260.66 924,301.37 924,382.8 L924,641.2 C924,722.63 924,763.34 910.14,807.17 C892.72,855.03 855.03,892.72 807.17,910.14 C763.34,924 722.63,924 641.2,924 L382.8,924 C301.37,924 260.66,924 216.83,910.14 C168.97,892.72 131.28,855.03 113.86,807.17 C100,763.34 100,722.63 100,641.2 L100,382.8 C100,301.37 100,260.66 113.86,216.83 C131.28,168.97 168.97,131.28 216.83,113.86 C260.66,100 301.37,100 382.8,100 Z";
export const TILE_S = "M11.63,2 L20.37,2 C23.14,2 24.53,2 26.02,2.47 C27.65,3.07 28.93,4.35 29.53,5.98 C30,7.47 30,8.86 30,11.63 L30,20.37 C30,23.14 30,24.53 29.53,26.02 C28.93,27.65 27.65,28.93 26.02,29.53 C24.53,30 23.14,30 20.37,30 L11.63,30 C8.86,30 7.47,30 5.98,29.53 C4.35,28.93 3.07,27.65 2.47,26.02 C2,24.53 2,23.14 2,20.37 L2,11.63 C2,8.86 2,7.47 2.47,5.98 C3.07,4.35 4.35,3.07 5.98,2.47 C7.47,2 8.86,2 11.63,2 Z";

// The app's colours.
export const OUT = { light: "#2f6fe4", dark: "#4b8dff" };
export const IN = { light: "#6a4fd8", dark: "#9479f0" };

/** id: a prefix unique to the option (its slug); defs: <defs> content; art: drawing in 1024 space, covering 100..924. */
export function wrapMaster(id, defs, art, { rim = "#fff", rimOpacity = 0.14 } = {}) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><defs>${defs}`
    + `<clipPath id="${id}-tc"><path d="${TILE}"/></clipPath>`
    + `<filter id="${id}-ts" x="-10%" y="-10%" width="120%" height="120%"><feGaussianBlur stdDeviation="14"/></filter></defs>`
    + `<path d="${TILE}" transform="translate(0,12)" fill="#000" opacity=".28" filter="url(#${id}-ts)"/>`
    + `<g clip-path="url(#${id}-tc)">${art}</g>`
    + `<path d="${TILE}" fill="none" stroke="${rim}" stroke-opacity="${rimOpacity}" stroke-width="3"/></svg>`;
}

/** Same art, full bleed: no shadow, clip or rim. */
export function wrapBleed(id, defs, art) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="100 100 824 824"><defs>${defs}</defs><g>${art}</g></svg>`;
}

/** 32 grid; art covers 0..32 and is clipped to the small tile. */
export function wrapSmall(id, defs, art) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><defs>${defs}<clipPath id="${id}-sc"><path d="${TILE_S}"/></clipPath></defs><g clip-path="url(#${id}-sc)">${art}</g></svg>`;
}
