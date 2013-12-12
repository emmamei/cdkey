//========================================
// RLV.lsl
//========================================

string ZWSP = "​"; // This is not an empty string it's a Zero Width Space Character
                  // used for a safe parameter seperator in messages.
                  
// Keys of important people in life of the Key:
key MasterBuilder = "42c7aaec-38bc-4b0c-94dd-ae562eb67e6d";   // Christina Halpin
key  MasterWinder = "64d26535-f390-4dc4-a371-a712b946daf8";   // GreigHighland
key        DevOne = "c5e11d0a-694f-46cc-864b-e42340890934";   // MayStone
key        DevTwo = "2fff40f0-ea4a-4b52-abb8-d4bf6b1c98c9";   // Silky Mesmeriser

// Current Controller - or Mistress
key MistressID = MasterBuilder;
key dollID;
key carrierID;

list rescuerList = [ MasterBuilder, MasterWinder ];
list developerList = [ DevOne, DevTwo ];

integer hasController;

integer configured;

integer afk;
integer autoTP;
integer canDress;
integer canFly;
integer canSit = 1;
integer canStand = 1;
integer detachable = 1;
integer helpless;
integer windDown = 1;

integer carried;

integer RLVck;
integer RLVok;

integer channel;
integer replyHandle;

string rlvAPIversion;

//========================================
// FUNCTIONS
//========================================

// This code assumes a human-generated config file
processConfiguration(string data) {

    // Return if done
    if (data == EOF)    {
        configured = 1;
        return;
    }
    
    integer i = llSubStringIndex(data, "=");

    // Configuration lines contain equals sign
    if (i != -1) {

        // Get parts of configuration: name and value
        string name = llGetSubString(data, 0, i - 1);
        string value = llGetSubString(data, i + 1, -1);

        // Trim input and lowercase name
        name = llStringTrim(llToLower(name), STRING_TRIM);
        value = llStringTrim(value, STRING_TRIM);

        //----------------------------------------
        // Assign values to program variables

        if (name == "helpless dolly") {
            helpless = (integer)value;
            if (RLVok) {
                if (helpless) llOwnerSay("@tplm=n,tploc=n");
                else llOwnerSay("@tplm=y,tploc=y");
            }
        }
        else if (name == "controller") {
            MistressID = (key)value;
            hasController = 1;
        }
        else if (name == "auto tp") {
            autoTP = (integer)value;
            if (RLVok) {
                if (autoTP) llOwnerSay("@accepttp=add");            // Allow auto TP
                else llOwnerSay("@accepttp=rem");            // Disallow auto TP
            }
        }
        else if (name == "detachable") {
            detachable = (integer)value;
        }
    }
}

string FormatFloat(float val, integer dp)
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
    integer free_memory = llGetFreeMemory();
    integer used_memory = llGetUsedMemory();
    
    llOwnerSay("RLV: Using " + FormatFloat(used_memory/1024.0, 2) + " of " + FormatFloat((used_memory + free_memory)/1024.0, 2) + " kB script memory, " + 
               FormatFloat(free_memory/1024.0, 2) + " kBytes free");
}

listenerStart() {
    // Get a unique number
    integer ncd = (integer)("0x" + llGetSubString((string)llGetKey(),-7,-1));
    channel = ncd + 3467;
    replyHandle = llListen(channel, "", "", "");
    
    llSetTimerEvent(60);
}

//----------------------------------------
// RLV Initialization Functions
//----------------------------------------
checkRLV()
{ // Run RLV viewer check
    RLVck = 1;
    llSetTimerEvent(60);
    llOwnerSay("@clear,versionnew=" + (string)channel);
}

postCheckRLV()
{ // Handle RLV check result
    if (RLVok) { // RLV detected
        llOwnerSay("Logged with Community Doll Key and " + rlvAPIversion + " active...");
        initializeRLV();
    } else { // No RLV detected
        llOwnerSay("Did not detect an RLV capable viewer, RLV features disabled.");
        if (hasController) {
            llMessageLinked(LINK_THIS, 11, (llGetDisplayName(llGetOwner()) + 
                            " has logged in without RLV!"), MistressID);
        }
        memReport();
    }
    
    // Mark RLV check completed
    RLVck = 0;
    llListenRemove(replyHandle);
}

