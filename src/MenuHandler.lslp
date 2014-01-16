// MenuHandler.lsl
//
// vim:sw=4 et nowrap:
//
// DATE: 10 December 2013
#include "include/GlobalDefines.lsl"

// Current Controller - or Mistress
//key MistressID = NULL_KEY;
key carrierID = NULL_KEY;
key poserID = NULL_KEY;
key dollID = NULL_KEY;

key mistressQuery;
integer mistressQueryIndex;

list windTimes = [ 30 ];

float timeLeftOnKey;
float windDefault = 1800.0;
float windRate = 1.0;
float baseWindRate = 1.0;

integer afk;
integer autoAFK = 1;
integer autoTP;
integer canAFK = 1;
integer canCarry = 1;
integer canDress = 1;
integer canFly = 1;
integer canSit = 1;
integer canStand = 1;
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

integer dialogChannel;
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

integer blacklistHandle;
list blacklist;
list blacklistNames;
list dialogKeys;
list dialogNames;
list dialogButtons;

doMainMenu(key id) {
    string msg;
    list menu =  ["Wind"];
    
    if (llListFindList(blacklist, [ (string)id ]) != -1) {
        lmSendToAgent("You are not permitted to access this key.", id);
        return;
    }

    // Compute "time remaining" message
    string timeleft;
    // Manual page
    string manpage;
    
   float displayWindRate = setWindRate();
    integer minsLeft = llRound(timeLeftOnKey / (60.0 * displayWindRate));
    
    if (minsLeft > 0) {
        timeleft = "Dolly has " + (string)minsLeft + " minutes remaining.\n";

        timeleft += "Key is ";
        if (windRate == 0.0) {
            timeleft += "not ";
        }
        timeleft += "winding down";
        
        if (windRate == 0.0) timeleft += ".";
        else timeleft += " at " + formatFloat(displayWindRate, 1) + "x rate.";

        timeleft += ". ";
    }
    else {
        timeleft = "Dolly has no time left.";
    }
    timeleft += "\n";

    // Is the doll being carried? ...and who clicked?
    if (hasCarrier) {
        // Three possibles:
        //   1. Doll
        //   2. Carrier
        //   3. Someone else

        // Doll being carried clicked on key
        if isDoll {
            msg = "You are being carried by " + carrierName + ".";
            menu = ["OK"];

            // Allows user to permit current carrier to take over and become Mistress
            if ((numControllers < MAX_USER_CONTROLLERS) && !takeoverAllowed) {
                menu += "Allow Takeover";
            }
        }

        // Doll's carrier clicked on key
        else if (isCarrier) {
            msg = "Place Down frees " + dollName + " when you are done with " + pronounHerDoll;
            menu += ["Place Down","Poses"];
            if (keyAnimation != "") {
                menu += "Unpose";
            }

            if (!isMistress) {
                if ((numControllers < MAX_USER_CONTROLLERS) && takeoverAllowed) {
                    menu += "Be Controller";
                }
                else if (numControllers < MAX_USER_CONTROLLERS) {
                    menu += "Request Control";
                }
            }

            #ifdef ADULT_MODE
            // Is doll strippable?
            if ((pleasureDoll || dollType == "Slut") && RLVok && (simRating == "MATURE" || simRating == "ADULT")) {
                menu += "Strip";
            }
            #endif
        }

        // Someone else clicked on key
        else {
            msg = dollName + " is currently being carried by " + carrierName + ". They have full control over this doll.\n";
            menu = ["OK"];
        }
    }
    else if (collapsed && isDoll) {
        msg = "You need winding.";
        menu = ["OK"];
        #ifdef TESTER_MODE
        menu += "Wind";
        #endif
        if (llGetInventoryType(LANDMARK_HOME) == INVENTORY_LANDMARK) {
            menu += "TP Home";
        }
    }
    else {    //not  being carried, not collapsed - normal in other words
        // Toucher could be...
        //   1. Doll
        //   2. Someone else

        // Is toucher the Doll?
        if (isDoll) {
            manpage = "dollkeyselfinfo.htm";
            
            menu = ["Options"];
            
            #ifdef TESTER_MODE
            #ifdef ADULT_MODE
            menu += "Strip";
            #endif
            menu += "Wind";
            #endif

            if (canAFK) {
                menu += "Toggle AFK";
            }

            if (detachable) {
                menu += "Detach";
            }

            if (visible) menu += "Invisible";
            else menu += "Visible";
        }
        else {
            manpage = "communitydoll.htm";
        
            // Toucher is not Doll.... could be anyone
            msg =  dollName + " is a doll and likes to be treated like " +
                   "a doll. So feel free to use these options.\n";
        }
               
        menu += "Help/Support";
        
        // Can the doll be dressed? Add menu button
        if (canDress || (isDoll && canWear && !wearLock)) {
            menu += "Dress";
        }
    
        // Can the doll be transformed? Add menu button
        if (isTransformingKey) {
            menu += "Type of Doll";
        }

        // Hide the general "Carry" option for all but Mistress when one exists
        if ((isController && !isDoll) || (numControllers == 0)) {
            if (canCarry) {
                msg =  msg +
                       "Carry option picks up " + dollName + " and temporarily" +
                       " makes the Dolly exclusively yours.\n";

                menu += "Carry";
            }
        }

        if (keyAnimation != "") {
            //msg += "Doll is currently in the " + currentAnimation + " pose. ";
            msg += "Doll is currently posed.\n";
        }

        if (keyAnimation != "" && (!isDoll || poserID == dollID)) menu += "Unpose";

        if (keyAnimation == "" || (!isDoll || poserID == dollID)) menu += "Poses";
    }

    // If toucher is Mistress and NOT self...
    //
    // That is, you can't be your OWN Mistress...
    if (isController && !isDoll) {
        menu += "Use Control";
    }
    
    llListenControl(dialogHandle, 1);
    llSetTimerEvent(60.0);
    
    if (!RLVok) msg += "No RLV detected some features unavailable.\n";
    
    msg += "See " + WEB_DOMAIN + manpage + " for more information." ;
    llDialog(id, timeleft + msg, menu, dialogChannel);
}

