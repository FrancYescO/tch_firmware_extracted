#
# (C) 2016 NETDUMA Software
# Kian Cross <kian.cross@netduma.com>
#

SEARCH_DIR=custom-elements

# All
find "$SEARCH_DIR" -iname bower.* -exec rm -r "{}" \;
find "$SEARCH_DIR" -iname .bower* -exec rm -r "{}" \;
find "$SEARCH_DIR" -iname .git* -exec rm -rf "{}" \;
find "$SEARCH_DIR" -iname index.html -exec rm -r "{}" \;
find "$SEARCH_DIR" -iname .travis.yml -exec rm -r "{}" \;
find "$SEARCH_DIR" -iname test -exec rm -r "{}" \;
find "$SEARCH_DIR" -iname tests -exec rm -r "{}" \;
find "$SEARCH_DIR" -iname demo -exec rm -r "{}" \;
find "$SEARCH_DIR" -iname demos -exec rm -r "{}" \;
find "$SEARCH_DIR" -iname site -exec rm -r "{}" \;
find "$SEARCH_DIR" -iname CONTRIBUTING* -exec rm -r "{}" \;
find "$SEARCH_DIR" -iname docs* -exec rm -r "{}" \;
find "$SEARCH_DIR" -iname README* -exec rm -r "{}" \;
find "$SEARCH_DIR" -iname build* -exec rm -r "{}" \;
find "$SEARCH_DIR" -iname package.json -exec rm -r "{}" \;
find "$SEARCH_DIR" -iname .package.json -exec rm -r "{}" \;
find "$SEARCH_DIR" -iname COPYING* -exec rm -r "{}" \;
find "$SEARCH_DIR" -iname history* -exec rm -r "{}" \;
find "$SEARCH_DIR" -iname *.map -exec rm -r "{}" \;
find "$SEARCH_DIR" -iname hero.svg -exec rm -r "{}" \;
find "$SEARCH_DIR" -iname guide* -exec rm -r "{}" \;
find "$SEARCH_DIR" -iname LICENSE* -exec rm -r "{}" \;
find "$SEARCH_DIR" -iname LICENCE* -exec rm -r "{}" \;
find "$SEARCH_DIR" -iname .github* -exec rm -r "{}" \;
find "$SEARCH_DIR" -iname .gitignore* -exec rm -r "{}" \;

find "${SEARCH_DIR}/app-layout" -iname templates -exec rm -r "{}" \;

find "${SEARCH_DIR}/webcomponentsjs" -iname *.js -not -iname *.min.js -exec rm -r "{}" \;
find "${SEARCH_DIR}/webcomponentsjs" -iname webcomponents.min.js -exec rm -r "{}" \;

find "${SEARCH_DIR}/paper-tree" -iname catalog.html -exec rm -r "{}" \;
