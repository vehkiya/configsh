package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"strconv"
	"strings"
)

var (
	green  = "\033[0;32m"
	yellow = "\033[1;33m"
	blue   = "\033[0;34m"
	cyan   = "\033[0;36m"
	bold   = "\033[1m"
	reset  = "\033[0m"
)

func main() {
	var (
		flagHost         string
		flagUser         string
		flagPort         int
		flagAlias        string
		flagKey          string
		flagPasswordOnly bool
		flagNonInteract  bool
	)

	flag.StringVar(&flagHost, "host", "", "Remote hostname or IP address")
	flag.StringVar(&flagHost, "h", "", "Remote hostname or IP address (shorthand)")
	flag.StringVar(&flagUser, "user", "", "SSH username")
	flag.StringVar(&flagUser, "u", "", "SSH username (shorthand)")
	flag.IntVar(&flagPort, "port", 0, "SSH port (default 22)")
	flag.IntVar(&flagPort, "p", 0, "SSH port (shorthand)")
	flag.StringVar(&flagAlias, "alias", "", "Host alias for ~/.ssh/config")
	flag.StringVar(&flagAlias, "a", "", "Host alias (shorthand)")
	flag.StringVar(&flagKey, "key", "", "Path to private key identity file")
	flag.StringVar(&flagKey, "k", "", "Path to private key (shorthand)")
	flag.BoolVar(&flagPasswordOnly, "password-only", false, "Configure password-only authentication (disables pubkey & agent)")
	flag.BoolVar(&flagNonInteract, "yes", false, "Non-interactive mode (assume defaults / yes)")
	flag.BoolVar(&flagNonInteract, "y", false, "Non-interactive mode (shorthand)")

	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "%sUsage:%s ssh-add-host [options] [user@host[:port]] [alias]\n\n", bold, reset)
		fmt.Fprintf(os.Stderr, "Interactively configure and save an SSH host block to ~/.ssh/config.\n\n")
		fmt.Fprintf(os.Stderr, "%sArguments:%s\n", bold, reset)
		fmt.Fprintf(os.Stderr, "  user@host[:port]   Target connection string (optional)\n")
		fmt.Fprintf(os.Stderr, "  alias              Custom nickname/alias for ~/.ssh/config (optional)\n\n")
		fmt.Fprintf(os.Stderr, "%sOptions:%s\n", bold, reset)
		flag.PrintDefaults()
		fmt.Fprintf(os.Stderr, "\n%sFeatures:%s\n", bold, reset)
		fmt.Fprintf(os.Stderr, "  • Key authentication, password-only hardening, or standard fallback\n")
		fmt.Fprintf(os.Stderr, "  • Detects existing keys in ~/.ssh, offers key generation, or ssh-copy-id\n")
		fmt.Fprintf(os.Stderr, "  • Disables pubkey on password-only hosts to prevent 'Too many authentication failures'\n")
		fmt.Fprintf(os.Stderr, "  • Automatically places host definitions before wildcard 'Host *' blocks\n")
		fmt.Fprintf(os.Stderr, "  • Atomic writes with strict 0600 file permissions\n")
		fmt.Fprintf(os.Stderr, "  • Offers immediate connection testing upon completion\n")
	}

	flag.Parse()

	homeDir, err := os.UserHomeDir()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error resolving home directory: %v\n", err)
		os.Exit(1)
	}

	defaultUsername := os.Getenv("USER")
	if defaultUsername == "" {
		if u, err := user.Current(); err == nil {
			defaultUsername = u.Username
		}
	}

	// Parse positional arguments
	args := flag.Args()
	var posTarget, posAlias string
	if len(args) > 0 {
		posTarget = args[0]
	}
	if len(args) > 1 {
		posAlias = args[1]
	}

	targetUser, targetHost, targetPort := ParseTarget(posTarget)

	hostName := flagHost
	if hostName == "" {
		hostName = targetHost
	}

	userName := flagUser
	if userName == "" {
		userName = targetUser
	}

	port := flagPort
	if port == 0 {
		port = targetPort
	}
	if port == 0 {
		port = 22
	}

	alias := flagAlias
	if alias == "" {
		alias = posAlias
	}

	scanner := bufio.NewScanner(os.Stdin)

	// Step 1: Prompt for HostName if missing
	if hostName == "" {
		if flagNonInteract {
			fmt.Fprintln(os.Stderr, "Error: HostName is required in non-interactive mode.")
			os.Exit(1)
		}
		fmt.Printf("%sHostName%s (FQDN or IP address): ", bold, reset)
		if scanner.Scan() {
			hostName = strings.TrimSpace(scanner.Text())
		}
		if hostName == "" {
			fmt.Fprintln(os.Stderr, "HostName is required.")
			os.Exit(1)
		}
	}

	// Step 2: Prompt for User if missing
	if userName == "" {
		if flagNonInteract {
			userName = defaultUsername
		} else {
			fmt.Printf("%sUser%s [%s]: ", bold, reset, defaultUsername)
			if scanner.Scan() {
				input := strings.TrimSpace(scanner.Text())
				if input != "" {
					userName = input
				} else {
					userName = defaultUsername
				}
			}
		}
	}

	// Step 3: Prompt for Port if not specified anywhere
	if len(args) == 0 && flagPort == 0 && !flagNonInteract {
		fmt.Printf("%sPort%s [22]: ", bold, reset)
		if scanner.Scan() {
			input := strings.TrimSpace(scanner.Text())
			if input != "" {
				if p, err := strconv.Atoi(input); err == nil && p > 0 && p <= 65535 {
					port = p
				}
			}
		}
	}

	// Step 4: Prompt for Alias if missing
	if alias == "" {
		defaultAlias := hostName
		if flagNonInteract {
			alias = defaultAlias
		} else {
			fmt.Printf("%sHost alias / nickname%s [%s]: ", bold, reset, defaultAlias)
			if scanner.Scan() {
				input := strings.TrimSpace(scanner.Text())
				if input != "" {
					alias = input
				} else {
					alias = defaultAlias
				}
			}
		}
	}

	// Step 5: Authentication Method
	sshDir := filepath.Join(homeDir, ".ssh")
	var (
		authChoice   = 1
		identityFile = flagKey
		pubkeyAuth   = true
		passwordAuth = false
	)

	if flagPasswordOnly {
		authChoice = 2
	} else if flagKey != "" {
		authChoice = 1
	} else if !flagNonInteract {
		fmt.Println()
		fmt.Printf("%sAuthentication method for '%s':%s\n", bold, alias, reset)
		fmt.Println("  1) SSH Key (IdentityFile) [default]")
		fmt.Println("  2) Password only (disables pubkey & agent keys)")
		fmt.Println("  3) Standard / Default (agent keys with password fallback)")
		fmt.Printf("%sSelect [1-3] (default: 1):%s ", bold, reset)
		if scanner.Scan() {
			input := strings.TrimSpace(scanner.Text())
			if input == "2" {
				authChoice = 2
			} else if input == "3" {
				authChoice = 3
			} else {
				authChoice = 1
			}
		}
	}

	switch authChoice {
	case 2: // Password only
		pubkeyAuth = false
		passwordAuth = true
		identityFile = ""

	case 3: // Default / Standard
		pubkeyAuth = true
		passwordAuth = false
		identityFile = ""

	case 1: // SSH Key
		pubkeyAuth = true
		passwordAuth = false

		if identityFile == "" && !flagNonInteract {
			discovered, _ := DiscoverKeys(sshDir)
			if len(discovered) > 0 {
				fmt.Println()
				fmt.Printf("%sAvailable SSH keys in ~/.ssh:%s\n", bold, reset)
				for i, k := range discovered {
					rel := k
					if strings.HasPrefix(k, homeDir) {
						rel = "~" + k[len(homeDir):]
					}
					fmt.Printf("  %d) %s\n", i+1, rel)
				}
				fmt.Println("  c) Enter custom key path")
				fmt.Println("  n) Generate new Ed25519 key")
				fmt.Printf("%sSelect key [1]:%s ", bold, reset)

				keyChoice := "1"
				if scanner.Scan() {
					input := strings.TrimSpace(scanner.Text())
					if input != "" {
						keyChoice = input
					}
				}

				if idx, err := strconv.Atoi(keyChoice); err == nil && idx >= 1 && idx <= len(discovered) {
					identityFile = discovered[idx-1]
				} else if strings.EqualFold(keyChoice, "c") {
					fmt.Printf("Path to private key: ")
					if scanner.Scan() {
						identityFile = expandHome(strings.TrimSpace(scanner.Text()), homeDir)
					}
				} else if strings.EqualFold(keyChoice, "n") {
					identityFile = generateNewKey(alias, userName, hostName, sshDir, homeDir, scanner)
				} else {
					identityFile = discovered[0]
				}
			} else {
				fmt.Println()
				fmt.Println("No SSH keys found in ~/.ssh.")
				fmt.Println("  1) Enter existing key path")
				fmt.Println("  2) Generate new Ed25519 key [default]")
				fmt.Printf("%sChoose [1-2] (default: 2):%s ", bold, reset)

				choice := "2"
				if scanner.Scan() {
					input := strings.TrimSpace(scanner.Text())
					if input == "1" {
						choice = "1"
					}
				}

				if choice == "1" {
					fmt.Printf("Path to private key: ")
					if scanner.Scan() {
						identityFile = expandHome(strings.TrimSpace(scanner.Text()), homeDir)
					}
				} else {
					identityFile = generateNewKey(alias, userName, hostName, sshDir, homeDir, scanner)
				}
			}

			// Offer ssh-copy-id if public key is present
			if identityFile != "" {
				pubKey := identityFile + ".pub"
				if _, err := os.Stat(pubKey); err == nil {
					fmt.Printf("\n%sCopy public key to %s@%s with ssh-copy-id? [y/N]:%s ", bold, userName, hostName, reset)
					if scanner.Scan() {
						resp := strings.TrimSpace(scanner.Text())
						if strings.HasPrefix(strings.ToLower(resp), "y") {
							copyKeyCmd(pubKey, port, userName, hostName)
						}
					}
				}
			}
		}
	}

	// Normalize identity file path for config (~/...)
	formattedKey := identityFile
	if strings.HasPrefix(identityFile, homeDir) {
		formattedKey = "~" + identityFile[len(homeDir):]
	}

	entry := HostEntry{
		Alias:          alias,
		HostName:       hostName,
		User:           userName,
		Port:           port,
		IdentityFile:   formattedKey,
		IdentitiesOnly: formattedKey != "",
		PubkeyAuth:     pubkeyAuth,
		PasswordAuth:   passwordAuth,
	}

	configPath := filepath.Join(sshDir, "config")
	var existingContent string
	if data, err := os.ReadFile(configPath); err == nil {
		existingContent = string(data)
	}

	if HasHost(existingContent, alias) {
		if !flagNonInteract {
			fmt.Printf("\n%sWarning: Host alias '%s' is already defined in %s.%s\n", yellow, alias, configPath, reset)
			fmt.Printf("Overwrite existing host block? [y/N]: ")
			if scanner.Scan() {
				resp := strings.TrimSpace(scanner.Text())
				if !strings.HasPrefix(strings.ToLower(resp), "y") {
					fmt.Println("Aborted.")
					os.Exit(0)
				}
			}
		}
		existingContent = RemoveHost(existingContent, alias)
	}

	formattedBlock := entry.Format()
	newContent := InsertHost(existingContent, formattedBlock)

	if err := AtomicWrite(configPath, []byte(newContent), 0600); err != nil {
		fmt.Fprintf(os.Stderr, "Error writing to %s: %v\n", configPath, err)
		os.Exit(1)
	}

	fmt.Println()
	fmt.Printf("%s%sSuccessfully saved to %s:%s\n", green, bold, configPath, reset)
	fmt.Println("----------------------------------------")
	fmt.Print(formattedBlock)
	fmt.Println("----------------------------------------")

	if !flagNonInteract {
		connectTarget := strings.Fields(alias)[0]
		fmt.Printf("\n%sConnect to '%s' now? [Y/n]:%s ", bold, connectTarget, reset)
		if scanner.Scan() {
			resp := strings.TrimSpace(scanner.Text())
			if resp == "" || strings.HasPrefix(strings.ToLower(resp), "y") {
				fmt.Printf("Connecting to %s...\n", connectTarget)
				cmd := exec.Command("ssh", connectTarget)
				cmd.Stdin = os.Stdin
				cmd.Stdout = os.Stdout
				cmd.Stderr = os.Stderr
				_ = cmd.Run()
			}
		}
	}
}

