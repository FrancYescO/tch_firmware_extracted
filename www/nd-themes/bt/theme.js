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
        main: "#5514B4",
        dark: "#400F87",
        light: "#9972D2",
    },
    secondary: {
        main: "#E60050",
        dark: "#AD003C",
        light: "#F06696",
    },
    error: {
        main: "#14AA37",
        dark: "#0F8029",
        light: "#72CC87",
    },
    warning: {
        main: "#14AA37",
        dark: "#0F8029",
        light: "#72CC87",
    },
    info: {
        main: "#14AA37",
        dark: "#0F8029",
        light: "#72CC87",
    },
    success: {
        main: "#14AA37",
        dark: "#0F8029",
        light: "#72CC87",
    },
    background: {
        default: "#ffffff",
        paper: "#EDEDED"
    },
    backdrop: {
        default: "rgba(237,237,237,0.75)",
        noblur: "rgba(237,237,237,0.9)"
    },
    map: {
        // text colour at 10% for map country
        country: "rgba(16,16,16,0.15)",
        // map container background colour for strokes
        countryStroke: "#EDEDED",
        background: "#EDEDED"
    },
    geofilter: {
        radius: "#5514B4",
        icon: "#101010",
        iconBlocked: "#FF8D00",
        iconDormant: "#5e5e5e",
    },
    rating: {
        F: "rgba(255,255,255,0.39)",
        D: "#E60050",
        C: "#F46000",
        B: "#FFC800",
        A: "#14AA37",
        APlus: "#72CC87",
    },
    graphs: {
        colours: [
            "#5514B4",
            "#E60050",
            "#FF8D00",
            "#14AA37",
            "#400F87",
            "#AD003C",
            "#F46000",
            "#0F8029",
            "#9972D2",
            "#F06696",
            "#FF8D00",
            "#72CC87",
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

((THEMES = typeof THEMES === "undefined" ? {} : THEMES).all_themes = THEMES.all_themes || {}).bt = __webpack_exports__;
/******/ })()
;