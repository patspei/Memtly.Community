# Masonry-Galerie

## Lokal ansehen und aktivieren

Die lokale Galerie **Masonry Demo** ist bereits auf Masonry gestellt:

http://localhost:5000/Gallery?identifier=735e87aeee694edd885014f2a1269745&group=0&order=0

Sie enthält zwölf nummerierte Testbilder mit unterschiedlichen Seitenverhältnissen,
ein freigegebenes Demovideo und einen ausstehenden Gast-Upload. Es wurden nur die
isolierte lokale Testdatenbank und lokale Testuploads verwendet.

Für andere Galerien: als Admin anmelden → Galerieeinstellungen (Zahnrad) →
**Thumbnails / Vorschaubilder → Thumbnail Style → Masonry → Speichern**.
Alternativ steht Masonry auch in den vorhandenen globalen Galerie-Standardwerten
zur Verfügung. Bestehende galerieweise Überschreibungen behalten Vorrang.

Masonry verwendet unabhängig vom alten Spaltenfeld folgende Viewport-Grenzen:

| Viewport | Spalten |
|---|---:|
| Unter 768 px | 1 |
| 768 bis 1199 px | 2 |
| Ab 1200 px | 3 |

Die vorhandene explizite Ansicht **Single** bleibt unverändert. Sie verwendet
weiterhin den bisherigen Single-Stil, auch wenn Masonry als Thumbnail-Stil gewählt ist.

## Umsetzung

`ThumbnailStyle.Masonry = 4` ergänzt den bestehenden Einstellungswert. Tile=1,
Letterbox=2 und Single=3 bleiben stabil. Keine Migration, neue Datenbankspalte oder
zusätzliche npm-Abhängigkeit ist nötig. Andere Stile bleiben erhalten.

Das Grid verwendet gleich breite Spalten, natürliche Bildhöhen und einen
8-px-Abstand. Es verwendet weder CSS Columns noch `grid-auto-flow: dense` und
verschiebt oder dupliziert keine Karten. Dadurch entsprechen DOM-, Tabulator-,
Lightbox- und visuelle Lesereihenfolge weiterhin der Server-Sortierung, jeweils
innerhalb der bestehenden Pending-/Approved- und Gruppierungsabschnitte.
Die Zeilenanfänge sind beim Masonry-Layout versetzt. Extrem unterschiedliche
Formate können kleine geometrisch bedingte Lücken erzeugen: eine Nachverdichtung
mit späteren Bildern würde die verlangte Reihenfolge verletzen.

Das Galerie-Viewmodell speichert nur die Orientierung, keine exakten Pixelmaße.
Die bereits vorhandenen Vorschaubilder behalten das originale Seitenverhältnis.
CSS nutzt ihre intrinsischen Dimensionen (`height: auto`, `object-fit: contain`);
vor dem Laden reserviert `aspect-ratio: auto 1` einen quadratischen Platzhalter.
Das bestehende Fehlerbild wird weiterhin über den vorhandenen Fallback geladen.

