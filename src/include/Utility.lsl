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

list dialogSort(list srcButtons) {
    list outButtons;
    while (llGetListLength(srcButtons) != 0) {
        outButtons += llList2List(srcButtons, -3, -1);
        srcButtons = llDeleteSubList(srcButtons, -3, -1);
    }
    return outButtons;
}


memReport(float delay) {
    if (delay != 0.0) llSleep(delay);
    float memory_limit = (float)llGetMemoryLimit();
    float free_memory = (float)llGetFreeMemory();
    float used_memory = (float)llGetUsedMemory();
    float max_memory = free_memory + (65536 - memory_limit);
    if (((used_memory + free_memory) > (memory_limit * 1.05)) && (memory_limit <= 16384)) { // LSL2 compiled script
       memory_limit = 16384;
       used_memory = 16384 - free_memory;
       max_memory = free_memory;
    }
    lmMemReply(used_memory, memory_limit, free_memory, max_memory);
}

#ifdef DEVELOPER_MODE
#ifdef DEBUG_HANDLER
#define debugSay(level,prefix,msg) debugMainHandler(SCRIPT_NAME, level, prefix, msg)
#define debugHandler(script,level,prefix,msg) debugMainHandler(script, level, prefix, msg)
#define linkDebug(sender,code,data,id) linkDebugHandler(sender, code, data, id)
#else
#define debugSay(level,prefix,msg) if (debugLevel >= level) llMessageLinked(LINK_THIS, 700, SCRIPT_NAME + "|" + (string)level + "|" + prefix + "|" + msg, NULL_KEY)
#endif
#else
#define debugSay(level,prefix,msg)
#define debugHandler(script,level,prefix,msg)
#define linkDebug(sender,code,data,id)
#endif //DEVELOPER_MODE

#ifdef DEVELOPER_MODE
linkDebugHandler(string sender, integer code, string data, key id) {
    if (!configured && (code == 300) && (initState == 104)) return;

    list split = llParseStringKeepNulls(data, ["|"], []);
    string script = llList2String(split, 0);
    if (llGetInventoryType(script) != INVENTORY_SCRIPT) llShout(DEBUG_CHANNEL, "Error invalid script name in link " + (string)code + " with data = " + data);
    data = llDumpList2String(llDeleteSubList(split, 0, 0), "|");

    integer level = 5;
         if (llListFindList([ 350, 399, 999 ], [ code ]) != -1)                 level = 2;
    else if (llListFindList([ 102, 150, 305, 850 ], [ code ]) != -1)		level = 3;
    else if (llListFindList([ 110 ], [ code ]) != -1)                           level = 4;
    else if (llListFindList([ 104, 105, 135, 136, 500 ], [ code ]) != -1)       level = 6;
    else if (llListFindList([ 300 ], [ code ]) != -1)                           level = 7;
    else if (llListFindList([ 315, 320 ], [ code ]) != -1)                      level = 8;
    
    string msg = (string)code;
    if (data != "") msg += ", " + data;
    if (id != NULL_KEY) msg += " - " + (string)id;
    
    debugHandler(sender, level, "LINK-DEBUG", msg);
}

debugMainHandler(string script, integer level, string prefix, string msg) {
    if (debugLevel >= level) {
        msg = formatFloat(llGetTime() - rezTime, 3) + " " + prefix + "(" + (string)level + "/" + (string)debugLevel + "): " + script + ": " + msg;
        if (DEBUG_TARGET == 1) llOwnerSay(msg);
        else llSay(DEBUG_CHANNEL, msg);
    }
}
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
         debugSay(7, "DEBUG", "Memory limit changed from " + formatFloat((float)limit / 1024.0, 2) + "kB to " + formatFloat((float)newlimit / 1024.0, 2) + "kB (" + formatFloat((float)(newlimit - limit) / 1024.0, 2) + "kB) " + formatFloat((float)llGetFreeMemory() / 1024.0, 2) + "kB free");
      }
   }
}
#endif // UTILITY_LSL

