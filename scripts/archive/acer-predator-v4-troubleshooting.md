# Troubleshooting: Predator PH315-54 fan "power"/turbo mode on Linux

Root-cause writeup for why the Predator "power"/Turbo fan option did nothing on
Linux, and how it was fixed. The actual fix is automated in
`../acer-predator-v4.sh`.

## Symptom

The physical Predator "power"/Turbo fan option had no effect on Linux — no way
to force the fans to max.

## Investigation

### 1. Identify the hardware and kernel
```bash
cat /sys/class/dmi/id/product_name   # Predator PH315-54
cat /sys/class/dmi/id/sys_vendor     # Acer
cat /sys/class/dmi/id/bios_version   # V1.12
uname -r                             # 7.0.0-27-generic
```
Reasoning: Acer's fan/turbo control on Linux runs through the `acer-wmi`
platform driver, and behavior depends heavily on the exact model generation.
The PH315-54 is a PredatorSense-**v4** machine — that detail turned out to be
the whole ballgame.

### 2. Confirm the driver is actually loaded
```bash
lsmod | grep -i acer          # acer_wmi loaded, bound to platform_profile
ls /sys/devices/platform/acer-wmi/
```
Reasoning: Before chasing anything exotic, verify the in-tree driver is present.
It was — `acer_wmi` was loaded and even linked against the `platform_profile`
subsystem, so the plumbing existed.

### 3. Look for the control surfaces that *should* exist
```bash
cat /sys/firmware/acpi/platform_profile          # empty
cat /sys/firmware/acpi/platform_profile_choices  # empty
ls /sys/class/platform-profile/                  # empty (no handler)
find /sys/devices/platform/acer-wmi -iname '*fan*'   # nothing
```
Reasoning: The "power" fan mode on Linux is exposed as a **platform profile**
(`performance` = turbo). Both the legacy ACPI node and the newer
`/sys/class/platform-profile/` class were empty, and there were no fan controls
at all. So the driver was loaded but registering *none* of its power/fan
features — pointing at a capability that's gated off, not a missing driver.

### 4. Inspect the driver's tunables
```bash
modinfo acer_wmi | grep parm
```
This surfaced the smoking gun:
```
parm: predator_v4:Enable features for predator laptops that use predator sense v4 (bool)
```

### 5. Check the current value and whether it's runtime-writable
```bash
cat /sys/module/acer_wmi/parameters/predator_v4     # N   <- disabled
ls -l /sys/module/acer_wmi/parameters/predator_v4   # -r--r--r--  (read-only)
grep -rniE 'acer.?wmi|predator_v4' /etc/modprobe.d/ # (none)
```
Reasoning: The parameter was **off by default** and **read-only at runtime** —
meaning it can only be set when the module loads, and nothing on the system was
setting it.

## Root cause

Mainline `acer-wmi` hides all PredatorSense-v4 features — the
`performance`/turbo platform profiles **and** the fan RPM sensors — behind the
`predator_v4` module parameter, which defaults to `N`. On a v4 machine like the
PH315-54, that leaves you with no profile handler and no fan controls, exactly
the empty sysfs observed.

## Fix (verified live)

```bash
sudo modprobe -r acer_wmi && sudo modprobe acer_wmi predator_v4=1
```
After reload:
```
predator_v4 = Y
/sys/class/platform-profile/platform-profile-0
  acer-wmi: low-power quiet balanced balanced-performance performance
fan1_input, fan2_input   # CPU + GPU fan RPM
```
`performance` is the turbo/max-fan mode.

Persist across reboots:
```bash
echo 'options acer_wmi predator_v4=1' | sudo tee /etc/modprobe.d/acer-wmi.conf
sudo update-initramfs -u
```

## Using it

```bash
# Turn fans to max / turbo:
echo performance | sudo tee /sys/class/platform-profile/*/profile
# Back to normal:
echo balanced    | sudo tee /sys/class/platform-profile/*/profile
# Current mode:
cat /sys/class/platform-profile/*/profile
```

GNOME/KDE power-mode applets and `powerprofilesctl` pick these modes up
automatically (`performance` = turbo).

## Follow-up: the physical Turbo button does NOT work (and can't)

Separately investigated. **The Turbo button emits nothing to Linux.** Verified by
monitoring *all* 22 input devices plus `/proc/acpi/event` simultaneously while
pressing and holding it — zero events from any source, including the
`Acer WMI hotkeys` device (`event8`) and the AT keyboard controller.

The button is handled entirely inside the EC/firmware on this model, so there is
no scancode to remap and nothing for `acer-wmi` to hook. This is not fixable in
userspace.

