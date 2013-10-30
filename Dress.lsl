//Oct. 1. Adds everything in ~normalself folder, if oldoutfit began with a +. adds channel dialog or id to screen listen
//Nov. 17, moves listen to cd2667 so it gets turned off
//Nov. 25, puts in dress menu
//Aug 1, redoes closing

string bigsubfolder = "Dressup"; //name of subfolder in RLV to always use if available. But also checks for outfits.

integer candresstemp;
integer candresstimeout;

key dollID;
key dresserID;
key setupID;

integer listen_id_outfitrequest3;
string newoutfitname;

integer channel_dialog;
integer cd2667;

string newoutfit;
string oldoutfit;
string oldoutfitname;

string clothingprefix;
string bigprefix;

integer listen_id_2667;
integer listen_id_outfitrequest;
integer listen_id_2555;
integer listen_id_2668;
integer listen_id_2669;
integer listen_id_9001;
integer listen_id_9002;
integer listen_id_9003;
integer listen_id_9005;
integer listen_id_9007;
integer listen_id_9011;
integer listen_id_9012;
integer listen_id_9013;
integer listen_id_9014;

string oldattachmentpoints;
integer newoutfitwordend;

setup ()  {
    dollID =   llGetOwner();
    candresstemp = TRUE;
    llOwnerSay("@getinv=2555");

//from dollkey36

    integer ncd = ( -1 * (integer)("0x"+llGetSubString((string)llGetKey(),-5,-1)) ) -1;
    if (channel_dialog != ncd) {
           llListenRemove(listen_id_2667); 
        channel_dialog = ncd;
        cd2667 = channel_dialog - 2667;
        llListenRemove(listen_id_2667);
        listen_id_2667 = llListen( cd2667, "", "", "");

    }
    if (dollID != setupID) {
        llListenRemove(listen_id_2555);
        llListenRemove(listen_id_outfitrequest3);
        llListenRemove(listen_id_outfitrequest);
        llListenRemove(listen_id_2668); 
        llListenRemove(listen_id_2669); 
        llListenRemove(listen_id_9001); 
        llListenRemove(listen_id_9002);
        llListenRemove(listen_id_9003); 
        llListenRemove(listen_id_9005); 
        llListenRemove(listen_id_9007); 
        llListenRemove(listen_id_9011);
        llListenRemove(listen_id_9012);
        llListenRemove(listen_id_9013); 
        llListenRemove(listen_id_9014);
         llSleep(2.0);
        listen_id_2555 = llListen(2555, "", dollID, "");
        listen_id_outfitrequest3 = llListen(2665, "", dollID, "");
        listen_id_outfitrequest = llListen(2666, "", dollID, "");
        listen_id_2668 = llListen(2668, "", dollID, "");
        listen_id_2669 = llListen(2669, "", dollID, "");
        listen_id_9001 = llListen(9001, "", dollID, "");
        listen_id_9002 = llListen(9002, "", dollID, "");
        listen_id_9003 = llListen(9003, "", dollID, "");
        listen_id_9005 = llListen(9005, "", dollID, "");
        listen_id_9007 = llListen(9007, "", dollID, "");
        listen_id_9011 = llListen(9011, "", dollID, "");
        listen_id_9012 = llListen(9012, "", dollID, "");
        listen_id_9013 = llListen(9013, "", dollID, "");
        listen_id_9014 = llListen(9014, "", dollID, "");
        setupID = dollID;
    }
}

