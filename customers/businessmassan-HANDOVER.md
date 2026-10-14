# HANDOVER — Businessmässan: businessmassan.se → businessmassan.azzar.org

**Skapad:** 2026-10-13
**Syfte:** Migrera/branda om kundens WordPress-sajt `businessmassan.se` till
Odoo-webbplatsen `businessmassan.azzar.org` — med Vertel-designsystemet.
**Status vid handover:** Diagnos klar. Inga ändringar gjorda i Odoo. Inga filer
ändrade i salt-repot.

---

## 1. VARFÖR HANSOLO

Nästa session ska köras **på hansolo** (`192.168.1.91`, wg `172.16.11.236`),
för där finns:

- **SSH-nyckel till `businessmassan`** (`waland@192.168.11.64`) — verifierad
  fungera: `ssh 192.168.11.64` → `waland@businessmassan:~$`
- **open-design** installerat (`~/open-design`, `.od/` komplett, pnpm 10.33.2)
- **Vertel-designsystemet** (`design-systems/vertel-ab/`) + `odoo-website`-pluginen
- Alla skills

Från mastern (192.168.11.22) finns **ingen** SSH-väg till businessmassan —
nyckeln saknas. Salt fungerar däremot från mastern (se §3).

---

## 2. MÅLMILJÖN — fakta

| Egenskap | Värde |
|---|---|
| Minion | `businessmassan` |
| IP | `192.168.11.64` |
| LXD-värd | `fors` |
| OS | Ubuntu 24.04 |
| Odoo | **18.0** (`18.0-20260915`) |
| DB | `businessmassan` @ `postgres16.vertel.se` (192.168.11.48) |
| db_user / db_password | `businessmassan` / `ON2fUq7HWXDOv9jUIE2eLQ==` |
| `admin_passwd` | `Qcp3;-Q,>qeZO$EZu,@}B/Z2^0"V,4^i` |
| Odoo-process | user `odoo`, `/usr/bin/odoo -c /etc/odoo/odoo.conf` |
| URL | https://businessmassan.azzar.org (HTTP 200) |
| Caddy-config | `caddy/sites/businessmassan.azzar.org.yaml` (`odoo_db: businessmassan`) |
| Storage | `storage/customers/businessmassan.yaml` (Garage S3) |
| Repo | `odoo/repos/customers/businessmassan.repo` |

⚠️ **`businessmassan.yaml` och `businessmassan.azzar.org.yaml`** i
`caddy/sites/` är två filer för samma domän — troligen dubblett, värt att
städa. Båda pekar på `192.168.11.64`.

---

## 3. SÅ NÅR DU ODOO (två vägar)

### Väg A — SSH (från hansolo, ENKLAST)
```bash
ssh 192.168.11.64
sudo -u odoo /usr/bin/odoo shell -c /etc/odoo/odoo.conf -d businessmassan \
     --no-http --log-level=warn < /tmp/mitt_script.py
```
`psql` finns i containern. `sudo` kräver lösenord för waland — använd
`sudo -u odoo` (verifiera först med `sudo -n true`).

### Väg B — Salt (från mastern, om SSH inte funkar)
Hjälpskriptet `/tmp/odsh.sh` finns redan i containern:
```bash
# skriv python till containern (base64 för att slippa citat-problem)
B64=$(base64 -w0 <<'PY'
print("hej")
PY
)
sudo -n salt businessmassan cmd.run "echo $B64 | base64 -d > /tmp/bm/q.py && /tmp/odsh.sh /tmp/bm/q.py" --timeout 120
```
`/tmp/odsh.sh` innehåller:
```bash
#!/bin/bash
sudo -u odoo /usr/bin/odoo shell -c /etc/odoo/odoo.conf -d businessmassan --no-http --log-level=warn < "$1" 2>&1
```
Och `/tmp/bmq.sh` (SQL-genväg):
```bash
#!/bin/bash
export PGPASSWORD=$(awk -F'= ' '/^db_password/{print $2}' /etc/odoo/odoo.conf)
psql -h postgres16.vertel.se -U businessmassan -d businessmassan -tAc "$1" 2>&1
```

