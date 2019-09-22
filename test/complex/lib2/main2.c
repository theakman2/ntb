#include "./api.h"

#include "../sublib2/api.h"

int lib2b(void) {
	return 400 + sublib2a();
}
