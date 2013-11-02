// Dress.lsl
//
// vim: et sw=4
//
// DATE: 26 February 2013
//
// HISTORY:
//   Oct. 1   Adds everything in ~normalself folder, if oldoutfit begins with a +.
//            Adds channel dialog or id to screen listen
//   Nov. 17  moves listen to cd2667 so it gets turned off
//   Nov. 25  puts in dress menu
//   Aug 1    redoes closing

//========================================
// VARIABLES
//========================================
string bigsubfolder = "Dressup"; //name of subfolder in RLV to always use if available. But also checks for outfits.

// FIXME: This should be in a notecard so it can be changed without mangling the scripts.
string outfits_url = "http://communitydolls.com/outfits.htm";

integer candresstemp;
integer candresstimeout;

key dollID;
key dresserID;
key setupID;

integer listen_id_outfitrequest3;
string newoutfitname;

integer channel_dialog;
integer cd2667;
integer cd2668;
integer cd2669;

// These are the paths of the outfits relative to #RLV
string newoutfit;
string oldoutfit;
string xfolder;

string oldoutfitname;
list outfitsList;
string msgx; // could be "msg" but that is used elsewhere?

string clothingFolder; // This contains clothing to be worn
string outfitsFolder;  // This contains folders of clothing to be worn

integer listen_id_outfitrequest;
integer listen_id_2555;
integer listen_id_2667;
integer listen_id_2668;
integer listen_id_2669;

integer outfitPage;

string oldattachmentpoints;
string oldclothespoints;
integer newoutfitwordend;
integer outfitPageSize = 9;

//========================================
// FUNCTIONS
//========================================

list outfitsPage(list outfitList) {
    integer newOutfitCount = llGetListLength(outfitList);

    // GLOBAL: outfitPage

    // compute start index
    integer currentIndex = outfitPage * outfitPageSize;

    // If reaching beyond the end...
    if (currentIndex > newOutfitCount) {
        // Wrap to start...
        //outfitPage = 0;
        //currentIndex = 0;

        // Halt at end
        outfitPage--;
        currentIndex = outfitPage * outfitPageSize;
    }
    // If reaching beyond the beginning...
    else if (currentIndex < 0) {
        // Wrap to end
        //currentIndex = newOutfitCount % outfitPageSize;
        //outfitPage = currentIndex % outfitPageSize;

        // Halt at start
        outfitPage = 0;
        currentIndex = 0;
    }

    integer endIndex = currentIndex + outfitPageSize - 1;
    if (endIndex > newOutfitCount) {
        endIndex = newOutfitCount;
    }

    // Use sort function to reverse order: this makes the sort
    // read top to bottom in dialog
    return (llListSort(llList2List(outfitsList, currentIndex, endIndex),3,FALSE));
    //return (llList2List(outfitsList, currentIndex, endIndex));
}

integer isClothingItem (string folder) {
    string prefix = llGetSubString(folder,0,0);

    // Folders that start with "~" are hidden and
    // those that start with "*" are actually outfit folders
    return (prefix == "~" || prefix == "*");
}

integer isGroupItem (string f) {
    string prefix = llGetSubString(f,0,0);

    return (prefix == "#");
}

integer isHiddenItem (string f) {
    string prefix = llGetSubString(f,0,0);

    // Items that start with "~" are hidden
    return (prefix == "~" || prefix == ">");
}

integer isTransformingItem (string f) {
    string prefix = llGetSubString(f,0,0);

    // Items that start with "*" are Transforming folders
    return (prefix == "*");
}

integer isPlusItem (string f) {
    string prefix = llGetSubString(f,0,0);

    // Items that start with "+" are self-contained outfits;
    // make no assumptions when restoring to "normal" outfit
    return (prefix == "+");
}

removeListeners () {
    llListenRemove(listen_id_2555);
    llListenRemove(listen_id_outfitrequest3);
    llListenRemove(listen_id_outfitrequest);
    llListenRemove(listen_id_2668);
    llListenRemove(listen_id_2669);
//    llListenRemove(listen_id_9001);
//    llListenRemove(listen_id_9002);
//    llListenRemove(listen_id_9003);
//    llListenRemove(listen_id_9005);
//    llListenRemove(listen_id_9007);
//    llListenRemove(listen_id_9011);
//    llListenRemove(listen_id_9012);
//    llListenRemove(listen_id_9013);
//    llListenRemove(listen_id_9014);
}

