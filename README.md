# Contao PfeilShell

Deine pfeilschnelle Kommandozentrale für Update, Installation, Migration,
Cache und viele weitere Helferchen rund um Contao-5-Projekte - alles in
einer einzigen Datei.

## Installation

1. Beide Dateien ins Projekt-Root legen (neben `composer.phar`, `vendor/`, `public/`):
   - `contao.sh`
   - `_contao-lib.sh` (gemeinsame Funktionen, wird von contao.sh gesourced)
2. Ausführbar machen: `chmod +x contao.sh`
3. Aufruf: `./contao.sh`

Liegt `contao.sh` in einem noch leeren Ordner (kein Contao-Projekt
gefunden), bietet es stattdessen eine Grundinstallation an (Contao 5.3.x
LTS oder 5.7.x LTS, per `composer create-project`).

## Menü-Übersicht

- **System** - PHP-Info, PHP-Version wählen
- **Composer** - installierte Pakete/Updates anzeigen, `composer.phar`
  herunterladen/aktualisieren, Selfupdate, Update (Profil/Dry-Run/normal)
- **Cache** - Cache leeren (aktuelle Umgebung, oder prod + dev)
- **Datenbank + Migration** - `contao:migrate`, Backup erstellen/auflisten/
  wiederherstellen, Migrate-Debugging
- **Erweiterungen** - installieren (Checkbox-Auswahl), Live-Suche auf
  Packagist, entfernen
- **Werkzeuge** - Filesync, Suchindex, Test-Mail, `.env.local` konfigurieren

Composer-Aktionen laufen ausschließlich über eine lokale `composer.phar`
im Projekt-Root (kein Fallback auf ein globales `composer` - das ist auf
Hosting-Umgebungen oft eine veraltete Distro-Version). Fehlt sie, lädt
`contao.sh` automatisch die aktuelle Version herunter.

Projektspezifische Einstellungen (PHP-Version, Test-Mail-Adressen,
Erweiterungsliste) landen automatisch in `.contao.conf` im Projekt-Root -
`contao.sh` selbst bleibt für alle Projekte identisch und enthält keine
projekteigenen Daten fest im Code.

## Mehr Details

Ausführliche technische Dokumentation (alle Menüpunkte im Detail,
`.contao.conf`-Mechanik, PHP-Erkennung & Kompatibilitäts-Check,
Statuszeile, Farbschema, Testprotokoll, Design-Entscheidungen): siehe
[README-PfeilShell.md](README-PfeilShell.md).

---

Ein Projekt von [CodeSache](https://www.codesache.de).
