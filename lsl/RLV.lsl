// 1 "RLV.lslp"
// 1 "<built-in>"
// 1 "<command-line>"
// 1 "RLV.lslp"
//========================================
// RLV.lsl
//========================================
//
// vim:sw=4 et nowrap:
//
// DATE: 8 December 2013
// 1 "include/GlobalDefines.lsl" 1
// include/GlobalDefines.lsl
//
// Global preprocessor and variable definitions for the key
//
// 32 "include/GlobalDefines.lsl"
// Link messages
// 41 "include/GlobalDefines.lsl"
// Keys of important people in life of the Key:





// 1 "include/Utility.lsl" 1
//----------------------------------------
// Utility Functions
//----------------------------------------
string wwGetSLUrl() {
    string region = llGetRegionName();
    vector pos = llGetPos();
    string posx = (string)llRound(pos.x);
    string posy = (string)llRound(pos.y);
    string posz = (string)llRound(pos.z);

    return ("secondlife://" + llEscapeURL(region) +"/" + posx + "/" + posy + "/" + posz);
}

string bits2nybbles(integer bits)
{
    string nybbles = "";
    do
    {
        integer lsn = bits & 0xF; // least significant nybble
        nybbles = llGetSubString("0123456789ABCDEF", lsn, lsn) + nybbles;
    } while (bits = (0xfffFFFF & (bits >> 4)));
    return nybbles;
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

    llOwnerSay(llGetScriptName() + ": Memory " + formatFloat(used_memory/1024.0, 2) + "/" + (string)llRound((used_memory + free_memory)/1024.0) + "kB, " + formatFloat(free_memory/1024.0, 2) + " kB free");
}
// 48 "include/GlobalDefines.lsl" 2
// 1 "include/KeySharedFuncs.lsl" 1
//-----------------------------------
// Internal Shared Functions
//-----------------------------------

float lastTimerEvent;

float setWindRate() {
    float newWindRate;
    vector agentPos = llList2Vector(llGetObjectDetails(dollID, [ OBJECT_POS ]), 0);
    integer agentInfo = llGetAgentInfo(dollID);
    integer windDown = (llGetAttached() == ATTACH_BACK) && !collapsed && dollType != "Builder" && dollType != "Key";

    newWindRate = 1.0;
    if (afk) newWindRate *= 0.5;

    if (windRate != newWindRate * windDown) {
        windRate = newWindRate * windDown;

        llMessageLinked(LINK_SET, 300, "windRate" + "|" + (string)windRate,NULL_KEY);
    }

    // llTargetOmega: With normalized vector spinrate is equal to radians per second
    // 2𝜋 radians per rotation.  This sets a normal rotation rate of 4 rpm about the
    // Z axis multiplied by the wind rate this way the key will visually run faster as
    // the dolly begins using their time faster.
    llTargetOmega(llVecNorm(<0.0, 0.0, 1.0>), windRate * (TWO_PI / 15.0), 1);

    return newWindRate;
}

integer setFlags(integer clear, integer set) {
    integer oldFlags = globalFlags;
    globalFlags = (globalFlags & ~clear) | set;
    if (globalFlags != oldFlags) {
        llMessageLinked(LINK_SET, 300, "globalFlags" + "|" + "0x" + bits2nybbles(globalFlags),NULL_KEY);
        return 1;
    }
    else return 0;
}
// 49 "include/GlobalDefines.lsl" 2
// 9 "RLV.lslp" 2
// Current Controller - or Mistress
key MistressID = NULL_KEY;
key dollID = NULL_KEY;
key carrierID = NULL_KEY;

key rlvTPrequest;

list rlvSources;
list rlvStatus;

string dollName;
string dollType;
string mistressName;
string carrierName;

integer configured;
float wearLockExpire;
float wearLockTime = 300.0;

integer permissionsGranted;

integer autoTP;
integer canFly = 1;
integer canSit = 1;
integer canStand = 1;
integer canWear = 1;
integer canUnwear = 1;
integer detachable = 1;
integer helpless;

integer afk;
integer collapsed;
integer quiet;
integer RLVck;
integer RLVok;
integer locked;

