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
    mode: "dark",
    action: {
        active: "rgba(255, 255, 255, 0.54)",
        hover: "rgba(255, 255, 255, 0.04)",
        selected: "rgba(255, 255, 255, 0.08)",
        disabled: "rgba(255, 255, 255, 0.26)",
        disabledBackground: "rgba(255, 255, 255, 0.12)",
    },
    divider: "rgba(255, 255, 255, 0.12)",
    text: {
        primary: "#ffffff",
        secondary: "rgba(255,255,255,0.75)",
        disabled: "rgba(255,255,255,0.39)",
    },
    primary: {
        main: "#028ED4",
        dark: "#0054A3",
        light: "#67BBE5",
    },
    secondary: {
        main: "#CA1E49",
        dark: "#970039",
        light: "#ED7392",
    },
    info: {
        main: "#028ED4",
        dark: "#0054A3",
        light: "#67BBE5",
    },
    background: {
        default: "#191919",
        paper: "#2B2B2B"
    },
    backdrop: {
        default: "rgba(43,43,43,0.75)",
        noblur: "rgba(43,43,43,0.9)"
    },
    geofilter: {
        radius: "#028ED4",
        icon: "#ffffff",
        iconBlocked: "#FDB913",
        iconDormant: "#5e5e5e",
    },
    rating: {
        F: "rgba(255,255,255,0.39)",
        D: "#C9234A",
        C: "#C86700",
        B: "#FDBA0B",
        A: "#04B24A",
        APlus: "#5AD46D",
    },
    graphs: {
        colours: [
            "#028ED4",
            "#CA1E49",
            "#FDB913",
            "#04B24A",
            "#0054A3",
            "#970039",
            "#F3701B",
            "#007E2E",
            "#67BBE5",
            "#ED7392",
            "#FED571",
            "#5AD46D",
        ]
    }
};
const theme = (palette) => ({
    palette: palette,
    components: {
    // MuiCssBaseline: {
    //   '@global': {
    //     body: {
    //       backgroundColor: palette.tertiary[900],
    //     },
    //   }
    // },
    }
});

})();

((THEMES = typeof THEMES === "undefined" ? {} : THEMES).all_themes = THEMES.all_themes || {}).xfinity = __webpack_exports__;
/******/ })()
;