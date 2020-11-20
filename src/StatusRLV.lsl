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

            if (cmd == "instantMessage") {

                // This is segregated for speed: this script (StatusRLV) doesn't have
                // an overriding need to not have a 2s delay in it
                llInstantMessage(id,llList2String(split,0));
            }
        }
        else if (code == RLV_CMD) {
            string commandString = cdListElement(split, 2);
            string cmd = llList2String(split, 1);
            //split = llDeleteSubList(split, 0, 0);

            debugSay(4,"DEBUG-STATUSRLV","Got RLV_CMD (315) from script " + script + ": " + cmd + " - " + commandString);

            if (RLVok != TRUE) {
                if (RLVok == UNSET) llSay(DEBUG_CHANNEL,"RLV command issued with RLV active! (" + commandString + ")");
                return;
            }

            if (cmd == "restrictRLVcmd") {
                // The goal of the restrictRLVcmd command is to implement the
                // requested restriction (cmd) and then store it in a variable
                // to be restored later
                //
                // Once this command is widely used, storeRLV will be unneeded.

                script = cdListElement(split,0);
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

//integer rlvAlwaysrun;
//integer rlvEdit;
//integer rlvFartouch;
//integer rlvSendchat;
//integer rlvShowhovertextall;
//integer rlvShowinv;
//integer rlvShowloc;
//integer rlvShowminimap;
//integer rlvShownames;
//integer rlvShowworldmap;
//integer rlvSit;
//integer rlvSittp;
//integer rlvTplm;
//integer rlvTploc;
//integer rlvTplure;

                // Split command string into multiple commands
                list commandList;
                commandList = llParseString2List(commandString,[","],[""]);

                // iterate over list
                integer index = ~llGetListLength(commandList);
                string ending;
                string command;

                while(index++) {
                    // Either find "=n" or "=y" and handle it
                    command = llList2String(commandList,index);
                    ending = llGetSubString(command,-2,-1);
                    debugSay(4,"DEBUG-STATUSRLV","RestrictRLVcmd: command = " + command);
                    debugSay(4,"DEBUG-STATUSRLV","RestrictRLVcmd: ending = " + ending);

                    llOwnerSay("@" + command);
                }


                rlvRestrict = (rlvRestrict=[]) + rlvRestrict + commandString;
            }
            else if (cmd == "restoreRLV") {
                // The goal of the restoreRLV command is to take saved RLV
                // restrictions and restore them after logon or RLV activation
                debugSay(4,"DEBUG-STATUSRLV","Restoring recorded restrictions...");

                //return; // FIXME: temporarily restore no restrictions at all
                if (rlvRestrict == []) return; // no restrictions

                string cmd;
                i = ~llGetListLength(rlvRestrict);
                while (i++) {
                    cmd = llList2String(rlvRestrict, i);
                    llOwnerSay("@" + cmd);
                }
            }
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

                llOwnerSay("@" + commandString);
                //lmInternalCommand("storeRLV",script + "|" + commandString,NULL_KEY);
            }
            else if (cmd == "escapeRLVcmd") {
                // complete zap of all RLV - such as from SafeWord
                llOwnerSay("@clear");
                RLVok = FALSE;
                rlvRestrict = [];
            }
            else if (cmd == "clearRLVcmd") {
                // this is a blanket clear, but it doesn't mean to us what
                // it means normally: we have a base RLV set

                llSay(DEBUG_CHANNEL,"blanket clear issued from " + script);
                llOwnerSay("@clear"); // clear
#ifdef LOCKON
                llOwnerSay("@detach=n"); // detach
#else
                llOwnerSay("@detach=y"); // detach
#endif
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

                if (commandString != "")
                    llOwnerSay("@" + commandString); // restore restrictions if need be

                //lmInternalCommand("reloadExceptions",script,NULL_KEY); // then restore exceptions
                //lmInternalCommand("clearRLV",script,NULL_KEY);
            }
        }
        else if (code == RLV_RESET) {
            RLVok = llList2Integer(split, 0);

            //debugSay(4,"DEBUG-STATUSRLV","rlvCommand (refresh) activated");
            if (RLVok == TRUE)
                lmRunRLVcmd("restoreRLV","");
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
