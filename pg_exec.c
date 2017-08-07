#include <string.h>
#include "postgres.h"
#include "fmgr.h"

#ifdef PG_MODULE_MAGIC
PG_MODULE_MAGIC;
#endif

PG_FUNCTION_INFO_V1(pg_exec);
Datum pg_exec(PG_FUNCTION_ARGS) {
    char* command = PG_GETARG_CSTRING(0);
    PG_RETURN_INT32(system(command));
}