default {
    state_entry() {
        channel_dialog = 0;
        setup();
        llSetTimerEvent(10.0);  //clock is accessed every ten seconds;
        clothingprefix = "";
    }

        on_rez(integer iParam) {
        setup();
     }

    timer() {   //called everytimeinterval 
        if (candresstimeout-- == 0) {
            candresstemp = TRUE;
        }
    }

     link_message(integer source, integer num, string choice, key id) {
// need to disallow dressing while dressing is happening
        if (num == 1)  { 
            if (candresstemp == FALSE) {
                llSay(0, "She cannot be dressed right now; she is already dressing");
            }
            else if (choice == "start") {
                dresserID = id;

                candresstimeout = 8;
                if (clothingprefix == "") {
                    llOwnerSay("@getinv=2666");
                }
                else {
                    llOwnerSay("@getinv:" + clothingprefix + "=2666");
                }
            }
            else if (choice == "random") {
                //candresstemp = FALSE;
                candresstimeout = 8;
                if (clothingprefix == "") {
                    llOwnerSay("@getinv=2665");
                }
                else {
                    llOwnerSay("@getinv:" + clothingprefix + "=2665");
                }
            }
        }
        if (num == 2)  {  //probably should have been in transformer
            string oldclothingprefix = clothingprefix;
            if (bigprefix) {
                clothingprefix = bigprefix + "/" +  choice;
            }
            else {
                clothingprefix = choice;
            }
            if (clothingprefix != oldclothingprefix) {
                llOwnerSay("@detach:" + oldclothingprefix + "/~AO=force");
                llOwnerSay("@attach:" + clothingprefix + "/~AO=force");
                if (oldclothingprefix != "") {
                    //remove tatoo");
                    llOwnerSay("@remoutfit:" + clothingprefix + "/tatoo=force");
                    llOwnerSay("@attach:~normalself=force");
                    llSleep(4.0);
                }

                llOwnerSay("@attach:" + clothingprefix + "/~normalself=force");
            }
            

            //puts on ~normalself
        }

     }
// First, all clothes are taken off except for skull and anything that might be revealing.
// Then the new outfit is put on. It uses replace, so it should take off any old clothes.
// Then there is an 8 second wait and then the new outfit is put on again! In case something was locked. This I think explains the double put-on.
// Then the places are checked where there could be old clothes still on. If anything is there, according to whatever is returned, the id is checked and it is taken off if they are old.
// This last step takes off all the clothes that weren't replaced.

//There is one place where the old outfit is removed.

    listen(integer channel, string name, key id, string choice) {
        if (channel == 2555) { // looks for one folder at start
            string oldbigprefix = bigprefix;
            list Outfits = llParseString2List(choice, [","], []); //what are brackets at end? 
            integer n;
            integer iStop = llGetListLength(Outfits);
            string itemname;
            bigprefix = "";
            for (n = 0; n < iStop; n++) {
                        itemname = llList2String(Outfits, n);
                if (itemname == bigsubfolder) {
                    bigprefix = bigsubfolder;
                }
                else if (itemname == "outfits") {
                    bigprefix = "outfits";
                }
                else if (itemname == "Outfits") {
                    bigprefix = "Outfits";
                }
            }
            if (bigprefix != oldbigprefix) {  //outfits-don't-match-type bug only occurs when big prefix is changed
                clothingprefix = bigprefix;
            }
        }
        if (channel == 2665) { // gets random outfit
            list Outfits = llParseString2List(choice, [","], []); //what are brackets at end? 
            list newoutfits = [];
            integer n;
            integer iStop = llGetListLength(Outfits);
            if (iStop == 0) {   //folder is empty, switching to regular folder
                llOwnerSay("There are no outfits in your " + clothingprefix + " folder.");
                if (bigprefix) {
                    clothingprefix = bigprefix + "/";
                }
                else {
                    clothingprefix = "";
                }
            }
            else {
                string itemname;
                string prefix;
                integer total = 0;
                for (n = 0; n < iStop; n++) {
                            itemname = llList2String(Outfits, n);
                    prefix = llGetSubString(itemname,0,0);
                    if (prefix != "~" && prefix != "*") {
                        total += 1;
                        newoutfits += itemname;
                    }
                }
                integer i = (integer) llFrand(total);
                string nextoutfit  = llList2String(newoutfits, i);
                llDialog(dollID, "You are being dressed in this",[nextoutfit], cd2667);
            }
        }

        if (channel == 2666) {
            list Outfits = llParseString2List(choice, [","], []); //what are brackets at end? 
            list newoutfits = [];
            integer n;
            integer iStop = llGetListLength(Outfits);
            string itemname;
            for (n = 0; n < iStop; n++) {
                        itemname = llList2String(Outfits, n);
                if (llStringLength(itemname) < 24  && llGetSubString(itemname,0,0) != "~"  && llGetSubString(itemname,0,0) != "*"&& itemname != oldoutfitname) {
                    newoutfits += itemname;
                }
            }
//picks out
            list newoutfits2 = [];
            integer total = 0;
            for (n = 0; n < 12; n++) {
                integer t = llGetListLength(newoutfits);
                if (t > 0) {
                    integer i = (integer) llFrand(t);
                    itemname  = llList2String(newoutfits, i);
                    newoutfits = llDeleteSubList(newoutfits, i, i);
                    newoutfits2 += itemname;
                }
            }
            string msgg = "You may choose any outfit.";
            if (dresserID == dollID) {
                msgg =     "See http://communitydolls.com/outfits.htm for information on outfits.";
            }
            llDialog(dresserID, msgg,newoutfits2, cd2667);

        }

        else if (channel == cd2667  && choice != "OK") {  //the random outfit from 2665 didn't work with the above
            candresstemp = FALSE;
            newoutfitname = choice;
            if (clothingprefix == "") {
                newoutfit = choice;
            }
            else {
                newoutfit = clothingprefix + "/" + choice;
            }
            newoutfitwordend = llStringLength(newoutfit)  - 1;
            llOwnerSay("@detach:left shoulder=force,detach:right shoulder=force,detach:left hand=force,detach:right hand=force,detach:left foot=force,detach:r upper leg=force,detach:l upper leg=force,detach:spine=force");
            llOwnerSay("@detach:right foot=force,detach:mouth=force,detach:chin=force,detach:left ear=force,detach:right ear=force,detach:left eyeball=force,detach:right eyeball=force,detach:nose=force,detach:r upper arm=force,detach:r forearm=force,detach:l upper arm=force,detach:l forearm=force,detach:r lower leg=force,detach:l lower leg=force,detach:left pec=force,detach:right pec=force");
            llOwnerSay("@remoutfit:gloves=force,remoutfit:shoes=force,remoutfit:socks=force,remoutfit:underpants=force,remoutfit:undershirt=force");
            //why have the following? i guess so hair replaces skull
            if (llGetSubString(newoutfitname,0,0) == "+") {
                llOwnerSay("@detach:skull=force");
                //detach hair too
            }
            llOwnerSay("@getattach=2668");
            if (llGetSubString(oldoutfitname,0,0) == "+" && llGetSubString(newoutfitname,0,0) != "+") {  // only works well assuming in regular
                llOwnerSay("@attach:~normalself=force");
            }

        }
        else if (channel == 2668) {
            //llOwnerSay("@attachall:" + newoutfit + "=force");
            llOwnerSay("@attachalloverorreplace:" + newoutfit + "=force");
 
            oldattachmentpoints = choice;
                    llSleep(8.0);
            llOwnerSay("@attachallover:" + newoutfit + "=force"); // puts on things that wouldn't go on over locked items explains second put-on
            if (oldoutfit) {
                if (oldoutfit != newoutfit) {
                    llOwnerSay("@detach:" + oldoutfit + "=force");
                }
            }
            oldoutfit = newoutfit;
            oldoutfitname = newoutfitname;
            candresstimeout = 2;
            llOwnerSay("@getoutfit=2669");
        }
        else if (channel == 2669) {
            string oldclothespoints = choice;
            if (llGetSubString(oldclothespoints, 1, 1) == "1") {
                llOwnerSay("@getpath:jacket=9011");
            }
            if (llGetSubString(oldclothespoints, 2, 2) == "1") {
                llOwnerSay("@getpath:pants=9012");
            }
            if (llGetSubString(oldclothespoints, 3, 3) == "1") {
                llOwnerSay("@getpath:shirt=9013");
            }
            if (llGetSubString(oldclothespoints, 5, 5) == "1") {
                llOwnerSay("@getpath:skirt=9014");
            }
            if (llGetSubString(oldattachmentpoints, 1, 1) == "1") {
                llOwnerSay("@getpath:chest=9001");
            }

            if (llGetSubString(oldattachmentpoints, 10, 10) == "1") {
                llOwnerSay("@getpath:pelvis=9002");
            }
            if (llGetSubString(oldattachmentpoints, 22, 22) == "1") {
                llOwnerSay("@getpath:right hip=9003");
            }
            if (llGetSubString(oldattachmentpoints, 25, 25) == "1") {
                llOwnerSay("@getpath:left hip=9005");
            }
            if (llGetSubString(oldattachmentpoints, 28, 28) == "1") {
                llOwnerSay("@getpath:stomach=9007");
            }
        }
        else if ((channel > 9000) && (llStringLength(choice) > 1) && (newoutfit != llGetSubString(choice, 0, newoutfitwordend))) {
            if (channel == 9001) {
                llOwnerSay("@detach:chest=force");
            }
            else if (channel == 9002) {
                llOwnerSay("@detach:pelvis=force");
            }
            else if (channel == 9003) {
                llOwnerSay("@detach:right hip=force");
            }
            else if (channel == 9005) {
                llOwnerSay("@detach:left hip=force");
            }
            else if (channel == 9007) {
                llOwnerSay("@detach:stomach=force");
            }
            else if (channel == 9011) {
                llOwnerSay("@remoutfit:jacket=force");
            }
            else if (channel == 9012) {
                llOwnerSay("@remoutfit:pants=force");
            }
            else if (channel == 9013) {
                llOwnerSay("@remoutfit:shirt=force");
            }
            else if (channel == 9014) {
                llOwnerSay("@remoutfit:skirt=force");
            }
        }

    }
}


