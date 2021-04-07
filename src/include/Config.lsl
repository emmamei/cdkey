#ifndef CONFIG_LSL
#define CONFIG_LSL
float Config_version=1.0;
#ifdef ADULT_MODE
#define ADULT ["Adult"]
#else
#define ADULT ["Child"]
#endif

#ifdef DEVELOPER_MODE
#define DEV ["Devel"]
#else
#define DEV []
#endif

#ifdef UPDATE_METHOD_CDKEY
#define UPCDKEY ["UpdateCDkey"]
#else
#define UPCDKEY []
#endif

#ifdef DEBUG_BADRLV
#define BADRLV ["DbgRlvFail"]
#else
#define BADRLV []
#endif

#ifdef DEBUG_LEVEL
#define DEBUG ["Debug="+(string)DEBUG_LEVEL]
#else
#define DEBUG []
#endif

#ifdef DEVELOPER_MODE
#define KEY_MODE ["Mode=Developer"]
#else
#define KEY_MODE ["Mode=Normal"]
#endif

#define BUILD_REPORT llListSort(ADULT + KEY_MODE + DEV + UPCDKEY + BADRLV + DEBUG, 1, 1)

#define lmConfigReport() llMessageLinked(LINK_THIS, 142, cdMyScriptName(), NULL_KEY)

//#define cdConfigReport() if (code == 142) llOwnerSay(__SHORTFILE__ + ":" + (string)__LINE__ + "\t\t\t\tCompiled  by " + __AGENTNAME__ + "\t" +  __DATE__ + " " + __TIME__ + "\nWith: " + llList2CSV(BUILD_REPORT))
#define cdConfigureReport() llOwnerSay(__SHORTFILE__ + ":" + (string)__LINE__ + "\t\t\t\tCompiled  by " + __AGENTNAME__ + "\t" +  __DATE__ + " " + __TIME__ + "\nWith: " + llList2CSV(BUILD_REPORT))

#endif //CONFIG_LSL
