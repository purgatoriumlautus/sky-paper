# sysctl — kernel & network hardening

A single drop-in (`99-hardening.conf`) that tightens kernel-level knobs the
firewall can't reach. Complements `nftables/` rather than overlapping with it:

- **nftables** decides which packets cross the network boundary.
- **sysctl** decides how the kernel reacts to packets that already crossed
  (ICMP redirects, spoofed sources) and what it leaks to non-root users.

## What each knob does

| Knob | Effect |
|---|---|
| `kernel.kptr_restrict=1` | Hides kernel pointers in `/proc/kallsyms` etc. from non-root — defeats one KASLR-bypass path. |
| `net.ipv4.conf.*.rp_filter=1` | Drops packets whose source IP isn't reachable via the receiving interface (anti-spoofing). |
| `net.ipv*.conf.*.accept_redirects=0` | Ignore ICMP redirects — a malicious peer on the LAN can't rewrite our routes. |
| `net.ipv4.conf.*.send_redirects=0` | We don't emit redirects either (only routers should). |
| `net.ipv4.tcp_syncookies=1` | SYN-cookie fallback under SYN-flood. Usually default; explicit. |
| `net.ipv4.ip_forward` | **Left off** — laptop is not a router. Uncomment when Docker / libvirt routed mode shows up. |

## Install

```sh
sudo ./install.sh
```

The script copies the drop-in into `/etc/sysctl.d/` and runs `sysctl --system`
so values apply immediately (no reboot).

## Verify

```sh
sysctl kernel.kptr_restrict net.ipv4.conf.all.rp_filter \
       net.ipv4.conf.all.accept_redirects net.ipv4.tcp_syncookies
```

All should report the values listed above.

## Rollback

```sh
sudo rm /etc/sysctl.d/99-hardening.conf
sudo sysctl --system
```
