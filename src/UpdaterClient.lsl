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

//========================================
// VARIABLES
//========================================

integer UNIQ = 1246;       // the private channel unique to the owner of this prim

// Not tuneable
integer UPDATE_TIMEOUT = 60;   // 60 seconds for reception to succeed
integer comChannel;            // placeholder for llRegionSay
integer controlChannel;
integer controlHandle;
integer pin;             // a random pin for security
integer update;
key owner;

//========================================
// FUNCTIONS
//========================================

startUpdate() {
    // All we do is create a key for the gate, then give a copy to the
    // updater via the comChannel
    pin = llCeil(llFrand(123456) + 654321);

    comChannel = (((integer)("0x" + llGetSubString((string)owner, -8, -1)) & 0x3FFFFFFF) ^ 0xBFFFFFFF ) + UNIQ;    // 1234 is the private channel for this owner
    llOwnerSay("client = " + (string)owner);
    llOwnerSay("client pin = " + (string)pin);

    // This is the key to the whole operation
    llSetRemoteScriptAccessPin(pin);

    // Trigger the update
    llRegionSay(comChannel, (string)llGetLinkKey(LINK_THIS) + "^" + (string)pin);

    llOwnerSay("Update client prepared to receive updated files...");
    llSetTimerEvent(UPDATE_TIMEOUT);
    update = 0;
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

        controlChannel = -1575318;
        controlHandle = llListen(controlChannel,"","","");

        llOwnerSay("Updater ready.");
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------

    // in case we rez, our UUID changed, so we check in
    on_rez(integer p) {
        llResetScript();
    }


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

            //string value = llList2String(split, 1);
            //string c = cdGetFirstChar(name); // for speedup
            //split = llDeleteSubList(split,0,0);

            if (name == "update") {
                update = 1;
                startUpdate();
            }
        }
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------

    // in case we rez, our UUID changed, so we check in
    timer() {
        integer index = llGetInventoryNumber(INVENTORY_SCRIPT);
        integer found = 0;

        // scan all scripts in our inventory, could be more than one needs updating.
        while (index--) {
            if (llGetInventoryName(INVENTORY_SCRIPT, index) == "New") {
                llRemoveInventory("New"); // This script only serves as a flag
                found = 1;
            }
        }

        if (found == 0) {
            llSay(PUBLIC_CHANNEL,"Update failed.");
        }

        llSetTimerEvent(0.0);
        //llSetScriptState(llGetScriptName(),NOT_RUNNING);
        //llSleep(1.0);
    }
}

//========== UPDATERCLIENT ==========
