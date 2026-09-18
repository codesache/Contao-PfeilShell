#!/bin/bash
#
# contao.sh - Contao PfeilShell
# ---------------------------------------------------------------------------
# Deine pfeilschnelle Kommandozentrale für Contao-5-Projekte: Grundinstallation,
# Migrate/Cache, Composer-Befehle, Erweiterungs-Installation per Checkbox,
# Filesync, Suchindex, Test-Mail, .env.local-Konfiguration und alle
# Datenbank-Werkzeuge (Backup/Restore/Migrate-Debugging) - alles in einer Datei.
#
# Ablage: im Projekt-Root, neben composer.phar / vendor / public.
# Aufruf:  bash contao.sh   (oder ausführbar machen: chmod +x contao.sh)
# Wird contao.sh in einen leeren Ordner gelegt und dort aufgerufen, bietet
# es eine Grundinstallation (Contao 5.3.x / 5.7.x) an.
#
# Ein Projekt von CodeSache - https://www.codesache.de
# ---------------------------------------------------------------------------

# ===================== KONFIGURATION (projektspezifisch) ===================

# Bevorzugte/mindestens gewünschte PHP-Version - steuert zwei Dinge:
#   1. Welche PHP-Version die automatische Erkennung bevorzugt auswählt
#      (die NIEDRIGSTE gefundene Version, die dies noch erfüllt - kein
#      unnötig neueres PHP als hier eingestellt).
#   2. Die Warnung, falls die tatsächlich gefundene/gewählte Version
#      niedriger ist.
# Technisch braucht Contao 5.3 nur PHP 8.1+ und Contao 5.7 nur PHP 8.3+ -
# hier bewusst höher als 8.3/8.4 eingestellt, damit auch 5.3-Projekte auf
# einem moderneren, zukunftssichereren PHP laufen, sofern die Hosting-
# Umgebung das hergibt. Ist auf einem Host nur eine ältere Version
# verfügbar, wird trotzdem automatisch die höchste gefundene Version
# genommen (nur mit Warnung) - contao.sh bricht deswegen nicht ab. Bei
# Bedarf pro Projekt hier anpassen (z.B. auf "8.1" senken).
REQUIRED_PHP="8.4"

# Min/Max-PHP-Empfehlung je Contao-Branch (grober Richtwert, keine harte
# Grenze - nur Warnung, siehe contao_php_compat_check in _contao-lib.sh).
# Composer selbst lässt oft auch neuere PHP-Versionen zu, ohne dass die
# jeweilige Contao-Version tatsächlich dafür getestet/freigegeben ist (siehe
# z.B. Contao 5.3: offiziell "PHP 8.1+" ohne echte Obergrenze in
# composer.json). Format je Zeile: "Branch|MinPHP|MaxEmpfohlenPHP"
CONTAO_PHP_COMPAT=(
    "5.3|8.1|8.4"
    "5.7|8.3|8.4"
    "6.0|8.4|8.4"
)

# Nur setzen, falls PHP weder im PATH noch unter den bekannten MAMP-/
# Server-Standardpfaden automatisch gefunden wird (siehe _contao-lib.sh):
# voller Pfad zum php-Binary, z.B.
# "/Applications/MAMP/bin/php/php8.3.x/bin/php" (lokal) oder
# "/usr/local/php83/bin/php" (Server). Leer lassen = automatische Erkennung.
# Hat immer Vorrang - auch vor einer im Menü ("PHP-Version wählen")
# getroffenen Auswahl.
PHP_BIN_OVERRIDE=""

# Datei (relativ zum Script-Ordner), in der projektspezifische Einstellungen
# stehen - wird per 'source' eingebunden (echtes Bash, kein reines
# Zeilenformat) und überschreibt bei Bedarf die Standard-Werte aus diesem
# Konfig-Block. Existiert sie noch nicht, legt contao.sh sie beim ersten
# Aufruf automatisch an (mit PHP_BIN_SELECTED, TESTMAIL_FROM/TESTMAIL_TO,
# vorbefüllt aus den Defaults unten). contao.sh selbst bleibt dadurch für
# alle Projekte identisch; nur diese eine Datei unterscheidet sich pro
# Projekt - dort lässt sich bei Bedarf auch EXTENSIONS_LIST komplett
# überschreiben. Wird PHP_BIN_OVERRIDE oben gesetzt, hat das immer Vorrang
# vor der in dieser Datei gespeicherten PHP-Wahl.
CONTAO_CONF_FILE_REL=".contao.conf"

# Erweiterungen für die Checkbox-Auswahl - bewusst KEIN fester Inhalt hier
# in contao.sh (contao.sh bleibt dadurch für alle Projekte identisch, ohne
# eigene Paket-/Firmenvorlieben fest im Code). Die eigentliche Liste steht
# ausschließlich in .contao.conf (siehe unten) und wird von dort per
# 'source' geladen - beim allerersten Aufruf legt contao.sh sie dort direkt
# vorbefüllt an. Bleibt EXTENSIONS_LIST leer (z.B. weil .contao.conf
# gelöscht/geleert wurde), zeigen die Erweiterungen-Menüpunkte einen
# entsprechenden Hinweis statt eines Fehlers.
EXTENSIONS_LIST=()

# Default-Absender/-Empfänger für den Test-Mail-Versand, falls .contao.conf
# noch keine eigenen TESTMAIL_FROM/TESTMAIL_TO enthält (im Dialog änderbar,
# projektspezifisch in .contao.conf speicherbar - siehe CONTAO_CONF_FILE_REL
# oben).
TESTMAIL_FROM_DEFAULT="test@MEINEDOMAIN.de"
TESTMAIL_TO_DEFAULT="anmich@MEINEDOMAIN.de"

# Dateiname der Umgebungs-Konfiguration relativ zum Projekt-Root
ENV_FILE_REL=".env.local"

# Backup-Verzeichnis relativ zum Projekt-Root (Contao-Standard)
BACKUP_DIR_REL="var/backups"

# Für die Grundinstallation anbietbare Contao-Versionen: "Label|Version|MinPHP"
# Installiert wird via "composer create-project contao/managed-edition . <Version>"
FRESH_INSTALL_VERSIONS=(
    "Contao 5.3.x (LTS)|5.3|8.1"
    "Contao 5.7.x (LTS)|5.7|8.3"
)

# ============================================================================

# Versionsnummer der Toolbox - erscheint im Hauptmenü-Titel
# ("=== Contao PfeilShell - V1.1.0 ==="). Schema MAJOR.MINOR.PATCH - bei
# jeder Änderung an contao.sh/_contao-lib.sh die PATCH-Stelle hochzählen
# (1.1.0 -> 1.1.1 -> 1.1.2 ...), bei größeren Feature-Sprüngen die
# MINOR-Stelle.
CONTAO_SH_VERSION="1.3.0"
TOOL_TITLE="Contao PfeilShell - V${CONTAO_SH_VERSION}"

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_FILE="$SCRIPT_DIR/_contao-lib.sh"

if [ ! -f "$LIB_FILE" ]; then
    echo "FEHLER: _contao-lib.sh nicht gefunden (erwartet unter: $LIB_FILE)" >&2
    echo "Bitte _contao-lib.sh ins selbe Verzeichnis wie contao.sh legen." >&2
    exit 1
fi
# shellcheck source=_contao-lib.sh
source "$LIB_FILE"

trap 'contao_cleanup_theme; contao_print_summary' EXIT

# ----- Vorabprüfungen --------------------------------------------------------

# PHP und UI-Backend werden in jedem Fall gebraucht - auch für eine
# Grundinstallation, bei der es noch gar kein Projekt gibt. CONTAO_CONF_FILE
# muss vor contao_resolve_php gesetzt sein, da eine dort gespeicherte
# PHP-Auswahl Vorrang vor der automatischen Erkennung hat.
CONTAO_CONF_FILE="$SCRIPT_DIR/$CONTAO_CONF_FILE_REL"

