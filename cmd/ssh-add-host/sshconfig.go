package main

import (
	"bufio"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

// HostEntry represents a configuration block for an SSH host in ~/.ssh/config.
type HostEntry struct {
	Alias          string
	HostName       string
	User           string
	Port           int
	IdentityFile   string
	IdentitiesOnly bool
	PubkeyAuth     bool   // If false, adds 'PubkeyAuthentication no'
	PasswordAuth   bool   // If true, adds 'PreferredAuthentications password,keyboard-interactive'
	PreferredAuths string // Custom PreferredAuthentications string
}

// Format renders the HostEntry into standard OpenSSH configuration syntax.
func (h HostEntry) Format() string {
	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("Host %s\n", h.Alias))
	if h.HostName != "" {
		sb.WriteString(fmt.Sprintf("    HostName %s\n", h.HostName))
	}
	if h.User != "" {
		sb.WriteString(fmt.Sprintf("    User %s\n", h.User))
	}
	if h.Port > 0 && h.Port != 22 {
		sb.WriteString(fmt.Sprintf("    Port %d\n", h.Port))
	}
	if h.IdentityFile != "" {
		sb.WriteString(fmt.Sprintf("    IdentityFile %s\n", h.IdentityFile))
		if h.IdentitiesOnly {
			sb.WriteString("    IdentitiesOnly yes\n")
		}
	}
	if !h.PubkeyAuth {
		sb.WriteString("    PubkeyAuthentication no\n")
	}
	if h.PasswordAuth || h.PreferredAuths != "" {
		auths := h.PreferredAuths
		if auths == "" {
			auths = "password,keyboard-interactive"
		}
		sb.WriteString(fmt.Sprintf("    PreferredAuthentications %s\n", auths))
	}
	return sb.String()
}

// ParseTarget parses connection strings such as:
//   - "user@host:port"
//   - "user@host"
//   - "host:port"
//   - "host"
//   - "ssh://user@host:port"
func ParseTarget(input string) (user, host string, port int) {
	input = strings.TrimSpace(input)
	input = strings.TrimPrefix(input, "ssh://")

	if idx := strings.Index(input, "@"); idx != -1 {
		user = input[:idx]
		input = input[idx+1:]
	}

	if idx := strings.LastIndex(input, ":"); idx != -1 {
		pStr := input[idx+1:]
		if p, err := strconv.Atoi(pStr); err == nil && p > 0 && p <= 65535 {
			port = p
			host = input[:idx]
		} else {
			host = input
		}
	} else {
		host = input
	}

	// Remove bracket wrappers if IPv6 literal like [::1]
	host = strings.TrimPrefix(host, "[")
	host = strings.TrimSuffix(host, "]")

	return user, host, port
}

// HasHost checks whether the given alias (or any whitespace-separated alias)
// is already defined in any Host directive within the configuration content.
func HasHost(content, alias string) bool {
	targets := strings.Fields(alias)
	if len(targets) == 0 {
		return false
	}
	targetMap := make(map[string]bool)
	for _, t := range targets {
		targetMap[t] = true
	}

	scanner := bufio.NewScanner(strings.NewReader(content))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		fields := strings.Fields(line)
		if len(fields) >= 2 && strings.EqualFold(fields[0], "Host") {
			for _, pat := range fields[1:] {
				if targetMap[pat] {
					return true
				}
			}
		}
	}
	return false
}

// RemoveHost removes any Host block matching the given alias (or whitespace-separated aliases).
func RemoveHost(content, alias string) string {
	targets := strings.Fields(alias)
	if len(targets) == 0 {
		return content
	}
	targetMap := make(map[string]bool)
	for _, t := range targets {
		targetMap[t] = true
	}

	lines := strings.Split(content, "\n")
	var result []string
	inSkipBlock := false

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		fields := strings.Fields(trimmed)

		if len(fields) >= 1 && (strings.EqualFold(fields[0], "Host") || strings.EqualFold(fields[0], "Match")) {
			inSkipBlock = false
			if strings.EqualFold(fields[0], "Host") {
				for _, pat := range fields[1:] {
					if targetMap[pat] {
						inSkipBlock = true
						break
					}
				}
			}
		}

		if !inSkipBlock {
			result = append(result, line)
		}
	}

	return cleanConsecutiveBlankLines(strings.Join(result, "\n"))
}