func expandHome(path, homeDir string) string {
	if strings.HasPrefix(path, "~/") {
		return filepath.Join(homeDir, path[2:])
	}
	if path == "~" {
		return homeDir
	}
	return path
}

func generateNewKey(alias, user, host, sshDir, homeDir string, scanner *bufio.Scanner) string {
	cleanAlias := strings.Fields(alias)[0]
	defaultPath := filepath.Join(sshDir, "id_ed25519_"+cleanAlias)
	relDefault := "~" + defaultPath[len(homeDir):]

	fmt.Printf("New key path [%s]: ", relDefault)
	targetPath := defaultPath
	if scanner.Scan() {
		input := strings.TrimSpace(scanner.Text())
		if input != "" {
			targetPath = expandHome(input, homeDir)
		}
	}

	comment := fmt.Sprintf("%s@%s", user, host)
	fmt.Printf("Generating Ed25519 key at %s...\n", targetPath)
	cmd := exec.Command("ssh-keygen", "-t", "ed25519", "-C", comment, "-f", targetPath)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "ssh-keygen failed: %v\n", err)
	}
	return targetPath
}

func copyKeyCmd(pubKey string, port int, user, host string) {
	args := []string{"-i", pubKey}
	if port > 0 && port != 22 {
		args = append(args, "-p", strconv.Itoa(port))
	}
	target := fmt.Sprintf("%s@%s", user, host)
	args = append(args, target)

	fmt.Printf("Running: ssh-copy-id %s\n", strings.Join(args, " "))
	cmd := exec.Command("ssh-copy-id", args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	_ = cmd.Run()
}
