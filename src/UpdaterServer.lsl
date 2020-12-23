//========================================
// UpdaterServer.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 24 November 2020

#include "include/GlobalDefines.lsl"

// This file was originally created by Fred Beckhusen (Ferd Frederix)
// It has been drastically cannibalized, and completely rewritten.
//
// Operation: Click on the server container that includes this script
// along with scripts to be used for updates. After clicking on this
// container, then trigger the update script in the object, which
// sends a command to a listener in this script in order to send all
// internal scripts over.

// :CATEGORY:Updater
// :NAME:Script Updater
// :AUTHOR:Fred Beckhusen (Ferd Frederix)
// :KEYWORDS:Update, updater
// :CREATED:2014-01-30 12:17:30
// :EDITED:2014-02-14 12:33:24
// :ID:1017
// :NUM:1581
// :REV:1.1
// :WORLD:Second Life, OpenSim
// :DESCRIPTION:
// Central prim updater for scripts.  Just drop a (non running) script in here and click the prim.  Scripts are sent to the registered clients
// :CODE:

// Rev 1.1 on 2-13-2014 fixes timeout bugs, adds

//========================================
// VARIABLES
//========================================

// tunables
integer TITLE = TRUE;      // show how many scripts can be updated in hover text
integer UNIQ = 1246;       // the private channel unique to the owner of this prim - MUST MATCH in client and server
integer UPDATE_TIMEOUT = 60;  // timeout in 60 seconds

// globals
integer comChannel ;       // we listen on this channel. It is unioque to this owner and a subchannel
integer comHandle;

integer pin;
key targetID;
key owner;
key touchingID;
integer publicMode = 0;

#define lmSetHovertext(a)  llSetText((a), <1,1,1>, 1)
#define lmClearHovertext() llSetText("", ZERO_VECTOR, 0)
#define RUNNING 1
#define NOT_RUNNING 0

//========================================
// FUNCTIONS
//========================================

sendUpdate() {
    integer numScripts = llGetInventoryNumber(INVENTORY_SCRIPT);        // how many  scripts checked in?
    integer index;
    string name;
    string myName;

    index = numScripts;
    myName = llGetScriptName();

    //llOwnerSay("touchingID = " + (string)touchingID);
    //llOwnerSay(  "targetID = " + (string)  targetID);
    //llOwnerSay("pin = " + (string)pin);

    // scan all scripts in our inventory, could be more than one needs updating.
    while (index--) {

        name = llGetInventoryName(INVENTORY_SCRIPT, index);

        // bypass this script, and the Start script...
        if (name != myName && name != "Start") {

            lmSetHovertext("Updating " + name + "...");
            llRegionSayTo(targetID, PUBLIC_CHANNEL, "Sending script " + name);
            llRemoteLoadScriptPin(targetID, name, pin, NOT_RUNNING, 100);
        }
    }

    // Updating Start, and starting after should reset key cleanly
    lmSetHovertext("Updating Start and Resetting Key...");
    llRemoteLoadScriptPin(targetID, "Start", pin, RUNNING, 100);

    lmSetHovertext("Update complete!");
    llRegionSayTo(targetID, PUBLIC_CHANNEL, "Update complete!");

    llSleep(15.0);
    lmSetHovertext("Click for update");
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
        lmSetHovertext("Click for update");
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------

    on_rez(integer start) {
        owner = llGetOwner();
        lmSetHovertext("Click for update");
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------

    // Listener is only being used to track scripts and UUIDs etc.
    // First step from client is contact via listener.

    listen(integer channel, string name, key id, string msg) {
        list params = llParseString2List(msg, ["^"], []);

        if (owner != touchingID) {
            lmSetHovertext("Update rejected.");
            return;
        }

        lmSetHovertext("Updating...");
        llSay(PUBLIC_CHANNEL,"Beginning update with nearby key...");
        targetID = llList2Key(params, 0);
        pin = llList2Integer(params, 1);

        llListenRemove(comHandle);
        llSetTimerEvent(0.0);

        // targetID is the object UUID
        // owner is the owner of this updater
        // touchingID is the person touching this updater

        sendUpdate();
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------

    timer() {
        llSay(PUBLIC_CHANNEL,"Update has expired...");
        lmClearHovertext();
        llListenRemove(comHandle);
        llSetTimerEvent(0.0);
    }

    // This is for when the user clicks the updater: this should start the process

    //----------------------------------------
    // TOUCH START
    //----------------------------------------

    touch_start(integer what) {

        touchingID = llDetectedKey(0);

        // This prevents anyone but the owner from using this updater
        if (touchingID != owner) {
            llSay(PUBLIC_CHANNEL,"You are not allowed access to this updater.");
            return;
        }

        lmSetHovertext("Awaiting update client...");

        // Create a private listener, and open it
        comChannel = (((integer)("0x" + llGetSubString((string)touchingID, -8, -1)) & 0x3FFFFFFF) ^ 0xBFFFFFFF ) + UNIQ;    // UNIQ is the private channel for this owner
        comHandle = llListen(comChannel,"","","");

        //llRegionSayTo(touchingID, PUBLIC_CHANNEL, "Put non-running scripts into inventory and touch this to send them to remote prims.");
        llSetTimerEvent(UPDATE_TIMEOUT);
    }

    //----------------------------------------
    // CHANGED
    //----------------------------------------
    changed(integer change) {
        if (change & CHANGED_OWNER) {

            llOwnerSay("This is an Updater for the Community Dolls Key: click on this object, then select Update from the Key Menu.\n");

            llSleep(1.0);
            llResetScript(); // start over
        }
    }
}

//========== UPDATERSERVER ==========