integer channel;
integer listenHandle;
integer RLVstarted;

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
    if ((llGetAttached() == ATTACH_BACK)) {
        llListenControl(listenHandle, 1);
        llSetTimerEvent(5);
        rlvAPIversion = "";
        RLVck = 1;

        llOwnerSay("@clear,versionnew=" + (string)channel);
    }
    else postCheckRLV();
}

postCheckRLV()
{ // Handle RLV check result
    if (RLVok) llOwnerSay("Logged with Community Doll Key and " + rlvAPIversion + " active...");
    else if ((llGetAttached() == ATTACH_BACK) && !RLVok) llOwnerSay("Did not detect an RLV capable viewer, RLV features disabled.");

    // Mark RLV check completed
    RLVck = 0;

    if (configured) initializeRLV(0);
    llMessageLinked(LINK_SET, 103, llGetScriptName(), NULL_KEY);
}

initializeRLV(integer refresh) {
    if (RLVok && (llGetAttached() == ATTACH_BACK)) {
        if (!refresh) {
            llOwnerSay("Enabling RLV mode");
            rlvSources = [];
            rlvStatus = [];
        }

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
        if (!canWear || wearLockExpire > 0) baseRLV += "addoutfit=n,addattach=n,";
        else baseRLV += "addoutfit=y,addattach=y,";
        if (!canUnwear || wearLockExpire > 0) baseRLV += "remoutfit=n,remattach=n";
        else baseRLV += "remoutfit=y,remattach=y";

        doRLV("Base", baseRLV);

        // if Doll is one of the developers... dont lock:
        // prevents inadvertent lock-in during development
// 140 "RLV.lslp"
        if (!refresh) {
            if (!quiet) llSay(0, "Developer Key not locked.");
            else llOwnerSay("Developer key not locked.");
        }

    }

    if (!refresh) {
        RLVstarted = 1;
        llSetTimerEvent(1);
        llMessageLinked(LINK_SET, 350, (string)RLVok + "|" + rlvAPIversion, NULL_KEY);
    }
}

allowRescue(string script) {
    list allow = [ "42c7aaec-38bc-4b0c-94dd-ae562eb67e6d", "64d26535-f390-4dc4-a371-a712b946daf8", "c5e11d0a-694f-46cc-864b-e42340890934", "2fff40f0-ea4a-4b52-abb8-d4bf6b1c98c9" ];
    if (MistressID != NULL_KEY) allow += MistressID;
    integer loop;
    for (loop = 0; loop < llGetListLength(allow); loop++) autoTPAllowed(script, llList2Key(allow, loop));
}

// Only useful if @tplure and @accepttp are off and denied by default...
autoTPAllowed(string script, key userID) {
    doRLV(script, "tplure:" + (string) userID + "=add,accepttp:" + (string) userID + "=add");
}

doRLV(string script, string commandString) {
    if (RLVok) {
        integer commandLoop; string sendCommands = "";
        integer charLimit = 756; // Secondlife supports chat messages up to 1024 chars
                                    // here we avoid sending over 756 at a time for safety
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

            if (llStringLength(sendCommands + fullCmd + ",") > charLimit) {
                llOwnerSay(llGetSubString("@" + sendCommands, 0, -2));
                llMessageLinked(LINK_SET, 320, script + "|" + llGetSubString(sendCommands, 0, -2), NULL_KEY);
                sendCommands = "";
            }

            if (cmd != "clear") {
                if (param == "n" || param == "add") {
                    integer cmdIndex = llListFindList(rlvStatus, [ cmd ]);
                    if (cmdIndex == -1) { // New restriction add to list and send to viewer
                        rlvStatus += [ cmd, script ];
                        sendCommands += fullCmd + ",";
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
                                sendCommands += fullCmd + ",";
                            } else { // Restriction still holds due to other scripts but release for this one
                                rlvStatus = llListReplaceList(rlvStatus, [ cmd, llDumpList2String(scriptList, "|") ],
                                                              cmdIndex, cmdIndex + 1);
                            }
                        }
                    }
                }
                else {
                    // Oneshot command
                    sendCommands += fullCmd + ",";
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
                                if (llStringLength(sendCommands + thisCmd + "=y,") > charLimit) {
                                    llOwnerSay(llGetSubString("@" + sendCommands, 0, -2));
                                    llMessageLinked(LINK_SET, 320, script + "|" + llGetSubString(sendCommands, 0, -2), NULL_KEY);
                                    sendCommands = "";
                                }
                                sendCommands += thisCmd + "=y,";
                            } else { // Restriction still holds due to other scripts but release for this one
                                rlvStatus = llListReplaceList(rlvStatus, [ thisCmd, llDumpList2String(scriptList, "|") ],
                                                              i, i + 1);
                            }
                        }
                    }
                }
            }
        }

        if (sendCommands != "") {
            llOwnerSay(llGetSubString("@" + sendCommands, 0, -2));
            llMessageLinked(LINK_SET, 320, script + "|" + llGetSubString(sendCommands, 0, -2), NULL_KEY);
        }

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
        doRLV(type,
"addoutfit=n,remoutfit=n,addattach=n,remattach=n,fly=n,sit=n,unsit=n,tplm=n,tploc=n,temprun=n,alwaysrun=n,sendchat=n,tplure=n,sittp=n,standtp=n,shownames=n,showhovertextall=n,redirchat:999=add,rediremote:999=add");

        lockAttachments(type, set);

        allowRescue(type);
        if (carrierID != NULL_KEY) autoTPAllowed(type, carrierID);
    }
    else doRLV(type, "clear");
}

