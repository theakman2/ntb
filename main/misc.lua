local common = require('ntb.common');

local ins = common.ins;
local flatten = common.flatten;
local reverseUniq = common.reverseUniq;

local objExt = jit.os == "Windows" and ".obj" or ".o";

return function()
	local re2cRule = rule("re2c --tags -W -Werror -o $out $in");
	local yasmRule;
	if jit.os == "Windows" then
		yasmRule = 'yasm -D __' .. jit.os .. '__ -f x64 -X vc -g cv8 -o $out $in';
	else
		yasmRule = 'yasm -D __' .. jit.os .. '__ -f elf64 -X gnu -g dwarf2 -o $out $in';
	end;
	yasmRule = rule(yasmRule);

	local glslToSpirvRule;
	if ntb.target.kind == "rel" then
		glslToSpirvRule = "glslc -MD -MF $out.d -O -Werror $in -o $out";
	else
		glslToSpirvRule = "glslc -MD -MF $out.d -g -O0 -Werror $in -o $out";
	end
	glslToSpirvRule = rule{
		command = glslToSpirvRule;
		deps = "gcc";
		depfile = "$out.d";
	};

	local function re2c(filePath, ...)
		filePath = path.abspath(filePath, ntb.scriptDir);
		local outputFile = common.getOutputPath(filePath, 're2c') .. '.c';
		build(outputFile, re2cRule, filePath, ...);
		return outputFile;
	end

	local function yasm(inputFile)
		inputFile = path.abspath(inputFile, ntb.scriptDir);
		local outputFile = common.getOutputPath(inputFile, 'yasm') .. objExt;
		build(outputFile, yasmRule, inputFile);
		return outputFile;
	end

	local function glslToSpirv(inputFile, ...)
		inputFile = path.abspath(inputFile, ntb.scriptDir);
		local outputFile = common.getOutputPath(inputFile, 'glslToSpirv') .. ".spv";
		build(outputFile, glslToSpirvRule, inputFile, ...);
		return outputFile;
	end

	local function luaToObj(moduleName, source, ...)
		local inputFile = path.abspath(source, ntb.scriptDir);

		local outputFile = common.getOutputPath(inputFile, 'luaToObj') .. objExt;
		local luaToObjRule;
		if ntb.target.kind == "rel" then
			luaToObjRule = rule('luajit -O3 -b -g -n ' .. moduleName .. ' $in $out');
		else
			luaToObjRule = rule('luajit -O0 -b -g -n ' .. moduleName .. ' $in $out');
		end
		build(outputFile, luaToObjRule, inputFile, ...);
		return outputFile;
	end

	local function luaObjToBinary(name, objectFilePaths, ldFlags, ...)
		local finalLdFlags = {
			'-Wl,-Bstatic,-lluajit-5.1,-Bdynamic',
			'-Wl,-E',
			'-ldl',
			'-lm',
			'-fuse-ld=bfd',
		};
		ins(finalLdFlags, ldFlags);
		return cbinary(name, objectFilePaths, finalLdFlags, ...);
	end

	_G.re2c = re2c;
	_G.yasm = yasm;
	_G.glslToSpirv = glslToSpirv;
	_G.luaToObj = luaToObj;
	_G.luaObjToBinary = luaObjToBinary;
end;