//========================================
// RLV.lsl
//========================================
//
// vim:sw=4 et nowrap:
//
// DATE: 8 December 2013
#include "include/GlobalDefines.lsl"
// Current Controller - or Mistress
key MistressID = NULL_KEY;
key dollID = NULL_KEY;
key carrierID = NULL_KEY;

key rlvTPrequest;

list rlvSources;
list rlvStatus;

string dollName;
string dollType;
string myPath;
string mistressName;
string carrierName;

integer configured;
integer wearLock;

integer permissionsGranted;
integer initState;

integer autoTP;
integer canFly = 1;
integer canSit = 1;
integer canStand = 1;
integer canWear = 1;
integer detachable = 1;
integer helpless;

integer afk;
integer collapsed;
integer quiet;
integer RLVck;
integer RLVok;
integer locked;
integer startup = 1;

integer channel;
integer listenHandle;
integer RLVstarted;
#ifdef SIM_FRIENDLY
integer lowScriptMode;
#endif

string rlvAPIversion;
string userBaseRLVcmd;
string userCollapseRLVcmd;
string scriptName;
string barefeet;
string wearLockRLV;

//========================================
// FUNCTIONS
//========================================

listenerStart() {
    // Get a unique number
    channel = (integer)("0x" + llGetSubString((string)llGenerateKey(),-7,-1)) + 3467;
    listenHandle = llListen(channel, "", "", "");
}

//----------------------------------------
// RLV Initialization Functions
//----------------------------------------
checkRLV()
{ // Run RLV viewer check
    locked = 0;
    if (!RLVok && isAttached) {
        #ifndef DEBUG_BADRLV
        // Setting the above debug flag causes the listener to not be open for the check
        // In effect the same as the viewer having no RLV support as no reply will be heard
        // all other code works as normal.
        llListenControl(listenHandle, 1);
        #endif
        llSetTimerEvent(5.0);
        RLVck = 1;
        
        llOwnerSay("@clear,versionnew=" + (string)channel);
    }
    else postCheckRLV();
}

postCheckRLV()
{ // Handle RLV check result
    llSetTimerEvent(0.0);
    if (RLVok) llOwnerSay("Logged with Community Doll Key and " + rlvAPIversion + " active...");
    else if (isAttached && !RLVok) llOwnerSay("Did not detect an RLV capable viewer, RLV features disabled.");
    
    // Mark RLV check completed
    RLVck = 0;
    
    llListenControl(listenHandle, 1);
    doRLV("Base", "getpathnew=" + (string)channel);
    if (initState == 105) initializeRLV(0);
}

