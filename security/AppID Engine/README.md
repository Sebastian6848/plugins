# os-ndpi-audit

OPNsense independent plugin for mirrored traffic application identification.

## Features

- Bundle prebuilt `ndpiReader` to `/usr/local/bin/ndpiReader`
- Bundle fingerprint datasets to `/usr/local/share/ndpi/`
- Mirror selected interfaces to a dedicated loopback interface with `pf` `dup-to`
- Run external `ndpiReader`-based engine as a daemon
- Write JSON line audit logs to `/var/log/ndpi_audit.log`
- GUI for global settings, live view, category statistics, and history search
- Service managed by `configd`, with startup hook and logrotate (`newsyslog`)

## Notes

- The plugin is plug-and-play after installation. External manual file copy is not required.
- If needed, binary path and fingerprint file paths can still be overridden in GUI.

## Self-check Commands

### Development side (after packaging source changes)

Run in plugin directory:

`make selfcheck`

or separately:

- `make selfcheck-package` (verify plist contains bundled engine/data files)
- `make selfcheck-stage` (verify staged install contains files and executable bit)

### Target firewall side (after package installation)

Verify installed file list:

`pkg info -l os-ndpi-audit | grep -E '/usr/local/bin/ndpiReader|/usr/local/share/ndpi/(ja4_fingerprints.csv|tcp_fingerprints.csv|protos.txt|sha1_fingerprints.csv|categories.txt)'`

Verify runtime artifacts:

- `test -x /usr/local/bin/ndpiReader && echo OK_binary`
- `ls -l /usr/local/share/ndpi/`
- `configctl ndpiaudit status`
