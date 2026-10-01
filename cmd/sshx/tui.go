package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/bubbles/list"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/huh"
	"github.com/charmbracelet/lipgloss"
)

var (
	titleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("205")).
			Background(lipgloss.Color("235")).
			Padding(0, 1)

	detailBoxStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("63")).
			Padding(0, 1).
			MarginTop(1)

	keyLabelStyle = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("99"))
	keyValStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("252"))
)

type customDelegate struct {
	list.DefaultDelegate
}

func newCustomDelegate() customDelegate {
	d := list.NewDefaultDelegate()
	d.Styles.SelectedTitle = d.Styles.SelectedTitle.
		Foreground(lipgloss.Color("205")).
		BorderLeftForeground(lipgloss.Color("205")).
		Bold(true)
	d.Styles.SelectedDesc = d.Styles.SelectedDesc.
		Foreground(lipgloss.Color("246")).
		BorderLeftForeground(lipgloss.Color("205"))
	return customDelegate{DefaultDelegate: d}
}

type listKeyMap struct {
	connect key.Binding
	add     key.Binding
	delete  key.Binding
	copyID  key.Binding
	edit    key.Binding
}

func newListKeyMap() *listKeyMap {
	return &listKeyMap{
		connect: key.NewBinding(
			key.WithKeys("enter"),
			key.WithHelp("enter", "connect"),
		),
		add: key.NewBinding(
			key.WithKeys("a"),
			key.WithHelp("a", "add host"),
		),
		delete: key.NewBinding(
			key.WithKeys("d", "x"),
			key.WithHelp("d", "delete"),
		),
		copyID: key.NewBinding(
			key.WithKeys("c"),
			key.WithHelp("c", "ssh-copy-id"),
		),
		edit: key.NewBinding(
			key.WithKeys("e"),
			key.WithHelp("e", "edit config"),
		),
	}
}

type model struct {
	list     list.Model
	keys     *listKeyMap
	choice   string
	action   string
	quitting bool
}

func (m model) Init() tea.Cmd {
	return nil
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		h, v := msg.Width, msg.Height
		m.list.SetSize(h, v-6)
		return m, nil

	case tea.KeyMsg:
		if m.list.FilterState() == list.Filtering {
			break
		}

		switch {
		case key.Matches(msg, m.keys.connect):
			if selected, ok := m.list.SelectedItem().(HostItem); ok {
				m.choice = selected.Alias
				m.action = "connect"
				return m, tea.Quit
			}

		case key.Matches(msg, m.keys.add):
			m.action = "add"
			return m, tea.Quit

		case key.Matches(msg, m.keys.delete):
			if selected, ok := m.list.SelectedItem().(HostItem); ok {
				m.choice = selected.Alias
				m.action = "delete"
				return m, tea.Quit
			}

		case key.Matches(msg, m.keys.copyID):
			if selected, ok := m.list.SelectedItem().(HostItem); ok {
				m.choice = selected.Alias
				m.action = "copy-id"
				return m, tea.Quit
			}

		case key.Matches(msg, m.keys.edit):
			m.action = "edit"
			return m, tea.Quit

		case msg.String() == "q" || msg.String() == "ctrl+c":
			m.quitting = true
			m.action = "quit"
			return m, tea.Quit
		}
	}

	var cmd tea.Cmd
	m.list, cmd = m.list.Update(msg)
	return m, cmd
}

func (m model) View() string {
	if m.quitting {
		return ""
	}

	var sb strings.Builder
	sb.WriteString(m.list.View())

	if selected, ok := m.list.SelectedItem().(HostItem); ok {
		var details []string
		targetStr := selected.HostName
		if selected.User != "" {
			targetStr = selected.User + "@" + targetStr
		}
		if selected.Port > 0 && selected.Port != 22 {
			targetStr += fmt.Sprintf(":%d", selected.Port)
		}

		details = append(details, fmt.Sprintf("%s %s", keyLabelStyle.Render("Target:"), keyValStyle.Render(targetStr)))

		authStr := "Default (Agent/Keys + Password)"
		if !selected.PubkeyAuth || selected.PasswordAuth {
			authStr = "Password Only (Pubkey Disabled)"
		} else if selected.IdentityFile != "" {
			authStr = fmt.Sprintf("Key: %s", selected.IdentityFile)
		}
		details = append(details, fmt.Sprintf("%s %s", keyLabelStyle.Render("Auth:"), keyValStyle.Render(authStr)))

		if selected.ProxyJump != "" {
			details = append(details, fmt.Sprintf("%s %s", keyLabelStyle.Render("ProxyJump:"), keyValStyle.Render(selected.ProxyJump)))
		}

		if len(selected.AllAliases) > 1 {
			details = append(details, fmt.Sprintf("%s %s", keyLabelStyle.Render("Aliases:"), keyValStyle.Render(strings.Join(selected.AllAliases, ", "))))
		}

		details = append(details, fmt.Sprintf("%s %s", keyLabelStyle.Render("Config:"), keyValStyle.Render(selected.ConfigFile)))

		sb.WriteString("\n" + detailBoxStyle.Render(strings.Join(details, "\n")))
	}

	return sb.String()
}

// RunTUI launches the interactive host browser and returns the selected alias and requested action.
func RunTUI(homeDir string) (selectedAlias string, action string, err error) {
	hosts, err := LoadAllHosts(homeDir)
	if err != nil {
		return "", "", err
	}

	items := make([]list.Item, len(hosts))
	for i, h := range hosts {
		items[i] = h
	}

	delegate := newCustomDelegate()
	l := list.New(items, delegate, 80, 20)
	l.Title = "SSH Connection Manager (sshx)"
	l.Styles.Title = titleStyle

	keys := newListKeyMap()
	l.AdditionalShortHelpKeys = func() []key.Binding {
		return []key.Binding{keys.connect, keys.add, keys.delete, keys.copyID, keys.edit}
	}
	l.AdditionalFullHelpKeys = func() []key.Binding {
		return []key.Binding{keys.connect, keys.add, keys.delete, keys.copyID, keys.edit}
	}

	m := model{
		list: l,
		keys: keys,
	}

	p := tea.NewProgram(m, tea.WithAltScreen())
	finalModel, err := p.Run()
	if err != nil {
		return "", "", err
	}

	fm, ok := finalModel.(model)
	if !ok {
		return "", "quit", nil
	}

	return fm.choice, fm.action, nil
}

// DeleteHostPrompt prompts for confirmation and strips a host from ~/.ssh/config.
func DeleteHostPrompt(alias, homeDir string) error {
	var confirm bool
	form := huh.NewForm(
		huh.NewGroup(
			huh.NewConfirm().
				Title(fmt.Sprintf("Delete host block for '%s' from ~/.ssh/config?", alias)).
				Description("This action permanently removes the Host configuration entry").
				Value(&confirm),
		),
	).WithTheme(huh.ThemeCharm())

	if err := form.Run(); err != nil || !confirm {
		return nil
	}

	configPath := filepath.Join(homeDir, ".ssh", "config")
	data, err := os.ReadFile(configPath)
	if err != nil {
		return err
	}

	cleaned := RemoveHost(string(data), alias)
	if err := AtomicWrite(configPath, []byte(cleaned), 0600); err != nil {
		return err
	}

	fmt.Printf("\n✔ Removed '%s' from %s\n\n", alias, configPath)
	return nil
}
