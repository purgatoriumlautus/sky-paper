# xdg

Default-application MIME mappings, deployed with `stow xdg` from the repo
root → `~/.config/mimeapps.list`.

Carries machine-specific handlers (e.g. the Burp Suite entry), so it
does not converge across machines as-is.

Verify: `xdg-mime query default application/pdf`
