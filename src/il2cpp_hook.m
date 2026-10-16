// StandRework iOS dylib — il2cpp-level hook (Dobby).
//
// Hooks the obfuscated TcpClient connect:
//     GIFELELIEGF::AOFELLMANAO(GIFELELIEGF* __this, MILECCIILMJ* config, MethodInfo*)
// at UnityFramework + SR_OFF_CONNECT_MAIN (0x2E3F7E8 for Standoff 2 0.22.0 iOS).
//
// Before the original runs it rewrites the connect config exactly like the
// 0.22.0 Android lib:
//     config+0x10  -> host string  = SR_SERVER_IP
//     config+0x28  -> useTLS       = false
// Everything else (host2, ports) is only logged, never touched — the 0.26.0 lib
// patches those too, but clobbering them broke the game on 0.22.0.

#include "config.h"

// Dobby patching of signed code is fatal on a non-jailbroken device
// ("CODESIGNING / Invalid Page"), so this whole file compiles to nothing
// unless the flag is explicitly enabled.
#if SR_USE_IL2CPP_HOOKS

#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#include <dlfcn.h>
#include <pthread.h>
#include <unistd.h>
#include <string.h>
#include "dobby.h"

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

static void sr_log_string(const char *label, void *s) {
    if (!s) {
        NSLog(@"[SR]   %s = <null>", label);
        return;
    }
    int len = *(int *)((uintptr_t)s + 0x10);
    if (len < 0 || len > 512) {
        NSLog(@"[SR]   %s = <bad length %d>", label, len);
        return;
    }
    const uint16_t *ch = (const uint16_t *)((uintptr_t)s + 0x14);
    char buf[520];
    int n = 0;
    for (int i = 0; i < len && n < 511; i++) {
        uint16_t c = ch[i];
        buf[n++] = (c >= 32 && c < 127) ? (char)c : '.';
    }
    buf[n] = 0;
    NSLog(@"[SR]   %s = \"%s\"", label, buf);
}

static void *sr_hook_connect(void *self, void *config, void *method) {
    if (!config || !orig_connect) {
        if (!orig_connect) NSLog(@"[SR] !! orig_connect is NULL, cannot forward");
        return orig_connect ? orig_connect(self, config, method) : NULL;
    }

    uintptr_t c = (uintptr_t)config;
    NSLog(@"[SR] CONNECT config=%p p1=%d p2=%d tls=%d i2c=%d i3=%d",
          config, *(int *)(c + OFF_PORT1), *(int *)(c + OFF_PORT2),
          *(bool *)(c + OFF_USETLS), *(int *)(c + 0x2C), *(int *)(c + 0x30));
    sr_log_string("host1", *(void **)(c + OFF_HOST1));
    sr_log_string("host2", *(void **)(c + OFF_HOST2));

    if (p_il2cpp_string_new) {
        void *s = p_il2cpp_string_new(SR_SERVER_IP);
        if (s) {
            *(void **)(c + OFF_HOST1) = s;
#if SR_PATCH_HOST2
            void *s2 = p_il2cpp_string_new(SR_SERVER_IP);
            if (s2) *(void **)(c + OFF_HOST2) = s2;
#endif
            NSLog(@"[SR] CONNECT host1 -> %s", SR_SERVER_IP);
        } else {
            NSLog(@"[SR] !! il2cpp_string_new returned null");
        }
    } else {
        NSLog(@"[SR] !! il2cpp_string_new not resolved");
    }

#if SR_PATCH_PORTS
    *(int *)(c + OFF_PORT1) = SR_GAME_PORT;
    *(int *)(c + OFF_PORT2) = SR_GAME_PORT;
    NSLog(@"[SR] CONNECT ports -> %d", SR_GAME_PORT);
#endif

    *(bool *)(c + OFF_USETLS) = false;
    NSLog(@"[SR] CONNECT tls -> off");

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

#endif  // SR_USE_IL2CPP_HOOKS