lockAttachments(string type, integer set) {
    list points = [ "spine", "chest", "skull", "left shoulder", "right shoulder", "left hand", "right hand", "left foot", "right foot", "pelvis", "mouth", "chin", "left ear", "right ear", "left eyeball", "right 
eyeball", "nose", "r upper arm", "r forearm", "l upper arm", "l forearm", "right hip", "r upper leg", "r lower leg", "left hip", "l upper leg", "l lower leg", "stomach", "left pec", "right pec", "center 2", "top
right", "top", "top left", "center", "bottom left", "bottom", "bottom right", "neck" ];
    if (set) {

        doRLV(type, "detach:" + llDumpList2String(llList2List(points, 1, -1), "=n,detach:") + "=n");



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
            if ((llGetAttached() == ATTACH_BACK) && RLVck != 6) llOwnerSay("@clear,versionnew=" + (string)channel);
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
            if (!RLVok) {
                RLVok = 1;
                rlvAPIversion = llStringTrim(msg, STRING_TRIM);
                postCheckRLV();
            }

            llListenControl(listenHandle, 0);
        }
    }

    //----------------------------------------
    // LINK_MESSAGE
    //----------------------------------------

    link_message(integer sender, integer code, string data, key id) {
        list split = llParseString2List(data, [ "|" ], []);

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
            if (!RLVck && !RLVstarted) initializeRLV(0);
        }
        else if (code == 104) {
            dollID = llGetOwner();
            dollName = llGetDisplayName(dollID);
            listenerStart();
            checkRLV();
        }
        else if (code == 105) {
            locked = 0;
            RLVok = 0;
            RLVstarted = 0;

            checkRLV();
        }
        else if (code == 106) {
            if (id == NULL_KEY && (MistressID != NULL_KEY) && !detachable && !locked) {
                // Undetachable key with controller is detached while RLV lock
                // is not available inform Mistress.
                // We send no message if the key is RLV locked as RLV will reattach
                // automatically this prevents neusance messages when defaultwear is
                // permitted.
                llMessageLinked(LINK_SET, 11, dollName + " has detached their key while undetachable.", MistressID);
            }
        }
        else if (code == 135) {
            memReport();
        }
        else if (code == 300) { // RLV Config
            string name = llList2String(split, 0);
            string value = llList2String(split, 1);

            if (llListFindList([ "autoTP", "canFly", "canSit", "canStand", "canWear", "canUnwear", "helpless" ], [ name ]) != -1) {
                     if (name == "autoTP") autoTP = (integer)value;
                else if (name == "canFly") canFly = (integer)value;
                else if (name == "canSit") canSit = (integer)value;
                else if (name == "canStand") canStand = (integer)value;
                else if (name == "canWear") canWear = (integer)value;
                else if (name == "canUnwear") canUnwear = (integer)value;
                else if (name == "helpless") helpless = (integer)value;

                if (RLVstarted) initializeRLV(1);
            } else {
                     if (name == "detachable") detachable = (integer)value;
                else if (name == "dollType") dollType = value;
                else if (name == "MistressID") MistressID = (key)value;
                else if (name == "mistressName") mistressName = value;
                else if (name == "quiet") quiet = (integer)value;
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
                    // AFK turns everything off
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
                if ((MistressID != NULL_KEY)) {
                    llMessageLinked(LINK_SET, 11, dollName + " has collapsed at this location: " + llList2String(split, 1), MistressID);
                }

                // Turn everything off: Dolly is down
                afkOrCollapse("Collapse", 1);
                // Add user defined restrictions
                doRLV("UserCollapse", userCollapseRLVcmd);
            }
            else if (cmd == "restore") {
                // Clear collapse restrictions
                doRLV("Collapse", "clear");
                // Clear user collapse restrictions
                doRLV("UserCollapse", "clear");
            }

            else if (llGetSubString(cmd, 0, 4) == "strip") {
                string stripped;
                if (cmd == "stripTop") {
                    stripped = "top";
                    doRLV("Dress", "remoutfit=y,remattach=y,detach:stomach=force,detach:left shoulder=force,detach:right shoulder=force,detach:left hand=force,detach:right hand=force,detach:r upper arm=force,detach:r 
forearm=force,detach:l upper arm=force,detach:l forearm=force,detach:chest=force,detach:left pec=force,detach:right
pec=force,remoutfit:gloves=force,remoutfit:jacket=force,remoutfit:shirt=force,addoutfit=n,addattach=n,remoutfit=n,remattach=n");
                    wearLockExpire = (float)wearLockTime;
                }
                else if (cmd == "stripBra") {
                    stripped = "bra";
                    doRLV("Dress", "remoutfit=y,remattach=y,remoutfit:undershirt=force,addoutfit=n,addattach=n,remoutfit=n,remattach=n");
                    wearLockExpire = (float)wearLockTime;
                }
                else if (cmd == "stripBottom") {
                    stripped = "bottoms";
                    doRLV("Dress", "remoutfit=y,remattach=y,,detach:chin=force,detach:r upper leg=force,detach:r lower leg=force,detach:l upper leg=force,detach:l lower leg=force,detach:pelvis=force,detach:right 
hip=force,detach:left hip=force,remoutfit:pants=force,remoutfit:skirt=force,addoutfit=n,addattach=n,remoutfit=n,remattach=n");
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
                    doRLV("Dress", "remoutfit=y,remattach=y,addoutfit=y,addattach=y,detach:l lower leg=force,detach:r lower leg=force,detach:right foot=force,detach:left 
foot=force,remoutfit:shoes=force,remoutfit:socks=force," + attachFeet + "addoutfit=n,addattach=n,remoutfit=n,remattach=n");
                    wearLockExpire = (float)wearLockTime;
                }
                if (!quiet) llSay(0, "The dolly " + dollName + " has her " + stripped + " stripped off her and may not redress for " + (string)llRound(wearLockExpire / 60.0) + " minutes.  (Timer resets if dolly is 
stripped again)");
                else llOwnerSay("You have had your " + stripped + " stripped off you and may not redress for " + (string)llRound(wearLockExpire / 60.0) + " minutes.");
            }

            else if (cmd == "carry") {
                carrierID = id;
                carrierName = llList2String(split, 0);

                // No TP allowed for Doll
                doRLV("Carry", "tplm=n,tploc=n,accepttp=rem,tplure=n,accepttp:" + (string)carrierID + "=add,tplure:" + (string)carrierID + "=add,showinv=n");

                // Allow rescuers to AutoTP
                allowRescue("Carry");
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
                wearLockExpire = (float)wearLockTime;
                doRLV(script, "addoutfit=n,addattach=n,remoutfit=n,remoutfit=n");
            }
        }
        else if (code == 315) {
            string script = llList2String(split, 0);
            string cmd = llList2String(split, 1);
            split = llList2List(split, 2, -1);

            if ((wearLockExpire > 0.0 || !canWear || !canUnwear) && script == "Dress" && id != dollID)
                doRLV(script, "remoutfit=y,remattach=y,addoutfit=y,addattach=y," + cmd + ",remoutfit=n,remattach=n,addoutfit=n,addattach=n");
            else doRLV(script, cmd);
        }
    }
}
