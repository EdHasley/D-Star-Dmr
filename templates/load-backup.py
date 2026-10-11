#!/usr/bin/env python3
"""Read portable reflector settings as data; never execute archived configuration."""
import base64
import pathlib
import re
import shlex
import sys
import tarfile


def load(archive, destination):
    dest = pathlib.Path(destination)
    with tarfile.open(archive, 'r:gz') as tar:
        files = {}
        for member in tar.getmembers():
            path = pathlib.PurePosixPath(member.name)
            if path.is_absolute() or '..' in path.parts or member.issym() or member.islnk():
                raise ValueError('Unsafe archive entry')
            name = str(path)
            if name in ('etc/reflector.conf', 'source/main.h') or name in {
                'access/' + f for f in ('xlxd.whitelist', 'xlxd.blacklist', 'xlxd.interlink', 'xlxd.terminal')
            }:
                if not member.isfile() or member.size > 4 * 1024 * 1024:
                    raise ValueError('Invalid backup member')
                files[name] = tar.extractfile(member).read().decode('utf-8')
    if 'etc/reflector.conf' not in files or 'source/main.h' not in files:
        raise ValueError('Backup must contain reflector.conf and main.h')
    conf = {}
    for line in files['etc/reflector.conf'].splitlines():
        if '=' not in line or line.startswith('#'):
            continue
        key, value = line.split('=', 1)
        words = shlex.split(value)
        conf[key] = words[0] if len(words) == 1 else ''
    for key in list(conf):
        if key.endswith('_B64'):
            conf[key[:-4]] = base64.b64decode(conf[key], validate=True).decode('utf-8')
    defines = dict(re.findall(r'^\s*#define\s+(\w+)\s+([^\s/]+)', files['source/main.h'], re.M))
    result = {}
    identity = conf.get('PROTOCOL_ID', '')
    if not re.fullmatch(r'XLX[A-Z0-9]{3}', identity):
        raise ValueError('Invalid protocol ID')
    result.update(XRFNUM=identity, XRFDIGIT=identity[3:])
    for key in ('EXTENDED_NAME', 'XLXDOMAIN', 'EMAIL', 'CALLSIGN', 'COUNTRY', 'TIMEZONE', 'COMMENT', 'HEADER', 'FOOTER', 'INSTALL_SSL', 'INSTALL_ECHO'):
        if key in conf:
            result[key] = conf[key]
    result['CALLHOME_USER'] = conf.get('CALL_HOME', 'N')
    result['ENABLE_TRANSCODER'] = conf.get('TRANSCODER_ENABLED', 'N')
    backend = conf.get('TRANSCODER_BACKEND', 'hardware' if result['ENABLE_TRANSCODER'] == 'Y' else 'none')
    if backend not in ('none', 'hardware', 'software'):
        raise ValueError('Invalid transcoder backend')
    result['TRANSCODER_BACKEND'] = backend
    result['ENABLE_TRANSCODER'] = 'Y' if backend == 'hardware' else 'N'
    for key in ('CALLHOME_USER', 'ENABLE_TRANSCODER', 'INSTALL_SSL', 'INSTALL_ECHO'):
        if key in result and result[key] not in ('Y', 'N'):
            raise ValueError('Invalid switch: ' + key)
    for mode in ('DEXTRA', 'DPLUS', 'DCS', 'XLX', 'DMRPLUS', 'DMRMMDVM', 'YSF', 'IMRS', 'G3'):
        value = defines.get('ENABLE_' + mode)
        if value not in ('0', '1'):
            raise ValueError('Missing/invalid protocol switch: ' + mode)
        result['ENABLE_' + mode + '_USER'] = 'Y' if value == '1' else 'N'
    result['ENABLE_YAESU_USER'] = 'Y' if any(result['ENABLE_' + m + '_USER'] == 'Y' for m in ('YSF', 'IMRS')) else 'N'
    for key in ('DEXTRA_PORT', 'DPLUS_PORT', 'DCS_PORT', 'XLX_PORT', 'DMRPLUS_PORT', 'DMRMMDVM_PORT', 'IMRS_PORT', 'G3_PRESENCE_PORT', 'G3_CONFIG_PORT', 'G3_DV_PORT', 'TRANSCODER_PORT', 'YSF_PORT'):
        value = defines.get(key, '')
        if not value.isdigit() or not 1 <= int(value) <= 65535:
            raise ValueError('Invalid port: ' + key)
        result['YSFPORT' if key == 'YSF_PORT' else key + '_USER'] = value
    count = defines.get('NB_OF_MODULES', '')
    if not count.isdigit() or not 1 <= int(count) <= 26:
        raise ValueError('Invalid module count')
    result['MODQTD'] = count
    result['YSFFREQ'] = defines.get('YSF_DEFAULT_NODE_TX_FREQ', '433125000')
    if not re.fullmatch(r'\d{9}', result['YSFFREQ']):
        raise ValueError('Invalid YSF frequency')
    result['AUTOLINK'] = defines.get('YSF_AUTOLINK_ENABLE', '0')
    if result['AUTOLINK'] not in ('0', '1'):
        raise ValueError('Invalid YSF auto-link switch')
    result['AUTOLINK_USER'] = 'Y' if result['AUTOLINK'] == '1' else 'N'
    result['MODAUTO'] = defines.get('YSF_AUTOLINK_MODULE', "'C'").strip("'")
    if not re.fullmatch('[A-Z]', result['MODAUTO']):
        raise ValueError('Invalid YSF module')
    if 'TIMEZONE' in result:
        if not pathlib.Path('/usr/share/zoneinfo', result['TIMEZONE']).is_file() or '..' in result['TIMEZONE']:
            raise ValueError('Invalid timezone')
        result.update(TIMEZONE_USE_SYSTEM='0', FINAL_DISPLAY=result['TIMEZONE'])
    dest.mkdir(parents=True, exist_ok=True)
    for name, content in files.items():
        target = dest / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)
    (dest / 'settings.sh').write_text(''.join(k + '=' + shlex.quote(v) + '\n' for k, v in result.items()))


if __name__ == '__main__':
    try:
        load(*sys.argv[1:])
    except (ValueError, OSError, tarfile.TarError, UnicodeError) as exc:
        sys.exit('Cannot load backup: ' + str(exc))