initializeRLV() {
    // Key being attached to Spine?
    if (llGetAttached() == ATTACH_BACK) { //the proper location for the key
    
        if (!canDress) llOwnerSay("Other people cannot dress you.");
        
        if (RLVok) {
            if ( autoTP)     llOwnerSay("@accepttp=add");
            if ( helpless)   llOwnerSay("@tplm=n,tploc=n");
            if (!canFly)     llOwnerSay("@fly=n");
            if (!canStand)   llOwnerSay("@stand=n");
            if (!canSit)     llOwnerSay("@sit=n");
        }

        // if Doll is one of the developers... dont lock:
        // prevents inadvertent lock-in during development

        if (llListFindList(developerList, [ dollID ]) == -1) {
            if (RLVok) {

                // We lock the key on here - but in the menu system, it appears
                // unlocked and detachable: this is because it can be detached 
                // via the menu. To make the key truly "undetachable", we get
                // rid of the menu item to unlock it
                llOwnerSay("@detach=n,editobj:" + (string)llGetKey() + "=rem");  //locks key
            }
        } else {
            llSay(0, "Developer Key not locked.");
        }
        llMessageLinked(LINK_SET, 312, "windDown" + ZWSP + "1", NULL_KEY);
    }

    // Key attached elsewhere...
    else {
        // Key can be removed...
        if (RLVok) llOwnerSay("@detach=y");

        // Words are erroneous: attaches anyway
        llOwnerSay("Your key stubbornly refuses to attach itself, and you " +
                   "belatedly realize that it must be attached to your spine.");
        //llOwnerSay("Attach Point: " + (string) llGetAttached());
        llMessageLinked(LINK_SET, 312, "windDown" + ZWSP + "0", NULL_KEY);
    }
    
    memReport();
}

// Only useful if @tplure and @accepttp are off and denied by default...
autoTPAllowed(key userID) {
    if (RLVok) {
        llOwnerSay("@tplure:"   + (string) userID + "=add");
        llOwnerSay("@accepttp:" + (string) userID + "=add");
    }
}

//========================================
// STATES
//========================================

