-- Main build file. Only tested on Linux - may not work on other platforms.

local scriptDir;
if arg[0] == "build.lua" then
	scriptDir = ".";
else
	scriptDir = arg[0]:sub(1, -(2 + ("build.lua"):len()));
end
local scriptDirLen = scriptDir:len();

local osType = jit.os == "Windows" and "win" or "posix";
local sep = jit.os == "Windows" and "\\" or "/";

local function abs(fp)
	return scriptDir .. sep .. fp;
end

local luaScripts = {
	{ "ntb.c", abs("main/c.lua") },
	{ "ntb.common", abs("main/common.lua") },
	{ "ntb.importer", abs("main/importer.lua") },
	{ "ntb.main", abs("main/main.lua") },
	{ "ntb.misc", abs("main/misc.lua") },
	{ "ntb.ninjaFileBuilder", abs("main/ninjaFileBuilder.lua") },
	{ "ntb.ninjaFileWrite", abs("main/ninjaFileWrite.lua") },
};

local function pathSplit(fp)
	local dot;
	local slash;
	for i = fp:len(), 0, -1 do
		if dot and slash then
			break;
		end
		local c = fp:sub(i, i);
		if dot == nil and c == "." then
			dot = i;
		elseif slash == nil and c == sep then
			slash = i;
		end
	end
	if slash == nil then
		if dot == nil then
			return "", fp, "";
		end
		return "", fp:sub(1, dot - 1), fp:sub(dot);
	end
	if dot == nil or dot <= slash then
		return fp:sub(1, slash - 1), fp:sub(slash + 1), nil;
	end
	return fp:sub(1, slash - 1), fp:sub(slash + 1, dot - 1), fp:sub(dot);
end

local function luaLib(name, files)
	if type(files) == "string" then
		files = { files };
	end
	for _, file in ipairs(files) do
		local dir, base, ext = pathSplit(file);
		if (base == "init" and ext == ".lua") or base == name then
			table.insert(luaScripts, { name, file });
		else
			table.insert(luaScripts, { name .. "." .. base, file });
		end
	end
end

local function pl(names)
	local ret = {};
	for _, name in ipairs(names) do
		table.insert(ret, abs("main" .. sep .. "lib" .. sep .. "pl" .. sep .. name .. ".lua"));
	end
	return ret;
end

luaLib("pl", pl{
	"app",
	"array2d",
	"class",
	"compat",
	"comprehension",
	"config",
	"data",
	"Date",
	"dir",
	"file",
	"func",
	"import_into",
	"init",
	"input",
	"lapp",
	"lexer",
	"List",
	"luabalanced",
	"Map",
	"MultiMap",
	"operator",
	"OrderedMap",
	"path",
	"permute",
	"pretty",
	"seq",
	"Set",
	"sip",
	"strict",
	"stringio",
	"stringx",
	"tablex",
	"template",
	"test",
	"text",
	"types",
	"url",
	"utils",
	"xml",
});

local sources = {
	abs("main/main.c"),
	abs("main/lib/lfs/lfs.c"),
};

local luaCHeaders = {
	'lauxlib.h',
	'luaconf.h',
	'lua.h',
	'luajit.h',
	'lualib.h',
};

local buildBase = abs('build');

local function libObj(lib)
	local ext = jit.os == "Windows" and ".obj" or ".o";
	local p = lib:sub(scriptDirLen + 1);
	return buildBase .. sep .. 'obj' .. p .. ext;
end

local function getMainSourceFiles()
	local ret = {};
	for _, src in ipairs(sources) do
		table.insert(ret, src);
	end
	for _, lib in ipairs(luaScripts) do
		table.insert(ret, libObj(lib[2]));
	end
	return ret;
end

local function exec(cmd)
	print("Executing: " .. cmd);
	if os.execute(cmd) == nil then
		error("Command '" .. cmd .. "' failed.");
	end
end