addListeners (string dollID) {
    listen_id_2555           = llListen(2555, "", dollID, "");
    listen_id_outfitrequest3 = llListen(2665, "", dollID, "");
    listen_id_outfitrequest  = llListen(2666, "", dollID, "");
    listen_id_2668           = llListen(2668, "", dollID, "");
    listen_id_2669           = llListen(2669, "", dollID, "");

//    listen_id_9001           = llListen(9001, "", dollID, "");
//    listen_id_9002           = llListen(9002, "", dollID, "");
//    listen_id_9003           = llListen(9003, "", dollID, "");
//    listen_id_9005           = llListen(9005, "", dollID, "");
//    listen_id_9007           = llListen(9007, "", dollID, "");
//    listen_id_9011           = llListen(9011, "", dollID, "");
//    listen_id_9012           = llListen(9012, "", dollID, "");
//    listen_id_9013           = llListen(9013, "", dollID, "");
//    listen_id_9014           = llListen(9014, "", dollID, "");
}

listInventoryOn (string channel) {
    candresstimeout = 8;

    llSay(DEBUG_CHANNEL,">> clothingFolder = " + (string)clothingFolder);
    llSay(DEBUG_CHANNEL,">> outfitsFolder = " + (string)outfitsFolder);
                
    if (clothingFolder == "") {
        llOwnerSay("@getinv=" + channel);
    }
    else {
        llSay(DEBUG_CHANNEL,"cmd = getinv:" + clothingFolder + "=" + channel);
        llOwnerSay("@getinv:" + clothingFolder + "=" + channel);
    }
}

setup ()  {
    dollID = llGetOwner();
    candresstemp = TRUE;
    llOwnerSay("@getinv=2555");

//from dollkey36

    integer ncd = ( -1 * (integer)("0x" + llGetSubString((string)llGetKey(),-5,-1) ) ) - 1;

    if (channel_dialog != ncd) {
        llListenRemove(listen_id_2667);
        channel_dialog = ncd;
        cd2667 = channel_dialog - 2667;
        llListenRemove(listen_id_2667);
        listen_id_2667 = llListen( cd2667, "", "", "");
    }

    if (dollID != setupID) {
        removeListeners();
        llSleep(2.0);
        addListeners(dollID);

        setupID = dollID;
    }
}

