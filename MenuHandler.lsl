// MenuHandler.lsl
// DATE: 10 December 2013

// Keys of important people in life of the Key:
key MasterBuilder = "42c7aaec-38bc-4b0c-94dd-ae562eb67e6d";   // Christina Halpin
key        DevOne = "c5e11d0a-694f-46cc-864b-e42340890934";   // MayStone
key        DevTwo = "2fff40f0-ea4a-4b52-abb8-d4bf6b1c98c9";   // Silky Mesmeriser

// Current Controller - or Mistress
key MistressID = MasterBuilder;
key carrierID;
key dollID;

key mistressQuery;

list developerList = [ DevOne, DevTwo ];

// Add keys here to enable Tester facilities
list testerList = [ DevOne, DevTwo ];

float timeLeftOnKey;
float windRate = 1.0;

string httpstart = "http://communitydolls.com/";

string ANIMATION_COLLAPSED = "collapse";
string NOTECARD_HELP = "Community Dolls Key Help and Manual";
string LANDMARK_HOME = "Home";
string LANDMARK_CDROOM = "Community Dolls Room";
float RATE_STANDARD = 1.0;
float RATE_AFK = 0.5;

integer dialogChannel;
integer dialogHandle;
integer carried;
string dollName;
string dollType = "Regular";
integer collapsed;

integer configured;
integer visible = 1;
integer signOn;
integer detachable = 1;
integer autoTP;
integer pleasureDoll;
integer helpless;
integer canFly = 1;
integer hasController;
integer windDown = 1;
integer isTransformingKey;
integer afk;
integer autoAFK;
integer warned;
integer doWarnings;
integer canSit = 1;
integer canAFK = 1;
integer canDress = 1;
integer canStand = 1;
integer canCarry = 1;
integer quiet;
integer takeoverAllowed;

integer pose;

string carrierName;
string mistressName;
string simRating;
string keyAnimation;
string optiondate;

integer RLVok;

integer devKey() {
    if (dollID != llGetOwner()) dollID = llGetOwner();
    return llListFindList(developerList, [ dollID ]) != -1;
}

