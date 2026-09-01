# Contao PfeilShell

Deine pfeilschnelle Kommandozentrale für Update, Installation, Migration,
Cache und viele weitere Helferchen rund um Contao-5-Projekte - alles in
einer einzigen Datei.

## Installation

1. Beide Dateien ins Projekt-Root legen (neben `composer.phar`, `vendor/`, `public/`):
   - `contao.sh`
   - `_contao-lib.sh` (gemeinsame Funktionen, wird von contao.sh gesourced)
2. Ausführbar machen: `chmod +x contao.sh`
3. Für die dunkelgrau/orange TUI-Optik mit echten Checkboxen/Cursor-Menüs:
   `brew install dialog` (macOS) bzw. `apt install dialog` (Server).
   Ohne `dialog`/`whiptail` funktioniert alles trotzdem über ein einfaches,
   nummeriertes Textmenü.
4. Aufruf: `./contao.sh`

Liegt `contao.sh` in einem noch leeren Ordner (kein Contao-Projekt
gefunden), bietet es stattdessen eine **Grundinstallation** an (siehe unten).

## Menü-Übersicht

Contao PfeilShell ist in Abschnitte gruppiert:

- **Migrate & Cache** - `contao:migrate` mit/ohne automatisches Backup,
  Cache leeren (aktuelle Umgebung), Cache leeren für **prod + dev** in einem
  Rutsch, Cache leeren + Migrate in einem Rutsch.
- **System** - PHP-Info (verwendetes Binary, Version, geladene Extensions),
  PHP-Version wählen.
- **Composer** - `show`, `show -l`, `-V`, `selfupdate`, `update`
  (`--profile` / `--dry-run` / normal).
- **Erweiterungen** - Checkbox-Auswahl aus einer konfigurierbaren Paketliste
  (`EXTENSIONS_LIST`, lebt ausschließlich in `.contao.conf` - siehe unten;
  `composer require`, mit Dry-Run-Option und Bestätigung), Live-Suche nach
  Stichwort direkt auf **Packagist** (`composer search`, nicht die lokale
  Liste) mit Checkbox-Auswahl der Treffer, sowie Entfernen aktuell
  installierter Erweiterungen aus der lokalen Liste (`composer remove`).
- **Werkzeuge** - Filesync (`contao:filesync`), Suchindex-Aufbau
  (`contao:crawl`), Test-Mail-Versand (`mailer:send`, Absender/Empfänger
  projektspezifisch merkbar - siehe `.contao.conf` unten).
- **Konfiguration** - `.env.local` anlegen/bearbeiten: `DATABASE_URL` und
  `MAILER_DSN`, mit Erkennung/Vorbefüllung bestehender Werte, maskierter
  Passwort-Anzeige und automatischem Backup vor jedem Schreibvorgang.
- **Datenbank** - Backup erstellen (`contao:backup:create`), Backups
  auflisten (`contao:backup:list`), Restore per Cursor-Menü aus
  `var/backups/` (mit Sicherheits-Backup-Angebot und getippter
  JA-Bestätigung), Migrate-Debugging-Untermenü mit den gängigen
  `--dry-run`-Varianten (`--schema-only`, `--migrations-only`, `-vvv`,
  `--format=ndjson`, `--with-deletes`) sowie ein abgesicherter "echter"
  Lauf ohne Backup für bekannte Problemfälle.

## Grundinstallation (Contao 5.3.x / 5.7.x)

Wird `contao.sh` in einem Ordner ohne bestehendes Contao-Projekt aufgerufen,
erscheint automatisch ein Auswahlmenü für eine Grundinstallation:

- **Contao 5.3.x (LTS)** - benötigt mind. PHP 8.1
- **Contao 5.7.x (LTS)** - benötigt mind. PHP 8.3

Installiert wird per `composer create-project contao/managed-edition . <Version>`.
Dabei wird zuerst geprüft, ob eine lokale **`composer.phar`** im selben
Ordner wie `contao.sh` liegt - das ist gerade auf Hosting-Umgebungen ohne
globales Composer der Normalfall. Erst wenn keine `composer.phar` gefunden
wird, greift `contao.sh` auf ein globales `composer` im PATH zurück. Ist
weder das eine noch das andere vorhanden, lädt `contao.sh` automatisch die
aktuelle `composer.phar` von getcomposer.org herunter (per `wget`, sonst
`curl`) und verwendet diese. Nur wenn auch der Download fehlschlägt (z.B.
weder `wget` noch `curl` vorhanden, oder kein Netzwerkzugriff), bricht die
Grundinstallation mit einer entsprechenden Fehlermeldung ab. Derselbe
Auto-Download-Fallback greift auch im regulären Hauptmenü (bestehendes
Projekt ohne composer.phar und ohne globales `composer`).

