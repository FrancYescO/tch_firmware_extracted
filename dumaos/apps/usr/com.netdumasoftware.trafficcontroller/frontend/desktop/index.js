browserSetup.onReady(function() {
    $(document).ready(function() {
        var packageId = "com.netdumasoftware.trafficcontroller";
        var panels = $("duma-panels")[0];
        panels.add(
            "/apps/" + packageId + "/desktop/rules.html",
            packageId, null, {
                width: 8,
                height: 12,
                x: 0,
                y: 0
            }
        );
        panels.add(
            "/apps/" + packageId + "/desktop/traffic_numbers.html",
            packageId, null, {
                width: 4,
                height: 6,
                x: 8,
                y: 0
            }
        );
        panels.add(
            "/apps/" + packageId + "/desktop/logs.html",
            packageId, null, {
                width: 4,
                height: 6,
                x: 8,
                y: 6
            }
        );
    });
});
