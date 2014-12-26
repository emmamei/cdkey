//========================================
// StatusRLV.lsl
//========================================
//
// vim:sw=4 et nowrap:
//
// DATE: 18 December 2014

#include "include/GlobalDefines.lsl"
//
// As of 23 January 2014 this script is now state tracking only
// core RLV command generators are now part of the Avatar script
// thus we keep this script lightweight with plenty of heap room
// for it's runtime data needs.
//
// Why is this so complex? Because......
//
// Because if a script sends a restriction, we want to have that
// restriction remain, even if another script tries to clear it.
// For each restriction, the scripts that triggered it will be tracked
// and each reset checked.
//
// This is useful for when unknown scripts are setting and clearing
// restrictions. If we assume that the scripts are known... then
// things are simpler.

#define CHATMSG_MAXLEN 896
#define SCRIPT_MAXMEM 65536

// rlvStatus is a list with stride 2:
//
//  1: RLV restriction
//  2: String CSV containing scripts using restriction
//
list rlvStatus;
list rlvRestrict;

string scriptName;
integer statusChannel = 55117;
integer statusHandle;

//========================================
// STATES
//========================================
default {

    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------
    state_entry() {
        //dollID = llGetOwner();
        //scriptName = llGetScriptName();

        cdInitializeSeq();
        scaleMem();
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer start) {
        cdInitializeSeq();
        scaleMem();
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    listen(integer channel, string name, key id, string data) {

        if (channel == statusChannel) {
            rlvRestrict = llParseString2List(data, [ "/" ], []);
        }
    }

    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    link_message(integer sender, integer i, string data, key id) {

        // Parse link message header information
        split             =     cdSplitArgs(data);
        script            =     cdListElement(split, 0);
        remoteSeq         =     (i & 0xFFFF0000) >> 16;
        optHeader         =     (i & 0x00000C00) >> 10;
        code              =      i & 0x000003FF;
        split             =     llDeleteSubList(split, 0, 0 + optHeader);

        scaleMem();

        if (code == CONFIG) {

#ifdef DEVELOPER_MODE
            string name = cdListElement(split, 0);
            string value = cdListElement(split, 1);

                 if (name == "debugLevel") debugLevel = (integer)cdListElement(split, 1);
#endif
            return;
        }

        else if (code == INTERNAL_CMD) {
            string cmd = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);

            if (cmd == "refreshRLV") {
                llOwnerSay("Reactivating RLV restrictions");

                i = llGetListLength(rlvRestrict);
                while (i--) {
                    string cmd = llList2String(rlvRestrict, i);
                    debugSay(4,"DEBUG-STATUSRLV","rlvCommand (refresh): " + cmd);
                    llOwnerSay("@" + cmd + "=n");
                }
            }
        }

        else if (code == RLV_CMD) {
            string commandString = cdListElement(split, 1);

            debugSay(7,"DEBUG-STATUSRLV","Got Link Message 315 from script " + script + ": " + commandString);

            if (RLVok) {
                // This can happen...
                if (commandString == "" || commandString == "0") {
                    llSay(DEBUG_CHANNEL,"command empty! :" + script);
                    return;
                }

                if (llStringLength(commandString) > CHATMSG_MAXLEN) {
                    llSay(DEBUG_CHANNEL,"command string too long! :" + script + ":(" + commandString + ")");
                    return;
                }

                llOwnerSay("@" + commandString);

                statusHandle = cdListenMine(statusChannel);
                llOwnerSay("@getstatus=" + (string)statusChannel);
            }
#ifdef DEVELOPER_MODE

            // There is a case to be made that this is a run-time program error,
            // and needs to be sent to the user as an error to be reported.

            else {
                llSay(DEBUG_CHANNEL,"Received RLV with no RLV active: " + commandString);
            }
#endif
        }
        else if (code == RLV_RESET) {
            RLVok = (cdListIntegerElement(split, 0) == 1);

            debugSay(4,"DEBUG-STATUSRLV","rlvCommand (refresh) activated");
            if (RLVok)
                lmInternalCommand("refreshRLV","",NULL_KEY);
        }
        else if (code < 200) {
            if (code == 135) {
                float delay = cdListFloatElement(split, 0);

                memReport(cdMyScriptName(),delay);
            }
            else if (code == 142) {

                cdConfigureReport();
            }
        }
    }
}

//========== STATUSRLV ==========
