#ifndef UTILITY_LSL
#define UTILITY_LSL
#include "config.h"
float Utility_version=1.0;

// This allows "oneshot" RLV commands without spamming
// non-RLV users.
#define cdRlvSay(a) if (rlvOk == TRUE) llOwnerSay(a)
#define cdUserProfile(id) "secondlife:///app/agent/"+(string)id+"/about"

/*
 * ========================================
 * UTILITY FUNCTIONS
 * ========================================
 */
string wwGetSLUrl() {
    vector pos = llGetPos();
    string posx = (string)llRound(pos.x);
    string posy = (string)llRound(pos.y);
    string posz = (string)llRound(pos.z);

    return ("secondlife://" + llEscapeURL(llGetRegionName()) +"/" + posx + "/" + posy + "/" + posz);
}

list dialogSort(list srcButtons) {
    list outButtons;

    // This function realigns the buttons so we can
    // get the proper buttons in the proper places:
    //
    // (Placeholders only: in actual lists, strings are
    // required, not integers.)
    //
    // INPUT: [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 ]
    //
    // OUTPUT: [ 10, 11, 12, 7, 8, 9, 4, 5, 6, 1, 2, 3 ]

    while (llGetListLength(srcButtons) != 0) {
        outButtons += (list)srcButtons[-3, -1];
        srcButtons = llDeleteSubList(srcButtons, -3, -1);
    }

    return outButtons;
}

#define isCollapseAnimationPresent() (llGetInventoryType(ANIMATION_COLLAPSED) == INVENTORY_ANIMATION)
#define isPreferencesNotecardPresent() (llGetInventoryType(NOTECARD_PREFERENCES) == INVENTORY_NOTECARD)
#define isAnimationPresent(a) (llGetInventoryType(a) == INVENTORY_ANIMATION)
#define isNotecardPresent(a) (llGetInventoryType(a) == INVENTORY_NOTECARD)
#define isLandmarkPresent(a) (llGetInventoryType(a) == INVENTORY_LANDMARK)

integer numberOfPosesPresent() {
    integer poseCount;

    poseCount = llGetInventoryNumber(INVENTORY_ANIMATION);

    if (poseCount > 0) {
        // There are animations - but one could be the collapse animation
        if (isCollapseAnimationPresent()) poseCount--;
    }

    return poseCount;
}

integer arePosesPresent() {
    integer poseCount;
    integer inventoryType;

    poseCount = llGetInventoryNumber(INVENTORY_ANIMATION);

    if (poseCount == 0) {
        llSay(DEBUG_CHANNEL, "No animations found!");
    }
    else {
        // Either there are more than two animations, which means at least one pose -
        // or there is one pose, which may or may not be a pose (could be a collapse animation)
        if (poseCount > 2) return TRUE;
        else if (!isCollapseAnimationPresent()) return TRUE;
    }

    return FALSE;
}

#define getNotecardName(n) llGetInventoryName(INVENTORY_NOTECARD, (n))

integer areTypesPresent() {
    integer notecardCount;
    integer i;

    notecardCount = llGetInventoryNumber(INVENTORY_NOTECARD);

    if (notecardCount == 0) {
        return FALSE;
    }
    else {
        // There are notecards, but are they notecards for types?
        i = notecardCount;

        while(i--) {
            // Types have notecards starting with "*"
            if (cdGetFirstChar(getNotecardName(i)) == "*") return TRUE;
        }
    }

    return FALSE;
}

memReport(string script, float delay) {
    if (delay != 0.0) llSleep(delay);

    integer usedMemory = llGetUsedMemory();
    integer memoryLimit = llGetMemoryLimit();
    integer freeMemory = memoryLimit - usedMemory;
    integer availMemory = freeMemory + (65536 - memoryLimit);

    cdLinkMessage(LINK_THIS,0,136,
        (string)usedMemory + "|" +
        (string)memoryLimit + "|" +
        (string)freeMemory + "|" +
        (string)availMemory,llGetKey());
}

#ifdef DEVELOPER_MODE
#define debugSay(level,prefix,msg) if (debugLevel >= level) llOwnerSay( \
    prefix+"("+((string)level)+"):"+((string)__LINE__)+": "+(msg))
