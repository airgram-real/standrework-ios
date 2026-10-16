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
// These are only used when SR_USE_IL2CPP_HOOKS is enabled (needs Dobby).

#define SR_USE_IL2CPP_HOOKS 0

#define SR_OFF_NETWORKINGPEER_CONNECT            0x01A23D24UL
#define SR_OFF_NETWORKINGPEER_GETNAMESERVERADDR  0x01A22CACUL
#define SR_OFF_PHOTONASYNC_CONNECT               0x01F6A818UL
