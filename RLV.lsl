// RLV.lsl
//
// vim:sw=4 et nowrap:
//
// DATE: 8 December 2013
                  
//========================================
// VARIABLES
//========================================
// Keys of important people in life of the Key:
key MasterBuilder = "42c7aaec-38bc-4b0c-94dd-ae562eb67e6d";   // Christina Halpin
key  MasterWinder = "64d26535-f390-4dc4-a371-a712b946daf8";   // GreigHighland
key        DevOne = "c5e11d0a-694f-46cc-864b-e42340890934";   // MayStone
key        DevTwo = "2fff40f0-ea4a-4b52-abb8-d4bf6b1c98c9";   // Silky Mesmeriser

// Current Controller - or Mistress
key MistressID = MasterBuilder;
key dollID;
key carrierID;

key rlvTPrequest;

list rescuerList = [ MasterBuilder, MasterWinder ];
list developerList = [ DevOne, DevTwo ];

list rlvSources;
list rlvStatus;

string dollName;

integer hasController;

integer configured;
float wearLockExpire;
float wearLockTime = 300.0;

integer permissionsGranted;
integer controlLock;

integer quiet;

integer afk;
integer signOn;
integer autoTP;
integer canFly = 1;
integer canSit = 1;
integer canStand = 1;
integer canWear = 1;
integer canUnwear = 1;
integer detachable = 1;
integer helpless;
integer locked;

integer visible = 1;

integer carried;
integer collapsed;
integer posed;

integer RLVck;
integer RLVok;
integer ATHok;

integer channel;
integer listenHandle;
integer RLVstarted;

string carrierName;
string rlvAPIversion;
string addBaseRLVcmd;
string addCollapseRLVcmd;
string addRestoreRLVcmd;
string scriptName;
string dollType;
string barefeet;
string wearLockRLV;
string myPath;

integer devKey() {
    if (dollID != llGetOwner()) dollID = llGetOwner();
    return llListFindList(developerList, [ dollID ]) != -1;
}

//========================================
// FUNCTIONS
//========================================

// This code assumes a human-generated config file
processConfiguration(string name, list values) {
    //----------------------------------------
    // Assign values to program variables

    if (name == "helpless dolly") {
        helpless = llList2Integer(values, 0);
        if (helpless) doRLV(scriptName, "tplm=n,tploc=n");
        else doRLV(scriptName, "tplm=y,tploc=y");
    }
    else if (name == "barefeet path") {
        barefeet = llList2String(values, 0);
    }
    else if (name == "controller") {
        MistressID = llList2Key(values, 0);
        hasController = 1;
    }
    else if (name == "auto tp") {
        autoTP = llList2Integer(values, 0);
        if (autoTP) doRLV(scriptName, "accepttp=add");
        else doRLV(scriptName, "accepttp=rem");
    }
    else if (name == "detachable") {
        detachable = llList2Integer(values, 0);
    }
    else if (name == "can fly") {
        canFly = llList2Integer(values, 0);
        if (canFly) doRLV(scriptName, "fly=y");
        else doRLV(scriptName, "fly=n");
    }
    else if (name == "can sit") {
        canSit = llList2Integer(values, 0);
        if (canSit) doRLV(scriptName, "sit=y");
        else doRLV(scriptName, "sit=n");
    }
    else if (name == "can stand") {
        canStand = llList2Integer(values, 0);
        if (canStand) doRLV(scriptName, "unsit=y");
        else doRLV(scriptName, "unsit=n");
    }
    else if (name == "user startup rlv") {
        string rlv = llList2String(values, 0);
        if (llGetSubString(rlv, 0, 0) == "@") rlv = llGetSubString(rlv, 1, -1);
        
        if (addBaseRLVcmd == "") addBaseRLVcmd = rlv;
        else addBaseRLVcmd += "," + rlv;
        
        doRLV(scriptName, addBaseRLVcmd);
    }
    else if (name == "user collapse rlv") {
        string rlv = llList2String(values, 0);
        if (llGetSubString(rlv, 0, 0) == "@") rlv = llGetSubString(rlv, 1, -1);
        
        if (addCollapseRLVcmd == "") addCollapseRLVcmd = rlv;
        else addCollapseRLVcmd += "," + rlv;
    }
    else if (name == "user restore rlv") {
        string rlv = llList2String(values, 0);
        if (llGetSubString(rlv, 0, 0) == "@") rlv = llGetSubString(rlv, 1, -1);
        
        if (addRestoreRLVcmd == "") addRestoreRLVcmd = rlv;
        else addRestoreRLVcmd += "," + rlv;
    }
    else if (name == "quiet key") {
        quiet = llList2Integer(values, 0);
    }
}

