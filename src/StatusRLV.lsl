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
//list rlvStatus; ... not used
list rlvRestrict;
//list rlvRestrictions; ... not used

string scriptName;
string defaultBaseRLVcmd;
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
            if (data == "") return; // fast exit

            // Note that we are building rlvRestrict here - its value
            // was cleared elsewhere before we got here the first time
            debugSay(4,"DEBUG-STATUSRLV","RLV status: " + data);
            rlvRestrict = (rlvRestrict=[]) + rlvRestrict + llParseString2List(data, [ "/" ], []);
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
                 if (name == "debugLevel") debugLevel = (integer)value;
#endif
            else if (name == "defaultBaseRLVcmd") defaultBaseRLVcmd = value;
            return;
        }

        else if (code == INTERNAL_CMD) {
            string cmd = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);

            if (cmd == "refreshRLV") {
                debugSay(4,"DEBUG-STATUSRLV","Restoring recorded restrictions...");

                if (rlvRestrict == []) return; // no restrictions

                string cmd;
                i = llGetListLength(rlvRestrict);
                while (i--) {
                    cmd = llList2String(rlvRestrict, i);

                    // This assumes that all cmds in the rlvRestrict are y/n options!
                    llOwnerSay("@" + cmd + "=n");
                }
            }
            else if (cmd == "instantMessage") {

                // This is segregated for speed: this script (StatusRLV) doesn't have
                // an overriding need to not have a 2s delay in it
                llInstantMessage(id,llList2String(split,0));
            }
#ifdef NOT_USED
            else if (cmd == "runRLVcmd") {
                // The goal of the runRLVcmd command is to perform
                // non-restrictive RLV commands requested

                string commandString = cdListElement(split, 1);

                if (RLVok != TRUE) {
                    if (RLVok == UNSET) llSay(DEBUG_CHANNEL,"RLV command issued with RLV active! (" + commandString + ")");
                    return;
                }

                debugSay(4,"DEBUG-STATUSRLV","Got RLV_CMD (315) from script " + script + ": " + commandString);

                if (RLVok == TRUE) {
                    if (commandString == "clear") {
                        // this is a blanket clear, but it doesn't mean to us what
                        // it means normally: we have a base RLV set

                        //llSay(DEBUG_CHANNEL,"blanket clear issued from " + script);
                        commandString +=
#ifdef LOCKON
                            ",permissive=n,detach=n";
#else
                            ",permissive=y,detach=y";
#endif
                        if (rlvRestrict == []) {
                            if (defaultBaseRLVcmd != "") commandString += defaultBaseRLVcmd;
                        }
                        else commandString += llDumpList2String(rlvRestrict, ",");

                        llOwnerSay("@" + commandString);
                        lmInternalCommand("reloadExceptions",script,NULL_KEY);
                        //lmInternalCommand("clearRLV",script,NULL_KEY);
                        return;
                    }
                    else {

                        // This could thereotically happen...
                        if (commandString == "" || commandString == "0") {
                            llSay(DEBUG_CHANNEL,"requested RLV command from " + script + " is empty!");
                            return;
                        }

                        if (llStringLength(commandString) > CHATMSG_MAXLEN) {
                            llSay(DEBUG_CHANNEL,"requested RLV command from " + script + " is too long!");
                            //llSay(DEBUG_CHANNEL,"requested RLV command from " + script + " is too long!");
                            return;
                        }

                        llOwnerSay("@" + commandString);
                    }
                }
#ifdef DEVELOPER_MODE

                // This is not a run-time error - after all, the RLV was not executed -
                // the only problem is one of speed and optimization.

                else {
                    debugSay(4,"DEBUG-STATUSRLV","Received RLV with no RLV active: " + commandString);
                }
#endif
            }