# Einmalige, stille Migration von der alten (bis V1.0 genutzten) separaten
# PHP-Override-Datei auf die neue, vereinheitlichte .contao.conf - damit auf
# bereits im Einsatz befindlichen Projekten eine frühere PHP-Auswahl nicht
# verloren geht.
_contao_legacy_php_conf="$SCRIPT_DIR/.contao-sh-php.conf"
if [ ! -f "$CONTAO_CONF_FILE" ] && [ -f "$_contao_legacy_php_conf" ]; then
    _contao_legacy_php_bin="$(head -n1 "$_contao_legacy_php_conf" 2>/dev/null)"
    if [ -n "$_contao_legacy_php_bin" ]; then
        contao_env_set_value "PHP_BIN_SELECTED" "PHP_BIN_SELECTED=\"$_contao_legacy_php_bin\"" "$CONTAO_CONF_FILE" no_backup
    fi
    rm -f "$_contao_legacy_php_conf"
fi
unset _contao_legacy_php_conf _contao_legacy_php_bin

# .contao.conf ist echtes Bash und wird per 'source' eingebunden (nicht nur
# zeilenweise geparst) - kann dadurch neben einfachen KEY="VALUE"-Zeilen
# (PHP_BIN_SELECTED, TESTMAIL_FROM, TESTMAIL_TO) bei Bedarf auch ein
# komplettes EXTENSIONS_LIST-Array enthalten, das die Vorgabe oben im
# Konfig-Block überschreibt. Nur eine vom Tool selbst gepflegte/lesbare
# Datei im Projekt-Root, kein externer Input.
if [ -f "$CONTAO_CONF_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONTAO_CONF_FILE"
fi

# Composer braucht bei Contao-Projekten regelmäßig mehr Speicher, als das
# CLI-PHP per php.ini erlaubt (auf Hosting-Umgebungen oft 128/256 MB) - der
# Abhängigkeitsbaum ist groß genug, dass "Allowed memory size exhausted"
# mitten im Update der Normalfall ist. Composer wertet dafür
# COMPOSER_MEMORY_LIMIT aus. Ein in .contao.conf gesetzter eigener Wert
# bleibt erhalten (z.B. "2G" statt unbegrenzt, wenn der Hoster hart
# begrenzt und der Prozess sonst vom OOM-Killer beendet wird).
export COMPOSER_MEMORY_LIMIT="${COMPOSER_MEMORY_LIMIT:--1}"

contao_resolve_php

# Live-Check pro Start: welche PHP-Version ist gerade tatsächlich aktiv,
# passt das zur installierten Contao-Version (CONTAO_PHP_COMPAT)? Läuft
# bewusst VOR dem Schreiben in .contao.conf (siehe unten) - reine Warnung,
# blockiert nichts, aber macht eine falsch eingestellte PHP-Version (z.B.
# nach einem Hoster-Wechsel der Standardversion) sofort sichtbar, statt sie
# stillschweigend zu übernehmen.
contao_php_compat_check "$SCRIPT_DIR"
if [ "$CONTAO_SH_PHP_COMPAT_STATUS" = "low" ] || [ "$CONTAO_SH_PHP_COMPAT_STATUS" = "high" ]; then
    echo "${C_ORANGE}WARNUNG: $CONTAO_SH_PHP_COMPAT_MSG${C_RESET}" >&2
fi

# Existiert .contao.conf noch nicht (auch nicht durch die Migration oben
# angelegt), wird sie jetzt einmalig mit den aktuellen Werten vorbefüllt -
# PHP_BIN_SELECTED mit der gerade automatisch ermittelten (zu REQUIRED_PHP
# passenden) PHP-Version, TESTMAIL_FROM/TESTMAIL_TO mit den Defaults aus
# dem Konfig-Block. So liegt von Anfang an eine sichtbare, direkt editierbare
# Datei vor statt erst nach der ersten Menü-Interaktion.
if [ ! -f "$CONTAO_CONF_FILE" ]; then
    cat > "$CONTAO_CONF_FILE" << EOF
# Contao PfeilShell - projektspezifische Konfiguration.
# Wird von contao.sh per 'source' eingebunden - gültiges Bash, kein reines
# Zeilenformat. Überschreibt bei Bedarf die Standard-Werte aus dem
# Konfig-Block von contao.sh, ohne contao.sh selbst anzufassen.
TESTMAIL_FROM="$TESTMAIL_FROM_DEFAULT"
TESTMAIL_TO="$TESTMAIL_TO_DEFAULT"

# Erweiterungen für "Erweiterungen installieren/entfernen". Frei anpassbar -
# Zeilen ergänzen, ändern oder löschen. Format je Zeile:
# "Composer-Paket|Kurzbeschreibung"
EXTENSIONS_LIST=(
    "madeyourday/contao-rocksolid-custom-elements|RockSolid Custom Elements - Basis für eigene Content-Elemente"
    "madeyourday/contao-rocksolid-frontend-helper|RockSolid Frontend-Helper - Debug-/Diagnose-Hilfen im Frontend"
    "terminal42/contao-leads|Contao Leads - Formular-/Lead-Erfassung"
    "terminal42/notification_center|Notification Center - zentrales Benachrichtigungs-/Mailsystem"
    "terminal42/contao-changelanguage|Changelanguage - Sprachumschalter mehrsprachiger Seiten"
    "terminal42/contao-url-rewrite|URL Rewrite - Weiterleitungen/Rewrites verwalten"
    "terminal42/contao-fineuploader|Fine Uploader - Datei-Upload-Widget im Frontend"
    "codesache/contao-backend-user-style-bundle|Backend User Style Bundle - individuelles Backend-Farbschema"
    "erdmannfreunde/contao-grid-bundle|Grid Bundle - Grid-System für Layout-Sections"
    "erdmannfreunde/theme-toolbox|Theme Toolbox - Helferlein-Bundle fürs Theme"
    "codefog/contao-news_categories|News Categories - Kategorien für die News-Erweiterung"
)
EOF
    # PHP_BIN_SELECTED nur eintragen, wenn beim Erstaufruf tatsächlich ein
    # PHP-Binary gefunden wurde (contao_resolve_php oben) - so landet nie ein
    # leerer Wert in der Datei. Wurde nichts gefunden, bleibt die Zeile weg
    # und jeder weitere Aufruf versucht die automatische Erkennung erneut,
    # bis entweder ein PHP gefunden wird oder der Nutzer es manuell über
    # "PHP-Version wählen" festlegt.
    if [ -n "${PHP_BIN:-}" ]; then
        contao_env_set_value "PHP_BIN_SELECTED" "PHP_BIN_SELECTED=\"$PHP_BIN\"" "$CONTAO_CONF_FILE" no_backup
        PHP_BIN_SELECTED="$PHP_BIN"
    fi
    contao_log "Projektspezifische $CONTAO_CONF_FILE_REL neu angelegt (PHP: ${PHP_BIN:-nicht gefunden})"
fi

contao_detect_dialog

# ----- Grundinstallation (nur relevant, wenn noch kein Projekt existiert) ----

action_fresh_install() {
    local label="$1" version="$2" min_php="$3"
    local -a fresh_composer_cmd=()
    local composer_desc=""
    local use_tmp_install=0
    local tmp_install_dir=""
    local target_arg="." target_desc="$SCRIPT_DIR"

    echo ""
    echo "Contao $version wird installiert in:"
    echo "  $SCRIPT_DIR"

    local extra
    extra="$(find "$SCRIPT_DIR" -mindepth 1 -maxdepth 1 \
        ! -name 'contao.sh' ! -name '_contao-lib.sh' ! -name 'composer.phar' \
        2>/dev/null)"
    if [ -n "$extra" ]; then
        echo ""
        echo "${C_ORANGE}WARNUNG: Das Verzeichnis enthält bereits weitere Dateien/Ordner:${C_RESET}"
        echo "$extra" | sed 's/^/    /'
        echo "composer create-project bricht normalerweise ab, wenn das Zielverzeichnis nicht leer ist."

        if contao_yesno "Nicht leeres Verzeichnis" "Trotzdem installieren?\n\nEs wird in einen temporären Unterordner installiert und die fertige Installation anschließend hierher verschoben. Bereits vorhandene Dateien/Ordner (siehe Liste oben) werden dabei NICHT überschrieben."; then
            use_tmp_install=1
        else
            echo "Abgebrochen."
            contao_pause
            return 1
        fi
    fi

    # Bewusst OHNE Fallback auf ein globales 'composer' im PATH - siehe
    # Kommentar bei contao_resolve_composer() in _contao-lib.sh. composer.phar
    # im Zielordner hat Vorrang (wird initial oft manuell abgelegt), sonst
    # automatischer Download.
    if [ -f "$SCRIPT_DIR/composer.phar" ]; then
        fresh_composer_cmd=("$PHP_BIN" "$SCRIPT_DIR/composer.phar")
        composer_desc="php composer.phar"
        echo ""
        echo "Verwende lokale composer.phar: $SCRIPT_DIR/composer.phar"
    elif contao_download_composer_phar "$SCRIPT_DIR"; then
        fresh_composer_cmd=("$PHP_BIN" "$SCRIPT_DIR/composer.phar")
        composer_desc="php composer.phar"
    else
        echo ""
        echo "FEHLER: Keine composer.phar in $SCRIPT_DIR gefunden, und der" >&2
        echo "        automatische Download ist fehlgeschlagen." >&2
        echo "        composer.phar manuell ablegen: https://getcomposer.org" >&2
        contao_pause
        return 1
    fi

    if [ -n "$PHP_BIN" ]; then
        local cur_ver
        cur_ver="$("$PHP_BIN" -r 'echo PHP_VERSION;' 2>/dev/null)"
        if [ -n "$cur_ver" ] && ! "$PHP_BIN" -r "exit(version_compare(PHP_VERSION, '$min_php', '>=') ? 0 : 1);" 2>/dev/null; then
            echo ""
            echo "${C_ORANGE}WARNUNG: $label benötigt mindestens PHP $min_php, gefunden: $cur_ver ($PHP_BIN).${C_RESET}"
        fi
    fi

    if [ "$use_tmp_install" = "1" ]; then
        tmp_install_dir="$(mktemp -d "$SCRIPT_DIR/.pfeilshell-install.XXXXXX" 2>/dev/null)"
        if [ -z "$tmp_install_dir" ] || [ ! -d "$tmp_install_dir" ]; then
            echo ""
            echo "${C_RED}FEHLER: Konnte kein temporäres Installationsverzeichnis in $SCRIPT_DIR anlegen.${C_RESET}" >&2
            contao_pause
            return 1
        fi
        target_arg="$tmp_install_dir"
        target_desc="$tmp_install_dir  (temporär - wird danach nach $SCRIPT_DIR verschoben)"
    fi

    if ! contao_yesno "Grundinstallation" "$composer_desc create-project contao/managed-edition $target_arg $version\n\nZiel:\n$target_desc\n\nausführen?"; then
        echo "Abgebrochen."
        [ -n "$tmp_install_dir" ] && rm -rf "$tmp_install_dir"
        contao_pause
        return 1
    fi

    if (cd "$SCRIPT_DIR" && contao_run "Grundinstallation $label" "${fresh_composer_cmd[@]-}" create-project contao/managed-edition "$target_arg" "$version"); then
        if [ "$use_tmp_install" = "1" ]; then
            echo ""
            echo "Verschiebe installierte Dateien nach $SCRIPT_DIR (bestehende Dateien bleiben unangetastet) ..."
            cp -Rn "$tmp_install_dir"/. "$SCRIPT_DIR"/ 2>/dev/null
            rm -rf "$tmp_install_dir"
            echo "${C_ORANGE}Hinweis: Bereits vorhandene Dateien/Ordner (siehe Warnliste oben) wurden NICHT überschrieben. Bei Namensgleichheit mit Contao-Kerndateien bitte manuell abgleichen.${C_RESET}"
        fi
        echo ""
        echo "$label wurde installiert."
        contao_pause
        return 0
    else
        echo ""
        echo "${C_RED}!! Installation fehlgeschlagen.${C_RESET}" >&2
        [ -n "$tmp_install_dir" ] && rm -rf "$tmp_install_dir"
        contao_pause
        return 1
    fi
}

action_fresh_install_menu() {
    while true; do
        local menu_args=() entry label version min_php
        menu_args+=("#" "Grundinstallation")
        for entry in "${FRESH_INSTALL_VERSIONS[@]-}"; do
            label="$(echo "$entry" | cut -d'|' -f1)"
            version="$(echo "$entry" | cut -d'|' -f2)"
            menu_args+=("$version" "$label installieren")
        done
        menu_args+=("0" "Abbrechen / Beenden")

        local choice
        choice="$(contao_menu "Grundinstallation" \
            "Kein bestehendes Contao-Projekt in $SCRIPT_DIR gefunden. Neu installieren?" \
            "${menu_args[@]-}")"
        [ -z "$choice" ] || [ "$choice" = "0" ] && return 1

        for entry in "${FRESH_INSTALL_VERSIONS[@]-}"; do
            label="$(echo "$entry" | cut -d'|' -f1)"
            version="$(echo "$entry" | cut -d'|' -f2)"
            min_php="$(echo "$entry" | cut -d'|' -f3)"
            if [ "$choice" = "$version" ]; then
                action_fresh_install "$label" "$version" "$min_php" && return 0
                continue 2
            fi
        done
    done
}

PROJECT_ROOT="$(contao_find_project_root "$SCRIPT_DIR")"
if [ -z "$PROJECT_ROOT" ]; then
    if action_fresh_install_menu; then
        PROJECT_ROOT="$(contao_find_project_root "$SCRIPT_DIR")"
    fi
    if [ -z "$PROJECT_ROOT" ]; then
        echo "FEHLER: Kein Contao-Projekt gefunden/installiert (kein vendor/bin/contao-console" >&2
        echo "        oberhalb von $SCRIPT_DIR). contao.sh einfach erneut aufrufen," >&2
        echo "        sobald ein Projekt vorhanden ist." >&2
        contao_cleanup_theme
        exit 1
    fi
fi
cd "$PROJECT_ROOT" || exit 1

PHP_VERSION_STR="$(contao_check_php "$REQUIRED_PHP")"
php_check_rc=$?
if [ $php_check_rc -eq 1 ]; then
    exit 1
fi
# rc=2 -> nur Warnung, weiter gehts

if ! contao_resolve_composer "$PROJECT_ROOT"; then
    echo "FEHLER: Keine composer.phar im Projekt-Root gefunden, und der automatische" >&2
    echo "        Download ist fehlgeschlagen. composer.phar manuell ablegen:" >&2
    echo "        https://getcomposer.org" >&2
    exit 1
fi

CONSOLE_CMD=("$PHP_BIN" "$PROJECT_ROOT/vendor/bin/contao-console")
SETUP_CMD=("$PHP_BIN" "$PROJECT_ROOT/vendor/bin/contao-setup")
ENV_FILE="$PROJECT_ROOT/$ENV_FILE_REL"
BACKUP_DIR="$PROJECT_ROOT/$BACKUP_DIR_REL"

contao_log "contao.sh gestartet (Projekt-Root: $PROJECT_ROOT, PHP: ${PHP_VERSION_STR:-unbekannt})"

# ----- Migrate & Cache --------------------------------------------------------

action_migrate_backup() {
    contao_run "Migrate mit Backup" "${CONSOLE_CMD[@]-}" contao:migrate
    contao_pause
}

action_migrate_nobackup() {
    if contao_yesno "Migrate ohne Backup" "contao:migrate wird OHNE automatisches DB-Backup ausgeführt.\n\nFortfahren?"; then
        contao_run "Migrate ohne Backup" "${CONSOLE_CMD[@]-}" contao:migrate --no-backup
    else
        echo "Abgebrochen."
    fi
    contao_pause
}

action_cache_clear() {
    contao_purge_cache_dir prod
    contao_run "Cache clear" "${CONSOLE_CMD[@]-}" cache:clear --no-warmup
    contao_run "Cache warmup" "${CONSOLE_CMD[@]-}" cache:warmup
    contao_pause
}

# Leert - anders als "Cache leeren" oben, das nur die aktuelle APP_ENV
# (i.d.R. prod) leert - beide Umgebungen nacheinander über den
# Symfony-Standard-Parameter --env.
action_cache_clear_both() {
    local env
    for env in prod dev; do
        contao_purge_cache_dir "$env"
        contao_run "Cache clear ($env)" "${CONSOLE_CMD[@]-}" cache:clear --no-warmup --env="$env"
        contao_run "Cache warmup ($env)" "${CONSOLE_CMD[@]-}" cache:warmup --env="$env"
    done
    contao_pause
}

action_cache_migrate() {
    contao_purge_cache_dir prod
    contao_run "Cache clear" "${CONSOLE_CMD[@]-}" cache:clear --no-warmup
    contao_run "Cache warmup" "${CONSOLE_CMD[@]-}" cache:warmup
    contao_run "Migrate mit Backup" "${CONSOLE_CMD[@]-}" contao:migrate
    contao_pause
}

# ----- System ------------------------------------------------------------------

action_phpinfo() {
    echo ""
    echo "Verwendetes PHP-Binary: $PHP_BIN"
    "$PHP_BIN" -v
    echo ""
    echo "Geladene Extensions ($PHP_BIN -m):"
    "$PHP_BIN" -m
    contao_log "PHP-Info angezeigt ($PHP_BIN)"
    contao_pause
}

# Aktualisiert alle vom PHP-Binary abhängigen globalen Kommando-Arrays -
# nach jedem Wechsel der PHP-Version (Menü oder Reset) aufrufen, damit
# Composer und contao-console sofort mit der neuen Version laufen.
contao_refresh_php_dependents() {
    contao_check_php "$REQUIRED_PHP" >/dev/null 2>&1
    contao_resolve_composer "$PROJECT_ROOT"
    CONSOLE_CMD=("$PHP_BIN" "$PROJECT_ROOT/vendor/bin/contao-console")
    SETUP_CMD=("$PHP_BIN" "$PROJECT_ROOT/vendor/bin/contao-setup")
}

action_php_select() {
    contao_collect_php_candidates
    local -a idx_paths=()
    local -a menu_args=()
    local c v i=1

    for c in "${CONTAO_SH_PHP_CANDIDATES[@]-}"; do
        v="$("$c" -r 'echo PHP_VERSION;' 2>/dev/null)"
        [ -z "$v" ] && continue
        menu_args+=("$i" "$c  (PHP $v)")
        idx_paths+=("$c")
        i=$((i + 1))
    done

    menu_args+=("m" "Manuell: vollen Pfad eingeben")
    if [ -n "${PHP_BIN_SELECTED:-}" ]; then
        menu_args+=("a" "Automatische Erkennung verwenden (Auswahl zurücksetzen)")
    fi
    menu_args+=("0" "Abbrechen")

    local choice
    choice="$(contao_menu "PHP-Version wählen" "Aktuell verwendet: $PHP_BIN" "${menu_args[@]}")"
    [ -z "$choice" ] && { contao_pause; return; }
    [ "$choice" = "0" ] && { contao_pause; return; }

    if [ "$choice" = "a" ]; then
        contao_env_unset_value "PHP_BIN_SELECTED" "$CONTAO_CONF_FILE"
        PHP_BIN_SELECTED=""
        contao_resolve_php
        contao_refresh_php_dependents
        echo ""
        echo "Automatische Erkennung aktiviert. Verwendetes PHP: $PHP_BIN"
        contao_log "PHP-Version zurückgesetzt auf automatische Erkennung ($PHP_BIN)"
        contao_pause
        return
    fi

    local new_bin=""
    if [ "$choice" = "m" ]; then
        new_bin="$(contao_inputbox "PHP-Version" "Vollen Pfad zum php-Binary eingeben:" "$PHP_BIN")" || { contao_pause; return; }
        if [ ! -x "$new_bin" ]; then
            echo ""
            echo "${C_RED}FEHLER: '$new_bin' ist nicht ausführbar oder existiert nicht.${C_RESET}" >&2
            contao_pause
            return
        fi
    else
        local idx=$((choice - 1))
        new_bin="${idx_paths[$idx]:-}"
        if [ -z "$new_bin" ]; then
            echo "Ungültige Auswahl." >&2
            contao_pause
            return
        fi
    fi

    contao_env_set_value "PHP_BIN_SELECTED" "PHP_BIN_SELECTED=\"$new_bin\"" "$CONTAO_CONF_FILE" no_backup
    PHP_BIN_SELECTED="$new_bin"
    PHP_BIN="$new_bin"
    contao_refresh_php_dependents
    echo ""
    echo "${C_GREEN}PHP-Version gesetzt: $PHP_BIN${C_RESET}"
    echo "Gespeichert in $CONTAO_CONF_FILE_REL - bleibt bei künftigen Aufrufen erhalten,"
    echo "bis hier wieder auf automatische Erkennung zurückgesetzt wird."
    contao_log "PHP-Version manuell gesetzt: $PHP_BIN"
    contao_pause
}

# ----- Composer ------------------------------------------------------------------

action_composer_show() {
    contao_run "composer show" "${COMPOSER_CMD[@]-}" show
    contao_pause
}

action_composer_show_updates() {
    contao_run "composer show -l" "${COMPOSER_CMD[@]-}" show -l
    contao_pause
}

action_composer_version() {
    contao_run "composer -V" "${COMPOSER_CMD[@]-}" -V
    contao_pause
}

action_composer_phar_download() {
    local target="$PROJECT_ROOT/composer.phar" prompt
    if [ -f "$target" ]; then
        prompt="Vorhandene composer.phar unter\n$target\ndurch die aktuelle Version von getcomposer.org ersetzen?"
    else
        prompt="composer.phar von getcomposer.org herunterladen und unter\n$target\nablegen?"
    fi
    if ! contao_yesno "composer.phar herunterladen" "$prompt"; then
        echo "Abgebrochen."
        contao_pause
        return
    fi

    echo ""
    if contao_download_composer_phar "$PROJECT_ROOT"; then
        contao_resolve_composer "$PROJECT_ROOT"
        contao_log "composer.phar heruntergeladen/aktualisiert: $target"
    fi
    contao_pause
}

action_composer_selfupdate() {
    if contao_yesno "Composer Selfupdate" "composer.phar selfupdate ausführen?"; then
        contao_run "composer selfupdate" "${COMPOSER_CMD[@]-}" selfupdate
    else
        echo "Abgebrochen."
    fi
    contao_pause
}

action_composer_update_profile() {
    if contao_yesno "Composer Update (Profil)" "composer update --profile ausführen?\n(aktualisiert alle Pakete, zeigt Speicherverbrauch)"; then
        contao_run "composer update --profile" "${COMPOSER_CMD[@]-}" --profile update
    else
        echo "Abgebrochen."
    fi
    contao_pause
}

action_composer_update_dryrun() {
    contao_run "composer update --dry-run" "${COMPOSER_CMD[@]-}" --dry-run update
    contao_pause
}

action_composer_update_all() {
    if contao_yesno "Composer Update" "composer update ausführen?\nAktualisiert ALLE Pakete auf die neuesten kompatiblen Versionen."; then
        contao_run "composer update" "${COMPOSER_CMD[@]-}" update
    else
        echo "Abgebrochen."
    fi
    contao_pause
}

action_composer_install() {
    if contao_yesno "Composer Install" "composer install ausführen?\n\nInstalliert exakt die in composer.lock festgehaltenen Versionen - der\nübliche Schritt nach git clone/pull oder einem Deployment, im Gegensatz\nzu update, das die Versionen neu auflöst."; then
        contao_run "composer install" "${COMPOSER_CMD[@]-}" install
        # vendor/bin/* existiert vor dem ersten install noch nicht - die vom
        # PHP-Binary abhängigen Kommandos danach neu aufbauen.
        contao_refresh_php_dependents
        if contao_yesno "contao-setup" "Im Anschluss vendor/bin/contao-setup ausführen?\n(legt Verzeichnisse an, veröffentlicht Assets, leert den Cache -\nnormalerweise direkt nach einem install fällig)"; then
            action_contao_setup noprompt
        fi
    else
        echo "Abgebrochen."
    fi
    contao_pause
}

# contao-setup ist der von contao/manager-bundle bereitgestellte
# Nachbereitungsschritt (contao:setup) - Verzeichnisse, Assets, Symlinks,
# Cache. Composer ruft ihn bei install/update über ein Script selbst auf;
# wenn das dort z.B. wegen Speichermangel abgebrochen ist, fehlt er.
action_contao_setup() {
    local quiet="${1:-}"
    if [ ! -f "$PROJECT_ROOT/vendor/bin/contao-setup" ]; then
        contao_msgbox "contao-setup" "vendor/bin/contao-setup nicht gefunden.\n\nDas Kommando liefert contao/manager-bundle - zuerst composer install\nausführen."
        [ "$quiet" = "noprompt" ] || contao_pause
        return 1
    fi
    if [ "$quiet" = "noprompt" ] || contao_yesno "contao-setup" "vendor/bin/contao-setup ausführen?\n(legt Verzeichnisse an, veröffentlicht Assets, leert den Cache)"; then
        contao_run "contao-setup" "${SETUP_CMD[@]-}"
    else
        echo "Abgebrochen."
    fi
    [ "$quiet" = "noprompt" ] || contao_pause
}

# ----- Erweiterungen ------------------------------------------------------------

action_install_extensions() {
    local checklist_args=()
    local entry pkg desc
    for entry in "${EXTENSIONS_LIST[@]-}"; do
        pkg="${entry%%|*}"
        desc="${entry#*|}"
        checklist_args+=("$pkg" "$desc" "off")
    done

    local selection
    selection="$(contao_checklist "Erweiterungen installieren" \
        "Mit Leertaste oder Zifferntaste an-/abwählen, danach \"Fertig\" bestätigen:" "${checklist_args[@]-}")"
    if [ -z "$selection" ]; then
        contao_msgbox "Erweiterungen installieren" "Keine Auswahl getroffen - nichts installiert."
        return
    fi

    echo ""
    echo "Ausgewählte Pakete:"
    for pkg in $selection; do
        echo "  - $pkg"
    done

    local run_mode
    run_mode="$(contao_menu "Vorgehen wählen" "Wie soll installiert werden?" \
        1 "Erst Dry-Run (composer require --dry-run)" \
        2 "Direkt installieren" \
        0 "Abbrechen")"

    case "$run_mode" in
        1)
            # shellcheck disable=SC2086
            contao_run "composer require --dry-run ($selection)" "${COMPOSER_CMD[@]-}" require --dry-run $selection
            if contao_yesno "Jetzt wirklich installieren?" "Dry-Run abgeschlossen.\n\nJetzt echt installieren (composer require)?"; then
                # shellcheck disable=SC2086
                contao_run "composer require ($selection)" "${COMPOSER_CMD[@]-}" require $selection
            else
                echo "Installation abgebrochen (nur Dry-Run ausgeführt)."
            fi
            ;;
        2)
            if contao_yesno "Installieren bestätigen" "composer require für:\n$selection\n\nwirklich ausführen?"; then
                # shellcheck disable=SC2086
                contao_run "composer require ($selection)" "${COMPOSER_CMD[@]-}" require $selection
            else
                echo "Abgebrochen."
            fi
            ;;
        *)
            echo "Abgebrochen."
            ;;
    esac

    case " $selection " in
        *" codesache/contao-backend-user-style-bundle "*)
            echo ""
            echo "Hinweis: Das Farbschema (dunkelgrau/orange) des Backend User Style"
            echo "Bundles wird nicht von diesem Script gesetzt, sondern über die"
            echo "Bundle-eigene Konfiguration bzw. die Contao-Backend-Einstellungen"
            echo "des jeweiligen Users. Bitte nach der Installation manuell prüfen."
            ;;
    esac

    contao_pause
}