initializeRLV(integer refresh) {
    if (RLVok && isAttached) {
        if (!refresh) {
            llOwnerSay("Enabling RLV mode");
            rlvSources = [];
            rlvStatus = [];
        }
        
        // if Doll is one of the developers... dont lock:
        // prevents inadvertent lock-in during development
        #ifndef DEVELOPER_MODE
        // We lock the key on here - but in the menu system, it appears
        // unlocked and detachable: this is because it can be detached 
        // via the menu. To make the key truly "undetachable", we get
        // rid of the menu item to unlock it
        doRLV("Base", "detach=n,editobj:" + (string)llGetKey() + "=add");  //locks key
        if (!refresh) locked = 1;
        #else
        if (myPath != "") doRLV("Base", "attachallthis_except:" + myPath + "=add,detachallthis_except:" + myPath + "=add");
        if (!refresh) {
            if (!quiet) llSay(0, "Developer Key not locked.");
            else llOwnerSay("Developer key not locked.");
        }
        
        if (myPath != "") {
        #endif
            if (userBaseRLVcmd != "")
                doRLV("UserBase", userBaseRLVcmd);
            
            afkOrCollapse("Collapsed", collapsed);
            afkOrCollapse("AFK", afk);
            
            if (collapsed) doRLV("UserCollapsed", userCollapseRLVcmd);
            else doRLV("UserCollapsed", "clear");
            
            string baseRLV = "accepttp=";
            if (autoTP) baseRLV += "add,";
            else baseRLV += "rem,";
            if (helpless) baseRLV += "tplm=n,tploc=n,";
            else baseRLV += "tplm=y,tploc=y,";
            if (!canFly) baseRLV += "fly=n,";
            else baseRLV += "fly=y,";
            if (!canStand) baseRLV += "unsit=n,";
            else baseRLV += "unsit=y,";
            if (!canSit) baseRLV += "sit=n,";
            else baseRLV += "sit=y,";
            if (!canWear) baseRLV += "unsharedwear=n,unsharedunwear=n,attachallthis:=n,detachallthis:=n";
            else baseRLV += "unsharedwear=y,unsharedunwear=y,attachallthis:=y,detachallthis:=y";
            
            if (wearLock) doRLV("Dress", "unsharedwear=n,unshareunwear=n,attachallthis:=n,detachallthis:=n");
            
            doRLV("Base", baseRLV);
            
            if (afk) afkOrCollapse("AFK", 1);
            else doRLV("AFK", "clear");
            
            if (collapsed) {
                afkOrCollapse("Collapsed", 1);
                if (userCollapseRLVcmd != "") doRLV("UserCollapsed", userCollapseRLVcmd);
            }
            else {
                doRLV("Collapsed", "clear");
                doRLV("UserCollapsed", "clear");
            }
        #ifdef DEVELOPER_MODE
        }
        #endif
        if (!refresh) {
            llMessageLinked(LINK_SET, 350, (string)RLVok + "|" + rlvAPIversion, NULL_KEY);
            lmInitState(105);
        }
    }
    else {
        llListenControl(listenHandle, 0);
    }
    
    if (!refresh) {
        RLVstarted = 1;
        startup = 0;
    }
}

doRLV(string script, string commandString) {
    if (isAttached && RLVok) {
        integer commandLoop; string sendCommands = ""; string confCommands = "";
        integer charLimit = 896;    // Secondlife supports chat messages up to 1024 chars
                                    // here we avoid sending over 896 at a time for safety
                                    // links will be longer due the the prefix.
        integer scriptIndex = llListFindList(rlvSources, [ script ]);
        list commandList = llParseString2List(commandString, [ "," ], []);
        
        if (scriptIndex == -1) {
            scriptIndex = llGetListLength(rlvSources);
            rlvSources += script;
        }
        
        for (commandLoop = 0; commandLoop < llGetListLength(commandList); commandLoop++) {
            string fullCmd; list parts; string param; string cmd;
            
            fullCmd = llStringTrim(llList2String(commandList, commandLoop), STRING_TRIM);
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
        }
        
        if (sendCommands != "") llOwnerSay(llGetSubString("@" + sendCommands, 0, -2));
        if (confCommands != "") {
            lmConfirmRLV(script, llGetSubString(confCommands, 0, -2));
            //debugSay(llGetSubString(confCommands, 0, -2));
        }
        
        //llOwnerSay("RLV Sources " + llList2CSV(rlvSources));
        debugSay(9, "Active RLV: " + llDumpList2String(llList2ListStrided(rlvStatus, 0, -1, 2), "/"));
        integer i;
        for (i = 0; i < llGetListLength(rlvStatus); i += 2) {
            debugSay(9, llList2String(rlvStatus, i) + "\t" + llList2String(rlvStatus, i + 1));
        }
    }
}

rlvTeleportToLandmark(string landmark) {
    rlvTPrequest = llRequestInventoryData(landmark);
}

rlvTeleportToVector(vector global) {
    string locx = (string)llFloor(global.x);
    string locy = (string)llFloor(global.y);
    string locz = (string)llFloor(global.z);
    
    llOwnerSay("Dolly is now teleporting.");
    
    llOwnerSay("@tpto:" + locx + "/" + locy + "/" + locz + "=force");
}

