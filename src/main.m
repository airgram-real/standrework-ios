// StandRework iOS dylib — redirects game traffic to your own server.
//
// Hooks (via fishhook, no external deps):
//   getaddrinfo() — known game hosts resolve to SR_SERVER_IP
//   connect()     — game/Photon ports are rewritten to SR_SERVER_IP:SR_GAME_PORT
//
// Everything is logged with the [SR] prefix (Console.app / idevicesyslog).

#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <string.h>
#include <stdlib.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include "fishhook.h"
#include "config.h"

#pragma mark - state

static int  (*orig_connect)(int, const struct sockaddr *, socklen_t) = NULL;
static int  (*orig_getaddrinfo)(const char *, const char *,
                                const struct addrinfo *, struct addrinfo **) = NULL;

static uint32_t g_server_addr_be = 0;   // SR_SERVER_IP in network byte order

#pragma mark - helpers

static BOOL sr_host_matches(const char *node) {
    if (!node) return NO;
    for (int i = 0; SR_REDIRECT_HOSTS[i]; i++) {
        if (strcasecmp(node, SR_REDIRECT_HOSTS[i]) == 0) return YES;
    }
    return NO;
}

static BOOL sr_is_photon_port(int port) {
    for (int i = 0; SR_PHOTON_PORTS[i]; i++) {
        if (SR_PHOTON_PORTS[i] == port) return YES;
    }
    return NO;
}

static BOOL sr_is_web_port(int port) {
    return port == SR_WEB_PORT || port == SR_WEB_PORT_2;
}

static void sr_ip_str(uint32_t addr_be, char *out, size_t n) {
    struct in_addr a;
    a.s_addr = addr_be;
    inet_ntop(AF_INET, &a, out, (socklen_t)n);
}

#pragma mark - getaddrinfo hook

static int sr_getaddrinfo(const char *node, const char *service,
                          const struct addrinfo *hints, struct addrinfo **res) {
    if (sr_host_matches(node)) {
        char ip[INET_ADDRSTRLEN];
        sr_ip_str(g_server_addr_be, ip, sizeof(ip));
        NSLog(@"[SR] getaddrinfo '%s' -> %s", node, ip);

        struct addrinfo *ai = calloc(1, sizeof(struct addrinfo));
        struct sockaddr_in *sin = calloc(1, sizeof(struct sockaddr_in));
        if (!ai || !sin) { free(ai); free(sin); return EAI_MEMORY; }

        sin->sin_family = AF_INET;
        sin->sin_addr.s_addr = g_server_addr_be;
        sin->sin_port = htons((uint16_t)SR_GAME_PORT);
        ai->ai_family = AF_INET;
        ai->ai_socktype = hints ? hints->ai_socktype : SOCK_STREAM;
        ai->ai_protocol = hints ? hints->ai_protocol : IPPROTO_TCP;
        ai->ai_addrlen = sizeof(struct sockaddr_in);
        ai->ai_addr = (struct sockaddr *)sin;
        *res = ai;
        return 0;
    }
    return orig_getaddrinfo(node, service, hints, res);
}

#pragma mark - connect hook

static int sr_connect(int fd, const struct sockaddr *addr, socklen_t len) {
    if (addr && addr->sa_family == AF_INET && len >= (socklen_t)sizeof(struct sockaddr_in)) {
        struct sockaddr_in sin;
        memcpy(&sin, addr, sizeof(sin));
        char ip[INET_ADDRSTRLEN];
        sr_ip_str(sin.sin_addr.s_addr, ip, sizeof(ip));
        int port = ntohs(sin.sin_port);

        BOOL to_our_ip = (sin.sin_addr.s_addr == g_server_addr_be);

        if (!to_our_ip && sr_is_photon_port(port)) {
            NSLog(@"[SR] connect %s:%d -> redirect %s:%d", ip, port, SR_SERVER_IP, SR_GAME_PORT);
            sin.sin_addr.s_addr = g_server_addr_be;
            sin.sin_port = htons((uint16_t)SR_GAME_PORT);
            return orig_connect(fd, (struct sockaddr *)&sin, sizeof(sin));
        }

        if (to_our_ip && !sr_is_web_port(port) && port != SR_GAME_PORT) {
            NSLog(@"[SR] connect %s:%d -> port fix %s:%d", ip, port, SR_SERVER_IP, SR_GAME_PORT);
            sin.sin_port = htons((uint16_t)SR_GAME_PORT);
            return orig_connect(fd, (struct sockaddr *)&sin, sizeof(sin));
        }

        NSLog(@"[SR] connect %s:%d (passthrough)", ip, port);
    }
    return orig_connect(fd, addr, len);
}

#pragma mark - init

#if SR_USE_IL2CPP_HOOKS
// Placeholder for the il2cpp-level hooks (Dobby). Offsets are in config.h.
// Enabled only when the Dobby submodule is present in CI.
extern void sr_install_il2cpp_hooks(void);
#endif

__attribute__((constructor))
static void sr_init(void) {
    struct in_addr a;
    inet_pton(AF_INET, SR_SERVER_IP, &a);
    g_server_addr_be = a.s_addr;

    NSLog(@"[SR] dylib loaded, target %s game-port %d", SR_SERVER_IP, SR_GAME_PORT);

    struct rebinding binds[] = {
        {"connect",    (void *)sr_connect,    (void **)&orig_connect},
        {"getaddrinfo",(void *)sr_getaddrinfo,(void **)&orig_getaddrinfo},
    };
    int rc = rebind_symbols(binds, sizeof(binds) / sizeof(binds[0]));
    NSLog(@"[SR] fishhook rebind rc=%d (connect=%p getaddrinfo=%p)",
          rc, (void *)orig_connect, (void *)orig_getaddrinfo);

#if SR_USE_IL2CPP_HOOKS
    sr_install_il2cpp_hooks();
#endif
}
