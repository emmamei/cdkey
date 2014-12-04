//========================================
// StatusRLV.lsl
//========================================
//
// vim:sw=4 et nowrap:
//
// DATE: 27 October 2014
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

#ifdef LINK_320
#define RESTRICTION_NEW "+"
#define RESTRICTION_ADDED "^"
#define RESTRICTION_REMOVED "-"
#define RESTRICTION_DROPPED "~"
#endif

#define CHATMSG_MAXLEN 896
#define SCRIPT_MAXMEM 65536

key rlvTPrequest;

list rlvSources;
list rlvStatus;

string scriptName;

integer RLVstarted;

//========================================
// STATES
//========================================
default {

    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------
    state_entry() {
        dollID = llGetOwner();
        scriptName = llGetScriptName();

        cdInitializeSeq();
        scaleMem();

#ifdef WAKESCRIPT
        llSetScriptState("StatusRLV",0);
#endif
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer start) {
        // This converts the "on_rez" event to a "state_entry" event
        debugSay(1,"DEBUG-STATUSRLV","Resetting (on_rez complete)");
        llResetScript();
    }

    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    link_message(integer sender, integer i, string data, key id) {

        // Parse link message header information
        list split        =     cdSplitArgs(data);
        string script     =     cdListElement(split, 0);
        integer remoteSeq =     (i & 0xFFFF0000) >> 16;
        integer optHeader =     (i & 0x00000C00) >> 10;
        integer code      =      i & 0x000003FF;
        split             =     llDeleteSubList(split, 0, 0 + optHeader);

        // Link Messages Handled:
        //
        // 104: Initialization
        // 105: Initialization
        // 110: Initialization
        // 135: Memory Report
        // 300: Commands? ("debugLevel")
        // 315: RLV Commands
        // 350: RLVok Yes/No Notification

        scaleMem();

        // quick return for often ignored codes
             if (code == 305) return;
        else if (code == 136) return;

        else if (code == 300) {
            string name = cdListElement(split, 0);
            string value = cdListElement(split, 1);

            if (name == "RLVok")    RLVok = (integer)value;
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel") debugLevel = (integer)cdListElement(split, 1);
#endif
            return;
        }

        else if (code == 135) {
            float delay = cdListFloatElement(split, 0);

            memReport(cdMyScriptName(),delay);
        } else

        cdConfigReport();

        else if (code == 315) {
            //string realScript = script;
            //string script = cdListElement(split, 0);
            string commandString = cdListElement(split, 1);

            // This can happen...
            if (commandString == "" || commandString == "0") return;

            debugSay(1,"DEBUG-STATUSRLV","Got Link Message 315 from script " + script + ": " + commandString);

            //if (script == "") script = realScript;

            if (RLVok) {
                //llSetMemoryLimit(65536);
                //debugSay(5,"DEBUG-STATUSRLV","StatusRLV memory increased to max.");
                integer commandLoop; string sendCommands = "";
#ifdef LINK_320
                string confCommands = "";
#endif
                string fullCmd;
                list parts;
                string param;
                string cmd;
                integer nextComma;

                do {
                    scaleMem();

                    // Pull out the next RLV command into commandString
                    fullCmd = "";

                    if ((nextComma = llSubStringIndex(commandString, ",")) == NOT_FOUND) {
                        //nextComma = llStringLength(commandString);
                        fullCmd = commandString;
                        commandString = "";
                    }
                    else {
                        fullCmd = llStringTrim(llGetSubString(commandString, 0, nextComma - 1), STRING_TRIM);
                        commandString = llDeleteSubString(commandString, 0, nextComma);
                    }

                    if ((llSubStringIndex(fullCmd, "=")) == NOT_FOUND) {
                        param = "";
                        cmd = fullCmd;
                    }
                    else {
                        parts = llParseString2List(fullCmd, [ "=" ], []);
                        param = cdListElement(parts, 1);
                        cmd = cdListElement(parts, 0);
                    }

                    parts = []; // not needed, so clear it

                    // Send an RLV command if the string would be too long
                    if (llStringLength(sendCommands + fullCmd + ",?") > CHATMSG_MAXLEN) {
                        llOwnerSay(llGetSubString("@" + sendCommands, 0, -2));
                        sendCommands = "";
                    }
                    //sendCommands += fullCmd + ",";

#ifdef LINK_320
                    // confirm RLV commands
                    if (llStringLength(confCommands + fullCmd + ",?") > CHATMSG_MAXLEN) {
                        lmConfirmRLV(script, llGetSubString(confCommands, 0, -2));
                        //debugSay(llGetSubString(confCommands, 0, -2));
                        confCommands = "";
                    }
                    //confCommands += fullCmd + ",";
#endif

                    //debugSay(5,"DEBUG-RLV","fullCmd = \"" + fullCmd + "\"");
                    if (cmd != "clear") {
                        if (param == "n" || param == "add") {
                            integer cmdIndex = cdListElementP(rlvStatus, cmd);

                            if (cmdIndex == NOT_FOUND) { // New restriction add to list and send to viewer
                                rlvStatus += [ cmd, script ];
                                sendCommands += fullCmd + ",";
#ifdef LINK_320
                                // + symbol confirms that our restriction has been added and it was not in effect from another
                                //   script.  The restriction has now been sent to the viewer and currently we have full control
                                //   of it.

                                confCommands += RESTRICTION_NEW + cmd + ",";
#endif
                            }

                            else if (llGetSubString(cmd, -8, -1) == "_except") sendCommands += fullCmd + ",";

                            else { // Duplicate restriction, note but do not send again
                                string scripts = cdListElement(rlvStatus, cmdIndex + 1);
                                list scriptList = cdSplitString(scripts);
                                integer myIndex = cdListElementP(scriptList, script);

                                if (myIndex == NOT_FOUND) {
#ifdef LINK_320
                                    // ^ symbol confirms our restriction has been added but was already set by another script
                                    //   both scripts must release this restriction before it will be removed.

                                    confCommands += RESTRICTION_ADDED + cmd + ",";
#endif
                                    scriptList = llListSort(scriptList + [ script ], 1, 1);
                                    rlvStatus = llListReplaceList(rlvStatus, [ cmd, llDumpList2String(scriptList, ",") ],
                                                                  cmdIndex, cmdIndex + 1);
                                }
                            }
                        }
                        else if (param == "y" || param == "rem") {
                            integer cmdIndex = cdListElementP(rlvStatus, cmd);

                            if (cmdIndex != NOT_FOUND) { // Restriction does exist from one or more scripts
                                string scripts = cdListElement(rlvStatus, cmdIndex + 1);
                                list scriptList = cdSplitString(scripts);
                                integer myIndex = cdListElementP(scriptList, script);

                                if (myIndex != NOT_FOUND) { // This script is one of the restriction issuers clear it
                                    scriptList = llDeleteSubList(scriptList, myIndex, myIndex);

                                    if (scriptList == []) { // All released delete old record and send to viewer
                                        rlvStatus = llDeleteSubList(rlvStatus, cmdIndex, cmdIndex + 1);
                                        sendCommands += fullCmd + ",";

#ifdef LINK_320
                                        // - symbol means we were the only script holding this restriction it has been
                                        //   deleted from the viewer.
                                        confCommands += RESTRICTION_REMOVED + cmd + ",";
#endif
                                    }
                                    else {

#ifdef LINK_320
                                        // ~ symbol means we cleared our restriction but it is still enforced by at least
                                        //   one other script.
                                        confCommands += RESTRICTION_DROPPED + cmd + ",";
#endif
                                        rlvStatus = llListReplaceList(rlvStatus, [ cmd, llDumpList2String(scriptList, ",") ],
                                                                      cmdIndex, cmdIndex + 1);
                                    }
                                }
                            }
                        }
                        else {
                            // Oneshot command
                            sendCommands += fullCmd + ",";
#ifdef LINK_320
                            confCommands += fullCmd + ",";
#endif
                        }
                    }
                    else {
                        // command is "clear" ...
                        integer i;
#ifdef LINK_320
                        integer matches; integer reduced; integer cleared; integer held;
#endif
                        string scripts;
                        list scriptList;
                        integer myIndex;
                        string thisCmd;

                        for (; i < llGetListLength(rlvStatus); i = i + 2) {
                            thisCmd = cdListElement(rlvStatus, i);

                            if (llSubStringIndex(thisCmd, param) != NOT_FOUND) { // Restriction matches clear param
#ifdef LINK_320
                                matches++;
#endif
                                scripts = cdListElement(rlvStatus, i + 1);
                                scriptList = cdSplitString(scripts);
                                myIndex = cdListElementP(scriptList, script);

                                if (myIndex != NOT_FOUND) { // This script is one of the restriction issuers clear it
                                    scriptList = llDeleteSubList(scriptList, myIndex, myIndex);
#ifdef LINK_320
                                    reduced++;
#endif
                                    if (scriptList == []) { // All released delete old record and send to viewer
                                        rlvStatus = llDeleteSubList(rlvStatus, i, i + 1);
                                        i = i - 2;
#ifdef LINK_320
                                        cleared++;
#endif

                                        if (llStringLength(sendCommands + thisCmd + "=y,") > CHATMSG_MAXLEN) {
                                            llOwnerSay(llGetSubString("@" + sendCommands, 0, -2));
                                            sendCommands = "";
                                        }

                                        sendCommands += thisCmd + "=y,";
                                    }
                                    else { // Restriction still holds due to other scripts but release for this one
#ifdef LINK_320
                                        held++;
#endif
                                        rlvStatus = llListReplaceList(rlvStatus, [ thisCmd, llDumpList2String(scriptList, ",") ],
                                                                      i, i + 1);
                                    }
                                }
                            }
                        }

#ifdef LINK_320
                        // Clear command confirmations are a little more complex as they can have many matches, the reply gives the
                        // records affected counts as follows clear=param/matches/reduced/cleared/held
                        //  * Matches: At least one restriction matching this param exists which may or may not be ours.
                        //  * Reduced: Matching restrictions of ours which have now been eliminated by the clear command they may be held by others.
                        //  * Cleared: Number of reduced restrictions which were completly cleared and removed from the viewer.
                        //  * Held: Number of reduced restrictions which were also held by others scripts and remain in effect.

                        if (reduced != 0 || cleared != 0 || held != 0) { // Send confirm link only for changes
                            string clrCmd = fullCmd + "/" + (string)matches + "/" + (string)reduced + "/" + (string)cleared + "/" + (string)held;
                            if (llStringLength(confCommands + clrCmd + ",") > CHATMSG_MAXLEN) {
                                lmConfirmRLV(script, llGetSubString(confCommands, 0, -2));
                                //debugSay(llGetSubString(confCommands, 0, -2));
                                confCommands = "";
                            }
                            confCommands += clrCmd + ",";
                        }
#endif
                    }
                } while (llStringLength(commandString));
                

                if ((sendCommands != "") && (sendCommands != ",")) {
                    debugSay(2,"DEBUG-STATUSRLV","RLV commands sent: " + sendCommands);
                    llOwnerSay(llGetSubString("@" + sendCommands, 0, -2));
                }
#ifdef LINK_320
                if ((confCommands != "") && (confCommands != ",")) lmConfirmRLV(script, llGetSubString(confCommands, 0, -2));
#endif
            }
#ifdef DEVELOPER_MODE

            // There is a case to be made that this is a run-time program error,
            // and needs to be sent to the user as an error to be reported.

            else {
                debugSay(2,"DEBUG-STATUSRLV","Received RLV with no RLV active: " + commandString);
            }
#endif
        }
        else if (code == 350) {
            RLVok = (cdListIntegerElement(split, 0) == 1);
            RLVstarted = 1;
        }
    }
}
