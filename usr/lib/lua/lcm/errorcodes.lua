--[[
/********** COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE *************
** Copyright (c) 2017 -          Technicolor Delivery Technologies, SAS **
** - All Rights Reserved                                                **
** Technicolor hereby informs you that certain portions                 **
** of this software module and/or Work are owned by Technicolor         **
** and/or its software providers.                                       **
** Distribution copying and modification of all such work are reserved  **
** to Technicolor and/or its affiliates, and are not permitted without  **
** express written authorization from Technicolor.                      **
** Technicolor is registered trademark and trade name of Technicolor,   **
** and shall not be used in any manner without express written          **
** authorization from Technicolor                                       **
*************************************************************************/
--]]

return {
  INVALID_ARGUMENT = 1,
  DOWNLOAD_FAILED  = 2,
  INSTALL_FAILED   = 3,
  WRONG_STATE      = 4,
  START_FAILED     = 5,
  STOP_FAILED      = 6,
  UNINSTALL_FAILED = 7,
  DUPLICATE_PKG    = 8,
  INTERNAL_ERROR   = 99
}

-- TODO: create corresponding C header to avoid users of lcmd creating
-- their own version that has to be kept in sync. Possibly we also
-- include error strings.
