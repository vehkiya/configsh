package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestParseTarget(t *testing.T) {
	tests := []struct {
		input        string
		expectedUser string
		expectedHost string
		expectedPort int
	}{
		{"root@10.0.0.1:2222", "root", "10.0.0.1", 2222},
		{"admin@example.com", "admin", "example.com", 0},
		{"myserver.lan:8022", "", "myserver.lan", 8022},
		{"myserver.lan", "", "myserver.lan", 0},
		{"ssh://git@github.com:22", "git", "github.com", 22},
		{"[2001:db8::1]:2222", "", "2001:db8::1", 2222},
	}

	for _, tc := range tests {
		u, h, p := ParseTarget(tc.input)
		if u != tc.expectedUser || h != tc.expectedHost || p != tc.expectedPort {
			t.Errorf("ParseTarget(%q) = (%q, %q, %d); want (%q, %q, %d)",
				tc.input, u, h, p, tc.expectedUser, tc.expectedHost, tc.expectedPort)
		}
	}
}

func TestHostEntryFormat(t *testing.T) {
	// Key-based entry
	entry1 := HostEntry{
		Alias:          "prod-api",
		HostName:       "api.example.com",
		User:           "deploy",
		Port:           2222,
		IdentityFile:   "~/.ssh/id_ed25519_prod",
		IdentitiesOnly: true,
		PubkeyAuth:     true,
	}

	f1 := entry1.Format()
	expected1 := "Host prod-api\n    HostName api.example.com\n    User deploy\n    Port 2222\n    IdentityFile ~/.ssh/id_ed25519_prod\n    IdentitiesOnly yes\n"
	if f1 != expected1 {
		t.Errorf("Format() mismatch.\nGot:\n%s\nWant:\n%s", f1, expected1)
	}

	// Password-only entry
	entry2 := HostEntry{
		Alias:        "legacy-box",
		HostName:     "192.168.1.50",
		User:         "admin",
		Port:         22,
		PubkeyAuth:   false,
		PasswordAuth: true,
	}

	f2 := entry2.Format()
	expected2 := "Host legacy-box\n    HostName 192.168.1.50\n    User admin\n    PubkeyAuthentication no\n    PreferredAuthentications password,keyboard-interactive\n"
	if f2 != expected2 {
		t.Errorf("Format() mismatch.\nGot:\n%s\nWant:\n%s", f2, expected2)
	}
}

func TestHasHost(t *testing.T) {
	config := `
Host fortress 10.10.1.218
    HostName fortress.kerrlab.app
    User vehkiya

Host *
    AddKeysToAgent yes
`
	if !HasHost(config, "fortress") {
		t.Errorf("expected HasHost to find 'fortress'")
	}
	if !HasHost(config, "10.10.1.218") {
		t.Errorf("expected HasHost to find '10.10.1.218'")
	}
	if HasHost(config, "unknown") {
		t.Errorf("did not expect HasHost to find 'unknown'")
	}
}

func TestRemoveHost(t *testing.T) {
	config := `Host alpha
    HostName alpha.lan
    User alice

Host beta
    HostName beta.lan
    User bob

Host *
    AddKeysToAgent yes
`

	cleaned := RemoveHost(config, "alpha")
	if strings.Contains(cleaned, "alpha.lan") || strings.Contains(cleaned, "Host alpha") {
		t.Errorf("expected 'alpha' to be removed, got:\n%s", cleaned)
	}
	if !strings.Contains(cleaned, "Host beta") || !strings.Contains(cleaned, "Host *") {
		t.Errorf("expected 'beta' and 'Host *' to be preserved, got:\n%s", cleaned)
	}
}

func TestInsertHost(t *testing.T) {
	initial := `Host alpha
    HostName alpha.lan

# Global defaults
Host *
    AddKeysToAgent yes
`

	newBlock := `Host beta
    HostName beta.lan
    User bob`

	result := InsertHost(initial, newBlock)

	// Check ordering: alpha -> beta -> # Global defaults -> Host *
	alphaIdx := strings.Index(result, "Host alpha")
	betaIdx := strings.Index(result, "Host beta")
	commentIdx := strings.Index(result, "# Global defaults")
	wildcardIdx := strings.Index(result, "Host *")

	if alphaIdx == -1 || betaIdx == -1 || commentIdx == -1 || wildcardIdx == -1 {
		t.Fatalf("expected all elements present, got:\n%s", result)
	}

	if !(alphaIdx < betaIdx && betaIdx < commentIdx && commentIdx < wildcardIdx) {
		t.Errorf("incorrect ordering:\nalphaIdx: %d, betaIdx: %d, commentIdx: %d, wildcardIdx: %d\nFull config:\n%s",
			alphaIdx, betaIdx, commentIdx, wildcardIdx, result)
	}
}

func TestInsertHostEmptyConfig(t *testing.T) {
	newBlock := `Host server
    HostName server.lan`

	result := InsertHost("", newBlock)
	expected := "Host server\n    HostName server.lan\n"
	if result != expected {
		t.Errorf("expected:\n%q\ngot:\n%q", expected, result)
	}
}

func TestAtomicWrite(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "sshconfig_test_*")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	target := filepath.Join(tmpDir, "config")
	content := []byte("Host test\n    HostName test.lan\n")

	if err := AtomicWrite(target, content, 0600); err != nil {
		t.Fatalf("AtomicWrite failed: %v", err)
	}

	read, err := os.ReadFile(target)
	if err != nil {
		t.Fatalf("ReadFile failed: %v", err)
	}
	if string(read) != string(content) {
		t.Errorf("got %q, want %q", string(read), string(content))
	}

	fi, err := os.Stat(target)
	if err != nil {
		t.Fatal(err)
	}
	if fi.Mode().Perm() != 0600 {
		t.Errorf("permissions = %o, want 0600", fi.Mode().Perm())
	}
}
