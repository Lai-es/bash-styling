# Credits

This project includes code copied or adapted from other open-source projects.
Where a license is noted below, that code remains under its original license —
check it before reusing this project's code elsewhere.

Each entry follows the same shape: **Source** (a permalink to the exact commit,
not a branch), **License**, and **Status** (`Copied verbatim`, `Adapted`, or
`Based on`, i.e. rewritten but inspired by).

---

## `install.sh`

### `get_latest_version()`
- **Source:** https://github.com/HalFrgrd/flyline/blob/6c196ec94942d95c21f00a6a96ab8bd600ceb2a8/install.sh#L103-L115
- **License:** MIT
- **Status:** Adapted — added `local` variable declarations and wired the
  function into this project's `REPO` variable; redirect-resolution logic
  is unchanged from the original.

---

## `functions.sh`

### `success_banner(), fail_banner(), banner_border(), banner_mid()`
- **Source:** https://unix.stackexchange.com/a/250094, adapted as https://github.com/TimothyJones/timbash/blob/39cdf77ae4f1981527a494d5a02be62c40df900e/lib/lib-logging.sh#L33-L58
- **License:** -
- **Status:** Adapted — added a `BOXES_AVAILABLE` branch that pipes the
  banner text through `boxes` with `stone` or `warning` styles; retained the
  original colored echo fallback when `boxes` is unavailable.

### `center_text()`
- **Source:** https://unix.stackexchange.com/a/464432
- **License:** -
- **Status:** Copied verbatim

### `center_box()`
- **Source:** https://unix.stackexchange.com/a/464432
- **License:** -
- **Status:** Copied verbatim

---

<!--
Template for a new entry:

### `<function_name>()`
- **Source:**
- **License:**
- **Status:**
-->