# Durchsucht ausschließlich Packagist (composer search) nach einem
# Stichwort - NICHT die lokale EXTENSIONS_LIST. Zeigt die Treffer als
# Checkbox-Auswahl und installiert die gewählten Pakete per composer
# require (Dry-Run oder direkt, wie bei "Erweiterungen installieren").
action_extensions_search() {
    local term
    term="$(contao_inputbox "Erweiterungen suchen" "Suchbegriff (Paketname oder Stichwort, sucht auf Packagist, leer = abbrechen):" "")"
    if [ -z "$term" ]; then
        return
    fi

    echo ""
    echo "Suche auf Packagist nach \"$term\" (nur Contao-Erweiterungen, Typ contao-bundle) ..."
    local raw
    # --type=contao-bundle grenzt auf Pakete mit Contao-Manager-Bundle-Typ
    # ein - der Standard-Composer-Typ, den Contao-Erweiterungen im
    # composer.json (`"type": "contao-bundle"`) angeben. Filtert dadurch
    # Treffer ohne Contao-Bezug zuverlässig heraus.
    raw="$("${COMPOSER_CMD[@]-}" search --type=contao-bundle "$term" 2>/dev/null)"

    local checklist_args=() matches=0
    local line pkg desc max_matches=40
    if [ -n "$raw" ]; then
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            pkg="${line%% *}"
            desc="${line#* }"
            [ "$pkg" = "$desc" ] && desc=""
            # Nur Zeilen übernehmen, die wie ein echter Composer-Paketname
            # ("vendor/paket") aussehen - filtert eventuelle Warn-/Hinweis-
            # zeilen von Composer heraus.
            case "$pkg" in
                */*/*) continue ;;
                */*) ;;
                *) continue ;;
            esac
            # Paketname sichtbar voranstellen - die Checkbox-Liste zeigt nur
            # die Beschreibung an, ohne das würde der Paketname (vendor/name)
            # beim Suchergebnis gar nicht auftauchen.
            if [ -n "$desc" ]; then
                desc="$pkg - $desc"
            else
                desc="$pkg"
            fi
            checklist_args+=("$pkg" "$desc" "off")
            matches=$((matches + 1))
            [ "$matches" -ge "$max_matches" ] && break
        done <<< "$raw"
    fi

    if [ "$matches" -eq 0 ]; then
        contao_msgbox "Erweiterungen suchen" "Keine Treffer für \"$term\" auf Packagist (oder keine Internetverbindung)."
        return
    fi

    local selection
    selection="$(contao_checklist "Erweiterungen suchen: \"$term\" ($matches Treffer, Packagist)" \
        "Mit Leertaste oder Zifferntaste an-/abwählen, danach \"Fertig\" bestätigen:" "${checklist_args[@]-}")"
    if [ -z "$selection" ]; then
        contao_msgbox "Erweiterungen suchen" "Keine Auswahl getroffen - nichts installiert."
        return
    fi

    echo ""
    echo "Ausgewählte Pakete:"
    for pkg in $selection; do
        echo "  - $pkg"
    done

    local run_mode
    run_mode="$(contao_menu "Vorgehen wählen" "Wie soll installiert werden?" \
        1 "Erst Dry-Run (composer require --dry-run)" \
        2 "Direkt installieren" \
        0 "Abbrechen")"

    case "$run_mode" in
        1)
            # shellcheck disable=SC2086
            contao_run "composer require --dry-run ($selection)" "${COMPOSER_CMD[@]-}" require --dry-run $selection
            if contao_yesno "Jetzt wirklich installieren?" "Dry-Run abgeschlossen.\n\nJetzt echt installieren (composer require)?"; then
                # shellcheck disable=SC2086
                contao_run "composer require ($selection)" "${COMPOSER_CMD[@]-}" require $selection
            else
                echo "Installation abgebrochen (nur Dry-Run ausgeführt)."
            fi
            ;;
        2)
            if contao_yesno "Installieren bestätigen" "composer require für:\n$selection\n\nwirklich ausführen?"; then
                # shellcheck disable=SC2086
                contao_run "composer require ($selection)" "${COMPOSER_CMD[@]-}" require $selection
            else
                echo "Abgebrochen."
            fi
            ;;
        *)
            echo "Abgebrochen."
            ;;
    esac

    contao_pause
}

