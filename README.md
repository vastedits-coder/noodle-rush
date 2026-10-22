# Noodle Rush (v0.1)

Restaurant tycoon pe Roblox: ramen, egg noodles, buldak. Clienți cu răbdare limitată, bucătari, ospătari, casieri, upgrade-uri, atmosferă și magazin cu Robux. Totul e generat din cod, deci nu trebuie construită nicio hartă ca să-l joci.

## Controale în joc

| Tastă | Ce face |
| --- | --- |
| E (lângă tejghea) | Iei comanda primului client |
| F | Upgrade-uri (Menu, Staff, Restaurant) |
| G | Magazin Robux |
| V | Comuți first person / third person |

## Cum îl deschizi rapid (fără unelte)

1. Deschide Roblox Studio.
2. File → Open from File → alegi `NoodleRush.rbxl`.
3. Apeși Play (F5).

## Setup pentru dezvoltare (Windows)

1. Instalează [Git](https://git-scm.com/download/win) și [VS Code](https://code.visualstudio.com/).
2. Instalează Rokit: descarcă arhiva pentru Windows de pe [releases](https://github.com/rojo-rbx/rokit/releases), dezarhivează, apoi în PowerShell, în folderul respectiv:
   ```powershell
   .\rokit.exe self-install
   ```
   Închide și redeschide terminalul.
3. Clonează proiectul și instalează uneltele:
   ```powershell
   git clone https://github.com/<user>/noodle-rush.git
   cd noodle-rush
   rokit install
   rojo plugin install
   ```
4. În VS Code instalează extensiile: **Rojo**, **Luau Language Server**, **Selene**, **StyLua**.
5. Construiești fișierul jocului și îl deschizi în Studio:
   ```powershell
   rojo build -o NoodleRush.rbxl
   ```
6. Pentru sincronizare live: `rojo serve`, apoi în Studio, tab-ul Plugins → Rojo → Connect. Orice salvare în VS Code apare imediat în Studio.

## Structura

```
src/
  shared/   Config (toată balansarea), Formulas, Remotes      -> ReplicatedStorage.Shared
  server/   Main, PlayerData, RestaurantBuilder, Restaurant,
            Npc, UpgradeService, Monetization                 -> ServerScriptService.Server
  client/   Main, UI, CameraToggle                            -> StarterPlayerScripts.Client
```

## Monetizare

Game Passes și Developer Products se creează în Creator Hub (după ce jocul e publicat), apoi ID-urile se pun în `src/shared/Config.luau` la `GamePasses` și `Products`. Cu ID 0, magazinul le arată ca „nu e configurat încă”.

## Salvare

Ca să meargă salvarea în Studio: Game Settings → Security → Enable Studio Access to API Services (jocul trebuie publicat întâi).
