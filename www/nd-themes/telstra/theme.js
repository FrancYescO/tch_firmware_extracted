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
        main: "#0064D2",
        dark: "#0036A7",
        light: "#0098F7",
    },
    secondary: {
        main: "#FE2795",
        dark: "#C4006C",
        light: "#FF66B6",
    },
    error: {
        main: "#FE2795",
        dark: "#C4006C",
        light: "#FF66B6",
    },
    warning: {
        main: "#F08C21",
        dark: "#D85107",
        light: "#FFAD78",
    },
    info: {
        main: "#0064D2",
        dark: "#0036A7",
        light: "#0098F7",
    },
    success: {
        main: "#00B6B4",
        dark: "#00828C",
        light: "#21D8C6",
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
        radius: "#0064D2",
        icon: "#101010",
        iconBlocked: "#FE2795",
        iconDormant: "#5e5e5e",
    },
    rating: {
        F: "rgba(255,255,255,0.39)",
        D: "#D71479",
        C: "#D85107",
        B: "#F08C21",
        A: "#00828C",
        APlus: "#00B6B4",
    },
    graphs: {
        colours: [
            "#0064D2",
            "#FE2795",
            "#F08C21",
            "#00B6B4",
            "#0036A7",
            "#C4006C",
            "#D85107",
            "#00828C",
            "#0098F7",
            "#FF66B6",
            "#FFAD78",
            "#21D8C6",
        ]
    }
};
const theme = (palette) => ({
    palette: palette,
    components: {}
});

})();

((THEMES = typeof THEMES === "undefined" ? {} : THEMES).all_themes = THEMES.all_themes || {}).telstra = __webpack_exports__;
/******/ })()
;