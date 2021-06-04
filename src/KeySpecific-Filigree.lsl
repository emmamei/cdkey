//========================================
// KeySpecific.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl

#include "include/GlobalDefines.lsl"
#define cdMenuInject(a,b,c) lmMenuReply(a,b,c)

#define RUNNING 1
#define NOT_RUNNING 0
#define UNSET -1
#define cdStopScript(a) llSetScriptState(a, NOT_RUNNING)
#define cdRunScript(a) llSetScriptState(a, RUNNING)
#define cdResetKey() llResetOtherScript("Start")

#define cdProfileURL(i) "secondlife:///app/agent/"+(string)(i)+"/about"
#define cdList2String(a) llDumpList2String(a,"|")

#define COLOR_PURPLE <0.3, 0.1, 0.6>
#define COLOR_PINK   <0.9, 0.1, 0.8>
#define COLOR_RED    <0.8, 0.1, 0.1>
#define COLOR_GREEN  <0.1, 0.8, 0.1>
#define COLOR_BLUE   <0.1, 0.1, 0.8>
#define COLOR_CYAN   <0.1, 0.8, 0.8>
#define COLOR_YELLOW <0.8, 0.8, 0.1>
#define COLOR_ORANGE <0.8, 0.4, 0.1>
#define COLOR_WHITE  <0.9, 0.9, 0.9>
#define COLOR_BLACK  <0.0, 0.0, 0.0>
#define COLOR_GREY   <0.1, 0.1, 0.1>

#define KEY_SPECIFIC_PRODUCT "Community Dolls Filigree Key"

#define cdListenAll(a)    llListen(a, NO_FILTER, NO_FILTER, NO_FILTER)
#define cdListenUser(a,b) llListen(a, NO_FILTER,         b, NO_FILTER)
#define cdListenMine(a)   llListen(a, NO_FILTER,    dollID, NO_FILTER)
#define cdListenerDeactivate(a) llListenControl(a, 0)
#define cdListenerActivate(a) llListenControl(a, 1)

//=======================================
// VARIABLES
//=======================================

list colorNames = [ "Purple", "Pink", "Red", "Green", "Blue", "Cyan", "Yellow", "Orange", "White" ];
list colorValues = [ <0.3, 0.1, 0.6>, <0.9, 0.1, 0.8>, <0.8, 0.1, 0.1>, <0.1, 0.8, 0.1>, <0.1, 0.1, 0.8>, <0.1, 0.8, 0.8>, <0.8, 0.8, 0.1>, <0.8, 0.4, 0.1>, <0.9, 0.9, 0.9> ];

integer keySpecificChannel = -32111;
integer keySpecificHandle;
string keySpecificMenu = "Gem...";

integer isVisible;
vector gemColor;
vector normalGemColor = COLOR_PINK;

//=======================================
// FUNCTIONS
//=======================================

doLuminosity() {

    // If the Key is invisible, the glow may still be visible:
    // so shut it off.
    //
    if (!isVisible || collapsed) {

        vector newGemColor;

        if (collapsed) newGemColor = COLOR_GREY;
        else newGemColor = gemColor;

        // Turn off glow et al when not visible or collapsed
        llSetLinkPrimitiveParamsFast(LINK_SET, [
            PRIM_POINT_LIGHT, FALSE, newGemColor, 0.5, 2.5, 2.0,
            PRIM_GLOW, ALL_SIDES, 0.0
            ]);
    }
    else {

        list params;

        // Prims in this key:
        //
        // * Mount1 (7)
        // * Mount2 (6)
        // * Heart1 (5)
        // * Heart2 (4)
        // * TouchOrb (3)
        // * Object (2?)
        // * Dolly Lady's Key (1)

        // Set Mount1 (7)
        params += [ PRIM_LINK_TARGET, 7,
                    PRIM_GLOW, ALL_SIDES, 0.1 ];

        // Set Mount2 (6)
        params += [ PRIM_LINK_TARGET, 6,
                    PRIM_GLOW, ALL_SIDES, 0.1 ];

        // Set Heart1 (5)
        params += [ PRIM_LINK_TARGET, 5,
                    PRIM_POINT_LIGHT, TRUE, gemColor, 0.5, 2.5, 2.0,
                    PRIM_GLOW, ALL_SIDES, 0.08 ];

        // Set Heart2 (4)
        params += [ PRIM_LINK_TARGET, 4,
                    PRIM_POINT_LIGHT, TRUE, gemColor, 0.5, 2.5, 2.0,
                    PRIM_GLOW, ALL_SIDES, 0.08 ];

        debugSay(4, "DEBUG-FILIGREE", "doLuminosity params list: " + llDumpList2String(params, ","));
        llSetLinkPrimitiveParamsFast(0, params);
    }
}

vector colorNoise(vector color) {

    vector shade;

    // Add noise to color
    shade = <llFrand(0.2) - 0.1 + color.x,
             llFrand(0.2) - 0.1 + color.y,
             llFrand(0.2) - 0.1 + color.z>  * (0.9 + llFrand(0.2));

    // make sure we're in bounds
    if (shade.x < 0.0) shade.x = 0.0;
    if (shade.y < 0.0) shade.y = 0.0;
    if (shade.z < 0.0) shade.z = 0.0;

    if (shade.x > 1.0) shade.x = 1.0;
    if (shade.y > 1.0) shade.y = 1.0;
    if (shade.z > 1.0) shade.z = 1.0;

    return shade;
}

