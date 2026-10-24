# Technische Vorbereitung — 24. Oktober 2026

## Ergebnis

Windows-Entwicklungsumgebung mit .NET SDK 10.0.402, Runtime 10.0.13,
Node.js 24.15.0 und Docker Desktop eingerichtet. CI und Docker verwenden Node 22.
Keine Galerie-Features, Designs oder produktiven Systeme wurden verändert.

## Änderungen

- Beide Repositories verwenden `feature/wedding-customizations`; Core ist nicht
  detached. `origin` zeigt jeweils auf den entsprechenden `patspei`-Fork.
- `.gitmodules` verwendet die absolute Core-Fork-URL und den Entwicklungsbranch.
  Der Superproject-Pointer zeigt auf Core `74ce7fd`.
- Die sechs rein automatisch veränderten Lockfiles wurden vor dem gezielten
  Paketupdate geprüft, lokal gesichert und ausschließlich im Arbeitsverzeichnis
  zurückgesetzt. Die ursprünglichen `.gitmodules`-Änderungen blieben erhalten.
- Zu Beginn war das Staging bereits leer; `.idea` war untracked. Beide
  `.gitignore`-Dateien verhindern jetzt IDE-Tracking. Lokale Dateien wurden erhalten.
- Ungültige SDK-Auswahl `10.0.0` auf `10.0.100` mit bestehendem
  `rollForward: latestMinor` korrigiert.
- NuGet-Sicherheitsupdates und alle sieben betroffenen NuGet-Lockfiles aktualisiert.
- Webpack-Ausgaben werden erst nach der Generierung in MSBuild registriert und
  das aktuelle Manifest eingebettet. Das behebt gelöschte/stale statische Assets
  beim Wechsel zwischen Debug und Release sowie beim ersten Publish.
- Test-Fixtures setzen ihre vorausgesetzte englische Kultur explizit. Der
  Upload-Testmock liefert einen gültigen UTC-Dateizeitstempel statt
  `DateTime.MinValue`. Keine Assertions wurden entfernt oder abgeschwächt.
- Lokaler Launcher, fixiertes MariaDB-Image, zufällige Secrets, VS-Code-Tasks,
  F5-Konfiguration und Dokumentation hinzugefügt. ASP.NET respektiert jetzt
  `ASPNETCORE_URLS`; der bisherige Container-Standardport bleibt erhalten.
- GitHub-CI verwendet .NET 10 und Node 22, prüft beide Builds, Tests und Audit und
  veröffentlicht Entwicklungsimages unter dem eigenen GHCR-Namespace.
- `.dockerignore` schließt zusätzlich lokale Secrets, Laufzeitdaten und IDE-Dateien aus.

## Sicherheit

| Paket | Vorher | Nachher |
|---|---|---|
| MailKit / MimeKit | 4.18.0 | 4.18.2 |
| System.Security.Cryptography.Pkcs | 10.0.0 | 10.0.13 |
| Microsoft.Data.Sqlite / EF-Pakete auf 9.0.18 | 9.0.18 | 9.0.19 |
| SQLitePCLRaw.bundle_e_sqlite3 / lib.e_sqlite3 | 2.1.10 | 2.1.12 |

