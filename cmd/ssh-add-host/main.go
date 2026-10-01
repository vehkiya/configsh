package main

import (
	"errors"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/charmbracelet/huh"
	"github.com/charmbracelet/lipgloss"
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
		fmt.Fprintf(os.Stderr, "Usage: ssh-add-host [options] [user@host[:port]] [alias]\n\n")
		fmt.Fprintf(os.Stderr, "Interactively configure and save an SSH host block to ~/.ssh/config.\n\n")
		fmt.Fprintf(os.Stderr, "Arguments:\n")
		fmt.Fprintf(os.Stderr, "  user@host[:port]   Target connection string (optional)\n")
		fmt.Fprintf(os.Stderr, "  alias              Custom nickname/alias for ~/.ssh/config (optional)\n\n")
		fmt.Fprintf(os.Stderr, "Options:\n")
		flag.PrintDefaults()
		fmt.Fprintf(os.Stderr, "\nFeatures:\n")
		fmt.Fprintf(os.Stderr, "  • Interactive TUI wizard powered by Charm Huh\n")
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
	if userName == "" {
		userName = defaultUsername
	}

	port := flagPort
	if port == 0 {
		port = targetPort
	}
	if port == 0 {
		port = 22
	}
	portStr := strconv.Itoa(port)

	alias := flagAlias
	if alias == "" {
		alias = posAlias
	}
	if alias == "" && hostName != "" {
		alias = hostName
	}

	theme := huh.ThemeCharm()
	sshDir := filepath.Join(homeDir, ".ssh")
	configPath := filepath.Join(sshDir, "config")

	authMethod := "key"
	if flagPasswordOnly {
		authMethod = "password"
	}

	identityFile := flagKey

	// If interactive mode, present the Huh TUI
	if !flagNonInteract {
		formHost := huh.NewForm(
			huh.NewGroup(
				huh.NewInput().
					Title("HostName / IP").
					Description("FQDN or IP address of the remote host").
					Placeholder("e.g. 192.168.1.100 or server.example.com").
					Value(&hostName).
					Validate(func(s string) error {
						if strings.TrimSpace(s) == "" {
							return errors.New("HostName is required")
						}
						return nil
					}),
				huh.NewInput().
					Title("Host Alias").
					Description("Nickname used with ssh <alias> and fssh").
					Placeholder("e.g. prod-server").
					Value(&alias).
					Validate(func(s string) error {
						if strings.TrimSpace(s) == "" {
							return errors.New("Host alias is required")
						}
						return nil
					}),
				huh.NewInput().
					Title("User").
					Description("Remote login username").
					Placeholder(defaultUsername).
					Value(&userName),
				huh.NewInput().
					Title("Port").
					Description("SSH port (standard is 22)").
					Placeholder("22").
					Value(&portStr).
					Validate(func(s string) error {
						p, err := strconv.Atoi(strings.TrimSpace(s))
						if err != nil || p <= 0 || p > 65535 {
							return errors.New("port must be between 1 and 65535")
						}
						return nil
					}),
			),
			huh.NewGroup(
				huh.NewSelect[string]().
					Title("Authentication Method").
					Description("Choose how you connect to this server").
					Options(
						huh.NewOption("SSH Key (IdentityFile) [Recommended]", "key"),
						huh.NewOption("Password only (disables pubkey & agent to prevent lockouts)", "password"),
						huh.NewOption("Standard / Default (agent keys with password fallback)", "default"),
					).
					Value(&authMethod),
			),
		).WithTheme(theme)

		if err := formHost.Run(); err != nil {
			if errors.Is(err, huh.ErrUserAborted) {
				fmt.Println("\nAborted.")
				os.Exit(0)
			}
			fmt.Fprintf(os.Stderr, "Form error: %v\n", err)
			os.Exit(1)
		}

		if p, err := strconv.Atoi(strings.TrimSpace(portStr)); err == nil && p > 0 {
			port = p
		}

		// Handle Authentication selection
		if authMethod == "key" && identityFile == "" {
			discovered, _ := DiscoverKeys(sshDir)
			var keyOptions []huh.Option[string]

			for _, k := range discovered {
				rel := k
				if strings.HasPrefix(k, homeDir) {
					rel = "~" + k[len(homeDir):]
				}
				keyOptions = append(keyOptions, huh.NewOption(rel, k))
			}
			keyOptions = append(keyOptions,
				huh.NewOption("Custom key path...", "custom"),
				huh.NewOption("Generate new Ed25519 key on the fly...", "generate"),
			)

			selectedKey := ""
			formKey := huh.NewForm(
				huh.NewGroup(
					huh.NewSelect[string]().
						Title("Select Private Key").
						Description("Choose an existing key in ~/.ssh or generate a new one").
						Options(keyOptions...).
						Value(&selectedKey),
				),
			).WithTheme(theme)

			if err := formKey.Run(); err != nil {
				if errors.Is(err, huh.ErrUserAborted) {
					fmt.Println("\nAborted.")
					os.Exit(0)
				}
				os.Exit(1)
			}

			if selectedKey == "custom" {
				var customPath string
				formCustom := huh.NewForm(
					huh.NewGroup(
						huh.NewInput().
							Title("Private Key Path").
							Description("Path to your private key file").
							Placeholder("~/.ssh/id_custom").
							Value(&customPath).
							Validate(func(s string) error {
								exp := expandHome(strings.TrimSpace(s), homeDir)
								if _, err := os.Stat(exp); err != nil {
									return fmt.Errorf("file does not exist: %s", exp)
								}
								return nil
							}),
					),
				).WithTheme(theme)

				if err := formCustom.Run(); err != nil {
					if errors.Is(err, huh.ErrUserAborted) {
						fmt.Println("\nAborted.")
						os.Exit(0)
					}
					os.Exit(1)
				}
				identityFile = expandHome(strings.TrimSpace(customPath), homeDir)
			} else if selectedKey == "generate" {
				cleanAlias := strings.Fields(alias)[0]
				defaultPath := filepath.Join(sshDir, "id_ed25519_"+cleanAlias)
				genPath := "~" + defaultPath[len(homeDir):]

				formGen := huh.NewForm(
					huh.NewGroup(
						huh.NewInput().
							Title("New Key File Path").
							Description("Path where the new Ed25519 key will be created").
							Value(&genPath),
					),
				).WithTheme(theme)

				if err := formGen.Run(); err != nil {
					if errors.Is(err, huh.ErrUserAborted) {
						fmt.Println("\nAborted.")
						os.Exit(0)
					}
					os.Exit(1)
				}

				expandedGenPath := expandHome(strings.TrimSpace(genPath), homeDir)
				comment := fmt.Sprintf("%s@%s", userName, hostName)
				fmt.Printf("\nGenerating Ed25519 key at %s...\n", expandedGenPath)
				cmd := exec.Command("ssh-keygen", "-t", "ed25519", "-C", comment, "-f", expandedGenPath)
				cmd.Stdin = os.Stdin
				cmd.Stdout = os.Stdout
				cmd.Stderr = os.Stderr
				if err := cmd.Run(); err != nil {
					fmt.Fprintf(os.Stderr, "ssh-keygen failed: %v\n", err)
				}
				identityFile = expandedGenPath
			} else {
				identityFile = selectedKey
			}

			// Offer ssh-copy-id if public key exists
			if identityFile != "" {
				pubKey := identityFile + ".pub"
				if _, err := os.Stat(pubKey); err == nil {
					var copyKey bool
					formCopy := huh.NewForm(
						huh.NewGroup(
							huh.NewConfirm().
								Title(fmt.Sprintf("Copy public key to %s@%s with ssh-copy-id?", userName, hostName)).
								Description("Uploads public key so you can login passwordless").
								Value(&copyKey),
						),
					).WithTheme(theme)

					if err := formCopy.Run(); err == nil && copyKey {
						copyKeyCmd(pubKey, port, userName, hostName)
					}
				}
			}
		}
	}

	// Prepare HostEntry
	pubkeyAuth := true
	passwordAuth := false

	switch authMethod {
	case "password":
		pubkeyAuth = false
		passwordAuth = true
		identityFile = ""
	case "default":
		pubkeyAuth = true
		passwordAuth = false
		identityFile = ""
	case "key":
		pubkeyAuth = true
		passwordAuth = false
	}

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

	var existingContent string
	if data, err := os.ReadFile(configPath); err == nil {
		existingContent = string(data)
	}

	if HasHost(existingContent, alias) {
		if !flagNonInteract {
			var overwrite bool
			formOverwrite := huh.NewForm(
				huh.NewGroup(
					huh.NewConfirm().
						Title(fmt.Sprintf("Host alias '%s' already exists in ~/.ssh/config. Overwrite?", alias)).
						Value(&overwrite),
				),
			).WithTheme(theme)

			if err := formOverwrite.Run(); err != nil || !overwrite {
				fmt.Println("Aborted.")
				os.Exit(0)
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

	// Render stylish success box with Lip Gloss
	boxStyle := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color("63")).
		Padding(0, 2).
		Margin(1, 0)

	titleStyle := lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color("42"))

	fmt.Println()
	fmt.Println(titleStyle.Render(fmt.Sprintf("✔ Successfully saved to %s", configPath)))
	fmt.Println(boxStyle.Render(strings.TrimRight(formattedBlock, "\n")))

	if !flagNonInteract {
		connectTarget := strings.Fields(alias)[0]
		var connectNow bool
		formConnect := huh.NewForm(
			huh.NewGroup(
				huh.NewConfirm().
					Title(fmt.Sprintf("Connect to '%s' now?", connectTarget)).
					Value(&connectNow),
			),
		).WithTheme(theme)

		if err := formConnect.Run(); err == nil && connectNow {
			fmt.Printf("Connecting to %s...\n\n", connectTarget)
			cmd := exec.Command("ssh", connectTarget)
			cmd.Stdin = os.Stdin
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			_ = cmd.Run()
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

func copyKeyCmd(pubKey string, port int, user, host string) {
	args := []string{"-i", pubKey}
	if port > 0 && port != 22 {
		args = append(args, "-p", strconv.Itoa(port))
	}
	target := fmt.Sprintf("%s@%s", user, host)
	args = append(args, target)

	fmt.Printf("\nRunning: ssh-copy-id %s\n", strings.Join(args, " "))
	cmd := exec.Command("ssh-copy-id", args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	_ = cmd.Run()
}