// This command does NOT set normalGemColor - which is as it
// should be. This allows us to set the gemColor without
// losing the color we "normally" use.
//
setGemColor(vector color) {

    list params;

    debugSay(4,"DEBUG-FILIGREE","Setting gem color to " + (string)color);
    debugSay(4,"DEBUG-FILIGREE","Visibility = " + (string)isVisible);

    if (!isVisible) return;

    if (color == COLOR_BLACK) {
        llSay(DEBUG_CHANNEL,"Script " + script + " tried to set gem color to Black!");
        return;
    }

    gemColor = color;

    // Set Heart1 (5)
    params += [ PRIM_LINK_TARGET, 5,
                PRIM_COLOR, ALL_SIDES, color, 1.0 ];

    // Set Heart2 (4)
    params += [ PRIM_LINK_TARGET, 4,
                PRIM_COLOR, ALL_SIDES, color, 1.0 ];

    debugSay(4, "DEBUG-FILIGREE", "setGemColor params list: " + llDumpList2String(params, ","));
    llSetLinkPrimitiveParamsFast(0, params);
}

setNormalGemColor(vector color) {
    normalGemColor = color;
    setGemColor(normalGemColor);
}

resetGemColor() {
    setGemColor(normalGemColor);
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
        keyID = llGetKey();
        dollName = dollyName();
        myName = llGetScriptName();

        // Beware listener is now available to users other than the doll
        // make sure to take this into account within all handlers.
        //chatHandle = llListen(chatChannel, "", "", "");
        cdInitializeSeq();
    }

    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    link_message(integer source, integer i, string data, key id) {

        // Parse link message header information
        split             =     cdSplitArgs(data);
        script            =     (string)split[0];
        remoteSeq         =     (i & 0xFFFF0000) >> 16;
        optHeader         =     (i & 0x00000C00) >> 10;
        code              =      i & 0x000003FF;
        split             =     llDeleteSubList(split, 0, 0 + optHeader);

        if (code == SEND_CONFIG) {
            string name  = (string)split[0];
            string value = (string)split[1];

            split = llDeleteSubList(split,0,0);

            switch (name): {

                case "collapsed": {

                    collapsed = (integer)value;

                    doLuminosity();
                    break;
                }

                case "visibility": {
                    visibility = (integer)value;

                    doLuminosity();
                    break;
                }

                case "isVisible": {
                    isVisible = (integer)value;

                    doLuminosity();
                    break;
                }
                
                case "gem color": {
                    switch (llToLower(value)): {
                        case "purple": {
                            normalGemColor = COLOR_PURPLE;
                            break;
                        }
                        case "pink": {
                            normalGemColor = COLOR_PINK;
                            break;
                        }
                        case "red": {
                            normalGemColor = COLOR_RED;
                            break;
                        }
                        case "green": {
                            normalGemColor = COLOR_GREEN;
                            break;
                        }
                        case "blue": {
                            normalGemColor = COLOR_BLUE;
                            break;
                        }
                        case "cyan": {
                            normalGemColor = COLOR_CYAN;
                            break;
                        }
                        case "yellow": {
                            normalGemColor = COLOR_YELLOW;
                            break;
                        }
                        case "orange": {
                            normalGemColor = COLOR_ORANGE;
                            break;
                        }
                        case "white": {
                            normalGemColor = COLOR_WHITE;
                            break;
                        }
                        default: {
                            llSay(DEBUG_CHANNEL,"Invalid color (" + value + ") in the preferences file!");
                            break;
                        }
                    }
                }
            }
        }
        else if (code == MENU_SELECTION) {
            string choice = (string)split[0];
            string avatar = (string)split[1];

            if (choice == keySpecificMenu) {
                string msg = "Here you can choose your own gem color.";

                keySpecificHandle = cdListenMine(keySpecificChannel);
                llDialog(id, msg, dialogSort(colorNames + "Options..."), keySpecificChannel);
            }
        }
#ifdef NOT_USED
        else if (code == SET_CONFIG) {
            string setName = (string)split[0];
            string value   = (string)split[1];
        }
        else if (code == INTERNAL_CMD) {
            string cmd = (string)split[0];

        }
        else if (code == RLV_RESET) {
            RLVok = (integer)split[0];
            rlvAPIversion = (string)split[1];
        }
#endif
        else if (code < 200) {
            if (code == INIT_STAGE1) {
                llOwnerSay("Key-specific extensions loaded for " + KEY_SPECIFIC_PRODUCT);
                lmSendConfig("keySpecificConfigs","gem color");
            }
            else if (code == INIT_STAGE5) {

                lmSendConfig("keySpecificMenu","Gem...");
                setNormalGemColor(normalGemColor);
                doLuminosity();
            }
#ifdef DEVELOPER_MODE
            else if (code == MEM_REPORT) {
                memReport(myName,(float)split[0]);
            }
#endif
            else if (code == CONFIG_REPORT) {
                cdConfigureReport();
            }
        }
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer channel, string name, key id, string choice) {
        // channel = chat channel to listen on
        //    name = filter by prim name
        //     key = filter by avatar key
        //  chatCommand = filter by specific message

        //----------------------------------------
        // CHAT COMMAND CHANNEL
        //----------------------------------------

        if (channel == keySpecificChannel) {
            integer index;

            if ((index = llListFindList(colorNames, [ choice ])) != NOT_FOUND) {
                vector colorValue = (vector)colorValues[ index ];

                setNormalGemColor(colorValue);
                lmMenuReply("Options...","",dollID);
            }
        }
    }

#define removeLastListTerm(a) llDeleteSubList(a,-2,-1);
#define stopTimer() llSetTimerEvent(0.0)

#ifdef NOT_USED
    //----------------------------------------
    // TIMER
    //----------------------------------------
    timer() {
    }
#endif
}

//========== KEYSPECIFIC-FILIGREE ==========
