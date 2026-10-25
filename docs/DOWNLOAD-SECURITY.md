# Serverseitige Medien- und Downloadabsicherung — 25. Oktober 2026

## Bestätigte Ursachen

1. `DownloadGallery` scannte Verzeichnisse. `ShowPendingUploads` konnte dabei auch
   anonymen ZIP-Anfragen Pending-Dateien hinzufügen. Eine leere Schnittmenge bei
   Filtern war außerdem nicht zuverlässig von „alle Dateien“ getrennt.
2. Die Drop-Sonderbehandlung hing an `IsBasicUser`, statt jeden Zugriff auf das
   konkrete Medium zu prüfen. Einzelmedien und Lightbox verwendeten andere Regeln.
3. Collection-Verzeichnisse wurden ohne unabhängige Autorisierung der enthaltenen
   Galerien übernommen. Die Collection-Erweiterung im Repository übergab zudem
   eine Collection-ID als Benutzer-ID an `GetCollections`.
4. `/uploads`, `/thumbnails` und `/temp` wurden vor der Authentifizierung statisch
   ausgeliefert. Ein bekannter Dateipfad umging damit die gesamte Galerieprüfung;
   auch Range-/HEAD-Requests und temporäre Exporte waren betroffen.
5. Abgelehnte, aufbewahrte Dateien verloren ihren Datenbankeintrag. Außerdem
   verwendeten Vorschaubilder nur den Dateibasename: unterschiedliche Originale
   mit gleichem Basename konnten dasselbe Thumbnail überschreiben.
6. Eine Download-Logmeldung enthielt den übergebenen Secret-Key. Framework-
   Requestdiagnostik konnte Querystrings und die Einstellungs-Audits konnten
   geheime Konfigurationswerte protokollieren.

Der ursprüngliche Fehler wurde auf der alten lokalen Instanz nochmals bestätigt:
**14 ZIP-Einträge, davon 1 Pending**. Nach dem Update derselben Testgalerie:
**13 ZIP-Einträge, 0 Pending, 0 Rejected**.

## Gemeinsame Berechtigungsregeln

`MediaAccessHelper` ist pro Request registriert. Die Datenbank bestimmt Galerie,
Besitzer, Uploader und Status; URL, Dateiname, Gruppierung und Filter vergeben
keine Rechte. `ShowPendingUploads` steuert weiterhin die Darstellung bereits
berechtigter Pending-Uploads und wird vom ZIP-Autorisierer nicht ausgewertet.

| Benutzer / Galerie | Vorschau und Original | ZIP / expliziter Download |
|---|---|---|
| Anonym, Basic mit gültigem Zugang | Nur Approved | Nur Approved, sofern Download erlaubt |
| Angemeldet, fremde Basic | Approved und eigene Pending-Vorschau wie bisher | Nur Approved, sofern erlaubt |
| Anonym, Drop | Keine vorhandenen Medien oder ursprünglichen Dateipfade | Verweigert; Upload bleibt möglich |
| Angemeldeter Drop-Uploader | Eigene Approved-/Pending-Medien | Nur eigene Approved, sofern erlaubt |
| Authentifizierter Galerieeigentümer | Eigene Galerie verwalten, alle bekannten Status | Eigene Galerie, alle Status |
| Privilegierte Review-Rolle | Mit `Review.View` auch nicht freigegebene Medien | Nicht freigegebene Medien nur mit zusätzlichem `Gallery.Download` |
| Admin mit Review-/Downloadrechten | Approved, Pending, Rejected | Approved, Pending, Rejected |

„All Galleries“ setzt authentifizierte privilegierte `ViewAllGallery`-Rechte voraus.
Für Collections wird zuerst der Container geprüft und anschließend jede enthaltene
Galerie separat. Ein Collection-Schlüssel oder die Eigentümerschaft an der
Collection erteilt keine Rechte an einer fremden geschützten oder privaten Galerie.
Explizite bestehende Shares und unabhängig gültige Galeriezugänge bleiben wirksam.
Verschachtelte Collections werden nicht automatisch expandiert.

Eine sichtbare freigegebene Originaldatei enthält naturgemäß herunterladbare Bytes.
`Gallery.Download=false` sperrt ZIP und den expliziten Attachment-Download; es kann
das Speichern eines bereits berechtigt angezeigten Bildes technisch nicht verhindern.

## Geschützte Auslieferung