afkOrCollapse(string type, integer set) {
    string RLV;
    
    if (set) {
        RLV = "unsharedwear=n,unsharedunwear=n,attachallthis:=n,detachallthis:=n,";
        RLV += "fly=n,sit=n,unsit=n,tplm=n,tploc=n,temprun=n,alwaysrun=n,sendchat=n,tplure=n,";
        RLV += "sittp=n,standtp=n,shownames=n,showhovertextall=n,redirchat:999=add,rediremote:999=add,";
        RLV += getAutoTPList();
    }
    else RLV = "clear";
    
    doRLV(type, RLV);
}

string getAttachName() {
    return llList2String(llParseString2List("chest|skull|left shoulder|right shoulder|left hand|right hand|left foot|right foot|spine|pelvis|mouth|chin|left ear|right ear|left eyeball|right eyeball|nose|r upper arm|r forearm|l upper arm|l forearm|right hip|r upper leg|r lower leg|left hip|l upper leg|l lower leg|stomach|left pec|right pec|center 2|top right|top|top left|center|bottom left|bottom|bottom right|neck|root", [ "|" ], []), llGetAttached() - 1);
}

// Only useful if @tplure and @accepttp are off and denied by default...
string getAutoTPList() {
    list allow = [ AGENT_CHRISTINA_HALPIN, AGENT_GREIGHIGHLAND_RESIDENT, AGENT_MAYSTONE_RESIDENT, AGENT_SILKY_MESMERISER ];
    if (MistressList != []) allow += MistressList;
    if (carrierID != NULL_KEY) allow += carrierID;
    integer loop; key userID;
    string RLV = "tplure:" + llDumpList2String(allow, "=add,tplure:") + "=add,";
    RLV += "accepttp:" + llDumpList2String(allow, "=add,accepttp:") + "=add";
    return RLV;
}

//========================================
// STATES
//========================================

