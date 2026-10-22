# Noodle Rush (v0.2)

Restaurant tycoon pe Roblox: ramen, egg noodles, buldak. Clienți reali cu avatare Roblox, dialoguri cu upsell, bar cu verificare de buletin, inspector sub acoperire, review-uri, personal, upgrade-uri și magazin cu Robux. Totul e generat din cod.

## Cum se joacă (v0.2)

La început ești singur: tu iei comenzile, gătești, torni băuturile și servești.

1. Clientul intră, trece pe la recepție, se așază la masă și citește meniul.
2. Când scrie „Ready to order!”, mergi la el și apeși **E**. Discuți cu el: poți să-i recomanzi un fel mai scump, să-i oferi o băutură și, dacă refuză, să insiști cu „e nouă și 50% reducere azi”.
3. Pentru băuturi cu limită de vârstă (Volt Energy, 16+) îți arată buletinul. Verifici numele, data nașterii, expirarea și poza. Dacă refuzi un buletin real, se enervează și lasă review prost. Dacă servești unul fals, primești review bun, dar crește riscul. Peste 40% risc poate veni un inspector sub acoperire.
4. Mergi la aragaz (**E** = Cook) și aștepți să se gătească, apoi iei bolul de pe pass (**E** = Pick up) și îl duci la client (**E** = Serve).
5. Cât mănâncă, îl poți întreba „How's everything?”. Lasă bacșiș mai mare și îți spune ce să îmbunătățești.
6. La plecare lasă un review. Rating-ul mare aduce clienți mai des.

Ospătarii, bucătarii și barmanii se deblochează din meniul de upgrade-uri (**F**).

| Tastă | Ce face |
| --- | --- |
| E | Interacționezi (comandă, gătit, ridici, servești) |
| 1-4 | Alegi o replică în dialog |
| F | Upgrade-uri (Menu, Bar, Staff, Restaurant) |
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
  server/   Main, PlayerData, RestaurantBuilder, Restaurant, Conversation,
            IdCards, Avatars, Npc, UpgradeService, Monetization -> ServerScriptService.Server
  client/   Main, UI, DialogUI, Theme, CameraToggle             -> StarterPlayerScripts.Client
```

## Monetizare

Game Passes și Developer Products se creează în Creator Hub (după ce jocul e publicat), apoi ID-urile se pun în `src/shared/Config.luau` la `GamePasses` și `Products`. Cu ID 0, magazinul le arată ca „nu e configurat încă”.

## Salvare

Ca să meargă salvarea în Studio: Game Settings → Security → Enable Studio Access to API Services (jocul trebuie publicat întâi).
