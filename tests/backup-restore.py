#!/usr/bin/env python3
import base64
import importlib.util
import io
import pathlib
import subprocess
import tarfile
import tempfile

root = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('backup', root / 'templates/load-backup.py')
backup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backup)
with tempfile.TemporaryDirectory() as directory:
    base = pathlib.Path(directory)
    def archive(name, conf, extra=None):
        path = base / name
        entries = {'etc/reflector.conf': conf, 'source/main.h': (root / 'xlxd/src/main.h').read_text(), 'access/xlxd.whitelist': 'AF0WX\n'}
        entries.update(extra or {})
        with tarfile.open(path, 'w:gz') as tar:
            for key, value in entries.items():
                data = value.encode()
                member = tarfile.TarInfo('./' + key)
                member.size = len(data)
                tar.addfile(member, io.BytesIO(data))
        return path
    old = 'PROTOCOL_ID="XLXX80"\nEXTENDED_NAME="Ed\'s Reflector"\nCALL_HOME="N"\nTRANSCODER_ENABLED="N"\n'
    backup.load(archive('old.tar.gz', old), base / 'old')
    text = (base / 'old/settings.sh').read_text()
    assert 'XLXDOMAIN=' not in text
    assert 'ENABLE_DMRMMDVM_USER=' in text
    assert 'TRANSCODER_BACKEND=none' in text
    backup.load(archive('software.tar.gz', old + 'TRANSCODER_BACKEND=software\n'), base / 'software')
    assert 'TRANSCODER_BACKEND=software' in (base / 'software/settings.sh').read_text()
    backup.load(archive('hardware.tar.gz', old.replace('TRANSCODER_ENABLED="N"', 'TRANSCODER_ENABLED="Y"')), base / 'hardware')
    assert 'TRANSCODER_BACKEND=hardware' in (base / 'hardware/settings.sh').read_text()
    new = old + 'XLXDOMAIN=example.com\nEMAIL=ed@example.com\nCALLSIGN=AF0WX\nCOUNTRY=United\\ States\nTIMEZONE=America/Chicago\nCOMMENT=hello\nHEADER=Reflector\nFOOTER=Ed\nINSTALL_SSL=Y\nINSTALL_ECHO=N\n'
    new += 'COMMENT_B64="' + base64.b64encode(b"Ed's $club\nsecond line").decode() + '"\n'
    backup.load(archive('new.tar.gz', new), base / 'new')
    output = subprocess.check_output(['bash', '-c', 'source "$1"; printf "%s|%s|%s" "$XLXDOMAIN" "$COUNTRY" "$XRFDIGIT"', 'test', str(base / 'new/settings.sh')], text=True)
    assert output == 'example.com|United States|X80'
    assert (base / 'new/access/xlxd.whitelist').read_text() == 'AF0WX\n'
    for name, conf, extra in [('bad', old, {'../escape': 'x'}), ('invalid', old.replace('XLXX80', 'BAD'), {})]:
        try:
            backup.load(archive(name + '.tar.gz', conf, extra), base / name)
        except ValueError:
            pass
        else:
            raise AssertionError('Invalid backup accepted')
    # Backup text remains literal data even with shell substitutions.
    injected = old + 'COUNTRY="$(touch /tmp/reflector-backup-injection)"\n'
    backup.load(archive('literal.tar.gz', injected), base / 'literal')
    subprocess.run(['bash', '-c', 'source "$1"', 'test', str(base / 'literal/settings.sh')], check=True)
    assert not pathlib.Path('/tmp/reflector-backup-injection').exists()
print('Backup restore checks passed: old/new backups, access files, unsafe archive rejection, literal shell data.')

manager = (root / 'templates/reflector-manager.sh').read_text().split('need_root "$@"\n', 1)[1]
script = 'clear(){ :; }; yellow(){ :; }; access_control_menu(){ echo ACCESS_OK; }; backup_restore_menu(){ echo BACKUP_OK; };\n' + manager
output = subprocess.check_output(['bash', '-c', script], input='10\n11\nx\n', text=True)
assert 'ACCESS_OK' in output and 'BACKUP_OK' in output
assert '10. Access control' in output and '11. Backup / restore' in output
print('Manager choices 10 and 11 dispatch correctly.')

selector = (root / 'installer.sh').read_text().split('select_installation_backup() {', 1)[1].split('\nRESTORE_DIR=""', 1)[0]
selector = 'select_installation_backup() {' + selector
with tempfile.TemporaryDirectory() as directory:
    folder = pathlib.Path(directory)
    # Isolate the standard backup folder as well as the current and installer folders.
    selector = selector.replace('/var/backups/extended-name-reflector', directory)
    prefix = 'print_wrapped(){ echo "$1"; }; read_or_abort(){ read -r "$1"; }; XLXINS="$PWD";\n'
    suffix = '\nselect_installation_backup; printf "SELECTED=%s\\n" "$RESTORE_ARCHIVE"'
    script = prefix + selector + suffix
    output = subprocess.check_output(['bash', '-c', script], cwd=folder, input='1\n', text=True)
    assert 'No portable backups found' in output and 'SELECTED=\n' in output
    for name in ('reflector-backup-20261009-100000.tar.gz', 'reflector-backup-20261008-100000.tar.gz'):
        (folder / name).touch()
    output = subprocess.check_output(['bash', '-c', script], cwd=folder, input='99\n2\n', text=True)
    assert 'Invalid selection' in output
    assert 'SELECTED=' + str(folder / 'reflector-backup-20261009-100000.tar.gz') in output
    assert output.count('2. Install from backup:') == 1  # overlapping folders deduplicated
    output = subprocess.check_output(['bash', '-c', script], cwd=folder, input='3\n', text=True)
    assert 'SELECTED=' + str(folder / 'reflector-backup-20261008-100000.tar.gz') in output
print('Automatic backup selection passed: no backups, numbered choices, invalid input, duplicate folders.')
