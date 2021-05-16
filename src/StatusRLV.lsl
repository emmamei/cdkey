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
        cdInitializeSeq();
        keyID = llGetKey();
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

            if (cmd == "restrictRLVcmd") {
                // The goal of the restrictRLVcmd command is to implement the
                // requested restriction (cmd) and then store it in a variable
                // to be restored later
                //
                // Once this command is widely used, storeRLV will be unneeded.

                script = (string)split[0];
                list tmpList;

                // This could thereotically happen...
                if (commandString == "" || commandString == "0") {
                    llSay(DEBUG_CHANNEL,"requested RLV command from " + script + " is empty!");
                    return;
                }

                if (llStringLength(commandString) > CHATMSG_MAXLEN) {
                    llSay(DEBUG_CHANNEL,"requested RLV command from " + script + " is too long!");
                    return;
                }

#ifdef COMPLETE_CLEAR
                llOwnerSay("@" + commandString);
#else
                // Split command string into multiple commands
                list commandList;
                commandList = llParseString2List(commandString,[","],[""]);

                // iterate over list
                integer index = ~llGetListLength(commandList);
                string ending;
                string command;

                while(index++) {
                    // Either find "=n" or "=y" and handle it
                    command = (string)commandList[index];
                    ending = llGetSubString(command,-2,-1);

                    llOwnerSay("@" + command);
                }


                rlvRestrict = (rlvRestrict=[]) + rlvRestrict + commandString;
#endif
            }
#ifndef COMPLETE_CLEAR
            else if (cmd == "restoreRLV") {
                // The goal of the restoreRLV command is to take saved RLV
                // restrictions and restore them after logon or RLV activation
                debugSay(4,"DEBUG-STATUSRLV","Restoring recorded restrictions...");

                if (rlvRestrict == []) return; // no restrictions

                string cmd;
                i = ~llGetListLength(rlvRestrict);
                while (i++) {
                    cmd = (string)rlvRestrict[i];
                    llOwnerSay("@" + cmd);
                }
            }
            else if (cmd == "storeRLV") {
                // The goal of the storeRLV command is to take current RLV
                // restrictions and save them into a variable, and thus
                // preserve the restrictions for later logon

                script = (string)split[0];
                string commandString = (string)split[1];
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
            else if (cmd == "runRLVcmd") {
                if (commandString == "clear") {
                    llSay(DEBUG_CHANNEL,"Clear command run from " + script + " using lmRunRLVcmd");
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
                //lmInternalCommand("storeRLV",script + "|" + commandString,NULL_KEY);
            }
            else if (cmd == "escapeRLVcmd") {
                // complete zap of all RLV - such as from SafeWord
                llOwnerSay("@clear");
                RLVok = FALSE;
#ifndef COMPLETE_CLEAR
                rlvRestrict = [];
#endif
            }
            else if (cmd == "clearRLVcmd") {
                // this is a blanket clear, but it doesn't mean to us what
                // it means normally: we have a base RLV set

                debugSay(2,"DEBUG-STATUSRLV","RLV clear command issued from " + script);

#ifdef COMPLETE_CLEAR
                llOwnerSay("@clear"); // clear
#else
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
                llOwnerSay("@clear=tp");
                llOwnerSay("@clear=sit");
                llOwnerSay("@clear=show");
                llOwnerSay("@clear=alwaysrun");
                llOwnerSay("@clear=edit");
                llOwnerSay("@clear=fartouch");
                llOwnerSay("@clear=send");
                llOwnerSay("@clear=recv");
#endif
                if (commandString != "")
                    llOwnerSay("@" + commandString); // restore restrictions if need be

                //lmInternalCommand("reloadExceptions",script,NULL_KEY); // then restore exceptions
                //lmInternalCommand("clearRLV",script,NULL_KEY);
            }
        }
        else if (code == RLV_RESET) {
            RLVok = (integer)split[0];

            if (RLVok == TRUE)
                lmRunRLVcmd("restoreRLV","");
        }
        else if (code < 200) {
            if (code == CONFIG_REPORT) {

                cdConfigureReport();
            }
#ifdef DEVELOPER_MODE
            else if (code == MEM_REPORT) {
                float delay = (float)split[0];

                memReport(cdMyScriptName(),delay);
            }
#endif
        }
    }
}

//========== STATUSRLV ==========
