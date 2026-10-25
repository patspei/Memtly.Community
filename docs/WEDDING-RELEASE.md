# Dokploy-Update

Nur beim bestehenden Memtly-Service die `image:`-Zeile durch das im Release-Bericht
genannte `ghcr.io/patspei/memtly.community:<vollständige-Commit-SHA>` ersetzen.
Service-Name, MariaDB-Service, Netzwerke, Domain, Port 5000, Environment und alle
bestehenden Volume-Zuordnungen unverändert lassen. Kein Compose-Reset, kein
`down -v`, keine „Fresh Volumes“. Die Produktion wurde nicht verändert.

Bei gemounteter alter appsettings.json oder abweichenden Galerie-Namen diese Werte
im **bestehenden** Environment ergänzen (bestehende Einträge behalten):

```yaml
# Im vorhandenen Memtly-Service, kein neuer Service:
image: ghcr.io/patspei/memtly.community:<vollständige-Commit-SHA>
# Zusätzliche Environment-Einträge, falls nötig:
environment:
  Wedding__Enabled: "true"
  Wedding__ProfessionalGallery: "Unsere Hochzeit"
  Wedding__GuestGallery: "Eure Hochzeitsfotos"
  Wedding__PrivateGallery: "Nur für Julia & Patrick"
```

Diese Werte sind bereits Image-Defaults. Statt Namen können eindeutige bestehende
Galerie-Identifier verwendet werden. Keine Galerie-Keys oder Admin-Zugangsdaten
hinzufügen. Bestehende Galerie-Keys werden weiterhin über den Galeriezugang geprüft.
Die private Galerie muss eine Drop-Gallery sein; die anderen beiden Basic-Galerien.
Gäste-Uploads benötigen weiterhin aktivierte Uploads in der jeweiligen Galerie.

Hero austauschen: Bild in das bestehende `custom_resources`-Volume legen und
`Wedding__HeroImage=/custom_resources/hochzeit-hero.jpg` setzen. Der lokale
Bildplatzhalter im Image ist `/_content/Memtly.Core/images/DemoImage.png`.

Vergleich mit Release 1.0.7.6: Arbeitsverzeichnis `/app`, Port `5000`, Originale
`/app/uploads`, Vorschauen `/app/thumbnails`, Ressourcen `/app/custom_resources`,
Konfiguration `/app/config` und temporäre Dateien `/app/temp` sind unverändert.
Alle bisher verwendeten Environment-Namen, DB-Verbindung, Verschlüsselungswerte
und Secrets bleiben erhalten. Keine neuen EF-Migrationsdateien oder Schemaänderungen;
die vorhandene automatische Migration beim Start bleibt bestehen.
Absichtliche Verhaltensänderung: alte direkte `/uploads`-/`/thumbnails`-Links sind
gesperrt. Geschützte `/Media/...`-Routen ersetzen diese Links. Gäste-Uploads in der
konfigurierten Gäste-Galerie werden immer moderiert.

Vor dem Update Uploads kurz pausieren bzw. nur den Memtly-Service stoppen. MariaDB
mit `mariadb-dump --single-transaction --routines --events --triggers` sichern
(bestehende Zugangsdaten verwenden), Dump prüfen und sicher außerhalb des VPS
kopieren. Zusätzlich die **bestehenden** Foto-/Ressourcen-/Config-Volumes sowie
Compose und Environment sichern; eine bloße Kopie eines laufenden MariaDB-Datenvolumes
ersetzt keinen konsistenten Dump. Keine produktiven Volumes umbenennen oder neu anlegen.

Rollback: nur Memtly auf das zuvor notierte Image bzw. `memtly/memtly:1.0.7.6`
zurückstellen und mit denselben Volumes/Secrets starten. Es gibt keine neue
Schema-Migration zurückzunehmen. DB-/Foto-Backups nur bei tatsächlicher Beschädigung
gemeinsam auf den Sicherungsstand zurückspielen; neuere Uploads vorher separat
sichern. Das alte Image besitzt die frühere Downloadabsicherung nicht.

Die produktive Compose-Datei war lokal nicht vorhanden; dieser Patch beschreibt
die minimale Änderung, ohne unbekannte Service- oder Volume-Namen zu erfinden.