//========================================
// STATES
//========================================
default {

    //----------------------------------------
    // STATE_ENTRY
    //----------------------------------------
    state_entry() {
        clothingFolder = "";
        channel_dialog = 0;

        setup();

        llSetTimerEvent(10.0);  //clock is accessed every ten seconds;
    }

    //----------------------------------------
    // ON_REZ
    //----------------------------------------
    on_rez(integer iParam) {
        setup();
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------
    timer() {   //called everytimeinterval
        if (candresstimeout-- == 0) {
            candresstemp = TRUE;
        }
    }

    //----------------------------------------
    // LINK_MESSAGE
    //----------------------------------------
    link_message(integer source, integer num, string choice, key id) {

        // need to disallow dressing while dressing is happening

        // Choice #1: Dress Dolly
        if (num == 1)  {
            if (candresstemp == FALSE) {
                llRegionSayTo(dresserID, PUBLIC_CHANNEL, "Dolly cannot be dressed right now; she is already dressing");
            }
            // If this code is linked with an argument of "start", then
            // act normally
            else if (choice == "start") {
                dresserID = id;
                listInventoryOn("2666");
            }
            // If this code is linked with an argument of "random", then
            // choose random outfit and be done
            //
            // This is used on style change
            else if (choice == "random") {
                //candresstemp = FALSE;
                listInventoryOn("2665");
            }
        }
        // Choice #2: ...
        else if (num == 2)  {  //probably should have been in transformer

            string oldclothingprefix = clothingFolder;

            if (outfitsFolder) {
                clothingFolder = outfitsFolder + "/" +  choice;
            }
            else {
                clothingFolder = choice;
            }

            if (clothingFolder != oldclothingprefix) {

                xfolder = "~normalself";
                //llOwnerSay("@attach:" + clothingFolder + "/~normalself=force");
                llOwnerSay("@attach:~normalself=force");
                llOwnerSay("@getinvworn:~normalself=2668");

                // FIXME: Make sure...
                //llSleep(2.0);
                //llOwnerSay("@attach:~normalself=force");
            }
        }
    }

// First, all clothes are taken off except for skull and anything that might be revealing.
//
// Then the new outfit is put on. It uses replace, so it should take off any old clothes.
//
// Then there is an 8 second wait and then the new outfit is put on again! In case something
// was locked. This I think explains the double put-on.
//
// Then the places are checked where there could be old clothes still on. If anything is there,
// according to whatever is returned, the id is checked and it is taken off if they are old.
//
// This last step takes off all the clothes that weren't replaced.

// There is one place where the old outfit is removed.

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer channel, string name, key id, string choice) {

        // channels:
        //
        // 2555: list of inventory
        // 2665: random outfit
        // 2666:
        // 2667:
        // 2668:
        // 2669:
        // 9000+

        //----------------------------------------
        // Channel: 2555
        //
        // Look for a usable outfits directory, or use the root: looks for
        // "Outfits" or "outfits" - results are saved for use later to get
        // at appropriate outfits in folders
        //
        if (channel == 2555) { // looks for one folder at start
            list Outfits = llParseString2List(choice, [","], []); //what are brackets at end?
            integer iStop = llGetListLength(Outfits);
            string oldbigprefix = outfitsFolder;
            integer n;
            string itemname;

            llSay(DEBUG_CHANNEL,">on channle 2555");
            outfitsFolder = "";

            // Looks for a folder that may contain outfits - folders such
            // as Dressup/, or outfits/, or Outfits/ ...
            for (n = 0; n < iStop; n++) {
                itemname = llList2String(Outfits, n);

                // If there are more than one of these folders in #RLV,
                // then the last one read will be used...
                if (itemname == bigsubfolder) {
                    outfitsFolder = bigsubfolder;
                }
                else if (itemname == "outfits") {
                    outfitsFolder = "outfits";
                }
                else if (itemname == "Outfits") {
                    outfitsFolder = "Outfits";
                }
            }

            // if prefix changes, change clothingFolder to match
            if (outfitsFolder != oldbigprefix) {  //outfits-don't-match-type bug only occurs when big prefix is changed
                clothingFolder = outfitsFolder;
            }

            llSay(DEBUG_CHANNEL,">oldbigprefix = " + oldbigprefix);
            llSay(DEBUG_CHANNEL,">outfitsFolder = " + outfitsFolder);
            llSay(DEBUG_CHANNEL,">clothingFolder = " + clothingFolder);
        }

        //----------------------------------------
        // Channel: 2665
        //
        // Switched doll types: grab a new (appropriate) outfit at random and change to it
        //
        else if (channel == 2665) { // list of inventory items from the current prefix
            list Outfits = llParseString2List(choice, [","], []); //what are brackets at end?
            integer iStop = llGetListLength(Outfits);

            integer n;

            // May never occur: other directories, hidden directories and files,
            // and hidden UNIX files all take up space here.

            if (iStop == 0) {   // folder is bereft of files, switching to regular folder

                // No files found; leave the prefix alone and don't change
                llOwnerSay("There are no outfits in your " + clothingFolder + " folder.");

                // Didnt find any outfits in the standard folder, try the
                // "extended" folder containing (we hope) outfits....

                if (outfitsFolder) {
                    clothingFolder = outfitsFolder + "/";
                    llOwnerSay("Trying the " + clothingFolder + " folder.");
                    listInventoryOn("2665"); // recursion
                }
                //else {
                //    clothingFolder = "";
                //    llOwnerSay("Trying the main #RLV folder.");
                //}
            }
            else {
                // Outfits (theoretically) found: change to one

                string itemname;
                string prefix;
                integer total = 0;

                outfitsList = [];

                for (n = 0; n < iStop; n++) {
                    itemname = llList2String(Outfits, n);
                    prefix = llGetSubString(itemname,0,0);

                    llSay(DEBUG_CHANNEL,">itemname = " + itemname);
                    llSay(DEBUG_CHANNEL,">prefix = " + prefix);

                    // skip hidden files/directories and skip
                    // Doll Type (Transformation) folders...
                    //
                    // Note this skips *Regular too

                    if (!isHiddenItem(itemname) && !isTransformingItem(itemname) && !isGroupItem(itemname)) {
                        total += 1;
                        outfitsList += itemname;
                    }
                }

                // Pick outfit at random
                integer i = (integer) llFrand(total);
                string nextoutfitname = llList2String(outfitsList, i);
                llSay(DEBUG_CHANNEL,">nextoutfitname = " + nextoutfitname);

                // the dialog not only OKs things - but fires off the dressing process
                llDialog(dollID, "You are being dressed in this outfit.",[nextoutfit], cd2667);
                //llSay(cd2667, nextoutfitname);
                llOwnerSay("You are being dressed in this outfit: " + nextoutfitname);
            }
        }

        //----------------------------------------
        // Channel: 2666
        //
        // Choosing a new outfit normally and manually: create a paged dialog with an
        // alphabetical list of available outfits, and let the user choose one
        //
        else if (channel == 2666) {
            list Outfits = llParseString2List(choice, [","], []); //what are brackets at end?
            integer n;
            integer iStop = llGetListLength(Outfits);
            string itemname;
            string prefix;

            // Collect names of possible new outfits, removing folders (items)
            // longer than 23 characters, those that start with "~" (hidden) or
            // with "*" (outfit folder). Also do not count current outfit name

            outfitsList = [];
            for (n = 0; n < iStop; n++) {
                itemname = llList2String(Outfits, n);

                if (llStringLength(itemname) < 24 &&
                    !isHiddenItem(itemname) &&
                    !isGroupItem(itemname) &&
                    !isTransformingItem(itemname) &&
                    itemname != oldoutfitname) {

                    outfitsList += itemname;
                }
            }

            // Sort: slow bubble sort
            outfitsList = llListSort(outfitsList,1,TRUE);

            // Now create appropriate menu page from full outfits list
            integer total = 0;
            outfitPage = 0;
            integer newOutfitCount = llGetListLength(outfitsList);

            list newoutfits2 = outfitsPage(outfitsList);
            if (newOutfitCount > 12) {
                newoutfits2 = ["Prev", "Next", "Page " + (string)(outfitPage+1)] + outfitsPage(outfitsList);
            }

            msgx = "You may choose any outfit.";

            if (dresserID == dollID) {
                msgx = "See " + outfits_url + " for more information on outfits.";
            }

            // Provide a dialog to user to choose new outfit
            llDialog(dresserID, msgx, newoutfits2, cd2667);
        }

        //----------------------------------------
        // Channel: 2667
        //
        // Handle a newly chosen outfit: outfit path relative to clothingFolder is the choice.
        // The original random code could also return a "OK" as choice, and this was filtered for.
        //
        else if (channel == cd2667) {
            llSay(DEBUG_CHANNEL,">>> channel 2667: " + choice);
            if (choice == "OK") {
                ; // No outfits: only OK is available
            } else if (choice == "Next") {
                outfitPage++;
                llDialog(dresserID, msgx, ["Prev", "Next", "Page " + (string)(outfitPage+1)] + outfitsPage(outfitsList), cd2667);
            } else if (choice == "Prev") {
                outfitPage--;
                llDialog(dresserID, msgx, ["Prev", "Next", "Page " + (string)(outfitPage+1)] + outfitsPage(outfitsList), cd2667);
            } else if (choice == "Page " + (string)(outfitPage+1)) {
                ; // Do nothing
            } else {
                candresstemp = FALSE;
                newoutfitname = choice;

                if (clothingFolder == "") {
                    newoutfit = choice;
                }
                else {
                    newoutfit = clothingFolder + "/" + choice;
                }

                newoutfitwordend = llStringLength(newoutfit)  - 1;
                llSay(DEBUG_CHANNEL,">>>newoutfit = " + newoutfit);

                //llOwnerSay("newoutfit is: " + newoutfit);
                //llOwnerSay("newoutfitname is: " + newoutfitname);
                //llOwnerSay("choice is: " + choice);
                //llOwnerSay("clothingFolder is: " + clothingFolder);

                // Four steps to dressing avi:
                //
                // 1) Replace every item that can be replaced (using the
                //    command @attachalloverorreplace)
                // 2) Add every item that didnt get put on the first time
                //    (using the @attachallover command)
                // 3) Remove the remaining portions of the old outfit
                // 4) Add items that are required for all outfits
                //    (using the @attach command)

                llOwnerSay("New outfit chosen: " + newoutfit);

                // Original outfit was a complete avi reset....
                // Restore our usual look from the ~normalself
                // folder...

                if ( isPlusItem(oldoutfitname) &&
                    !isPlusItem(newoutfitname)) {  // only works well assuming in regular

                    llOwnerSay("@attach:~normalself=force");
                    llSleep(4.0);

                    // FIXME: Make sure
                    //llOwnerSay("@attach:~normalself=force");
                    //llSleep(4.0);
                }

                // First, replace current outfit with new (or replace)
                llOwnerSay("@attach:" + newoutfit + "=force");
                llSleep(4.0);

                // FIXME: Try to make sure
                //llOwnerSay("@attach:" + newoutfit + "=force");
                //llSleep(4.0);

                // Add items that cant replace what is already there
                llOwnerSay("@attachallover:" + newoutfit + "=force");
                llSleep(4.0);

                // FIXME: Make sure
                //llOwnerSay("@attachallover:" + newoutfit + "=force");
                //llSleep(4.0);

                // Remove rest of old outfit
                if (oldoutfit) {
                    if (oldoutfit != newoutfit) {
                        llOwnerSay("@detachall:" + oldoutfit + "=force");
                        llSleep(4.0);

                        // FIXME: Make sure
                        //llOwnerSay("@detachall:" + oldoutfit + "=force");
                        //llSleep(4.0);
                    }
                }

                if (!isPlusItem(newoutfit)) {
                    // Attach items that should be present when we are nude...
                    // This could include things like (actual) tattoos, piercings,
                    // enhanced feet or lipstick or mascara, rings, etc.
                    //
                    // This is necessary because many items may be considered part
                    // of the "nude" outfit, but will still be removed during an
                    // automated removal process.  There is nothing to determine
                    // which are desired and which are not.
                    //
                    // Perhaps these things should be individually locked.
                    //
                    // This could also be expanded to create a Nude dress selection -
                    // such as for use when going to nude beaches and such.
                    llOwnerSay("@attach:~nude=force");
                    llSleep(4.0);

                    // FIXME: Make sure
                    //llOwnerSay("@attach:~nude=force");
                    //llSleep(4.0);
                }

                oldoutfit = newoutfit;
                oldoutfitname = newoutfitname;
                candresstimeout = 2;

                llOwnerSay("Change to new outfit " + newoutfitname + " complete.");
            }
        }

        //----------------------------------------
        // Channel: 2668
        //
        // Check to see if all items are fully worn; if not, try again
        //
        else if (channel == cd2668) {
            llSay(DEBUG_CHANNEL,">> @getinvworn:" + xfolder);
            if ((llGetSubString(choice,2,2)) != "3") {
                llSleep(4.0);
                llOwnerSay("@attach:" + xfolder + "=force");
                llOwnerSay("@getinvworn:" + xfolder + "=2668");
            }
        }

        //----------------------------------------
        // Channel: 2669
        //
        // Check to see if all items are fully removed; if not, try again
        //
        else if (channel == cd2669) {
            llSay(DEBUG_CHANNEL,">> @getinvworn:" + xfolder);
            if ((llGetSubString(choice,2,2)) != "1") {
                llSleep(4.0);
                llOwnerSay("@detach:" + xfolder + "=force");
                llOwnerSay("@getinvworn:" + xfolder + "=2669");
            }
        }
    }
}


