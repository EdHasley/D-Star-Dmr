#!/usr/bin/env python3
"""Build and run isolated protocol selections; never installs services."""
import socket
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='xlxd-smoke-') as td:
    work = Path(td)
    shutil.copytree(ROOT / 'xlxd/src', work / 'src', ignore=shutil.ignore_patterns('*.o', 'xlxd'))
    shutil.copytree(ROOT / 'xlxd/config', work / 'config')
    header = work / 'src/main.h'
    original = header.read_text()
    original = original.replace('#define RUN_AS_DAEMON', '// RUN_AS_DAEMON disabled for smoke test')
    original = original.replace('/xlxd/', str(work / 'config') + '/').replace('/var/log/', str(work) + '/')
    for key in ('DMRIDDB_USE_RLX_SERVER', 'YSFNODEDB_USE_RLX_SERVER'):
        original = re.sub(r'(#define\s+' + key + r'\s+)1', r'\g<1>0', original)
    bridge = None
    for variant, enabled in [('dmr-only', {'DMRMMDVM'}), ('dstar-dmr', {'DEXTRA', 'DPLUS', 'DCS', 'DMRMMDVM'})]:
        selected = re.sub(r'(#define\s+ENABLE_(\w+)\s+)[01]', lambda m: m[1] + ('1' if m[2] in enabled else '0'), original)
        # Bind nonstandard test ports; verify selections by sockets owned by this PID.
        ports = {'DEXTRA': 33001, 'DPLUS': 33002, 'DCS': 33003, 'DMRMMDVM': 33004}
        for protocol, port in ports.items():
            selected = re.sub(r'(#define\s+' + protocol + r'_PORT\s+)\d+', lambda m: m[1] + str(port), selected)
        header.write_text(selected)
        with (work / 'build.log').open('w') as log:
            subprocess.run(['make', '-j4'], cwd=work / 'src', stdout=log, stderr=log, check=True)
        if variant == 'dstar-dmr':
            bridge = subprocess.Popen([str(ROOT / 'software-ambed/software-ambed'), '--peer', '127.0.0.2'], stdout=subprocess.DEVNULL)
        with (work / 'run.log').open('w') as log:
            proc = subprocess.Popen([str(work / 'src/xlxd'), 'XLXX80', '127.0.0.2', '127.0.0.1'], stdout=log, stderr=log)
            try:
                expected = {ports[p] for p in enabled}
                for port in expected:
                    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
                        probe.bind(('127.0.0.2', port))
                actual = set()
                for _ in range(100):
                    if proc.poll() is not None:
                        raise RuntimeError((work / 'run.log').read_text())
                    actual = set()
                    for port in {33001,33002,33003,33004,10002,8880,62030,42000,21110,12345,12346,40000,30001,20001,30051}:
                        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
                            try:
                                probe.bind(('127.0.0.2', port))
                            except OSError as error:
                                if error.errno != 98:
                                    raise
                                actual.add(port)
                    if expected <= actual:
                        break
                    time.sleep(0.1)
                # XLXD also opens an ephemeral transcoder socket, which is not a protocol listener.
                protocol_ports = actual & {33001,33002,33003,33004,10002,8880,62030,42000,21110,12345,12346,40000,30001,20001,30051}
                assert protocol_ports == expected, (variant, expected, actual)
                if bridge is not None:
                    for _ in range(70):
                        if 'Transcoder connected at' in (work / 'run.log').read_text():
                            break
                        time.sleep(0.1)
                    else:
                        raise AssertionError('XLXD did not connect to software AMBED: ' + (work / 'run.log').read_text())
                    print('Real XLXD connects to local software AMBED', flush=True)
                print(f'{variant}: expected protocol listeners verified {sorted(expected)}', flush=True)
            finally:
                proc.terminate()
                proc.wait(timeout=10)
                if bridge is not None:
                    bridge.terminate()
                    bridge.wait(timeout=10)
