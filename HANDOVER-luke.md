# HANDOVER — Businessmässan → luke

**Skapad:** 2026-10-13
**Av:** Pi-agent (session på hansolo)
**Till:** nästa session på `luke`
**Syfte:** Fortsätta arbetet med Businessmässans Odoo-webbplats, och använda
open-design + `odoo-website`-pluginen för designarbetet.

---

## 1. VAD SOM ÄR KLART

**Alla fyra faser är klara.** Sajten är live på https://businessmassan.azzar.org
— alla 12 sidor HTTP 200, noll demodata, kundens design applicerad.

| Fas | Vad | Resultat |
|---|---|---|
| **FAS 1** | Städning | Demodata borta, `res.company` ifylld, meny städad, `ir.asset` skapad |
| **FAS 2** | Innehåll | Alla 10 sidor byggda från WP-texten **ordagrant** |
| **FAS 3** | Design | Kundens palett extraherad och applicerad |
| **FAS 4** | Reproducerbarhet | Modulen i git, deploy-skript klart |

**Modul:** `businessmassan_website` version **18.0.1.23.0**.

---

## 2. REPOT — github.com/vertelab/odoo-design

```
~/odoo-design/                          (på hansolo; klona på luke)
├── README.md                           Konventioner + Odoo 18-fällor
├── customers/
│   ├── README.md                       Kundöversikt
│   ├── deploy.sh                       git → container (en kommandorad)
│   ├── businessmassan-HANDOVER.md      Denna fil (ursprunglig handover)
│   ├── businessmassan_website/         Odoo-modulen
│   │   ├── __manifest__.py             18.0.1.23.0
│   │   ├── data/
│   │   │   ├── ir_asset.xml            ⚠️ KRÄVS för att SCSS ska laddas
│   │   │   ├── website_pages.xml       10 sidor (genererad från WP)
│   │   │   ├── website_config.xml      namn, logotyp, Google Fonts
│   │   │   └── website_menu.xml        meny
│   │   ├── models/website_menu_cleanup.py
│   │   ├── views/
│   │   │   ├── website_footer.xml      svensk footer
│   │   │   └── website_contactus.xml   rensade kontaktsidor
│   │   └── static/
│   │       ├── src/img/                17 bilder
│   │       ├── src/scss/businessmassan.scss   designspråket
│   │       └── description/            skärmbilder
│   └── _source/bm-wp/                  WordPress-materialet (71 media, 28 MB)
└── .gitignore
```

**Commits:** `a5a5f9d` (modul + struktur), `cd5aafe` (FAS 2-text),
`da9d15b` (deploy-skript). Allt pushat till `main`.

---

## 3. MILJÖN

| | |
|---|---|
| Minion | `businessmassan` @ 192.168.11.64 (LXD-värd `fors`) |
| Odoo | 18.0 |
| Databas | `businessmassan` @ postgres16.vertel.se |
| Deploy-mål | `/usr/share/odoo-website/businessmassan_website/` |
| Publik URL | https://businessmassan.azzar.org |
| Salt-master | `192.168.11.22` (hostname `SaltStack`) |

⚠️ **SSH-nyckeln från hansolo18 till businessmassan är BORTA.** Allt går via
mastern. `salt-cp` fungerar INTE i denna miljö (misslyckas tyst) — filer
överförs som base64 i 60 KB-bitar genom `cmd.run`. `deploy.sh` gör detta åt dig.

```bash
ssh 192.168.11.22
sudo -n salt businessmassan cmd.run "..." --timeout 30
```

I containern finns `/tmp/odsh.sh` (odoo shell) och `/tmp/bmq.sh` (psql).

---

## 4. DE KUNDSPECIFIKA BESLUTEN

1. **WP-texten är ORDAGRANN.** Ingen omskrivning. `build_pages.py` kopierar
   exakt. Odoo-versionen som fanns tidigare var en omskrivning — den är ersatt.
2. **Kundens egen design**, inte Vertels palett.
3. **Allt i `data/*.xml`** så det överlever moduluppdatering.

---

## 5. KUNDENS DESIGNSPRÅK (extraherat från businessmassan.se)

| Roll | Färg |
|---|---|
| Bakgrund | `#12100b` (dominerande) |
| Sekundär / header | `#262528` / `#272629` |
| Accent 1 | `#e64500` (orange) |
| Accent 2 | `#e60077` (rosa) |
| Ljus | `#f9f9f9` |
| Typsnitt | Noto Sans (rubriker), Lato (brödtext) |

