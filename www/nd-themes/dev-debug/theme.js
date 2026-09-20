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
// ESM COMPAT FLAG
__webpack_require__.r(__webpack_exports__);

// EXPORTS
__webpack_require__.d(__webpack_exports__, {
  "palette": () => (/* binding */ palette),
  "theme": () => (/* binding */ theme)
});

;// CONCATENATED MODULE: external "material_ui.core"
const external_material_ui_core_namespaceObject = material_ui.core;
;// CONCATENATED MODULE: ./nd-themes/dev-debug/theme.ts

const palette = {
    primary: {
        main: external_material_ui_core_namespaceObject.colors.green[700],
        dark: external_material_ui_core_namespaceObject.colors.green[100],
        light: external_material_ui_core_namespaceObject.colors.green.A100,
    },
    secondary: {
        main: external_material_ui_core_namespaceObject.colors.yellow[700],
        dark: external_material_ui_core_namespaceObject.colors.yellow[100],
        light: external_material_ui_core_namespaceObject.colors.yellow.A100,
    },
    background: {
        default: external_material_ui_core_namespaceObject.colors.red[400],
        paper: external_material_ui_core_namespaceObject.colors.red.A100,
    },
    backdrop: {
        default: "rgba(255,255,255,0.75)",
        noblur: "rgba(255,255,255,0.9)"
    },
    geofilter: {
        radius: external_material_ui_core_namespaceObject.colors.blue[500],
        iconBlocked: external_material_ui_core_namespaceObject.colors.blue[100],
    },
    graphs: {
        colours: [
            "#631D76",
            "#9E4770",
            "#FBFBFB",
            "#2e2532",
            "#201a23",
            "#e8aeb7",
            "#b8e1ff",
            "#a9fff7",
            "#94fbab",
            "#82aba1",
        ]
    },
    map: {
        country: "#009dc4",
        countryStroke: "#70483c",
        background: "#70483c"
    },
};
const theme = (palette) => ({
    palette: palette,
    typography: {
        // yes
        fontFamily: 'DumaFontIcons',
    },
    components: {
        // MuiCssBaseline: {
        //   '@global': {
        //     body: {
        //       backgroundColor: palette.tertiary[900],
        //     },
        //   }
        // },
        MuiButton: {
            defaultProps: {
                variant: "contained",
            },
            styleOverrides: {
                contained: {
                    color: palette.primary.contrastText,
                    backgroundColor: palette.primary.main,
                },
            }
        }
    }
});

})();

((THEMES = typeof THEMES === "undefined" ? {} : THEMES).all_themes = THEMES.all_themes || {})["dev-debug"] = __webpack_exports__;
/******/ })()
;