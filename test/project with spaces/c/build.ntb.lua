local lib = import("a");

return cbinary(
	"c",
	{
		ccompile("main.c"),
		lib,
	}
);