#define debugPrint(prefix,msg) llOwnerSay(prefix+":"+((string)__LINE__)+": "+(msg))
#else
#define debugSay(level,prefix,msg)
#define debugPrint(prefix,msg)
#endif

/*
 * ----------------------------------------
 * NUMERIC FUNCTIONS
 * ----------------------------------------
 */
string formatFloat(float val, integer dp) {
    string out = "ERROR";

    if (dp == 0) {
        out = (string)llRound(val);
    } else if (dp > 0 && dp <= 6) {
        val = llRound(val * llPow(10.0, dp)) / llPow(10.0, dp);
        out = llGetSubString((string)val, 0, -7 + dp);
    }
    return out;
}

// Instead of the generic formatFlot(), using the following should
// result in memory savings and speed increase.
//
string formatFloat1(float val) {
    val = llRound(val * 10.0) / 10.0;
    return llGetSubString((string)val, 0, -6);
}

string formatFloat2(float val) {
    val = llRound(val * 100.0) / 100.0;
    return llGetSubString((string)val, 0, -5);
}

string bits2nybbles(integer bits) {
    string nybbles = "";

    do {
        integer lsn = bits & 0xF; // least significant nybble
        nybbles = llGetSubString("0123456789ABCDEF", lsn, lsn) + nybbles;
    } while (bits = (0xfffFFFF & (bits >> 4)));
    return nybbles;
}

/*
 * ----------------------------------------
 * DATE/TIME FUNCTIONS
 * ----------------------------------------
 */
// Useful constants
#define DAY_TO_YEAR 365
#define SEC_TO_YEAR 31536000
#define SEC_TO_DAY 86400
#define SEC_TO_HOUR 3600

#define MONTHS_SHORT [ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" ]
#define MONTHS_FULL [ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" ]

string formatDuration(float time, integer inDays) {
    integer t = (integer)time;
    integer s = (t % 60);
    integer m = ((t % 3600) / 60);
    integer h; integer d;
    string ret;
    if (inDays) {
        h = ((t % 86400) / 3600);
        d = (t / 86400);
        if (d != 0) ret = (string)d + " days, ";
    }
    else h = (t / 3600);

    if (h != 0 && h <= 9) ret += "0" + (string)h + ":";
    else if (h > 9) ret += (string)h + ":";
    if (m <= 9) ret += "0" + (string)m + ":";
    else ret += (string)m + ":";
    if (s <= 9) ret += "0" + (string)s;
    else ret += (string)s;

    return ret;
}

#define isLeapYear(year) !(year & 3)
#define daysPerYear(year) (365 + isLeapYear(year))

#define getDate() dateString(llList2List(unix2DateTime(llGetUnixTime()), 0, 2), "/", 0)

integer daysPerMonth(integer year, integer month) {
    if (month == 2) return 28 + isLeapYear(year);
    return 30 + ( (month + (month > 7) ) & 1);
}

list unix2DateTime(integer unixtime) {
    integer days_since_1_1_1970     = unixtime / SEC_TO_DAY;
    integer day = days_since_1_1_1970 + 1;
    integer year  = 1970;
    integer days_per_year = daysPerYear(year);

    while (day > days_per_year) {
        day -= days_per_year;
        ++year;
        days_per_year = daysPerYear(year);
    }

    integer month = 1;
    integer days_per_month = daysPerMonth(year, month);

    while (day > days_per_month) {
        day -= days_per_month;

        if (++month > 12) {
            ++year;
            month = 1;
        }

        days_per_month = daysPerMonth(year, month);
    }

    integer seconds_since_midnight  = unixtime % SEC_TO_DAY;
    integer hour        = seconds_since_midnight / SEC_TO_HOUR;
    integer second      = seconds_since_midnight % SEC_TO_HOUR;
    integer minute      = second / SEC_TO_MIN;
    second              = second % SEC_TO_MIN;

    return [ year, month, day, hour, minute, second ];
}

#ifdef NOT_USED
// This doesn't compile, either...
string monthName(integer month, integer long) {
    if (month >= 0 && month < 12 && long == 2) return (string)MONTHS_FULL[month]);
    else if (month >= 0 && month < 12 && long == 1) return (string)MONTHS_SHORT[month]);
    else if (month >= 0 && month < 12 && long == 0) return (string)month;
    else return "";
}
#endif

