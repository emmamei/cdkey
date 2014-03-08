#ifdef ADULT_MODE
#define ADULT ["Adult"]
#else
#define ADULT []
#endif

#ifdef DEVELOPER_MODE
#define DEV ["Devel"]
#else
#define DEV []
#endif

#ifdef TESTER_MODE
#define TEST ["Test"]
#else
#define TEST []
#endif

#ifdef SIM_FRIENDLY
#define FRI ["LowScript"]
#else
#define FRI []
#endif

#ifdef LINK_320
#define L320 ["Link320"]
#else
#define L320 []
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

#ifdef SALT
#define HAVE_SALT ["HaveSalt=yes"]
#else
#define HAVE_SALT ["HaveSalt=no"]
#endif

#define BUILD_REPORT llListSort(ADULT + DEV + L320 + HAVE_SALT + FRI + TEST + UPCDKEY + BADRLV + DEBUG, 1, 1)

#define lmConfigReport() llMessageLinked(LINK_THIS, 142, SCRIPT_NAME, NULL_KEY)

#define cdConfigReport() if (code == 142) llOwnerSay(SCRIPT_NAME + ":\t\tCompiled  by " + __AGENTNAME__ + "\t" +  __DATE__ + " " + __TIME__ + "\nWith: " + llList2CSV(BUILD_REPORT))