// InsertHost inserts a formatted host block before any wildcard 'Host *' block (and its comments).
// If no 'Host *' block is present, it appends the block to the end of the configuration.
func InsertHost(content, block string) string {
	block = strings.TrimRight(block, "\n")
	if strings.TrimSpace(content) == "" {
		return block + "\n"
	}

	lines := strings.Split(content, "\n")
	wildcardIdx := -1

	// Locate the wildcard 'Host *' directive
	for i, line := range lines {
		fields := strings.Fields(strings.TrimSpace(line))
		if len(fields) == 2 && strings.EqualFold(fields[0], "Host") && fields[1] == "*" {
			wildcardIdx = i
			break
		}
	}

	if wildcardIdx == -1 {
		// No Host * found: append to bottom cleanly
		trimmed := strings.TrimRight(content, "\n")
		return trimmed + "\n\n" + block + "\n"
	}

	// Walk backwards to find comments immediately attached to 'Host *'
	insertIdx := wildcardIdx
	for i := wildcardIdx - 1; i >= 0; i-- {
		trimmed := strings.TrimSpace(lines[i])
		if strings.HasPrefix(trimmed, "#") {
			insertIdx = i
		} else {
			break
		}
	}

	// Build the new document with clean spacing
	var sb strings.Builder
	for i := 0; i < insertIdx; i++ {
		sb.WriteString(lines[i])
		sb.WriteString("\n")
	}

	// Ensure blank line before new block if there was prior content
	before := strings.TrimRight(sb.String(), "\n")
	if len(before) > 0 {
		sb.Reset()
		sb.WriteString(before)
		sb.WriteString("\n\n")
	} else {
		sb.Reset()
	}

	sb.WriteString(block)
	sb.WriteString("\n\n")

	// Append remaining lines starting from insertIdx
	for i := insertIdx; i < len(lines); i++ {
		sb.WriteString(lines[i])
		if i < len(lines)-1 {
			sb.WriteString("\n")
		}
	}

	return cleanConsecutiveBlankLines(sb.String())
}

// cleanConsecutiveBlankLines collapses 3+ consecutive newlines into 2.
func cleanConsecutiveBlankLines(s string) string {
	re := regexp.MustCompile(`\n{3,}`)
	cleaned := re.ReplaceAllString(s, "\n\n")
	if !strings.HasSuffix(cleaned, "\n") {
		cleaned += "\n"
	}
	return cleaned
}

// DiscoverKeys inspects sshDir (usually ~/.ssh) for private keys.
// Returns a list of absolute paths.
func DiscoverKeys(sshDir string) ([]string, error) {
	entries, err := os.ReadDir(sshDir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}

	var keys []string
	ignoredNames := map[string]bool{
		"config":          true,
		"authorized_keys": true,
		"known_hosts":     true,
		"known_hosts.old": true,
		"allowed_signers": true,
		"environment":     true,
	}

	for _, entry := range entries {
		name := entry.Name()
		if entry.IsDir() || strings.HasPrefix(name, ".") || strings.HasSuffix(name, ".pub") {
			continue
		}
		if ignoredNames[name] || strings.HasPrefix(name, "known_hosts") {
			continue
		}

		fullPath := filepath.Join(sshDir, name)
		fi, err := entry.Info()
		if err != nil {
			continue
		}
		if fi.Mode().IsRegular() {
			keys = append(keys, fullPath)
		}
	}

	sort.Strings(keys)
	return keys, nil
}

// AtomicWrite safely writes data to targetPath with the given permissions by first writing
// to a temporary file in the same directory, syncing to disk, and renaming.
func AtomicWrite(targetPath string, data []byte, perm os.FileMode) error {
	dir := filepath.Dir(targetPath)
	if err := os.MkdirAll(dir, 0700); err != nil {
		return fmt.Errorf("failed to create directory %s: %w", dir, err)
	}

	randBytes := make([]byte, 4)
	if _, err := rand.Read(randBytes); err != nil {
		return err
	}
	tmpName := filepath.Join(dir, fmt.Sprintf(".tmp.%s.%s", filepath.Base(targetPath), hex.EncodeToString(randBytes)))

	tmpFile, err := os.OpenFile(tmpName, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, perm)
	if err != nil {
		return fmt.Errorf("failed to create temp file: %w", err)
	}

	success := false
	defer func() {
		if !success {
			_ = tmpFile.Close()
			_ = os.Remove(tmpName)
		}
	}()

	if _, err := tmpFile.Write(data); err != nil {
		return fmt.Errorf("failed to write to temp file: %w", err)
	}

	if err := tmpFile.Sync(); err != nil {
		return fmt.Errorf("failed to sync temp file: %w", err)
	}

	if err := tmpFile.Close(); err != nil {
		return fmt.Errorf("failed to close temp file: %w", err)
	}

	if err := os.Chmod(tmpName, perm); err != nil {
		return fmt.Errorf("failed to set permissions on temp file: %w", err)
	}

	if err := os.Rename(tmpName, targetPath); err != nil {
		return fmt.Errorf("failed to rename temp file to %s: %w", targetPath, err)
	}

	success = true
	return nil
}