Die vorhandenen Speicherverzeichnisse bleiben außerhalb von `wwwroot`; Dateien
werden nicht verschoben. Die Umstellung entspricht dem Grundsatz der
[ASP.NET-Core-Dokumentation zur Static-File-Autorisierung](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/static-files?view=aspnetcore-10.0#static-file-authorization):
geschützte Dateien benötigen eine autorisierte Auslieferung statt eines öffentlichen
Static-File-Providers.

| Endpoint | Absicherung |
|---|---|
| `POST /Gallery/DownloadGallery` | Datenbankbasierte erlaubte Dateiliste; vollständiges ZIP, Gruppe und Auswahl verwenden dieselbe Schnittmenge |
| `GET/HEAD /Media/Original/{id}` | Leserecht am konkreten Medium vor Zugriff auf die Datei; Range-Unterstützung bleibt erhalten |
| `GET /Media/Original/{id}?download=true` | Zusätzlich Downloadrecht; Originaldateiname per Content-Disposition |
| `GET/HEAD /Media/Thumbnail/{id}` | Dasselbe Leserecht; Vorschau aus genau diesem berechtigten Original |
| `GET /MediaViewer/GalleryItem` | Gemeinsame Galerie-/Statusprüfung vor Lightbox-Metadaten und Medien-URLs |
| `GET /MediaViewer/ReviewItem` | Bestehende Review-Rolle plus gemeinsame Medienprüfung |
| `POST /MediaViewer/Like`, `Comment` | Zusätzlich Leserecht am betreffenden Medium |
| `GET /Media/CustomResourceThumbnail/{id}` | Authentifizierter, für diese Ressource berechtigter Besitzer/Verwalter |
| Alte `/uploads/...`, `/thumbnails/...`, `/temp/...` | Immer 404 vor Static-File-Middleware, auch für Admins; kodierte Pfade und versehentliche RCL-Kopien werden ebenfalls gesperrt |

Alle Galerie-, Slideshow-, Review- und Lightbox-Verweise verwenden Medien-IDs.
Alte Original-/Thumbnail-Links werden bewusst nicht weiter öffentlich bedient.
Öffentliche Branding-Assets unter `custom_resources` bleiben als solche erhalten;
Galerieoriginale und temporäre Dateien werden darüber nicht veröffentlicht.

Ein korrekt validierter Galerie-Schlüssel gewährt Zugriff über die bestehende
serverseitige ASP.NET-Session. Die Session speichert nur einen Digest des aktuellen
Schlüssels. Ein Schlüsselwechsel entzieht diesen Zugang beim nächsten Request.
Medien-URLs benötigen keinen Schlüssel oder Zugangstoken. Für kompatible direkte
ZIP-/Lightbox-Aufrufe kann der bestehende Schlüsselparameter weiter validiert werden.

Dateinamen und Galerie-Identifier werden als einzelne Datenbankpfadsegmente
validiert. Absolute Pfade, Traversal, Separatoren, Alternate-Data-Stream-Syntax
und Reparse Points/Symlinks werden nicht als Medienpfade akzeptiert. ZIP-Quellen
werden auf echte kanonische Unterpfade begrenzt; Archivpfade verwenden `/`.
Unbekannte Status oder Galerietypen geben keine Medien frei.

Antworten verwenden `Cache-Control: private, no-store` und `Vary: Cookie`.
Jeder neue GET-, HEAD- oder Range-Request wird autorisiert, auch wenn die
Vorschaudatei bereits im Cache liegt. Vorschauen sind nach Medien-ID und Version
des Originals getrennt und werden atomar erzeugt. Alte, möglicherweise kollidierte
Basename-Thumbnails werden für Galerie-Medien nicht wiederverwendet.

## Review, Logging und Kompatibilität

- Keine Schemaänderung/Migration: `Rejected=4` ergänzt den bestehenden numerischen
  Status, ohne frühere Werte zu ändern. Neue behaltene Ablehnungen behalten ihren
  Datenbankeintrag. Bei ausgeschalteter Aufbewahrung werden Datei und Eintrag wie
  bisher entfernt. Normale Galerieansichten zeigen Rejected weiterhin nicht.
- Historische Dateien im `Rejected`-Ordner ohne Datenbankeintrag bleiben nur im
  ZIP eines für diese Galerie berechtigten Verwalters verfügbar. Sie erhalten
  keinen anonymen Medien-Endpunkt und werden nicht in Gäste-Listen übernommen.
- Download-Logs enthalten Galerie-ID und Ergebnisstatus, keine Schlüssel oder
  clientseitigen Filterinhalte. Einstellungs-Audits speichern keine Werte mehr.
- Verbatim Request-/MVC-Diagnostik mit Querystrings/Argumenten wird unterhalb von
  Warning gefiltert. Fachliche Diagnosemeldungen bleiben erhalten. Ein absichtlich
  übergebenes Test-Credential wurde in den lokalen App-Logs **nicht** gefunden.
- Masonry, Bildreihenfolge, Kartenklassen, Auswahl-IDs und die vorhandenen
  Upload-/Downloadaktionen bleiben bestehen. Es wurde keine Gast-Mehrfachauswahl
  und kein neuer Bestätigungsdialog implementiert.

## Geänderte Dateien

Im Core (Pfade relativ zur Core-Repository-Wurzel):

- `Memtly.Core/Helpers/`: neue `MediaAccessHelper.cs`, `GalleryDownloadHelper.cs`,
  `MediaFileStore.cs`, `MediaThumbnailHelper.cs`; angepasstes `Database/EFDatabaseHelper.cs`.
- `Memtly.Core/Controllers/`: neue `MediaController.cs`; angepasste
  `GalleryController.cs`, `MediaViewerController.cs`, `AccountController.cs`, `BaseController.cs`.
- `Memtly.Core/Middleware/PrivateMediaMiddleware.cs`,
  `Attributes/RequiresSecretKeyAttribute.cs`, `Configurations/DependencyInjectionConfiguration.cs`,
  `Configurations/LoggingConfiguration.cs`, `Extensions/StartupExtensions.cs`,
  `Enums/GalleryItemState.cs`, `Models/Database/SearchModels.cs` (jeweils unter `Memtly.Core/`).
- `Memtly.Core/Views/Account/Partials/CustomResources.cshtml`, `PendingReviews.cshtml`;
  `Views/Gallery/GalleryOptions.cshtml`, `Views/Gallery/Layouts/Grid.cshtml` und
  `src/modules/media-viewer/index.js` (jeweils unter `Memtly.Core/`).
- `Memtly.Core.UnitTests/Tests/Controllers/GalleryControllerTests.cs`,
  neue `Controllers/MediaSecurityTests.cs` und `Helpers/GalleryRepositorySecurityTests.cs`
  (die beiden letzten Pfade relativ zu `Memtly.Core.UnitTests/Tests/`).

Im Community-Repository: Core-Submodule-Pointer, `DEVELOPMENT.md`,
`docs/MASONRY.md` und dieser Bericht. Keine generierten/minifizierten Dateien,
Paketversionen oder Lockfiles wurden geändert.

## Verifikation

- Debug- und Release-Build der vollständigen Solution: erfolgreich.
  Jeweils 80 nicht sicherheitsbezogene Warnungen (Nullable-Analysen, veraltete
  APIs und NuGet-Paketbereinigung), 0 Fehler. Die neuen HTTP-Testhosts verwenden
  wie die vorhandene Anwendung noch die kompatible, als veraltet markierte
  `UseStaticFiles`-API; eine Asset-Pipeline-Migration ist nicht Teil dieses Fixes.
- **472 .NET-Tests je Konfiguration**, 0 fehlgeschlagen, 0 übersprungen.
  Darin enthalten: 37 HTTP-/ZIP-Fälle mit echtem lokalem Kestrel, Cookie-/Session-
  Verhalten, realen Dateiinhalten, No-Store, HEAD, Range, Filter-Traversal,
  Statuswechsel, Collection-/Drop-/All-Galleries-Regeln und Legacy-Static-Kopien;
  außerdem 1 SQLite-In-Memory-Test für Rejected- und Collection-Abfragen.
- Alle 434 bisherigen Tests sind weiterhin vorhanden und erfolgreich. Ihre
  Controller-Fixtures enthalten jetzt echte Collection-Kindbeziehungen und
  explizite Rollenrechte statt widersprüchlicher pauschaler Identity-Mocks.
- **9 Masonry-JavaScript-Tests** erfolgreich.
- NuGet-Audit aller 7 Projekte inklusive transitiver Pakete: **0 bekannte
  Schwachstellen**; npm-Audit: **0**. Keine neuen Paketabhängigkeiten/Lockfile-Updates.
- Reale lokale MariaDB-/HTTP-Prüfung: Gäste-ZIP nur Approved; Admin-ZIP mit
  Approved/Pending/Rejected; Gast-Uploads und Approve/Reject mit Aufbewahrung;
  Drop-Gast ohne Karten/Original/Vorschau/ZIP; Collection ohne Zugriff auf private
  Kinder; gültiger privater Sessionzugang; fremder Zugriff verweigert;
  Video-Range HTTP 206; Legacy-Pfade HTTP 404. Der ursprüngliche Fehler ist behoben.
- Visuelle Browser-Klicktests wurden in diesem Schritt nicht ausgeführt.
  Siehe manuelle Abnahme unten. Produktionssysteme wurden nicht angesprochen.

Vollständige lokale Protokolle: `.local/verification/media-security-*`,
Vorher-/Nachher-ZIPs: `download-before-security-fix.zip` und
`download-after-security-fix.zip` im selben geschützten Verzeichnis.

```powershell
dotnet test Memtly.Community.sln -c Debug --no-build --no-restore
dotnet test Memtly.Community.sln -c Debug --no-build --no-restore --filter "FullyQualifiedName~MediaSecurityTests|FullyQualifiedName~GalleryRepositorySecurityTests"
npm --prefix Memtly.Core/Memtly.Core test
```

## Manuelle lokale Abnahme

1. In einem privaten Browserfenster die [Masonry-Demo](http://localhost:5000/Gallery?identifier=735e87aeee694edd885014f2a1269745&group=0&order=0)
   öffnen. Bilder und Lightbox müssen funktionieren; der Gesamt-ZIP muss genau
   13 freigegebene Medien enthalten. Kein `Pending`-/`Rejected`-Inhalt.
2. Die [neue Basic-Testgalerie](http://localhost:5000/Gallery?identifier=54d6f428795741a19192d162398c37c3)
   hat ein freigegebenes, ein ausstehendes und ein aufbewahrtes abgelehntes Bild.
   Anonym sind nur das freigegebene Bild und dessen ZIP verfügbar.
3. Anonym [Pending-Original](http://localhost:5000/Media/Original/17),
   [Pending-Vorschau](http://localhost:5000/Media/Thumbnail/17) und
   [Rejected-Original](http://localhost:5000/Media/Original/18) öffnen: jeweils 404.
   Anschließend als Admin anmelden und berechtigte Medien/ZIPs prüfen.
4. [Drop-Testgalerie](http://localhost:5000/Gallery?identifier=46b4f822397c43008631b816300016b0)
   anonym öffnen: Upload bleibt möglich, vorhandene Medien bleiben verborgen.
   [Bekanntes Drop-Original](http://localhost:5000/Media/Original/19) bleibt anonym 404.
5. Als Admin in der Galerieverwaltung „Local Security Collection …“ öffnen.
   Für die Gastprüfung den Collection-Link in einem getrennten privaten Fenster
   öffnen, ohne vorher die geschützte Kindgalerie freizuschalten. Das ZIP darf nur
   das eine freigegebene öffentliche Testbild enthalten.
6. Als Admin in der Masonry-Demo mehrere Bilder auswählen und die bestehenden
   Auswahl-/Gruppendownloads testen. In der Basic-Testgalerie enthält der Admin-
   Gesamtdownload alle drei Status. Review und neuen Gast-Upload zusätzlich prüfen.
7. Im Browser-Netzwerk-Panel bei Bedarf prüfen: Bilder laden über `/Media/...`,
   ohne Schlüsselparameter, mit `no-store`; Video-Seek erzeugt berechtigte
   Range-Requests. Keine Browserkonsole oder Code-Injektion ist erforderlich.

## Grenzen und späteres Deployment

Bereits vorher heruntergeladene oder fremd gecachte Dateien lassen sich durch
diesen Patch nicht zurückholen. Vor einer späteren öffentlichen Freigabe müssen
eventuelle alte CDN-/Proxy-Caches und zusätzliche direkte Static-Aliase auf die
Medienvolumes geprüft bzw. entfernt werden. Ein vorgelagerter Webserver darf die
private Auslieferung nicht am ASP.NET-Prozess vorbei übernehmen. Es wurden keine
Server-, Dokploy-, Cloudflare- oder Produktionsänderungen vorgenommen.

Die Zugangsgrants verwenden die vorhandene serverseitige Session. Für mehrere
App-Instanzen ist ein gemeinsamer Session-Store bzw. die bereits sonst erforderliche
Session-Zuordnung nötig. Ohne passenden Sessionzugang wird verweigert, nicht freigegeben.

Beide Repository-Branches bleiben `feature/wedding-customizations`.
Core-Sicherheitscommit: `19b3766` (`fix: authorize gallery media and archive downloads consistently`).
Der Community-Commit übernimmt diesen Submodule-Pointer und die Dokumentation.
Es erfolgt kein Push und kein Deployment.
