# celestia

**Flexoki Dark** — a warm ink-and-paper dark rice: [niri](https://github.com/YaLTeR/niri)
+ Quickshell on Arch. PC variant (the ThinkPad sibling is `laniakea`). Warm
near-black base ([Flexoki](https://stephango.com/flexoki) adopted as-is),
purple UI accent, bitmap fonts, no light mode — full color breakdown in
[PALETTE.md](PALETTE.md).

## Deploy

```sh
git clone -b celestia git@github.com:purgatoriumlautus/sky-paper.git ~/celestia
stow -d ~/celestia -t ~ <module>      # each $HOME module
sudo ~/celestia/<module>/install.sh   # each system module
```
