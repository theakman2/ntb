/* A lot of this is just copied from Lua's interpreter source (lua.c) from Lua 5.1 */

#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "lib/lfs/lfs.h"
#define XXH_INLINE_ALL
#define XXH_STATIC_LINKING_ONLY
#include "vendor/xxhash/xxh3.h"

#define ntb_VERSION_MAJOR 1
#define ntb_VERSION_MINOR 0
#define ntb_VERSION_PATCH 0
#define ntb_VERSION_BUILD "alpha.111"

#define ntb_STRX(s) #s
#define ntb_STR(s) ntb_STRX(s)

#define ntb_VERSION ntb_STR(ntb_VERSION_MAJOR) "." ntb_STR(ntb_VERSION_MINOR) "." ntb_STR(ntb_VERSION_PATCH) "." ntb_VERSION_BUILD

static lua_State *globalLuaState_ = NULL;

static const char *progName_ = "(unknown)";

static void lstop_(lua_State *L, lua_Debug *ar) {
	(void)ar;
	lua_sethook(L, NULL, 0, 0);
	luaL_error(L, "interrupted!");
}

static void laction_(int i) {
	signal(i, SIG_DFL); /* if another SIGINT happens before lstop_, terminate process (default action) */
	lua_sethook(globalLuaState_, lstop_, LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1);
}

static void printUsage_(void) {
	fprintf(
		stderr,
		"NTB - A Hackable Build Generator"
		"\n" ntb_VERSION
		"\n"
		"\nUsage: %s [manifest path]"
		"\n"
		"\nOptions:"
		"\n-h, --help       Show help"
		"\n-v, --version    Show version"
		"\n",
		progName_);
	fflush(stderr);
}

static void lmessage_(const char *pname, const char *msg) {
	if (pname) {
		fprintf(stderr, "%s: ", pname);
	}
	fprintf(stderr, "%s\n", msg);
	fflush(stderr);
}

static int report_(lua_State *L, int status) {
	if (status && !lua_isnil(L, -1)) {
		const char *msg = lua_tostring(L, -1);
		if (msg == NULL) {
			msg = "(error object is not a string)";
		}
		lmessage_(progName_, msg);
		lua_pop(L, 1);
	}
	return status;
}

static int traceback_(lua_State *L) {
	if (!lua_isstring(L, 1)) { /* 'message' not a string? */
		return 1; /* keep it intact */
	}
	lua_getfield(L, LUA_GLOBALSINDEX, "debug");
	if (!lua_istable(L, -1)) {
		lua_pop(L, 1);
		return 1;
	}
	lua_getfield(L, -1, "traceback");
	if (!lua_isfunction(L, -1)) {
		lua_pop(L, 2);
		return 1;
	}
	lua_pushvalue(L, 1); /* pass error message */
	lua_pushinteger(L, 2); /* skip this function and traceback */
	lua_call(L, 2, 1); /* call debug.traceback */
	return 1;
}

static int doCall_(lua_State *L, int narg) {
	int status;
	int base = lua_gettop(L) - narg; /* function index */
	lua_pushcfunction(L, traceback_); /* push traceback function */
	lua_insert(L, base); /* put it under chunk and args */
	signal(SIGINT, laction_);
	status = lua_pcall(L, narg, 0, base);
	signal(SIGINT, SIG_DFL);
	lua_remove(L, base); /* remove traceback function */
	/* force a complete garbage collection in case of errors */
	if (status != 0) {
		lua_gc(L, LUA_GCCOLLECT, 0);
	}
	return status;
}

static void printVersion_(void) {
	lmessage_(NULL, ntb_VERSION);
}

static void getArgs_(lua_State *L, const char **argv, int argc) {
	lua_createtable(L, argc, 0);
	for (int i = 0; i < argc; ++i) {
		lua_pushstring(L, argv[i]);
		lua_rawseti(L, -2, i + 1);
	}
}

static void collectArgs_(const char **argv, int *pv, int *ph) {
	*pv = 0;
	*ph = 0;
	for (int i = 0; argv[i]; i++) {
		if ((strcmp(argv[i], "-h") == 0) || (strcmp(argv[i], "--help") == 0)) {
			*ph = 1;
		} else if ((strcmp(argv[i], "-v") == 0) || (strcmp(argv[i], "--version") == 0)) {
			*pv = 1;
		}
	}
}

struct Smain {
	int argc;
	int status;
	const char **argv;
};

int base32_encode(const uint8_t *data, int length, uint8_t *result, int bufSize) {
	int count = 0;
	if (length > 0) {
		int buffer = data[0];
		int next = 1;
		int bitsLeft = 8;
		while (count < bufSize && (bitsLeft > 0 || next < length)) {
			if (bitsLeft < 5) {
				if (next < length) {
					buffer <<= 8;
					buffer |= data[next++] & 0xFF;
					bitsLeft += 8;
				} else {
					int pad = 5 - bitsLeft;
					buffer <<= pad;
					bitsLeft += pad;
				}
			}
			int index = 0x1F & (buffer >> (bitsLeft - 5));
			bitsLeft -= 5;
			result[count++] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"[index];
		}
	}
	if (count < bufSize) {
		result[count] = '\000';
	}
	return count;
}

static int luaHash_(lua_State *lstate) {
	const char *data = luaL_checkstring(lstate, 1);
	uint8_t hashString[2 * sizeof(XXH128_hash_t)];
	union {
		XXH128_hash_t u128;
		uint8_t u8[sizeof(XXH128_hash_t)];
	} hash;
	hash.u128 = XXH128(data, strlen(data), 12345678);
	int outLen = base32_encode(hash.u8, sizeof(hash.u8), hashString, sizeof(hashString));
	lua_pushlstring(lstate, hashString, outLen);
	return 1;
}

static int pmain(lua_State *L) {
	struct Smain *s = (struct Smain *)lua_touserdata(L, 1);
	if (s->argv[0] && s->argv[0][0]) {
		progName_ = s->argv[0];
	}
	int has_v;
	int has_h;
	collectArgs_(s->argv + 1, &has_v, &has_h);
	if (has_v) {
		printVersion_();
		return 0;
	}
	if (has_h) {
		printUsage_();
		return 0;
	}

	globalLuaState_ = L;
	lua_gc(L, LUA_GCSTOP, 0); /* stop collector during initialization */

	luaL_openlibs(L); /* open libraries */
	lua_pushcfunction(L, luaHash_);
	lua_setglobal(L, "hash");
	luaopen_lfs(L);

	lua_gc(L, LUA_GCRESTART, 0);

	getArgs_(L, s->argv, s->argc); /* collect arguments */
	lua_setglobal(L, "arg");

	/* Execute the adjacent 'main.lua' script. */
	lua_getglobal(L, "require");
	lua_pushliteral(L, "ntb.main");
	s->status = doCall_(L, 1);
	return report_(L, s->status);
}

int main(int argc, const char **argv) {
	struct Smain s;
	lua_State *L = lua_open(); /* create state */
	if (L == NULL) {
		lmessage_(argv[0], "cannot create state: not enough memory");
		return EXIT_FAILURE;
	}
	s.argc = argc;
	s.argv = argv;
	int status = lua_cpcall(L, &pmain, &s);
	report_(L, status);
	lua_close(L);
	return (status || s.status) ? EXIT_FAILURE : EXIT_SUCCESS;
}