Nach erfolgreicher Installation läuft `contao.sh` direkt ins reguläre
Hauptmenü weiter, ein erneuter Aufruf ist nicht nötig.

**Ordner bereits vorbereitet (z.B. eigenes README, `public/`-Grundgerüst,
Projektnotizen)?** Composer bricht `create-project` normalerweise ab, sobald
das Zielverzeichnis nicht komplett leer ist. `contao.sh` erkennt das,
zeigt die vorhandenen Dateien/Ordner an und bietet dann an, trotzdem zu
installieren: Contao wird dazu in einen temporären Unterordner installiert
und die fertigen Dateien werden anschließend nach `$SCRIPT_DIR` verschoben,
**ohne bereits vorhandene Dateien/Ordner zu überschreiben**. Der temporäre
Ordner wird danach automatisch wieder entfernt. Bei Namensgleichheit
zwischen einer eigenen Datei und einer Contao-Kerndatei bleibt die eigene
Version erhalten - so einen Fall bitte anschließend manuell abgleichen.

## Hinweise

- Das Projekt-Root wird automatisch ermittelt (Suche nach
  `vendor/bin/contao-console` oberhalb des Script-Ordners, mit Fallback über
  `composer.json`-Inhalt bzw. `contao/` + `vendor/`-Heuristik) und die
  PHP-Version geprüft (Konfig: `REQUIRED_PHP`, Standard `8.4`, im
  Konfig-Block oben in `contao.sh` - projektspezifisch anpassbar). Technisch
  braucht Contao 5.3 nur PHP 8.1+ und Contao 5.7 nur PHP 8.3+; `REQUIRED_PHP`
  ist bewusst auf `8.4` voreingestellt, damit auch 5.3-Projekte automatisch
  auf einer moderneren, zukunftssichereren Version laufen, sofern das
  Hosting es hergibt. Ist auf einem Host nur eine ältere Version verfügbar,
  wird trotzdem automatisch die höchste gefundene Version genommen (nur mit
  Warnung, kein Abbruch).
- **PHP-Erkennung mit allen gängigen Namensschemata:** `contao.sh` sammelt
  alle auffindbaren PHP-Binaries - generisches `php` im PATH, versionierte
  Binaries in jedem PATH-Verzeichnis in beiden üblichen Schreibweisen
  (`php8.4` UND `php84`), sowie feste Installationspfade für MAMP,
  Homebrew (auch `php@8.4`-Formeln), Plesk und cPanel/EasyApache
  (`ea-php84`) - und wählt daraus automatisch die niedrigste Version, die
  `REQUIRED_PHP` noch erfüllt. Das ist besonders auf Shared-Hosting
  relevant, wo ein generisches `php` im PATH oft fehlt oder auf eine alte
  Version zeigt, während die gewünschte Version nur unter einem
  versionierten Namen erreichbar ist. Composer und `contao-console` laufen
  danach automatisch mit der so ermittelten Version. Bei Bedarf lässt sich
  der Pfad zusätzlich über `PHP_BIN_OVERRIDE` fest vorgeben (hat immer
  Vorrang vor der automatischen Suche).
- **PHP-Version im Menü wählen (System → "PHP-Version wählen"):** listet alle
  gefundenen PHP-Binaries mit ihrer Version auf, alternativ lässt sich ein
  Pfad manuell eingeben. Die Auswahl wird in `.contao.conf` (siehe unten)
  gespeichert und bei jedem künftigen Aufruf automatisch wieder verwendet -
  Composer und `contao-console` laufen sofort mit der gewählten Version.
  Über denselben Menüpunkt lässt sich die Auswahl auch wieder auf die
  automatische Erkennung zurücksetzen. `PHP_BIN_OVERRIDE` im Konfig-Block
  hat weiterhin Vorrang vor dieser Menü-Auswahl.
