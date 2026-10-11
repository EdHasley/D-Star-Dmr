#!/usr/bin/env python3
"""Exercise real software codec through XLXD's AMBED UDP messages."""
import pathlib
import socket
import struct
import subprocess
import time
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class ProtocolTests(unittest.TestCase):
    def setUp(self):
        self.sockets = []
        self.port = None
        for port in range(24000, 26000, 3):
            probes = []
            try:
                for ip, p in [('127.0.0.1', port), ('127.0.0.1', port+1), ('127.0.0.2', port+1)]:
                    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                    probes.append(s)
                    s.bind((ip, p))
                self.port = port
                break
            except OSError:
                pass
            finally:
                for s in probes:
                    s.close()
        self.assertIsNotNone(self.port)
        self.proc = subprocess.Popen([str(ROOT/'software-ambed'), '--peer', '127.0.0.2', '--port', str(self.port), '--channels', '1', '--idle', '1'], stdout=subprocess.DEVNULL)
        self.control = self.sock('127.0.0.2')
        for _ in range(50):
            try:
                self.control.sendto(b'AMBEDPINGXLX999  ', ('127.0.0.1', self.port))
                if self.control.recv(128) == b'AMBEDPONG':
                    break
            except socket.timeout:
                self.assertIsNone(self.proc.poll())
        else:
            self.fail('service did not start')

    def tearDown(self):
        self.proc.terminate()
        self.proc.wait(timeout=5)
        for s in self.sockets:
            s.close()

    def sock(self, ip, port=0):
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.bind((ip, port))
        s.settimeout(0.1)
        self.sockets.append(s)
        return s

    def request(self, data, client=None):
        client = client or self.control
        client.sendto(data, ('127.0.0.1', self.port))
        return client.recv(128)

    def open(self, source, destination):
        response = self.request(b'AMBEDOSXLX999  '+bytes([source, destination]))
        self.assertEqual(response[:8], b'AMBEDSTD')
        sid, port = struct.unpack('=HH', response[8:12])
        self.assertEqual(response[12:], bytes([source, destination]))
        return sid, port

    def test_both_directions_and_capacity(self):
        data_sock = self.sock('127.0.0.2', self.port+1)
        for source, destination in [(1, 2), (2, 1)]:
            sid, port = self.open(source, destination)
            self.assertEqual(self.request(b'AMBEDOSXLX999  '+bytes([source, destination])), b'AMBEDBUSY')
            for pid in range(30):
                data_sock.sendto(bytes([source, pid])+bytes(9), ('127.0.0.1', port))
                response = data_sock.recv(128)
                self.assertEqual(len(response), 11)
                self.assertEqual(response[:2], bytes([destination, pid]))
            self.control.sendto(b'AMBEDCS'+struct.pack('=H', sid), ('127.0.0.1', self.port))
            # A controller keepalive acts as a barrier after close.
            self.assertEqual(self.request(b'AMBEDPINGXLX999  '), b'AMBEDPONG')

    def test_bad_requests_peer_and_close_owner(self):
        for bad in [b'AMBEDOS', b'AMBEDCS', b'AMBEDPING', b'AMBEDOSXLX999  '+bytes([1, 1])]:
            if len(bad) == 17:
                self.assertEqual(self.request(bad), b'AMBEDBUSY')
            else:
                with self.assertRaises(socket.timeout):
                    self.request(bad)
        foreign = self.sock('127.0.0.3')
        with self.assertRaises(socket.timeout):
            self.request(b'AMBEDPINGXLX999  ', foreign)
        sid, _ = self.open(1, 2)
        other = self.sock('127.0.0.2')
        other.sendto(b'AMBEDCS'+struct.pack('=H', sid), ('127.0.0.1', self.port))
        self.assertEqual(self.request(b'AMBEDPINGXLX999  ', other), b'AMBEDPONG')
        self.assertEqual(self.request(b'AMBEDOSXLX999  '+bytes([1, 2])), b'AMBEDBUSY')

    def test_idle_releases_capacity(self):
        self.open(1, 2)
        time.sleep(1.2)
        self.open(2, 1)


if __name__ == '__main__':
    unittest.main()