integer testerKey() {
    if (dollID != llGetOwner()) dollID = llGetOwner();
    return llListFindList(testerList, [ dollID ]) != -1;
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

setDollType(string choice) {
    // Pre-conversion... restore settings as needed

    // change to new Doll Type
    dollType = llGetSubString(llToUpper(choice), 0, 0) + llGetSubString(llToLower(choice), 1, -1);
}

processConfiguration(string name, list values) {
    if (name == "helpless dolly") {
        helpless = llList2Integer(values, 0);
    }
    else if (name == "controller") {
        MistressID = llList2Key(values, 0);
        llMessageLinked(LINK_SET, 300, "MistressID", MistressID);
        hasController = 1;
        takeoverAllowed = 0; // there is a Mistress; takeover is irrelevant
    }
    else if (name == "auto tp") {
        autoTP = llList2Integer(values, 0);
    }
    else if (name == "pleasure doll") {
        pleasureDoll = llList2Integer(values, 0);
    }
    else if (name == "detachable") {
        detachable = llList2Integer(values, 0);
    }
    else if (name == "outfitable") {
        canDress = llList2Integer(values, 0);
        if (RLVok && !canDress) llOwnerSay("Other people cannot outfit you.");
    }
    else if (name == "can fly") {
        canFly = llList2Integer(values, 0);
    }
    else if (name == "can sit") {
        canSit = llList2Integer(values, 0);
    }
    else if (name == "can stand") {
        canStand = llList2Integer(values, 0);
    }
    else if (name == "quiet key") {
        quiet = llList2Integer(values, 0);
    }
}

aoControl(integer on) {
    integer LockMeisterChannel = -8888;

    if (on) llWhisper(LockMeisterChannel, (string)dollID + "booton");
    else    llWhisper(LockMeisterChannel, (string)dollID + "bootoff");
}

doMainMenu(key id) {
    string msg;
    list menu = ["Wind"];

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

        if (windRate == 1.0) timeleft += ".";
        else timeleft += " at " + formatFloat(displayWindRate, 1) + "x rate.";

        timeleft += ". ";
    }
    else {
        timeleft = "Dolly has no time left.";
    }
    timeleft += "\n";

    // Can the doll be dressed? Add menu button
    if (canDress) menu += "Dress";

    // Can the doll be transformed? Add menu button
    if (isTransformingKey) menu += "Type of Doll";

    // Is the doll being carried? ...and who clicked?
    if (carried) {
        // Three possibles:
        //   1. Doll
        //   2. Carrier
        //   3. Someone else

        // Doll being carried clicked on key
        if (id == dollID) {
            msg = "You are being carried by " + carrierName + ".";
            menu = ["OK"];

            // Allows user to permit current carrier to take over and become Mistress
            if (!hasController) {
                if (!takeoverAllowed) {
                    menu += "Allow Takeover";
                }
            }
        }

        // Doll's carrier clicked on key
        else if (id == carrierID) {
            msg = "Place Down frees " + dollName + " when you are done with her";
            menu += ["Place Down","Pose"];
            if (pose) menu += "Unpose";

            if (!hasController) {
                if (takeoverAllowed) menu += "Be Controller";
            }

            // Is doll strippable?
            if ((pleasureDoll || dollType == "Slut") && RLVok && (simRating == "MATURE" || simRating == "ADULT")) menu += "Strip";
        }

        // Someone else clicked on key
        else {
            msg = dollName + " is currently being carried by " + carrierName + ". They have full control over this doll.\n";
            menu = ["OK"];
        }
    }
    else if (collapsed) {
        if (id == dollID) {
            msg = "You need winding.";
            menu = ["OK"];
        }
    }
    else {    //not  being carried, not collapsed - normal in other words
        // Toucher could be...
        //   1. Doll
        //   2. Someone else

        // Is toucher the Doll?
        if (id == dollID) {
            manpage = "dollkeyselfinfo.htm";

            menu = ["Dress","Options"];
            if (testerKey()) menu += ["Strip","Wind"];

            if (canAFK) menu += "Toggle AFK";

            if (detachable) menu += "Detach";

            if (visible) menu += "Invisible";
            else         menu += "Visible";

            if (llGetInventoryType(LANDMARK_HOME) == INVENTORY_LANDMARK) {
               menu += "TP Home";
            }

            if (isTransformingKey) menu += "Type of Doll";
        }
        else {
            manpage = "communitydoll.htm";

            // Toucher is not Doll.... could be anyone
            msg =  dollName + " is a doll and likes to be treated like " +
                   "a doll. So feel free to use these options.\n";
        }

        menu += "Help/Support";

        // Hide the general "Carry" option for all but Mistress when one exists
        if (((id == MistressID) || !hasController) && id != dollID) {
            if (canCarry) {
                msg =  msg +
                       "Carry option picks up " + dollName + " and temporarily" +
                       " makes the Dolly exclusively yours.\n";

                menu += "Carry";
            }
        }

        if (pose) {
            //msg += "Doll is currently in the " + currentAnimation + " pose. ";
            msg += "Doll is currently posed.\n";
        }

        if (pose) menu += "Unpose";

        menu += "Pose";
    }

    // If toucher is Mistress and NOT self...
    //
    // That is, you can't be your OWN Mistress...
    if ((id == MistressID) && (id != dollID)) {
        menu += "Use Control";

        if (llGetInventoryType(LANDMARK_HOME) == INVENTORY_LANDMARK) menu += "TP Home";
    }

    msg += "See " + httpstart + manpage + " for more information." ;
    llDialog(id, timeleft + msg, menu, dialogChannel);
}

doHelpMenu(key id) {
    string msg = "Here you can find various options to get help with your " +
                "key and to connect with the community.";
    list menu;

    menu += [ "Report Bug", "Ask Question", "Suggestions" ];
    if (llGetInventoryType(NOTECARD_HELP) == INVENTORY_NOTECARD) menu += "Help Notecard";
    menu += [ "Join Group", "Visit CD Room" ];

    llDialog(id, msg, menu, dialogChannel);
}

