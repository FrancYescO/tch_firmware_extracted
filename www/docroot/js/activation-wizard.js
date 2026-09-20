var wpsPressed = false,
    connectionTimeout = 0,
    connection,
    isPPPOE,
    hasWANIP;
$(document).ready(function() {
    // Add smooth scrolling to all links
    $('input:radio[name=connection]').removeClass("radio-checked").addClass("radio-unchecked");
    $("html, body").animate({
        scrollTop: 0
    }, "slow");

    //Initial start function
    $("#aw-btn-start").click(function() {
        $.post("/activation-wizard.lp", {
            action: "Start",
            CSRFtoken: $("[name=CSRFtoken]").attr("content")
        }, function(data) {
            if (data.activationStatus == "Completed") {
                showWifi();
            } else if (data.activationStatus == "In_Progress") {
                window.location = "/activation-inprogress.lp"
            } else {
                $(".press-start").addClass("hide");
                $(".check-internet, .icon-loading").removeClass("hide");
                $("#aw-btn-start").addClass("hide");
                checkInternet(true);
            }
        });
    });

    $(".aw-info-wifiFail").addClass('hide');
    //connection type check and validate
    $(".connection-type input[name='connection']").click(function() {
        $('input:radio[name=connection]').removeClass("radio-checked").addClass("radio-unchecked");
        if ($('input:radio[name=connection]:checked')) {
            $(this).removeClass("radio-unchecked").addClass("radio-checked");
            $(".next-btn").removeClass("op40");
        }
    });

    //Next button function for all modules
    $(".next-btn").click(function() {
        if ($(".connection-type").is(":visible")) {
            $("#topBarRightSteps div:lt(2)").addClass("actv");
            if ($(":radio:visible:checked").val() == 'ADSL') {
                $(".topbar-steps-states, .connect-cable, .connection-type, .vdf-box, .fibre-internet, .wizard-states, .topbar-steps-connect-cable, .back-btn").addClass("hide");
                $(".back-btn, .connect-adsl, .topbar-steps-connect-adsl, .adsl-internet").removeClass("hide");
            } else {
                $(".topbar-steps-states, .connect-adsl, .connection-type, .vdf-box, .wizard-states, .adsl-internet, .topbar-steps-connect-adsl, .back-btn").addClass("hide");
                $(".back-btn, .connect-cable, .topbar-steps-connect-cable, .fiber-internet").removeClass("hide");
            }
        } else if ($(".connect-cable").is(":visible")) {
            checkInternet(false, "ETH");
        } else if ($(".connect-adsl").is(":visible")) {
            checkInternet(false, "DSL");
        } else if ($(".pppoe-connection").is(":visible")) {
            $(".wizard-states, .check-internet, .icon-loading").removeClass("hide");
            $(".pppoe-connection, .press-start").addClass('hide');
            $.post("/activation-wizard.lp", {
                action: "SAVE",
                username: $("#aw-txt-username").val(),
                password: $("#aw-txt-password").val(),
                CSRFtoken: $("[name=CSRFtoken]").attr("content")
            }, function() {
                checkInternet();
            });
        } else if ($("[id*=conn-err], .connect-cable-ok").is(":visible")) {
            showWifi();
        } else if ($(".wifi-setup").is(":visible")) {
            showWifiBinding();
        } else if ($(".wifi-device-detect-ok").is(":visible")) {
            showPhone();
        } else if ($(".connect-phone").is(":visible")) {
            showFinish();
        }
    });

    //back button function for connection type
    $(".back-btn").click(function() {
        $(".topbar-steps-states, .connection-type, .vdf-box, .wizard-states").removeClass("hide");
        $(".back-btn, .topbar-steps-connect-adsl, .connect-cable, .connect-adsl, .topbar-steps-connect-cable, .fiber-internet, #conn-err-ADSL, #conn-err-Fibre").addClass("hide");
        $("#topBarRightSteps>div.actv").last().removeClass("actv");
    });

    //back button function for wps
    $(".back-btn-wps").click(function() {
        $(".wifi-setup, .topbar-steps-wifi-setup, .wifi-setup-description, .next-btn, .skip-btn, .wps-btn").removeClass("hide");
        $(".wps-pairing, .wps-pairing-description, .topbar-steps-wps-pairing, .back-btn-wps, .vdf-box, .pairing-btn, .back-btn-wps, .wifi-device-detect-ok").addClass("hide");
    });

    //wps button function for wps pairing
    $(".wps-btn").click(function() {
        wpsPressed = true;
        $(".vdf-box, .topbar-steps-wifi-setup, .wifi-setup, .wifi-setup-description, .wifi-setup-adsl, .wifi-device-detect-ok, .next-btn, .skip-btn, .wps-btn, .aw-info-wifiFail, .press-start").addClass("hide");
        $(".wps-pairing, .wps-pairing-description, .topbar-steps-wps-pairing, .pairing-btn, .back-btn-wps").removeClass("hide");
    });

    // Skip from WiFi
    $(".skip-btn").click(function() {
        if ($(".pppoe-connection").is(":visible")) {
            showWifi();
        } else {
            showPhone();
        }
    });

    //next button function for finish
    $(".next-btn-skip").click(function() {
        $(".wifi-device-detect-ok, .setup-more-btn, .wizard-states, .check-wifi-binding, .icon-loading, .connect-phone, .topbar-steps-connect-phone, .next-btn-skip").addClass("hide");
        $(".vdf-box, .topbar-steps-finish, .finish, .done-btn").removeClass("hide");
        $("#topBarRightSteps div").addClass("actv");
    });

    //next button function for finish
    $(".pairing-btn").click(function() {
        $(".wps-pairing, .wps-pairing-description, .pairing-btn, .back-btn-wps, .check-internet").addClass("hide");
        $(".icon-loading, .wizard-states, .wps-pairing-ok, .vdf-box").removeClass("hide");
        $.get("/activation-wizard.lp?action=pairing", function(data) {
            data = data.wpsStatus;
            $(".icon-loading, .wizard-states, .wps-pairing-ok, .back-btn-wps, .pairing-btn").addClass("hide");
            if (data == "success") {
                $(".wps-pairing-success, .setup-more-btn, .next-btn-pairing").removeClass("hide");
                $(".aw-info-wifiFail").addClass("hide");
            } else {
                $(".aw-info-wifiFail, .retry-description").removeClass("hide");
            }
        });
    });

    //next button function for troubleshoot tips
    $(".next-btn-pairing").click(function() {
        $(".wps-pairing-success, .setup-more-btn, .topbar-steps-wps-pairing, .next-btn-pairing").addClass("hide");
        $(".topbar-steps-connect-phone, .next-btn-phone, .connect-phone").removeClass("hide");
        $("#topBarRightSteps>div.actv").last().next().addClass("actv");
    });

    //next pairing button function for finish
    $(".next-btn-phone").click(function() {
        $(".topbar-steps-connect-phone, .next-btn-phone").addClass("hide");
        $(".topbar-steps-finish, .finish, .done-btn").removeClass("hide");
        $("#topBarRightSteps>div.actv").last().next().addClass("actv");
    });

    //setup more button function for wifi setup and description
    $(".setup-more-btn").click(function() {
        $(".topbar-steps-wps-pairing, .vdf-box, .wps-pairing-success, .setup-more-btn, .next-btn-pairing, .wifi-device-detect-ok").addClass("hide");
        $(".topbar-steps-wifi-setup, .wifi-setup, .wifi-setup-description, .skip-btn, .wps-btn, .next-btn").removeClass("hide");
    });

    //done button function for redirect to homepage
    $(".done-btn").click(function() {
        $.post("/activation-wizard.lp", {
            action: "Finish",
            CSRFtoken: $("[name=CSRFtoken]").attr("content")
        }, function() {
            location.href = "/home.lp";
        });
    });

    $("#aw-btn-wifiSkip").click(function() {
        if (wpsPressed) {
            wpsPressed = false;
            showWifi();
        } else showPhone();
    });

    $("#aw-btn-wifiRetry").click(function() {
        $("#activation-content-bottom :button:visible").addClass("hide");
        if (wpsPressed) {
            $(".wps-btn").click();
        } else showWifi();
    });

    $("#aw-chk-showPasswd").click(function() {
        $("[id^=aw-info-wpa]").toggle();
    });

    $('input:radio[name=connection]').click(function() {
        $(".next-btn").removeClass('op40');
    });

    $(".retry-internet").click(function() {
        $(".press-start").addClass('hide');
        connectionTimeout = 0;
        checkInternet(true);
    });

    $(".skip-internet").click(function() {
        showWifi();
    });

    if (window.location.href.indexOf(location.protocol+"//adsl.vf") === 0 || location.href.match("pppoe=1$")) {
        showPPPOE();
    }

});

