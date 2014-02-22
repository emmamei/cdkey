//========================================
// StatusRLV.lsl
//========================================
//
// vim:sw=4 et nowrap:
//
// DATE: 8 December 2013
#include "include/GlobalDefines.lsl"
//#define DEBUG_BADRLV 1
//
// As of 23 January 2014 this script is now state tracking only
// core RLV command generators are now part of the Avatar script
// thus we keep this script lightweight with plenty of heap room
// for it's runtime data needs.

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
        llSetMemoryLimit(65536);
    }
    
    //----------------------------------------
    // LINK_MESSAGE
    //----------------------------------------

    link_message(integer sender, integer code, string data, key id) {
        list split = llParseStringKeepNulls(data, [ "|" ], []);
        
        // valid numbers:
        //    101: Initial configuration from Preferences
        //    102: End of Preferences notification message
        //    104: Global startup trigger from start.lsl
        //    105: Global on_rez trigger
        //    300: Configuration messages from other scripts
        //    305: Internal RLV Commands
        //    315: Raw RLV Commands
        //
        // 300 cmds:
        //    * MistressID
        //    * hasController
        //    * autoTP
        //    * helpless
        //    * canFly
        //    * canStand
        //    * canSit
        //    * canWear
        //    * canUnwear
        //    * detachable
        //    * visible
        //    * signOn
        //
        // 305 cmds:
        //    * autoSetAFK
        //    * setAFK
        //    * unsetAFK
        //    * collapse
        //    * restore
        //    * stripTop
        //    * stripBra
        //    * stripBottom
        //    * stripPanties
        //    * stripShoes
        //    * carried
        
        if (code == 104 || code == 105) {
            string script = llList2String(split, 0);
            if (script != "Start") return;
            
            if (initState == code) lmInitState(initState++);
        }
        if (code == 110) {
            initState = 105;
        }
        else if (code == 135) {
            float delay = llList2Float(split, 1);
            memReport(delay);
        }
        else if (code == 300) {
            string name = llList2String(split, 1);
            string value = llList2String(split, 2);
            
            if (name == "debugLevel")                    debugLevel = (integer)value;
        }
        else if (code == 315) {
            string realScript = llList2String(split, 0);
            string script = llList2String(split, 1);
            string commandString = llList2String(split, 2);
            
            if (script == "") script = realScript;
            
            if (isAttached && RLVok) {
                integer commandLoop; string sendCommands = ""; string confCommands = "";
                integer charLimit = 896;    // Secondlife supports chat messages up to 1024 chars
                                            // here we avoid sending over 896 at a time for safety
                                            // links will be longer due the the prefix.
                integer scriptIndex = llListFindList(rlvSources, [ script ]);
                
                if (scriptIndex == -1) {
                    scriptIndex = llGetListLength(rlvSources);
                    rlvSources += script;
                }
                
                do {
                    string fullCmd; list parts; string param; string cmd;
                    
                    integer nextComma = llSubStringIndex(commandString, ",");
                    if (nextComma == -1) nextComma = llStringLength(commandString);
                    
                    fullCmd = llStringTrim(llGetSubString(commandString, 0, nextComma - 1), STRING_TRIM);
                    commandString = llDeleteSubString(commandString, 0, nextComma);
                    
                    parts = llParseString2List(fullCmd, [ "=" ], []);
                    param = llList2String(parts, 1);
                    cmd = llList2String(parts, 0);
                    
                    if (llStringLength(sendCommands + fullCmd + ",?") > charLimit) {
                        llOwnerSay(llGetSubString("@" + sendCommands, 0, -2));
                        sendCommands = "";
                    }
                    //sendCommands += fullCmd + ",";
                    if (llStringLength(confCommands + fullCmd + ",?") > charLimit) {
                        lmConfirmRLV(script, llGetSubString(confCommands, 0, -2));
                        //debugSay(llGetSubString(confCommands, 0, -2));
                        confCommands = "";
                    }
                    //confCommands += fullCmd + ",";
                    
                    if (cmd != "clear") {
                        if (param == "n" || param == "add") {
                            integer cmdIndex = llListFindList(rlvStatus, [ cmd ]);
                            if (cmdIndex == -1 ) { // New restriction add to list and send to viewer
                                rlvStatus += [ cmd, script ];
                                sendCommands += fullCmd + ",";
                                // + symbol confirms that our restriction has been added and it was not in effect from another
                                //   script.  The restriction has now been sent to the viewer and currently we have full control
                                //   of it.
                                confCommands += "+" + cmd + ",";
                            }
                            else if (llGetSubString(cmd, -8, -1) == "_except") sendCommands += fullCmd + ",";
                            else { // Duplicate restriction, note but do not send again
                                string scripts = llList2String(rlvStatus, cmdIndex + 1);
                                list scriptList = llParseString2List(scripts, [ "," ], []);
                                integer myIndex = llListFindList(scriptList, [ script ]);
                                if (myIndex == -1) {
                                    // ^ symbol confirms our restriction has been added but was already set by another script
                                    //   both scripts must release this restriction before it will be removed.
                                    confCommands += "^" + cmd + ",";
                                    scriptList = llListSort(scriptList + [ script ], 1, 1);
                                    rlvStatus = llListReplaceList(rlvStatus, [ cmd, llDumpList2String(scriptList, ",") ],
                                                                  cmdIndex, cmdIndex + 1);
                                }
                            }
                        }
                        else if (param == "y" || param == "rem") {
                            integer cmdIndex = llListFindList(rlvStatus, [ cmd ]);
                            if (cmdIndex != -1) { // Restriction does exist from one or more scripts
                                string scripts = llList2String(rlvStatus, cmdIndex + 1);
                                list scriptList = llParseString2List(scripts, [ "," ], []);
                                integer myIndex = llListFindList(scriptList, [ script ]);
                                if (myIndex != -1) { // This script is one of the restriction issuers clear it
                                    scriptList = llDeleteSubList(scriptList, myIndex, myIndex);
                                    if (scriptList == []) { // All released delete old record and send to viewer
                                        rlvStatus = llDeleteSubList(rlvStatus, cmdIndex, cmdIndex + 1);
                                        sendCommands += fullCmd + ",";
                                        // - symbol means we were the only script holding this restriction it has been
                                        //   deleted from the viewer.
                                        confCommands += "-" + cmd + ",";
                                    }
                                    else {
                                        // ~ symbol means we cleared our restriction but it is still enforced by at least
                                        //   one other script.
                                        confCommands += "~" + cmd + ",";
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
                    else if (cmd == "clear") {
                        integer i; integer matches; integer reduced; integer cleared; integer held;
                        for (i = 0; i < llGetListLength(rlvStatus); i = i + 2) {
                            string thisCmd = llList2String(rlvStatus, i);
                            if (llSubStringIndex(thisCmd, param) != -1) { // Restriction matches clear param
                                matches++;
                                string scripts = llList2String(rlvStatus, i + 1);
                                list scriptList = llParseString2List(scripts, [ "," ], []);
                                integer myIndex = llListFindList(scriptList, [ script ]);
                                if (myIndex != -1) { // This script is one of the restriction issuers clear it
                                    scriptList = llDeleteSubList(scriptList, myIndex, myIndex);
                                    reduced++;
                                    if (scriptList == []) { // All released delete old record and send to viewer
                                        rlvStatus = llDeleteSubList(rlvStatus, i, i + 1);
                                        i = i - 2;
                                        cleared++;
                                        if (llStringLength(sendCommands + thisCmd + "=y,") > charLimit) {
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
                            if (llStringLength(confCommands + clrCmd + ",") > charLimit) {
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
                
                //llOwnerSay("RLV Sources " + llList2CSV(rlvSources));
                debugSay(9, "DEBUG-RLV", "Active RLV: " + llDumpList2String(llList2ListStrided(rlvStatus, 0, -1, 2), "/"));
                integer i;
                for (i = 0; i < llGetListLength(rlvStatus); i += 2) {
                    debugSay(9, "DEBUG-RLV", llList2String(rlvStatus, i) + "\t" + llList2String(rlvStatus, i + 1));
                }
            }
        }
        else if (code == 350) {
            RLVok = llList2Integer(split, 1);
            RLVstarted = 1;
        }
    }
}
