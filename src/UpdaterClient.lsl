//========================================
// UpdaterClient.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 24 November 2020

#include "include/GlobalDefines.lsl"

// This file was originally created by Fred Beckhusen (Ferd Frederix)
// It has been drastically cannibalized, and completely rewritten.
//
// Operation: Click on the server container that includes the server script
// along with scripts to be used for updates. After clicking on that
// container, trigger this update script contained in the object, which
// sends a command to a listener in the server in order to send all
// internal scripts over.

// :CATEGORY:Updater
// :NAME:Script Updater
// :AUTHOR:Fred Beckhusen (Ferd Frederix)
// :KEYWORDS:Update, updater
// :CREATED:2014-01-30 12:16:43
// :EDITED:2014-02-14 12:33:24
// :ID:1017
// :NUM:1578
// :REV:1.0
// :WORLD:Second Life, OpenSim
// :DESCRIPTION:
// Remote prim updater for scripts.  This registers the prim to accept scripts from a server in the same region.
// :CODE:

#define cdLocalSay(a) llSay(PUBLIC_CHANNEL,(a))
#define cdKeyInfo(a) ((string)(llGetLinkKey(LINK_THIS)) + "^" + ((string)(a)))
#define cdResetKey() llResetOtherScript("Start")

//========================================
// VARIABLES
//========================================

// Not tuneable
#define UPDATE_TIMEOUT 30
#define BEGIN_TIMEOUT 10
#define MAX_RETRIES 5
integer comChannel;
integer comHandle;
integer pin;             // a random pin for security
integer updating;
integer comWaitingForResponse;
integer comRetries = MAX_RETRIES;
#ifdef DEVELOPER_MODE
integer scriptCount;
integer scriptIndex;
#endif
key owner;

//========================================
// FUNCTIONS
//========================================

startUpdate() {
    // All we do is create a key for the gate, then give a copy to the
    // updater via the comChannel
    pin = generateRandomPin();

    comChannel = generateRandomComChannel();
#ifdef LISTENER
    comHandle = llListen(comChannel,"","","");
#endif
    // This is the key to the whole operation
    llSetRemoteScriptAccessPin(pin);

    // Trigger the update
    comWaitingForResponse = TRUE;
    llSetTimerEvent(BEGIN_TIMEOUT);

    // This is the command that lets the Updater know the pin, which begins the update
    llRegionSay(comChannel, cdKeyInfo(pin));

    //llOwnerSay("Key ready for update...");
}

doHalt() {
    integer n;
    string script;

    // Set all other scripts to stop
    n = llGetInventoryNumber(INVENTORY_SCRIPT);
    while(n--) {

        script = llGetInventoryName(INVENTORY_SCRIPT, n);
        if (script != "UpdaterClient") {

            llSetScriptState(script, NOT_RUNNING);
        }
    }
    llSleep(1.0); // Make sure all scripts have time to stop
}

//========================================
// STATES
//========================================