#endif
            else if (cmd == "restrictRLVcmd") {
                // The goal of the restrictRLVcmd command is to implement the
                // requested restriction (cmd) and then store it in a variable
                // to be restored later
                //
                // Once this command is widely used, storeRLV will be unneeded.

                string commandString = cdListElement(split,1);

                if (RLVok != TRUE) {
                    if (RLVok == UNSET) llSay(DEBUG_CHANNEL,"RLV command issued with RLV active! (" + commandString + ")");
                    return;
                }

                script = cdListElement(split,0);
                list tmpList;

                llOwnerSay("@" + commandString);

                rlvRestrict = (rlvRestrict=[]) + rlvRestrict + commandString;
            }
#ifdef NOT_USED
            else if (cmd == "storeRLV") {
                // The goal of the storeRLV command is to take current RLV
                // restrictions and save them into a variable, and thus
                // preserve the restrictions for later logon

                script = cdListElement(split,0);
                string commandString = cdListElement(split, 1);
                list tmpList;

                // *** We don't need to do this, if we implement an internal
                //     command that is used only for restrictions - which is
                //     a better idea anyway. Such a command "rlvRestrictCmd"
                //     would be the one to call storeRLV
                //
                // if rlvCmdIssued is 0, that means that
                // no command has gone out since we ran last....
                // so ignore it.
                // if (rlvCmdIssued) rlvCmdIssued = 0;
                // else return;

                // Here we're just getting current RLV restrictions
                statusHandle = cdListenMine(statusChannel);
                rlvRestrict = [];

                // Default restrictions used by the key:
                //     * alwaysrun
                //     * edit
                //     * fartouch
                //     * sendchat
                //     * showhovertextall
                //     * showinv
                //     * showloc
                //     * showminimap
                //     * shownames
                //     * showworldmap
                //     * sit
                //     * sittp
                //     * tplm
                //     * tploc
                //     * tplure

                // The following sequence should get all restrictions,
                // one by one - and maybe a few more, but that is ok
                llOwnerSay("@getstatus:tp="        + (string)statusChannel);
                llOwnerSay("@getstatus:sit="       + (string)statusChannel);
                llOwnerSay("@getstatus:show="      + (string)statusChannel);
                llOwnerSay("@getstatus:alwaysrun=" + (string)statusChannel);
                llOwnerSay("@getstatus:edit="      + (string)statusChannel);
                llOwnerSay("@getstatus:fartouch="  + (string)statusChannel);
            }
#endif
        }

        else if (code == RLV_CMD) {
            string commandString = cdListElement(split, 1);

            debugSay(4,"DEBUG-STATUSRLV","Got RLV_CMD (315) from script " + script + ": " + commandString);

            if (RLVok != TRUE) {
                if (RLVok == UNSET) llSay(DEBUG_CHANNEL,"RLV command issued with RLV active! (" + commandString + ")");
                return;
            }

            if (RLVok == TRUE) {
                if (commandString == "clear") {
                    // this is a blanket clear, but it doesn't mean to us what
                    // it means normally: we have a base RLV set

                    //llSay(DEBUG_CHANNEL,"blanket clear issued from " + script);
#ifdef LOCKON
                    commandString += ",permissive=n,detach=n," + defaultBaseRLVcmd;
#else
                    commandString += ",permissive=y,detach=y," + defaultBaseRLVcmd;
#endif
                    llOwnerSay("@" + commandString);
                    lmInternalCommand("reloadExceptions",script,NULL_KEY);
                    //lmInternalCommand("clearRLV",script,NULL_KEY);
                    return;
                }
                else {

                    // This could thereotically happen...
                    if (commandString == "" || commandString == "0") {
                        llSay(DEBUG_CHANNEL,"requested RLV command from " + script + " is empty!");
                        return;
                    }

                    if (llStringLength(commandString) > CHATMSG_MAXLEN) {
                        llSay(DEBUG_CHANNEL,"requested RLV command from " + script + " is too long!");
                        //llSay(DEBUG_CHANNEL,"requested RLV command from " + script + " is too long!");
                        return;
                    }

                    llOwnerSay("@" + commandString);
                    rlvCmdIssued = 1;
                    //lmInternalCommand("storeRLV",script + "|" + commandString,NULL_KEY);
                }
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