# Ermittelt, welche der in EXTENSIONS_LIST bekannten Pakete aktuell
# installiert sind (composer show --name-only), zeigt sie als Checkbox-
# Auswahl und entfernt die gewählten Pakete per composer remove.
action_extensions_remove() {
    local installed_list
    installed_list="$("${COMPOSER_CMD[@]-}" show --name-only 2>/dev/null)"
    if [ -z "$installed_list" ]; then
        contao_msgbox "Erweiterungen entfernen" "Konnte installierte Pakete nicht ermitteln (composer show fehlgeschlagen)."
        return
    fi

    local checklist_args=() matches=0
    local entry pkg desc
    for entry in "${EXTENSIONS_LIST[@]-}"; do
        pkg="${entry%%|*}"
        desc="${entry#*|}"
        if echo "$installed_list" | grep -qx "$pkg"; then
            checklist_args+=("$pkg" "$desc" "off")
            matches=$((matches + 1))
        fi
    done

    if [ "$matches" -eq 0 ]; then
        contao_msgbox "Erweiterungen entfernen" "Keine der in EXTENSIONS_LIST bekannten Erweiterungen ist aktuell installiert."
        return
    fi

    local selection
    selection="$(contao_checklist "Erweiterungen entfernen" \
        "Mit Leertaste oder Zifferntaste an-/abwählen, danach \"Fertig\" bestätigen:" "${checklist_args[@]-}")"
    if [ -z "$selection" ]; then
        contao_msgbox "Erweiterungen entfernen" "Keine Auswahl getroffen - nichts entfernt."
        return
    fi

    echo ""
    echo "Zum Entfernen ausgewählte Pakete:"
    for pkg in $selection; do
        echo "  - $pkg"
    done

    if contao_confirm_dangerous "composer remove wird ausgeführt für:\n$selection\n\nDadurch werden die Dateien der Erweiterung(en) entfernt."; then
        # shellcheck disable=SC2086
        contao_run "composer remove ($selection)" "${COMPOSER_CMD[@]-}" remove $selection
    else
        echo "Abgebrochen."
    fi

    contao_pause
}

