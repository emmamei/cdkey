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

#define RUNNING 1
#define NOT_RUNNING 0
#define lmLocalSay(a) llSay(PUBLIC_CHANNEL,(a))
#define cdResetKey() llResetOtherScript("Start")

//========================================
// VARIABLES
//========================================

integer UNIQ = 1246;       // the private channel unique to the owner of this prim

// Not tuneable
#define UPDATE_TIMEOUT 30
#define BEGIN_TIMEOUT 10
integer comChannel;
integer comHandle;
integer pin;             // a random pin for security
integer update;
integer waiting;
integer waitingRetries = 5;
integer scriptCount;
integer scriptIndex;
key owner;

//========================================
// FUNCTIONS
//========================================

startUpdate() {
    // All we do is create a key for the gate, then give a copy to the
    // updater via the comChannel
    pin = llCeil(llFrand(123456) + 654321);

    comChannel = (((integer)("0x" + llGetSubString((string)owner, -8, -1)) & 0x3FFFFFFF) ^ 0xBFFFFFFF ) + UNIQ;    // 1234 is the private channel for this owner
#ifdef LISTENER
    comHandle = llListen(comChannel,"","","");
#endif
    //llOwnerSay("client = " + (string)owner);
    //llOwnerSay("client pin = " + (string)pin);

    // This is the key to the whole operation
    llSetRemoteScriptAccessPin(pin);

    // Trigger the update
    waiting = TRUE;
    llSetTimerEvent(BEGIN_TIMEOUT);
    llRegionSay(comChannel, (string)llGetLinkKey(LINK_THIS) + "^" + (string)pin);

    llOwnerSay("Key ready for update...");
    update = 0;
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
        update = 0;
        scriptCount = llGetInventoryNumber(INVENTORY_SCRIPT);
        scriptIndex = scriptCount; // Update should add one new file (New.lsl)
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
        script            =     cdListElement(split, 0);
        remoteSeq         =     (i & 0xFFFF0000) >> 16;
        optHeader         =     (i & 0x00000C00) >> 10;
        code              =      i & 0x000003FF;
        split             =     llDeleteSubList(split, 0, 0 + optHeader);

        scaleMem();

        string name = llList2String(split, 0);

        debugSay(2,"DEBUG-UPDATER","Received link message code " + (string)code + " command: " + name);
        if (update == 1) return;

        if (code == CONFIG) {

            string value = llList2String(split, 1);
            //split = llDeleteSubList(split,0,0);

            if (name == "update") {
                update = 1;
		doHalt();
                startUpdate();
            }
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel") debugLevel = (integer)value;
#endif
        }
    }

    //----------------------------------------
    // CHANGED
    //----------------------------------------
    changed(integer change) {
        if (change & CHANGED_INVENTORY) {
            llSetTimerEvent(UPDATE_TIMEOUT);
            if (waiting) {
                llSay(PUBLIC_CHANNEL, "Key update in progress...");
                waiting = 0;
            }
            //debugSay(4,"DEBUG-UPDATER","Inventory changed: script #" + (string)(scriptCount - scriptIndex + 1) + " of " + (string)scriptCount);
            llOwnerSay("Received script #" + (string)(scriptCount - scriptIndex + 1) + " of " + (string)scriptCount);
            scriptIndex--;
            if (scriptIndex == 0) llSay(PUBLIC_CHANNEL, "Key update complete.");
        }
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------

    // in case we rez, our UUID changed, so we check in
    timer() {

        if (waiting) {
	    if (waitingRetries > 0) {
		debugSay(2,"DEBUG-UPDATER","Update retry: remaining retries: " + (string)waitingRetries);
		waitingRetries--;
		llSetTimerEvent(BEGIN_TIMEOUT);
		llRegionSay(comChannel, (string)llGetLinkKey(LINK_THIS) + "^" + (string)pin);
	    }
	    else {
		llSay(DEBUG_CHANNEL,"Updater failed to respond. Restarting key.");
		llSetScriptState("Start", RUNNING);
		cdResetKey(); // Key state is may or may not be ok, and scripts are at full-stop...
            }
        }
	else {

            debugSay(4,"DEBUG-UPDATER","Inventory script index on timeout: " + (string)scriptIndex);

	    integer index = llGetInventoryNumber(INVENTORY_SCRIPT);
	    integer found = 0;

	    llSetTimerEvent(0.0);

	    // scan all scripts in our inventory, could be more than one needs updating.
	    while (index--) {
		if (llGetInventoryName(INVENTORY_SCRIPT, index) == "New") {
		    found = 1;
		}
	    }

	    // If we find the script, we don't need to say anything:
	    // the updater server and key reset will handle the last bit.
	    if (found == 0) {
		llSay(DEBUG_CHANNEL,"Update failed. Restarting key.");
		llSetScriptState("Start", RUNNING);
		cdResetKey(); // Key state is indeterminate, and scripts are at full-stop...
	    }
	}
    }
}

//========== UPDATERCLIENT ==========