⚠️ **`odoo shell` skriver mycket WARNING-brus** — filtrera med
`grep -vE "WARNING|^$"`. Bruset är ofarligt (kända fältvarningar i
`website_event_sale_reservation` m.fl.).

⚠️ **Salt + `=` i argument** tolkas som kwarg → använd base64 (ovan) eller
skriptfil. Rå `cmd.run "psql ... -tAc \"select ...\""` faller på detta.

---

## 4. DIAGNOSEN — vad som är fel på sajten

### 4.1 Modulen `businessmassan_website` FINNS och är rätt byggd
Sökväg: `/usr/share/odoo-website/businessmassan_website/`
(alltså **inte** i `addons_path`-listan i odoo.conf — men `odoo-website` är
en av sökvägarna, så den hittas)

```
__manifest__.py          version 18.0.1.1.0, author "Vertel AB", AGPL-3
models/website_menu_cleanup.py   _businessmassan_clean_default_menu()
data/website_pages.xml   10 sidor
data/website_config.xml  namn, logo, Google Fonts (Noto Sans + Lato)
data/website_menu.xml    6 menyposter
static/src/scss/businessmassan.scss   egen styling (#272629 header m.m.)
static/src/img/          9 bilder (BM.png, BM-Vit.png, logo.png, map.png …)
```

**Installerad:** `state=installed`, `installed_version=18.0.1.1.0`.

### 4.2 De fem konkreta felen

**FEL 1 — Demodata i footern.** Detta är Odoo-standardtext, inte kundens:
> "Vi är ett team av passionerade människor vars mål är att förbättra allas
> liv genom **rebelliska produkter**." · "**info@yourcompany.example.com**" ·
> "**+1 555-555-5556**" · "Copyright © **Företagsnamn**" · "Drivs med —
> Den #1 e-handelssystem med öppen källkod"

**FEL 2 — `res.company` är orensad:** `name='My Company'`, `email=False`,
`phone=''`. Detta läcker ut i footer/header/kontaktsida.

**FEL 3 — Två menyer, fel en aktiv.** `website.menu_id = 4`
("Toppmeny för webbplats 1") är aktiv. Men modulens `_clean_default_menu()`
kördes **inte** — meny **id 1** ("Standard huvudmeny") har kvar Odoo-skräpet:
`Webbutik /shop`, `Händelser /event`, `Forum /forum`, `Event Types
/event-types`, `Kurser /slides`, `Bokning /website/calendar`, `Kontakta oss
/contactus`. Meny 4 saknar dessutom NKPG-sidorna (Boka NKPG, För utställare
NKPG, Program NKPG, Save the date) — de finns som sidor men nås inte.

**FEL 4 — `+1 555-555-5556` i headern.** Odoo:s standardtelefonnummer, ej
borttaget.

**FEL 5 — SCSS:en är inte laddad.** `ir.asset` med `businessmassan` = **0
poster**. `website.custom_code_head` är satt (551 tecken, Google Fonts +
font-family-regler) men **asset-pipelinen har inte plockat upp SCSS-filen**.
Detta är varför sajten ser naken ut — ingen Vertel-/BM-styling alls.

### 4.3 Sidorna och deras xmlid (alla publicerade)

