# Businessmässan — businessmassan.azzar.org

Migrering av kundens WordPress-sajt `businessmassan.se` till Odoo-webbplatsen
`businessmassan.azzar.org`.

**Kund:** Anders Björck AB (arrangör av Businessmässan).
**Kontakt:** Anders Björck · info@businessmassan.se · 013-10 09 10.
**Källa:** businessmassan.se (WordPress + Elementor Pro).
**Status:** FAS 1 + FAS 2 klara 2026-10-13.

## Innehåll

```
businessmassan_website/     Odoo-modulen (10 filer)
businessmassan-HANDOVER.md  Full handover: miljö, fällor, nästa steg
_source/bm-wp/              WordPress-materialet via REST-API
```

## Modulen

`businessmassan_website` version 18.0.1.16.0. Äger:

- **10 sidor** (`data/website_pages.xml`) — LKPG + NKPG, alla publicerade
- **Meny** (`data/website_menu.xml`) — Startsida, Boka, För utställare,
  Program, Norrköping, Tidigare mässor
- **Config** (`data/website_config.xml`) — namn, logotyp, Google Fonts
- **`ir.asset`** (`data/ir_asset.xml`) — **krävs för att SCSS:en ska laddas**
- **Footer** (`views/website_footer.xml`) — svensk, kundens uppgifter
- **Kontaktsidor** (`views/website_contactus.xml`) — rensade från demoadress
- **Stil** (`static/src/scss/businessmassan.scss`) — Noto Sans / Lato,
  mörk header `#272629`, cart-ikonen dold

## Miljö

| | |
|---|---|
| Minion | `businessmassan` @ 192.168.11.64 (LXD-värd `fors`) |
| Odoo | 18.0 |
| Databas | `businessmassan` @ postgres16.vertel.se |
| Deploy-mål | `/usr/share/odoo-website/businessmassan_website/` |

**Arbetsväg:** SSH-nyckeln från hansolo18 till businessmassan är borta. Använd
mastern `192.168.11.22` (hostname `SaltStack`):

```bash
ssh 192.168.11.22
sudo -n salt businessmassan cmd.run "..." --timeout 30
```

I containern finns `/tmp/odsh.sh` (odoo shell) och `/tmp/bmq.sh` (psql).
Base64:a skript — Salt tolkar `=` som kwarg.

## Deploy

```bash
# 1. Bumpa version i __manifest__.py
# 2. Kopiera modulen till /usr/share/odoo-website/businessmassan_website/
# 3. Uppdatera
sudo -u odoo /usr/bin/odoo -c /etc/odoo/odoo.conf -d businessmassan \
     --no-http --stop-after-init -u businessmassan_website
# 4. Starta om (rensar vy-cache)
systemctl restart odoo
```

## Beslut

1. **Design = kundens egen.** Modulen använder `#272629`. Vertels palett
   (`#4b1f50`/`#f29e29`) hör inte hit.
2. **WP-texten är sanningen.** Odoo-versionen är en omskrivning, inte en kopia.
3. **Allt ska tillbaka in i `data/*.xml`** så det överlever uppgradering.

## Klart

- **FAS 1** — städning: demodata borta, `res.company`, meny, footer, `ir.asset`
- **FAS 2** — innehåll: alla 10 sidor byggda från WP-texten **ordagrant**
- **FAS 3** — design: kundens palett extraherad från businessmassan.se
- **FAS 4** — modulen versionshanterad här (källan var tidigare okänd)

## Kvar

- Bilderna: 17 av 71 media används i modulen; resten ligger i `_source/bm-wp/media/`
- `website.custom_code_head` sätts via shell — bör flyttas till `data/website_config.xml`