# ----- Werkzeuge ------------------------------------------------------------------

action_filesync() {
    contao_run "Filesync" "${CONSOLE_CMD[@]-}" contao:filesync
    contao_pause
}

action_crawl() {
    contao_run "Suchindex aufbauen (crawl)" "${CONSOLE_CMD[@]-}" contao:crawl
    contao_pause
}

# Contao arbeitet seit 5.x mit Symfony Messenger: Cronjobs und
# Hintergrundarbeit (Suchindex, Bildbearbeitung, Benachrichtigungen) laufen
# über Queues. contao:cron ist der Einstiegspunkt, den sonst der Webcron
# oder ein System-Cron anstößt - hier für den manuellen Anstoß und zum
# Nachsehen, ob die Queue überhaupt läuft.
action_cron() {
    contao_run "Cron ausführen" "${CONSOLE_CMD[@]-}" contao:cron
    contao_pause
}

# Fehlgeschlagene Messages landen im Failure-Transport und bleiben dort
# liegen, bis sie jemand ansieht - ohne Blick in diese Queue fehlt bei
# "die Mails kommen nicht an"/"der Suchindex aktualisiert nicht" die
# entscheidende Information.
action_messenger_menu() {
    while true; do
        local choice
        choice="$(contao_menu "Queue / Messenger" "Projekt: $PROJECT_ROOT" \
            1 "Fehlgeschlagene Messages anzeigen (messenger:failed:show)" \
            2 "Fehlgeschlagene Messages erneut verarbeiten (retry)" \
            3 "Fehlgeschlagene Messages verwerfen (remove, mit Rückfrage)" \
            4 "Worker einmal laufen lassen (messenger:consume, Zeitlimit 60s)" \
            0 "Zurück")"
        [ -z "$choice" ] && break
        case "$choice" in
            1) contao_run "messenger:failed:show" "${CONSOLE_CMD[@]-}" messenger:failed:show; contao_pause ;;
            2) contao_run "messenger:failed:retry" "${CONSOLE_CMD[@]-}" messenger:failed:retry; contao_pause ;;
            3)
                local id
                id="$(contao_inputbox "Messages verwerfen" "ID der zu verwerfenden Message (leer = abbrechen).\nIDs zeigt \"Fehlgeschlagene Messages anzeigen\":" "")"
                if [ -n "$id" ]; then
                    if contao_confirm_dangerous "Message $id wird endgültig aus der Failure-Queue entfernt und NICHT mehr verarbeitet."; then
                        contao_run "messenger:failed:remove $id" "${CONSOLE_CMD[@]-}" messenger:failed:remove "$id" --force
                    else
                        echo "Abgebrochen."
                    fi
                fi
                contao_pause
                ;;
            4)
                # Ohne Zeitlimit läuft consume endlos und das Menü kommt nicht
                # zurück - 60 Sekunden reichen, um zu sehen, ob die Queue
                # abgearbeitet wird. Ohne Transport-Argument fragt Symfony
                # selbst nach, welcher Transport konsumiert werden soll -
                # damit bleibt das unabhängig davon, wie die Transporte in
                # der jeweiligen Contao-Version heißen.
                contao_run "messenger:consume (60s)" "${CONSOLE_CMD[@]-}" messenger:consume --time-limit=60
                contao_pause
                ;;
            0) break ;;
            *) : ;;
        esac
    done
}

