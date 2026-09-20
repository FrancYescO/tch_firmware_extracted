/******/ (() => { // webpackBootstrap
/******/ 	// runtime can't be in strict mode because a global variable is assign and maybe created.
/******/ 	// The require scope
/******/ 	var __webpack_require__ = {};
/******/ 	
/************************************************************************/
/******/ 	/* webpack/runtime/define property getters */
/******/ 	(() => {
/******/ 		// define getter functions for harmony exports
/******/ 		__webpack_require__.d = (exports, definition) => {
/******/ 			for(var key in definition) {
/******/ 				if(__webpack_require__.o(definition, key) && !__webpack_require__.o(exports, key)) {
/******/ 					Object.defineProperty(exports, key, { enumerable: true, get: definition[key] });
/******/ 				}
/******/ 			}
/******/ 		};
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/hasOwnProperty shorthand */
/******/ 	(() => {
/******/ 		__webpack_require__.o = (obj, prop) => (Object.prototype.hasOwnProperty.call(obj, prop))
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/make namespace object */
/******/ 	(() => {
/******/ 		// define __esModule on exports
/******/ 		__webpack_require__.r = (exports) => {
/******/ 			if(typeof Symbol !== 'undefined' && Symbol.toStringTag) {
/******/ 				Object.defineProperty(exports, Symbol.toStringTag, { value: 'Module' });
/******/ 			}
/******/ 			Object.defineProperty(exports, '__esModule', { value: true });
/******/ 		};
/******/ 	})();
/******/ 	
/************************************************************************/
var __webpack_exports__ = {};
// This entry need to be wrapped in an IIFE because it need to be in strict mode.
(() => {
"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "palette": () => (/* binding */ palette),
/* harmony export */   "theme": () => (/* binding */ theme)
/* harmony export */ });
const palette = {
    // mode: "light",
    action: {
        active: "rgba(16, 16, 16, 0.54)",
        hover: "rgba(16, 16, 16, 0.04)",
        selected: "rgba(16, 16, 16, 0.08)",
        disabled: "rgba(16, 16, 16, 0.26)",
        disabledBackground: "rgba(16, 16, 16, 0.12)",
    },
    divider: "rgba(16, 16, 16, 0.12)",
    text: {
        primary: "#101010",
        secondary: "rgba(16,16,16,0.75)",
        disabled: "rgba(16,16,16,0.39)",
    },
    primary: {
        main: "#00a1de",
        dark: "#0064aa",
        light: "#66c7eb",
    },
    secondary: {
        main: "#ff4678",
        dark: "#d20f46",
        light: "#ff82aa",
    },
    error: {
        main: "#d20f46",
        dark: "#0F8029",
        light: "#72CC87",
    },
    warning: {
        main: "#ffbe00",
        dark: "#0F8029",
        light: "#72CC87",
    },
    info: {
        main: "#00a1de",
        dark: "#0F8029",
        light: "#72CC87",
    },
    success: {
        main: "#00873c",
        dark: "#0F8029",
        light: "#72CC87",
    },
    background: {
        default: "#ffffff",
        paper: "#EDEDED",
    },
    backdrop: {
        default: "rgba(237,237,237,0.75)",
        noblur: "rgba(237,237,237,0.9)"
    },
    map: {
        country: "rgba(16,16,16,0.15)",
        countryStroke: "#EDEDED",
        background: "#EDEDED"
    },
    geofilter: {
        radius: "#00a1de",
        icon: "#101010",
        iconBlocked: "#f08700",
        iconDormant: "#5e5e5e",
    },
    rating: {
        F: "rgba(255,255,255,0.39)",
        D: "#d20f46",
        C: "#f08700",
        B: "#ffbe00",
        A: "#00b464",
        APlus: "#00873c",
    },
    graphs: {
        colours: [
            "#00a1de",
            "#ff4678",
            "#ffbe00",
            "#00b464",
            "#0064aa",
            "#d20f46",
            "#f08700",
            "#00873c",
            "#66c7eb",
            "#ff82aa",
            "#ffde66",
            "#66d4a2",
        ]
    }
};
const theme = (palette) => ({
    palette: palette,
    components: {}
});

})();

((THEMES = typeof THEMES === "undefined" ? {} : THEMES).all_themes = THEMES.all_themes || {}).orbi = __webpack_exports__;
/******/ })()
;