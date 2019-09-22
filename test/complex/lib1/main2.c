#include "./api.h"

#include "../sublib1/api.h"
#include "../sublib2/api.h"

int lib1b(void) {
	return 4 - sublib1b() + sublib2a();
}
