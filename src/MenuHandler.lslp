// MenuHandler.lsl
//
// vim:sw=4 et nowrap:
//
// DATE: 10 December 2013
#include "include/GlobalDefines.lsl"

// Current Controller - or Mistress
//key MistressID = NULL_KEY;
key poserID = NULL_KEY;
key dollID = NULL_KEY;

list windTimes = [ 30 ];

float timeLeftOnKey;
float windDefault = 1800.0;
float windRate = 1.0;
float baseWindRate = 1.0;
float collapseTime;

integer afk;
integer autoAFK = 1;
integer autoTP;
integer canAFK = 1;
integer canCarry = 1;
integer canDress = 1;
integer canFly = 1;
integer canSit = 1;
integer canStand = 1;
integer canRepeat = 1;
integer poseSilence;
//integer canWear;
//integer canUnwear;
integer carryMoved;
integer clearAnim;
integer collapsed;
integer configured;
integer demoMode;
integer detachable = 1;
integer doWarnings;
integer helpless;
integer pleasureDoll;
integer isTransformingKey;
integer visible = 1;
integer quiet;
integer RLVok;
integer signOn;
integer takeoverAllowed;
integer warned;
integer offlineMode;
integer wearLock;
integer dbConfig;
integer initState = 104;
integer textboxType;

integer blacklistChannel;
integer textboxChannel;
integer controlChannel;
integer dialogChannel;
integer blacklistHandle;
integer textboxHandle;
integer controlHandle;
integer dialogHandle;
string isDollName;
string dollType = "Regular";
string pronounHerDoll = "Her";
string pronounSheDoll = "She";

string carrierName;
string mistressName;
#ifdef ADULT_MODE
string simRating;
#endif
string keyAnimation;
string dollyName;

list blacklist;
list dialogKeys;
list dialogNames;
list dialogButtons;

