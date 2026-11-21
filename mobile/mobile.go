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
	"github.com/OpenListTeam/OpenList/v4/internal/db"
	"github.com/OpenListTeam/OpenList/v4/internal/media"
	"github.com/OpenListTeam/OpenList/v4/internal/op"
	"github.com/OpenListTeam/OpenList/v4/internal/setting"
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

// ResetAdminPassword sets the admin user's password to the given value,
// using the core's own password hashing (SetPassword + UpdateUser).
// It needs no old password and touches nothing else (no data is wiped),
// so it recovers a lockout without losing storages or files.
// Call only after Init (the database must be open).
// Returns "" on success, or an error message on failure.
// Note: this bypasses the login API, so it works even while the account
// is 429-locked from too many failed sign-ins; the next login still has
// to wait for that lock (5 minutes) to expire.
func ResetAdminPassword(newPassword string) string {
	admin, err := op.GetAdmin()
	if err != nil {
		return err.Error()
	}
	admin.SetPassword(newPassword)
	if err := op.UpdateUser(admin); err != nil {
		return err.Error()
	}
	return ""
}

// CheckpointDB flushes the database to disk: it checkpoints the SQLite
// WAL (write-ahead log) into the main data.db file and truncates the WAL.
// Call it when the app moves to the background. After that, even if the
// app is swiped away from the app switcher (force-killed) and never gets
// a chance to shut down cleanly, all committed data is already in
// data.db and survives. Without this, data that only lives in the WAL
// could be lost if the app is killed at the wrong moment.
// Call only after Init (the database must be open).
// Returns "" on success, or an error message on failure.
// (If the database is not in WAL mode, the checkpoint is a harmless no-op.)
func CheckpointDB() string {
	gdb := db.GetDb()
	if gdb == nil {
		return "database not open"
	}
	if err := gdb.Exec("PRAGMA wal_checkpoint(TRUNCATE)").Error; err != nil {
		return err.Error()
	}
	return ""
}

// SetAdminUsername sets the admin user's username to the given value.
// The admin is looked up by role (not by name), so renaming is safe and
// the account keeps its ID, role and storages. It needs no password and
// touches nothing else (no data is wiped).
// Call only after Init (the database must be open).
// Returns "" on success, or an error message on failure.
func SetAdminUsername(newUsername string) string {
	admin, err := op.GetAdmin()
	if err != nil {
		return err.Error()
	}
	admin.Username = newUsername
	if err := op.UpdateUser(admin); err != nil {
		return err.Error()
	}
	return ""
}

// RevealAppKey decrypts and returns the plain app key (e.g. "olmp_...") for
// the given key ID. The stored secret is AES-GCM ciphertext encrypted with
// a stable key, so a key created earlier can be shown again (not just once).
// Only the admin's own keys can be revealed. Returns "" on any failure
// (unknown ID, not the admin's key, or decrypt error).
// Call only after Init (the database must be open).
func RevealAppKey(id int) string {
	admin, err := op.GetAdmin()
	if err != nil {
		return ""
	}
	k, err := db.GetMediaAppKey(uint(id))
	if err != nil {
		return ""
	}
	if k.UserID != admin.ID {
		return ""
	}
	plain, err := media.DecryptAppKey(k.Secret)
	if err != nil {
		return ""
	}
	return plain
}

// RenameAppKey changes the display name (remark) of one of the admin's app
// keys. There is no core rename endpoint, so this edits the stored row
// directly (name only; the key itself never changes).
// Call only after Init (the database must be open).
// Returns "" on success, or an error message on failure.
func RenameAppKey(id int, newName string) string {
	admin, err := op.GetAdmin()
	if err != nil {
		return err.Error()
	}
	k, err := db.GetMediaAppKey(uint(id))
	if err != nil {
		return err.Error()
	}
	if k.UserID != admin.ID {
		return "not your key"
	}
	k.Name = newName
	gdb := db.GetDb()
	if gdb == nil {
		return "database not open"
	}
	if err := gdb.Save(k).Error; err != nil {
		return err.Error()
	}
	return ""
}

// IsEmbyEnabled reports whether the pseudo-Emby API (/@emby) is enabled.
func IsEmbyEnabled() bool {
	return setting.GetBool(conf.MediaEmbyEnabled)
}

// SetEmbyEnabled turns the pseudo-Emby API (/@emby) on or off.
// It fetches the existing setting row and flips only its value.
// Call only after Init (the database must be open).
// Returns "" on success, or an error message on failure.
func SetEmbyEnabled(enabled bool) string {
	item, err := op.GetSettingItemByKey(conf.MediaEmbyEnabled)
	if err != nil {
		return err.Error()
	}
	if enabled {
		item.Value = "true"
	} else {
		item.Value = "false"
	}
	if err := op.SaveSettingItem(item); err != nil {
		return err.Error()
	}
	return ""
}
