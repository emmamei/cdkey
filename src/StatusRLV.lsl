//========================================
// StatusRLV.lsl
//========================================
//
// vim:sw=4 et nowrap:
//
// DATE: 8 December 2013
#include "include/GlobalDefines.lsl"
//
// As of 23 January 2014 this script is now state tracking only
// core RLV command generators are now part of the Avatar script
// thus we keep this script lightweight with plenty of heap room
// for it's runtime data needs.

/* =================================
 * Bugfix: Preprocessor directives may not be redefined unless
 * first #undef.  The following are already defined by the main
 * GlobalDefines.lsl
 * =================================
 * #define cdListElement(a,b) llList2String(a, b)
 * #define cdListFloatElement(a,b) llList2Float(a, b)
 * #define cdListIntegerElement(a,b) llList2Integer(a, b)
 * #define cdListElementP(a,b) llListFindList(a, [ b ]);
 * #define cdSplitArgs(a) llParseStringKeepNulls((a), [ "|" ], [])
 * #define cdSplitString(a) llParseString2List(a, [ "," ], []);
 */
#define NOT_FOUND -1

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
    state_entry() {
        dollID = llGetOwner();
        scriptName = llGetScriptName();
        llSetMemoryLimit(SCRIPT_MAXMEM);
    }
    
    on_rez(integer start) {
        llResetScript();
    }

    //----------------------------------------
    // LINK_MESSAGE
    //----------------------------------------

    link_message(integer sender, integer code, string data, key id) {
        list split = cdSplitArgs(data);
        string script = cdListElement(split, 0);

        // Link Messages Handled:
        //
        // 104: Initialization
        // 105: Initialization
        // 110: Initialization
        // 135: Memory Report
        // 300: Commands? ("debugLevel")
        // 315: RLV Commands
        // 350: RLVok Yes/No Notification

        if (code == 102) {
            scaleMem();
        }
        else if (code == 135) {
            scaleMem();
            memReport(cdListFloatElement(split, 1));
        }
        else if (code == 300) {
            string name = cdListElement(split, 1);
#ifdef DEVELOPER_MODE
            if (name == "debugLevel") debugLevel = (integer)cdListElement(split, 2);
#endif
            if (script == "Main") scaleMem();
        }
        else if (code == 315) {
            string realScript = cdListElement(split, 0);
            string script = cdListElement(split, 1);
            string commandString = cdListElement(split, 2);

            if (script == "") script = realScript;

            if (cdAttached() && RLVok) {
                llSetMemoryLimit(65536);
                integer commandLoop; string sendCommands = "";
#ifdef LINK_320
                string confCommands = "";
#endif
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

#ifdef LINK_320
                    // confirm RLV commands
                    if (llStringLength(confCommands + fullCmd + ",?") > CHATMSG_MAXLEN) {
                        lmConfirmRLV(script, llGetSubString(confCommands, 0, -2));
                        //debugSay(llGetSubString(confCommands, 0, -2));
                        confCommands = "";
                    }
                    //confCommands += fullCmd + ",";
#endif

                    if (cmd != "clear") {
                        if (param == "n" || param == "add") {
                            integer cmdIndex = cdListElementP(rlvStatus, cmd);

                            if (cmdIndex == NOT_FOUND) { // New restriction add to list and send to viewer
                                rlvStatus += [ cmd, script ];
                                sendCommands += fullCmd + ",";

                                // + symbol confirms that our restriction has been added and it was not in effect from another
                                //   script.  The restriction has now been sent to the viewer and currently we have full control
                                //   of it.
#ifdef LINK_320
                                confCommands += RESTRICTION_NEW + cmd + ",";
#endif
                            }

                            else if (llGetSubString(cmd, -8, -1) == "_except") sendCommands += fullCmd + ",";

                            else { // Duplicate restriction, note but do not send again
                                string scripts = cdListElement(rlvStatus, cmdIndex + 1);
                                list scriptList = cdSplitString(scripts);
                                integer myIndex = cdListElementP(scriptList, script);

                                if (myIndex == NOT_FOUND) {

                                    // ^ symbol confirms our restriction has been added but was already set by another script
                                    //   both scripts must release this restriction before it will be removed.
#ifdef LINK_320
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

                                        // - symbol means we were the only script holding this restriction it has been
                                        //   deleted from the viewer.
#ifdef LINK_320
                                        confCommands += RESTRICTION_REMOVED + cmd + ",";
#endif
                                    }
                                    else {

                                        // ~ symbol means we cleared our restriction but it is still enforced by at least
                                        //   one other script.
#ifdef LINK_320
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

                        for (i = 0; i < llGetListLength(rlvStatus); i = i + 2) {
                            string thisCmd = cdListElement(rlvStatus, i);

                            if (llSubStringIndex(thisCmd, param) != NOT_FOUND) { // Restriction matches clear param
#ifdef LINK_320
                                matches++;
#endif

                                string scripts = cdListElement(rlvStatus, i + 1);
                                list scriptList = cdSplitString(scripts);
                                integer myIndex = cdListElementP(scriptList, script);

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
                                    } else { // Restriction still holds due to other scripts but release for this one
#ifdef LINK_320
                                        held++;
#endif
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
#ifdef LINK_320
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

                if ((sendCommands != "") && (sendCommands != ",")) llOwnerSay(llGetSubString("@" + sendCommands, 0, -2));
#ifdef LINK_320
                if ((confCommands != "") && (confCommands != ",")) lmConfirmRLV(script, llGetSubString(confCommands, 0, -2));
#endif

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
            RLVok = (cdListIntegerElement(split, 1) == 1);
            RLVstarted = 1;
        }
    }
}
