# Lokale Entwicklung

Das erste Galerie-Feature ist lokal verfügbar: Aktivierung, Demolink und
Browser-Prüfschritte stehen in [`docs/MASONRY.md`](docs/MASONRY.md).

Die Entwicklungsumgebung verwendet ausschließlich lokale Testdaten. Sie hat keine
Verbindung zur produktiven Installation, zu Dokploy oder zu Cloudflare.

## Voraussetzungen und Clone

- .NET SDK 10 (gültige Auswahl über `global.json`, C# 14 durch `net10.0`).
- Node.js 22 oder neuer, npm, Git und PowerShell 7 (`pwsh`).
- Docker Desktop mit Linux-Engine unter Windows; lokaler Docker-Socket unter Linux.
- VS Code mit der empfohlenen C#-Erweiterung für Breakpoints.

```powershell
git clone --branch feature/wedding-customizations --recurse-submodules https://github.com/patspei/Memtly.Community.git
cd Memtly.Community
git -C Memtly.Core switch feature/wedding-customizations
```

Ein rekursiver Clone verwendet den committed Core-Stand. `git submodule update`
checkt diesen normalerweise detached aus: vor Core-Änderungen immer den eigenen
Branch auswählen. Kein `--remote` für einen reproduzierbaren Checkout verwenden.
Beide `origin`-Remotes zeigen auf `patspei`.

## Start und Debugging

Aus dem Workspace-Hauptverzeichnis:

```powershell
pwsh -NoProfile -File scripts/dev.ps1 start
```

Der Befehl erzeugt beim ersten Start zufällige lokale Zugangsdaten, startet die
MariaDB mit Healthcheck, führt Locked Restore und Debug-Publish aus und startet
Memtly im Vordergrund. Standardadresse: **http://localhost:5000**. Ist der Port
beim ersten Einrichten belegt, wird der nächste freie Port gespeichert. Eigene
Ports vor dem ersten Start: `pwsh -File scripts/dev.ps1 init -Port 5010 -DatabasePort 13310`.
Bei späteren Portkonflikten die gespeicherten lokalen Portwerte konsistent ändern;
Secrets nicht neu generieren, solange die Testdatenbank weiterverwendet wird.

Für Breakpoints: F5 → **Memtly: local MariaDB (Debug)**. Der Task `memtly: prepare`
startet die Datenbank und veröffentlicht Debug-Code samt PDBs nach `.local/app`.
Der Debugger lädt `.local/dev.env` und verwendet `.local/app` als Arbeitsverzeichnis.
Keine zweite Instanz auf demselben Port starten. Ein bereits laufender Prozess
kann über **Debug: Attach to a .NET 5+ or .NET Core process** ausgewählt werden.

Admin-Benutzername: `admin`. Das zufällige Passwort steht unter
`ACCOUNT_ADMIN_PASSWORD` in `.local/dev.env`. Es wird nicht im Terminal ausgegeben.
Diese Datei und `.env` niemals einchecken oder weitergeben.

```powershell
pwsh -File scripts/dev.ps1 db-up    # Nur die lokale Datenbank starten
pwsh -File scripts/dev.ps1 prepare  # DB + Locked Restore + Debug-Publish
pwsh -File scripts/dev.ps1 db-down  # Lokale DB stoppen, Daten bleiben erhalten
```

Strg+C beziehungsweise Stop Debugging beendet den Webserver. Für eine bei der
Einrichtung im Hintergrund gestartete Instanz steht deren PID in `.local/app.pid`;
vor dem Beenden prüfen, dass diese noch zur lokalen Memtly-Instanz gehört.

## Isolation und Daten

- Compose-Projekt: `memtly-wedding-dev`; Datenbank und Benutzer: `memtly_dev`.
- MariaDB 11.4 ist per Image-Digest fixiert. Der Port wird nur an
  `127.0.0.1:13306` gebunden; die tatsächliche Wahl steht in `.env`.
- Docker-Volume: `memtly-wedding-dev_database`. `db-down` löscht es nicht.
- Uploads, Vorschaubilder und temporäre Testdateien liegen unter
  `.local/app/{uploads,thumbnails,temp,custom_resources}`. Diese Verzeichnisse
  bleiben bei erneutem Publish erhalten; `.local` nicht als Build-Cleanup löschen.
- Data-Protection-Schlüssel liegen in `.local/app/config`; FFmpeg in `.local/ffmpeg`.
  FFmpeg kann beim ersten Start heruntergeladen werden.
- Verschlüsselungsschlüssel, Salt und Admin-Passwort werden zufällig erzeugt und
  persistent gespeichert. Sie müssen zur Testdatenbank passen.
- Windows: `.local` und `.env` sind auf den aktuellen Benutzer und SYSTEM
  beschränkt. Unter Unix erhalten die Secret-Dateien Modus 600.
- Memtlys dokumentierte Konfigurationsaliases werden explizit gesetzt, damit
  geerbte Datenbankvariablen sie nicht überschreiben. Der Launcher akzeptiert nur
  die erzeugte Loopback-Verbindung zur Testdatenbank. Remote-Docker-Kontexte sowie
  `DOCKER_HOST` und `DOCKER_CONTEXT` werden abgewiesen.
- HTTPS-Zwang, Registrierung, externe Fehlerberichte und Benachrichtigungen sind
  lokal ausgeschaltet. Produktive Zugangsdaten werden nirgends benötigt.
- Git und Docker-Build-Kontext schließen lokale Secrets, IDE-State und Laufzeitdaten aus.

Nicht direkt ohne diese Konfiguration starten: `appsettings.json` enthält die
unveränderten Upstream-Standardwerte. Einstellungen werden zum Teil in der DB
gespeichert. `Sync_From_Config` bleibt aus, damit lokale Änderungen erhalten bleiben.
ASP.NET meldet ohne XML-Encryptor einen unverschlüsselten lokalen
Data-Protection-Keyring; er ist durch die Dateiberechtigungen geschützt.

## Restore, Builds, Tests und Audit

```powershell
dotnet restore Memtly.Community.sln --locked-mode
dotnet build Memtly.Community.sln -c Debug --no-restore
dotnet test Memtly.Community.sln -c Debug --no-build --no-restore
dotnet build Memtly.Community.sln -c Release --no-restore
dotnet test Memtly.Community.sln -c Release --no-build --no-restore
dotnet package list --project Memtly.Community.sln --vulnerable --include-transitive --no-restore
Push-Location Memtly.Core/Memtly.Core
npm ci
npm test
npm audit
Pop-Location
docker --context desktop-linux build -t memtly-wedding-dev:local -f Memtly.Community/Dockerfile .
```

Builds benötigen Netzwerkzugriff für `npm ci`. Debug und Release nacheinander
ausführen: beide erzeugen denselben Webpack-Ausgabeordner. Der Build registriert
erst nach Webpack die erzeugten statischen Assets samt aktuellem Manifest.

Für beabsichtigte NuGet-Updates Paketversionen ändern, dann einmal
`dotnet restore Memtly.Community.sln --force-evaluate` ausführen, alle betroffenen
Lockfiles prüfen und anschließend mit `--locked-mode` verifizieren. Normale
Entwicklung und CI verwenden die committed Lockfiles. `NuGetAudit` bleibt aktiv.

## Git und CI

Änderungen im Submodule unabhängig committen und **zuerst Core pushen**:

```powershell
git -C Memtly.Core push -u origin feature/wedding-customizations
git add Memtly.Core
git commit -m "chore: update Core submodule"
git push -u origin feature/wedding-customizations
```

Nur Entwicklungsbranches pushen, kein Force-Push. Die GitHub-Pipeline prüft
.NET 10, Debug/Release, Tests und NuGet-Audit. Nur Pushes auf den Entwicklungsbranch
veröffentlichen Images als `ghcr.io/patspei/memtly.community:wedding-dev` und mit
Commit-SHA; Pull Requests veröffentlichen keine Images. Der Workflow enthält keinen
produktiven Deployment-Schritt; Serverkonfigurationen werden nicht verändert.

Die ausgeführten Prüfungen und verbleibenden Warnungen stehen in
[`docs/SETUP-REPORT.md`](docs/SETUP-REPORT.md). Lokale vollständige Protokolle liegen
unter `.local/verification/` und sind nicht versioniert.
