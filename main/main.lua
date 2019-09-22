-- The lfs module has already been injected via the C API so mark it as already having been loaded so 'require("lfs")' doesn't error.
package.loaded.lfs = lfs;

ntb = {};

require("pl");

local manifestPath;
if arg[2] and arg[2] ~= "" then
	manifestPath = path.abspath(arg[2]);
else
	manifestPath = path.abspath("ntbconf.lua");
end

local manifestDir = path.dirname(manifestPath);
lfs.chdir(manifestDir);

ntb.scriptPath = manifestPath;
ntb.scriptDir = manifestDir;
ntb.projectsDirectory = manifestDir;
ntb.buildDirectory = path.abspath('_out', manifestDir);

local importerCreate = require('ntb.importer');
local ninjaFileWrite = require('ntb.ninjaFileWrite');
local ninjaFileBuilderCreate = require('ntb.ninjaFileBuilder');
local cCreate = require('ntb.c');
local misc = require('ntb.misc');

local cnf = dofile(manifestPath);

if type(cnf) ~= "table" then
	error("config not supplied");
end
if not cnf.targets then
	error("config.targets must be a table");
end
if type(cnf.targets) ~= "table" then
	error("config.targets must be a table");
end
if #cnf.targets < 1 then
	error("config.targets must have at least one element");
end
if type(cnf.projects) ~= "table" then
	error("config.projects must be a table");
end

local targetsByName = {};
for i, target in ipairs(cnf.targets) do
	if not target.name then
		error("target #" .. i .. " must have a name");
	end
	if targetsByName[target.name] then
		error("target #" .. i .. " has the same name as another target");
	end
	if target.name[1] == "_" then
		error("target.name must not start with '_' (target #" .. i .. ")");
	end
	targetsByName[target.name] = target;
end

for targetIdx, target in ipairs(cnf.targets) do
	local old = ntb.buildDirectory;
	ntb.buildDirectory = path.join(old, target.name);
	ntb.target = target;

	local cpp = cCreate();
	cpp:registerGlobals();

	local importer = importerCreate();
	importer:registerGlobals();

	local ninjaFileBuilder = ninjaFileBuilderCreate();
	ninjaFileBuilder:registerGlobals();

	ntb.scriptDir = nil;
	ntb.scriptPath = nil;

	misc();

	if type(cnf.beforeTarget) == "function" then
		cnf.beforeTarget();
	end

	for _, imp in ipairs(cnf.projects) do
		local fp = imp;
		if not fp:match('%.lua$') then
			fp = path.join(fp, "main.ntb.lua");
		end
		importer:import(fp);
	end

	if target.useForCompileCommands then
		cpp:writeCompileDatabaseCommand();
	end

	if type(cnf.afterTarget) == "function" then
		cnf.afterTarget();
	end
	
	ninjaFileWrite(ninjaFileBuilder, ntb.buildDirectory);
	ntb.buildDirectory = old;
end