Die beiden [PKCS-Advisories](https://github.com/advisories/GHSA-846f-f764-76mx)
([zweites Advisory](https://github.com/advisories/GHSA-2fmv-rv2c-59x7)) sind durch
10.0.13 behoben. Die [SQLite-Schwachstelle](https://github.com/advisories/GHSA-2m69-gcr7-jv3q)
betrifft die alten nativen SQLite-Versionen; die tatsächlich ausgelieferte
Windows-DLL wurde direkt abgefragt und meldet **SQLite 3.53.3**.

Die kleinste folgende EF-Patchversion
[9.0.19](https://www.nuget.org/packages/Microsoft.Data.Sqlite/9.0.19) zieht das
korrigierte Bundle ein; EF/Identity-Referenzen wurden innerhalb dieser Patchlinie
angeglichen. Keine EF-Major-Migration oder transitive Versionsüberschreibung.

Vier zusätzlich entdeckte npm-Schwachstellen (zwei hoch, eine mittel, eine niedrig)
wurden ausschließlich durch vier kompatible Lockfile-Updates behoben:
brace-expansion 5.0.12, fast-uri 3.1.9, serialize-javascript 7.1.4 und
source-map-js 1.2.2. Keine neue direkte Abhängigkeit.

**Verbleibende bekannte Sicherheitswarnungen im ausgeführten NuGet-/npm-Audit: 0.**
Audit blieb eingeschaltet; keine Sicherheitswarnungen wurden unterdrückt.
Weitere Paketdetails und Quellen: `Memtly.Core/SECURITY-UPDATES.md`.

## Tatsächlich ausgeführte Prüfungen

| Prüfung | Ergebnis |
|---|---|
| Baseline Locked Restore vor Paketupdate | Erfolgreich, ursprüngliche drei Advisories bestätigt |
| `dotnet restore ... --force-evaluate` | Erfolgreich, Lockfiles regeneriert |
| Locked Restore Community-Solution | Erfolgreich |
| Unabhängiger Locked Restore Core-Solution | Erfolgreich |
| Debug-Build der vollständigen Solution | Erfolgreich, 0 Fehler, 76 Warnungen |
| Release-Build der vollständigen Solution | Erfolgreich, 0 Fehler, 76 Warnungen |
| Debug-Tests | 433 erfolgreich, 0 fehlgeschlagen, 0 übersprungen |
| Release-Tests | 433 erfolgreich, 0 fehlgeschlagen, 0 übersprungen |
| NuGet-Audit inklusive transitiver Pakete | Alle 7 Projekte ohne bekannte Schwachstellen |
| npm-Update-Audit und anschließendes `npm ci` | 0 bekannte Schwachstellen |
| Docker Compose-Konfigurationsprüfung und Healthcheck | Erfolgreich |
| Lokaler Debug-Publish über Launcher | Erfolgreich |
| Lokale HTTP-Startseite / Login | Jeweils HTTP 200 |
| Admin-Anmeldung mit zufälligem Passwort und CSRF-Token | Erfolgreich |
| 7 verlinkte lokale CSS-/JS-/Bilddateien | Jeweils HTTP 200 |
| Linux-x64-Dockerimage, Locked Restore, Build und Publish | Erfolgreich, `memtly-wedding-dev:local` |
| Linux ARM64 und ARM/v7: Locked Restore, Build und Cross-Publish | Beide erfolgreich; keine ARM-Laufzeittests |

Die ersten Windows-Tests scheiterten mit 39 Fehlern: 34 durch deutsche
Zahlenformatierung und 5 durch den ungesetzten Mock-Zeitstempel in einer positiven
UTC-Zeitzone. Beide Fixture-Ursachen wurden korrigiert; die vollständigen Tests
wurden danach in beiden Konfigurationen erneut ausgeführt.

Verbleibende Buildwarnungen betreffen hauptsächlich Nullable-Annotationen,
veraltete WebHost-/Kryptografie-APIs, ASP.NET-ServiceProvider-Verwendung und
NU1510 für zwei explizite Configuration-Pakete, die .NET 10 automatisch bereitstellt.
Release-Webpack meldet außerdem die bereits großen Bundle-/Entrypoint-Größen.
Diese unabhängigen Punkte wurden bewusst nicht durch eine Architektur- oder
Designänderung bearbeitet. Der lokale Data-Protection-Keyring verwendet den
Upstream-Standard ohne XML-Verschlüsselung und ist durch Dateirechte geschützt.

VS-Code-Konfiguration wurde erstellt und der entsprechende Prepare-/Publish-Pfad
ausgeführt. Ein interaktiver F5-Breakpoint-Test wurde nicht ausgeführt.
Das erzeugte Dockerimage wurde gebaut; ein HTTP-Laufzeittest des Containers
wurde nicht durchgeführt. Der HTTP-Laufzeittest betrifft den Windows-.NET-Prozess
mit der separaten lokalen MariaDB.

## Relevante Dateien

Community: `.gitmodules`, `.gitignore`, `.dockerignore`, `global.json`,
`.github/workflows/docker-image.yml`, `Memtly.Community/{Program.cs,Memtly.Community.csproj,packages.lock.json}`,
Submodule-Pointer, `.env.example`, `compose.dev.yaml`, `scripts/dev.ps1`,
`.vscode/{launch.json,tasks.json,extensions.json}`, `DEVELOPMENT.md`, dieser Bericht.

Core: `.gitignore`, `global.json`, `Memtly.Core/Memtly.Core.csproj`,
die Projektdateien von SqlServer-/Sqlite-Migrations, alle sechs
`packages.lock.json`, `Memtly.Core/package-lock.json`,
`Memtly.Core.UnitTests/GlobalUsings.cs`,
`Memtly.Core.UnitTests/Tests/Controllers/GalleryControllerTests.cs`,
`SECURITY-UPDATES.md`.

Lokale Secrets und vollständige Prüfprotokolle liegen ausschließlich in `.env`
und `.local/`; sie sind nicht Bestandteil der Commits oder des Docker-Build-Kontexts.

## Branches und Commits

Beide Branches: `feature/wedding-customizations`.

Core (bereits separat gepusht):

- `04c52df` — SDK-Auswahl und lokale Ignore-Regeln.
- `e6d13b0` — NuGet-/npm-Sicherheitsupdates mit Lockfiles.
- `74ce7fd` — reproduzierbare Asset-Builds und portable Test-Fixtures.

Community:

- `24c8b14` — Core-Fork, Pointer und dazu passender Paket-/Lockfile-Stand.
- Der nachfolgende technische Commit enthält Launcher, CI, VS Code und Dokumentation;
  seinen Hash zeigt `git log -1`.

## Lokaler Start

Die isolierte MariaDB läuft auf `127.0.0.1:13306`, Memtly auf
**http://localhost:5000**. Benutzer `admin`, Passwort in `.local/dev.env`.
Die bei der Einrichtung gestartete Webserver-PID steht in `.local/app.pid`.

Für erneuten Start: `pwsh -NoProfile -File scripts/dev.ps1 start`.
Für C#-Breakpoints F5 oder an den laufenden .NET-Prozess anhängen.
Details und Testbefehle: [`DEVELOPMENT.md`](../DEVELOPMENT.md).