Workaround: bind `scripts/acer-predator-v4.sh --toggle` to a keyboard shortcut.

## Follow-up: independent fan control is NOT possible with mainline

Everything `acer-wmi` exposes under hwmon is read-only:

```
fan1_input, fan2_input      -r--r--r--   RPM
temp1_input..temp3_input    -r--r--r--   degC
```

There is no `pwm*` node anywhere on the system. Fan speed is only a side effect
of the platform profile.

The out-of-tree [`linuwu-sense`](https://github.com/0x7375646F/Linuwu-Sense)
module does provide per-fan control (`predator_sense/fan_speed`, "cpu,gpu"
percentages), but as of this writing it is **not viable here**:

- Tested only on kernels **6.12–6.14**; this machine runs **7.0.0-27**.
- Already broken at 6.17: unknown-symbol errors for `platform_profile_notify`,
  `devm_platform_profile_register`, `sparse_keymap` (CRCs `0x00000000`), plus
  incompatible-pointer errors in `wmi_install_notify_handler` / `platform_remove`.
- Only **PHN16-71** is listed as fully supported; the PH315-54 is not.
- Installs via plain `make install` (not DKMS) and *replaces* the in-tree
  `acer_wmi` with a patched fork. Uninstall is `make uninstall`.

Revisit if upstream adds 7.x support.

## Sensor mapping (important — temp3 is a dead channel)

Per `drivers/platform/x86/acer-wmi.c`, the three channels are defined as:

```c
static const enum acer_wmi_predator_v4_sensor_id
acer_wmi_temp_channel_to_sensor_id[] = {
	[0] = ACER_WMID_SENSOR_CPU_TEMPERATURE,
	[1] = ACER_WMID_SENSOR_GPU_TEMPERATURE,
	[2] = ACER_WMID_SENSOR_EXTERNAL_TEMPERATURE_2,
};
```

No labels are registered, so they show up unnamed. Values are read via
`WMID_gaming_get_sys_info()` and scaled with `* MILLIDEGREE_PER_DEGREE` — the EC
reports whole degrees, so there is no scaling bug.

Verified empirically against known-good sources:

| Channel | Driver ID              | Behaviour on PH315-54                         |
|---------|------------------------|-----------------------------------------------|
| `temp1` | CPU_TEMPERATURE        | Correct — tracks `acpitz`/coretemp within 1-2C |
| `temp2` | GPU_TEMPERATURE        | Correct — tracks `nvidia-smi` within 1-2C      |
| `temp3` | EXTERNAL_TEMPERATURE_2 | **Dead — fixed ~83C placeholder**              |

### Evidence that temp3 is not a live reading

A controlled 3.5-minute experiment (balanced -> performance -> balanced) swung
fan speed 3.7x while logging every 5s:

| Phase       | Fans      | CPU     | GPU     | temp3     |
|-------------|-----------|---------|---------|-----------|
| balanced    | 3092 rpm  | 55-58C  | 51-54C  | 83-85C    |
| performance | 5000/5660 | 57->53C | 52->49C | **83C**   |
| balanced    | 1538 rpm  | 53-56C  | 48-52C  | **83C**   |

`temp1`/`temp2` responded correctly to airflow; `temp3` never moved, emitting
only the quantized values 82-85. No other sensor on the system reads anywhere
near 83C. Conclusion: this board doesn't have "external sensor 2" wired, and the
EC returns a placeholder. The channel is real in the driver; the sensor is not
real on this machine.

**Do not use temp3 for anything.** A `max()` across all hwmon sensors is
dominated by it and pins the machine to `performance` forever —
`acer-fan-curve.sh` reads only the CPU package and dGPU for this reason.

For reference, i3status's `cpu_temperature 0` reads `thermal_zone0` (`acpitz`)
and is correct; it disagreeing with `temp3_input` is expected, not a fault.
Idle temps on this machine are CPU ~57C / GPU ~52C, which is healthy.

Note: hwmon numbering shifts when `acer_wmi` is reloaded (it was `hwmon8`, later
`hwmon6`) — always resolve it by reading the `name` file rather than hardcoding.

## Notes

- `power-profiles-daemon` is active on this system and **owns** the platform
  profile — direct sysfs writes fight it and can be reverted. Use
  `powerprofilesctl` instead; it also needs no root, which is what makes the
  keybind toggle work. PPD collapses acer-wmi's five profiles into three
  (performance / balanced / power-saver).
- If a BIOS update ever changes the WMI interface and the profiles disappear
  again, `predator_v4=1` is still the switch to check.
