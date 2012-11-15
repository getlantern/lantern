package org.lantern.state;

/**
 * The state for the modal dialog.
 */
public enum Modal {

    settingsUnlock, 
    settingsLoadFailure, 
    welcome, 
    authorize, 
    gtalkUnreachable, 
    notInvited, 
    requestInvite, 
    requestSent, 
    firstInviteReceived, 
    proxiedSites, 
    systemProxy, 
    inviteFriends, 
    finished, 
    settings, 
    giveMode, 
    about, 
    updateAvailable
}
