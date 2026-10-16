# StandRework — iOS dylib (Standoff 2 0.22.0)

Dylib, который в рантайме уводит трафик игры на свой сервер. Собирается в GitHub Actions
(macOS-раннер с Xcode), потому что для iOS-дайлибы нужен iPhoneOS SDK.

## Что делает

Перехватывает два системных вызова (через [fishhook](https://github.com/facebook/fishhook)):

| Хук | Поведение |
|---|---|
| `getaddrinfo()` | хосты из `SR_REDIRECT_HOSTS` резолвятся в `SR_SERVER_IP` |
| `connect()` | порты Photon (5055–5063, 27000–27002, 9090/9091) переписываются на `SR_SERVER_IP:SR_GAME_PORT`; соединения на наш IP с «неправильным» портом получают порт 2222. Порты 80/443 не трогаются |

Всё пишется в лог с префиксом `[SR]` — смотреть в Console.app или через `idevicesyslog`.

## Настройки

Всё в `src/config.h`:

```c
static const char *SR_SERVER_IP = "84.21.173.237";
static const int   SR_GAME_PORT = 2222;
static const char *SR_REDIRECT_HOSTS[] = { "fra02.bolt.bolt-api.com", ... };
static const int   SR_PHOTON_PORTS[]   = { 5055, 5056, ..., 27000, ... };
```

## Сборка через GitHub Actions

Репозиторий: **https://github.com/airgram-real/standrework-ios** (уже создан, пустой).
Папка `E:\libing\ios` уже инициализирована как git-репозиторий с remote `origin` —
осталось только запушить:

```bash
cd E:/libing/ios
git push -u origin main
```

При первом пуше Git Credential Manager попросит залогиниться в GitHub
(нужен аккаунт, у которого есть права на `airgram-real/standrework-ios`).

Если нужно пересоздать с нуля:

```bash
cd E:/libing/ios
rm -rf .git
git init -b main
git add .
git commit -m "StandRework iOS dylib"
git remote add origin https://github.com/airgram-real/standrework-ios.git
git push -u origin main
```

Дальше: Actions → workflow **Build StandRework iOS dylib** → дождись зелёной галочки.
Внизу страницы сборки → **Artifacts** → скачай `StandRework.dylib`.

Пересобрать вручную: Actions → workflow → **Run workflow**.

## Дальше (ещё не сделано)

- Инжект `StandRework.dylib` в IPA: положить в `Payload/Standoff2.app/Frameworks/`
  и добавить в `UnityFramework` (или в основной бинарь) команду `LC_LOAD_DYLIB`
  с путём `@executable_path/Frameworks/StandRework.dylib`.
- Переподпись и установка (Sideloadly / AltStore / TrollStore).

## Offsets для 0.22.0 iOS (UnityFramework, arm64)

Получены Il2CppDumper'ом из `[AP] Standoff 2 (0.22.0).ipa`
(CodeRegistration `0x46E9B50`, MetadataRegistration `0x47CE860`, metadata v29):

| Метод | Адрес (VA) |
|---|---|
| `Axlebolt.Standoff.Photon.PhotonAsync::Connect(masterServerAddress, port, appId, gameVersion)` | `0x01F6A818` |
| `Axlebolt.Standoff.Photon.AsyncConnect::Connect(__this, masterServerAddress, port, appId, gameVersion)` | `0x01F64214` |
| `NetworkingPeer::GetNameServerAddress()` | `0x01A22CAC` |
| `NetworkingPeer::Connect(__this, serverAddress, type)` | `0x01A23D24` |
| `NetworkingPeer::ConnectToNameServer()` | `0x01A24A40` |
| `NetworkingPeer::ConnectToRegionMaster(region)` | `0x01A24C64` |

Поля `NetworkingPeer`: `AppId` `0xE8`, `MasterServerAddress` `0x110`, `GameServerAddress` `0x118`, `Server` `0x120`.

Эти адреса нужны, если переходить на il2cpp-хуки уровня Dobby (как в Android-либе
`src/main.cpp`, где хукается `connect_async` и правится `config+0x10` / `config+0x28`).
Включается флагом `SR_USE_IL2CPP_HOOKS` в `config.h` (пока `0` — сначала проверяем
socket-хуки, они проще и не зависят от смещений).
