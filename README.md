# bash-styling

Shell startup styling, banners, package checks, aliases, and simple timing
helpers for Bash. External packages are used and have smart defaults in their absence.

## Installation

The installer downloads the current release files into
`~/.local/share/bash-styling` and adds a managed source block to `~/.bashrc`:

```bash
curl -fsSL https://raw.githubusercontent.com/Lai-es/bash-styling/main/install.sh | bash
```

The installer downloads:

- `lib/functions.sh`, the Bash functions and startup configuration.
- `lib/success-box`, the `boxes` design used by boxed banners.

Reload the shell after installation:

```bash
source ~/.bashrc
```

To remove the package and its managed `.bashrc` block:

```bash
curl -fsSL https://raw.githubusercontent.com/Lai-es/bash-styling/main/install.sh | bash -s -- uninstall
```

The installer creates timestamped `.bashrc` backups before changing the file.
It supports either `curl` or `wget` for downloads.

## Dependencies

The startup package check looks for these commands:

`lolcat`, `figlet`, `boxes`, `fortune`, `cowsay`, `eza`, `zoxide`, `tput`.

Missing commands are reported when Bash starts, along with a hint to install
the unavailable packages.

To skip the startup package checks, source the library with `-q` or `--quiet`:

`source "$HOME/.local/share/bash-styling/functions.sh" --quiet`

## Functions

### Startup behavior

On startup, the library checks and offers to install
missing packages when a supported package manager is available. When `fortune`,
`cowsay`, and `lolcat` are installed, it prints a random fortune in a random
cow's speech bubble with colored message text. Otherwise, it falls back to a
plain `fortune` and `cowsay` pipeline, if present.

It scans for updates of this package periodically.

### Banners

All banners are centered in the terminal.

- `success_banner "message"` prints a green success banner.
- `fail_banner "message"` prints a red failure banner.
- `log_banner "message"` prints a neutral log banner.

When `boxes` is available, the banner functions use the configured box styles.
Otherwise they fall back to plain colored text, so the functions remain usable
without the optional `boxes` package.

### Timers

- `script_start` (re)sets the script timer.
- `print_script_time` prints elapsed time since the script timer started.
	If `script_start` was not called, it displays an additional warning, as the time began tracking since beginning of the bash session.
- `step_start` starts a step and saves the duration of the previous step.
- `print_step_time` prints the previous step number and duration.

### Aliases and helpers

The library provides directory navigation aliases, an `eza`-based `ls` when
available, a formatted `clear` when `figlet` and `lolcat` are available, and
package-free fallbacks for both commands.

## Testing

Run the verbose test suite from the repository root:

```bash
bash tests/test.sh
```

The tests use a temporary home directory and mocked download/dependency
commands. They cover installer installation, update, and uninstall behavior;
package detection; boxed and fallback banners; text helpers; aliases; and all
timer formatting branches. No real `.bashrc` or installed package files are
changed.
