#ifndef UTILITY_LSL
#define UTILITY_LSL
/*
 * ========================================
 * UTILITY FUNCTIONS
 * ========================================
 */
string wwGetSLUrl() {
    string region = llGetRegionName();
    vector pos = llGetPos();
    string posx = (string)llRound(pos.x);
    string posy = (string)llRound(pos.y);
    string posz = (string)llRound(pos.z);

    return ("secondlife://" + llEscapeURL(region) +"/" + posx + "/" + posy + "/" + posz);
}

integer isKeyFormat(string input) {
    if (llStringLength(input) != 36) return 0;
    integer i; list dashes = [ 8, 13, 18, 23 ];
    //string part = llGetSubString(input, 0, 7);
    //if ((integer)("0x" + part) == 0 && part != "00000000") return 0;
    if (llGetSubString(input, 8, 8) != "-") return 0;
    //part = llGetSubString(input, 9, 12);
    //if ((integer)("0x" + part) == 0 && part != "0000") return 0;
    if (llGetSubString(input, 13, 13) != "-") return 0;
    //part = llGetSubString(input, 14, 17);
    //if ((integer)("0x" + part) == 0 && part != "0000") return 0;
    if (llGetSubString(input, 18, 18) != "-") return 0;
    //part = llGetSubString(input, 19, 22);
    //if ((integer)("0x" + part) == 0 && part != "0000") return 0;
    if (llGetSubString(input, 23, 23) != "-") return 0;
    //part = llGetSubString(input, 24, 31);
    //if ((integer)("0x" + part) == 0 && part != "00000000") return 0;
    //part = llGetSubString(input, 31, 35);
    //if ((integer)("0x" + part) == 0 && part != "0000") return 0;
    
    return 1;
}

#ifdef DEVELOPER_MODE
memReport(float delay) {
    if (delay != 0.0) llSleep(delay);
    float memory_limit = (float)llGetMemoryLimit();
    float free_memory = (float)llGetFreeMemory();
    float used_memory = (float)llGetUsedMemory();
    if (((used_memory + free_memory) > (memory_limit * 1.05)) && (memory_limit <= 16384)) { // LSL2 compiled script
       memory_limit = 16384;
       used_memory = 16384 - free_memory;
    }
    llOwnerSay(SCRIPT_NAME + ": Memory " + formatFloat(used_memory/1024.0, 2) + "/" + (string)llRound((memory_limit)/1024.0) + "kB, " + formatFloat(free_memory/1024.0, 2) + " kB free");
}
#else
#define memReport(dummy)
#endif // DEVELOPER_MODE

debugSay(integer level, string msg) {
    if (DEBUG_LEVEL >= level) {
        msg = "DEBUG(" + (string)level + "): " + llGetScriptName() + ": " + msg;
        if (DEBUG_TARGET == 1) llOwnerSay(msg);
        else llSay(DEBUG_CHANNEL, msg);
    }
}
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

string bits2nybbles(integer bits) {
    string nybbles = "";
    do
    {
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

string monthName(integer month, integer long) {
    if (month >= 0 && month < 12 && long == 2) return llList2String(MONTHS_FULL, month);
    else if (month >= 0 && month < 12 && long == 1) return llList2String(MONTHS_SHORT, month);
    else if (month >= 0 && month < 12 && long == 0) return (string)month;
    else return "";
}

string dateString(list timelist, string seperator, integer long) {
    if (seperator == "") seperator = "-";

    integer year       = llList2Integer(timelist,0);
    integer month      = llList2Integer(timelist,1);
    integer day        = llList2Integer(timelist,2);

    return (string)day + seperator + monthName(month - 1, long) + seperator + (string)year;
}

string timeString(list timelist) {
    integer index = 0;
    if (llGetListLength(timelist) == 6) index += 3;
    string  hourstr     = llGetSubString ( (string) (100 + llList2Integer(timelist, index++) ), -2, -1);
    string  minutestr   = llGetSubString ( (string) (100 + llList2Integer(timelist, index++) ), -2, -1);
    string  secondstr   = llGetSubString ( (string) (100 + llList2Integer(timelist, index++) ), -2, -1);
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
/*
 * ----------------------------------------
 * MEMORY SCALING
 * ----------------------------------------
 */
scaleMem() {
   integer free = llGetFreeMemory();
   integer used = llGetUsedMemory();
   integer limit = llGetMemoryLimit();
   integer newlimit = limit;
   integer short = 1024;
   if ((free + used) <= (limit * 1.05)) {
      // If this fails it is probably an LSL2 compiled script not mono and the
      // rest can't apply.
      newlimit = llCeil((float)(limit - (free - 6144)) / 1024.0) * 1024;

      if (newlimit < 16384) newlimit=16384;
      else if (newlimit > 65536) newlimit=65536;

      if (newlimit != limit) {
         llSetMemoryLimit(newlimit);
         debugSay(7, "Memory limit changed from " + formatFloat((float)limit / 1024.0, 2) + "kB to " + formatFloat((float)newlimit / 1024.0, 2) + "kB (" + formatFloat((float)(newlimit - limit) / 1024.0, 2) + "kB) " + formatFloat((float)llGetFreeMemory() / 1024.0, 2) + "kB free");
      }
      //debugSay(5, SCRIPT_NAME + ":  free=" + (string)free + " used=" + (string)used + " short=" + (string)short + " limit=" + (string)limit + " newlimit=" + (string)newlimit);
   }
}
#endif // UTILITY_LSL

