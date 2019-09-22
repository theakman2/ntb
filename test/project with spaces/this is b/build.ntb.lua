local lib = import("a");

cbinary(
	"b",
	{
		ccompile("main.c"),
		lib,
	}
);
