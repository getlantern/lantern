package org.lantern.state;

import org.lantern.annotation.Keep;

/**
 * The state for the modal dialog.
 */
@Keep
public enum Modal {


    settingsLoadFailure,
    welcome,
    authorize,
    connecting,
    authorizeLater,
    notInvited,
    requestInvite,
    requestSent,
    firstInviteReceived,
    proxiedSites,
    systemProxy,
    lanternFriends,
    finished,
    contact,
    settings,
    confirmReset,
    giveModeForbidden,
    about,
    updateAvailable,
    scenarios,
    none

}
