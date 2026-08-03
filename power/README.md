# power — lid, sleep and hibernate policy

Root-owned systemd drop-ins. `sudo ./install.sh` deploys; nothing here is
stowed.

Scope split: **tlp/** owns charge thresholds and runtime power tuning.
**power/** owns what happens when the lid shuts and how deep the machine
goes. They don't overlap.

| File | Target |
|---|---|
| `etc/systemd/logind.conf.d/00-aru.conf` | lid switch → `sleep`, `SleepOperation=` |
| `etc/systemd/sleep.conf.d/00-aru.conf` | `HibernateDelaySec`, `MemorySleepMode=deep` |
| `optional/99-no-usb-wake.rules` | **not installed** — see the file's header |

## Why this module exists

The X280's previous battery died with the protection IC latched. Suspected
cause: the machine stayed awake in a closed backpack and cooked. Three
independent config faults made that reachable:

1. **The Control Center "Auto-suspend" toggle blocked lid-close suspend.**
   It ran `systemd-inhibit --mode=block --what=sleep`, and a block-mode sleep
   inhibitor blocks *every* logind sleep path — lid included. Toggle it off,
   shut the lid, and the machine stayed fully awake with the screen dark.
   Now a Wayland idle inhibitor held by `Bar.qml`, which pauses swayidle's
   timeline and leaves logind alone — see `SuspendInhibit.qml`, not here.
2. **Nothing ever hibernated.** All four sleep entry points called plain
   `systemctl suspend`, so `SleepOperation=` and `HibernateDelaySec=` were
   live in config and dead in practice. Fixed by `HandleLidSwitch=sleep`.
3. **S3 was firmware-default, not pinned.** Fixed by `MemorySleepMode=deep`.

## Hibernation

`install.sh` refuses to run unless hibernation is viable — resume device
resolves, swap ≥ RAM, kernel has `disk` support. Pointing lid-close at
suspend-then-hibernate when hibernate is broken would wake the machine at the
30 min mark and potentially leave it awake with the lid shut, which is the
failure this module prevents.

Current state: 16 GiB swap partition vs ~16 GB RAM, `resume=UUID=` on the
cmdline resolving to `nvme0n1p2`, `systemd` initramfs hook. Configured
correctly — **test it end to end before relying on it:**

```sh
systemctl hibernate      # machine powers off; press power to resume
# after resume — CURRENT boot (-b 0), see the boot-id note below:
journalctl -b 0 -k | grep -iE 'hibernation entry|hibernation exit'
python3 -c 'import time; print(f"{time.clock_gettime(time.CLOCK_BOOTTIME)-time.clock_gettime(time.CLOCK_MONOTONIC):.1f}s powered down")'
```

PASS = `hibernation exit` present, and the second command reports roughly how
long the machine sat switched off. On a cold boot that number is `0.0s`.

**A successful resume looks exactly like a cold boot, and that is the whole
problem.** The machine really is fully powered down, so coming back has to go
through GRUB → kernel → initramfs before `sd-hibernate-resume` restores the
image. Then the lock screen appears, which `quickshell-greeter` deliberately
mirrors. Four separate things therefore mislead:

- **Use `-b 0`, not `-b -1`.** A successful hibernate restores the pre-hibernate
  boot id, so the resume continues the *same* journal boot. `-b -1` is the
  session before it and shows nothing hibernation-related.
- **`Image saved` can never appear after a resume.** The kernel snapshots memory
  first and writes the image to swap *afterwards*, so those lines are printed
  after the snapshot was taken and are not inside it. A restored printk buffer
  always ends at `Disabling non-boot CPUs`. Never grep for them.
- **Seeing GRUB is expected**, not evidence of a cold boot.
- **Being asked for a password is expected** — that is `LockScreen.qml` (logind
  records no new session), not greetd. `loginctl list-sessions` proves which.

Cheapest sanity check of all: your terminals and windows are still open.

`Unable to resume from device … continuing boot process` on a *cold* boot is
normal — it means no image was present, not a fault.

## Verify

```sh
systemd-analyze cat-config systemd/logind.conf | grep -E '^Handle|^SleepOperation'
systemd-analyze cat-config systemd/sleep.conf  | grep -E '^Hibernate|^MemorySleep'
cat /sys/power/mem_sleep          # s2idle [deep]  ← deep must be bracketed
grep -c . <(systemd-inhibit --list | grep 'block.*sleep')   # → 0, nothing blocks sleep
```

Lid test: shut the lid, confirm the machine drops to S3 within a second or
two, wait past 30 min, confirm it has hibernated (power LED off, and
`journalctl -b -1 | grep hibernation` after resume).

## BIOS

Not settable from userspace — check after any firmware update:

- **Config → Power → Sleep State = `Linux`.** If it reads `Windows 10` the
  kernel only offers s2idle and `MemorySleepMode=deep` silently can't apply.
  `cat /sys/power/mem_sleep` must show `deep` as an option.
