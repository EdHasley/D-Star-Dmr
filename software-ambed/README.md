# Standalone software AMBED for XLXD

Experimental CPU-only D-Star ↔ DMR transcoding using the bundled DroidStar
MBEVocoder. This is a local AMBED-compatible service, not a network master.
XLXD supplies the D-Star and DMR protocol handling and module routing.

## Build and test without installing

```bash
sudo apt install -y build-essential python3
make -C software-ambed -j2 test
```

`codec-check` generates 160-sample, 8 kHz frames and exercises encode → decode →
encode → decode in both directions. Its decoded energy check is a basic codec
smoke test, not a speech quality score. UDP tests cover stream opening, both
conversion directions, capacity rejection, close ownership, malformed messages,
peer filtering and idle reclamation. Timing is host-dependent.

## Fresh test VM

Use the root installer and choose **Software** under review item **15**.
Enable DExtra/DPlus/DCS as appropriate and DMR MMDVM. Keep call-home disabled for
private tests. Link the D-Star and DMR clients to the same reflector module.
XLXD handles existing callsign/RadioID mapping; ensure the operator database is current.

The service binds `127.0.0.1`; XLXD must bind the VM's specific LAN IPv4 address,
not `0.0.0.0` or `127.0.0.1`. Both processes use the same controller and stream
port numbers on different local addresses. The service accepts packets only from
the configured XLXD address. Do not forward its UDP ports through the router.
Hardware AMBED and software AMBED must not run together on the same controller port.

For an existing experimental installation using this project's source:

```bash
sudo bash /usr/src/xlxd/software-ambed/install.sh 10100
sudo systemctl restart xlxd.service
sudo journalctl -u software-ambed.service -n 100 --no-pager
```

The helper reads the peer from `/etc/systemd/system/xlxd.service`. Port `10100`
must match `TRANSCODER_PORT` in `/usr/src/xlxd/src/main.h`; rebuild XLXD if changed.
Manager option **4** controls the installed backend; option **7** rebuilds and
synchronizes the software service port. Software selection survives fresh-install
portable-backup restoration. Full uninstall removes the software unit and binary.
The inherited manager restore of an already installed reflector restores settings;
it does not automatically install or switch transcoder backends.

For manual foreground development, with XLXD listening on `10.201.1.50`:

```bash
./software-ambed/software-ambed --peer 10.201.1.50 --port 10100 --channels 4
```

## Wire contract

| Message | Bytes |
| --- | --- |
| Keepalive | `AMBEDPING` + 8-byte callsign; reply `AMBEDPONG` |
| Open | `AMBEDOS` + 8-byte callsign + input codec + output codec |
| Open reply | `AMBEDSTD` + native-endian uint16 stream ID + uint16 port + input + output |
| Capacity/unsupported conversion | `AMBEDBUSY` |
| Close | `AMBEDCS` + native-endian uint16 stream ID |
| Voice | codec byte + packet ID byte + 9-byte voice codeword |

Codec 1 is D-Star 2400/1200; codec 2 is DMR 2450/1150. Each stream has separate
decoder and encoder state. Voice responses preserve the request packet ID.
The service converts frames serially, avoiding concurrent access to upstream
codec globals. Four channels is a starting limit, not a verified capacity rating.
Inactive streams expire after ten seconds by default.

## Remaining validation

- Capture independently generated voice from actual D-Star and DMR radios.
- Listen to speech both ways; compare levels, intelligibility and clipping.
- Test long transmissions, end-of-stream behavior, dropouts and multiple modules.
- Check p95 frame latency under load and XLXD's existing FIFO response handling.
- Test a full Debian/Ubuntu VM install, reboot, manager changes and uninstall.

No live-radio interoperability claim is made yet. The software has no firmware
download or hardware dependency. Upstream licenses and original credits are
retained; see `PROVENANCE.md` and source-file notices.
