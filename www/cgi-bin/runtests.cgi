#!/bin/sh
# (C) 2016 NETDUMA Software
# Iain Fraser <iainf@netduma.com>
# Run unit tests as CGI script.

echo "Content-Type: text/html"
echo ""
echo "<html><body>"
# run test
echo "<h2>OS API Tests</h2>"
echo "<pre>"
find /dumaos/api/ -name unittest -type d | sed s,unittest$,, | xargs /dumaos/testing/unit-tester/lua/unittest.sh
echo "</pre>"

echo "<h2>System R-App Tests</h2>"
echo "<pre>"
find /dumaos/apps/system/ -name unittest -type d | sed s,unittest$,, | xargs /dumaos/testing/unit-tester/lua/unittest.sh
echo "</pre>"

echo "<h2>User R-App Tests</h2>"
echo "<pre>"
find /dumaos/apps/usr/ -name unittest -type d | sed s,unittest$,, | xargs /dumaos/testing/unit-tester/lua/unittest.sh
echo "</pre>"

echo "</body></html>"
