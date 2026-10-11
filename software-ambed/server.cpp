// SPDX-License-Identifier: GPL-3.0-or-later
// AF0WX standalone software transcoder for XLXD's AMBED wire interface.
#include <arpa/inet.h>
#include <sys/socket.h>
#include <poll.h>
#include <unistd.h>
#include <signal.h>
#include <chrono>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <map>
#include <memory>
#include <stdexcept>
#include <vector>
#include "mbe/mbevocoder.h"

using Clock = std::chrono::steady_clock;
static volatile sig_atomic_t stopping = 0;
static void stop(int) { stopping = 1; }
struct Socket {
    int fd;
    Socket(const std::string& ip, unsigned port) : fd(socket(AF_INET, SOCK_DGRAM, 0)) {
        sockaddr_in a = {}; a.sin_family = AF_INET; a.sin_port = htons(port);
        inet_pton(AF_INET, ip.c_str(), &a.sin_addr);
        if (fd < 0 || bind(fd, reinterpret_cast<sockaddr*>(&a), sizeof(a)) != 0) {
            if (fd >= 0) close(fd);
            throw std::runtime_error("Cannot bind " + ip + ":" + std::to_string(port));
        }
    }
    ~Socket() { close(fd); }
    Socket(const Socket&) = delete;
    Socket& operator=(const Socket&) = delete;
};
struct Stream {
    Socket socket;
    sockaddr_in owner;
    uint8_t input, output;
    Clock::time_point activity;
    MBEVocoder decoder, encoder;
    Stream(const std::string& ip, unsigned port, sockaddr_in peer, uint8_t in, uint8_t out)
        : socket(ip, port), owner(peer), input(in), output(out), activity(Clock::now()) {}
};
static bool same_owner(const sockaddr_in& a, const sockaddr_in& b) {
    return a.sin_addr.s_addr == b.sin_addr.s_addr && a.sin_port == b.sin_port;
}
static void send_packet(int fd, const sockaddr_in& peer, const void* data, size_t size) {
    if (sendto(fd, data, size, 0, reinterpret_cast<const sockaddr*>(&peer), sizeof(peer)) < 0)
        std::cerr << "UDP send failed\n";
}
static bool tag(const uint8_t* data, ssize_t n, const char* value, size_t length, size_t size) {
    return n == static_cast<ssize_t>(size) && std::memcmp(data, value, length) == 0;
}
static unsigned number(const char* text, unsigned min, unsigned max) {
    char* end; unsigned long value = std::strtoul(text, &end, 10);
    if (!*text || *end || value < min || value > max) throw std::runtime_error("Invalid numeric option");
    return value;
}
int main(int argc, char** argv) {
    try {
        std::string listen = "127.0.0.1", peer_ip;
        unsigned port = 10100, channels = 4, idle = 10;
        for (int i = 1; i < argc; ++i) {
            std::string key = argv[i];
            if (key == "--help") {
                std::cout << "software-ambed --peer XLXD_LISTEN_IP [--listen 127.0.0.1] [--port 10100] [--channels 4] [--idle 10]\n";
                return 0;
            }
            if (++i >= argc) throw std::runtime_error("Missing option value");
            if (key == "--listen") listen = argv[i];
            else if (key == "--peer") peer_ip = argv[i];
            else if (key == "--port") port = number(argv[i], 1024, 65534);
            else if (key == "--channels") channels = number(argv[i], 1, 26);
            else if (key == "--idle") idle = number(argv[i], 1, 3600);
            else throw std::runtime_error("Unknown option: " + key);
        }
        in_addr allowed, local;
        if (inet_pton(AF_INET, peer_ip.c_str(), &allowed) != 1 ||
            inet_pton(AF_INET, listen.c_str(), &local) != 1 ||
            (ntohl(local.s_addr) >> 24) != 127 || port + channels > 65535)
            throw std::runtime_error("Set --peer to XLXD's IPv4 listen address; --listen must be loopback; check port range");
        Socket controller(listen, port);
        std::map<unsigned, std::unique_ptr<Stream>> streams;
        signal(SIGINT, stop); signal(SIGTERM, stop);
        std::cout << "Experimental software AMBED at " << listen << ':' << port
                  << ", allowed XLXD peer " << peer_ip << ", capacity " << channels << std::endl;
        while (!stopping) {
            std::vector<pollfd> fds(1, {controller.fd, POLLIN, 0});
            std::vector<unsigned> ids;
            for (auto& entry : streams) {
                fds.push_back({entry.second->socket.fd, POLLIN, 0}); ids.push_back(entry.first);
            }
            if (poll(fds.data(), fds.size(), 20) < 0) continue;
            // Data first: controller close/open can invalidate the poll snapshot.
            for (size_t i = 1; i < fds.size(); ++i) {
                if (!(fds[i].revents & POLLIN)) continue;
                Stream& s = *streams.at(ids[i-1]);
                uint8_t data[64] = {}; sockaddr_in sender = {}; socklen_t len = sizeof(sender);
                ssize_t n = recvfrom(s.socket.fd, data, sizeof(data), 0, reinterpret_cast<sockaddr*>(&sender), &len);
                if (n != 11 || sender.sin_addr.s_addr != s.owner.sin_addr.s_addr ||
                    ntohs(sender.sin_port) != port + ids[i-1] || data[0] != s.input) continue;
                int16_t pcm[160] = {};
                uint8_t encoded[9] = {};
                if (s.input == 1) s.decoder.decode_2400x1200(pcm, data + 2);
                else s.decoder.decode_2450x1150(pcm, data + 2);
                if (s.output == 1) s.encoder.encode_2400x1200(pcm, encoded);
                else s.encoder.encode_2450x1150(pcm, encoded);
                data[0] = s.output; std::memcpy(data + 2, encoded, 9);
                send_packet(s.socket.fd, sender, data, 11);
                s.activity = Clock::now();
            }
            if (fds[0].revents & POLLIN) {
                uint8_t data[128] = {}; sockaddr_in sender = {}; socklen_t len = sizeof(sender);
                ssize_t n = recvfrom(controller.fd, data, sizeof(data), 0, reinterpret_cast<sockaddr*>(&sender), &len);
                if (sender.sin_addr.s_addr == allowed.s_addr) {
                    if (tag(data, n, "AMBEDPING", 9, 17)) send_packet(controller.fd, sender, "AMBEDPONG", 9);
                    else if (tag(data, n, "AMBEDOS", 7, 17)) {
                        unsigned id = 1;
                        while (id <= channels && streams.count(id)) ++id;
                        bool valid = (data[15] == 1 && data[16] == 2) || (data[15] == 2 && data[16] == 1);
                        if (valid && id <= channels) {
                            try {
                                streams.emplace(id, std::unique_ptr<Stream>(new Stream(listen, port+id, sender, data[15], data[16])));
                                uint8_t reply[14] = {'A','M','B','E','D','S','T','D'};
                                // Existing XLXD/AMBED uses native-endian uint16 fields.
                                uint16_t sid = id, sport = port+id;
                                std::memcpy(reply+8, &sid, 2); std::memcpy(reply+10, &sport, 2);
                                reply[12] = data[15]; reply[13] = data[16];
                                send_packet(controller.fd, sender, reply, sizeof(reply));
                            } catch (const std::exception& e) {
                                std::cerr << e.what() << '\n';
                                send_packet(controller.fd, sender, "AMBEDBUSY", 9);
                            }
                        } else send_packet(controller.fd, sender, "AMBEDBUSY", 9);
                    } else if (tag(data, n, "AMBEDCS", 7, 9)) {
                        uint16_t id; std::memcpy(&id, data+7, 2);
                        auto found = streams.find(id);
                        if (found != streams.end() && same_owner(sender, found->second->owner)) streams.erase(found);
                    }
                }
            }
            for (auto it = streams.begin(); it != streams.end();) {
                if (Clock::now() - it->second->activity > std::chrono::seconds(idle)) it = streams.erase(it);
                else ++it;
            }
        }
    } catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
}