action_testmail() {
    local default_from default_to from to
    # TESTMAIL_FROM/TESTMAIL_TO kommen - falls in .contao.conf gesetzt -
    # bereits als fertige Variablen aus dem 'source' beim Start.
    default_from="${TESTMAIL_FROM:-$TESTMAIL_FROM_DEFAULT}"
    default_to="${TESTMAIL_TO:-$TESTMAIL_TO_DEFAULT}"

    from="$(contao_inputbox "Test-Mail" "Absender (--from):" "$default_from")" || { echo "Abgebrochen."; contao_pause; return; }
    to="$(contao_inputbox "Test-Mail" "Empfänger (--to):" "$default_to")" || { echo "Abgebrochen."; contao_pause; return; }

    if [ "$from" != "$default_from" ] || [ "$to" != "$default_to" ]; then
        if contao_yesno "Als Standard speichern?" "Absender/Empfänger für dieses Projekt in $CONTAO_CONF_FILE_REL als neuen Standard speichern?"; then
            contao_env_set_value "TESTMAIL_FROM" "TESTMAIL_FROM=\"$from\"" "$CONTAO_CONF_FILE" no_backup
            contao_env_set_value "TESTMAIL_TO" "TESTMAIL_TO=\"$to\"" "$CONTAO_CONF_FILE" no_backup
            TESTMAIL_FROM="$from"
            TESTMAIL_TO="$to"
            echo "Gespeichert in $CONTAO_CONF_FILE_REL."
        fi
    fi

    contao_run "Test-Mail von $from an $to" "${CONSOLE_CMD[@]-}" mailer:send \
        --from="$from" --to="$to" --subject=testmail --body=testmail
    contao_pause
}

# ----- Konfiguration: .env.local (DATABASE_URL / MAILER_DSN) -------------------