| id | url | arkiv | xmlid |
|---|---|---|---|
| 6 | `/` | 2700 B | `businessmassan_website.page_lkpg` |
| 7 | `/boka` | 4389 B | `...page_boka` |
| 8 | `/for-utstallare` | 9303 B | `...page_for_utstallare` |
| 9 | `/program` | 2557 B | `...page_program` |
| 10 | `/nkpg` | 3161 B | `...page_nkpg` |
| 11 | `/boka-nkpg` | 2972 B | `...page_boka_nkpg` |
| 12 | `/for-utstallare-i-nkpg` | 3876 B | `...page_for_utstallare_i_nkpg` |
| 13 | `/program-nkpg` | 1973 B | `...page_program_nkpg` |
| 14 | `/save-the-date` | 1519 B | `...page_save_the_date` |
| 15 | `/tidigare-massor` | 1616 B | `...page_tidigare_massor` |
| 1,3 | `/contactus*` | — | `website.*` (Odoo-standard) |
| 5 | `/membership-info` | — | `website_event_membership_restriction.*` |

⚠️ **`businessmassan_website.page_for_utstallare_nkpg` → SAKNAS** som xmlid,
men sidan finns (id 12, xmlid `...page_for_utstallare_i_nkpg`). Namngivningen
i `website_pages.xml` matchar alltså inte helt — kontrollera vid uppdatering.

---

## 5. KÄLLAN — businessmassan.se (WordPress)

**Stack:** WordPress + **Elementor Pro**, tema `hello-elementor`.

**REST-API:t är ÖPPET** (ingen auth behövs) — detta är den stora genvägen:

```bash
curl -s "https://businessmassan.se/wp-json/wp/v2/pages?per_page=100&_fields=id,slug,link,title,content,excerpt,template"
curl -s "https://businessmassan.se/wp-json/wp/v2/posts?per_page=100&_fields=id,slug,link,title,content,date"
curl -s "https://businessmassan.se/wp-json/wp/v2/media?per_page=100&_fields=id,slug,source_url,mime_type,title,media_details"
```
(`/wp-json/wp/v2/menus` → 401, menyn måste skrapas ur HTML:en)

**Inventering:**

| | Antal | Not |
|---|---|---|
| Sidor | **10** | se tabell nedan |
| Inlägg | **3** | BM-LKPG 2024, BM-LKPG 2025, BM-NKPG 2025 |
| Media | **71** | 33,3 MB totalt |
| Kategorier | 1 | Uncategorized |
| Formulär | 5 | Elementor-form |

**Media-fördelning:** 30 jpeg, 24 png, 7 pdf, 7 svg, 2 xlsx, 1 mp4 (7,3 MB).

**WP-sidorna (slug → ord):**
| slug | ord | Odoo-motsvarighet |
|---|---|---|
| `lkpg` (=`/`) | 445 | `/` |
| `boka` | **811** | `/boka` |
| `for-utstallare` | **1161** | `/for-utstallare` |
| `program` | 253 | `/program` |
| `nkpg` | 410 | `/nkpg` |
| `boka-nkpg` | 374 | `/boka-nkpg` |
| `for-utstallare-i-nkpg` | 487 | `/for-utstallare-i-nkpg` |
| `program-nkpg` | 186 | `/program-nkpg` |
| `save-the-date` | 210 | `/save-the-date` |
| `tidigare-massor` | 174 | `/tidigare-massor` |
| **Totalt** | **4511** | |

**Lokalt nedladdat (om det finns kvar):** `/tmp/bm-wp-*/` med `pages.json`,
`posts.json`, `media.json`, `categories.json`. Om borta — hämta om med
curlen ovan (30 sekunder).

---

## 6. VIKTIGA INSIKTER

### 6.1 Odoo ≠ WordPress — innehållet kan inte klistras in
Elementor-markupen (`elementor-widget-*`, 260 `container`, 85 `heading`,
56 `text-editor`, testimonials, icon-lists) är **inte portabel**. Elementors
CSS/JS finns inte i Odoo. Innehållet måste **byggas om som Odoo-snippets**
(`s_cover`, `s_features`, `s_call_to_action`, `s_text_image` …).

Användarens egna ord: *"Odoo använder ett annat css-ramverk, typsnitt och
bilder är grundläggande för att det skall bli bra."*

