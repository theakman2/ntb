local objExtension = jit.os == "Windows" and ".obj" or ".o";
local exeExtension = jit.os == "Windows" and ".exe" or "";
local dllExtension = jit.os == "Windows" and ".dll" or ".so";

local common = require('ntb.common');

local ins = common.ins;
local flatten = common.flatten;
local reverseUniq = common.reverseUniq;

local function getObjectBuildPath(source, buildHash)
	local src = path.abspath(source, ntb.scriptDir);
	if src:sub(1, 1) == "/" then
		src = src:sub(2);
	elseif src:match("^%a:\\") then
		src = src:sub(4);
	end
	return path.join(ntb.buildDirectory, "obj", src, buildHash, "obj" .. objExtension);
end

local function getCompileCmd(flags, isCpp)
	local ret = {};
	local args = {};
	local bin = isCpp and "clang++" or "clang";
	local prop = isCpp and "cppflags" or "cflags";

	ins(args, {bin, "-MP", "-MD", "-MF $out.d"});
	ins(args, ntb.target[prop]);
	ins(args, common.flatten(flags));
	ins(args, {"-c", "$in", "-o $out"});
	reverseUniq(args, ret);
	return table.concat(ret, ' ');
end

local cMt = {};

local function compileOneRaw(self, isCpp, source, cFlags, deps, odeps, implicitOutputs, vars)
	local source = path.abspath(source, ntb.scriptDir);
	local cmd = getCompileCmd(cFlags, isCpp);
	local cmdHash = common.hashItem({cmd, vars});
	local out = getObjectBuildPath(source, cmdHash);
	local compileRule = rule{
		command = cmd;
		deps = "gcc";
		depfile = "$out.d";
	};
	build(out, compileRule, source, deps, odeps, implicitOutputs, vars);
	self.compileRuleNames[compileRule] = compileRule;
	self.allSourceFiles[source] = source;
	return out;
end;

local function compileRaw(self, isCpp, source, ...)
	if type(source) == "table" then
		source = flatten(source);
		local ret = {};
		for _, item in ipairs(source) do
			table.insert(ret, compileOneRaw(self, isCpp, item, ...));
		end
		return ret;
	end
	return compileOneRaw(self, isCpp, source, ...);
end;

cMt.cppcompile = function(self, ...)
	return compileRaw(self, true, ...);
end;

cMt.ccompile = function(self, ...)
	return compileRaw(self, false, ...);
end;

local function getBinaryCommand(ldFlags, isCpp, isSharedObject)
	local args = {};
	local bin = isCpp and "clang++" or "clang";
	ins(args, {bin, "-o $out", "$in"});
	ins(args, ntb.target.ldflags);
	ins(args, common.flatten(ldFlags));
	if isSharedObject then
		ins(args, {"-shared"});
	end
	local ret = {};
	reverseUniq(args, ret);
	return table.concat(ret, ' ');
end

local function getBinaryOutputPath(name)
	return path.join(ntb.buildDirectory, 'bin', name .. exeExtension);
end

local function getDllOutputPath(name)
	return path.join(ntb.buildDirectory, 'dll', name .. dllExtension);
end

local function binaryRaw(self, isCpp, isSharedObject, name, objectFilePaths, ldFlags, deps, odeps, implicitOutputs, vars)
	local out = isSharedObject and getDllOutputPath(name) or getBinaryOutputPath(name);
	local cmd = getBinaryCommand(ldFlags, isCpp, isSharedObject);
	local binaryRule = rule(cmd);
	build(out, binaryRule, flatten(objectFilePaths), deps, odeps, implicitOutputs, vars);
	return out;
end;

cMt.cppbinary = function(self, ...)
	return binaryRaw(self, true, false, ...);
end;

cMt.cbinary = function(self, ...)
	return binaryRaw(self, false, false, ...);
end;

cMt.cppdll = function(self, ...)
	return binaryRaw(self, true, true, ...);
end;

cMt.cdll = function(self, ...)
	return binaryRaw(self, false, true, ...);
end;

cMt.writeCompileDatabaseCommand = function(self)
	local rulesList = {};
	for _, r in pairs(self.compileRuleNames) do
		table.insert(rulesList, r);
	end
	table.sort(rulesList);
	local allSourceFiles = {};
	for _, s in pairs(self.allSourceFiles) do
		table.insert(allSourceFiles, s);
	end
	table.sort(allSourceFiles);
	local rulesString = table.concat(rulesList, ' ');
	local r = rule("ninja -f $in -t compdb " .. rulesString .. " > $out");
	build(path.join(ntb.projectsDirectory, "compile_commands.json"), r, path.join(ntb.buildDirectory, "build.ninja"), allSourceFiles);
end;

cMt.registerGlobals = function(self)
	_G.getBinaryOutputPath = getBinaryOutputPath;
	_G.getDllOutputPath = getDllOutputPath;
	_G.cppcompile = func.bind1(self.cppcompile, self);
	_G.ccompile = func.bind1(self.ccompile, self);
	_G.cppbinary = func.bind1(self.cppbinary, self);
	_G.cbinary = func.bind1(self.cbinary, self);
	_G.cppdll = func.bind1(self.cppdll, self);
	_G.cdll = func.bind1(self.cdll, self);
end;

local function cCreate()
	return setmetatable(
		{
			compileRuleNames = {};
			allSourceFiles = {};
		},
		{
			__index = cMt;
		}
	);
end

return cCreate;