default {

    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------

    state_entry() {
        owner = llGetOwner();
        updating = 0;
#ifdef DEVELOPER_MODE
        scriptCount = llGetInventoryNumber(INVENTORY_SCRIPT) - 1; // Two scripts are uncounted
        scriptIndex = scriptCount; // Update should add one new file (New.lsl)
#endif
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------

    // in case we rez, our UUID changed, so we check in
    on_rez(integer p) {
        llResetScript();
    }

#ifdef LISTENER
    //----------------------------------------
    // LISTEN
    //----------------------------------------

    listen(integer channel, string name, key id, string msg) {
        // get update complete message
    }
#endif

    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    link_message(integer source, integer i, string data, key id) {

        // Parse link message header information
        split             =     cdSplitArgs(data);
        script            =     (string)split[0];
        remoteSeq         =     (i & 0xFFFF0000) >> 16;
        optHeader         =     (i & 0x00000C00) >> 10;
        code              =      i & 0x000003FF;
        split             =     llDeleteSubList(split, 0, 0 + optHeader);

        string name = (string)split[0];
        string value = (string)split[1];

#ifdef DEVELOPER_MODE
        string mode;

             if (code == 15)  mode = "SEND_TO_CONTROLLER";
        else if (code == 101) mode = "INIT_STAGE1";
        else if (code == 102) mode = "INIT_STAGE2";
        else if (code == 104) mode = "INIT_STAGE3";
        else if (code == 105) mode = "INIT_STAGE4";
        else if (code == 110) mode = "INIT_STAGE5";
        else if (code == 135) mode = "MEM_REPORT";
        else if (code == 136) mode = "MEM_REPLY";
        else if (code == 142) mode = "CONFIG_REPORT";
        else if (code == 150) mode = "SIM_RATING_CHG";
        else if (code == 300) mode = "SEND_CONFIG";
        else if (code == 301) mode = "SET_CONFIG";
        else if (code == 305) mode = "INTERNAL_CMD";
        else if (code == 315) mode = "RLV_CMD";
        else if (code == 350) mode = "RLV_RESET";
        else if (code == 500) mode = "MENU_SELECTION";
        else if (code == 502) mode = "POSE_SELECTION";
        else if (code == 503) mode = "TYPE_SELECTION";
        else                  mode = (string)code;

        if (mode != "") { debugSay(8,"DEBUG-LINKMONITOR","Link message #" + mode + " cmd: " + name + " [" + script + "] = " + value); }
#endif

        if (code == SEND_CONFIG) {

            if (name == "update") {
                if (updating == 1) return;

                updating = 1;
                doHalt();
                startUpdate();
            }
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel") debugLevel = (integer)value;
#endif
        }
        else if (code == CONFIG_REPORT) {
            cdConfigureReport();
        }
    }

    //----------------------------------------
    // CHANGED
    //----------------------------------------
    changed(integer change) {
        if (change & CHANGED_INVENTORY) {
            // This triggers each time the Updater updates a file
            if (updating == 0) return; // Inventory changed, but we're not updating now...

            llSetTimerEvent(UPDATE_TIMEOUT);
            if (comWaitingForResponse) {
                llSay(PUBLIC_CHANNEL, "Key update in progress...");
                comWaitingForResponse = 0;
            }

#ifdef DEVELOPER_MODE
            // If we include this for users, would have to note that 2 scripts would not be
            // counted: this script is updated (and stopped) plus Start.lsl. Don't bother
            // the users with innards.
            debugSay(2,"DEBUG-UPDATER","Received script #" + (string)(scriptCount - scriptIndex + 1) + " of " + (string)scriptCount);

            scriptIndex--;

            // This never happens, as this script gets updated (and stopped) before this comes true
            if (scriptIndex == 0) llSay(PUBLIC_CHANNEL, "Key update complete.");
#endif
        }
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------

    // in case we rez, our UUID changed, so we check in
    timer() {

        if (comWaitingForResponse) {

            // Waiting for a response from the Key Updater

            if (comRetries > 0) {
                // Note this is a count DOWN... so comRetries starts with MAX_RETRIES
                if (comRetries == MAX_RETRIES) llSay(PUBLIC_CHANNEL, "Click the updater to begin update...");

                debugSay(2,"DEBUG-UPDATER","Update retry: remaining retries: " + (string)comRetries);

                comRetries--;

                llSetTimerEvent(BEGIN_TIMEOUT);
                llRegionSay(comChannel, cdKeyInfo(pin));
            }
            else {
                llOwnerSay("Updater failed to respond. Restarting key.");
                llSetScriptState("Start", RUNNING);
                cdResetKey(); // Key state is may or may not be ok, and scripts are at full-stop...
            }
        }
        else {
            // Timer expired during an update

#ifdef DEVELOPER_MODE
            debugSay(4,"DEBUG-UPDATER","Inventory script index on timeout: " + (string)scriptIndex);
#endif

            llSetTimerEvent(0.0);
            llOwnerSay("Update stopped unexpectedly.");
            cdResetKey();
        }
    }
}

//========== UPDATERCLIENT ==========