newController(key id) {
    if (carrierID) {
        if (numControllers < MAX_USER_CONTROLLERS && llListFindList(MistressList, [ (string)carrierID ]) == -1) {
            MistressList = llListSort(MistressList + [ (string)carrierID ], 1, 1);
            lmSendConfig("MistressList", llDumpList2String(MistressList, "|"));
        }
        if (isCarrier) {
            llOwnerSay("Your carrier, " + carrierName + ", has become your controller.");
        } else if (isDoll) {
            llOwnerSay("You have accepted your carrier " + carrierName + " as you controller, they now " +
                       "have complete control over dolly.");
            lmSendToAgent("The dolly " + dollName + " has fully accepted your control of them.", carrierID);
        }
        
        if (!quiet) llSay(0, carrierName + " has become controller of the doll " + dollName + ".");
    
        llOwnerSay("Your controllers are now: " + MistressNameList);
    
        // Note that the response goes to 9999 - a nonsense channel
        string msg = "You are now controller of " + dollName + ". See " + WEB_DOMAIN + "controller.htm for more information.";
        llDialog(carrierID, msg, ["OK"], 9999);
    } else {
        llOwnerSay("Unable to accept new controller as you are not currently being carried, your new Mistress needs to " +
                   "be carrying you when the request is accepted for this to work.");
    }
}

doWindMenu(key id) {
    float displayWindRate = setWindRate();
    integer minsLeft = llRound(timeLeftOnKey / (60.0 * displayWindRate));
    
    if (llListFindList(blacklist, [ (string)id ]) != -1) return;
    
    string timeleft;
    if (minsLeft > 0) {
        timeleft = "Dolly has " + (string)minsLeft + " minutes remaining.\n";

        timeleft += "Key is ";
        if (windRate == 0.0) {
            timeleft += "not ";
        }
        timeleft += "winding down";
        
        if (windRate == 0.0) timeleft += ".";
        else timeleft += " at " + formatFloat(displayWindRate, 1) + "x rate.";

        timeleft += ". ";
    }
    else {
        timeleft = "Dolly has no time left.";
    }
    timeleft += "\n";
    string msg = "How many minutes would you like to wind?";
    
    list buttons; integer i;
    for (i = 0; i < llGetListLength(windTimes); i++) {
        buttons += "Wind " + llList2String(windTimes, i);
    }
    
    if (demoMode) buttons = [ "Wind 1", "Wind 2", "Wind 5" ]; // If we are in demo mode make our buttons make sense
    
    llDialog(id, timeleft + msg, buttons, dialogChannel);
}