local function quote(argument)
	if jit.os == "Windows" then
		if argument == "" or argument:find('[ \f\t\v]') then
			argument = '"' .. argument:gsub([[(\*)"]], [[%1%1\"]]):gsub([[\+$]], "%0%0") .. '"';
		end
		return (argument:gsub('["^<>!|&%%]', "^%0"));
	else
		if argument == "" or argument:find('[^a-zA-Z0-9_@%+=:,./-]') then
			argument = "'" .. argument:gsub("'", [['\'']]) .. "'";
		end
		return argument;
	end
end

local function getLuajitIncludeFile()
	local function tryIncludeDir(input, output)
		local compileCmd;
		if jit.os == "Windows" then
			compileCmd = 'cl.exe -TC -c ' .. quote(input) .. ' -Fo' .. quote(output) .. ' >nul 2>nul';
		else
			compileCmd = 'clang -I/usr/local/include -x c -c ' .. quote(input) .. ' -o ' .. quote(output) .. ' > /dev/null 2>&1';
		end
		return os.execute(compileCmd);
	end
	local function getCCode(prefix)
		local pref = '';
		if prefix and prefix ~= "" then
			pref = prefix .. '/';
		end
		local ret = {};
		for _, ch in ipairs(luaCHeaders) do
			table.insert(ret, '#include <' .. pref .. ch .. '>');
		end
		return table.concat(ret, '\n');
	end

	local prefixes = {'luajit-2.1', 'luajit-2.0', 'luajit', ''};
	for _, prefix in ipairs(prefixes) do
		local ccode = getCCode(prefix);
		local input = os.tmpname();
		local output = os.tmpname();

		local inp = io.open(input, 'w');
		inp:write(ccode);
		inp:close();
		local code = tryIncludeDir(input, output);
		os.remove(output);
		if code == 0 then
			return input;
		end
		os.remove(input);
	end
	return nil;
end

local function checkSourceFiles()
	local files = {
		"main/lib/lfs/lfs.c",
		"main/lib/lfs/lfs.h",
		"main/vendor/xxhash/xxhash.c",
		"main/vendor/xxhash/xxhash.h",
		"main/main.c",
	};
	for _, f in ipairs(files) do
		f = abs(f);
		local fh = io.open(f, "rb");
		local str = fh:read("*all");
		fh:close();
		for _, ch in ipairs(luaCHeaders) do
			if str:find(ch, 1, true) then
				return f;
			end
		end
	end
	return nil;
end

local function mkdirp(dir)
	if jit.os == "Windows" then
		os.execute('mkdir ' .. quote(dir));
	else
		os.execute('mkdir -p ' .. quote(dir));
	end
end

local function doPrebuildCommands()
	local f = checkSourceFiles();
	if f then
		error("File '" .. f .. "' must not include lua headers because they will be automatically inserted.");
	end
	for _, lib in ipairs(luaScripts) do
		local l = libObj(lib[2]);
		local name = lib[1];
		local dir = pathSplit(l);
		mkdirp(dir);
		exec('luajit -O3 -b -g -n ' .. quote(name) .. ' ' .. quote(lib[2]) .. ' ' .. quote(l));
	end
end

local function doBuildCommands()
	local inc = getLuajitIncludeFile();
	if not inc then
		error("Could not find luajit.");
	end
	local src = getMainSourceFiles();
	local buildBinDir = buildBase .. sep .. "bin";
	mkdirp(buildBinDir);
	if jit.os == "Windows" then
		local out = buildBinDir .. sep .. "ntb.exe";
		exec(
			'cl.exe'
			.. ' /Ox /FI ' .. quote(inc) .. ' /nologo /W3 /DNDEBUG /D_CRT_SECURE_NO_WARNINGS /DSODIUM_STATIC=1'
			.. ' ' .. table.concat(src, " ")
			.. ' lua51.lib'
			.. ' /Fe' .. quote(out)
		);
	else
		local out = buildBinDir .. sep .. "ntb";
		if jit.os == "Linux" then
			exec(
				'clang'
				.. ' -include ' .. quote(inc) .. ' -O3 -s -DNDEBUG -D_GNU_SOURCE=1 -std=gnu99 -Wall -Wextra -flto'
				.. ' ' .. table.concat(src, " ")
				.. ' -Wl,-Bstatic,-lluajit-5.1,-Bdynamic -Wl,-E -ldl -lm'
				.. ' -o ' .. quote(out)
			);
		elseif jit.os == "OSX" then
			exec(
				'clang'
				.. ' -include ' .. quote(inc) .. ' -O3 -DNDEBUG -D_GNU_SOURCE=1 -std=gnu99 -Wall -Wextra -flto'
				.. ' ' .. table.concat(src, " ")
				.. ' -lluajit-5.1 -ldl -lm -pagezero_size 10000 -image_base 100000000'
				.. ' -o ' .. quote(out)
			);
		else
			exec(
				'clang'
				.. ' -include ' .. quote(inc) .. ' -O3 -s -DNDEBUG -D_GNU_SOURCE=1 -std=gnu99 -Wall -Wextra -flto -fuse-ld=lld -I/usr/local/include -L/usr/local/lib'
				.. ' ' .. table.concat(src, " ")
				.. ' -Wl,-Bstatic,-lluajit-5.1,-Bdynamic -Wl,-E -lm'
				.. ' -o ' .. quote(out)
			);
		end
	end
	os.remove(inc);
end

local function compile()
	doPrebuildCommands();
	doBuildCommands();
end

compile();