string dateString(list timelist, string seperator, integer long) {
    if (seperator == "") seperator = "-";

    integer year       = (integer)timelist[0];
    integer month      = (integer)timelist[1];
    integer day        = (integer)timelist[2];

    return (string)day + seperator + monthName(month - 1, long) + seperator + (string)year;
}

string timeString(list timelist) {
    integer index = 0;
    if (llGetListLength(timelist) == 6) index += 3;
    string  hourstr     = llGetSubString ( (string) (100 + (integer)timelist[index++] ), -2, -1);
    string  minutestr   = llGetSubString ( (string) (100 + (integer)timelist[index++] ), -2, -1);
    string  secondstr   = llGetSubString ( (string) (100 + (integer)timelist[index++] ), -2, -1);
    return  hourstr + ":" + minutestr + ":" + secondstr;
}

integer dateTime2Unix(integer year, integer month, integer day, integer hour, integer minute, integer second) {
    integer time = 0;
    integer yr = 1970;
    integer mt = 1;
    integer days;

    while(yr < year)
    {
        days = daysPerYear(yr++);
        time += days * SEC_TO_DAY;
    }

    while (mt < month)
    {
        days = DaysPerMonth(year, mt++);
        time += days * SEC_TO_DAY;
    }

    days = day - 1;
    time += days * SEC_TO_DAY;
    time += hour * SEC_TO_HOUR;
    time += minute * SEC_TO_MIN;
    time += second;

    return time;
}

#define MAX_LIMIT 65536
#define MIN_LIMIT 16384
#define MEM_BUFFER_SIZE 6144

/*
 * ----------------------------------------
 * MEMORY SCALING
 * ----------------------------------------
 */
scaleMem() {
   integer used = llGetUsedMemory();
   integer limit = llGetMemoryLimit();
   integer free = limit - used;
   integer newlimit;
   //integer short = 1024;

   // If this fails it is probably an LSL2 compiled script not mono and the
   // rest can't apply.
   //if ((free + used) <= (limit * 1.05)) {

      // note carefully: "limit" is the CURRENT memory limit, not Max
      newlimit = llCeil((float)(limit - (free - 6144)) / 1024.0) * 1024;

      // Bump up a minimum of 4k
      if (newlimit > limit && newlimit < limit + 4096) newlimit = limit + 4096;

      // clip newlimit inside reasonable limits
      if (newlimit < MIN_LIMIT) newlimit = MIN_LIMIT;
      else if (newlimit > MAX_LIMIT) newlimit = MAX_LIMIT;

      // This uses adjusted newlimit, not the unmodified one:
      // saves having to clip the value to Max and setting it to Max
      // repeatedly, for instance

      if (newlimit != limit) {

#ifdef DEVELOPER_MODE
         string s = myName + " Memory limit has been ";
#endif
         // if more memory appears necessary, do it
         // if reducing... stall until 4k can be freed up
         // This reduces the number of memory changes for speed

         if (newlimit > limit) {
            llSetMemoryLimit(newlimit);
#ifdef DEVELOPER_MODE
            debugSay(5, "DEBUG", (s + "increased " + formatFloat((float)(newlimit - limit) / 1024.0, 2) + "kB to " + formatFloat((float)newlimit / 1024.0, 2) + "kB"));
            if (newlimit == MAX_LIMIT)
                debugSay(2, "DEBUG", "WARNING! Maximum reached in script " + myName);
            else if (MAX_LIMIT - newlimit <= 6144)
                debugSay(2, "DEBUG", "WARNING! Low memory (" + formatFloat((float)(MAX_LIMIT - newlimit) / 1024.0, 2) + "kB) reached in script " + myName);
#endif
         }
         else if (limit - newlimit > 4096) {
            llSetMemoryLimit(newlimit);
#ifdef DEVELOPER_MODE
            debugSay(5, "DEBUG", (s + "decreased " + formatFloat((float)(newlimit - limit) / 1024.0, 2) + "kB to " + formatFloat((float)newlimit / 1024.0, 2) + "kB"));
#endif
         }
      }
   //}
}
#endif // UTILITY_LSL

