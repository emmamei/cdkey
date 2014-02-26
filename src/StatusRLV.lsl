//========================================
// StatusRLV.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 25 February 2014

#include "include/GlobalDefines.lsl"

//#define DEBUG_BADRLV 1
//
// As of 23 January 2014 this script is now state tracking only
// core RLV command generators are now part of the Avatar script
// thus we keep this script lightweight with plenty of heap room
// for it's runtime data needs.

#define RESTRICTION_NEW "+"
#define RESTRICTION_ADDED "^"
#define RESTRICTION_REMOVED "-"
#define RESTRICTION_DROPPED "~"
#define CHATMSG_MAXLEN 896
#define SCRIPT_MAXMEM 65536

key rlvTPrequest;

list rlvSources;
list rlvStatus;

string scriptName;

integer RLVstarted;
integer initState = 104;
//========================================
// STATES
//========================================
default {
    state_entry() {
        dollID = llGetOwner();
        scriptName = llGetScriptName();
        llSetMemoryLimit(SCRIPT_MAXMEM);
    }

    //----------------------------------------
    // LINK_MESSAGE
    //----------------------------------------

    link_message(integer sender, integer code, string data, key id) {
        list split = cdSplitArgs(data);

        // Link Messages Handled:
        //
        // 104: Initialization
        // 105: Initialization
        // 110: Initialization
        // 135: Memory Report
        // 300: Commands? ("debugLevel")
        // 315: RLV Commands
        // 350: RLVok Yes/No Notification

        if (code == 104 || code == 105) {
            string script = cdListElement(split, 0);
            if (script != "Start") return;

            if (initState == code) lmInitState(initState++);
        }
        if (code == 110) {
            initState = 105;
        }
        else if (code == 135) {
            memReport(cdListFloatElement(split, 1));
        }
        else if (code == 300) {
#ifdef DEVELOPER_MODE
            if (cdListElement(split, 1) == "debugLevel") debugLevel = (integer)cdListElement(split, 2);
#else
            ;
#endif
        }
        else if (code == 315) {
            string realScript = cdListElement(split, 0);
            string script = cdListElement(split, 1);
            string commandString = cdListElement(split, 2);

            if (script == "") script = realScript;

            if (isAttached && RLVok) {
                integer commandLoop; string sendCommands = ""; string confCommands = "";
                //integer charLimit = 896;    // Secondlife supports chat messages up to 1024 chars
                                            // here we avoid sending over 896 at a time for safety
                                            // links will be longer due the the prefix.

                do {
                    string fullCmd; list parts; string param; string cmd;

                    // Pull out the next RLV command into commandString

                    integer nextComma = llSubStringIndex(commandString, ",");
                    if (nextComma == NOT_FOUND) nextComma = llStringLength(commandString);

                    fullCmd = llStringTrim(llGetSubString(commandString, 0, nextComma - 1), STRING_TRIM);
                    commandString = llDeleteSubString(commandString, 0, nextComma);

                    parts = llParseString2List(fullCmd, [ "=" ], []);
                    param = cdListElement(parts, 1);
                    cmd = cdListElement(parts, 0);

                    // Send an RLV command if the string would be too long
                    if (llStringLength(sendCommands + fullCmd + ",?") > CHATMSG_MAXLEN) {
                        llOwnerSay(llGetSubString("@" + sendCommands, 0, -2));
                        sendCommands = "";
                    }
                    //sendCommands += fullCmd + ",";

                    // confirm RLV commands
                    if (llStringLength(confCommands + fullCmd + ",?") > CHATMSG_MAXLEN) {
                        lmConfirmRLV(script, llGetSubString(confCommands, 0, -2));
                        //debugSay(llGetSubString(confCommands, 0, -2));
                        confCommands = "";
                    }
                    //confCommands += fullCmd + ",";

                    if (cmd != "clear") {
                        if (param == "n" || param == "add") {
                            integer cmdIndex = cdListElementP(rlvStatus, cmd);

                            if (cmdIndex == NOT_FOUND) { // New restriction add to list and send to viewer
                                rlvStatus += [ cmd, script ];
                                sendCommands += fullCmd + ",";

                                // + symbol confirms that our restriction has been added and it was not in effect from another
                                //   script.  The restriction has now been sent to the viewer and currently we have full control
                                //   of it.
                                confCommands += RESTRICTION_NEW + cmd + ",";
                            }

                            else if (llGetSubString(cmd, -8, -1) == "_except") sendCommands += fullCmd + ",";

                            else { // Duplicate restriction, note but do not send again
                                string scripts = cdListElement(rlvStatus, cmdIndex + 1);
                                list scriptList = cdSplitString(scripts);
                                integer myIndex = cdListElementP(scriptList, script);

                                if (myIndex == NOT_FOUND) {

                                    // ^ symbol confirms our restriction has been added but was already set by another script
                                    //   both scripts must release this restriction before it will be removed.
                                    confCommands += RESTRICTION_ADDED + cmd + ",";
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

                                        // - symbol means we were the only script holding this restriction it has been
                                        //   deleted from the viewer.
                                        confCommands += RESTRICTION_REMOVED + cmd + ",";
                                    }
                                    else {

                                        // ~ symbol means we cleared our restriction but it is still enforced by at least
                                        //   one other script.
                                        confCommands += RESTRICTION_DROPPED + cmd + ",";
                                        rlvStatus = llListReplaceList(rlvStatus, [ cmd, llDumpList2String(scriptList, ",") ],
                                                                      cmdIndex, cmdIndex + 1);
                                    }
                                }
                            }
                        }
                        else {
                            // Oneshot command
                            sendCommands += fullCmd + ",";
                            confCommands += fullCmd + ",";
                        }
                    }
                    else {
                        // command is "clear" ...
                        integer i; integer matches; integer reduced; integer cleared; integer held;

                        for (i = 0; i < llGetListLength(rlvStatus); i = i + 2) {
                            string thisCmd = cdListElement(rlvStatus, i);

                            if (llSubStringIndex(thisCmd, param) != NOT_FOUND) { // Restriction matches clear param
                                matches++;

                                string scripts = cdListElement(rlvStatus, i + 1);
                                list scriptList = cdSplitString(scripts);
                                integer myIndex = cdListElementP(scriptList, script);

                                if (myIndex != NOT_FOUND) { // This script is one of the restriction issuers clear it
                                    scriptList = llDeleteSubList(scriptList, myIndex, myIndex);
                                    reduced++;

                                    if (scriptList == []) { // All released delete old record and send to viewer
                                        rlvStatus = llDeleteSubList(rlvStatus, i, i + 1);
                                        i = i - 2;
                                        cleared++;

                                        if (llStringLength(sendCommands + thisCmd + "=y,") > CHATMSG_MAXLEN) {
                                            llOwnerSay(llGetSubString("@" + sendCommands, 0, -2));
                                            sendCommands = "";
                                        }

                                        sendCommands += thisCmd + "=y,";
                                    } else { // Restriction still holds due to other scripts but release for this one
                                        held++;
                                        rlvStatus = llListReplaceList(rlvStatus, [ thisCmd, llDumpList2String(scriptList, ",") ],
                                                                      i, i + 1);
                                    }
                                }
                            }
                        }

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
                    }
                } while (llStringLength(commandString));

                if ((sendCommands != "") && (sendCommands != ",")) llOwnerSay(llGetSubString("@" + sendCommands, 0, -2));
                if ((confCommands != "") && (confCommands != ",")) lmConfirmRLV(script, llGetSubString(confCommands, 0, -2));

#ifdef DEVELOPER_MODE
                debugSay(9, "DEBUG-RLV", "Active RLV: " + llDumpList2String(llList2ListStrided(rlvStatus, 0, -1, 2), "/"));
                integer i;
                for (i = 0; i < llGetListLength(rlvStatus); i += 2) {
                    debugSay(9, "DEBUG-RLV", cdListElement(rlvStatus, i) + "\t" + cdListElement(rlvStatus, i + 1));
                }
#endif
            }
        }
        else if (code == 350) {
            RLVok = cdListIntegerElement(split, 1);
            RLVstarted = 1;
        }
    }
}