function showInternetOK() {
    $("#activation-top-left span, .welcome-text, .description, .wizard-states, .icon-loading, .txt-space, :button, .row-wizard").addClass("hide");
    $(".topbar-steps-start, .next-btn, .topbar-steps-internet-connect, .connect-cable-ok").removeClass("hide");
    $("#topBarRightSteps div:lt(2)").addClass("actv");
}

function showInternetError() {
    $("#activation-top-left span, .welcome-text, .description, .wizard-states, .icon-loading, .txt-space, :button, .row-wizard, .vdf-box").addClass("hide");
    $(".topbar-steps-start, .topbar-steps-internet-connect, .aw-err-timedout, .conn-timedout, .skip-internet, .retry-internet, .ads-troubleshoot").removeClass("hide");
    $("#topBarRightSteps div:lt(2)").addClass("actv");
}

function showWifi() {
    $(".description, .connect-cable-ok, .wizard-states, .txt-space, .topbar-steps-internet-connect, .vdf-box, #conn-err-ADSL, #conn-err-Fibre, :button, .icon-loading, .welcome-text, .topbar-steps-wps-pairing, .aw-info-wifiFail, .ads-troubleshoot").addClass("hide");
    $(".activation-top, #topBarRightSteps, .topbar-steps-wifi-setup, .wifi-setup, .wifi-setup-description, .next-btn, .skip-btn, .wps-btn").removeClass("hide");
    $("#topBarRightSteps div:lt(3)").addClass("actv");
}

