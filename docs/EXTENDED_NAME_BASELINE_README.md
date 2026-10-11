# AF0WX XLX Reflector Installer

Maintained by **Ed Hasley, AF0WX** in [EdHasley/Extended_Name_Reflector](https://github.com/EdHasley/Extended_Name_Reflector).

The AF0WX installer builds and installs the bundled XLXD reflector, PP5PK dashboard, optional AMBED transcoder, and optional Echo Test. It adds a reflector manager, selectable protocols and ports, separate extended display names, private/public call-home settings, and portable configuration backups.

**Credit to Daniel K., PP5PK:** This installer and its documentation are based on his [XLX Installer](https://github.com/PP5PK/XLX_Installer). His dashboard and user/RadioID management work are included with their original credits. AF0WX maintains the changes in this repository.

## Requirements

Use a Debian or Ubuntu VM with internet access and administrator access. The installer uses APT and systemd, installs dependencies, and runs an OS upgrade. Have your dashboard domain, sysop email/callsign, and three-character protocol ID ready. Automatic HTTPS requires the domain to resolve correctly and TCP ports 80 and 443 to reach this VM.

Forward the ports for the protocols you enable to the VM running this reflector. AMBE hardware is required for D-Star transcoding to other modes; D-Star-only operation and DMR/YSF operation do not require AMBE transcoding hardware.

## GitHub installation

Run on the target VM:

```bash
sudo apt update
sudo apt install -y git
cd /usr/src
sudo git clone https://github.com/EdHasley/Extended_Name_Reflector.git
cd Extended_Name_Reflector
sudo bash installer.sh
```

Download the whole repository. The installer needs its bundled `templates/`, `xlxd/`, `dashboard/`, and `XLXEcho/` folders. A standalone `installer.sh` download is insufficient. Running `sudo bash installer.sh` avoids executable permission problems.

To update an existing checkout before running the installer:

```bash
cd /usr/src/Extended_Name_Reflector
sudo git pull --ff-only
sudo bash installer.sh
```

Pulling updates changes the checkout; it does not automatically update installed files or restart services. The installer detects existing installations and offers the full uninstaller before reinstalling. Create a backup before removal. Cancelling stops further steps; initial checks or an already confirmed uninstall may have changed the system.

## Startup menu and backup installation

| Choice | Action |
| --- | --- |
| 1 | Install with fresh settings |
| 2 onward | Install from the backup shown beside that number |
| P | Choose a backup from another folder by entering its full path |
| X | Cancel |

The installer automatically finds `reflector-backup-*.tar.gz` files in `/var/backups/extended-name-reflector`, the current working folder, and the installer folder. Duplicate paths are removed. If none are found, the menu says so.

Create a portable backup with `sudo reflector-manager`, **11**, then **1**. For a replacement VM, copy the archive into one of the folders above and select its number during installation. Saved settings are loaded before any existing-install removal and appear in the editable review. The replacement VM keeps its current network configuration; services use its detected IP addresses.

Backups include installation metadata, XLXD build settings, and whitelist, blacklist, interlink, and terminal files. New installation metadata includes domain, email, callsign, country, timezone, dashboard text, SSL, and Echo Test choices. Older backups ask for details they did not save. Protocol switches and ports are read from the backed-up `main.h`, including changes made with the manager.

These are configuration backups. Save custom dashboard images, user databases/passwords, certificates, and public calling-home identity separately when needed. The backup directory survives the full uninstaller.

## Installation choices and settings review

The initial questions collect identity, domain, sysop details, timezone, dashboard text, HTTPS, Echo Test, modules, protocols, ports, AMBED, and public advertising. YSF frequency and auto-link questions appear only when YSF is enabled.

The **final review menu** uses the following numbers. Enter one to edit its setting before compilation, press Enter to proceed, or X to cancel.

| Number | Setting |
| --- | --- |
| 1 | Protocol ID |
| 2 | Extended name |
| 3 | Dashboard FQDN |
| 4 | Email |
| 5 | Callsign |
| 6 | Country |
| 7 | Timezone |
| 8 | XLX list comment |
| 9 | Dashboard tab text |
| 10 | Dashboard footer |
| 11 | SSL certification |
| 12 | Echo Test on module E |
| 13 | Number of modules |
| 14 | Protocol enable/disable and ports; YSF options when enabled |
| 15 | AMBE/transcoder enablement and port |
| 16 | Public call-home advertising |

The protocol ID is three alphanumeric characters, for example `300`, producing `XLX300`. The extended display name is independent and accepts 1–60 characters. Public call-home advertising defaults to **off**. Modules range from 1–26; Echo Test on E requires at least five.

The bundled source supports DExtra, DPlus, DCS, XLX interlink, DMRPlus, DMR MMDVM, YSF, IMRS, and G3 Terminal. Disabled protocols do not open their listening sockets. M17, P25, and NXDN are not implemented by this source.

## Reflector Manager menu structure

Run:

```bash
sudo reflector-manager
```

| Choice | Main menu action |
| --- | --- |
| 1 | User / RadioID management |
| 2 | Enable or disable protocols |
| 3 | Change protocol ports |
| 4 | AMBE / transcoder settings |
| 5 | Extended name / dashboard text |
| 6 | Public call-home advertising |
| 7 | Rebuild XLXD and restart reflector |
| 8 | XLXD uninstall / reinstall maintenance |
| 9 | Show service / reflector status |
| 10 | Access control: whitelist / blacklist / interlink / terminal |
| 11 | Backup / restore reflector configuration |
| X | Exit |

Choose **7** after changing compiled protocol switches or ports. It also rebuilds installed AMBED and synchronizes Echo Test's interlink port. Manager option **5** edits the extended name displayed on the dashboard.

### Protocols: main option 2

| Choice | Protocol |
| --- | --- |
| 1 | DExtra |
| 2 | DPlus |
| 3 | DCS |
| 4 | XLX interlink |
| 5 | DMRPlus |
| 6 | DMR MMDVM |
| 7 | Yaesu / System Fusion (YSF) |
| 8 | IMRS |
| 9 | G3 Terminal |
| X | Back |

After selecting a protocol, use **E** to enable, **D** to disable, or **X** to go back. The ports submenu, main option **3**, numbers its entries according to enabled protocols and includes the core JSON port. **A** opens AMBE/transcoder settings there; **X** goes back.

### AMBE: main option 4

When AMBED is installed, **1** changes its port and **2** enables/disables its service. When it is not installed, **1** offers installation from bundled source. **X** goes back. Compatible AMBE hardware and the FTDI runtime are needed for operation. Choose **7** from the main menu to apply compiled port changes.

### Maintenance: main option 8

| Choice | Action |
| --- | --- |
| 1 | Reinstall/rebuild XLXD from existing source, preserving configuration |
| 2 | Uninstall XLXD core binary/service, after typing UNINSTALL |
| X | Back |

Core maintenance preserves the dashboard, configuration, AMBED, SSL/Certbot, and Cloudflared. Full removal through `templates/uninstaller.sh` has a broader scope, described below.

### Access control: main option 10

| Choice | File |
| --- | --- |
| 1 | `/xlxd/xlxd.whitelist` |
| 2 | `/xlxd/xlxd.blacklist` |
| 3 | `/xlxd/xlxd.interlink` |
| 4 | `/xlxd/xlxd.terminal` |
| X | Back |

For the selected file, **V** views, **E** edits, and **X** goes back. Editing creates a timestamped safety copy in `/var/backups/extended-name-reflector/safety`.

### Backup / restore: main option 11

| Choice | Action |
| --- | --- |
| 1 | Create portable backup |
| 2 | Restore portable backup to an installed reflector |
| X | Back |

Manager restore currently lists backup paths and asks for the full path. It keeps the VM's network configuration, saves pre-restore copies, and restores saved build/configuration and access files. Choose main option **7** afterward. For a fresh or replacement installation, use the installer's numbered backup selection instead.

### User / RadioID management: main option 1

This opens PP5PK's user manager. Its own menu has **1: Database (RadioID)**, **2: Access control**, and **X: Exit** to return to the AF0WX manager.

| Database submenu | Access control submenu |
| --- | --- |
| 1: Add / Edit record | 1: Add user (whitelist + dashboard) |
| 2: Delete record | 2: Reset password (dashboard) |
| 3: List records by callsign | 3: Remove user (whitelist + dashboard) |
| 4: Search records (filter) | 4: Look up user (whitelist + dashboard) |
| 5: Create / Update SQL database | 5: List pending passwords |
| X: Back | 6: List whitelist |
| | X: Back |

## Ports and forwarding

Use the actual ports selected for your reflector. This installer does not configure router forwarding. The following are bundled defaults; only enabled protocols need their protocol ports forwarded.

| Function | Default port | Transport |
| --- | --- | --- |
| Dashboard HTTP / HTTPS | 80 / 443 | TCP |
| DExtra | 30001 | UDP |
| DPlus | 20001 | UDP |
| DCS | 30051 | UDP |
| XLX core / JSON | 10001 | UDP |
| XLX interlink | 10002 | UDP |
| DMRPlus | 8880 | UDP |
| DMR MMDVM | 62030 | UDP |
| YSF | 42000 | UDP |
| IMRS | 21110 | UDP |
| G3 presence / configuration / DV | 12346 / 12345 / 40000 | UDP |
| AMBE/transcoder controller | 10100 | UDP |

AMBED normally communicates locally. Changing its controller port requires matching XLXD and AMBED settings; the installer and manager synchronize them. On a shared public IP, use distinct forwarded ports for separate reflectors.

## Installed files and directories

The checkout path below follows the installation commands above. If cloned elsewhere, run installer and uninstaller commands from that checkout.

| Purpose | Location |
| --- | --- |
| AF0WX installer checkout | `/usr/src/Extended_Name_Reflector/` |
| Bundled sources in checkout | `xlxd/`, `dashboard/`, `XLXEcho/`, `templates/` |
| XLXD build source and settings | `/usr/src/xlxd/`, `/usr/src/xlxd/src/main.h` |
| AMBED source / binary | `/usr/src/xlxd/ambed/`, `/ambed/ambed` |
| Echo Test source / binary | `/usr/src/XLXEcho/`, `/xlxd/xlxecho` |
| Dashboard source copy | `/usr/src/XLX_Dark_Dashboard/` |
| Installed dashboard | `/var/www/html/xlxd/` |
| Dashboard base configuration | `/var/www/html/xlxd/pgs/config.inc.php` |
| Dashboard name / call-home overrides | `/var/www/html/xlxd/config.inc.php` |
| Reflector binary and access files | `/xlxd/` |
| Installation metadata | `/etc/extended-name-reflector/reflector.conf` |
| AF0WX manager | `/usr/local/bin/reflector-manager` |
| Dashboard settings helper | `/usr/local/bin/dashboard-settings.py` |
| PP5PK user manager | `/xlxd/users_db/reflector_user_manager.sh` |
| RadioID/operator files | `/xlxd/users_db/` |
| Database update helper | `/usr/local/bin/update_db.sh` |
| Dashboard authentication | `/var/www/restricted/.htpasswd` |
| Apache site configuration | `/etc/apache2/sites-available/YOUR_DOMAIN.conf` |
| Portable backups / safety copies | `/var/backups/extended-name-reflector/` |
| Installed systemd units | `/etc/systemd/system/` |
| Activity / Echo logs | `/var/log/xlx.log`, `/var/log/xlxecho.log` |
| Reflector XML / PID | `/var/log/xlxd.xml`, `/var/log/xlxd.pid` |
| Log helper / rotation configuration | `/usr/local/bin/xlx_log.sh`, `/etc/logrotate.d/xlx_logrotate.conf` |
| Installer/uninstaller logs | `log/` under the working directory used to launch the script |

Services are `xlxd.service`, `xlx_log.service`, `update_XLX_db.service`, and `update_XLX_db.timer`, plus optional `ambed.service` and `xlxecho.service`.

## HTTPS, service control, and troubleshooting

```bash
sudo systemctl status xlxd.service
sudo systemctl restart xlxd.service
sudo journalctl -u xlxd.service -n 100 --no-pager
sudo tail -f /var/log/xlx.log
```

If certificate setup fails, check DNS and forwarding, then retry:

```bash
sudo certbot --apache -d YOUR_DASHBOARD_DOMAIN
```

For an IP mismatch, inspect `ExecStart` in `/etc/systemd/system/xlxd.service`. The reflector address should be the VM's LAN address behind a router or its directly assigned public address on a VPS. After correcting the service file, run `sudo systemctl daemon-reload` and restart XLXD.

Public-list troubleshooting applies only when call-home is enabled. Private reflectors are intentionally not advertised. Public reflector identity may involve `/xlxd/callinghome.php`; if present, preserve it separately before reinstalling. It is not included in the portable configuration backup.

Internet access is needed for APT packages, RadioID/DMR database downloads, certificates, and optional FTDI D2XX drivers. The proprietary FTDI runtime is downloaded when AMBED is selected and is not bundled here.

## Full uninstall

```bash
cd /usr/src/Extended_Name_Reflector
sudo bash templates/uninstaller.sh
```

The full uninstaller asks for confirmation, removes reflector services/timers, XLXD and AMBED files, installed dashboard and source copies, project metadata/helpers, and listed logs. It also removes the domain's Apache configuration when domain cleanup is selected. The AF0WX installer checkout and portable backup folder are outside its removal list.

**SSL certificates:** The full uninstaller may ask whether to remove the domain's certificate. Choose **NO** to retain it for reuse. It does not uninstall the Certbot package or remove Cloudflared. Main manager option **8 → 2** removes only the XLXD core binary/service and does not perform this full cleanup.

## AF0WX changes and source credits

| Contribution | Credit |
| --- | --- |
| AF0WX installer customization, reflector manager, extended names, selectable protocols/ports, private call-home, portable backups and numbered backup installation | Ed Hasley, **AF0WX** |
| Original installer foundation, dashboard and user/RadioID management | Daniel K., **PP5PK** — [XLX Installer](https://github.com/PP5PK/XLX_Installer), [Dashboard](https://github.com/PP5PK/XLX_Dark_Dashboard) |
| XLX reflector software | Jean-Luc Deltombe, **LX3JL**, and Luc Engelmann, **LX1IQ** — [XLXD](https://github.com/LX3JL/xlxd) |
| Original Debian installer idea | **N5AMD** — [installer](https://github.com/n5amd/xlxd-debian-installer) |
| Echo Test | **Narspt** — [XLXEcho](https://github.com/narspt/XLXEcho) |
| HTTPS certificates | [Certbot](https://certbot.eff.org/) |

Original source credits and component licenses remain in the bundled projects. See [source provenance](docs/BUNDLED_SOURCES.md), [identity audit](docs/IDENTITY_AUDIT.md), and `baseline/installer.sh` for the preserved original installer. Consult each component's license files; the bundled package contains multiple upstream components.

Report AF0WX installer issues in [this repository](https://github.com/EdHasley/Extended_Name_Reflector/issues). Validation includes backup/menu checks, Bash syntax, CI PHP linting and source build/listener checks. A complete VM installation and operation with AMBE hardware still require target-system testing.
