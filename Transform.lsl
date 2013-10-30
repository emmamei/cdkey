//Aug 14, totally changing
//Nov. 12, adding compatibility with hypnosisHUD

string dollname;
string statename;
list types;
integer lineno;

integer cd8666;
integer cd8667;
integer cd8665;

integer listen_id_8666;
integer listen_id_8667;
integer listen_id_8665;
integer listen_id_ask;
integer minmin;
integer maxmin;
integer avoid;
integer channel_dialog;
integer channelHUD;
integer channelAsk;

integer menulimit = 9;     // 1.5 minute

string currentstate;
integer winddown;
integer needsagree;
integer seesphrases;
key dollID;
string clothingprefix;

key kQuery;

list currentphrases;



setup ()  {
    dollID =   llGetOwner();
    dollname = llGetDisplayName(dollID);
    llMessageLinked( -4, 18, "here", dollID );
    integer ncd = ( -1 * (integer)("0x"+llGetSubString((string)llGetKey(),-5,-1)) ) -1;
    if (channel_dialog != ncd) {
        llListenRemove(listen_id_8666);
        llListenRemove(listen_id_8665);
        llListenRemove(listen_id_8667);
        llListenRemove(listen_id_ask);
        channel_dialog = ncd;
        cd8666 = channel_dialog - 8666;
        listen_id_8666 = llListen( cd8666, "", "", "");
        listen_id_8667 = llListen( cd8666+1, "", "", "");
        listen_id_8665 = llListen( cd8666-1, "", "", "");
        channelHUD = ( -1 * (integer)("0x"+llGetSubString((string)llGetOwner(),-5,-1)) )  - 1114;
        channelAsk = channelHUD - 1;
        listen_id_ask = llListen( cd8666-1, "", "", "");
    }
    sendstatename();
}

sendstatename() {
    string tosend = statename;
    if (tosend == "Regular") {
        tosend = "Normal";
    }
    else if (tosend = "Domme") {
        tosend = "Dominant";
    }
    else if (tosend = "Submissive") {
        tosend = "submissive";
    }
    llSay(channelHUD,tosend);
}
    

reloadscripts() {
    types = [];
    integer  n = llGetInventoryNumber(7);
    while(n) {
        types += llGetInventoryName(7, --n);
    }
}

default {
    state_entry() {
         setup();
        reloadscripts();
        llSetTimerEvent(120.0); 
        cd8666 = ( -1 * (integer)("0x"+llGetSubString((string)llGetKey(),-5,-1)) ) - 8666;
        maxmin = -1;
        needsagree = FALSE;
         seesphrases = TRUE;
        avoid = FALSE;
    }

     on_rez(integer iParam) {
        setup();
    }

    changed(integer change) {
        if ((change & CHANGED_INVENTORY)  || (change & CHANGED_ALLOWED_DROP))  {
            reloadscripts();
        }
    }

    timer() {   //called everytimeinterval
        minmin--;
         maxmin--;
        if (maxmin == 0) {
            llSay(cd8666,"Regular");
        }

        if (seesphrases) {
            integer i = (integer) llFrand(llGetListLength(currentphrases));
            string phrase  = llList2String(currentphrases, i);
            if (llGetSubString(phrase,0,0) == "*") {
    phrase = llGetSubString(phrase,1,-1);
                float r = llFrand(3);
                if (r < 1.0) {
                    phrase = "*** feel your need to " + phrase;
                }
                else if (r < 2.0) {
                    phrase = "*** feel your desire to " + phrase;
                }
                else {
        if (currentstate  == "Domme") {
                        phrase = "*** You like to " + phrase;
        }
        else {
                        phrase = "*** feel how people like you to " + phrase;
        }
                }
            }
            else {
                phrase = "*** " + phrase;
            }
            if (currentstate == "Regular") {
                phrase += " ***";
            }
            else {        
                phrase += ", " + statename + "Doll ***";
            }
            llOwnerSay(phrase);
        }
    }

    link_message(integer source, integer num, string choice, key id) {
        if (num == 17) {
            if (minmin > 0) {
                llDialog(id,dollname + "cannot be transformed right now. She was recently transformed.",["OK"], 9999);
            }
            else {
                string msg = "These change the personality of " + dollname + " She is currently a " + statename + ". What type of doll do you want her to be?";
                llOwnerSay(choice + " is looking at your Transform options.");
                list choices = types;
                if (id == dollID) {
                    choices += "CHOICES";
                }

                integer channel = cd8666 - needsagree;
                llDialog(id,msg,choices, channel);
            }
        }
     }

     listen(integer channel, string name, key id, string choice) {
        if (choice == "CHOICES") {
                list choices;
                if (needsagree == TRUE) {
                    choices = ["automatic"];
                }
                else {
                    choices = ["needs agree"];
                }
                if (seesphrases == TRUE) {
                    choices += ["stop phrases"];
                }
                else {
                    choices += ["start phrases"];
                }
                llDialog(dollID,"Options",choices, cd8666+1);
        }

        else if (channel == cd8666 -1) {
                list choices = [choice,"I cannot"];
                string msg = "Can you make this change?";
                llDialog(dollID,msg,choices, cd8666);
                avoid = TRUE;
        }
        
        else if (channel == cd8666 && choice != "OK" && choice != "I cannot") {
            avoid = FALSE;
            statename = choice;
    sendstatename();
            minmin = 5;
    currentstate = choice;
    clothingprefix = "*" + choice;
    currentphrases = [];
    lineno = 0;
     kQuery = llGetNotecardLine(choice,0);

            llMessageLinked( -4, 2, clothingprefix, dollID);
                    llSleep(1.0);
            llMessageLinked( -4, 1, "random", dollID);
            llMessageLinked( -4, 16, currentstate, dollID);
            llSay(0, dollname + " has become a " + statename + " Doll.");
            if (currentstate != "Regular") {
                   llSetText(statename + " Doll", <1,1,1>, 2);
            }
            else {
                   llSetText("", <1,1,1>, 2);
            }
        }

        else if (channel == cd8666+1) {
            if (choice == "automatic" || choice == "needs agree") {
                needsagree = 1 - needsagree;
            }
            else if (choice == "stop phrases" || choice == "start phrases") {
                seesphrases = 1 - seesphrases;
            }
        }

        else if (channel == channelAsk) {
            if (choice == "ask") {
                sendstatename();
            }
        }
    }
    dataserver(key query_id, string data)  {
         if (query_id == kQuery) {
            if (data != EOF) {

                if (llStringLength(data) > 1) {
                    currentphrases += data;
                }
                lineno++;
                kQuery = llGetNotecardLine(currentstate,lineno);

            }

         }
     }

}
