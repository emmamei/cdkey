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
// CheckRLV at one point uses this command:
//
//     rlvChannel = MAX_INT - (integer)llFrand(5000);
//
// Transform.lsl:
//              rlvChannel = ~dialogChannel + 1;
//
//              typeDialogChannel = dialogChannel - TYPE_CHANNEL_OFFSET;
//              llListen(typeDialogChannel, NO_FILTER, dollID, NO_FILTER);
//
//              typeSearchChannel = rlvChannel + 1;
//              outfitSearchChannel = rlvChannel + 2;
//              systemSearchChannel = rlvChannel + 3;
//
//              typeFolderBufferChannel = rlvChannel + 4;
// Aux.lsl:
//              textboxChannel = dialogChannel - TEXTBOX_CHANNEL_OFFSET;
// Avatar.lsl
//              poseChannel = dialogChannel - POSE_CHANNEL_OFFSET;
// CheckRLV.lsl
//              llListenRemove(rlvHandle);
//
//              // Calculate positive (RLV compatible) rlvChannel
//              rlvChannel = ~dialogChannel + 1;
//              rlvHandle = cdListenMine(rlvChannel);
//              cdListenerActivate(rlvHandle);
// Dress.lsl
// #ifdef RLV_BASE_CHANNEL
//              rlvBaseChannel = dialogChannel ^ 0x80000000; // Xor with the sign bit forcing the positive channel needed by RLV spec.
// #endif
//              dressMenuChannel = (dialogChannel ^ 0x80000000) + 2666; // Xor with the sign bit forcing the positive channel needed by RLV spec.
//              dressRandomChannel = dressMenuChannel + 1;
//              outfitChannel = dialogChannel + 15; // arbitrary offset
//              debugSay(6, "DEBUG-DRESS", "outfits Channel set to " + (string)outfitChannel);
// Main.lsl:
//              (none)
//
// SUMMARY:
//   * Transform: sets a bunch of search channels, and opens type Dialog Channel
//   * Aux: sets textbox channel
//   * Avatar: sets pose Channel
//   * CheckRLV: sets and opens rlv channel
//   * Dress: sets rlvBaseChannel, dress Menu Channels, outfit Channel...
//   * Main: nothing - only sets dialog channel

// These offsets will be very soon obsolete
#define BLACKLIST_CHANNEL_OFFSET 666
#define CONTROL_CHANNEL_OFFSET 888
#define POSE_CHANNEL_OFFSET 777
#define TYPE_CHANNEL_OFFSET 778
#define TEXTBOX_CHANNEL_OFFSET 1111

#define MAX_INT DEBUG_CHANNEL

#define cdListenAll(a)    llListen(a, NO_FILTER, NO_FILTER, NO_FILTER)
#define cdListenUser(a,b) llListen(a, NO_FILTER,         b, NO_FILTER)
#define cdListenMine(a)   llListen(a, NO_FILTER,    dollID, NO_FILTER)
#define cdListenerDeactivate(a) llListenControl(a, 0)
#define cdListenerActivate(a) llListenControl(a, 1)

//========================================
// VARIABLES
//========================================

integer baseChannel;

// Have to remove these from CommonGlobals.lsl first,
// modify scripts, then invoke them here...
//
//integer chatChannel         = 75;
//integer dialogChannel;
//integer dialogHandle;

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
    if (baseChannel == 0)
        baseChannel = MAX_INT - (integer)llFrand(5000);

    return baseChannel++;
}

//----------------------------------------
// ACTIVATE CHANNELS
//
integer listenerSetChannel(integer listenerChannel, integer listenerHandle){

    // Remove any set channel
    if (listenerHandle)
        llListenRemove(listenerHandle);

    // Set channel and return handle
    //
    // Uses llListen(a, NO_FILTER, NO_FILTER, NO_FILTER)
    listenerHandle = cdListenAll(listenerChannel);

    return listenerHandle;
}

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
    //debugSay(4,"DEBUG-MENU","doDialogChannel() called");
    //debugSay(4,"DEBUG-MENU","dialogChannel = " + (string)dialogChannel);

    dialogHandle = listenerActivateChannel(dialogChannel,dialogHandle);

    return dialogChannel;
}

//----------------------------------------
// STOP CHANNELS
//
listenerStopChannel(integer listenerHandle) {
    llListenRemove(listenerHandle);
}

//----------------------------------------
// DEACTIVATE CHANNELS
//
listenerDeactivateChannel(integer listenerHandle) {
    if (listenerHandle) cdListenerDectivate(listenerHandle);
    else llSay(DEBUG_CHANNEL,"No listener handle to deactivate with!");
}

//----------------------------------------
// ORIGINAL FUNCTIONS
//
// As used in MenuHandler.lsl

// The doDialogChannel actually opens the dialog channel

doDialogChannel() {
    listenerActivateDialogChannel();
}

// The chooseDialogChannel only sets the values for all of the
// channels used in MenuHandler

chooseDialogChannel() {
    debugSay(4,"DEBUG-MENU","chooseDialogChannel() called");

    dialogChannel = listenerGetDialogChannel();

    poseChannel = listenerGetChannel();
    //typeDialogChannel = listenerGetChannel();

    // NOTE: blacklistChannel and controllerChannel are not opened here
    blacklistChannel = listenerGetChannel();
      controllerChannel = listenerGetChannel();
}

// This is a chooseDialogChannel replacement: its purpose is to
// set all channel values
//
// Here, it sets values for:
//   * dialogChannel
//   * poseChannel
//   * blacklistChannel
//   * controllerChannel

listenerGetAllChannels() {

    dialogChannel = listenerGetDialogChannel();

    poseChannel = listenerGetChannel();
    //typeDialogChannel = listenerGetChannel();

    // NOTE: blacklistChannel and controllerChannel are not opened here
    blacklistChannel = listenerGetChannel();
      controllerChannel = listenerGetChannel();
}