default {

    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------

    state_entry() {
        dollID = llGetOwner();
        
        listenerStart();
        checkRLV();
    }
    
    //----------------------------------------
    // TIMER
    //----------------------------------------

    timer() {
        if (!RLVok && RLVck < 5) {
            llSetTimerEvent(15);
            RLVck++;
            llOwnerSay("@clear,versionnew=" + (string)channel);
        } else if (!RLVok && RLVck >= 1) {
            llSetTimerEvent(0);
            postCheckRLV();
            llMessageLinked(LINK_SET, 311, "", llGetOwner());
        }
    }
    
    //----------------------------------------
    // LISTEN
    //----------------------------------------

    listen(integer chan, string name, key id, string msg) {
        llOwnerSay(msg);
        if (chan == channel) {
            RLVok = 1;
            rlvAPIversion = llStringTrim(msg, STRING_TRIM);
            llSetTimerEvent(0);
            postCheckRLV();
            llMessageLinked(LINK_SET, 310, msg, llGetOwner());
        }
    }
    
    //----------------------------------------
    // LINK_MESSAGE
    //----------------------------------------

    link_message(integer sender, integer num, string data, key id) {
        integer index;
        string parameter;
        list parameterList;

        // valid numbers:
        //    300: RLV Configuration
        //    305: RLV Commands
        //    100: Process Mistress ID
        //    101: Process configuration
        //
        // 300 cmds:
        //    * autoTP
        //    * helpless
        //    * canFly
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

        if (num >= 300 && num < 400) {
            while (index != -1) {
                index = llSubStringIndex(data, ZWSP);
                parameter = llGetSubString(data, 0, index - 1);
                data = llGetSubString(data, index + 1, -1);
                parameterList += llStringTrim(parameter, STRING_TRIM);
            }
        }
        
        if (num == 300) { // RLV Config
            string cmd = llList2String(parameterList, 0);

            if (cmd == "autoTP") {
                autoTP = llList2Integer(parameterList, 1);
                if (autoTP) {
                    llOwnerSay("You will now be automatically teleported.");
                    if (RLVok) llOwnerSay("@accepttp=add");
                } else {
                    if (RLVok) llOwnerSay("@accepttp=rem");
                }
            } else if (cmd == "helpless") {
                helpless = llList2Integer(parameterList, 1);
                if (helpless) {
                    llOwnerSay("You can no longer teleport yourself. You are a Helpless Dolly.");
                    if (RLVok) llOwnerSay("@tplm=n,tploc=n");
                } else {
                    if (RLVok) llOwnerSay("@tplm=y,tploc=y");
                }
            } else if (cmd == "canFly") {
                canFly = llList2Integer(parameterList, 1);
                if (!canFly) {
                    llOwnerSay("You can no longer fly. Helpless Dolly!");
                    if (RLVok) llOwnerSay("@fly=n");
                } else {
                    if (RLVok) llOwnerSay("@fly=y");
                }
            }
        }

        else if (num == 305) { // RLV Commands
            string cmd = llList2String(parameterList, 0);

            if (cmd == "autoSetAFK") {
                afk = 1;
                
                // set sign to "afk"
                llSetText("Away", <1,1,1>, 1);

                // AFK turns everything off
                if (RLVok) {
                    llOwnerSay("@temprun=n,alwaysrun=n,sendchat=n,tplure=n,sittp=n,standtp=n,unsit=n,sit=n");
                    llOwnerSay("@fly=n,tplm=n,tploc=n,accepttp=rem");
                }

                llOwnerSay("Automatically entering AFK mode. Wind down time has slowed by a factor of " + llList2String(parameterList, 1) + " and movements are restricted.");
                llOwnerSay("You have " + llList2String(parameterList, 2) + " minutes of life remaning.");
            }

            else if (cmd == "setAFK") {
                afk = 1;
                
                // set sign to "afk"
                llSetText("Away", <1,1,1>, 1);

                // AFK turns everything off
                if (RLVok) {
                    llOwnerSay("@temprun=n,alwaysrun=n,sendchat=n,tplure=n,sittp=n,standtp=n,unsit=n,sit=n");
                    llOwnerSay("@fly=n,tplm=n,tploc=n,accepttp=rem");
                }
                
                llOwnerSay("You are now away from keyboard (AFK). Wind down time has slowed by a factor of " + llList2String(parameterList, 1) + " and movements are restricted.");
                llOwnerSay("You have " + llList2String(parameterList, 2) + " minutes of life remaning.");
            }

            else if (cmd == "unsetAFK") {
                afk = 0;
                
                if (RLVok) {
                    if (canFly) {
                        llOwnerSay("@fly=y"); // restore flying capability
                    }
    
                    if (!helpless) {
                        llOwnerSay("@tplm=y,tploc=y"); // restore travel capabilities
                    }
    
                    if (autoTP) {
                        llOwnerSay("@accepttp=add"); // restore autoTP
                    } else {
                        llOwnerSay("@accepttp=rem"); // remove autoTP
                    }
    
                    llOwnerSay("@temprun=y,alwaysrun=y,sendchat=y,tplure=y,sittp=y,standtp=y,unsit=y,sit=y");
                }
    
                llOwnerSay("You are now no longer away from keyboard (AFK). Movements are unrestricted and winding down proceeds at normal rate.");
                llOwnerSay("You have " + llList2String(parameterList, 1) + " minutes of life remaning.");
            }

            else if (cmd == "collapse") {
                // Turn everything off: Dolly is down
                if (RLVok) {
                    llOwnerSay("@fly=n,temprun=n,alwaysrun=n,sendchat=n,tplm=n,tploc=n,sittp=n,standtp=n,accepttp=rem," +
                        "unsit=n,sit=n,shownames=n,showhovertextall=n");
            
                    // Only the carrier and the General Dolly Rescuers can
                    // AutoTP someone who is collapsed...
                    //
                    llOwnerSay("@accepttp=rem,tplure=n");
            
                    autoTPAllowed(MistressID);
                    autoTPAllowed(MasterBuilder);
                    autoTPAllowed(MasterWinder);
                    autoTPAllowed(DevOne);
                    autoTPAllowed(DevTwo);
            
                    if (carried) {
                        autoTPAllowed(carrierID);
                    }
            
                    llOwnerSay("@unsit=force");
                }
            }

            else if (cmd == "restore") {
                if (RLVok) {
                    // Clear restrictions
                    if (canFly) {
                        llOwnerSay("@fly=y");
                    }
            
                    if (!helpless) {
                        llOwnerSay("@tplm=y,tploc=y");
                    }
            
                    llOwnerSay("@accepttp=rem,temprun=y,alwaysrun=y,sendchat=y,tplure=y,sittp=y,standtp=y,unsit=y,sit=y,shownames=y,showhovertextall=y,rediremote:999=rem");
                }
            }

            else if (cmd == "stripTop") {
                llOwnerSay("@detach:stomach=force,detach:left shoulder=force,detach:right shoulder=force,detach:left hand=force,detach:right hand=force,detach:r upper arm=force,detach:r forearm=force,detach:l upper arm=force,detach:l forearm=force,detach:chest=force,detach:left pec=force,detach:right pec=force");
                llOwnerSay("@remoutfit:gloves=force,remoutfit:jacket=force,remoutfit:shirt=force");
            }

            else if (cmd == "stripBra") {
                llOwnerSay("@remoutfit:undershirt=force");
            }

            else if (cmd == "stripBottom") {
                llOwnerSay("@detach:chin=force,detach:r upper leg=force,detach:r lower leg=force,detach:l upper loge=force,detach:l lower leg=force,detach:pelvis=force,detach:right hip=force,detach:left hip=force,detach");
                llOwnerSay("@remoutfit:pants=force,remoutfit:skirt=force");
            }

            else if (cmd == "stripPanties") {
                llOwnerSay("@remoutfit:underpants=force");
            }

            else if (cmd == "stripShoes") {
                llOwnerSay("@detach:right foot=force,detach:left foot=force");
                llOwnerSay("@remoutfit:shoes=force,remoutfit:socks=force");
            }

            else if (cmd == "carried") {
                if (RLVok) {
                    // No TP allowed for Doll
                    llOwnerSay("@tplm=n,tploc=n,accepttp=rem,tplure=n");
        
                    // Allow carrier to TP: but Doll can deny
                    llOwnerSay("@tplure:" + (string)carrierID  + "=add");
        
                    // Allow rescuers to AutoTP
                    autoTPAllowed(MistressID);
                    autoTPAllowed(DevOne);
                    autoTPAllowed(DevTwo);
                }
            }
        }

        else if (num == 100) {
            if (data == "MistressID") {
                MistressID = id;
                if (MistressID != MasterBuilder) hasController = 1;
                else hasController = 0;
            }
        }

        else if (num == 101) {
            if (!configured) processConfiguration(data);
        }
    }
} 
