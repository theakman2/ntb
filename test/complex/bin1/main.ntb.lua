local lib2 = import("lib2");
local sublib2 = import("sublib2");

return cbinary(
	"bin1",
	{
		ccompile{
			"main.c",
		},
		lib2,
		sublib2,
	}
);