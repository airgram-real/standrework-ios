// StandRework iOS dylib — configuration
#pragma once

// ---- Server ----------------------------------------------------------------
static const char *SR_SERVER_IP   = "84.21.173.237";  // your server
static const int   SR_GAME_PORT   = 2222;             // game protocol port (open on server)
static const int   SR_WEB_PORT    = 443;              // leave HTTP(S) ports alone
static const int   SR_WEB_PORT_2  = 80;

// ---- Hosts that must be redirected to SR_SERVER_IP -------------------------
static const char *SR_REDIRECT_HOSTS[] = {
    "fra02.bolt.bolt-api.com",
    "fra01.staging.boltgaming.io",
    "fra02.staging.boltgaming.io",
    "server1.boltgaming.io",
    "ns.exitgames.com",
    NULL
};

// ---- Photon ports (rewritten to SR_GAME_PORT) ------------------------------
static const int SR_PHOTON_PORTS[] = {
    5055, 5056, 5057, 5058, 5059, 5060, 5061, 5062, 5063,
    27000, 27001, 27002, 9090, 9091,
    0
};

// ---- il2cpp offsets for Standoff 2 0.22.0 iOS (UnityFramework, arm64) ------
// From Il2CppDumper run on [AP] Standoff 2 (0.22.0).ipa
// (CodeRegistration 0x46E9B50, MetadataRegistration 0x47CE860)
//
//   Axlebolt.Standoff.Photon.PhotonAsync$$Connect(masterServerAddress, port, appId, gameVersion)
//        0x01F6A818   static
//   Axlebolt.Standoff.Photon.AsyncConnect$$Connect(__this, masterServerAddress, port, appId, gameVersion)
//        0x01F64214
//   NetworkingPeer$$GetNameServerAddress()          0x01A22CAC
//   NetworkingPeer$$Connect(__this, serverAddress, type)   0x01A23D24
//   NetworkingPeer$$ConnectToNameServer()           0x01A24A40
//   NetworkingPeer$$ConnectToRegionMaster(region)   0x01A24C64
//
//   NetworkingPeer field offsets: AppId 0xE8, MasterServerAddress 0x110,
//                                 GameServerAddress 0x118, Server 0x120
//
// ---------------------------------------------------------------------------
// MAIN HOOK:  GIFELELIEGF::AOFELLMANAO(__this, MILECCIILMJ* config, method)
//             returns Task   (obfuscated TcpClient connect)
//
// MILECCIILMJ layout (dump.cs, TypeDefIndex 14035) — identical to what the
// Android lib patches:
//     0x10 string host1      0x18 string host2
//     0x20 int port1         0x24 int port2
//     0x28 bool useTLS       0x2C int   0x30 int
//
// The Android lib does: *(void**)(config+0x10) = "IP"; *(bool*)(config+0x28) = false.

// Dobby inline hooks are IMPOSSIBLE here: patching code in a signed Mach-O makes
// iOS kill the app ("CODESIGNING / Invalid Page", confirmed by a crash report).
// fishhook only rewrites __DATA pointers, which the kernel does not validate.
#define SR_USE_IL2CPP_HOOKS 0     // Dobby — DO NOT enable on non-jailbroken iOS
#define SR_SOCKET_REDIRECT  1     // getaddrinfo + connect rewriting (fishhook, safe)

// What to rewrite in the connect config.
// The 0.22.0 lib patches ONLY host1 (+0x10) and useTLS (+0x28).
// Extra fields below are from the 0.26.0 lib — they clobber values the game may
// still need, so they are off by default.
#define SR_PATCH_HOST2      0     // +0x18
#define SR_PATCH_PORTS      0     // +0x20 / +0x24

#define SR_OFF_CONNECT_MAIN                      0x2E3F7E8UL

// Secondary offsets (Photon) — kept for reference / future hooks
#define SR_OFF_NETWORKINGPEER_CONNECT            0x01A23D24UL
#define SR_OFF_NETWORKINGPEER_GETNAMESERVERADDR  0x01A22CACUL
#define SR_OFF_PHOTONASYNC_CONNECT               0x01F6A818UL
