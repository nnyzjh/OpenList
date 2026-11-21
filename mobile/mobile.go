// Package mobile exposes a minimal, gomobile-compatible API for embedding
// the OpenList core (the Go server) inside the iOS app.
//
// It reuses the core's own entry points — cmd.Init, bootstrap.Start and
// bootstrap.Shutdown, exactly the sequence the `openlist server` command
// runs — and adds only the two things an embedding shell must control:
// where the data lives, and the first-run admin password.
//
// Deliberately NOT changed here: the listen address and port. OpenList's own
// defaults (0.0.0.0:5244) are kept as-is; on iOS the loopback is reachable
// at 127.0.0.1. Only revisit if it actually errors.
//
// Everything else (file browsing, WebDAV, version, storage management) is
// done by the shell over the core's HTTP API on 127.0.0.1:5244, never by
// reading files directly.
package mobile

import (
	"os"
	"time"

	"github.com/OpenListTeam/OpenList/v4/cmd"
	"github.com/OpenListTeam/OpenList/v4/cmd/flags"
	"github.com/OpenListTeam/OpenList/v4/internal/bootstrap"
	"github.com/OpenListTeam/OpenList/v4/internal/conf"
)

// SetDataDir sets the absolute path of the data directory (config.json,
// data.db, logs, temp files, search index). Must be called before Init.
// On iOS the shell passes the app's Documents directory. Relative paths
// are resolved against the process working directory by the core, so the
// shell must always pass an absolute path.
func SetDataDir(path string) {
	flags.DataDir = path
}

// SetAdminPassword sets the password used to auto-create the admin account
// on first launch (OPENLIST_ADMIN_PASSWORD). The core only auto-creates an
// admin in dev mode or when this variable is set; otherwise it waits for
// the web setup wizard (POST /api/public/init/setup). Must be called before
// Init. On later launches the value is ignored because the admin already
// exists, so it is safe to call on every launch.
func SetAdminPassword(password string) {
	_ = os.Setenv("OPENLIST_ADMIN_PASSWORD", password)
}

// Init initialises the core: reads (or creates) config.json, opens the
// database and loads settings and users. Call once, after SetDataDir and
// SetAdminPassword.
func Init() {
	cmd.Init()
}

// Start starts the HTTP server (and any other endpoints enabled in config)
// in the background and returns immediately. Use IsRunning or poll
// http://127.0.0.1:5244/ping to know when it accepts requests.
func Start() {
	bootstrap.Start()
}

// Shutdown stops all servers gracefully (5s timeout) but keeps the
// database open, so a later Start() can read it again.
// Call when the app moves to the background.
func Shutdown() {
	bootstrap.Shutdown(5 * time.Second)
}

// IsRunning reports whether the HTTP server is currently running.
func IsRunning() bool {
	return bootstrap.IsRunning("http")
}

// Version returns the core version string injected at build time
// (for example "v4.2.9").
func Version() string {
	return conf.Version
}