default
{
    state_entry() {
        dollID = llGetOwner();
        dollName = llGetDisplayName(dollID);
    }
    
    link_message(integer sender, integer code, string data, key id) {
        list split = llParseString2List(data, [ "|" ], []);
        
        if (code == 102) {
            if (data == "OnlineServices") dbConfig = 1;
            else if (data == "Start") configured = 1;
        }
        else if (code == 104 || code == 105) {
            if (llList2String(split, 0) != "Start") return;
            
            if (code == 104) {
                dialogChannel = 0x80000000 | (integer)("0x" + llGetSubString((string)llGetLinkKey(2), -8, -1));
                blacklistChannel = dialogChannel - 666;
                controlChannel = dialogChannel - 888;
                if (!dialogHandle && dialogChannel) {
                    dialogHandle = llListen(dialogChannel, "", "", "");
                    llListenControl(dialogHandle, 0);
                }
                lmSendConfig("dialogChannel", (string)dialogChannel);
            }
            if (initState == code) lmInitState(initState++);
        }
        else if (code == 110) {
            initState = 105;
            lmInternalCommand("updateExceptions", "", NULL_KEY);
        }
        else if (code == 135) {
            float delay = llList2Float(split, 1);
            memReport(delay);
        }
        else if (code == 150) {
            simRating = llList2String(split, 0);
        }
        else if (code == 300) {
            string script = llList2String(split, 0);
            string name = llList2String(split, 1);
            string value = llList2String(split, 2);
            split = llList2List(split, 2, -1);
            
                 if (name == "timeLeftOnKey")           timeLeftOnKey = (float)value;
            else if (name == "baseWindRate")             baseWindRate = (float)value;
            else if (name == "keyAnimation")             keyAnimation = value;
            else if (name == "pronounHerDoll")         pronounHerDoll = value;
            else if (name == "pronounSheDoll")         pronounSheDoll = value;
            else if (name == "dollyName")                   dollyName = value;
            else if (name == "afk")                               afk = (integer)value;
            else if (name == "autoTP")                         autoTP = (integer)value;
            else if (name == "canAFK")                         canAFK = (integer)value;
            else if (name == "canCarry")                     canCarry = (integer)value;
            else if (name == "canDress")                     canDress = (integer)value;
            else if (name == "canWear")                       canWear = (integer)value;
            else if (name == "wearLock")                     wearLock = (integer)value;
            else if (name == "canFly")                         canFly = (integer)value;
            else if (name == "canSit")                         canSit = (integer)value;
            else if (name == "canStand")                     canStand = (integer)value;
            else if (name == "canRepeat")                   canRepeat = (integer)value;
            else if (name == "poseSilence")               poseSilence = (integer)value;
            else if (name == "configured")                 configured = (integer)value;
            else if (name == "detachable")                 detachable = (integer)value;
            else if (name == "demoMode")                     demoMode = (integer)value;
            else if (name == "helpless")                     helpless = (integer)value;
            else if (name == "pleasureDoll")             pleasureDoll = (integer)value;
            else if (name == "isTransformingKey")   isTransformingKey = (integer)value;
            else if (name == "wearLock")                     wearLock = (integer)value;
            else if (name == "quiet")                           quiet = (integer)value;
            else if (name == "signOn")                         signOn = (integer)value;
            else if (name == "takeoverAllowed")       takeoverAllowed = (integer)value;
            else if (name == "poserID")                       poserID = (key)value;
            else if (name == "isVisible") {
                visible = (integer)value;
                llSetLinkAlpha(LINK_SET, (float)visible, ALL_SIDES);
            }
            else if (name == "dollType") {
                dollType = llGetSubString(llToUpper(value), 0, 0) + llGetSubString(llToLower(value), 1, -1);
            }
            else if (name == "MistressList") MistressList = llListSort(split, 2, 1);
            else if (name == "blacklist") blacklist = llListSort(split, 2, 1);
        }        
        else if (code == 305) {
            string script = llList2String(split, 0);
            string cmd = llList2String(split, 1);
            split = llList2List(split, 2, -1);
            
            if (cmd == "carry") {
                // Doll has been picked up...
                carrierID = id;
                carrierName = llList2String(split, 0);
            }
            else if (cmd == "uncarry") {
                // Doll has been placed down...
                carrierID = NULL_KEY;
                carrierName = "";
            }
            else if (cmd == "setAFK") afk = llList2Integer(split, 0);
            else if (cmd == "collapse") {
                keyAnimation = ANIMATION_COLLAPSED;
                collapseTime = llGetTime();
                collapsed = 1;
            }
            else if (cmd == "uncollapse") {
                keyAnimation = "";
                collapsed = 0;
            }
            else if (cmd == "dialogListen") {
                llListenControl(dialogHandle, 1);
                llSetTimerEvent(60.0);
            }
            
            // Deny access to the menus when the command was recieved from blacklisted avatar
            if (llListFindList(blacklist, [ (string)id ]) != -1) {
                lmSendToAgent("You are not permitted to access this key.", id);
                return;
            }
            else if (cmd == "setGemColour") {
                integer i; list params; vector baseColour = (vector)llList2String(split, 0);
                for (i = 0; i < llGetLinkNumberOfSides(4); i++) {
                    vector shade = <llFabs((llFrand(0.2) - 0.1) + baseColour.x), llFabs((llFrand(0.2) - 0.1) + baseColour.y), llFabs((llFrand(0.2) - 0.1) + baseColour.z)>;
                    float mag = llVecMag(shade);
                    
                    if (llVecMag(shade) > 1.0) {
                        if (llVecMag(shade) < 1.2) shade = llVecNorm(shade);
                        else shade /= 256.0;
                    }
                    
                    params += [ PRIM_COLOR, i, shade, 1.0 ];
                }
                
                params = [ PRIM_POINT_LIGHT, TRUE, baseColour, 0.350, 3.50, 2.00 ] + params;
                llSetLinkPrimitiveParamsFast(4, params + [ PRIM_LINK_TARGET, 5 ] + params);
            }
            else if (cmd == "mainMenu") {
                string msg; list menu; string manpage;
                
                // Compute "time remaining" message for mainMenu/windMenu
                string timeleft;
                
                float displayWindRate = setWindRate();
                integer minsLeft = llRound(timeLeftOnKey / (60.0 * displayWindRate));
                
                if (minsLeft > 0) {
                    timeleft = "Dolly has " + (string)minsLeft + " minutes remaining.\n";
            
                    timeleft += "Key is ";
                    if (windRate == 0.0) timeleft += "not ";
                    timeleft += "winding down";
                    
                    if (windRate == 0.0) timeleft += ".";
                    else timeleft += " at " + formatFloat(displayWindRate, 1) + "x rate.";
            
                    timeleft += ". ";
                }
                else timeleft = "Dolly has no time left.";
                timeleft += "\n";
                
                // Handle our "special" states first which significantly alter the menu
                
                // When the doll is carried they have exclusive control
                if (hasCarrier) {
                    // Doll being carried clicked on key
                    if isDoll {
                        msg = "You are being carried by " + carrierName + ".";
                        menu = ["OK"];
                    }
                    
                    else if (isCarrier) {
                        msg = "Place Down frees " + dollName + " when you are done with " + pronounHerDoll;
                        
                        menu += "Uncarry";
                    }
            
                    // Someone else clicked on key
                    else {
                        msg = dollName + " is currently being carried by " + carrierName + ". They have full control over this doll.\n";
                        menu = ["OK"];
                    }
                }
                // When the doll is collapsed they lose their access to most key functions with a few exceptions
                else if (collapsed) {
                    if (isDoll) {
                        msg = "You need winding.";
                        
                        if (llGetInventoryType(LANDMARK_HOME) == INVENTORY_LANDMARK) {
                            // Only present the TP home option for the doll if they have been collapsed
                            // for at least 900 seconds (15 minutes) - Suggested by Christina
                            if (collapseTime + 900.0 < llGetTime()) menu = ["TP Home"];
                        }
                        
                        #ifndef TESTER_MODE
                        // Otherwise no more options here
                        if (menu == []) menu = ["OK"]
                        #endif
                    }
                }
                
                if (!collapsed && (!hasCarrier || isCarrier)) {   
                    //not  being carried (or for carrier), not collapsed - normal in other words
                    // Toucher could be...
                    //   1. Doll
                    //   2. Carrier
                    //   3. Controller
                    //   4. Someone else
                    
                    // Options only available to dolly
                    if (isDoll) {
                        menu += "Options";
                        if (detachable) menu += "Detach";
                        #ifdef TESTER_MODE
                        menu += "Wind";
                        #endif
            
                        if (canAFK) menu += getButton("AFK", id, afk, 0);
            
                        menu += getButton("Visible", id, visible, 0);
                    }
                    // Options only available if controller
                    else if (isController || (numControllers == 0)) {
                        menu += [ "Options", "Detach" ];
                        
                        if (canCarry) {
                            msg =  msg +
                                   "Carry option picks up " + dollName + " and temporarily" +
                                   " makes the Dolly exclusively yours.\n";
            
                            if (!hasCarrier) menu += "Carry";
                        }
                    }
                    else {
                        manpage = "communitydoll.htm";
                    
                        // Toucher is not Doll.... could be anyone
                        msg =  dollName + " is a doll and likes to be treated like " +
                               "a doll. So feel free to use these options.\n";
                    }
                    
                    #ifdef TESTER_MODE
                    menu += "Wind";
                    #else
                    if (!isDoll) menu += "Wind";
                    #endif
                 
                    // Can the doll be dressed? Add menu button
                    if (RLVok && ((!isDoll && canDress) || (isDoll && canWear && !wearLock))) {
                        menu += "Dress";
                    }
                
                    // Can the doll be transformed? Add menu button
                    if (isTransformingKey) {
                        menu += "Type of Doll";
                    }
            
                    if (keyAnimation != "" && keyAnimation != ANIMATION_COLLAPSED) {
                        //msg += "Doll is currently in the " + currentAnimation + " pose. ";
                        msg += "Doll is currently posed.\n";
                    }
            
                    if (keyAnimation != "" && keyAnimation != ANIMATION_COLLAPSED && (!isDoll || poserID == dollID)) menu += "Unpose";
            
                    if (keyAnimation == "" || (!isDoll || poserID == dollID)) menu += "Poses";
                
                    #ifdef ADULT_MODE
                        // Is doll strippable?
                        if (RLVok && (pleasureDoll || dollType == "Slut")) {
                            #ifdef TESTER_MODE
                            if (isController || isCarrier || isDoll) {
                            #else
                            if (isController || isCarrier) {
                            #endif
                                if (simRating == "MATURE" || simRating == "ADULT") menu += "Strip";
                            }
                        }
                    #endif
                }
                
                menu += "Help/Support";
                
                llListenControl(dialogHandle, 1);
                llSetTimerEvent(60.0);
                
                if (!RLVok) msg += "No RLV detected some features unavailable.\n";
                
                msg += "See " + WEB_DOMAIN + manpage + " for more information." ;
                llDialog(id, timeleft + msg, dialogSort(llListSort(menu, 1, 1)) , dialogChannel);
            }
        }
        else if (code == 350) {
            RLVok = llList2Integer(split, 0);
        }
        
        string type = llList2String(llParseString2List(data, [ "|" ], []), 1);
        if (type == "MistressList" || type == "carry" || type == "uncarry" || type == "updateExceptions") {
            // Exempt builtin or user specified controllers from TP restictions
            list allow = BuiltinControllers + llList2ListStrided(MistressList, 0, -1, 2);
            // Also exempt the carrier if any provided they are not already exempted as a controller
            if ((carrierID != NULL_KEY) && (llListFindList(allow, [ (string)carrierID ]) == -1)) allow += carrierID;
            
            // Directly dump the list using the static parts of the RLV command as a seperatior no looping
            string exceptionRLV = "tplure:" + llDumpList2String(allow, "=add,tplure:") + "=add,";
            exceptionRLV += "accepttp:" + llDumpList2String(allow, "=add,accepttp:") + "=add";
        
            // Apply exemptions to base RLV
            lmRunRLVas("Base", exceptionRLV);
        }
    }
    
    on_rez(integer start) {
        dbConfig = 0;
    }
    
    timer() {
        if(blacklistHandle) {
            llListenRemove(blacklistHandle);
            blacklistHandle = 0;
        }
        if (controlHandle) {
            llListenRemove(controlHandle);
            controlHandle = 0;
        }
        if (textboxHandle) {
            llListenRemove(textboxHandle);
            textboxHandle = 0;
        }
        llListenControl(dialogHandle, 0);
        dialogKeys = []; dialogButtons = []; dialogNames = [];
        llSetTimerEvent(0.0);
    }
    
    sensor(integer num) {
        integer i;
        if (num > 12) num = 12;
        for (i = 0; i < num; i++) {
            dialogKeys += llDetectedKey(i);
            dialogNames += llDetectedName(i);
            dialogButtons += llGetSubString(llDetectedName(i), 0, 23);
        }
        
        if (blacklistHandle) llDialog(dollID, "Select the avatar to be added to the blacklist.", dialogSort(dialogButtons + MAIN), blacklistChannel);
        else if (controlHandle) llDialog(dollID, "Select the avatar to be added to the controller list.", dialogSort(dialogButtons + MAIN), controlChannel);
    }
    
    no_sensor() {
        llDialog(dollID, "No avatars detected within chat range", [MAIN], dialogChannel);
    }
    
    touch_start(integer num) {
        integer i;
        for (i = 0; i < num; i++) lmInternalCommand("mainMenu", "", llDetectedKey(i));
    }
    
    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer channel, string name, key id, string choice) {
        // channel = chat channel to listen on
        //    name = filter by prim name
        //     key = filter by avatar key
        //  choice = filter by specific message
        if (llListFindList(blacklist, [ (string)id ]) != -1) {
            lmSendToAgent("You are not permitted to access this key.", id);
            return;
        }
        
        string displayName = llGetDisplayName(id);
        if (displayName != "") name = displayName;
        
        list split = llParseStringKeepNulls(choice, [ " " ], []);
        string optName = llDumpList2String(llList2List(split, 1, -1), " ");
        string curState = llList2String(split, 0);

        debugSay(3, "Button clicked: " + choice + ", optName=\"" + optName + "\", curState=\"" + curState + "\"");
        lmMenuReply(choice, name, id);
        
        if (channel == dialogChannel) {
            integer isAbility; // Temporary variables used to determine if an option
            integer isFeature; // from the features or abilities menu was clicked that 
                               // way we can restore it making setting several choices
                               // much more user friendly.
                               
            if (choice == MAIN) {
                lmInternalCommand("mainMenu", "", id);;
                return;
            }
            
            if (choice == "Help/Support") {
                string msg = "Here you can find various options to get help with your " +
                            "key and to connect with the community.";
                list pluslist = [ "Join Group", "Visit Dollhouse" ];
                if (llGetInventoryType(NOTECARD_HELP) == INVENTORY_NOTECARD) pluslist += [ "Help Notecard" ];
                if (isController) pluslist += "Reset Scripts";
                if (isDoll) pluslist += "Check Update";
                if (isController || isDoll) pluslist += "Reset Scripts";
                
                llDialog(id, msg, dialogSort(pluslist + MAIN), dialogChannel);
            }
            else if (choice == "Help Notecard") {
                llGiveInventory(id,NOTECARD_HELP);
            }
            else if (choice == "Join Group") {
                llOwnerSay("Here is your link to the community dolls group profile secondlife:///app/group/0f0c0dd5-a611-2529-d5c7-1284fb719003/about");
                llDialog(id, "To join the community dolls group open your chat history (CTRL+H) and click the group link there.  Just click the Join Group button when the group profile opens.", [MAIN], dialogChannel);
            }
            else if (choice == "Visit Dollhouse") {
                if (isDoll) llMessageLinked(LINK_THIS, 305, llGetScriptName() + "|TP|" + LANDMARK_CDROOM, id);
                else llGiveInventory(id, LANDMARK_CDROOM);
            }
            else if (choice == "Type of Doll") {
                llMessageLinked(LINK_THIS, 17, name, id);
            }
            else if (choice == "Dress") {
                if (!isDoll) llOwnerSay("secondlife:///app/agent/" + (string)id + "/about is looking at your dress menu");
            }
            #ifdef ADULT_MODE
            else if ((dollType == "Slut" || pleasureDoll) && choice == "Strip") {
                llDialog(id, "Take off:", ["Top", "Bra", "Bottom", "Panties", "Shoes", MAIN], dialogChannel);
            }
            #endif
            else if (choice == "Options") {
                string msg; list pluslist;
                if (isDoll) {
                    msg = "See " + WEB_DOMAIN + "keychoices.htm for explanation.";
                    pluslist += [ "Type Options", "Access Menu" ];
                    if (isController) pluslist += "Abilities Menu";
                }
                else if (isController) {
                    msg = "See " + WEB_DOMAIN + "controller.htm. Choose what you want to happen.";
                    pluslist += [ "Abilities Menu", "Drop Control" ];
                }
                else return;
                
                pluslist += [ "Features Menu", "Key Settings" ];
                
                llDialog(id, msg, dialogSort(pluslist + MAIN), dialogChannel); 
            }
            else if (choice == "Key Settings" && (isController || isDoll)) {
                llDialog(id, "Here you can set various key appearance options.", [ "Dolly Name", "Gem Colour" ], dialogChannel);
            }
            else if (choice == "Dolly Name") {
                llDialog(id, "Not implemented yet", [MAIN], dialogChannel);
            }
            else if ((choice == "Gem Colour") || (llListFindList(COLOR_NAMES, [ choice ]) != -1)) {
                if ((choice != "CUSTOM") && (choice != "Gem Colour")) {
                    integer index = llListFindList(COLOR_NAMES, [ choice ]);
                    string choice = (string)llList2Vector(COLOR_VALUE, index);
                    
                    lmInternalCommand("setGemColour", choice, id);
                } 
                else if (choice == "CUSTOM") {
                    textboxType = 1;
                    textboxHandle = llListen(textboxChannel, "", "", "");
                    llTextBox(id, "Here you can input a custom colour value\n\nSupported Formats:\nLSL Vector <0.900, 0.500, 0.000>\n" +
                                  "Web Format Hex #A4B355\nRGB Value 240, 120, 10", textboxChannel);
                    return;
                }
                
                string msg = "Here you can set various key settingd. (" + OPTION_DATE + " version)";
                list pluslist;
                
                pluslist = COLOR_NAMES;
                
                llDialog(id, msg, dialogSort(pluslist + MAIN), dialogChannel);
            }
            else if (choice == "Detach")
                lmInternalCommand("detach", "", id);
            else if (optName == "Visible") lmSendConfig("isVisible", (string)(visible = (curState == CROSS)));
            else if (choice == "Reload Config") {
                llResetOtherScript("Start");
            }
            else if (choice == "TP Home") {
                lmInternalCommand("TP", LANDMARK_HOME, id);
            }
            else if (optName == "AFK") {
                afk = (curState == CROSS);
                float displayWindRate = setWindRate();
                integer minsLeft = llRound(timeLeftOnKey / (60.0 * displayWindRate));
                lmInternalCommand("setAFK", (string)afk + "|0|" + formatFloat(windRate, 1) + "|" + (string)minsLeft, id);
            }
            else if (choice == "Access Menu") {
                string msg =    "Key Access Menu. (" + OPTION_DATE + " version)\n" +
                                "These are powerful options allowing you to give someone total control of your key or block someone from touch or even winding your key\n" +
                                "Good dollies should read their key help before \n" +
                                "Blacklist - Fully block this avatar from using any key option even winding\n" +
                                "Controller - Take care choosing your controllers, they have great control over their doll can only be removed by their choice";
                list pluslist = [ "⊕ Blacklist", "⊖ Blacklist", "List Blacklist", "⊕ Controller", "List Controllers" ];
                
                if (llListFindList(BuiltinControllers, [ (string)id ]) != -1) pluslist +=  "⊖ Controller";
                
                llDialog(id, msg, dialogSort(llListSort(pluslist, 1, 1) + MAIN), dialogChannel);
            }
            if ((optName == "Blacklist") || (optName == "Controller")) {
                integer activeChannel; integer i;
                dialogKeys = []; dialogNames = []; dialogButtons = [];
                if (optName == "Blacklist") {
                    if (controlHandle) {
                        llListenRemove(controlHandle);
                        controlHandle = 0;
                    }
                    activeChannel = blacklistChannel;
                    for (i = 0; i < llGetListLength(blacklist); i++) {
                        dialogKeys += llList2Key(blacklist, i);
                        dialogNames += llList2String(blacklist, ++i);
                        dialogButtons += llGetSubString(llList2String(blacklist, i), 0, 23);
                    }
                    blacklistHandle = llListen(blacklistChannel, "", dollID, "");
                }
                else {
                    if (blacklistHandle) {
                        llListenRemove(blacklistHandle);
                        blacklistHandle = 0;
                    }
                    activeChannel = controlChannel;
                    for (i = 0; i < llGetListLength(MistressList); i++) {
                        dialogKeys += llList2Key(MistressList, i);
                        dialogNames += llList2String(MistressList, ++i);
                        dialogButtons += llGetSubString(llList2String(MistressList, i), 0, 23);
                    }
                    controlHandle = llListen(controlChannel, "", dollID, "");
                }
                
                if (curState == "⊕") {
                    if (llGetListLength(dialogKeys) < 11) {
                        llSensor("", "", AGENT, 20.0, PI);
                    }
                    else {
                        string msg = "You already have the maximum (11) entries in your ";
                        if (activeChannel == controlChannel) msg += "controller list, ";
                        else msg += "blacklist, ";
                        msg += "please remove one or more entries before attempting to add another.";
                        llRegionSayTo(id, 0, msg);
                    }
                }
                else if (curState == "⊖") {
                    string msg;
                    if (dialogKeys != []) msg = "Choose a person to remove from ";
                    else msg = "You currently have nobody listed in your ";
                    
                    if (activeChannel == controlChannel) msg += "controller list.";
                    else msg += "blacklist.";
                    
                    if (dialogKeys == []) {
                        msg += "did you mean to select the add option instead?.";
                        llRegionSayTo(id, 0, msg);
                        return;
                    }
                    
                    llDialog(id, msg, dialogSort(llListSort(dialogButtons, 1, 1) + MAIN), activeChannel);
                    llSetTimerEvent(60.0);
                }
                else if (curState == "List") {
                    integer i; string output;
                    
                    if (activeChannel == controlChannel) output += "Allowed Controllers:";
                    else output += "Blacklisted Avatars:";
                    
                    do {
                        output += "\n" + (string)(i + 1) + ". " + llList2String(dialogNames, i++);
                    } while (i < llGetListLength(dialogKeys));
                    llOwnerSay(output);
                }
            }
            
            // Entering options menu section
            
            // Entering abilities menu section
            isAbility = 1;
            if (optName == "Self TP") lmSendConfig("helpless", (string)(helpless = (curState == CHECK)));
            else if (optName == "Self Dress") lmSendConfig("canWear", (string)(canWear = (curState == CHECK)));
            else if (optName == "Detachable") lmSendConfig("detachable", (string)(detachable = (curState == CROSS)));
            else if (optName == "Flying") lmSendConfig("canFly", (string)(canFly = (curState == CROSS)));
            else if (optName == "Sitting") lmSendConfig("canSit", (string)(canSit = (curState == CROSS)));
            else if (optName == "Standing") lmSendConfig("canStand", (string)(canStand = (curState == CROSS)));
            else if (optName == "Force TP") lmSendConfig("autoTP", (string)(autoTP = (curState == CROSS)));
            else if (optName == "Poses Silence") lmSendConfig("poseSilence", (string)(poseSilence = (curState == CROSS)));
            else isAbility = 0; // Not an options menu item after all
                
            isFeature = 1; // Maybe it'a a features menu item
            if (optName == "Type Text") lmSendConfig("signOn", (string)(signOn = (curState == CROSS)));
            else if (optName == "Quiet Key") lmSendConfig("quiet", (string)(quiet = (curState == CROSS)));
            else if (optName == "Allow AFK") lmSendConfig("canAFK", (string)(canAFK = (curState == CROSS)));
            else if (optName == "Repeat Wind") lmSendConfig("canRepeat", (string)(canRepeat = (curState == CROSS)));
            else if (optName == "Carryable") lmSendConfig("canCarry", (string)(canCarry = (curState == CROSS)));
            else if (optName == "Outfitable") lmSendConfig("canDress", (string)(canDress = (curState == CROSS)));
            else if (optName == "Warnings") lmSendConfig("doWarnings", (string)(doWarnings = (curState == CROSS)));
            else if (optName == "Offline") lmSendConfig("offlineMode", (string)(offlineMode = (curState == CROSS)));
            #ifdef ADULT_MODE
            else if (optName == "Pleasure Doll") lmSendConfig("pleasureDoll", (string)(pleasureDoll = (curState == CROSS)));
            #endif
            else isFeature = 0;
                
            if (isAbility || choice == "Abilities Menu") {
                string msg = "See " + WEB_DOMAIN + "keychoices.htm for explanation. (" + OPTION_DATE + " version)";
                list pluslist;
                
                if (RLVok) {
                    // One-way options
                    pluslist += getButton("Detachable", id, detachable, 1);
                    pluslist += getButton("Flying", id, canFly, 1);
                    pluslist += getButton("Sitting", id, canSit, 1);
                    pluslist += getButton("Standing", id, canStand, 1);
                    pluslist += getButton("Self Dress", id, canWear, 1);
                    pluslist += getButton("Self TP", id, !helpless, 1);
                    pluslist += getButton("Force TP", id, autoTP, 1);
                    pluslist += getButton("Poses Silence", id, poseSilence, 1);
                }
                else {
                    msg += "\n\nDolly does not have an RLV capable viewer of has RLV turned off in her viewer settings.  There are no usable options available.";
                    pluslist = [ "OK" ];
                }
                
                llDialog(id, msg, dialogSort(pluslist + MAIN), dialogChannel);
            }
            else if (isFeature || choice == "Features Menu") {
                string msg = "See " + WEB_DOMAIN + "keychoices.htm for explanation. (" + OPTION_DATE + " version)";
                list pluslist;
                
                if (isTransformingKey) pluslist += getButton("Type Text", id, signOn, 0);
                pluslist += getButton("Quiet Key", id, quiet, 0);
                #ifdef ADULT_MODE
                pluslist += getButton("Pleasure Doll", id, pleasureDoll, 0);
                #endif
                pluslist += getButton("Warnings", id, doWarnings, 0);
                pluslist += getButton("Outfitable", id, canDress, 0);
                pluslist += getButton("Carryable", id, canCarry, 0);
                pluslist += getButton("Offline", id, offlineMode, 0);
                // One-way options
                pluslist += getButton("Allow AFK", id, canAFK, 1);
                pluslist += getButton("Repeat Wind", id, canRepeat, 1);
                
                llDialog(id, msg, dialogSort(pluslist + MAIN), dialogChannel);
            }
            
            if (isController && choice == "Drop Control") {
                integer index = llListFindList(MistressList, [ (string)id ]);
                if (index != -1) {
                    MistressList = llDeleteSubList(MistressList, index, index + 1);
                    lmSendConfig("MistressList", llDumpList2String(MistressList, "|"));
                }
            }
            
        #ifdef ADULT_MODE
            // Strip items... only for Pleasure Doll and Slut Doll Types...
            if (isCarrier || isDoll || ((numControllers != 0) && isController)) {
                if (choice == "Top") {
                    llMessageLinked(LINK_THIS, 305, llGetScriptName() + "|stripTop", id);
                }
                else if (choice == "Bra") {
                    llMessageLinked(LINK_THIS, 305, llGetScriptName() + "|stripBra", id);
                }
                else if (choice == "Bottom") {
                    llMessageLinked(LINK_THIS, 305, llGetScriptName() + "|stripBottom", id);
                }
                else if (choice == "Panties") {
                    llMessageLinked(LINK_THIS, 305, llGetScriptName() + "|stripPanties", id);
                }
                else if (choice == "Shoes") {
                    llMessageLinked(LINK_THIS, 305, llGetScriptName() + "|stripShoes", id);
                }
        
                if (llListFindList(["Top", "Bra", "Bottom", "Panties", "Shoes", "Strip"], [ choice ]) != -1)
                    // Do strip menu
                    llDialog(id, "Take off:",
                        dialogSort(["Top", "Bra", "Bottom", "Panties", "Shoes"] + MAIN),
                        dialogChannel);
            }
        #endif
        }
        
        if ((channel == blacklistChannel) || (channel == controlChannel)) {
            if (choice == MAIN) {
                lmInternalCommand("mainMenu", "", id);;
                return;
            }
            
            list tempList; integer i;
            dialogKeys = []; dialogNames = []; dialogButtons = [];
            if (channel == blacklistChannel) {
                if (blacklistHandle) {
                    llListenRemove(blacklistHandle);
                    blacklistHandle = 0;
                }
                for (i = 0; i < llGetListLength(blacklist); i++) {
                    dialogKeys += llList2Key(blacklist, i);
                    dialogNames += llList2String(blacklist, ++i);
                    dialogButtons += llGetSubString(llList2String(blacklist, i), 0, 23);
                }
            }
            else {
                if (controlHandle) {
                    llListenRemove(controlHandle);
                    controlHandle = 0;
                }
                for (i = 0; i < llGetListLength(MistressList); i++) {
                    dialogKeys += llList2Key(MistressList, i);
                    dialogNames += llList2String(MistressList, ++i);
                    dialogButtons += llGetSubString(llList2String(MistressList, i), 0, 23);
                }
            }
            
            integer index = llListFindList(dialogButtons, [ choice ]);
            string name = llList2String(dialogNames, index);
            string uuid = llList2String(dialogKeys, index);
            
            if (channel == blacklistChannel) lmInternalCommand("addRemBlacklist", (string)uuid + "|" + name, id);
            else if (index != -1) lmInternalCommand("remMistress", (string)uuid + "|" + name, id);
            else lmInternalCommand("addMistress", (string)uuid + "|" + name, id);
        }
        
        if (channel == textboxChannel) {
            if (textboxType == 1) {
                string first = llGetSubString(choice, 0, 0);
                if (first == "<") choice = (string)((vector)choice);
                else if (first == "#") choice = (string)((vector)("<0x" + llGetSubString(choice, 1, 2) + ",0x" + llGetSubString(choice, 3, 4) + ",0x" + llGetSubString(choice, 5, 6) + ">"));
                else choice = (string)((vector)("<" + choice + ">"));
                lmInternalCommand("setGemColour", choice, id);
            }
        }
        
        // Ideally the listener should be closing here and only reopened when we spawn another menu
        // other scripts also use the dialog listerner in this script.  Until they are writtent to send
        // a dialogListen command whenever they respawn a dialog we have to keep the listener open
        // at any sign of usage.
        llListenControl(dialogHandle, 1);
        llSetTimerEvent(60.0);
    }
}