doOptionsMenu(key id) {
    integer controller;
    if ((id == MistressID) && (id != dollID)) controller = 1;

    string msg = "See " + httpstart + "keychoices.htm for explanation. (" + optiondate + " version)";
    list pluslist;

    if (controller) {
        msg = "See " + httpstart + "controller.htm. Choose what you want to happen. (" + optiondate + " version)";
        pluslist += "drop control";
    }

    if (!canDress) pluslist += "can outfit";
    else pluslist += "no outfitting";

    if (!canCarry) pluslist += "can carry";
    else pluslist += "no carry";

    // One-way option
    if (detachable) pluslist += "no detaching";
    else if (controller) pluslist += "detachable";

    if (doWarnings) pluslist += "no warnings";
    else pluslist += "warnings";

    if (canSit) pluslist += "no sitting";
    else pluslist += "can sit";

    // One-way option
    if (!autoTP) pluslist += "auto tp";
    else if (controller) pluslist += "no auto tp";

    // One-way option
    if (!helpless) pluslist += "no self tp";
    else if (controller) pluslist += "self tp";

    // One-way option
    if (canFly) pluslist += "no flying";
    else if (controller) pluslist += "can fly";

    if (pleasureDoll) pluslist += "no pleasure";
    else pluslist += "pleasure doll";

    if (!hasController) {
        if (takeoverAllowed) pluslist += "no takeover";
        else pluslist += "allow takeover";
    }

    if (isTransformingKey) {
        if (signOn) pluslist += "turn off sign";
        else pluslist += "turn on sign";
    }

    llDialog(id, msg, pluslist, dialogChannel);
}