default {
    state_entry() {
        dollID = llGetOwner();
        scriptName = llGetScriptName();
        lmScriptReset();
        
        // RLV.lsl memory usage varies very rapidly memory scaling is not
        // an option here.
        llSetMemoryLimit(64 * 1024);
    }
    
    on_rez(integer start) {
        RLVstarted = 0;
        RLVok = 0;
        locked = 0;
        startup = 0;
    }
    
    //----------------------------------------
    // TIMER
    //----------------------------------------
    timer() {
        if (RLVck != 0 && RLVck <= 6) {
            if (isAttached && RLVck != 6) llOwnerSay("@clear,versionnew=" + (string)channel);
            llSetTimerEvent(5.0 * RLVck++);
        } else if (RLVck != 0) {
            postCheckRLV();
        }
    }
    
    dataserver(key query_id, string data) {
        if (query_id == rlvTPrequest) {
            vector loc = llGetRegionCorner() + (vector)data;
            rlvTeleportToVector(loc);
        }
    }
    
    //----------------------------------------
    // LISTEN
    //----------------------------------------

    listen(integer chan, string name, key id, string msg) {
        if (chan == channel) {
            debugSay(5, "RLV Reply: " + msg);
            if (!RLVok && llGetSubString(msg, 0, 13) == "RestrainedLove") {
                RLVok = 1;
                rlvAPIversion = llStringTrim(msg, STRING_TRIM);
                postCheckRLV();
            }
            else if (RLVok && llGetSubString(msg, 0, 13) != "RestrainedLove") {
                myPath = msg;
                initializeRLV(1);
                llListenControl(listenHandle, 0);
            }
        }
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
        
        
        if (code == 102) {
            configured = 1;
        }
        else if (code == 104) {
            if (llList2String(split, 0) != "Start") return;
            dollID = llGetOwner();
            dollName = llGetDisplayName(dollID);
            listenerStart();
            checkRLV();
            initState = code;
            lmInitState(104);
        }
        else if (code == 105) {
            if (llList2String(split, 0) != "Start") return;
            initState = code;
            if (!startup) checkRLV();
            else if (RLVck == 0) initializeRLV(0);
            lmInitState(105);
        }
        else if (code == 106) {
            if (id == NULL_KEY && !detachable && !locked) {
                // Undetachable key with controller is detached while RLV lock
                // is not available inform Mistress.
                // We send no message if the key is RLV locked as RLV will reattach
                // automatically this prevents neusance messages when defaultwear is
                // permitted.
                llMessageLinked(LINK_THIS, 15, dollName + " has detached their key while undetachable.", scriptkey);
            }
        }
        else if (code == 135) {
            memReport();
        }
        else if (code == 300) { // RLV Config
            string script = llList2String(split, 0);
            string name = llList2String(split, 1);
            split = llList2List(split, 2, -1);
            string value = llList2String(split, 0);
            
            if (script != SCRIPT_NAME) {
                if (llListFindList([ "afk", "autoTP", "canFly", "canSit", "canStand", "canWear", "collapsed", "helpless" ], [ name ]) != -1) {
                         if (name == "autoTP")                       autoTP = (integer)value;
                    else if (name == "afk")                             afk = (integer)value;
                    else if (name == "collapsed")                 collapsed = (integer)value;
                    else if (name == "canFly")                       canFly = (integer)value;
                    else if (name == "canSit")                       canSit = (integer)value;
                    else if (name == "canStand")                   canStand = (integer)value;
                    else if (name == "canWear")                     canWear = (integer)value;
                    else if (name == "helpless")                   helpless = (integer)value;
                    
                    if (RLVstarted) initializeRLV(1);
                } else {            
                         if (name == "detachable")               detachable = (integer)value;
                    else if (name == "barefeet")                   barefeet = value;
                    else if (name == "dollType")                   dollType = value;
                    else if (name == "MistressID")            MistressList += (key)value;
                    else if (name == "MistressList")           MistressList = split;
                    else if (name == "mistressName")           mistressName = value;
                    else if (name == "quiet")                         quiet = (integer)value;
                    else if (name == "userBaseRLVcmd") {
                        if (userBaseRLVcmd == "") userBaseRLVcmd = value;
                        else userBaseRLVcmd += "," +value;
                    }
                    else if (name == "userCollapseRLVcmd") {
                        if (userCollapseRLVcmd == "") userCollapseRLVcmd = value;
                        else userCollapseRLVcmd += "," +value;
                    }
                }
            }
        }
        else if (code == 305) { // RLV Commands
            string script = llList2String(split, 0);
            string cmd = llList2String(split, 1);
            split = llList2List(split, 2, -1);
            
            if (cmd == "setAFK") {
                afk = llList2Integer(split, 0);
                integer auto = llList2Integer(split, 1);
                string rate = llList2String(split, 2);
                string mins = llList2String(split, 3);
                
                if (afk) {
                    afkOrCollapse("AFK", 1);
                    
                    if (auto)
                        llOwnerSay("Automatically entering AFK mode. Wind down rate has slowed to " + rate + "x however and movements and abilities are restricted.");
                    else
                        llOwnerSay("You are now away from keyboard (AFK). Wind down rate has slowed to " + rate + "x however and movements and abilities are restricted.");
                } else {
                    doRLV("AFK", "clear");
                    llOwnerSay("You are now no longer away from keyboard (AFK). Movements are unrestricted and winding down proceeds at normal rate.");
                }
                llOwnerSay("You have " + mins + " minutes of life remaning.");
            }
            else if (cmd == "collapse") {
                llMessageLinked(LINK_SET, 15, dollName + " has collapsed at this location: " + wwGetSLUrl(), scriptkey);
                
                // Turn everything off: Dolly is down
                afkOrCollapse("Collapsed", 1);
                // Add user defined restrictions
                if (userCollapseRLVcmd != "")
                    doRLV("UserCollapsed", userCollapseRLVcmd);
            }
            else if (cmd == "uncollapse") {
                // Clear collapse restrictions
                doRLV("Collapsed", "clear");
                // Clear user collapse restrictions
                doRLV("UserCollapsed", "clear");
            }
#ifdef ADULT_MODE
            else if (llGetSubString(cmd, 0, 4) == "strip") {
                string stripped;
                if (cmd == "stripTop") {
                    stripped = "top";
                    doRLV("Dress", "detach:stomach=force,detach:left shoulder=force,detach:right shoulder=force,detach:left hand=force,detach:right hand=force,detach:r upper arm=force,detach:r forearm=force,detach:l upper arm=force,detach:l forearm=force,detach:chest=force,detach:left pec=force,detach:right pec=force,remoutfit:gloves=force,remoutfit:jacket=force,remoutfit:shirt=force");
                }
                else if (cmd == "stripBra") {
                    stripped = "bra";
                    doRLV("Dress", "remoutfit=y,remattach=y,remoutfit:undershirt=force");
                }
                else if (cmd == "stripBottom") {
                    stripped = "bottoms";
                    doRLV("Dress", "detach:chin=force,detach:r upper leg=force,detach:r lower leg=force,detach:l upper leg=force,detach:l lower leg=force,detach:pelvis=force,detach:right hip=force,detach:left hip=force,remoutfit:pants=force,remoutfit:skirt=force");
                }
                else if (cmd == "stripPanties") {
                    stripped = "panties";
                    doRLV("Dress", "remoutfit:underpants=force");
                }
                else if (cmd == "stripShoes") {
                    stripped = "shoes";
                    string attachFeet;
                    if (barefeet != "") attachFeet = "attachallover:" + barefeet + "=force,";
                    doRLV("Dress", "detach:l lower leg=force,detach:r lower leg=force,detach:right foot=force,detach:left foot=force,remoutfit:shoes=force,remoutfit:socks=force," + attachFeet);
                }
                lmInternalCommand("wearLock", (string)(wearLock = 1), NULL_KEY);
                if (!quiet) llSay(0, "The dolly " + dollName + " has her " + stripped + " stripped off her and may not redress for " + (string)llRound(WEAR_LOCK_TIME / 60.0) + " minutes.  (Timer resets if dolly is stripped again)");
                else llOwnerSay("You have had your " + stripped + " stripped off you and may not redress for " + (string)llRound(WEAR_LOCK_TIME / 60.0) + " minutes.");
            }
#endif
            else if (cmd == "carry") {
                carrierID = id;
                carrierName = llList2String(split, 0);
                
                // No TP allowed for Doll except rescuers
                doRLV("Carry", "tplm=n,tploc=n,accepttp=rem,tplure=n,showinv=n," + getAutoTPList());
            }
            else if (cmd == "uncarry") {
                // Clear carry restrictions
                doRLV("Carry", "clear");

                carrierID = NULL_KEY;
                carrierName = "";
                
                string mid = " being carried by " + llList2String(split, 0) + " and ";
                string end = " been set down";
                if (!quiet) llSay(0, dollName + " was" + mid + "has" + end);
                else llOwnerSay("You were" + mid + "have" + end);
            }
            else if (cmd == "setPose") doRLV("Pose", "attachallthis:=n,chatnormal=n,edit=n,fartouch=n,fly=n,rez=n,showinv=n,sit=n," +                                                      "touchattachother=n,tplm=n,tploc=n,unsit=n,unsharedwear=n");
            else if (cmd == "doUnpose") doRLV("Pose", "clear");
            else if (cmd == "TP") {
                string lm = llList2String(split, 0);
                llRegionSayTo(id, 0, "Teleporting dolly " + dollName + " to  landmark " + lm + ".");
                rlvTeleportToLandmark(lm);
            }
            else if (cmd == "detach") {
                if (RLVok) llOwnerSay("@clear,detachme=force");
                else llDetachFromAvatar();
            }
            else if (cmd == "wearLock") {
                wearLock = llList2Integer(split, 0);
                if (wearLock) doRLV("Dress", "unsharedwear=n,unsharedunwear=n,attachallthis:=n,detachallthis:=n");
                else doRLV("Dress", "clear");
            }
        }
        else if (code == 315) {
            string script = llList2String(split, 0);
            string cmd = llList2String(split, 1);
            split = llList2List(split, 2, -1);
            
            doRLV(script, cmd);
        }
    }
}