string formatFloat(float val, integer dp)
{
    string out = "ERROR";
    if (dp == 0) {
        out = (string)llRound(val);
    } else if (dp > 0 && dp <= 6) {
        val = llRound(val * llPow(10.0, dp)) / llPow(10.0, dp);
        out = llGetSubString((string)val, 0, -7 + dp);
    }
    return out;
}

memReport() {
    float free_memory = (float)llGetFreeMemory();
    float used_memory = (float)llGetUsedMemory();
    
    if (devKey()) llOwnerSay(llGetScriptName() + ": Memory " + formatFloat(used_memory/1024.0, 2) + "/" + (string)llRound((used_memory + free_memory)/1024.0) + "kB, " + formatFloat(free_memory/1024.0, 2) + " kB free");
}

listenerStart() {
    // Get a unique number
    channel = (integer)("0x" + llGetSubString((string)llGenerateKey(),-7,-1)) + 3467;
    listenHandle = llListen(channel, "", "", "");
}

//----------------------------------------
// RLV Initialization Functions
//----------------------------------------
checkRLV() { // Run RLV viewer check
    locked = 0;
    ATHok = llGetAttached() == ATTACH_BACK;
    if (ATHok) {
        if (RLVck == 0) {
            llListenControl(listenHandle, 1);
            llSetTimerEvent(5);
            rlvAPIversion = "";
            RLVck = 1;
        }
        
        llOwnerSay("@clear,versionnew=" + (string)channel);
    } else postCheckRLV();
}

postCheckRLV() { // Handle RLV check result
    if (RLVok) llOwnerSay("Logged with Community Doll Key and " + rlvAPIversion + " active...");
    else if (ATHok && !RLVok) llOwnerSay("Did not detect an RLV capable viewer, RLV features disabled.");
    
    // Mark RLV check completed
    RLVck = 0;
    
    if (configured) initializeRLV();
    llMessageLinked(LINK_SET, 103, scriptName, NULL_KEY);
}

initializeRLV() {
    if (RLVok && ATHok) {
        llOwnerSay("Enabling RLV mode");
        
        rlvSources = [];
        rlvStatus = [];
        
        doRLV("UserBase", addBaseRLVcmd);
        
        afkOrCollapse("Collapsed", collapsed);
        afkOrCollapse("AFK", afk);

        if (collapsed)  doRLV("UserCollapsed", addCollapseRLVcmd);
        else            doRLV("UserCollapsed", addRestoreRLVcmd);
    
        if ( autoTP)                           doRLV("Base", "accepttp=add");
        if ( helpless)                         doRLV("Base", "tplm=n,tploc=n");
        if (!canFly)                           doRLV("Base", "fly=n");
        if (!canStand)                         doRLV("Base", "unsit=n");
        if (!canSit)                           doRLV("Base", "sit=n");
        if (!canWear   || wearLockExpire > 0)  doRLV("Base", "addoutfit=n,addattach=n");
        if (!canUnwear || wearLockExpire > 0)  doRLV("Base", "remoutfit=n,remattach=n");

        // if Doll is one of the developers... dont lock:
        // prevents inadvertent lock-in during development

        if (!devKey()) {
            // We lock the key on here - but in the menu system, it appears
            // unlocked and detachable: this is because it can be detached
            // via the menu. To make the key truly "undetachable", we get
            // rid of the menu item to unlock it
            doRLV("Base", "detach=n,editobj:" + (string)llGetKey() + "=add");  //locks key
        } else {
            if (!quiet) llSay(0, "Developer Key not locked.");
            else llOwnerSay("Developer key not locked.");
        }
    }
    
    RLVstarted = 1;
    llSetTimerEvent(1);
    llMessageLinked(LINK_SET, 350, (string)RLVok + "|" + rlvAPIversion, NULL_KEY);
}