default
{
    state_entry() {
        dollID = llGetOwner();
        dollName = llGetDisplayName(dollID);
        lmScriptReset();
    }
    
    link_message(integer sender, integer code, string data, key id) {
        list split = llParseString2List(data, [ "|" ], []);
        
        if (code == 102) {
            if (llList2String(split, 0) == "OnlineServices") dbConfig = 1;
            else if (llList2String(split, 0) == "Start") configured = 1;
        }
        else if (code == 104 || code == 105) {
            if (llList2String(split, 0) != "Start") return;
            
            dbConfig = 0;
            
            dialogChannel = 0x80000000 | (integer)("0x" + llGetSubString((string)llGetLinkKey(2), -8, -1));
            llListenRemove(dialogHandle);
            dialogHandle = llListen(dialogChannel, "", "", "");
            
            lmInitState(code);
        }
        else if (code == 106) {
            
        }
        else if (code == 135) {
            float delay = llList2Float(split, 1);
            memReport(delay);
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
            else if (name == "afk")                               afk = (integer)value;
            else if (name == "autoTP")                         autoTP = (integer)value;
            else if (name == "canAFK")                         canAFK = (integer)value;
            else if (name == "canCarry")                     canCarry = (integer)value;
            else if (name == "canDress")                     canDress = (integer)value;
            else if (name == "canFly")                         canFly = (integer)value;
            else if (name == "canSit")                         canSit = (integer)value;
            else if (name == "canStand")                     canStand = (integer)value;
            else if (name == "configured")                 configured = (integer)value;
            else if (name == "detachable")                 detachable = (integer)value;
            else if (name == "demoMode")                     demoMode = (integer)value;
            else if (name == "helpless")                     helpless = (integer)value;
            else if (name == "pleasureDoll")             pleasureDoll = (integer)value;
            else if (name == "isTransformingKey")   isTransformingKey = (integer)value;
            else if (name == "isVisible")                     visible = (integer)value;
            else if (name == "wearLock")                     wearLock = (integer)value;
            else if (name == "quiet")                           quiet = (integer)value;
            else if (name == "signOn")                         signOn = (integer)value;
            else if (name == "takeoverAllowed")       takeoverAllowed = (integer)value;
            else if (name == "windTimes") {
                integer timesCount = llGetListLength(split);
                integer i;
                for (i = 0; i < llGetListLength(split); i++) split = llListReplaceList(split, [ llList2Integer(split, i) ], i ,i);
                split = llListSort(split, 1, 1);
                windTimes = [];
                do {
                    windTimes = llList2List(split, 0, 2) + windTimes;
                    split = llDeleteSubList(split, 0, 2);
                    //debugSay(5, "windTimes " + llList2CSV(windTimes) + "\nsplit " + llList2CSV(split));
                } while (llGetListLength(split) > 0);
            }
            else if (name == "dollType")
                dollType = llGetSubString(llToUpper(value), 0, 0) + llGetSubString(llToLower(value), 1, -1);
            else if (name == "MistressID") {
                if ((key)value != NULL_KEY && llListFindList(MistressList, [ (string)value ]) == -1) {
                    MistressList = llListSort(MistressList + [ (string)value ], 1, 1);
                    if (dbConfig) lmSendConfig("MistressList", llDumpList2String(MistressList, "|"));
                }
            }
            else if (name == "MistressList") {
                list newList = llListSort(split, 1, 1);
                //debugSay(5, "newList (" + (string)llGetListLength(newList) + ") " + llList2CSV(newList));
                if (MistressList != newList) MistressList = newList;
            }
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
            
            if (llListFindList(blacklist, [ (string)id ]) != -1) {
                lmSendToAgent("You are not permitted to access this key.", id);
                return;
            }
            else if (cmd == "mainMenu") doMainMenu(id);
            else if (cmd == "windMenu") doWindMenu(id);
        }
        else if (code == 350) {
            RLVok = llList2Integer(split, 0);
        }
    }
    
    timer() {
        llListenControl(dialogHandle, 0);
        llListenRemove(blacklistHandle);
        dialogKeys = []; dialogButtons = []; dialogNames = [];
        llSetTimerEvent(0.0);
    }
    
    sensor(integer num) {
        integer i;
        for (i = 0; i < num; i++) {
            dialogKeys += llDetectedKey(0);
            dialogNames += llGetDisplayName(llDetectedKey(0));
            dialogButtons += llGetSubString(llGetDisplayName(llDetectedKey(0)), 0, 23);
        }
    }
    
    no_sensor() {
        llDialog(llGetOwner(), "No avatars detected within chat range", [ "OK" ], 9999);
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

        debugSay(5, "Button clicked: " + choice);
        lmMenuReply(choice, name, id);
        
        if (channel == dialogChannel) {
            integer isAbility; // Temporary variables used to determine if an option
            integer isFeature; // from the features or abilities menu was clicked that 
                               // way we can restore it making setting several choices
                               // much more user friendly.
            
            if (!hasCarrier && !isDoll && choice == "Carry") {
                // Doll has been picked up...
                carrierID = id;
                carrierName = name;
                lmInternalCommand("carry", carrierName, carrierID);
                doMainMenu(id);
            }
            else if (choice == "Help/Support") {
                string msg = "Here you can find various options to get help with your " +
                            "key and to connect with the community.";
                list menu = [ "Join Group", "Visit CD Room", "Issue Tracker" ];
                if (llGetInventoryType(NOTECARD_HELP) == INVENTORY_NOTECARD) menu += "Help Notecard";
                if (isDoll) menu += [ "Reset Scripts", "Check Update" ];
                
                llListenControl(dialogHandle, 1);
                llSetTimerEvent(60.0);
                
                llDialog(id, msg, menu, dialogChannel);
            }
            else if (choice == "Help Notecard") {
                llGiveInventory(id,NOTECARD_HELP);
            }
            else if (choice == "Join Group") {
                llOwnerSay("Here is your link to the community dolls group profile secondlife:///app/group/0f0c0dd5-a611-2529-d5c7-1284fb719003/about");
                llDialog(id, "To join the community dolls group open your chat history (CTRL+H) and click the group link there.  Just click the Join Group button when the group profile opens.", [ "OK" ], 9999);
            }
            else if (choice == "Visit CD Room") {
                if (isDoll) llMessageLinked(LINK_THIS, 305, llGetScriptName() + "|TP|" + LANDMARK_CDROOM, id);
                else llGiveInventory(id, LANDMARK_CDROOM);
            }
            else if (choice == "Issue Tracker") {
                llLoadURL(id, "Visit our issue tracker to report bugs, ask questions or make suggestions and help us to create a better key for everyone.", "https://github.com/emmamei/cdkey/issues");
            }
            else if (isCarrier && choice == "Place Down") {
                // Doll has been placed down...
                llMessageLinked(LINK_THIS, 305, llGetScriptName() + "|uncarry|" + carrierName, carrierID);
                carrierID = NULL_KEY;
                carrierName = "";
            }
            else if (choice == "Type of Doll") {
                llMessageLinked(LINK_THIS, 17, name, id);
            }
            else if ((keyAnimation == "" || (!isDoll || poserID == dollID)) && llGetSubString(choice, 0, 4) == "Poses") {
                integer page = 1; integer len = llStringLength(choice);
                if (len > 5) page = (integer)llGetSubString(choice, 6 - len, -1);
                integer poseCount = llGetInventoryNumber(20);
                list poseList; integer i;
                
                llListenControl(dialogHandle, 1);
                llSetTimerEvent(60.0);
                
                for (i = 0; i < poseCount; i++) {
                    string poseName = llGetInventoryName(20, i);
                    if (poseName != ANIMATION_COLLAPSED &&
                        llGetSubString(poseName, 0, 0) != ".") {
                        if (poseName != keyAnimation) poseList += poseName;
                        else poseList += "* " + poseName;
                    }
                }
                poseCount = llGetListLength(poseList);
                if (poseCount > 12) {
                    poseList = llList2List(poseList, page * 9, (page + 1) * 9 - 1);
                    integer prevPage = page - 1;
                    integer nextPage = page + 1;
                    if (prevPage == 0) prevPage = llFloor((float)poseCount / 9.0);
                    if (nextPage > llFloor((float)poseCount / 9.0)) nextPage = 1;
                    poseList = [ "Poses " + (string)prevPage, "Main Menu", "Poses " + (string)nextPage ] + poseList;
                }
                
                llDialog(id, "Select the pose to put the doll into", poseList, dialogChannel);
            }
            else if ((!isDoll || poserID == dollID) && choice == "Unpose") {
                keyAnimation = "";
                lmInternalCommand("doUnpose", "", id);
            }
            else if (choice == "Dress") {
                if (!isDoll) llOwnerSay(name + " is looking at your dress menu");
            }
            #ifdef ADULT_MODE
            else if ((dollType == "Slut" || pleasureDoll) && choice == "Strip") {
                llDialog(id, "Take off:",
                    ["Top", "Bra", "Bottom", "Panties", "Shoes"],
                    dialogChannel);
            }
            #endif
            else if (isCarrier && takeoverAllowed && choice == "Be Controller") {
                newController(id);
            }
            else if (isCarrier && !takeoverAllowed && choice == "Request Control") {
                if (id) {
                    lmSendToAgent("You have asked " + dollName + " to grant you permanant contol of " + llToLower(pronounHerDoll) + " key. " +
                                  "If " + llToLower(pronounSheDoll) + " accepts this dolly will become yours, please wait for " + llToLower(pronounHerDoll) + " response.\n\n" +
                                  "Place the doll down before " + llToLower(pronounSheDoll) + " accepts to cancel your request.", id);
                    llDialog(dollID, name + " has requested to take permanant control of your key. " +
                             "If you accept then you will not be able to remove them yourself, become " + name + "'s dolly?",
                             [ "Accept Control", "Refuse Control" ], dialogChannel);
                }
            }
            else if (isDoll && choice == "Accept Control") {
                newController(id);
            }
            else if (isDoll && choice == "Refuse Control") {
                if (carrierID) {
                    lmSendToAgent("The dolly " + dollName + " refuses to allow you to take permanant control of " + llToLower(pronounHerDoll) + ". ", carrierID);
                }
            }
            else if (choice == "Use Control" || choice == "Options") {
                string msg = "See " + WEB_DOMAIN + "keychoices.htm for explanation. (" + OPTION_DATE + " version)";
                list pluslist;
                
                llListenControl(dialogHandle, 1);
                llSetTimerEvent(60.0);
                
                pluslist = [ "Abilities Menu", "Features Menu", "Access Menu" ];
                
                if (isController) {
                    msg = "See " + WEB_DOMAIN + "controller.htm. Choose what you want to happen. (" + OPTION_DATE + " version)";
                    pluslist += "Drop Control";
                }
                
                llDialog(id, msg, pluslist, dialogChannel);
            }
            else if (choice == "Detach")
                lmInternalCommand("detach", "", id);
            else if (choice == "Invisible") {
                lmSendConfig("visible", (string)(visible = 0));
                llSetLinkAlpha(LINK_SET, visible, ALL_SIDES);
                //llSetLinkPrimitiveParamsFast(LINK_SET, [ PRIM_GLOW, ALL_SIDES, 0.0 ]);
                llOwnerSay("Your key fades from view...");
                //doFade(LINK_THIS, 1.0, 0.0, ALL_SIDES, 0.1);
            }
            else if (choice == "Visible") {
                lmSendConfig("visible", (string)(visible = 1));integer i;
                llSetLinkAlpha(LINK_SET, visible, ALL_SIDES);
                llOwnerSay("Your key appears magically.");
                //doFade(LINK_THIS, 0.0, 1.0, ALL_SIDES, 0.1);
            }
            else if (choice == "Reload Config") {
                llResetOtherScript("Start");
            }
            else if (choice == "TP Home") {
                lmInternalCommand("TP", LANDMARK_HOME, id);
            }
            else if (choice == "Toggle AFK") {
                afk = !afk;
                float displayWindRate = setWindRate();
                integer minsLeft = llRound(timeLeftOnKey / (60.0 * displayWindRate));
                lmInternalCommand("setAFK", (string)afk + "|0|" + formatFloat(windRate, 1) + "|" + (string)minsLeft, id);
            }
            else if (choice == "Access Menu") {
                string msg = "Manage key access options. (" + OPTION_DATE + " version)";
                list pluslist;
                
                if (llGetListLength(blacklist) < 12) pluslist += [ "✔ Blacklist" ];
                else pluslist += [ "﻿" ];
                if (llGetListLength(blacklist) > 0) pluslist += [ "✘ Blacklist", "List Blacklist" ];
                else pluslist += [ "﻿", "﻿" ];
                
                llDialog(id, msg, pluslist, dialogChannel);
            }
            else if (choice == "✔ Blacklist") {
                llSensor("", "", AGENT, 20.0, TWO_PI);
            }
            else if (choice == "✘ Blacklist") {
                string msg = "Choose a person to remove from blacklist";
                integer i; dialogButtons = [];
                for (i = 0; i < llGetListLength(blacklistNames); i++) {
                    dialogButtons += llGetSubString(llList2String(blacklistNames, i), 0, 23);
                }
                dialogNames = blacklistNames;
                blacklistHandle = llListen(dialogChannel + 1, "", "", "");
                llDialog(id, msg, dialogButtons, dialogChannel + 1);
                llSetTimerEvent(60.0);
            }
            else if (choice == "List Blacklist") {
                integer i; string output = "Blacklisted Avatars:";
                do {
                    output += "\n" + (string)(i + 1) + ". " + llList2String(blacklistNames, i++);
                } while (i < llGetListLength(blacklist));
                llOwnerSay(output);
            }
            
            // Entering options menu section
            
            // Entering abilities menu section
            isAbility = 1;
            if (choice == "No Detaching")
                lmSendConfig("detachable", (string)(detachable = 0));
            else if (isController && choice == "Detachable") 
                lmSendConfig("detachable", (string)(detachable = 1));
            else if (choice == "Auto TP")
                lmSendConfig("autoTP", (string)(autoTP = 1));
            else if (isController && choice == "No Auto TP")
                lmSendConfig("autoTP", (string)(autoTP = 0));
            else if (choice == "No Self TP")
                lmSendConfig("helpless", (string)(helpless = 1));
            else if (isController && choice == "Self TP")
                lmSendConfig("helpless", (string)(helpless = 0));
            else if (choice == "No Flying")
                lmSendConfig("canFly", (string)(canFly = 0));
            else if (isController && choice == "Can Fly")
                lmSendConfig("canFly", (string)(canFly = 1));
            else if (choice == "No Sitting")
                lmSendConfig("canSit", (string)(canSit = 0));
            else if (isController && choice == "Can Sit")
                lmSendConfig("canSit", (string)(canSit = 1));
            else if (choice == "No Standing")
                lmSendConfig("canStand", (string)(canStand = 0));
            else if (isController && choice == "Can Stand")
                lmSendConfig("canStand", (string)(canStand = 1));
            else isAbility = 0; // Not an options menu item after all
                
            isFeature = 1; // Maybe it'a a features menu item
            if (choice == "Turn Off Sign")
                lmSendConfig("signOn", (string)(signOn = 0));
            else if (choice == "Turn On Sign")
                lmSendConfig("signOn", (string)(signOn = 1));
            else if (choice == "No AFK")
                lmSendConfig("canAFK", (string)(canAFK = 0));
            else if (isController && choice == "Can AFK")
                lmSendConfig("canAFK", (string)(canAFK = 1));
            else if (choice == "Can Carry") {
                llOwnerSay("Other people can now carry you.");
                lmSendConfig("canCarry", (string)(canCarry = 1));
            }
            else if (choice == "No Carry") {
                llOwnerSay("Other people can no longer carry you.");
                lmSendConfig("canCarry", (string)(canCarry = 0));
            }
            else if (choice == "Can Outfit") {
                llOwnerSay("Other people can now outfit you.");
                lmSendConfig("canDress", (string)(canDress = 1));
            }
            else if (choice == "No Outfitting") {
                llOwnerSay("Other people can no longer outfit you.");
                lmSendConfig("canDress", (string)(canDress = 0));
            }
            else if (isController & choice == "Can Dress Self") {
                llOwnerSay("You are now able to change your own outfits again.");
                lmSendConfig("canWear", (string)(canWear = 1));
            }
            else if (choice == "No Dress Self") {
                llOwnerSay("You are just a dolly and can no longer dress or undress by yourself.");
                lmSendConfig("canWear", (string)(canWear = 0));
            }
            else if (isDoll && choice == "Allow Takeover") {
                llOwnerSay("Anyone carrying you may now choose to be your controller.");
                if (hasCarrier) {
                    lmSendToAgent(dollName + " seems willing to let you take permanant control of " + llToLower(pronounHerDoll) + " key now. " +
                                    "Maybe you could claim " + dollName + " as your own? (Be Controller from the menu).", carrierID);
                }
                lmSendConfig("takeoverAllowed", (string)(takeoverAllowed = 1));
            }
            else if (isDoll && choice == "No Takeover") {
                llOwnerSay("There is now no way for someone to become your controller.");
                lmSendConfig("takeoverAllowed", (string)(takeoverAllowed = 0));
            }
            else if (choice == "No Warnings") {
                llOwnerSay("No warnings will be given when time remaining is low.");
                lmSendConfig("doWarnings", (string)(doWarnings = 0));
            }
            else if (choice == "Warnings") {
                llOwnerSay("Warnings will now be given when time remaining is low.");
                lmSendConfig("doWarnings", (string)(doWarnings = 1));
            }
            else if (choice == "Offline Mode") {
                llOwnerSay("Key now working in offline mode setting changes will no longer be backed up.");
                lmSendConfig("offlineMode", (string)(offlineMode = 1));
            }
            else if (choice == "Online Mode") {
                llOwnerSay("Key now working in online mode settings will be backed up online and automatically shared between your keys.");
                lmSendConfig("offlineMode", (string)(offlineMode = 0));
            }
            #ifdef ADULT_MODE
            else if (choice == "Pleasure Doll") {
                llOwnerSay("You are now a pleasure doll.");
                lmSendConfig("pleasureDoll", (string)(pleasureDoll = 0));
            }
            else if (choice == "No Pleasure") {
                llOwnerSay("You are no longer a pleasure doll.");
                lmSendConfig("pleasureDoll", (string)(pleasureDoll = 1));
            }
            #endif
            else isFeature = 0;
                
            if (isAbility || choice == "Abilities Menu") {
                string msg = "See " + WEB_DOMAIN + "keychoices.htm for explanation. (" + OPTION_DATE + " version)";
                list pluslist;
                
                llListenControl(dialogHandle, 1);
                llSetTimerEvent(60.0);
                
                // One-way option
                if (detachable) pluslist += "No Detaching";
                else if (isController) pluslist += "Detachable";
                
                // One-way option
                if (canSit) pluslist += "No Sitting";
                else if (isController) pluslist += "Can Sit";
                
                // One-way option
                if (canStand) pluslist += "No Standing";
                else if (isController) pluslist += "Can Stand";
                
                // One-way option
                if (!autoTP) pluslist += "Auto TP";
                else if (isController) pluslist += "No Auto TP";
                
                // One way option
                if (canWear) pluslist += "No Dress Self";
                else if (isController) pluslist += "Can Dress Self";
                
                // One-way option
                if (!helpless) pluslist += "No Self TP";
                else if (isController) pluslist += "Self TP";
                
                // One-way option
                if (canFly) pluslist += "No Flying";
                else if (isController) pluslist += "Can Fly";
                
                llDialog(id, msg, pluslist, dialogChannel);
            }
            else if (isFeature || choice == "Features Menu") {
                string msg = "See " + WEB_DOMAIN + "keychoices.htm for explanation. (" + OPTION_DATE + " version)";
                list pluslist;
                
                llListenControl(dialogHandle, 1);
                llSetTimerEvent(60.0);
                
                if (isTransformingKey) {
                    if (signOn) pluslist += "Turn Off Sign";
                    else pluslist += "Turn On Sign";
                }
                
                if (isDoll && (numControllers < MAX_USER_CONTROLLERS)) {
                    if (takeoverAllowed) pluslist += "No Takeover";
                    else pluslist += "Allow Takeover";
                }
                
                #ifdef ADULT_MODE
                if (pleasureDoll) pluslist += "No Pleasure";
                else pluslist += "Pleasure Doll";
                #endif
                
                if (doWarnings) pluslist += "No Warnings";
                else pluslist += "Warnings";
                
                if (!canDress) pluslist += "Can Outfit";
                else pluslist += "No Outfitting";
            
                if (!canCarry) pluslist += "Can Carry";
                else pluslist += "No Carry";
                
                if (isDoll && !offlineMode) pluslist += "Offline Mode";
                else if (isDoll) pluslist += "Online Mode";
                
                llDialog(id, msg, pluslist, dialogChannel);
            }
            
            if (isController && choice == "Drop Control") {
                integer index = llListFindList(MistressList, [ id ]);
                if (index != -1) {
                    MistressList = llDeleteSubList(MistressList, index, index);
                    lmSendConfig("MistressList", llDumpList2String(MistressList, "|"));
                }
            }
            if ((keyAnimation == "" || (!isDoll || poserID == dollID)) && llGetInventoryType(choice) == 20) {
                keyAnimation = choice;
                lmInternalCommand("setPose", choice, id);
                poserID = id;
            }
            else if ((keyAnimation == "" || (!isDoll || poserID == dollID)) && llGetInventoryType(llGetSubString(choice, 2, -1)) == 20) {
                keyAnimation = llGetSubString(choice, 2, -1);
                lmInternalCommand("setPose", llGetSubString(choice, 2, -1), id);
                poserID = id;
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
                        ["Top", "Bra", "Bottom", "Panties", "Shoes"],
                        dialogChannel);
            }
        #endif
        }
        else if (channel == (dialogChannel + 1)) {
            llListenRemove(blacklistHandle);
            
            if (dialogNames == blacklistNames) {
                integer index = llListFindList(dialogButtons, [ choice ]);
                if (index != -1) {
                    blacklist = llDeleteSubList(blacklist, index, index);
                    blacklistNames = llDeleteSubList(blacklistNames, index, index);
                    llOwnerSay("Successfully removed " + llList2String(dialogNames, index) + " from Blacklist");
                }
            }
            else {
                integer index = llListFindList(dialogButtons, [ choice ]);
                string name = llList2String(dialogNames, index);
                if (llListFindList(blacklistNames, [ name ]) == -1) {
                    blacklist += llList2String(dialogKeys, index);
                    blacklistNames += name;
                    llOwnerSay("Successfully added " + name + " to blacklist.");
                }
                else llOwnerSay(name + " is already on the blacklist.");
                dialogKeys = []; dialogButtons = []; dialogNames = [];
            }
            lmSendConfig("blacklist", llDumpList2String(blacklist, "|"));
            lmSendConfig("blacklistNames", llDumpList2String(blacklistNames, "|"));
        }
        
        // Ideally the listener should be closing here and only reopened when we spawn another menu
        // other scripts also use the dialog listerner in this script.  Until they are writtent to send
        // a dialogListen command whenever they respawn a dialog we have to keep the listener open
        // at any sign of usage.
        llListenControl(dialogHandle, 1);
        llSetTimerEvent(60.0);
    }
    
    /*dataserver(key query_id, string data) {
        if (query_id == mistressQuery) {
            MistressNameList = llListReplaceList(MistressNameList, [ data ], mistressQueryIndex, mistressQueryIndex);
            
            if (++mistressQueryIndex < numControllers) {
                mistressQuery = llRequestDisplayName(llList2Key(MistressList, mistressQueryIndex));
            }
            else {
                llOwnerSay("Your controllers are now: " + llList2CSV(MistressNameList));
            }
        }
    }*/
}

