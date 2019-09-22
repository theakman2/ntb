#include "./api.h"

#include "../sublib1/api.h"
#include "../sublib2/api.h"

int lib1a(void) {
	return 4 + sublib1a() - sublib2b();
}
