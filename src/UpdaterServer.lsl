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

#define UPDATE_TIMEOUT 60
#define START_PARAMETER 100

// globals
integer comChannel ;       // we listen on this channel. It is unique to this owner and a subchannel
integer comHandle;

integer pin;
key targetID;
key owner;
key toucherID;
integer publicMode = 0;

#define setHovertext(a)  llSetText((a), <1,1,1>, 1)
#define clearHovertext() llSetText("", ZERO_VECTOR, 0)
#define RUNNING 1
#define NOT_RUNNING 0

//========================================
// FUNCTIONS
//========================================

sendUpdate() {
    integer numScripts = llGetInventoryNumber(INVENTORY_SCRIPT);        // how many  scripts checked in?
    integer index;
    string name;

    index = numScripts;

    // scan all scripts in our inventory, could be more than one needs updating.
    while (index--) {

        name = llGetInventoryName(INVENTORY_SCRIPT, index);

        // bypass this script, and the Start script...
        if (name != myName && name != "Start" && name != "UpdaterClient") {

            setHovertext("Updating script: " + name + "...");
            llRegionSayTo(targetID, PUBLIC_CHANNEL, "Sending script " + name);
            llRemoteLoadScriptPin(targetID, name, pin, NOT_RUNNING, START_PARAMETER);
        }
    }

    // Updating UpdaterClient
    setHovertext("Updating script: UpdaterClient");
    llRemoteLoadScriptPin(targetID, "UpdaterClient", pin, NOT_RUNNING, START_PARAMETER);

    // Updating Start, and starting after should reset key cleanly
    setHovertext("Updating script: Start (and Resetting Key)");
    llRemoteLoadScriptPin(targetID, "Start", pin, RUNNING, START_PARAMETER);

    setHovertext("Update complete!");
    llRegionSayTo(targetID, PUBLIC_CHANNEL, "Update complete!");

    llSleep(15.0);
    setHovertext("Click for update");
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
        myName = llGetScriptName();
        setHovertext("Click for update");
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------

    on_rez(integer start) {
        owner = llGetOwner();
        setHovertext("Click for update");

        llSay(PUBLIC_CHANNEL,"This is an Updater for the Community Dolls Key: click on this object, then select Update from the Key Menu.\n");
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------

    // Listener is only being used to track scripts and UUIDs etc.
    // First step from client is contact via listener.

    listen(integer channel, string name, key id, string msg) {
        list params = llParseString2List(msg, ["^"], []);

        // guaranteed to be on comChannel...
        if (owner != toucherID) return;

        setHovertext("Updating...");
        llSay(PUBLIC_CHANNEL,"Beginning update with nearby key...");
        targetID = (key)params[0];
        pin = (integer)params[1];

        llListenRemove(comHandle);
        llSetTimerEvent(0.0);

        // targetID is the object UUID
        // owner is the owner of this updater
        // toucherID is the person touching this updater

        sendUpdate();
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------

    timer() {
        llSay(PUBLIC_CHANNEL,"Update has expired...");
        llListenRemove(comHandle);
        llSetTimerEvent(0.0);
        setHovertext("Click for update");
    }

    // This is for when the user clicks the updater: this should start the process

    //----------------------------------------
    // TOUCH START
    //----------------------------------------

    touch_start(integer what) {

        toucherID = llDetectedKey(0);

        // This prevents anyone but the owner from using this updater
        if (toucherID != owner) {
            llSay(PUBLIC_CHANNEL,"You are not allowed access to this updater.");
            return;
        }

        setHovertext("Awaiting update client...");
        llSay(PUBLIC_CHANNEL,"Ready to begin update...");
        llOwnerSay("*** KEY WILL RESET AFTER UPDATE ***");

        // Create a private listener, and open it
        comChannel = generateRandomComChannel();
        comHandle = llListen(comChannel,"","","");

        llSetTimerEvent(UPDATE_TIMEOUT);
    }

    //----------------------------------------
    // CHANGED
    //----------------------------------------
    changed(integer change) {
        if (change & CHANGED_OWNER) {
            llResetScript(); // start over
        }
    }
}

//========== UPDATERSERVER ==========
