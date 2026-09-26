#include <sqlite3.h>

static inline int kansolendar_sqlite_set_db_config(sqlite3 *database, int option, int enabled) {
    int previous_value = 0;
    return sqlite3_db_config(database, option, enabled, &previous_value);
}