- **Projektspezifische Konfiguration (`.contao.conf`):** contao.sh selbst
  ist für alle Projekte identisch - keine Paket-, Adress- oder sonstigen
  Vorlieben fest im Code. Nur diese eine, im Projekt-Root liegende Datei
  unterscheidet sich pro Projekt. Sie wird von contao.sh per `source`
  eingebunden (echtes Bash, kein reines Zeilenformat) und überschreibt bei
  Bedarf die Standard-Werte aus dem Konfig-Block. Existiert sie noch nicht,
  legt contao.sh sie beim allerersten Aufruf automatisch an - vorbefüllt mit
  den Test-Mail-Defaults (`TESTMAIL_FROM`/`TESTMAIL_TO`) sowie einer
  Standard-`EXTENSIONS_LIST` (frei anpassbar: Zeilen ergänzen, ändern,
  löschen), damit sofort eine sichtbare, direkt editierbare Datei vorliegt
  statt erst nach der ersten Menü-Interaktion. `contao.sh` selbst enthält
  dagegen kein einziges Paket fest im Code - `EXTENSIONS_LIST` ist dort nur
  ein leeres Array, das ausschließlich als Fallback dient, falls
  `.contao.conf` fehlt oder geleert wurde. `PHP_BIN_SELECTED` wird beim
  Erstaufruf nur eingetragen, wenn tatsächlich ein passendes PHP-Binary
  gefunden wurde - sonst bleibt die Zeile weg und jeder weitere Aufruf
  versucht die automatische Erkennung erneut, bis PHP gefunden oder manuell
  über "PHP-Version wählen" festgelegt wird. Nach Eingabe abweichender
  Test-Mail-Adressen fragt contao.sh zusätzlich, ob sie als neuer Standard
  für dieses Projekt gespeichert werden sollen. Ältere Installationen mit
  der bis V1.0 genutzten separaten `.contao-sh-php.conf` werden beim ersten
  Aufruf automatisch und unbemerkt nach `.contao.conf` migriert.
- Composer wird im Projekt-Root zuerst über `composer.phar` gesucht, dann
  über ein globales `composer` im PATH, zuletzt per Auto-Download (siehe
  oben) - gilt sowohl für das reguläre Hauptmenü als auch für die
  Grundinstallation.
- Jede Sitzung schreibt eine Zusammenfassung ans Ende der Konsole und
  zusätzlich nach `var/log/contao-sh.log`.
- **Backend-Farbschema (dunkelgrau/orange):** Das
  `codesache/contao-backend-user-style-bundle` wird nur installiert
  (`composer require`). Das eigentliche Farbschema wird nicht von diesem
  Script gesetzt, sondern über die Bundle-eigene Konfiguration bzw. die
  Contao-Backend-Einstellungen des jeweiligen Users - das bitte nach der
  Installation manuell einstellen.
- Restore und der "echte" Migrate-Lauf ohne Backup sind als verändernde
  Aktionen klar markiert (rot hervorgehoben) und verlangen eine explizite
  Bestätigung (exakt "JA" eintippen).
- Reine Terminal-Bedienung: kein `osascript`/GUI-Popup, kein `dialog`/
  `whiptail` mehr (bewusst deaktiviert, auch wenn auf dem Host installiert -
  deren generisches Aussehen würde sonst automatisch statt der eigenen,
  gebrandeten Optik mit Logo/Farben/Gruppierung erscheinen). Läuft
  `contao.sh` in einem echten Terminal, wird immer das eigene Menü mit
  Pfeiltasten-Navigation gezeigt: hoch/runter bewegt die Markierung
  (überspringt Abschnitts-Überschriften), Pfeil-rechts oder Enter bestätigt,
  Pfeil-links springt sofort zu "Beenden"/"Zurück"/"Abbrechen" (ohne erst
  dorthin navigieren zu müssen). Alternativ funktioniert weiterhin die
  direkte Zahl-Eingabe + Enter, Esc bricht ab. Läuft das Script nicht
  interaktiv (z.B. per Pipe oder in einer Automatisierung), wird automatisch
  auf reine Zahl + Enter zurückgefallen (ohne Logo, für saubere Logs).
  Weiterklicken bei Ergebnis-/Infobildschirmen erfolgt bewusst **nur per
  Leertaste** (keine Enter-Taste), um versehentliches Weiterklicken bei
  langen Ausgaben zu vermeiden.