`GalleryMasonry` misst alle Karten vor den Schreibzugriffen und berechnet
Grid-Spannen inklusive Abstand. Für normale Seiten sind die Tracks 1 px hoch;
bei langen nachgeladenen Gruppen steigt die Trackgröße automatisch, um die
[Browsergrenzen großer impliziter Grids](https://www.w3.org/TR/css-grid/#overlarge-grids)
zu berücksichtigen. Rundungsabweichungen bleiben unter einer Trackhöhe.

`ResizeObserver` beobachtet Containerbreiten und Kartengrößen; ein
`MutationObserver` erkennt neue oder ersetzte Partial-Inhalte. Bild-`load` und
`error` werden am Galerie-Root abgefangen. Alle Änderungen werden über einen
einzigen `requestAnimationFrame` zusammengefasst. Änderungen der Grid-Höhe allein
lösen keine Neuberechnungsschleife aus. Entfernte Elemente werden abgemeldet;
`pagehide` räumt Beobachter, Listener, Frames und Layoutstile auf; `pageshow`
initialisiert sie erneut, auch beim Browser-Zurück aus dem Cache.

Die bestehende Videovorschau setzt für Masonry keine feste Anchor-Höhe mehr.
Nur dort wird das Play-Symbol per CSS zentriert. Lightbox-Klickhandler,
Admin-Multi-Select, Auswahl-IDs und alle Download-/Upload-Endpunkte bleiben bestehen.
Beim Nachladen wurde zusätzlich der bestehende Fehler bei der jQuery-Leerprüfung für neue
Gruppen korrigiert (`.length === 0`), damit Bilder neuer Gruppen nicht verloren gehen.

## Ausgeführte Prüfungen

- Locked Restore und vollständiger Debug-/Release-Build: erfolgreich.
- .NET-Tests in beiden Konfigurationen: **434 erfolgreich**, keine übersprungen.
  Dazu gehört eine neue Prüfung für die unveränderten bisherigen Einstellungswerte.
- `npm --prefix Memtly.Core/Memtly.Core test`: **9 erfolgreich**. Getestet werden
  Messungen/Rundung, lange Gruppen, spätes Laden und Fehler-Fallbacks, Resize,
  zusammengefasste Frames, neue Karten/Gruppen, ersetzte Partials, ausgeblendete
  Abschnitte sowie vollständiges Aufräumen. Diese Tests verwenden DOM-Testdoubles,
  keinen echten Browser-Renderer.
- Lokaler Debug-Publish über den vorhandenen Launcher: erfolgreich.
- Lokale HTTP-Prüfungen mit Admin und Gast: Auswahlfeld mit gespeichertem Wert 4,
  gerenderte Masonry-Klasse, 13 freigegebene Medien gegenüber 14 Admin-Medien,
  Admin-Auswahlbuttons, Gast ohne Auswahlbuttons, Lightbox-Markup mit bestehendem
  Downloadbutton, Video-Popup, Ablehnung der Pending-Lightbox für Gäste.
- Zwei nachgeladene Seiten mit je sechs freigegebenen Bildern: ursprüngliche
  Reihenfolge erhalten, keine doppelten IDs. Die lokale Demo nutzt Scroll Loading.
- Separate lokale Schlüsselgalerie: richtige Schlüssel erlauben Masonry;
  falsche Schlüssel geben weder Karten noch das Lightbox-Medium frei.
- Die neun JS-Tests sind auch in die GitHub-Pipeline aufgenommen. Es wurde kein
  Push ausgeführt; die Pipeline wurde für diesen Featurestand daher nicht gestartet.

**Die visuelle Browserabnahme steht aus.** Computer Use wurde vom Dienst beendet,
weil er die aktuelle Windows-Browser-URL nicht zuverlässig bestimmen konnte.
Es wurden deshalb keine tatsächlichen Browser-Klicks, Screenshots oder visuellen
Viewport-Prüfungen als erfolgreich gewertet. Die folgenden Schritte bitte lokal
ausführen; Browserkonsole oder Code-Injektion sind dafür nicht erforderlich.

## Manuelle Browserabnahme

1. Demolink oben zunächst in einem privaten Fenster öffnen. Bei mindestens
   1200 px Fensterbreite müssen drei Spalten sichtbar sein. Nummern 01–06 der
   ersten Seite müssen in Lesereihenfolge bleiben; Ränder und Formatbeschriftungen
   der Testbilder müssen vollständig sichtbar sein.
2. Dasselbe Fenster auf etwa 1024 px und dann 390 px verkleinern: zwei bzw.
   eine Spalte, keine Überlagerungen oder horizontalen Scrollbalken. Mehrmals
   zwischen den Größen wechseln, auch nach dem Nachladen und mit Videokarte.
3. Scrollen, bis die zweite und dritte Seite geladen sind: Bilder 07–12 und
   danach das Video müssen erscheinen. Reihenfolge, Abstände und Gruppen prüfen.
4. Ein Hochformatbild öffnen, mit Lightbox-Pfeilen wechseln und schließen.
   Das Video öffnen und abspielen; das Play-Symbol muss nach Resize mittig bleiben.
   Den vorhandenen Einzel-Download der Lightbox prüfen.
5. Als `admin` anmelden (Passwort in `.local/dev.env`). Kontrollieren, dass der
   zusätzliche ausstehende Upload getrennt angezeigt wird. Zwei freigegebene
   Karten über ihre Auswahlbuttons wählen, dann Strg-/Shift-Auswahl und die
   vorhandenen Auswahlaktionen prüfen. Keine Dateien löschen.
6. Ausloggen oder ein weiteres privates Fenster verwenden: der Pending-Upload
   darf nicht in der Galerie oder Lightbox erscheinen, keine Admin-Auswahlbuttons.
7. In der Galerie zwischen Tile, Letterbox und Masonry wechseln und speichern.
   Reload und Browser-Zurück/Vorwärts prüfen. Abschließend Masonry wiederherstellen.
8. Optional Netzwerkdrosselung im Browser aktivieren, neu laden und scrollen:
   langsam geladene Vorschaubilder müssen sich nach dem Laden neu einpassen.

## Historischer Downloadfehler (mit Feature 2a behoben)

**Mit Feature 2a behoben:** Die folgende Beschreibung dokumentiert den damaligen
Befund. Die aktuelle Absicherung und der erfolgreiche Vorher-/Nachher-Test stehen
in [`DOWNLOAD-SECURITY.md`](DOWNLOAD-SECURITY.md).

**Der vorhandene anonyme Gesamt-ZIP-Download enthält in der lokalen Testgalerie
auch den ausstehenden Gast-Upload.** Der Befund wurde zuerst mit Masonry und
anschließend identisch mit Tile reproduziert (13 Approved + 1 Pending im ZIP).
Galerie-HTML und Lightbox verweigern Gästen diesen Pending-Inhalt korrekt.

Im Masonry-Schritt wurden Downloadimplementierung und Berechtigungen gemäß
Featureauftrag noch nicht verändert. Die separate Korrektur ist inzwischen in
Feature 2a enthalten und mit echten ZIP-Inhalten überprüft.
Die produktive Installation wurde weder abgefragt noch verändert. Für die manuelle
Prüfung von Gesamt-ZIPs ausschließlich die erzeugten lokalen Testmedien verwenden.

## Geänderte Quellen

Core: `Enums/ThumbnailStyle.cs`, `Constants/ViewOptions.cs`,
`Views/Gallery/Layouts/Grid.cshtml`, `src/pages/gallery/gallery.js`,
`src/modules/gallery-masonry/{index.js,masonry.mjs,masonry.css}`,
`src/modules/media-viewer/index.js`, `package.json`, `tests/masonry.test.mjs`,
`Memtly.Core.UnitTests/Tests/Helpers/ThumbnailStyleTests.cs`.

Community: Submodule-Pointer, `.github/workflows/docker-image.yml`,
`DEVELOPMENT.md` und diese Dokumentation. Keine generierten Bundles, Secrets,
Testbilder oder lokalen Datenbanken sind versioniert.

Core-Commit: `1cd4ed4` (`feat: add responsive ordered Masonry gallery layout`).
Core und Community bleiben auf `feature/wedding-customizations`; alle
Feature-Commits wurden ausschließlich lokal erstellt, ohne Push oder Deployment.
