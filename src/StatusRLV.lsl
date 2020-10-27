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
list rlvRestrictions;

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
    // LISTEN
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
            string name = cdListElement(split, 0);
            string value = cdListElement(split, 1);

#ifdef DEVELOPER_MODE
                 if (name == "debugLevel") debugLevel = (integer)cdListElement(split, 1);
            //else if (name == "debugLevel") debugLevel = (integer)cdListElement(split, 1);
#endif
            return;
        }

        else if (code == INTERNAL_CMD) {
            string cmd = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);

            if (cmd == "refreshRLV") {
                //llOwnerSay("Reactivating RLV restrictions");
                if (rlvRestrict) llOwnerSay("@" + llDumpList2String(rlvRestrict,",=n") + "=n");

                //string cmd;
                //i = llGetListLength(rlvRestrict);
                //while (i--) {
                //    cmd += llList2String(rlvRestrict, i);
                //
                //    This assumes that all cmds in the rlvRestrict are y/n options!
                //    llOwnerSay("@" + cmd + "=n");
                //}
            }
            else if (cmd == "instantMessage") {

                // This is segregated for speed: this script (StatusRLV) doesn't have
                // an overriding need to not have a 2s delay in it
                llInstantMessage(id,llList2String(split,0));
            }
            else if (cmd == "storeRLV") {
                script = cdListElement(split,0);
                string commandString = cdListElement(split, 1);
                list tmpList;

                // if rlvCmdIssued is 0, that means that
                // no command has gone out since we ran last....
                // so ignore it.
                if (rlvCmdIssued) rlvCmdIssued = 0;
                else return;

                // Here we're just getting current RLV restrictions
                statusHandle = cdListenMine(statusChannel);
                llOwnerSay("@getstatus=" + (string)statusChannel);
            }
        }

        else if (code == RLV_CMD) {
            string commandString = cdListElement(split, 1);

            debugSay(7,"DEBUG-STATUSRLV","Got Link Message 315 from script " + script + ": " + commandString);

            if (RLVok == TRUE) {
                // Note that this does NOT handle "clear=..."
                if (commandString == "clear") {
#ifdef LOCKON
                    // this is a blanket clear, but it doesn't mean to us what
                    // it means normally: we have a base RLV set
                    commandString += ",permissive=n,detach=n";
                    //if (userBaseRLVcmd) commandString += "," + userBaseRLVcmd;
#else
                    //llSay(DEBUG_CHANNEL,"blanket clear issued from " + script);
                    commandString += ",permissive=y,detach=y";
#endif
                    //lmInternalCommand("clearRLV",script,NULL_KEY);
                    //return;
                }

                // This can happen...
                if (commandString == "" || commandString == "0") {
                    llSay(DEBUG_CHANNEL,"requested RLV command from " + script + " is empty!");
                    return;
                }

                if (llStringLength(commandString) > CHATMSG_MAXLEN) {
                    llSay(DEBUG_CHANNEL,"requested RLV command (" + commandString + ") from " + script + " is too long!");
                    return;
                }

                llOwnerSay("@" + commandString);
                rlvCmdIssued = 1;
                lmInternalCommand("storeRLV",script + "|" + commandString,NULL_KEY);
            }
#ifdef DEVELOPER_MODE

            // This is not a run-time error - after all, the RLV was not executed -
            // the only problem is one of speed and optimization.

            else {
                debugSay(4,"DEBUG-STATUSRLV","Received RLV with no RLV active: " + commandString);
            }
#endif
        }
        else if (code == RLV_RESET) {
            RLVok = llList2Integer(split, 0);

            //debugSay(4,"DEBUG-STATUSRLV","rlvCommand (refresh) activated");
            if (RLVok == TRUE)
                lmInternalCommand("refreshRLV","",NULL_KEY);
        }
        else if (code < 200) {
            if (code == MEM_REPORT) {
                float delay = cdListFloatElement(split, 0);

                memReport(cdMyScriptName(),delay);
            }
            else if (code == CONFIG_REPORT) {

                cdConfigureReport();
            }
        }
    }
}

//========== STATUSRLV ==========
