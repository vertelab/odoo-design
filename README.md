# odoo-design

Odoo-webbplatser och designmoduler för Vertels kunder.

Detta repo är hemvisten för de Odoo-moduler som bygger kunders webbplatser —
teman, snippets, sidstruktur, meny, footer och varumärkesanpassning. Syftet är
att allt som görs i en kunds databas ska finnas som versionshanterad XML i en
modul, så att det överlever en moduluppdatering och kan reproduceras.

## Struktur

```
customers/
├── <kund>_website/          # Odoo-modulen (deployas till /usr/share/odoo-website/)
│   ├── __manifest__.py
│   ├── data/                # Sidor, meny, config, ir.asset
│   ├── models/              # Datamodell-tillägg
│   ├── views/               # Ärvda vyer (footer, contactus, …)
│   └── static/src/          # SCSS, bilder
├── <kund>-HANDOVER.md       # Projektets handover (status, fällor, nästa steg)
└── _source/                 # Källmaterial från kundens befintliga sajt
```

## Konventioner

**En kunds webbplats = en modul.** Modulen äger sidorna, menyn, footern och
stilen. Databasen är en spegling — inte källan.

**Allt i `data/*.xml`.** Ändringar som bara görs i webbeditorn försvinner vid
nästa moduluppdatering. Redigera XML:en.

**Kundens varumärke, inte Vertels.** Vertels designsystem (`~/plan/theme/`,
Navy `#0F172A` / Gold `#F59E0B`) används för Vertels egna moduler och
App Store-material. En kunds webbplats använder kundens egna färger.

**Språk:** kod och commits på engelska. UI-strängar engelska i koden,
svenska i `i18n/sv.po` och i webbplatsinnehållet.

## Kända fallgropar (Odoo 18)

| Fälla | Detalj |
|---|---|
| **`ir.asset` skapas inte från manifestet** | Manifestets `assets`-block registrerar filen i asset-pipelinen, men `ir.asset`-tabellen fylls bara av `ir.asset`-XML-poster med xmlid. Utan XML-posten laddas SCSS:en aldrig. |
| **Xpath utvärderas mot engelska arketypen** | Översättningen ligger i jsonb. `//h5[text()='Mitt Företag']` hittas inte — `//h5[text()='My Company']` gör det. Använd `hasclass()` för klassmatchning. |
| **Inaktivera aldrig en `primary`-vy** | Om layouten anropar den ger `active=False` → `RuntimeError: object is not bound` och 500 på hela sajten. Dölj med CSS i stället. |
| **Demodata i ärvda vyer** | Odoo:s exempeltext (`info@yourcompany.example.com`, `+1 555-555-5556`, "rebelliska produkter") ligger hårdkodad i ärvda vyer — inte som demodataposter. Fixas genom att redigera mallen och `res.company`. |
| **Version bump krävs** | `--update` hoppar över en modul vars version inte ändrats. Bumpa `__manifest__.py` före varje uppdatering. |

## Kunder

| Kund | Modul | Domän | Status |
|---|---|---|---|
| Businessmässan (Anders Björck AB) | `businessmassan_website` | businessmassan.azzar.org | FAS 1 klar |

## Drift

Modulerna deployas till `/usr/share/odoo-website/` på respektive minion och
aktiveras med `-u <modul>` efter version bump. Se respektive HANDOVER för
miljö, arbetsväg och kommandon.

`customers/deploy.sh` gör hela kedjan: paketerar, överför till containern,
uppdaterar modulen, startar om Odoo och verifierar alla sidor.

## OpenDesign

`odoo-website`-pluginen (`~/open-design/.od/plugins/odoo-website/`) pekar på
detta repo:

```json
"plugin": { "repo": "https://github.com/vertelab/odoo-design" }
```

Pluginen genererar Odoo-kompatibel HTML via XML-RPC. Se `HANDOVER-luke.md`
för uppsättning på arbetsstationen.
