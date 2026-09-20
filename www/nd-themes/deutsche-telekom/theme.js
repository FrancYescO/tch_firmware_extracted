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
        main: "#E20074",
        dark: "#9E065D",
        light: "#FF64A0",
    },
    secondary: {
        main: "#42B4EC",
        dark: "#2873C8",
        light: "#8EDBF4",
    },
    error: {
        main: "#E20074",
        dark: "#9E065D",
        light: "#FF64A0",
    },
    warning: {
        main: "#FFAF00",
        dark: "#F08700",
        light: "#FFE128",
    },
    info: {
        main: "#42B4EC",
        dark: "#2873C8",
        light: "#8EDBF4",
    },
    success: {
        main: "#41A037",
        dark: "#327828",
        light: "#78D278",
    },
    background: {
        default: "#FFFFFF",
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
        radius: "#E20074",
        icon: "#101010",
        iconBlocked: "#FFAF00",
        iconDormant: "#5E5E5E",
    },
    rating: {
        F: "rgba(255,255,255,0.39)",
        D: "#E20074",
        C: "#F08700",
        B: "#FFAF00",
        A: "#327828",
        APlus: "#41A037",
    },
    graphs: {
        colours: [
            "#E20074",
            "#42B4EC",
            "#FFAF00",
            "#41A037",
            "#9E065D",
            "#2873C8",
            "#F08700",
            "#327828",
            "#FF64A0",
            "#8EDBF4",
            "#FFE128",
            "#78D278",
        ]
    }
};
const theme = (palette) => ({
    palette: palette,
    components: {}
});

})();

((THEMES = typeof THEMES === "undefined" ? {} : THEMES).all_themes = THEMES.all_themes || {})["deutsche-telekom"] = __webpack_exports__;
/******/ })()
;