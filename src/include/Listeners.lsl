//========================================
// Listeners.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl

// PURPOSE:
//
// Listener management is way too complex: we need to have
// something conceptually simpler and more reliable.
//
// Offsets should be hidden, and the dialogChannel shouldn't
// be the base for everyone else - and any channels that need
// to be known widely should be passed using link messages.
//
// We have many listeners, nearly all are fully dependent on the dialogChannel
// for their values.
//
// There is a mix of channels, but only the chatChannel and dialogChannel are
// passed about, and the former could be any positive value.
//
// We need functions to:
//   * control dialogChannel: set, activate, stop
//   * control other channels: set (via offset), activate, stop
//
// We should be able to hide all deactivate vs close options in
// these functions
//
// SUMMARY:
//   * Transform: sets a bunch of search channels, and opens type Dialog Channel
//   * Aux: sets textbox channel
//   * Avatar: sets pose Channel
//   * CheckRLV: sets and opens rlv channel
//   * Dress: sets rlvBaseChannel, dress Menu Channels, outfit Channel...
//   * Main: nothing - only sets dialog channel

// These offsets may very well be very soon obsolete
#define BLACKLIST_CHANNEL_OFFSET 666
#define CONTROL_CHANNEL_OFFSET 888
#define POSE_CHANNEL_OFFSET 777
#define TYPE_CHANNEL_OFFSET 778
#define TEXTBOX_CHANNEL_OFFSET 1111

#define MENU_TIMEOUT 60.0
#define MAX_INT DEBUG_CHANNEL

#define cdListenerDeactivate(a) llListenControl(a, 0)
#define cdListenerActivate(a) llListenControl(a, 1)
#define cdPositive(a) ((a) ^ 0x80000000)

//========================================
// VARIABLES
//========================================

integer baseChannel;

// Only for MenuHandler:
integer blacklistChannel;
integer blacklistHandle;
integer controllerChannel;
integer controllerHandle;

// Only for Avatar:
integer poseMenuChannel;
integer poseMenuHandle;

// Have to remove these from CommonGlobals.lsl first,
// modify scripts, then invoke them here...
//
//integer chatChannel         = 75;
//integer dialogChannel;
//integer dialogHandle;

// THIS IS RAW DATA!!
//
// Many of these would not be part of any processing here,
// but others would be. This is a programmatically generated
// list of all (possible) channels in code.
//
// Eventually, they should all be defined here. Some of them are
// already. Note that unused variables are removed by the Firestorm
// optimizer, so we don't have to worry about that.
//
//      2 activeChannel
//      4 blacklistChannel
//     19 chatChannel
//      6 comChannel
//      4 controllerChannel
//     44 dialogChannel
//      8 dressMenuChannel
//      6 dressRandomChannel
//      4 keySpecificChannel
//      2 listChannel
//     11 outfitChannel
//      4 outfitSearchChannel
//      5 poseMenuChannel
//      8 rlvChannel
//      1 statusChannel
//      4 systemSearchChannel
//      4 textboxChannel
//      5 typeDialogChannel
//      4 typeFolderBufferChannel
//      5 typeSearchChannel
//
// Channels (presumably) by file - again this was originally
// programmatically generated:
//
// Aux.lsl: dialogChannel
// Aux.lsl: textboxChannel
//
// Avatar.lsl: poseMenuChannel
//
// ChatHandler.lsl: chatChannel
//
// CheckRLV.lsl: chatChannel
// CheckRLV.lsl: rlvChannel
//
// Dress.lsl: dialogChannel
// Dress.lsl: dressMenuChannel
// Dress.lsl: dressRandomChannel
// Dress.lsl: outfitChannel
//
// KeySpecific-Filigree.lsl: keySpecificChannel
//
// KeySpecific-Soen.lsl: chatChannel
//
// Main.lsl: dialogChannel
//
// MenuHandler.lsl: activeChannel
// MenuHandler.lsl: blacklistChannel
// MenuHandler.lsl: chatChannel
// MenuHandler.lsl: controllerChannel
// MenuHandler.lsl: dialogChannel
// MenuHandler.lsl: listChannel
//
// Start.lsl: chatChannel
//
// StatusRLV.lsl: statusChannel
//
// Transform.lsl: dialogChannel
// Transform.lsl: outfitSearchChannel
// Transform.lsl: systemSearchChannel
// Transform.lsl: typeDialogChannel
// Transform.lsl: typeFolderBufferChannel
// Transform.lsl: typeSearchChannel
//
// UpdaterClient.lsl: comChannel
//
// UpdaterServer.lsl: comChannel

//========================================
// FUNCTIONS
//========================================

