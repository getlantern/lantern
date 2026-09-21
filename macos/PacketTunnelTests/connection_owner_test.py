"""Exercise the production Swift callback against sockets owned by another process.

Requires the macOS Liblantern framework. Does not install or start a VPN.
"""

from contextlib import ExitStack
import ctypes
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
FRAMEWORK = Path(os.environ.get(
    "LANTERN_MACOS_FRAMEWORK_DIR",
    ROOT / "macos/Frameworks/Liblantern.xcframework/macos-arm64_x86_64",
))


class ConnectionOwnerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="lantern-connection-owner-")
        cls.addClassCleanup(temporary.cleanup)
        directory = Path(temporary.name)
        cls.probe = directory / "connection-owner"
        sources = [
            "macos/PacketTunnel/SingBox/ExtensionPlatformInterface.swift",
            "macos/PacketTunnel/SingBox/ExtensionProvider.swift",
            "macos/PacketTunnel/SingBox/Extension+RunBlocking.swift",
            "macos/Shared/Logger.swift",
            "macos/Shared/FilePath.swift",
            "macos/PacketTunnelTests/ConnectionOwnerProbe.swift",
        ]
        subprocess.run([
            "xcrun", "swiftc", "-swift-version", "5",
            "-module-cache-path", str(directory / "modules"),
            "-F", str(FRAMEWORK), "-framework", "Liblantern", "-lc++",
            *(str(ROOT / source) for source in sources), "-o", str(cls.probe),
        ], check=True, timeout=180)

        process_path = ctypes.create_string_buffer(4096)
        libproc = ctypes.CDLL("/usr/lib/libproc.dylib")
        if libproc.proc_pidpath(os.getpid(), process_path, len(process_path)) <= 0:
            raise RuntimeError("Cannot determine the socket owner's executable path")
        cls.expected_path = process_path.value.decode()

    def lookup(self, protocol, source, destination):
        return subprocess.run([
            str(self.probe), str(protocol), source[0], str(source[1]),
            destination[0], str(destination[1]),
        ], capture_output=True, text=True, timeout=15)

    def assert_owner(self, result):
        self.assertEqual(result.returncode, 0, result.stderr)
        owner = json.loads(result.stdout)
        self.assertEqual(owner["userId"], os.getuid())
        self.assertEqual(owner["processPath"], self.expected_path)

    def test_connected_tcp_and_udp(self):
        for family, host in [(socket.AF_INET, "127.0.0.1"), (socket.AF_INET6, "::1")]:
            for kind, protocol in [(socket.SOCK_STREAM, socket.IPPROTO_TCP),
                                   (socket.SOCK_DGRAM, socket.IPPROTO_UDP)]:
                with self.subTest(family=family, protocol=protocol), ExitStack() as sockets:
                    server = sockets.enter_context(socket.socket(family, kind))
                    client = sockets.enter_context(socket.socket(family, kind))
                    server.settimeout(5)
                    client.settimeout(5)
                    server.bind((host, 0))
                    if kind == socket.SOCK_STREAM:
                        server.listen()
                    client.connect(server.getsockname())
                    if kind == socket.SOCK_STREAM:
                        accepted, _ = server.accept()
                        sockets.enter_context(accepted)
                    else:
                        accepted = server
                    accepted.settimeout(5)
                    client.send(b"owner lookup")
                    self.assertEqual(accepted.recv(64), b"owner lookup")
                    self.assert_owner(self.lookup(protocol, client.getsockname(), server.getsockname()))

    def test_unconnected_udp(self):
        for family, host, wildcard in [(socket.AF_INET, "127.0.0.1", "0.0.0.0"),
                                       (socket.AF_INET6, "::1", "::")]:
            with self.subTest(family=family), ExitStack() as sockets:
                server = sockets.enter_context(socket.socket(family, socket.SOCK_DGRAM))
                client = sockets.enter_context(socket.socket(family, socket.SOCK_DGRAM))
                server.settimeout(5)
                client.settimeout(5)
                server.bind((host, 0))
                client.bind((wildcard, 0))
                client.sendto(b"owner lookup", server.getsockname())
                data, source = server.recvfrom(64)
                self.assertEqual(data, b"owner lookup")
                self.assert_owner(self.lookup(socket.IPPROTO_UDP, source, server.getsockname()))

    def test_dual_stack_udp(self):
        for family, host in [(socket.AF_INET, "127.0.0.1"), (socket.AF_INET6, "::1")]:
            with self.subTest(family=family), ExitStack() as sockets:
                server = sockets.enter_context(socket.socket(family, socket.SOCK_DGRAM))
                client = sockets.enter_context(socket.socket(socket.AF_INET6, socket.SOCK_DGRAM))
                server.settimeout(5)
                client.settimeout(5)
                server.bind((host, 0))
                client.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
                client.bind(("::", 0))
                destination_host = f"::ffff:{host}" if family == socket.AF_INET else host
                client.sendto(b"owner lookup", (destination_host, server.getsockname()[1]))
                data, source = server.recvfrom(64)
                self.assertEqual(data, b"owner lookup")
                self.assert_owner(self.lookup(socket.IPPROTO_UDP, source, server.getsockname()))

    def test_lookup_errors_reach_the_caller(self):
        cases = [
            (1, ("127.0.0.1", 1234), ("127.0.0.1", 443), "unknown protocol"),
            (6, ("invalid", 1234), ("127.0.0.1", 443), "parse source"),
            (6, ("127.0.0.1", -1), ("127.0.0.1", 443), "invalid port"),
            (6, ("127.0.0.1", 65536), ("127.0.0.1", 443), "invalid port"),
            (6, ("127.0.0.1", 1234), ("invalid", 443), "parse destination"),
            (6, ("127.0.0.1", 1234), ("127.0.0.1", 65536), "invalid port"),
        ]
        for protocol, source, destination, message in cases:
            with self.subTest(source=source, destination=destination, protocol=protocol):
                result = self.lookup(protocol, source, destination)
                self.assertEqual(result.returncode, 1)
                self.assertIn(message, result.stderr)


if __name__ == "__main__":
    unittest.main()