action_env_database() {
    local cur_user="" cur_pass="" cur_host="localhost" cur_port="3306" cur_db=""
    local existing
    existing="$(contao_env_get_value "DATABASE_URL" "$ENV_FILE" 2>/dev/null)"
    if [ -n "$existing" ] && [[ "$existing" =~ ^mysql://([^:@/]*):([^@]*)@([^:/]+):([0-9]+)/(.+)$ ]]; then
        cur_user="$(contao_rawurldecode "${BASH_REMATCH[1]}")"
        cur_pass="$(contao_rawurldecode "${BASH_REMATCH[2]}")"
        cur_host="${BASH_REMATCH[3]}"
        cur_port="${BASH_REMATCH[4]}"
        cur_db="${BASH_REMATCH[5]}"
    fi

    echo ""
    if [ -f "$ENV_FILE" ]; then
        echo "Bestehende $ENV_FILE_REL gefunden: $ENV_FILE"
        [ -n "$existing" ] && echo "Aktuelle DATABASE_URL: $(contao_env_mask_url "$existing")"
    else
        echo "Keine $ENV_FILE_REL vorhanden - wird beim Speichern neu angelegt: $ENV_FILE"
    fi

    local host port dbname user pass
    host="$(contao_inputbox "Datenbank" "Host:" "$cur_host")" || { echo "Abgebrochen."; contao_pause; return; }
    port="$(contao_inputbox "Datenbank" "Port (MAMP oft 8889, Server meist 3306):" "$cur_port")" || { echo "Abgebrochen."; contao_pause; return; }
    dbname="$(contao_inputbox "Datenbank" "DB-Name:" "$cur_db")" || { echo "Abgebrochen."; contao_pause; return; }
    user="$(contao_inputbox "Datenbank" "User:" "$cur_user")" || { echo "Abgebrochen."; contao_pause; return; }
    pass="$(contao_passwordbox "Datenbank" "Passwort (leer lassen = bisheriges Passwort behalten):")" || { echo "Abgebrochen."; contao_pause; return; }
    [ -z "$pass" ] && pass="$cur_pass"

    # User/Passwort prozent-kodiert einsetzen (siehe contao_rawurlencode) -
    # sonst zerlegt parse_url() eine DSN mit Sonderzeichen im Passwort falsch.
    local new_url="mysql://$(contao_rawurlencode "$user"):$(contao_rawurlencode "$pass")@${host}:${port}/${dbname}"
    local line="DATABASE_URL=\"$new_url\""

    echo ""
    echo "Neue DATABASE_URL: $(contao_env_mask_url "$new_url")"

    local backup_arg=""
    if [ -f "$ENV_FILE" ]; then
        if contao_yesno "Backup anlegen?" "Vor dem Speichern ein Backup der bestehenden $ENV_FILE_REL anlegen?\n(Empfohlen, aber nicht zwingend - gespeichert wird in jedem Fall.)"; then
            backup_arg=""
        else
            backup_arg="no_backup"
        fi
    fi

    contao_env_set_value "DATABASE_URL" "$line" "$ENV_FILE" "$backup_arg"
    contao_log "DATABASE_URL in $ENV_FILE_REL aktualisiert"
    echo "Gespeichert: $ENV_FILE"
    contao_pause
}

action_env_mailer() {
    local cur_user="" cur_pass="" cur_host="smtp.example.com" cur_port="465" cur_enc="ssl"
    local existing
    existing="$(contao_env_get_value "MAILER_DSN" "$ENV_FILE" 2>/dev/null)"
    if [ -n "$existing" ] && [[ "$existing" =~ ^smtp://([^:@/]*):([^@]*)@([^:/?]+):([0-9]+)(\?encryption=([a-zA-Z0-9]+))?$ ]]; then
        cur_user="$(contao_rawurldecode "${BASH_REMATCH[1]}")"
        cur_pass="$(contao_rawurldecode "${BASH_REMATCH[2]}")"
        cur_host="${BASH_REMATCH[3]}"
        cur_port="${BASH_REMATCH[4]}"
        [ -n "${BASH_REMATCH[6]}" ] && cur_enc="${BASH_REMATCH[6]}"
    fi

    echo ""
    if [ -f "$ENV_FILE" ]; then
        echo "Bestehende $ENV_FILE_REL gefunden: $ENV_FILE"
        [ -n "$existing" ] && echo "Aktuelle MAILER_DSN: $(contao_env_mask_url "$existing")"
    else
        echo "Keine $ENV_FILE_REL vorhanden - wird beim Speichern neu angelegt: $ENV_FILE"
    fi

    local host port user pass enc_choice enc
    host="$(contao_inputbox "Mailer" "SMTP-Host:" "$cur_host")" || { echo "Abgebrochen."; contao_pause; return; }
    port="$(contao_inputbox "Mailer" "SMTP-Port:" "$cur_port")" || { echo "Abgebrochen."; contao_pause; return; }
    user="$(contao_inputbox "Mailer" "Benutzername:" "$cur_user")" || { echo "Abgebrochen."; contao_pause; return; }
    pass="$(contao_passwordbox "Mailer" "Passwort (leer lassen = bisheriges Passwort behalten):")" || { echo "Abgebrochen."; contao_pause; return; }
    [ -z "$pass" ] && pass="$cur_pass"

    enc_choice="$(contao_menu "Verschlüsselung" "SMTP-Verschlüsselung wählen (aktuell: $cur_enc)" \
        1 "ssl" \
        2 "tls" \
        3 "keine" \
        0 "Abbrechen")"
    case "$enc_choice" in
        1) enc="ssl" ;;
        2) enc="tls" ;;
        3) enc="" ;;
        *) echo "Abgebrochen."; contao_pause; return ;;
    esac

    local new_dsn="smtp://$(contao_rawurlencode "$user"):$(contao_rawurlencode "$pass")@${host}:${port}"
    [ -n "$enc" ] && new_dsn="${new_dsn}?encryption=${enc}"
    # Wert in Anführungszeichen - eine unquotierte DSN mit # würde von
    # Symfony/Dotenv ab dem # als Kommentar gelesen (DATABASE_URL unten
    # macht es bereits so).
    local line="MAILER_DSN=\"$new_dsn\""

    echo ""
    echo "Neue MAILER_DSN: $(contao_env_mask_url "$new_dsn")"

    local backup_arg=""
    if [ -f "$ENV_FILE" ]; then
        if contao_yesno "Backup anlegen?" "Vor dem Speichern ein Backup der bestehenden $ENV_FILE_REL anlegen?\n(Empfohlen, aber nicht zwingend - gespeichert wird in jedem Fall.)"; then
            backup_arg=""
        else
            backup_arg="no_backup"
        fi
    fi

    contao_env_set_value "MAILER_DSN" "$line" "$ENV_FILE" "$backup_arg"
    contao_log "MAILER_DSN in $ENV_FILE_REL aktualisiert"
    echo "Gespeichert: $ENV_FILE"
    contao_pause
}

action_env_menu() {
    while true; do
        local choice
        choice="$(contao_menu "$ENV_FILE_REL konfigurieren" "Projekt: $PROJECT_ROOT" \
            1 "DATABASE_URL bearbeiten/anlegen" \
            2 "MAILER_DSN bearbeiten/anlegen" \
            3 "Beide nacheinander bearbeiten" \
            0 "Zurück")"
        [ -z "$choice" ] && break
        case "$choice" in
            1) action_env_database ;;
            2) action_env_mailer ;;
            3) action_env_database; action_env_mailer ;;
            0) break ;;
            *) : ;;
        esac
    done
}

# ----- Datenbank: Backup / Restore / Migrate-Debugging --------------------------

action_backup_create() {
    contao_run "Backup erstellen" "${CONSOLE_CMD[@]-}" contao:backup:create
    contao_pause
}

action_backup_list() {
    contao_run "Backup-Liste" "${CONSOLE_CMD[@]-}" contao:backup:list
    contao_pause
}

