# laniakea

**Flexoki Dark** — a warm ink-and-paper dark rice: [niri](https://github.com/YaLTeR/niri)
+ Quickshell on Arch, on a ThinkPad X280. Warm near-black base
([Flexoki](https://stephango.com/flexoki) adopted as-is), purple UI accent,
bitmap fonts, no light mode — full color breakdown in [PALETTE.md](PALETTE.md).

![home](docs/screenshots/home.png)

![overview](docs/screenshots/overview.png)

## Deploy

```sh
git clone -b laniakea git@github.com:purgatoriumlautus/sky-paper.git ~/dotfiles
stow -d ~/dotfiles -t ~ <module>      # each $HOME module
sudo ~/dotfiles/<module>/install.sh   # each system module
```