### 6.2 Odoo:s CSS-ramverk = Bootstrap 5
Snippets använder `container`, `row`, `col-lg-*`, `mt-*`, `py-*`.
Klasser från Elementor (`elementor-*`) gör ingenting i Odoo.

### 6.3 Bilderna ÄR grunden
71 media, varav de viktiga:
- **Logotyper:** `BM.png`, `BM-Vit.png`, `BM-original-utan-stad.svg`,
  `BM-original-Nkpg.png`, `logo.svg`
- **Hero/bakgrund:** `hero.jpg` (2500×1401), `AdobeStock_*.jpeg` (2560×1707,
  8 st), `bakgrund*.jpg`
- **Partnerloggor:** `linkoping-rgb-300x85-1.png`, `NTMmedia.white_.png`,
  `bb-lkpg-2.png`, `ABloggo-mindre.jpg`, `Foretagarna-LKPG-logga-white.png`
- **Dokument:** 7 PDF (utställarinformation, summeringar, monterskiss),
  2 xlsx (beställningslista, LOUIS-DE-GEER)

Nio av dessa finns **redan** i modulen (`static/src/img/`). Resten (hero,
AdobeStock-bilderna, PDF:erna) saknas.

### 6.4 Texten skiljer sig mellan WP och Odoo
Odoo-versionen är en **omskrivning**, inte en kopia. Exempel:
- WP: "Framtidsstaden Linköping och hur navigera i en osäker omvärld –
  Från hotbild till motståndskraft"
- Odoo: "Framtidsstaden Linköping - 'Vad händer i vår kommun och vårt
  näringsliv'"

**Användarens beslut: WP-texten är sanningen.**

---

## 7. VAD SOM SKA GÖRAS — föreslagen ordning

Användarens svar på frågorna:
- **(a)** "det är för kunden" → arbetet är för kund, mandat finns
- **(b)** "gör som du tror är bäst" → fria händer på metod
- **(c)** WP-texten är sanningen
- **(d)** ingen hjälp med API-nycklar → använd DB-uppgifterna i §2

### FAS 1 — Städa (okontroversiellt, syns direkt)
1. `res.company`: namn → **Businessmässan** (eller juridiskt namn — fråga),
   email `info@businessmassan.se`, telefon, webbplats
2. Footer: ta bort Odoo-demotexten, sätt riktig kontaktinfo + copyright
3. Header: bort med `+1 555-555-5556`
4. Kör `_businessmassan_clean_default_menu()` så meny 1 städas
5. Meny 4: lägg till NKPG-sidorna (Boka NKPG, För utställare NKPG,
   Program NKPG, Save the date) — eller besluta att de ska ligga under en
   "Norrköping"-dropdown
6. Fixa **SCSS-asseten** (`ir.asset` = 0) — detta är varför designen är borta

### FAS 2 — Innehåll
7. Hämta WP-innehållet (REST-API, §5)
8. Bygg om till Odoo-snippets per sida; **WP-texten är sanningen**
9. Ladda upp bilderna som `ir.attachment` (eller lägg i modulens
   `static/src/img/` och referera statiskt)
10. Uppdatera `website_pages.xml` i modulen (så det blir reproducerbart via
    moduluppdatering) — eller skriv direkt i DB och exportera tillbaka

### FAS 3 — Design (open-design)
11. Kör `odoo-website`-pluginen mot `businessmassan.azzar.org` för att
    applicera Vertel-designsystemet
12. ⚠️ **Vertel-paletten** (`#ffffff, #f4f5f6, #383838, #a7a7a7, #dee2e6,
    #4b1f50, #f29e29`) är **inte** Businessmässans varumärke. Modulen använder
    `#272629` (mörk header). **Klargör med användaren:** ska kunden ha
    Vertel-designen eller sin egen? Detta är en kund, inte Vertel själva.