- Der einleitende Satz ("Deine pfeilschnelle Kommandozentrale für ...") im
  Hauptmenü und die Bedienungs-Hinweiszeile ("Pfeiltasten hoch/runter, ...")
  erscheinen jeweils nur ein einziges Mal pro Sitzung - beim allerersten
  Zeichnen des jeweils zuerst geöffneten Menüs -, nicht bei jeder Rückkehr
  oder jedem Neuzeichnen durch Pfeiltasten-Navigation, damit die Ansicht
  danach kompakt bleibt.
- Die Zeile "Pfad: $PROJECT_ROOT" ist dagegen dauerhaft sichtbar - sie wird
  bei jedem Menü-Redraw gezeigt (Haupt- und Untermenüs), damit der
  Projektkontext immer erkennbar bleibt.
- Die Menüpunkte selbst werden nummeriert in eckigen Klammern angezeigt
  (z.B. "[ 1] Migrate ..."), passend zum demo-contao.sh-Vorbild.
- **Checkbox-Listen** (Erweiterungen installieren/suchen/entfernen) nutzen
  dieselbe Pfeiltasten-Bedienung wie das Checkbox-Untermenü der
  demo-contao.sh-Vorlage: hoch/runter bewegt den Cursor, Leertaste oder die
  passende Zifferntaste (1-9) markiert/demarkiert einen Eintrag, der letzte
  Eintrag "[ 0] Fertig" übernimmt die Auswahl (per Pfeil-rechts/Enter
  darauf, Ziffer 0, oder als Pfeil-links-Kurzbefehl von überall).
- Farben: fett/Orange (`#f47c00`) für Titel, Abschnitts-Überschriften und
  den Menüpunkt "Beenden", fett/Blau (`#1d70b7`, wie "Code" im Logo) für die
  aktuelle Auswahl/den Cursor in Menüs und Checklisten, fett/Grün für
  erfolgreiche Aktionen und markierte Checkbox-Einträge, fett/Rot für Fehler
  und verändernde Aktionen, gedimmtes Grau für die Befehls-Echo-Zeilen
  ("-> Ausführen: ..."). Farben respektieren `NO_COLOR` und werden
  automatisch deaktiviert, wenn die Ausgabe nicht ins Terminal geht (z.B.
  bei Umleitung in eine Datei).
- Der Hauptmenü-Titel zeigt die Versionsnummer der Toolbox
  ("=== Contao PfeilShell - V1.0 ==="), gepflegt über `CONTAO_SH_VERSION`
  im Konfig-Block von `contao.sh`.
- Kompatibel zu macOS' Standard-Bash 3.2 (kein Homebrew-Bash nötig).

## Getestet

`contao.sh` und `_contao-lib.sh` wurden mit `bash -n` auf Syntaxfehler
geprüft und in einer simulierten Projektstruktur (Stub-`composer.phar`/
`composer.phar`-Datei, Stub-`contao-console`, Stub-`composer`, Stub-`wget`)
end-to-end durchgespielt: Hauptmenü inkl. Gruppierung, Checkbox-Installer
inkl. Dry-Run, Erweiterungssuche gegen Packagist (`composer search`) mit
Pfeiltasten-Checkbox-Auswahl der Treffer, Erweiterungen entfernen (nur tatsächlich
installierte Pakete), Cache leeren für prod + dev, `.env.local`-
Konfiguration, Backup-Erstellung/-Liste/-Restore inkl. Sicherheitsabfragen,
Migrate-Debugging, Test-Mail-Eingabe, composer.phar-Auto-Download bei
fehlender lokaler/globaler Composer-Installation, sowie beide
Grundinstallations-Pfade (mit lokaler `composer.phar` und mit Fallback auf
globales `composer`).

## Nicht enthalten / bewusst offen gelassen

- Die Erweiterungsliste (`EXTENSIONS_LIST`) lebt ausschließlich in
  `.contao.conf` im Projekt-Root (dort ein echtes Bash-Array) - Pakete
  ergänzen/ändern/entfernen einfach dort, `contao.sh` selbst bleibt für alle
  Projekte identisch.
- Migrationsbezogene DB-Änderungen laufen ausschließlich über
  `contao-console`/`contao:migrate`, keine direkten SQL-Befehle.
- Cache leeren und Migrationen laufen ausschließlich über die in diesem
  Script hinterlegten `contao-console`-Befehle - falls dein Projekt eigene
  Shell-Skripte dafür hat, bitte vor genereller Nutzung von
  `contao.sh` kurz Rücksprache halten/anpassen.
