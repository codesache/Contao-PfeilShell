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
  herunterladen/aktualisieren, Selfupdate, Install (Versionen aus
  `composer.lock`), Update (Profil/Dry-Run/normal), `contao-setup`
- **Cache** - Cache leeren (aktuelle Umgebung, oder prod + dev)
- **Datenbank + Migration** - `contao:migrate`, Backup erstellen/auflisten/
  wiederherstellen, Migrate-Debugging
- **Erweiterungen** - installieren (Checkbox-Auswahl), Live-Suche auf
  Packagist, entfernen
- **Werkzeuge** - Filesync, Suchindex, Cron (`contao:cron`), Queue/Messenger
  (fehlgeschlagene Messages anzeigen, erneut verarbeiten, verwerfen),
  Test-Mail, `.env.local` konfigurieren

## DDEV

Liegt das Projekt in einem DDEV-Projekt (`.ddev/config.yaml` im Projekt-Root
oder darüber), erkennt `contao.sh` das beim Start und schickt PHP, Composer
und die Contao-Console in den Container - aufgerufen wird es weiterhin vom
Host aus, im Projekt-Root:

```
cd ~/Projekte/meine-seite
./contao.sh
```

Das ist kein Komfort-Detail: auf einem Entwickler-Rechner ist oft gar kein
PHP installiert, und wo eines liegt, ist es nicht das, gegen das das Projekt
läuft - andere Version, andere Extensions, kein Zugriff auf die Datenbank
des Containers. Ohne Erkennung bricht `contao.sh` dort mit „Kein PHP
gefunden" ab oder arbeitet mit dem falschen PHP.

Im DDEV-Betrieb gilt:

- Läuft der Container nicht, fragt `contao.sh` nach und startet ihn per
  `ddev start`.
- Composer kommt aus dem Container (`ddev composer`) - eine `composer.phar`
  im Projekt-Root wird nicht gebraucht.
- „PHP-Version wählen" schreibt `php_version` per `ddev config` in
  `.ddev/config.yaml` und startet den Container neu, statt ein Binary auf
  dem Host auszuwählen.
- Die Statuszeile zeigt zusätzlich den DDEV-Projektnamen, damit erkennbar
  bleibt, wo die Befehle landen.
- Eine zusätzliche Menügruppe **DDEV** bietet Snapshots (erstellen /
  wiederherstellen), `ddev restart`, `ddev describe` und das Eintragen der
  DDEV-Standardwerte (`DATABASE_URL`, Mailpit-`MAILER_DSN`) in `.env.local`.

Wird `contao.sh` innerhalb des Containers aufgerufen (`ddev ssh`), bleibt
alles beim Alten - dort liegen `php` und `composer` regulär im PATH. Ganz
abschalten lässt sich die Erkennung mit `CONTAO_DDEV_MODE="off"` in
`.contao.conf`.

## Composer

Composer-Aktionen laufen (außerhalb von DDEV) ausschließlich über eine lokale `composer.phar`
im Projekt-Root (kein Fallback auf ein globales `composer` - das ist auf
Hosting-Umgebungen oft eine veraltete Distro-Version). Fehlt sie, lädt
`contao.sh` automatisch die aktuelle Version herunter.

Composer läuft mit `COMPOSER_MEMORY_LIMIT=-1`, weil das CLI-`memory_limit`
auf Hosting-Umgebungen für einen Contao-Abhängigkeitsbaum regelmäßig zu
klein ist. Wer einen festen Wert braucht (z.B. weil der Hoster hart
begrenzt und sonst der OOM-Killer zuschlägt), setzt `COMPOSER_MEMORY_LIMIT`
in `.contao.conf` - der Wert bleibt dann erhalten.

Zugangsdaten in `DATABASE_URL`/`MAILER_DSN` werden prozent-kodiert
geschrieben, damit Passwörter mit `@`, `:`, `/`, `#` oder `%` die DSN nicht
zerlegen.

Projektspezifische Einstellungen (PHP-Version, Test-Mail-Adressen,
Erweiterungsliste) landen automatisch in `.contao.conf` im Projekt-Root -
`contao.sh` selbst bleibt für alle Projekte identisch und enthält keine
projekteigenen Daten fest im Code.

## Mehr Details

Ausführliche technische Dokumentation (alle Menüpunkte im Detail,
`.contao.conf`-Mechanik, PHP-Erkennung & Kompatibilitäts-Check,
Statuszeile, Farbschema, Testprotokoll, Design-Entscheidungen): siehe
README-PfeilShell.md.

---

Ein Projekt von [CodeSache](https://www.codesache.de).
