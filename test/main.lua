local sep = jit.os == "Windows" and "\\" or "/";
local scriptDir;
if arg[0] == "main.lua" then
	scriptDir = ".";
else
	scriptDir = arg[0]:sub(1, -(2 + ("main.lua"):len()));
end

local function bin()
	return scriptDir .. sep .. ".." .. sep .. "build" .. sep .. "bin" .. sep .. "ntb";
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

local function rmdir(fp)
	if jit.os == "Windows" then
		os.execute('rmdir /s /q ' .. quote(fp));
	else
		os.execute('rm -rf ' .. quote(fp));
	end
end

local function testBuild(fp, binaries)
	local testName = fp;
	fp = scriptDir .. sep .. fp;
	fp = fp:gsub('/', sep);
	local fpdir = fp;
	local fplen = fpdir:len();
	for i = fplen, 0, -1 do
		if fpdir:sub(i, i) == sep then
			fpdir = fp:sub(1, i - 1);
			break;
		end
	end

	local ntbconf = dofile(fp);

	local buildDir = fpdir .. sep .. "_out";

	local exeSuffix = jit.os == "Windows" and ".exe" or "";
	local expectedBinaries = {};
	for _, bin in ipairs(binaries) do
		table.insert(expectedBinaries, buildDir .. sep .. bin .. exeSuffix);
	end
	table.sort(expectedBinaries);
	local expectedBinaryCount = #expectedBinaries;

	local function resetTest()
		rmdir(buildDir);
	end

	local function run()
		local code = os.execute(bin() .. " " .. quote(fp));
		assert(code == 0);
		for _, targ in ipairs(ntbconf.targets) do
			local ninjaPath = buildDir .. sep .. targ.name .. sep .. "build.ninja";
			local code = os.execute("ninja -f " .. quote(ninjaPath));
			assert(code == 0);
		end
		for _, bin in ipairs(expectedBinaries) do
			local f = io.open(bin, "rb");
			local exists = f ~= nil;
			if f then
				f:close();
			end
			if not exists then
				error("binary '" .. bin .. "' does not exist");
			end
		end
		for _, f in ipairs(expectedBinaries) do
			local code = os.execute('"' .. f .. '"');
			assert(code == 0);
		end
	end

	print("running test: " .. testName);
	resetTest();
	local _, err = pcall(run);
	resetTest();
	if err then
		print("ERROR on test: " .. testName);
		error(err);
	else
		print("SUCCESS");
	end
end

testBuild(
	"simple/ntbconf.lua",
	{"dbg/bin/foo", "rel/bin/foo"}
);
testBuild(
	"project with spaces/ntbconf.lua",
	{"t1/bin/b", "t1/bin/c", "t2/bin/b", "t2/bin/c"}
);
testBuild(
	"complex/ntbconf.lua",
	{"dbg/bin/bin1", "dbg/bin/bin2", "rel/bin/bin1", "rel/bin/bin2"}
);