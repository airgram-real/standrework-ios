// StandRework iOS dylib — il2cpp-level hook (Dobby).
//
// Hooks the obfuscated TcpClient connect:
//     GIFELELIEGF::AOFELLMANAO(GIFELELIEGF* __this, MILECCIILMJ* config, MethodInfo*)
// at UnityFramework + SR_OFF_CONNECT_MAIN (0x2E3F7E8 for Standoff 2 0.22.0 iOS).
//
// Before the original runs it rewrites the connection config the same way the
// Android lib does:
//     config+0x10 / +0x18  -> host strings  = SR_SERVER_IP
//     config+0x20 / +0x24  -> ports         = SR_GAME_PORT
//     config+0x28          -> useTLS        = false

#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#include <dlfcn.h>
#include <pthread.h>
#include <unistd.h>
#include <string.h>
#include "dobby.h"
#include "config.h"

#define OFF_HOST1  0x10
#define OFF_HOST2  0x18
#define OFF_PORT1  0x20
#define OFF_PORT2  0x24
#define OFF_USETLS 0x28

typedef void *(*connect_fn)(void *__this, void *config, void *method);
static connect_fn orig_connect = NULL;

static void *(*p_il2cpp_string_new)(const char *) = NULL;

static uintptr_t sr_find_image(const char *needle) {
    uint32_t n = _dyld_image_count();
    for (uint32_t i = 0; i < n; i++) {
        const char *nm = _dyld_get_image_name(i);
        if (nm && strstr(nm, needle)) {
            return (uintptr_t)_dyld_get_image_header(i);
        }
    }
    return 0;
}

static void *sr_hook_connect(void *self, void *config, void *method) {
    if (config) {
        uintptr_t c = (uintptr_t)config;
        NSLog(@"[SR] CONNECT config=%p host1=%p host2=%p p1=%d p2=%d tls=%d",
              config, *(void **)(c + OFF_HOST1), *(void **)(c + OFF_HOST2),
              *(int *)(c + OFF_PORT1), *(int *)(c + OFF_PORT2), *(bool *)(c + OFF_USETLS));

        if (p_il2cpp_string_new) {
            *(void **)(c + OFF_HOST1) = p_il2cpp_string_new(SR_SERVER_IP);
            *(void **)(c + OFF_HOST2) = p_il2cpp_string_new(SR_SERVER_IP);
        } else {
            NSLog(@"[SR] !! il2cpp_string_new not resolved, host left as is");
        }
        *(int *)(c + OFF_PORT1) = SR_GAME_PORT;
        *(int *)(c + OFF_PORT2) = SR_GAME_PORT;
        *(bool *)(c + OFF_USETLS) = false;

        NSLog(@"[SR] CONNECT patched -> %s:%d tls=off", SR_SERVER_IP, SR_GAME_PORT);
    }
    return orig_connect(self, config, method);
}

static void *sr_worker(void *arg) {
    uintptr_t base = 0;
    for (int i = 0; i < 6000 && !base; i++) {     // up to ~60 s
        base = sr_find_image("UnityFramework");
        if (!base) usleep(10000);
    }
    if (!base) {
        NSLog(@"[SR] UnityFramework image not found");
        return NULL;
    }
    NSLog(@"[SR] UnityFramework base = %p", (void *)base);

    p_il2cpp_string_new = (void *(*)(const char *))dlsym(RTLD_DEFAULT, "il2cpp_string_new");
    if (!p_il2cpp_string_new) {
        p_il2cpp_string_new = (void *(*)(const char *))dlsym(RTLD_DEFAULT, "_il2cpp_string_new");
    }
    NSLog(@"[SR] il2cpp_string_new = %p", (void *)p_il2cpp_string_new);

    void *target = (void *)(base + SR_OFF_CONNECT_MAIN);
    uint32_t first = *(uint32_t *)target;
    NSLog(@"[SR] hook target %p first instr = 0x%08X", target, first);
    if (first == 0) {
        NSLog(@"[SR] !! target looks empty, refusing to hook");
        return NULL;
    }

    int rc = DobbyHook(target, (void *)sr_hook_connect, (void **)&orig_connect);
    NSLog(@"[SR] DobbyHook rc=%d orig=%p", rc, (void *)orig_connect);
    return NULL;
}

void sr_install_il2cpp_hooks(void) {
    pthread_t t;
    pthread_create(&t, NULL, sr_worker, NULL);
    pthread_detach(t);
}