//----------------------------------------
// GET CHANNEL NUMBERS
//
integer listenerGetDialogChannel() {

    dialogChannel = (0x80000000 | (integer)("0x" + llGetSubString((string)llGenerateKey(), -7, -1)));
    lmSendConfig("dialogChannel", (string)(dialogChannel));
    return dialogChannel;
}

integer listenerGetChannel() {
    integer returnChannel;

    if (baseChannel == 0)
        baseChannel = MAX_INT - (integer)llFrand(5000);

    returnChannel = baseChannel;

    // When we assign a new channel number - let everyone else know we've done it
    lmSendConfig("baseChannel", (string)(++baseChannel));

    return returnChannel;
}

//----------------------------------------
// OPEN CHANNELS
//
#define ALL_USERS ""
#define DOLL_ONLY dollID
#define MINE_ONLY dollID

#define NO_HANDLE 0

#define cdListenAll(a)    listenerOpenChannel(a,NO_HANDLE,ALL_USERS)
#define cdListenUser(a,b) listenerOpenChannel(a,NO_HANDLE,b)
#define cdListenMine(a)   listenerOpenChannel(a,NO_HANDLE,dollID)

#define listenerOpen(a,b) listenerOpenChannel(a,b,ALL_USERS)

integer listenerOpenChannel(integer listenerChannel, integer listenerHandle, string listenerFilter){

    // Remove any set channel
    if (listenerHandle) llListenRemove(listenerHandle);

    // Set channel and return handle
    //
    listenerHandle = llListen(listenerChannel, NO_FILTER, listenerFilter, NO_FILTER);

    llSetTimerEvent(MENU_TIMEOUT);

    return listenerHandle;
}

//----------------------------------------
// STOP CHANNELS
//
listenerStopChannel(integer listenerHandle) {
    llListenRemove(listenerHandle);
}

listenerClose(integer listenerHandle) {
    llListenRemove(listenerHandle);
}

//----------------------------------------
// CHANNEL TIMEOUTS
//
integer listenerTimeout(integer listenerHandle) {
    if (listenerHandle) {
        llListenRemove(listenerHandle);
        debugSay(4,"DEBUG-LISTENERS","Timer expired: listener removed");
        listenerHandle = 0;
    }

    return listenerHandle;
}

//----------------------------------------
// ACTIVATE CHANNELS
//
integer listenerActivateChannel(integer listenerChannel, integer listenerHandle){

    if (listenerHandle) {

        // Uses llListenControl(a, 1)
        cdListenerActivate(listenerHandle);
    }
    else {
        // Uses llListen(a, NO_FILTER, NO_FILTER, NO_FILTER)
        listenerHandle = cdListenAll(listenerChannel);
    }

    lmSendConfig("dialogChannel", (string)(dialogChannel));
    return listenerHandle;
}

// This function ONLY activates the dialogChannel - no
// reset is done unless necessary

integer listenerActivateDialogChannel() {

    dialogHandle = listenerActivateChannel(dialogChannel,dialogHandle);

    return dialogChannel;
}

//----------------------------------------
// DEACTIVATE CHANNELS
//
listenerDeactivateChannel(integer listenerHandle) {
    if (listenerHandle) cdListenerDectivate(listenerHandle);
    else llSay(DEBUG_CHANNEL,"No listener handle to deactivate with!");
}

//----------------------------------------
// REPLACEMENT FUNCTIONS
//
// As used in MenuHandler.lsl

// This is a chooseDialogChannel replacement: its purpose is to
// set all channel values
//
// Here, it sets values for:
//   * dialogChannel
//   * poseMenuChannel
//   * blacklistChannel
//   * controllerChannel

listenerGetAllChannels() {

    // We want this to be able to be called repeatedly...
    if (!dialogChannel) dialogChannel = listenerGetDialogChannel();
    lmSendConfig("dialogChannel", (string)(dialogChannel));

    if (!blacklistChannel)   blacklistChannel = listenerGetChannel();
    if (!controllerChannel) controllerChannel = listenerGetChannel();
}

listenerOpenAllChannels() {

        dialogHandle = listenerOpenChannel(    dialogChannel,     dialogHandle);
//    poseMenuHandle = listenerOpenChannel(  poseMenuChannel,   poseMenuHandle);
//  typeDialogHandle = listenerOpenChannel(typeDialogChannel, typeDialogHandle);
//   blacklistHandle = listenerOpenChannel( blacklistChannel,  blacklistHandle);
//  controllerHandle = listenerOpenChannel(controllerChannel, controllerHandle);

    lmSendConfig("dialogChannel", (string)(dialogChannel));
}

