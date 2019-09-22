local importerMt = {};

importerMt.import = function(self, filePath)
	if (not path.isabs(filePath)) and (filePath:sub(1, 1) ~= '.') then
		filePath = path.join(ntb.projectsDirectory, filePath);
	end
	if not filePath:match('%.lua$') then
		filePath = path.join(filePath, "build.ntb.lua");
	end
	filePath = path.abspath(filePath, ntb.scriptDir);

	local ret;
	
	if self.allImports[filePath] then
		ret = self.allImports[filePath];
	else
		if self.importStackMap[filePath] then
			error("circular dependency detected [path: " .. table.concat(self.importStack, " -> ") .. "]");
		end
		self.importStackMap[filePath] = true;
		table.insert(self.importStack, filePath);
		local f, err;
		if self.loadedChunks[filePath] then
			f = self.loadedChunks[filePath];
		else
			f, err = loadfile(filePath);
			if err then
				error(err);
			end
			self.loadedChunks[filePath] = f;
		end
		local oldcurr = ntb.scriptDir;
		ntb.scriptDir = path.dirname(filePath);
		local oldfp = ntb.scriptPath;
		ntb.scriptPath = filePath;
		ret = f();
		ntb.scriptPath = oldfp;
		ntb.scriptDir = oldcurr;
		table.remove(self.importStack);
		self.importStackMap[filePath] = nil;

		self.allImports[filePath] = ret;
	end

	return ret;
end;

importerMt.registerGlobals = function(self)
	_G.import = func.bind1(self.import, self);
end

local function importerCreate()
	return setmetatable(
		{
			allImports = {};
			importStack = {};
			importStackMap = {};
			loadedChunks = {};
		},
		{
			__index = importerMt;
		}
	);
end

return importerCreate;