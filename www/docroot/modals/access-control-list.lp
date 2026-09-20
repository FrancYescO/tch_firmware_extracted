--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')
  ngx.print('\
\
<script src="js/global.js"></script>\
<script>\
    $(function() {\
        $(\'select\').chosen({\
            disable_search_threshold: 100000,\
            allow_single_deselect: true\
        });\
    });\
</script>\
<div class="row no-margin-right">\
    <div class="col-xs-12 col-md-8 col-sm-8">\
        <h1>Access Control List</h1>\
    </div>\
</div>\
<h2>Placeholder text</h2>\
<div class="h3-content h3-content-mobile">\
\
    <div class="table-responsive margin-bottom-lg">\
        <table class="table wan-table" id="accesctrl-table-list">\
            <tbody>\
                <tr>\
                    <th>Name</th>\
                    <th>Order</th>\
                    <th>Interface</th>\
                    <th>Protocol</th>\
                    <th>Data Direction</th>\
                    <th>&nbsp;</th>\
                    <th>&nbsp;</th>\
                    <th>&nbsp;</th>\
                </tr>\
                <tr>\
                    <td>Name Example</td>\
                    <td>1</td>\
                    <td>WAN 1</td>\
                    <td>IPv4</td>\
                    <td>Output</td>\
                    <td>\
                        <input class="button button-edit mapping accessctrl-edit-viewmodal" value="" type="button" />\
                    </td>\
                    <td>\
                        <input class="button button-delete accectrl-btn-delete-row" value="" type="button" />\
                    </td>\
                    <td>\
                        <div id="access-btn-on-off" class="button button-on access-btn-on-off"></div>\
                    </td>\
                </tr>\
\
            </tbody>\
        </table>\
    </div>\
    <div class="row voice-status-row no-margin-left-right parent-control-mobile-entry-top">\
        <div class="col-md-12 col-xs-12 no-padding-left-right">\
            <p class="btn-add-right">\
                <input id="access-btn-add-row" class="button button-add" value="" type="button" />\
            </p>\
        </div>\
    </div>\
\
\
    <div class="row apply-cancel-hr no-margin-right">\
        <div class="col-md-12 col-sm-12 col-xs-12 no-padding-right">\
            <div class="articlediv hide">\
                <div class="message-arrowbox-applied">\
                    <div class="message-arrowbox-applied-right">\
                        <p class="success-info"></p>\
                    </div>\
                </div>\
            </div>\
            <input class="button button-apply mob-button-width" value="Apply" type="button" />\
            <input class="button button-cancel mob-button-width mob-apply-cancel" value="Cancel" type="button" />\
        </div>\
    </div>\
\
    <!-- Edit Popup Modal-->\
    <div class="modal fade" id="accessctrl-edit-modal" role="dialog">\
        <div class="modal-dialog">\
            <!-- Modal content-->\
            <div class="modal-content change-password-content">\
                <div class="modal-header hidden-sm hidden-md hidden-lg">\
                   <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
                </div>\
                <div class="modal-body no-padding">\
                    <form class="form-horizontal">\
                        <div class="form-group">\
                            <div class="col-sm-12">\
                                <p class="title tL">\
                                    Edit Access Control Rule\
                                </p>\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none ">\
                                <label for="Name" class="control-label">Name</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <input type="text" value="">\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
                                <label for="Order" class="control-label">Order</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <input type="text" value="">\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
                                <label for="policy" class="control-label">Policy</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <div id="top-info-mode" class="rel">\
                                    <select>\
                                        <option>Accept</option>\
                                        <option>Deny</option>\
                                    </select>\
                                </div>\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
                                <label for="interface" class="control-label">Interface</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <div id="top-info-mode" class="rel">\
                                    <select>\
                                        <option>LAN</option>\
                                        <option>WAN 1</option>\
                                        <option>WAN 2</option>\
                                    </select>\
                                </div>\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
                                <label for="protocol" class="control-label">Protocol</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <div id="top-info-mode" class="rel">\
                                    <select>\
                                        <option>IPv4</option>\
                                        <option>IPv6</option>\
                                    </select>\
                                </div>\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
                                <label for="Data Direction" class="control-label">Data Direction</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <div id="top-info-mode" class="rel">\
                                    <select>\
                                        <option>Input</option>\
                                        <option>Output</option>\
                                    </select>\
                                </div>\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
                                <label for="protocol" class="control-label">IP Protocol</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <div id="top-info-mode" class="rel">\
                                    <select>\
                                        <option>TCP</option>\
                                        <option>UDP</option>\
                                        <option>Both</option>\
                                    </select>\
                                </div>\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
                                <label for="Source IP" class="control-label">Source IP</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <input type="text" value="">\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
                                <label for="Source Mask" class="control-label">Source Mask</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <input type="text" value="">\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
                                <label for="Source Port Range" class="control-label">Source Port Range</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <div class="right halfWidth no-important col-xs-12 col-md-12 col-sm-12 col-lg-12 no-padding-left-right from-to-textbox pull-right">\
                                    <input class="max5 max5-range parent-max5 mobile-margin-bottom-20" value="" type="text" /><span>&#x2D;</span>\
                                    <input class="max5 max5-range parent-max5 mobile-margin-bottom-20" value="" type="text" />\
                                </div>\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
                                <label for="Destination IP" class="control-label">Destination IP</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <input type="text" value="">\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
                                <label for="Destination Mask" class="control-label">Destination Mask</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <input type="text" value="">\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
                                <label for="Destination Port Range" class="control-label">Destination Port Range</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <div class="right halfWidth no-important col-xs-12 col-md-12 col-sm-12 col-lg-12 no-padding-left-right from-to-textbox pull-right">\
                                    <input class="max5 max5-range parent-max5 mobile-margin-bottom-20" value="" type="text" /><span>&#x2D;</span>\
                                    <input class="max5 max5-range parent-max5 mobile-margin-bottom-20" value="" type="text" />\
                                </div>\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
                                <label for="TOS Range" class="control-label">TOS Range</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <div class="right halfWidth no-important col-xs-12 col-md-12 col-sm-12 col-lg-12 no-padding-left-right from-to-textbox pull-right">\
                                    <input class="max5 max5-range parent-max5 mobile-margin-bottom-20" value="" type="text" /><span>&#x2D;</span>\
                                    <input class="max5 max5-range parent-max5 mobile-margin-bottom-20" value="" type="text" />\
                                </div>\
                            </div>\
                        </div>\
\
\
                        <div class="form-group">\
                            <div class="col-sm-12">\
                                <div class="modal-footer">\
                                    <input class="button button-apply save mob-button-width" value="Save" type="button" />\
                                    <input class="button button-cancel close-password-popup mob-apply-cancel mob-button-width" data-dismiss="modal" value="Cancel" type="button" />\
                                </div>\
                            </div>\
                        </div>\
                    </form>\
                </div>\
            </div>\
        </div>\
    </div>\
\
    <!-- ADD Popup Modal-->\
    <div class="modal fade" id="accessctrl-add-modal" role="dialog">\
        <div class="modal-dialog">\
            <!-- Modal content-->\
            <div class="modal-content change-password-content">\
                <div class="modal-header hidden-sm hidden-md hidden-lg">\
                 <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
                </div>\
                <div class="modal-body no-padding">\
                    <form class="form-horizontal">\
                        <div class="form-group">\
                            <div class="col-sm-12">\
                                <p class="title tL">\
                                    Add Access Control Rule\
                                </p>\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none ">\
                                <label for="Name" class="control-label">Name</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <input type="text" value="">\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
                                <label for="Order" class="control-label">Order</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <input type="text" value="">\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
                                <label for="policy" class="control-label">Policy</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <div id="top-info-mode" class="rel">\
                                    <select>\
                                        <option>Accept</option>\
                                        <option>Deny</option>\
                                    </select>\
                                </div>\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
                                <label for="interface" class="control-label">Interface</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <div id="top-info-mode" class="rel">\
                                    <select>\
                                        <option>LAN</option>\
                                        <option>WAN 1</option>\
                                        <option>WAN 2</option>\
                                    </select>\
                                </div>\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
                                <label for="protocol" class="control-label">Protocol</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <div id="top-info-mode" class="rel">\
                                    <select>\
                                        <option>IPv4</option>\
                                        <option>IPv6</option>\
                                    </select>\
                                </div>\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
                                <label for="Data Direction" class="control-label">Data Direction</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <div id="top-info-mode" class="rel">\
                                    <select>\
                                        <option>Input</option>\
                                        <option>Output</option>\
                                    </select>\
                                </div>\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
                                <label for="protocol" class="control-label">IP Protocol</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <div id="top-info-mode" class="rel">\
                                    <select>\
                                        <option>TCP</option>\
                                        <option>UDP</option>\
                                        <option>Both</option>\
                                    </select>\
                                </div>\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
                                <label for="Source IP" class="control-label">Source IP</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <input type="text" value="">\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
                                <label for="Source Mask" class="control-label">Source Mask</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <input type="text" value="">\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
                                <label for="Source Port Range" class="control-label">Source Port Range</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <div class="right halfWidth no-important col-xs-12 col-md-12 col-sm-12 col-lg-12 no-padding-left-right from-to-textbox pull-right">\
                                    <input class="max5 max5-range parent-max5 mobile-margin-bottom-20" value="" type="text" /><span>&#x2D;</span>\
                                    <input class="max5 max5-range parent-max5 mobile-margin-bottom-20" value="" type="text" />\
                                </div>\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
                                <label for="Destination IP" class="control-label">Destination IP</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <input type="text" value="">\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
                                <label for="Destination Mask" class="control-label">Destination Mask</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <input type="text" value="">\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
                                <label for="Destination Port Range" class="control-label">Destination Port Range</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <div class="right halfWidth no-important col-xs-12 col-md-12 col-sm-12 col-lg-12 no-padding-left-right from-to-textbox pull-right">\
                                    <input class="max5 max5-range parent-max5 mobile-margin-bottom-20" value="" type="text" /><span>&#x2D;</span>\
                                    <input class="max5 max5-range parent-max5 mobile-margin-bottom-20" value="" type="text" />\
                                </div>\
                            </div>\
                        </div>\
                        <div class="form-group padding-top-bottom-20 no-margin">\
                            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
                                <label for="TOS Range" class="control-label">TOS Range</label>\
                            </div>\
                            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
                                <div class="right halfWidth no-important col-xs-12 col-md-12 col-sm-12 col-lg-12 no-padding-left-right from-to-textbox pull-right">\
                                    <input class="max5 max5-range parent-max5 mobile-margin-bottom-20" value="" type="text" /><span>&#x2D;</span>\
                                    <input class="max5 max5-range parent-max5 mobile-margin-bottom-20" value="" type="text" />\
                                </div>\
                            </div>\
                        </div>\
\
                        <div class="form-group">\
                            <div class="col-sm-12">\
                                <div class="modal-footer">\
                                    <input class="button button-apply save mob-button-width" value="Apply" type="button" id="accessctrl-btn-add-row" />\
                                    <input class="button button-cancel close-password-popup mob-apply-cancel mob-button-width" data-dismiss="modal" value="Cancel" type="button" />\
                                </div>\
                            </div>\
                        </div>\
                    </form>\
                </div>\
            </div>\
        </div>\
    </div>\
\
    <script>\
        $(function() {\
            $(document).on(\'click\', \'input.accectrl-btn-delete-row\', function() {\
                $(this).closest(\'tr\').remove();\
                return false;\
            });\
            $(".access-btn-on-off").click(function() {\
                if ($(this).hasClass("button-on")) {\
                    $(this).removeClass("button-on").addClass("button-off");\
                    $(this).closest("tr").children().not(":last-child").addClass("op50");\
                } else {\
                    $(this).removeClass("button-off").addClass("button-on");\
                    $(this).closest("tr").children().not(":last-child").removeClass("op50");\
                }\
            });\
\
            $("#access-btn-add-row").click(function() {\
                $("#accessctrl-add-modal").modal();\
            });\
            $("#accessctrl-btn-add-row").click(function() {\
                var addRow = \'<tr><td>Name Example</td><td>1</td>\' +\
                    \'<td>WAN 1</td>\' +\
                    \'<td>IPv4</td>\' +\
                    \'<td>Output</td>\' +\
                    \'<td><input class="button button-edit mapping accessctrl-edit-viewmodal" value="" type="button" /></td>\' +\
                    \'<td><input class="button button-delete accectrl-btn-delete-row" value="" type="button" /></td>\' +\
                    \'<td><div id="access-btn-on-off" class="button button-on access-btn-on-off"></div></td>\' +\
                    \'</tr>\';\
\
                $("#accesctrl-table-list tbody").append(addRow);\
                $("#accessctrl-add-modal").modal("hide");\
            })\
            $(document).on(\'click\', \'.accessctrl-edit-viewmodal\', function() {\
                $("#accessctrl-edit-modal").modal();\
            });\
\
        });\
    </script>\
'); 