handlemenuchoices(string choice, string name, key id) {
    integer doll = (id == dollID);
    integer carrier = (id == carrierID && !doll);
    integer controller = (id == MistressID && !doll);

    if (choice == "Dress")
        llMessageLinked(LINK_SET, 500, "Dress", id);
    else
        llMessageLinked(LINK_SET, 500, choice + "|" + name, id);

    if (!carried && !doll && choice == "Carry") {
        // Doll has been picked up...
        carried = 1;
        carrierID = id;
        carrierName = name;
        llMessageLinked(LINK_SET, 305, llGetScriptName() + "|carry|" + carrierName, carrierID);
    }
    else if (choice == "Help/Support") { doHelpMenu(id); }
    else if (choice == "Help Notecard") { llGiveInventory(id,NOTECARD_HELP); }
    else if (choice == "Join Group") {
        llOwnerSay("Here is your link to the community dolls group profile secondlife:///app/group/0f0c0dd5-a611-2529-d5c7-1284fb719003/about");
        llDialog(id, "To join the community dolls group open your chat history (CTRL+H) and click the group link there.  Just click the Join Group button when the group profile opens.", [ "OK" ], 9999);
    }
    else if (choice == "Visit CD Room") {
        if (id == dollID) llMessageLinked(LINK_SET, 305, llGetScriptName() + "|TP|" + LANDMARK_CDROOM, id);
        else llGiveInventory(id, LANDMARK_CDROOM);
    }
    else if (choice == "Report Bug" || choice == "Ask Question" || choice == "Suggestions") {
        llLoadURL(id, "Visit our issues page to report bugs, ask questions or post any suggestions you may have.", "https://github.com/emmamei/cdkey/issues");
    }
    else if (carried && carrier && choice == "Place Down") {
        // Doll has been placed down...
        llMessageLinked(LINK_SET, 305, llGetScriptName() + "|uncarry|" + carrierName, carrierID);
        carried = 0;
        carrierID = NULL_KEY;
        carrierName = "";
    }
    else if (choice == "Type of Doll") { llMessageLinked(LINK_SET, 17, name, id); }
    else if ((!pose || !doll) && choice == "Pose") { llMessageLinked(LINK_SET, 22, "menu", id); }
    else if ((pose && !doll) && choice == "Unpose") {
        //doUnpose(ToucherID);
        pose = 0;
        //aoChange("on");
    }
    else if (doll && choice == "Allow Takeover") {
        llMessageLinked(LINK_SET, 300, "takeoverAllowed|" + (string)(takeoverAllowed = 1), id);
    }
    else if ((!doll || testerKey()) && choice == "Wind") {
        //llSay(DEBUG_CHANNEL, "+> Wind");
        //llSay(DEBUG_CHANNEL, "+> Done Wind");
        doMainMenu(id);
    }
    else if (choice == "Dress") {
        //llMessageLinked(LINK_SET, 1, "start", id);
        //llMessageLinked(LINK_SET, 500, choice + "|" + name, id);
        if (!doll) llOwnerSay(name + " is looking at your dress menu");
    }
    else if (choice == "Strip") {
        llDialog(id, "Take off:",
            ["Top", "Bra", "Bottom", "Panties", "Shoes"],
            dialogChannel);
    }
    else if (choice == "Be Controller") {
        llMessageLinked(LINK_SET, 300, "takeoverAllowed|" + (string)(takeoverAllowed = 0), id);
        llMessageLinked(LINK_SET, 300, "hasController|" + (string)(hasController = 1), id);

        llMessageLinked(LINK_SET, 300, "MistressID|" + (string)(MistressID = id), id);

        // Mistress is present: use llKey2Name()
        llMessageLinked(LINK_SET, 300, "mistressName|" + (string)(mistressName = name), id);

        llOwnerSay("Your carrier, " + mistressName + ", has become your controller.");
        if (!quiet) llSay(0, mistressName + " has become controller of the doll " + dollName + ".");

        // Note that the response goes to 9999 - a nonsense channel
        string msg = "You are now controller of " + dollName + ". See " + httpstart + "controller.htm for more information.";
        llDialog(id, msg, ["OK"], 9999);
    }
    else if (choice == "Use Control" || choice == "Options") {
        doOptionsMenu(id);
    }
    else if (choice == "Detach") {
        //aoChange("on");
        if (RLVok) llMessageLinked(LINK_SET, 305, llGetScriptName() + "|detach", id);
        else llDetachFromAvatar();
    }
    else if (choice == "Invisible") {
        llMessageLinked(LINK_SET, 300, "visible|" + (string)(visible = 0), id);
        llSetLinkAlpha(LINK_SET, 0, ALL_SIDES);
        llOwnerSay("Your key fades from view...");
        //doFade(LINK_SET, 1.0, 0.0, ALL_SIDES, 0.1);
    }
    else if (choice == "Visible") {
        llMessageLinked(LINK_SET, 300, "visible|" + (string)(visible = 1), id);
        llSetLinkAlpha(LINK_SET, 1, ALL_SIDES);
        llOwnerSay("Your key appears magically.");
        //doFade(LINK_SET, 0.0, 1.0, ALL_SIDES, 0.1);
    }
    else if (choice == "Reload Config") { llResetScript(); }
    else if (choice == "TP Home") {
        llMessageLinked(LINK_SET, 305, llGetScriptName() + "|TP|" + LANDMARK_HOME, id);
    }
    else if (choice == "Toggle AFK") {
        afk = (!afk);
        if (afk) llSetText(dollType + " Doll (AFK)", <1,1,0>, 1);
        else if (signOn) llSetText(dollType + " Doll", <1,1,1>, 1);
        else llSetText("", <1,1,1>, 1);

        float displayWindRate = setWindRate();
        integer minsLeft = llRound(timeLeftOnKey / (60.0 * displayWindRate));
        llMessageLinked(LINK_SET, 305, llGetScriptName() + "|setAFK|" + (string)afk + "|0|" + formatFloat(displayWindRate, 1) + "|" + (string)minsLeft, id);
    }
    else if (choice == "no detaching") llMessageLinked(LINK_SET, 300, "detachable|" + (string)(detachable = 0), id);
    else if (controller && choice == "detachable") llMessageLinked(LINK_SET, 300, "detachable|" + (string)(detachable = 1), id);

    else if (choice == "auto tp") llMessageLinked(LINK_SET, 300, "autoTP|" + (string)(autoTP = 1), id);
    else if (controller && choice == "no auto tp") llMessageLinked(LINK_SET, 300, "autoTP|" + (string)(autoTP = 0), id);

    else if (choice == "pleasure doll") {
        llOwnerSay("You are now a pleasure doll.");
        llMessageLinked(LINK_SET, 300, "pleasureDoll|" + (string)(pleasureDoll = 1), id);
    }
    else if (choice == "not pleasure") {
        llOwnerSay("You are no longer a pleasure doll.");
        llMessageLinked(LINK_SET, 300, "pleasureDoll|" + (string)(pleasureDoll = 0), id);
    }
    else if (choice == "no self tp") llMessageLinked(LINK_SET, 300, "helpless|" + (string)(helpless = 1), id);
    else if (controller && choice == "can travel") llMessageLinked(LINK_SET, 300, "helpless|" + (string)(helpless = 0), id);

    else if (choice == "can carry") {
        llOwnerSay("Other people can now carry you.");
        llMessageLinked(LINK_SET, 300, "canCarry|" + (string)(canCarry = 1), id);
    }
    else if (choice == "no carry") {
        llOwnerSay("Other people can no longer carry you.");
        llMessageLinked(LINK_SET, 300, "canCarry|" + (string)(canCarry = 0), id);
    }
    else if (choice == "can outfit") {
        llOwnerSay("Other people can now outfit you.");
        llMessageLinked(LINK_SET, 300, "canDress|" + (string)(canDress = 1), id);
    }
    else if (choice == "no outfitting") {
        llOwnerSay("Other people can no longer outfit you.");
        llMessageLinked(LINK_SET, 300, "canDress|" + (string)(canDress = 0), id);
    }
    else if (choice == "no takeover") {
        llOwnerSay("There is now no way for someone to become your controller.");
        llMessageLinked(LINK_SET, 300, "takeoverAllowed|" + (string)(takeoverAllowed = 0), id);
    }
    else if (choice == "allow takeover") {
        llOwnerSay("Anyone carrying you may now choose to be your controller.");
        llMessageLinked(LINK_SET, 300, "takeoverAllowed|" + (string)(takeoverAllowed = 1), id);
    }
    else if (choice == "no warnings") {
        llOwnerSay("No warnings will be given when time remaining is low.");
        llMessageLinked(LINK_SET, 300, "doWarnings|" + (string)(doWarnings = 0), id);
    }
    else if (choice == "warnings") {
        llOwnerSay("Warnings will now be given when time remaining is low.");
        llMessageLinked(LINK_SET, 300, "doWarnings|" + (string)(doWarnings = 1), id);
    }
    else if (choice == "no flying") llMessageLinked(LINK_SET, 300, "canFly|" + (string)(canFly = 0), id);
    else if (controller && choice == "can fly") llMessageLinked(LINK_SET, 300, "canFly|" + (string)(canFly = 1), id);

    else if (choice == "turn off sign") {
        // erase sign
        llSetText("", <1,1,1>, 1);
        llMessageLinked(LINK_SET, 300, "signOn|" + (string)(signOn = 0), id);
    }
    else if (choice == "turn on sign") {
        // set sign
        llSetText(dollType, <1,1,1>, 1);
        llMessageLinked(LINK_SET, 300, "signOn|" + (string)(signOn = 1), id);
    }
    else if (choice == "no AFK")
        llMessageLinked(LINK_SET, 300, "canAFK|" + (string)(canAFK = 0), id);
    else if (controller && choice == "can AFK")
        llMessageLinked(LINK_SET, 300, "canAFK|" + (string)(canAFK = 1), id);
    else if (controller && choice == "drop control") {
        llMessageLinked(LINK_SET, 300, "MistressID|" + (string)(MistressID = MasterBuilder), id);
        llMessageLinked(LINK_SET, 300, "hasController|" + (string)(hasController = 0), id);
    }

    // Strip items... only for Pleasure Doll and Slut Doll Types...
    if (id == carrierID || id == dollID || (hasController && id == MistressID)) {
        if (choice == "Top") { llMessageLinked(LINK_SET, 305, llGetScriptName() + "|stripTop", id); }
        else if (choice == "Bra") { llMessageLinked(LINK_SET, 305, llGetScriptName() + "|stripBra", id); }
        else if (choice == "Bottom") { llMessageLinked(LINK_SET, 305, llGetScriptName() + "|stripBottom", id); }
        else if (choice == "Panties") { llMessageLinked(LINK_SET, 305, llGetScriptName() + "|stripPanties", id); }
        else if (choice == "Shoes") { llMessageLinked(LINK_SET, 305, llGetScriptName() + "|stripShoes", id); }

        if (llListFindList(["Top", "Bra", "Bottom", "Panties", "Shoes", "Strip"], [ choice ]) != -1)
            // Do strip menu
            llDialog(id, "Take off:",
                ["Top", "Bra", "Bottom", "Panties", "Shoes"],
                dialogChannel);
    }
}