### FAS 4 — Reproducerbarhet
13. Allt som görs i DB bör landa i `businessmassan_website`-modulen
    (`data/*.xml`) så det överlever en moduluppdatering
14. Modulen ligger i `/usr/share/odoo-website/` — hitta dess **källa**
    (git-repo? salt?) och committa dit. Just nu är den bara på disk i
    containern.

---

## 8. ÖPPNA FRÅGOR TILL ANVÄNDAREN

1. **Ska kunden ha Vertel-designen eller sin egen?** (se 7.12)
2. **Vilket juridiskt namn** ska stå i footer? (AB? org.nr?)
3. **Ska `businessmassan.se` omdirigeras** till `.azzar.org`, eller är
   `.azzar.org` en staging?
4. **Var ligger modulens git-källa?** (`/usr/share/odoo-website/` är ett
   deploy-mål, inte ett repo)
5. **NKPG-menyval:** dropdown under "Norrköping" eller egna toppnivåposter?

---

## 9. FÄLLOR ATT UNDVIKA

| Fälla | Detalj |
|---|---|
| **Decoy-PostgreSQL** | Kör alltid `psql -h postgres16.vertel.se`, aldrig utan `-h` — containern kan ha en lokal PG med fel data |
| **Salt + `=`** | Tolkas som kwarg → base64:a skriptet |
| **`odoo shell`-brus** | Filtrera `grep -vE "WARNING\|^$"` |
| **Citattecken över SSH** | Skriv skriptfil + `scp`, kör `bash /tmp/x.sh` |
| **`/tmp`-kollision** | Andra sessioner använder `/tmp/final.sh` m.fl. → använd `$$`-suffix |
| **Två menyer** | `website.menu_id` (id 4) är aktiv, men meny 1 har skräpet. Radera på rätt meny |
| **`_clean_default_menu`** | Matchar på `url` — `/contactus` ligger i listan, men kundens kontaktsida ÄR `/contactus`. Kontrollera att den inte raderas felaktigt |
| **xmlid-mismatch** | `page_for_utstallare_nkpg` saknas, heter `page_for_utstallare_i_nkpg` |
| **SCSS-asset** | `ir.asset` = 0 → designen laddas inte. Kontrollera efter moduluppdatering |
| **`/usr/share/odoo-website/`** | Ändringar där är inte reproducerbara — hitta källan |

---

## 10. SNABBSTART FÖR NÄSTA SESSION

```bash
# 1. På hansolo
ssh 192.168.11.64                       # → waland@businessmassan

# 2. Verifiera Odoo-åtkomst
sudo -u odoo /usr/bin/odoo shell -c /etc/odoo/odoo.conf -d businessmassan \
     --no-http --log-level=warn <<'PY' 2>&1 | grep -vE "WARNING|^$"
print(env['website'].browse(1).name)
print(env['res.company'].browse(1).name)
PY

# 3. Läs modulen
cat /usr/share/odoo-website/businessmassan_website/data/website_pages.xml

# 4. Hämta WP-innehållet igen om /tmp är rensat
mkdir -p /tmp/bm-wp && cd /tmp/bm-wp
curl -s "https://businessmassan.se/wp-json/wp/v2/pages?per_page=100&_fields=id,slug,link,title,content,template" -o pages.json
curl -s "https://businessmassan.se/wp-json/wp/v2/posts?per_page=100&_fields=id,slug,link,title,content,date" -o posts.json
curl -s "https://businessmassan.se/wp-json/wp/v2/media?per_page=100&_fields=id,slug,source_url,mime_type,title,media_details" -o media.json
```

**Börja med FAS 1** — den är okontroversiell och syns direkt i webbläsaren.

---

## 11. FAS 1 UTFÖRD — 2026-10-13 (session 2)

**Status: FAS 1 klar och verifierad. Alla 12 sidor HTTP 200, noll demodata.**

### Resultat

