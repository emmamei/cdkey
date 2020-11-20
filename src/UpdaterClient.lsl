//========================================
// UpdaterClient.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: Thu 19 Nov 2020 02:09:04 AM CST

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

//========================================
// VARIABLES
//========================================

integer UNIQ = 1246;       // the private channel unique to the owner of this prim

// Not tuneable
integer UPDATE_TIMEOUT = 60;   // 60 seconds for reception to succeed
integer comChannel;            // placeholder for llRegionSay
integer pin;             // a random pin for security

//========================================
// FUNCTIONS
//========================================

startUpdate() {
    llRegionSay(comChannel, (string)llGetOwner() + "^" + (string)pin);
    llOwnerSay("Update client prepared to receive updated files...");
    llSetTimerEvent(UPDATE_TIMEOUT);
}

//========================================
// STATES
//========================================

default {

    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------

    state_entry() {

        pin = llCeil(llFrand(123456) + 654321);

        comChannel = (((integer)("0x" + llGetSubString((string)llGetOwner(), -8, -1)) & 0x3FFFFFFF) ^ 0xBFFFFFFF ) + UNIQ;    // 1234 is the private channel for this owner

        // This is the key to the whole operation
        llSetRemoteScriptAccessPin(pin);

        startUpdate();
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------

    // in case we rez, our UUID changed, so we check in
    on_rez(integer p) {
        llResetScript();
    }
}

//========== UPDATERCLIENT ==========