function showWifiBinding() {
    $(".wizard-states span, .description, .wifi-setup, :button").addClass("hide");
    $(".wizard-states, .check-wifi-binding, .icon-loading, .vdf-box").removeClass("hide");
    $.get("/activation-wizard.lp?action=getWifiDevices", function(data) {
        data = data.newDevice;
        if (!data) {
            $(".wizard-states, .check-wifi-binding, .icon-loading").addClass("hide");
            $(".retry-description, .aw-info-wifiFail").removeClass("hide");
        } else {
            $(".aw-info-wifiDevice").text(data);
            $(".wizard-states, .check-wifi-binding, .icon-loading").addClass("hide");
            $(".wifi-device-detect-ok, .setup-more-btn, .next-btn").removeClass("hide");
        }
    });
}

function showConnectionError(connectionType) {
    $(".connect-cable, .connect-adsl, .fiber-internet, .topbar-steps-connect-adsl, .topbar-steps-connect-cable, .adsl-internet, #conn-err-ADSL, #conn-err-Fibre, .back-btn, img:visible, .check-internet").addClass("hide");
    $(".topbar-steps-internet-connect, .vdf-box, .next-btn").removeClass("hide");
    if (connectionType.indexOf("DSL") != -1) {
        $(".connect-cable").addClass("hide");
        $("#conn-err-ADSL, #conn-err-ADSL .description").removeClass("hide");
    } else {
        $(".connect-adsl").addClass("hide");
        $("#conn-err-Fibre, #conn-err-Fibre .description").removeClass("hide");
    }
}

function showPPPOE() {
    $("#activation-top-left span, .welcome-text, .description, .wizard-states, .icon-loading, .txt-space, :button, .row-wizard, .topbar-steps-internet-connect").addClass("hide");
    $(".topbar-steps-start, #conn-pppoe, .pppoe-connection, .skip-btn, .next-btn").removeClass("hide");
    $("#topBarRightSteps div:lt(2)").addClass("actv");
}

function showPhone() {
    $(".topbar-steps-wifi-setup, .vdf-box, .wifi-device-detect-ok, .setup-more-btn, .wifi-setup, .wifi-setup-description, :button, .aw-info-wifiFail").addClass("hide");
    $(".connect-phone, .topbar-steps-connect-phone, .next-btn").removeClass("hide");
    $("#topBarRightSteps div:lt(4)").addClass("actv");
}

function showFinish() {
    $(".connect-phone, .topbar-steps-connect-phone, .next-btn, .aw-info-wifiFail").addClass("hide");
    $(".vdf-box, .topbar-steps-finish, .finish, .done-btn").removeClass("hide");
    $("#topBarRightSteps div").addClass("actv");
}

function checkInternet(start, connectionType) {
    $("#activation-top-left span, #activation-content-left img, .description, :button").addClass('hide');
    $(".wizard-states, .check-internet, .icon-loading, .vdf-box").removeClass("hide");
    start && $(".topbar-steps-internet-connect").addClass("hide");
    setTimeout(function() {
        $.get("/activation-wizard.lp?action=getInternetStatus", function(data) {
            connection = data.l2type;
            isPPPOE = data.proto == "pppoe";
            hasWANIP = !!data.wanIP;
            if (hasWANIP) {
                showInternetOK();
            } else if (start) {
                if (connection.indexOf("DSL") != -1) {
                    isPPPOE ? showPPPOE() : checkInternet();
                } else if (connection == "ETH") {
                    checkInternet();
                } else {
                    showChooseConnection();
                }
            } else {
                connectionTimeout += 3;
                if (connectionType && connection && (connection.indexOf(connectionType) == -1)) {
                    showConnectionError(connection);
                } else if (connectionTimeout > 30) {
                    showInternetError();
                    return;
                } else {
                    checkInternet(false, connection && connection.indexOf("DSL") != -1 ? "DSL" : connection);
                }
            }
        }).fail(function() {
            showInternetError();
        });
    }, 3000);
}

function showChooseConnection() {
    $(".welcome-text, .check-internet, .icon-loading, #aw-btn-start, .txt-space").addClass("hide");
    $(".connection-type, .topbar-steps-states, .topbar-steps-start, .next-btn").removeClass("hide");
    $(".next-btn").addClass('op40');
    $('input:radio[name=connection]').prop("checked", false);
}
