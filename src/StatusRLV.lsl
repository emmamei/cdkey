//========================================
// StatusRLV.lsl
//========================================
//
// vim:sw=4 et nowrap:
//
// DATE: 24 November 2020

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
#define COMPLETE_CLEAR 1

#ifndef COMPLETE_CLEAR
// rlvStatus is a list with stride 2:
//
//  1: RLV restriction
//  2: String CSV containing scripts using restriction
//
list rlvRestrict;
#endif

string scriptName;
integer statusChannel = 55117;
integer statusHandle;
integer rlvCmdIssued;

//========================================
// FUNCTIONS
//========================================


//========================================
// STATES
//========================================
default {

    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------
    state_entry() {
        myName = llGetScriptName();
        keyID = llGetKey();

        cdInitializeSeq();
        //scaleMem();
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer start) {
        cdInitializeSeq();
        //scaleMem();
    }

#ifndef COMPLETE_CLEAR
    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer channel, string name, key id, string data) {

        if (channel == statusChannel) {
            if (data == "") return; // fast exit

            // Note that we are building rlvRestrict here - its value
            // was cleared elsewhere before we got here the first time
            debugSay(4,"DEBUG-STATUSRLV","RLV status: " + data);
            rlvRestrict = (rlvRestrict=[]) + rlvRestrict + llParseString2List(data, [ "/" ], []);
        }
    }
#endif

    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    link_message(integer sender, integer i, string data, key id) {

        // Parse link message header information
        split             =     cdSplitArgs(data);
        script            =     (string)split[0];
        remoteSeq         =     (i & 0xFFFF0000) >> 16;
        optHeader         =     (i & 0x00000C00) >> 10;
        code              =      i & 0x000003FF;
        split             =     llDeleteSubList(split, 0, 0 + optHeader);

        //scaleMem();

        if (code == SEND_CONFIG) {
            string name = (string)split[0];
            string value = (string)split[1];

                 if (name == "RLVok")              RLVok = (integer)value;
            else if (name == "RLVsupport")    RLVsupport = (integer)value;
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")    debugLevel = (integer)value;
#endif
            else
            return;
        }

        else if (code == INTERNAL_CMD) {
            string cmd = (string)split[0];
            split = llDeleteSubList(split, 0, 0);

            if (cmd == "instantMessage") {

                // This is segregated for speed: this script (StatusRLV) doesn't have
                // an overriding need to not have a 2s delay in it
                llInstantMessage(id,(string)split[0]);
            }
        }
        else if (code == RLV_CMD) {
            string commandString = (string)split[2];
            string cmd = (string)split[1];
            //split = llDeleteSubList(split, 0, 0);

            debugSay(4,"DEBUG-STATUSRLV","RLV_CMD script " + script + ": " + cmd + ": " + commandString);

            if (RLVok != TRUE) {
                if (RLVok == UNSET) llSay(DEBUG_CHANNEL,"RLV command issued with RLV inactive from " + script + "! (" + commandString + ")");
                return;
            }

            if (cmd == "runRLVcmd") {
                if (commandString == "clear") {
                    llSay(DEBUG_CHANNEL,"Clear command run from " + script + " using lmRunRLVcmd - use clearRLVcmd instead");
                    lmRunRLVcmd("clearRLVcmd",commandString);
                    return;
                }

                // This could thereotically happen...
                if (commandString == "" || commandString == "0") {
                    llSay(DEBUG_CHANNEL,"requested RLV command from " + script + " is empty!");
                    return;
                }

                if (llStringLength(commandString) > CHATMSG_MAXLEN) {
                    llSay(DEBUG_CHANNEL,"requested RLV command from " + script + " is too long!");
                    return;
                }

                debugSay(6,"DEBUG-STATUSRLV","RLV received: @" + commandString);

                llOwnerSay("@" + commandString);
            }
            else if (cmd == "escapeRLVcmd") {
                // complete cancel of all RLV - such as from SafeWord
                llOwnerSay("@clear"); // Total RLV zap: such as from SafeWord
                RLVok = FALSE;
            }
            else if (cmd == "clearRLVcmd") {
                // this is a blanket clear, but it doesn't mean to us what
                // it means normally: we have a base RLV set

                debugSay(2,"DEBUG-STATUSRLV","RLV clear command issued from " + script);
                llSay(DEBUG_CHANNEL,"clearRLVcmd run from " + script);

                llOwnerSay("@clear"); // clear command
                if (commandString != "")
                    llOwnerSay("@" + commandString); // restore restrictions if need be

                lmInternalCommand("restoreRestrictions",script,NULL_KEY); // restore RLV restrictions
                lmInternalCommand("reloadExceptions",script,NULL_KEY); // then restore exceptions
            }
        }
        else if (code == RLV_RESET) {
            RLVok = (integer)split[0];

            if (RLVok == TRUE)
                lmInternalCommand("restoreRestrictions",script,NULL_KEY); // restore RLV restrictions
        }
        else if (code < 200) {
            if (code == CONFIG_REPORT) {

                cdConfigureReport();
            }
#ifdef DEVELOPER_MODE
            else if (code == MEM_REPORT) {
                float delay = (float)split[0];

                memReport(myName,delay);
            }
#endif
        }
    }
}

//========== STATUSRLV ==========