Källa: WordPress + Elementor Pro, tema `hello-elementor`. Extraherat ur
`--e-global-color-*`-variablerna och verifierat mot en headless-rendering.

---

## 6. FYRA FÄLLOR SOM KOSTADE TID

### 6.1 `ir.asset` skapas INTE från manifestets `assets`-block
Odoo 18 fyller `ir.asset` bara från `ir.asset`-XML-poster med xmlid. Manifestets
`assets` registrerar filen i pipelinen, men utan XML-posten laddas den aldrig.
**Detta var hela orsaken till att designen saknades.**

### 6.2 Modulens SCSS vinner INTE över Odoo:s bakgrund
Odoo sätter sidans bakgrund via CSS-variabler (`--o-cc*-bg`) på
`.o_cc`/`.o_colored_level`, och `website/static/src/scss/user_custom_rules.scss`
laddas **efter** modulens bundle (modulnamnet sorteras före `website*`).
**Lösning:** designen appliceras via `website.custom_code_head`, som renderas
sist i `<head>`. Modulens SCSS finns kvar som versionshanterad källa.

### 6.3 Xpath i ärvda vyer utvärderas mot den ENGELSKA arketypen
Översättningen ligger i jsonb. `//h5[text()='Mitt Företag']` hittas inte;
`//h5[text()='My Company']` gör det. Använd `hasclass()` för klassmatchning.

### 6.4 Inaktivera ALDRIG en `primary`-vy som layouten anropar
`website_sale.header_cart_link` gav `RuntimeError: object is not bound` och 500
på hela sajten. Dölj med CSS i stället.

**Bonus:** `website.contactus_thanks` har xmlid
`website.contactus_thanks_ir_ui_view` — inte `website.contactus_thanks`.

---

## 7. KVAR ATT GÖRA

1. **`custom_code_head` är satt via shell, inte via XML.** Den bör flyttas till
   `data/website_config.xml` så den blir reproducerbar. ⚠️ Värdet innehåller
   `<style>`-block med `{}` — CDATA krävs.
2. **Bilderna:** 17 av 71 media används i modulen. Resten ligger i
   `_source/bm-wp/media/`. PDF:erna (7 st) och mp4:n (7,3 MB) är oanvända.
3. **`businessmassan.se` → `.azzar.org`-omdirigering** — ej beslutat.
4. **Menyns NKPG-post** pekar på `/nkpg`; barnen (Boka NKPG, För utställare
   NKPG, Program NKPG, Save the date) ligger inte i menyn än.

---

## 8. OPEN-DESIGN + odoo-website-PLUGINEN

`~/open-design` (på hansolo, 2,1 GB) är OpenDesign — ett lokalt designverktyg
som kör design-skills via en kod-agent-CLI.

**Det värdefulla är `.od/`-tillståndet** (684 KB), inte tredjepartskoden:
- `.od/design-systems/vertel-ab/` — Vertels designsystem
- `.od/plugins/odoo-website/` — pluginen (`open-design.json` + `SKILL.md`)
- `.od/memory/` — 7 minnesfiler om Vertels varumärke

⚠️ **Pluginen pekar på `https://github.com/vertelab/odoo-design`** — alltså
samma repo som modulen. Det bekräftar att repot är hemvisten för båda.

**Krav:** Node 24 (`~24`), pnpm 10.33.2 via Corepack. Luke har Node 22 och
corepack men ingen pnpm.

---

## 9. SNABBSTART PÅ LUKE

```bash
# 1. Klona repot
git clone git@github.com:vertelab/odoo-design.git ~/odoo-design

# 2. Läs konventionerna
cat ~/odoo-design/README.md

# 3. Deploya en ändring
cd ~/odoo-design/customers
./deploy.sh                    # full deploy + moduluppdatering
SKIP_IMAGES=1 ./deploy.sh      # snabb (hoppar över static/src/img)

# 4. Verifiera
curl -s -o /dev/null -w "%{http_code}\n" https://businessmassan.azzar.org/
```

**OpenDesign:** se `~/.od`-tillståndet. Node 24 krävs:
```bash
corepack enable && corepack pnpm --version   # ska ge 10.33.2
```

---

## 10. FILER ATT LÄSA FÖRST

1. `~/odoo-design/README.md` — konventioner och fällor
2. `~/odoo-design/customers/README.md` — kundöversikt
3. Denna fil
4. `businessmassan_website/__manifest__.py` — vad modulen innehåller
5. `businessmassan_website/data/ir_asset.xml` — den kritiska fixen