float setWindRate() {
    float newWindRate = RATE_STANDARD;
    integer attached = llGetAttached() == ATTACH_BACK;
    integer windDown = !(!attached || collapsed || (dollType == "Builder" || dollType == "Key"));
    if (afk) newWindRate *= RATE_AFK;

    if (windRate != (newWindRate * (float)windDown)) {
        if (windRate == 0.0) llResetTime();
        windRate = newWindRate * (float)windDown;
    }

    return newWindRate;
}

default
{
    state_entry() {
        dollID = llGetOwner();
        dollName = llGetDisplayName(dollID);
        llMessageLinked(LINK_SET, 999, llGetScriptName(), NULL_KEY);
    }

    link_message(integer sender, integer num, string data, key id) {
        list parameterList = llParseString2List(data, [ "|" ], []);

        // 16: Change Key Type: transforming: choice = Doll Type
        if (num == 16) {
            setDollType(llList2String(parameterList, 0));
        }

        // 18: Convert to Transforming Key
        else if (num == 18) { isTransformingKey = 1; }

        else if (num == 101) {
            string name = llList2String(parameterList, 0);
            list params = llList2List(parameterList, 1, -1);

            if (!configured) processConfiguration(name, params);
        }
        else if (num == 104 || num == 105) {
            dialogChannel = 0x80000000 | (integer)("0x" + llGetSubString((string)llGetLinkKey(2), -9, -1));
            llListenRemove(dialogHandle);
            dialogHandle = llListen(dialogChannel, "", "", "");

            llMessageLinked(LINK_SET, 103, llGetScriptName(), NULL_KEY);
        }
        else if (num == 106) {

        }
        else if (num == 135) memReport();
        else if (num == 300) {
            list split = llParseString2List(data, [ "|" ], []);
            string name = llList2String(split, 0);
            string value = llList2String(split, 1);

            if (name == "detachable") detachable = (integer)value;
            else if (name == "autoTP") autoTP = (integer)value;
            else if (name == "pleasureDoll") pleasureDoll = (integer)value;
            else if (name == "helpless") helpless = (integer)value;
            else if (name == "canCarry") canCarry = (integer)value;
            else if (name == "canDress") canDress = (integer)value;
            else if (name == "canStand") canStand = (integer)value;
            else if (name == "canSit") canSit = (integer)value;
            else if (name == "canFly") canFly = (integer)value;
            else if (name == "takeoverAllowed") takeoverAllowed = (integer)value;
            else if (name == "doWarnings") doWarnings = (integer)value;
            else if (name == "signOn") signOn = (integer)value;
            else if (name == "canAFK") canAFK = (integer)value;
            else if (name == "mistressName") mistressName = value;
            else if (name == "timeLeftOnKey") timeLeftOnKey = (float)value;
            else if (name == "MistressID") {
                MistressID = (key)value;
                hasController = !(MistressID == MasterBuilder);
                mistressQuery = llRequestDisplayName(MistressID);
            }
        }
        else if (num == 305) {
            list split = llParseString2List(data, [ "|" ], []);
            string script = llList2String(split, 0);
            string cmd = llList2String(split, 1);
            split = llList2List(split, 2, -1);

            if (cmd == "carry") {
                // Doll has been picked up...
                carried = 1;
                carrierID = id;
                carrierName = llList2String(split, 0);
            }
            else if (cmd == "uncarry") {
                // Doll has been placed down...
                carried = 0;
                carrierID = NULL_KEY;
                carrierName = "";
            }
            else if (cmd == "setAFK") {
                afk = llList2Integer(split, 0);
                integer autoSet = llList2Integer(split, 1);

                if (!autoSet) {
                    integer agentInfo = llGetAgentInfo(dollID);
                    if ((agentInfo & AGENT_AWAY) && afk) autoAFK = 1;
                    else if (!(agentInfo & AGENT_AWAY) && !afk) autoAFK = 1;
                    else autoAFK = 0;
                }
            }
            else if (cmd == "collapse") { collapsed = 1; }
            else if (cmd == "restore") { collapsed = 0; }
        }
        else if (num == 350) { RLVok = llList2Integer(parameterList, 0); }
    }

    touch_start(integer num) {
        doMainMenu(llDetectedKey(0));
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer channel, string name, key id, string choice) {
        // channel = chat channel to listen on
        //    name = filter by prim name
        //     key = filter by avatar key
        //  choice = filter by specific message
        string displayName = llGetDisplayName(id);
        if (displayName != "") name = displayName;

        handlemenuchoices(choice, name, id);
    }

    dataserver(key query_id, string data) {
        if (query_id == mistressQuery) {
            mistressName = data;
            llMessageLinked(LINK_SET, 300, "mistressName|" + mistressName, NULL_KEY);
        }
    }
}