action_backup_restore() {
    if [ ! -d "$BACKUP_DIR" ]; then
        contao_msgbox "Restore" "Backup-Verzeichnis nicht gefunden:\n$BACKUP_DIR"
        return
    fi

    # Bewusst über eine temporäre Datei statt Prozess-Substitution (< <(...)) -
    # Prozess-Substitution braucht /dev/fd/*, das auf manchen (insbesondere
    # eingeschränkten/gejailten) Hosting-Shells fehlt und dann mit
    # "/dev/fd/NN: Datei oder Verzeichnis nicht gefunden" abbricht. Eine
    # normale temporäre Datei funktioniert überall.
    local -a files=()
    local _backup_list_tmp
    _backup_list_tmp="$(mktemp 2>/dev/null || echo "/tmp/contao-sh-backups.$$")"
    (cd "$BACKUP_DIR" && ls -t 2>/dev/null | grep -E '\.sql(\.gz)?$') > "$_backup_list_tmp"
    while IFS= read -r f; do
        files+=("$f")
    done < "$_backup_list_tmp"
    rm -f "$_backup_list_tmp"
    unset _backup_list_tmp

    if [ ${#files[@]} -eq 0 ]; then
        contao_msgbox "Restore" "Keine Backups gefunden in:\n$BACKUP_DIR"
        return
    fi

    local menu_args=()
    local f size mtime
    for f in "${files[@]-}"; do
        size="$(du -h "$BACKUP_DIR/$f" 2>/dev/null | cut -f1)"
        mtime="$(date -r "$BACKUP_DIR/$f" '+%Y-%m-%d %H:%M' 2>/dev/null)"
        menu_args+=("$f" "$mtime  ${size:-?}")
    done
    menu_args+=("0" "Abbrechen")

    local chosen
    chosen="$(contao_menu "Backup wiederherstellen" \
        "Backup zum Wiederherstellen wählen (Pfeiltasten + Enter):" "${menu_args[@]-}")"

    if [ -z "$chosen" ] || [ "$chosen" = "0" ]; then
        echo "Abgebrochen."
        contao_pause
        return
    fi

    echo ""
    echo "Ausgewählt: $chosen"

    if contao_yesno "Sicherheitsnetz" "Vor dem Restore ein frisches Backup des AKTUELLEN Stands erstellen (contao:backup:create)?\n\nEmpfohlen."; then
        contao_run "Sicherheits-Backup vor Restore" "${CONSOLE_CMD[@]-}" contao:backup:create
    fi

    if ! contao_confirm_dangerous "Restore von '$chosen' überschreibt die AKTUELLE Datenbank vollständig und ist nicht rückgängig zu machen (außer über ein weiteres Backup)."; then
        echo "Abgebrochen."
        contao_pause
        return
    fi

    contao_run "Restore ($chosen)" "${CONSOLE_CMD[@]-}" contao:backup:restore "$chosen"
    contao_pause
}

action_migrate_debug_menu() {
    while true; do
        local choice
        choice="$(contao_menu "Migrate-Debugging" "Eingrenzen: erst schema-only, dann migrations-only, dann -vvv ohne Dry-Run" \
            1 "Dry-Run --schema-only (nur DB-Schema, nichts wird ausgeführt)" \
            2 "Dry-Run --migrations-only (nur Migration-Klassen, nichts wird ausgeführt)" \
            3 "Dry-Run -vvv (voller Trace, nichts wird ausgeführt)" \
            4 "Dry-Run --format=ndjson (maschinenlesbar, Schritt für Schritt)" \
            5 "Dry-Run --with-deletes (inkl. DROP-Statements)" \
            6 "ECHTER Lauf -vvv --no-backup (bei bekanntem Problem, VERÄNDERND)" \
            0 "Zurück")"

        [ -z "$choice" ] && break

        case "$choice" in
            1) contao_run "migrate --dry-run --schema-only" "${CONSOLE_CMD[@]-}" contao:migrate --dry-run --schema-only; contao_pause ;;
            2) contao_run "migrate --dry-run --migrations-only" "${CONSOLE_CMD[@]-}" contao:migrate --dry-run --migrations-only; contao_pause ;;
            3) contao_run "migrate --dry-run -vvv" "${CONSOLE_CMD[@]-}" contao:migrate --dry-run -vvv; contao_pause ;;
            4) contao_run "migrate --dry-run --format=ndjson" "${CONSOLE_CMD[@]-}" contao:migrate --dry-run --format=ndjson; contao_pause ;;
            5) contao_run "migrate --dry-run --with-deletes" "${CONSOLE_CMD[@]-}" contao:migrate --dry-run --with-deletes; contao_pause ;;
            6)
                if contao_confirm_dangerous "Echter Migrate-Lauf mit -vvv und OHNE automatisches Backup. Nur nutzen, wenn eine bestimmte Migration bekanntermaßen hängt und bereits per Dry-Run eingegrenzt wurde."; then
                    contao_run "migrate -vvv --no-backup" "${CONSOLE_CMD[@]-}" contao:migrate -vvv --no-backup
                else
                    echo "Abgebrochen."
                fi
                contao_pause
                ;;
            0) break ;;
            *) : ;;
        esac
    done
}

# ----- Hauptmenü --------------------------------------------------------------

# Pfad-Zeile: wird - wie im demo-contao.sh-Vorbild - bei JEDEM Menü-Redraw
# angezeigt (auch in Untermenüs), damit der Projektkontext immer sichtbar
# bleibt. Der längere Intro-/Marketing-Satz dagegen erscheint nur beim
# allerersten Aufruf des Hauptmenüs in dieser Sitzung, nicht bei jeder
# Rückkehr aus einem Untermenü.
CONTAO_SH_PATH_LINE="Pfad: $PROJECT_ROOT"
# Statuszeile (PHP/Composer-Segment-Balken) einmalig pro Skriptlauf bauen,
# nicht bei jedem Menü-Redraw (siehe contao_build_status_line).
contao_build_status_line
MAIN_MENU_INTRO_FULL="Deine pfeilschnelle Kommandozentrale für Update, Installation, Migration, Cache und viele weitere Helferchen."
MAIN_MENU_INTRO_SHORT=""
main_menu_shown=0

while true; do
    if [ "$main_menu_shown" = "0" ]; then
        main_menu_prompt="$MAIN_MENU_INTRO_FULL"
        main_menu_shown=1
    else
        main_menu_prompt="$MAIN_MENU_INTRO_SHORT"
    fi
    choice="$(contao_menu "$TOOL_TITLE" "$main_menu_prompt" \
        "#" "System" \
        1  "PHP-Info anzeigen" \
        2  "PHP-Version wählen" \
        "#" "Composer" \
        3  "Composer: installierte Pakete anzeigen" \
        4  "Composer: verfügbare Updates anzeigen (show -l)" \
        5  "Composer Version anzeigen" \
        6  "composer.phar herunterladen/aktualisieren" \
        7  "Composer Selfupdate" \
        8  "Composer Install (Versionen aus composer.lock)" \
        9  "Composer Update (mit Memory-Profil)" \
        10 "Composer Update (Dry-Run / Testlauf)" \
        11 "Composer Update (alle Pakete aktualisieren)" \
        12 "contao-setup ausführen (Verzeichnisse/Assets/Cache)" \
        "#" "Cache" \
        13 "Cache leeren" \
        14 "Cache leeren (prod + dev)" \
        "#" "Datenbank + Migration" \
        15 "Migrate (mit automatischem Backup)" \
        16 "Migrate ohne Backup" \
        17 "Cache leeren + Migrate" \
        18 "Datenbank sichern (contao:backup:create)" \
        19 "Vorhandene Backups auflisten (contao:backup:list)" \
        20 "Datenbank aus Backup wiederherstellen (contao:backup:restore)" \
        21 "Migrate-Debugging (Dry-Run-Varianten)" \
        "#" "Erweiterungen" \
        22 "Erweiterungen installieren (Checkbox-Auswahl)" \
        23 "Erweiterungen suchen (Packagist)" \
        24 "Erweiterungen entfernen (composer remove)" \
        "#" "Werkzeuge" \
        25 "Dateiverwaltung abgleichen (contao:filesync)" \
        26 "Suchindex aufbauen (contao:crawl)" \
        27 "Cron ausführen (contao:cron)" \
        28 "Queue / Messenger (fehlgeschlagene Messages)" \
        29 "Test-E-Mail versenden (mailer:send)" \
        30 "$ENV_FILE_REL konfigurieren (DATABASE_URL / MAILER_DSN)" \
        0  "Beenden")"

    # Leere/ungültige Eingabe (z.B. ESC bei dialog/whiptail, Tippfehler im
    # Textmenü) zeigt nur erneut die Auswahl - NUR ein bewusstes "0"
    # (Beenden) beendet das Script wirklich.
    [ -z "$choice" ] && continue

    case "$choice" in
        1) action_phpinfo ;;
        2) action_php_select ;;
        3) action_composer_show ;;
        4) action_composer_show_updates ;;
        5) action_composer_version ;;
        6) action_composer_phar_download ;;
        7) action_composer_selfupdate ;;
        8) action_composer_install ;;
        9) action_composer_update_profile ;;
        10) action_composer_update_dryrun ;;
        11) action_composer_update_all ;;
        12) action_contao_setup ;;
        13) action_cache_clear ;;
        14) action_cache_clear_both ;;
        15) action_migrate_backup ;;
        16) action_migrate_nobackup ;;
        17) action_cache_migrate ;;
        18) action_backup_create ;;
        19) action_backup_list ;;
        20) action_backup_restore ;;
        21) action_migrate_debug_menu ;;
        22) action_install_extensions ;;
        23) action_extensions_search ;;
        24) action_extensions_remove ;;
        25) action_filesync ;;
        26) action_crawl ;;
        27) action_cron ;;
        28) action_messenger_menu ;;
        29) action_testmail ;;
        30) action_env_menu ;;
        0) break ;;
        *) : ;;
    esac
done

exit 0
