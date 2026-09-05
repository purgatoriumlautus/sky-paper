# xdg

Default-application MIME mappings, deployed with `stow xdg` from the repo root -> `config/mimeapps.list`.
Application .desktop files for has to be copied from `./applications` to `~/.local/share/applications/`

## Examples :

**Set a default app**

```bash
xdg-settings set default-web-browser firefox.desktop
xdg-mime default nvim.desktop text/plain
```

**Open an app using a default xdg**

```bash
xdg-open https://example.com
```

**Verify** 
```bash
xdg-mime query default application/pdf
xdg-mime query default text/plain
```

**Update application database**
```bash
update-desktop-database ~/.local/share/applications
```

** Query filetype **
```bash
xdg-mime query filetype <файл>      #
```