allowRescue(string script) {
    list allow = [ MistressID, MasterBuilder, MasterWinder, DevOne, DevTwo ];
    integer index;
    integer allowLen = llGetListLength(allow);

    for (index = 0; index < allowLen; index++) autoTPAllowed(script, llList2Key(allow, index));
}

// Only useful if @tplure and @accepttp are off and denied by default...
autoTPAllowed(string script, key userID) {
    doRLV(script, "tplure:"   + (string) userID + "=add,accepttp:" + (string) userID + "=add");
}

doRLV(string script, string commandString) {
    if (RLVok) {
        integer commandLoop; list sendCommands;
        integer scriptIndex = llListFindList(rlvSources, [ script ]);
        list commandList = llParseString2List(commandString, [ "," ], []);
        integer commandListLen = llGetListLength(commandList);
        
        if (scriptIndex == -1) {
            scriptIndex = llGetListLength(rlvSources);
            rlvSources += script;
        }
        
        for (commandLoop = 0; commandLoop < commandListLen; commandLoop++) {
            string fullCmd; list parts; string param; string cmd;
            
            fullCmd = llStringTrim(llList2String(commandList, commandLoop), STRING_TRIM);
            parts = llParseString2List(fullCmd, [ "=" ], []);
            param = llList2String(parts, 1);
            cmd = llList2String(parts, 0);
            
            if (cmd != "clear") {
                if (param == "n" || param == "add") {
                    integer cmdIndex = llListFindList(rlvStatus, [ cmd ]);
                    if (cmdIndex == -1) { // New restriction add to list and send to viewer
                        rlvStatus += [ cmd, script ];
                        sendCommands += fullCmd;
                        llMessageLinked(LINK_SET, 320, script + "|" + fullCmd, NULL_KEY);
                    }
                    else { // Duplicate restriction, note but do not send again
                        string scripts = llList2String(rlvStatus, cmdIndex + 1);
                        list scriptList = llParseString2List(scripts, [ "|" ], []);
                        integer myIndex = llListFindList(scriptList, [ script ]);

                        if (myIndex == -1) {
                            scriptList = llListSort(scriptList + [ script ], 1, 1);
                            rlvStatus = llListReplaceList(rlvStatus, [ cmd, llDumpList2String(scriptList, "|") ],
                                                          cmdIndex, cmdIndex + 1);
                        }
                    }
                }
                else if (param == "y" || param == "rem") {
                    integer cmdIndex = llListFindList(rlvStatus, [ cmd ]);

                    if (cmdIndex != -1) { // Restriction does exist from one or more scripts
                        string scripts = llList2String(rlvStatus, cmdIndex + 1);
                        list scriptList = llParseString2List(scripts, [ "|" ], []);
                        integer myIndex = llListFindList(scriptList, [ script ]);

                        if (myIndex != -1) { // This script is one of the restriction issuers clear it
                            scriptList = llDeleteSubList(scriptList, myIndex, myIndex);

                            if (scriptList == []) { // All released delete old record and send to viewer
                                rlvStatus = llDeleteSubList(rlvStatus, cmdIndex, cmdIndex + 1);
                                sendCommands += fullCmd;
                                llMessageLinked(LINK_SET, 320, script + "|" + fullCmd, NULL_KEY);
                            } else { // Restriction still holds due to other scripts but release for this one
                                rlvStatus = llListReplaceList(rlvStatus, [ cmd, llDumpList2String(scriptList, "|") ],
                                                              cmdIndex, cmdIndex + 1);
                            }
                        }
                    }
                }
                else {
                    // Oneshot command
                    sendCommands += fullCmd;
                    llMessageLinked(LINK_SET, 320, script + "|" + fullCmd, NULL_KEY);
                }
            }
            else if (cmd == "clear") {
                integer i;

                for (i = 0; i < llGetListLength(rlvStatus); i = i + 2) {
                    string thisCmd = llList2String(rlvStatus, i);

                    if (llSubStringIndex(thisCmd, param) != -1) { // Restriction matches clear param
                        string scripts = llList2String(rlvStatus, i + 1);
                        list scriptList = llParseString2List(scripts, [ "|" ], []);
                        integer myIndex = llListFindList(scriptList, [ script ]);

                        if (myIndex != -1) { // This script is one of the restriction issuers clear it
                            scriptList = llDeleteSubList(scriptList, myIndex, myIndex);
                            if (scriptList == []) { // All released delete old record and send to viewer
                                rlvStatus = llDeleteSubList(rlvStatus, i, i + 1);
                                i = i - 2;
                                sendCommands += [ thisCmd + "=rem" ];
                                if (llGetListLength(sendCommands) >= 10) {
                                    llOwnerSay("@" + llDumpList2String(sendCommands, ","));
                                    sendCommands = [];
                                }
                                llMessageLinked(LINK_SET, 320, script + "|" + thisCmd + "=rem|" + fullCmd, NULL_KEY);
                            } else { // Restriction still holds due to other scripts but release for this one
                                rlvStatus = llListReplaceList(rlvStatus, [ thisCmd, llDumpList2String(scriptList, "|") ],
                                                              i, i + 1);
                            }
                        }
                    }
                }
            }
            if (llGetListLength(sendCommands) >= 10) {
                llOwnerSay("@" + llDumpList2String(sendCommands, ","));
                sendCommands = [];
            }
        }
        
        if (llGetListLength(sendCommands) > 0)
            llOwnerSay("@" + llDumpList2String(sendCommands, ","));
        
        //llOwnerSay("RLV Sources " + llList2CSV(rlvSources));
        //llOwnerSay("RLV Status " + llDumpList2String(llList2ListStrided(rlvStatus, 0, -1, 2), "/"));
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
    if (set) {

        lockAttachments(type, set);
        
        doRLV(type, "fly=n,sit=n,unsit=n,tplm=n,tploc=n,tplure=n,standtp=n,sittp=n," +
                    "addoutfit=n,addattach=n,remoutfit=n,remattach=n," +
                    "temprun=n,alwaysrun=n,sendchat=n,showhovertextall=n," +
                    "redirchat:999=add,rediremote:999=add");
                    
        allowRescue(type);
        if (carried) autoTPAllowed(type, carrierID);
    }
}

lockAttachments(string type, integer set) {
    list points = [ "spine", "chest", "skull", "left shoulder", "right shoulder", "left hand",
                    "right hand", "left foot", "right foot", "pelvis", "mouth", "chin", 
                    "left ear", "right ear", "left eyeball", "right eyeball", "nose",
                    "r upper arm", "r forearm", "l upper arm", "l forearm", "right hip",
                    "r upper leg", "r lower leg", "left hip", "l upper leg", "l lower leg",
                    "stomach", "left pec", "right pec", "center 2", "top right", "top",
                    "top left", "center", "bottom left", "bottom", "bottom right", "neck", "root" ];

    if (set) {
        // Skip locking spine on dev keys, this is for the same reason as we skip the @detach=n and
        // @editobj restrictions.
        if (!devKey()) doRLV(type, "detach:" + llDumpList2String(points, "=n,detach:") + "=n");
        else doRLV(type, "detach:" + llDumpList2String(llList2List(points, 1, -1), "=n,detach:") + "=n");
    }
}

//========================================
// STATES
//========================================

default {
    state_entry() {
    dollID = llGetOwner();
    scriptName = llGetScriptName();
    llMessageLinked(LINK_SET, 999, llGetScriptName(), NULL_KEY);
    }
    
    //----------------------------------------
    // TIMER
    //----------------------------------------
    timer() {
        if (RLVck != 0 && RLVck <= 6) {
            if (RLVck == 1) llMessageLinked(LINK_SET, 103, llGetScriptName(), NULL_KEY);
            RLVck++;
            if (ATHok && RLVck != 6) llOwnerSay("@clear,versionnew=" + (string)channel);
        } else if (RLVck != 0) {
            postCheckRLV();
        } else {
            if (wearLockExpire > 0.0) {
                wearLockExpire -= llGetAndResetTime();
                if (wearLockExpire <= 0.0) {
                    doRLV("Dress", "clear");
                    wearLockExpire = 0.0;
                }
            }
        }
    }
    
    //----------------------------------------
    // DATASERVER
    //----------------------------------------
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
            if (RLVck != 0) {
                RLVok = 1;
                rlvAPIversion = llStringTrim(msg, STRING_TRIM);
                postCheckRLV();
            } else {
                list split = llParseString2List(msg, [ "|" ], []);
                integer i;
                
                for (i = 0; i < llGetListLength(split); i++) {
                    string path = llStringTrim(llToLower(llList2String(split, 0)), STRING_TRIM);
                    if (llSubStringIndex(path, "key") != -1) myPath = llList2String(split, 0);
                }
            }
            
            llListenControl(listenHandle, 0);
        }
    }
    
    //----------------------------------------
    // LINK_MESSAGE
    //----------------------------------------
    link_message(integer sender, integer num, string data, key id) {
        integer index;
        string parameter;
        list parameterList = llParseString2List(data, [ "|" ], []);

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
        
        if (num == 16)
            dollType = llList2String(parameterList, 0);
        else if (num == 101) {
            if (!configured)
                processConfiguration(llList2String(parameterList, 0), llList2List(parameterList, 1, -1));
        }
        else if (num == 102) {
            configured = 1;
            if (!RLVck && !RLVstarted) initializeRLV();
        }
        else if (num == 104) {
            dollID = llGetOwner();
            dollName = llGetDisplayName(dollID);
            
            listenerStart();
            checkRLV();
        }
        else if (num == 105) {
            locked = 0;
            RLVok = 0;
            ATHok = llGetAttached() == ATTACH_BACK;
            RLVstarted = 0;
            llResetTime();
            
            checkRLV();
        }
        else if (num == 106) {
            if (id == NULL_KEY && hasController && !detachable && !locked) {
                // Undetachable key with controller is detached while RLV lock
                // is not available inform Mistress.
                // We send no message if the key is RLV locked as RLV will reattach
                // automatically this prevents neusance messages when defaultwear is
                // permitted.
                llMessageLinked(LINK_SET, 11, dollName + " has detached their key while undetachable.", MistressID);
            }
        }
        else if (num == 135) {
            memReport();
        }
        else if (num == 300) { // RLV Config
            string name = llList2String(parameterList, 0);
            if (name == "MistressID") {
                MistressID = llList2Key(parameterList, 1);
            }
            else if (name == "hasController") {
                hasController = llList2Integer(parameterList, 1);
            }
            else if (name == "autoTP") {
                autoTP = llList2Integer(parameterList, 1);
                if (autoTP) {
                    llOwnerSay("You will now be automatically teleported.");
                    doRLV("Base", "accepttp=add");
                }
                else doRLV("Base", "accepttp=rem");
            }
            else if (name == "helpless") {
                helpless = llList2Integer(parameterList, 1);
                if (helpless) {
                    llOwnerSay("You can no longer teleport yourself. You are a Helpless Dolly.");
                    doRLV("Base", "tplm=n,tploc=n");
                }
                else doRLV("Base", "tplm=y,tploc=y");
            }
            else if (name == "canFly") {
                canFly = llList2Integer(parameterList, 1);
                if (!canFly) {
                    llOwnerSay("You can no longer fly. Helpless Dolly!");
                    doRLV("Base", "fly=n");
                }
                else doRLV("Base", "fly=y");
            }
            else if (name == "canStand") {
                canStand = llList2Integer(parameterList, 1);
                if (!canStand) doRLV("Base", "unsit=n");
                else doRLV("Base", "unsit=y");
            }
            else if (name == "canSit") {
                canSit = llList2Integer(parameterList, 1);
                if (!canSit) doRLV("Base", "sit=n");
                else doRLV("Base", "sit=y");
            }
            else if (name == "canWear") {
                canWear = llList2Integer(parameterList, 1);
                if (!canWear) doRLV("Base", "addoutfit=n,addattach=n");
                else doRLV("Base", "addoutfit=y,addattach=y");
            }
            else if (name == "canUnwear") {
                canUnwear = llList2Integer(parameterList, 1);
                if (!canUnwear) doRLV("Base", "remoutfit=n,remattach=n");
                else doRLV("Base", "remoutfit=y,remoutfit=y");
            }
            else if (name == "detachable") {
                detachable = llList2Integer(parameterList, 1);
                llOwnerSay("Your key is now a permanent part of you.");
            }
            else if (name == "visible") {
                visible = llList2Integer(parameterList, 1);
            }
            else if (name == "signOn") {
                signOn = llList2Integer(parameterList, 1);
            }
        }

        else if (num == 305) { // RLV Commands
            string script = llList2String(parameterList, 0);
            string cmd = llList2String(parameterList, 1);
            parameterList = llList2List(parameterList, 2, -1);
            
            if (cmd == "setAFK") {
                afk = llList2Integer(parameterList, 0);
                integer auto = llList2Integer(parameterList, 1);
                string rate = llList2String(parameterList, 2);
                string mins = llList2String(parameterList, 3);
                
                if (afk) {
                    
                    // set sign to "afk"
                    llSetText(dollType + " Doll (AFK)", <1,1,0>, 1);
    
                    // AFK turns everything off
                    afkOrCollapse("AFK", 1);
                    
                    if (auto)
                        llOwnerSay("Automatically entering AFK mode. Wind down rate has slowed to " + rate + "x however and movements and abilities are restricted.");
                    else
                        llOwnerSay("You are now away from keyboard (AFK). Wind down rate has slowed to " + rate + "x however and movements and abilities are restricted.");
                } else {
                    // set sign back to normal
                    if (signOn) llSetText(dollType + " Doll", <1,1,1>, 1);
                    else llSetText("", <1,1,1>, 1);
                    
                    doRLV("AFK", "clear");
        
                    llOwnerSay("You are now no longer away from keyboard (AFK). Movements are unrestricted and winding down proceeds at normal rate.");
                }
                llOwnerSay("You have " + mins + " minutes of life remaning.");
            }
            else if (cmd == "collapse") {
                collapsed = 1;

                if (hasController) {
                    llMessageLinked(LINK_SET, 11, dollName + " has collapsed at this location: " + llList2String(parameterList, 1), MistressID);
                }
            
                // Set this so an "animated" but disabled dolly can be identified
                llSetText("Disabled Dolly!", <1,0,0>, 1);
            
                // Key is made visible again when collapsed
                llSetLinkAlpha(LINK_SET, 1, ALL_SIDES);
                
                // Turn everything off: Dolly is down
                afkOrCollapse("Collapse", 1);
                doRLV("UserCollapse", addCollapseRLVcmd);
            }
            else if (cmd == "restore") {
                collapsed = 0;
                
                // If key was set to be invisible hide it again now
                if (!visible) llSetLinkAlpha(LINK_SET, 0, ALL_SIDES);
                
                doRLV("Collapse", "clear");
                doRLV("UserCollapse", "clear");
                //afkOrCollapse("Collapsed", 0);
                //doRLV("UserCollapsed", addRestoreRLVcmd);
                
            }
            else if (llGetSubString(cmd, 0, 4) == "strip") {
                string stripped;
                if (cmd == "stripTop") {
                    stripped = "top";
                    doRLV("Dress", "remoutfit=y,remattach=y,detach:stomach=force,detach:left shoulder=force,detach:right shoulder=force,detach:left hand=force,detach:right hand=force,detach:r upper arm=force,detach:r forearm=force,detach:l upper arm=force,detach:l forearm=force,detach:chest=force,detach:left pec=force,detach:right pec=force,remoutfit:gloves=force,remoutfit:jacket=force,remoutfit:shirt=force,addoutfit=n,addattach=n,remoutfit=n,remattach=n");
                    wearLockExpire = (float)wearLockTime;
                }
                else if (cmd == "stripBra") {
                    stripped = "bra";
                    doRLV("Dress", "remoutfit=y,remattach=y,remoutfit:undershirt=force,addoutfit=n,addattach=n,remoutfit=n,remattach=n");
                    wearLockExpire = (float)wearLockTime;
                }
                else if (cmd == "stripBottom") {
                    stripped = "bottoms";
                    doRLV("Dress", "remoutfit=y,remattach=y,,detach:chin=force,detach:r upper leg=force,detach:r lower leg=force,detach:l upper leg=force,detach:l lower leg=force,detach:pelvis=force,detach:right hip=force,detach:left hip=force,remoutfit:pants=force,remoutfit:skirt=force,addoutfit=n,addattach=n,remoutfit=n,remattach=n");
                    wearLockExpire = (float)wearLockTime;
                }
                else if (cmd == "stripPanties") {
                    stripped = "panties";
                    doRLV("Dress", "remoutfit=y,remattach=y,remoutfit:underpants=force,addoutfit=n,addattach=n,remoutfit=n,remattach=n");
                    wearLockExpire = (float)wearLockTime;
                }
                else if (cmd == "stripShoes") {
                    stripped = "shoes";
                    string attachFeet;
                    if (barefeet != "") attachFeet = "attachallover:" + barefeet + "=force,";
                    doRLV("Dress", "remoutfit=y,remattach=y,addoutfit=y,addattach=y,detach:l lower leg=force,detach:r lower leg=force,detach:right foot=force,detach:left foot=force,remoutfit:shoes=force,remoutfit:socks=force," + attachFeet + "addoutfit=n,addattach=n,remoutfit=n,remattach=n");
                    wearLockExpire = (float)wearLockTime;
                }
                if (!quiet) llSay(0, "The dolly " + dollName + " has her " + stripped + " stripped off her and may not redress for " + (string)llRound(wearLockExpire / 60.0) + " minutes.  (Timer resets if dolly is stripped again)");
                else llOwnerSay("You have had your " + stripped + " stripped off you and may not redress for " + (string)llRound(wearLockExpire / 60.0) + " minutes.");
            }
            else if (cmd == "carry") {
                carrierID = id;
                carrierName = llList2String(parameterList, 0);
                carried = 1;
                
                // No TP allowed for Doll
                doRLV("Carry", "tplm=n,tploc=n,accepttp=rem,tplure=n,accepttp:" + (string)carrierID + "=add,tplure:" + (string)carrierID  + "=add,showinv=n");
    
                // Allow rescuers to AutoTP
                allowRescue("Carry");
            }
            else if (cmd == "uncarry") {
                doRLV("Carry", "clear");

                carrierID = NULL_KEY;
                carrierName = "";
                carried = 0;
            
                if (!quiet) llSay(0, dollName + " was being carried by " + llList2String(parameterList, 0) + " and has been set down.");
                else llOwnerSay("You were being carried by " + llList2String(parameterList, 0) + " and have now been set down.");
            }
            else if (cmd == "TP") {
                string lm = llList2String(parameterList, 0);
                llRegionSayTo(id, 0, "Teleporting dolly " + dollName + " to  landmark " + lm + ".");
                rlvTeleportToLandmark(lm);
            }
            else if (cmd == "detach") {
                if (detachable) doRLV(scriptName, "clear,detachme=force");
                else llOwnerSay("Attempts to detach your key fail it is currently stuck");
            }
            else if (cmd == "wearLock") {
                wearLockExpire = (float)wearLockTime;
                doRLV(script, "addoutfit=n,addattach=n,remoutfit=n,remoutfit=n");
            }
        }
        else if (num == 315) {
            string script = llList2String(parameterList, 0);
            string cmd = llList2String(parameterList, 1);
            parameterList = llList2List(parameterList, 2, -1);
            
            if ((wearLockExpire > 0.0 || !canWear || !canUnwear) && script == "Dress" && id != dollID) {
                doRLV(script, "remoutfit=y,remattach=y,addoutfit=y,addattach=y," + cmd + ",remoutfit=n,remattach=n,addoutfit=n,addattach=n");
            }
        }
    }
}
