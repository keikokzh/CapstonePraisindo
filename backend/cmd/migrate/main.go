// Legacy entry point intentionally disabled before loading any database configuration.
package main

import "log"

func main() {
	log.Fatal("Legacy migrate disabled. Read docs/DATABASE_V2.md; use cmd/migrate_v2 only for an explicitly selected V2 target.")
}