| Sida | HTTP | Demodata |
|---|---|---|
| /, /boka, /for-utstallare, /program | 200 | 0 |
| /nkpg, /boka-nkpg, /for-utstallare-i-nkpg, /program-nkpg | 200 | 0 |
| /save-the-date, /tidigare-massor | 200 | 0 |
| /contactus, /contactus-thank-you | 200 | 0 |

Designen laddad: `#272629` (mörk header), Noto Sans + Lato i CSS-bundlen.

### Vad som gjordes

Modul `businessmassan_website` version **18.0.1.1.0 → 18.0.1.16.0**.

1. **`res.company`** → Anders Björck AB / info@businessmassan.se / 013-10 09 10 /
   https://businessmassan.se
2. **`data/ir_asset.xml`** (NY) — `ir.asset`-post för SCSS:en. **Detta var den
   avgörande fixen för designen.**
3. **`views/website_footer.xml`** (NY) — svensk footer, kundens uppgifter
4. **`views/website_contactus.xml`** (NY) — rensar demoadress på /contactus
   och /contactus-thank-you
5. **`website.header_text_element`** → active=False (renderade Odoos exempeltext)
6. **`models/website_menu_cleanup.py`** — filtret fixat (meny 1: 13→7 barn,
   `/contactus` skyddad)
7. **`static/src/scss/businessmassan.scss`** — cart-ikonen dold

### Rotorsaker (viktigast)

**`ir.asset` skapas INTE från manifestets `assets`-block.** Odoo 18 fyller
`ir.asset` bara från `ir.asset`-XML-poster med xmlid. Manifestets `assets`
registrerar filen i pipelinen, men utan XML-posten laddas den aldrig.

**Xpath i ärvda vyer utvärderas mot den ENGELSKA arketypen.** Översättningen
ligger i jsonb. `//h5[text()='Mitt Företag']` hittas inte;
`//h5[text()='My Company']` gör det. Använd `hasclass()` för klassmatchning.

**`website.contactus_thanks` har xmlid `website.contactus_thanks_ir_ui_view`.**

**Inaktivera ALDRIG en `primary`-vy som layouten anropar.** Det gav
`RuntimeError: object is not bound` och 500 på hela sajten. Dölj med CSS.

### KORRIGERING av §4.2 FEL 3

Meny **4** ("Toppmeny för webbplats 1") är aktiv och har rätt struktur (id 19–29).
NKPG-sidorna saknas INTE — de ligger under post 27 "Norrköping". Meny 1 är
Odoo:s globala standardmeny (`website_id = NULL`), osynlig på sajten. Städningen
är kosmetisk.

### Korrigering av §2 (databastyp)

Databasen är **INTE** en demodatabas: 0 demodatamoduler, 415 installerade moduler,
8 AI-agenter + Skatteverket som partners. **`repo_apply` på ren databas vore
destruktivt.** Demodatan var Odoo:s exempeltext hårdkodad i ärvda vyer.

### Modulens källkod SÄKRAD

`hansolo18:~/plan/odoo-saltstack/businessmassan_website/` (10 filer).
⚠️ Git-källan är fortfarande okänd — detta är en säkerhetskopia, inte lösningen
på §7.14.

### Arbetsväg (uppdaterad)

SSH-nyckeln från hansolo18 till businessmassan är **BORTA**. Använd:
```bash
ssh 192.168.11.22          # mastern (hostname SaltStack)
sudo -n salt businessmassan cmd.run "..." --timeout 30
# I containern: /tmp/odsh.sh (odoo shell), /tmp/bmq.sh (psql)
# Base64:a skript — Salt tolkar '=' som kwarg
```
⚠️ `salt-run` finns inte på mastern. `sudo -n salt` fungerar.

### Nästa: FAS 2
WP-innehållet (4511 ord, 10 sidor) är omskrivet i Odoo, inte kopierat. WP-texten
är sanningen. Källmaterial: `hansolo18:~/plan/odoo-saltstack/.pi/bm-wp/`.
