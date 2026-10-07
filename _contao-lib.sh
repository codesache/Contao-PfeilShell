#!/bin/bash
#
# _contao-lib.sh
# ---------------------------------------------------------------------------
# Gemeinsame Funktionen für contao.sh.
# Wird per `source` eingebunden, liegt im selben Ordner wie contao.sh
# (also im Projekt-Root).
#
# Kompatibel zu macOS' Standard-Bash 3.2 (kein Homebrew-Bash nötig):
# keine assoziativen Arrays, kein mapfile/readarray, kein ${var,,}.
# ---------------------------------------------------------------------------

# Name der Toolbox, taucht im Menü-Backtitle und in Textmenü-Überschriften auf.
TOOL_TITLE="${TOOL_TITLE:-Contao PfeilShell}"

# ---------------------------------------------------------------------------
# Farben (ANSI, nur im echten Terminal und ohne NO_COLOR)
# ---------------------------------------------------------------------------
# C_ORANGE nutzt Truecolor (24-Bit) mit dem Branding-Ton #f47c00 fett -
# wird von praktisch jedem modernen Terminal unterstützt (Terminal.app,
# iTerm2, VS Code, gängige Linux-Terminals). NO_COLOR=1 oder Ausgabe in
# eine Datei/Pipe schaltet Farben automatisch ab.
contao_setup_colors() {
    if [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; then
        C_RESET=""
        C_ORANGE=""
        C_GREEN=""
        C_RED=""
        C_GREY=""
        C_LOGO_CODE=""
        C_LOGO_SACHE=""
        C_SELECT=""
        C_BG_GREEN=""
        C_BG_ORANGE=""
        C_BG_GREY=""
        return
    fi
    C_RESET=$'\033[0m'
    C_ORANGE=$'\033[1;38;2;244;124;0m'
    C_GREEN=$'\033[1;32m'
    C_RED=$'\033[1;31m'
    C_GREY=$'\033[2m'
    # Logo-Farben (Truecolor, exakte Hex-Werte): "Code" in #1d70b7,
    # "Sache" in #009640 - "PfeilShell" nutzt bewusst das normale C_ORANGE.
    C_LOGO_CODE=$'\033[38;2;29;112;183m'
    C_LOGO_SACHE=$'\033[38;2;0;150;64m'
    # Auswahl-/Cursor-Hervorhebung in Menüs und Checklisten: bewusst das
    # gleiche Blau wie "Code" im Logo (#1d70b7), fett für Kontrast - nicht
    # C_ORANGE, das bleibt Titeln/Überschriften/Warnungen vorbehalten.
    C_SELECT=$'\033[1;38;2;29;112;183m'
    # Hintergrundfarben für die segmentierte Statuszeile (echte "Blöcke"
    # statt nur eingefärbtem Text) - schwarzer Text auf grün/orange, weißer
    # Text auf dunkelgrau für neutrale Info-Segmente (PHP-/Composer-Version).
    C_BG_GREEN=$'\033[1;30;48;2;80;200;120m'
    C_BG_ORANGE=$'\033[1;30;48;2;244;124;0m'
    C_BG_GREY=$'\033[1;37;48;2;60;60;60m'
}
contao_setup_colors

# Hinweiszeile "(Pfeiltasten hoch/runter, ...)" in contao_menu_arrows nur
# beim allerersten Zeichnen eines Menüs in dieser Sitzung anzeigen (wie
# hint_shown in der demo-contao.sh-Vorlage) - danach bei jedem weiteren
# Menü (Haupt- oder Untermenüs) nicht mehr wiederholen.
CONTAO_SH_HINT_SHOWN=0

# ---------------------------------------------------------------------------
# ASCII-Block-Schrift-Logo "CodeSache PfeilShell" (wie in der demo-contao.sh
# Vorlage), dreifarbig ("Code" in #1d70b7, "Sache" in #009640, "PfeilShell"
# in Marken-Orange). Wird nur im interaktiven Pfeiltasten-Menü gezeigt
# (siehe contao_menu_arrows), nicht im Zahlen-Fallback für
# Pipes/Automatisierung. Einmalig vorgerendert in CONTAO_SH_LOGO_BLOCK, um
# es bei jedem Redraw nicht neu zusammenbauen zu müssen.
# ---------------------------------------------------------------------------
# Wichtig: jede Zeile ist bewusst auf eine feste Breite mit Leerzeichen
# aufgefüllt (CODE=20, SACHE=23, PFEIL=34 Zeichen) - ohne dieses Padding
# rutschen die drei Blöcke beim Zusammensetzen ineinander, da sie sonst
# direkt an der letzten sichtbaren Glyphe der jeweiligen Zeile aneinander-
# stoßen würden. Trailing Spaces hier bitte nicht "aufräumen"/entfernen.
IFS= read -r -d '' CONTAO_SH_LOGO_CODE << 'LOGO_EOF'
  ___         _     
 / __|___  __| |___ 
| (__/ _ \/ _` / -_)
 \___\___/\__,_\___|
                    
LOGO_EOF
IFS= read -r -d '' CONTAO_SH_LOGO_SACHE << 'LOGO_EOF'
 ___          _        
/ __| __ _ __| |_  ___ 
\__ \/ _` / _| ' \/ -_)
|___/\__,_\__|_||_\___|
                       
LOGO_EOF
IFS= read -r -d '' CONTAO_SH_LOGO_PFEILSHELL << 'LOGO_EOF'
 ___  __     _ _ ___ _        _ _ 
| _ \/ _|___(_) / __| |_  ___| | |
|  _/  _/ -_) | \__ \ ' \/ -_) | |
|_| |_| \___|_|_|___/_||_\___|_|_|
                                  
LOGO_EOF

contao_build_logo() {
    local i line_code line_sache line_pfeil divider
    CONTAO_SH_LOGO_BLOCK=""
    for i in 1 2 3 4 5; do
        line_code=$(sed -n "${i}p" <<< "$CONTAO_SH_LOGO_CODE")
        line_sache=$(sed -n "${i}p" <<< "$CONTAO_SH_LOGO_SACHE")
        line_pfeil=$(sed -n "${i}p" <<< "$CONTAO_SH_LOGO_PFEILSHELL")
        # Bindestrich als Trenner zwischen "CodeSache" und "PfeilShell",
        # nur in der mittleren Zeile sichtbar (vertikal zentriert), in den
        # anderen Zeilen ein gleich breiter Leerraum zur Ausrichtung.
        if [ "$i" -eq 3 ]; then
            divider=" - "
        else
            divider="   "
        fi
        CONTAO_SH_LOGO_BLOCK="${CONTAO_SH_LOGO_BLOCK}${C_LOGO_CODE}${line_code}${C_LOGO_SACHE}${line_sache}${C_GREY}${divider}${C_ORANGE}${line_pfeil}${C_RESET}"$'\n'
    done
}
contao_build_logo

# ---------------------------------------------------------------------------
# Projekt-Root robust ermitteln
# ---------------------------------------------------------------------------
# Startet im Verzeichnis des aufrufenden Scripts und geht so lange nach oben,
# bis vendor/bin/contao-console gefunden wird (Standard Contao-5-Struktur).
# Zwei Fallback-Stufen, falls der Console-Wrapper (noch) fehlt oder nicht
# ausführbar ist (z.B. frischer Checkout vor "composer install", oder
# Dateirechte auf dem Server verhindern -x):
#   1. composer.json mit Abhängigkeit "contao/manager-bundle"
#   2. contao/-Ordner (enthält dca/, config/, languages/ - Contao-Kernordner,
#      seit Contao 4 fester Bestandteil jeder Installation) zusammen mit vendor/
contao_find_project_root() {
    local start_dir dir
    start_dir="$1"
    dir="$start_dir"

    while [ "$dir" != "/" ]; do
        if [ -x "$dir/vendor/bin/contao-console" ]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done

    dir="$start_dir"
    while [ "$dir" != "/" ]; do
        if [ -f "$dir/composer.json" ] && grep -q "contao/manager-bundle" "$dir/composer.json" 2>/dev/null; then
            echo "$dir"
            return 0
        fi
        if [ -d "$dir/contao" ] && [ -d "$dir/vendor" ]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done

    return 1
}

# ---------------------------------------------------------------------------
# Kleiner Versions-Helfer ohne externe Tools: "8.4.17" -> 80417, zum
# Sortieren/Vergleichen von PHP-Versionen in reinem Bash (auch mit
# unvollständigen Versionsangaben wie "8.1" oder "8").
# ---------------------------------------------------------------------------
_contao_php_ver_to_num() {
    local v="$1"
    local -a parts
    IFS='.' read -ra parts <<< "$v"
    local major="${parts[0]:-0}" minor="${parts[1]:-0}" patch="${parts[2]:-0}"
    major="${major//[!0-9]/}"; minor="${minor//[!0-9]/}"; patch="${patch//[!0-9]/}"
    [ -z "$major" ] && major=0
    [ -z "$minor" ] && minor=0
    [ -z "$patch" ] && patch=0
    echo $(( 10#$major * 10000 + 10#$minor * 100 + 10#$patch ))
}

# Kanonischen Pfad ermitteln (löst Symlinks/Verzeichnis-Symlinks wie das auf
# vielen modernen Linux-Systemen übliche "/bin -> /usr/bin" auf), damit z.B.
# "/usr/bin/php84" und "/bin/php84" - dieselbe Datei, zweimal erreichbar -
# als Duplikat erkannt werden statt doppelt in der Auswahl aufzutauchen.
# Fällt auf den unveränderten Pfad zurück, falls weder realpath noch
# readlink -f verfügbar sind.
_contao_php_canon_path() {
    local p="$1"
    if command -v realpath >/dev/null 2>&1; then
        realpath "$p" 2>/dev/null && return 0
    fi
    if command -v readlink >/dev/null 2>&1; then
        readlink -f "$p" 2>/dev/null && return 0
    fi
    echo "$p"
}

# ---------------------------------------------------------------------------
# Alle auffindbaren PHP-Binaries sammeln (generisches 'php' im PATH,
# versionierte Binaries in jedem PATH-Verzeichnis - deckt beide üblichen
# Schreibweisen ab, z.B. "php8.4" UND "php84" -, sowie eine Reihe fester
# Installationspfade: MAMP, Homebrew (auch versionierte "php@8.4"-Formeln),
# Plesk, cPanel/EasyApache ("ea-php84") und klassische Server-/
# Hosting-Layouts). Duplikate werden anhand des kanonischen (Symlink-
# aufgelösten) Pfads entfernt, z.B. wenn "/bin" nur ein Symlink auf
# "/usr/bin" ist und dieselbe Datei so doppelt gefunden würde.
# Setzt das globale Array CONTAO_SH_PHP_CANDIDATES. Wird sowohl von
# contao_resolve_php (automatische Auswahl) als auch vom interaktiven
# "PHP-Version wählen"-Menü in contao.sh genutzt.
# ---------------------------------------------------------------------------
contao_collect_php_candidates() {
    CONTAO_SH_PHP_CANDIDATES=()
    local -a raw_candidates=()

    if command -v php >/dev/null 2>&1; then
        raw_candidates+=("$(command -v php)")
    fi

    # Jedes PATH-Verzeichnis nach versionierten php-Binaries durchsuchen -
    # sowohl "phpN.M" (php8.4) als auch "phpNM" (php84). Bekannte
    # Nicht-CLI-Tools (php-fpm, phpize, php-config, phpdbg, php-cgi,
    # phpunit, php.ini) werden ausgeschlossen.
    local dir cand name oldifs
    oldifs="$IFS"
    IFS=':'
    for dir in $PATH; do
        IFS="$oldifs"
        [ -d "$dir" ] || continue
        for cand in "$dir"/php[0-9]*; do
            [ -e "$cand" ] || continue
            name="${cand##*/}"
            case "$name" in
                php-fpm*|php-cgi*|phpize*|php-config*|phpdbg*|phpunit*|php.ini*)
                    continue
                    ;;
            esac
            if [[ "$name" =~ ^php[0-9]+(\.[0-9]+)?$ ]]; then
                raw_candidates+=("$cand")
            fi
        done
        IFS=':'
    done
    IFS="$oldifs"

    # Feste Installationspfade, auch relevant wenn das jeweilige
    # bin-Verzeichnis nicht im PATH liegt.
    for cand in \
        /Applications/MAMP/bin/php/php*/bin/php \
        /opt/homebrew/opt/php@*/bin/php \
        /usr/local/opt/php@*/bin/php \
        /opt/homebrew/bin/php \
        /usr/local/bin/php \
        /usr/local/php*/bin/php \
        /opt/plesk/php/*/bin/php \
        /opt/cpanel/ea-php*/root/usr/bin/php \
        /usr/php*/bin/php \
        /usr/bin/php
    do
        [ -x "$cand" ] && raw_candidates+=("$cand")
    done

    [ ${#raw_candidates[@]} -eq 0 ] && return 1

    local c canon already seen_canon
    local -a seen_canons=()
    for c in "${raw_candidates[@]-}"; do
        [ -x "$c" ] || continue
        canon="$(_contao_php_canon_path "$c")"
        [ -z "$canon" ] && canon="$c"
        already=0
        for seen_canon in "${seen_canons[@]-}"; do
            [ "$seen_canon" = "$canon" ] && { already=1; break; }
        done
        [ "$already" = "1" ] && continue
        seen_canons+=("$canon")
        CONTAO_SH_PHP_CANDIDATES+=("$c")
    done

    [ ${#CONTAO_SH_PHP_CANDIDATES[@]} -eq 0 ] && return 1
    return 0
}

# ---------------------------------------------------------------------------
# PHP-Binary auflösen (lokal per MAMP, auf einem Server per Systempaket,
# Plesk/cPanel-eigenem PHP o.ä.) und Version prüfen
# ---------------------------------------------------------------------------
# Setzt das globale PHP_BIN. Reihenfolge:
#   1. PHP_BIN_OVERRIDE, falls im aufrufenden Script gesetzt (Konfig-Block) -
#      hat immer Vorrang.
#   2. Eine per Menü ("PHP-Version wählen") getroffene und in
#      PHP_OVERRIDE_FILE gespeicherte Auswahl, falls vorhanden.
#   3. Alle auffindbaren PHP-Binaries sammeln (contao_collect_php_candidates)
#      und daraus die niedrigste Version wählen, die REQUIRED_PHP noch
#      erfüllt (kein unnötig neueres PHP als nötig, aber garantiert
#      kompatibel). Erfüllt keine der gefundenen Versionen die Anforderung,
#      wird ersatzweise die höchste gefundene Version genommen -
#      contao_check_php warnt danach wie gewohnt.
# Das ist wichtig, weil auf vielen Hostern ein generisches "php" im PATH
# fehlt oder auf eine alte Version zeigt, während die eigentlich gewünschte
# Version nur unter einem versionierten Namen erreichbar ist.
PHP_BIN=""

contao_resolve_php() {
    if [ -n "${PHP_BIN_OVERRIDE:-}" ] && [ -x "$PHP_BIN_OVERRIDE" ]; then
        PHP_BIN="$PHP_BIN_OVERRIDE"
        return 0
    fi

    # PHP_BIN_SELECTED kommt - falls vorhanden - direkt aus .contao.conf,
    # das contao.sh bereits per 'source' eingebunden hat, bevor diese
    # Funktion aufgerufen wird (siehe CONTAO_CONF_FILE-Handling in contao.sh).
    if [ -n "${PHP_BIN_SELECTED:-}" ] && [ -x "$PHP_BIN_SELECTED" ]; then
        PHP_BIN="$PHP_BIN_SELECTED"
        return 0
    fi

    contao_collect_php_candidates || return 1

    local required_num=0
    [ -n "${REQUIRED_PHP:-}" ] && required_num="$(_contao_php_ver_to_num "$REQUIRED_PHP")"

    local best_meet="" best_meet_num=999999999
    local best_any="" best_any_num=-1
    local c v vn

    for c in "${CONTAO_SH_PHP_CANDIDATES[@]-}"; do
        v="$("$c" -r 'echo PHP_VERSION;' 2>/dev/null)"
        [ -z "$v" ] && continue
        vn="$(_contao_php_ver_to_num "$v")"

        if [ "$vn" -gt "$best_any_num" ]; then
            best_any_num="$vn"
            best_any="$c"
        fi
        if [ "$vn" -ge "$required_num" ] && [ "$vn" -lt "$best_meet_num" ]; then
            best_meet_num="$vn"
            best_meet="$c"
        fi
    done

    if [ -n "$best_meet" ]; then
        PHP_BIN="$best_meet"
        return 0
    fi
    if [ -n "$best_any" ]; then
        PHP_BIN="$best_any"
        return 0
    fi
    return 1
}

# ---------------------------------------------------------------------------
# Ermittelt den Contao-Branch (z.B. "5.3") der installierten contao/core-
# bundle-Version direkt aus composer.lock - bewusst ohne Composer-Aufruf
# (kein Bootstrap-Overhead), damit das bei jedem Start unbedenklich läuft.
# ---------------------------------------------------------------------------
contao_detect_contao_branch() {
    local dir="$1" lock_file version
    lock_file="$dir/composer.lock"
    [ -f "$lock_file" ] || return 1
    version="$(grep -A6 '"name": *"contao/core-bundle"' "$lock_file" 2>/dev/null \
        | grep -m1 '"version"' \
        | sed -E 's/.*"version": *"v?([^"]+)".*/\1/')"
    [ -z "$version" ] && return 1
    echo "$version" | cut -d. -f1,2
    return 0
}

# ---------------------------------------------------------------------------
# Gleicht die aktuell aktive PHP-Version (PHP_BIN) gegen die für die
# installierte Contao-Version bekannte Min/Max-Empfehlung ab
# (CONTAO_PHP_COMPAT im Konfig-Block von contao.sh, Format
# "Branch|MinPHP|MaxEmpfohlenPHP"). Reine Warnung, kein Blocker - Composer
# selbst lässt eine zu neue PHP-Version ja meist ohnehin zu.
# Setzt CONTAO_SH_PHP_COMPAT_STATUS: "ok" | "low" | "high" | "unknown"
# und CONTAO_SH_PHP_COMPAT_MSG (Klartext, leer außer bei "low"/"high").
# ---------------------------------------------------------------------------
CONTAO_SH_PHP_COMPAT_STATUS="unknown"
CONTAO_SH_PHP_COMPAT_MSG=""

contao_php_compat_check() {
    local dir="$1" branch entry e_branch e_min e_max
    local php_ver php_num min_num max_num

    CONTAO_SH_PHP_COMPAT_STATUS="unknown"
    CONTAO_SH_PHP_COMPAT_MSG=""

    [ -n "${PHP_BIN:-}" ] && [ -x "$PHP_BIN" ] || return 1
    branch="$(contao_detect_contao_branch "$dir")" || return 1
    [ -z "$branch" ] && return 1

    for entry in "${CONTAO_PHP_COMPAT[@]-}"; do
        e_branch="${entry%%|*}"
        [ "$e_branch" = "$branch" ] || continue
        e_min="$(echo "$entry" | cut -d'|' -f2)"
        e_max="$(echo "$entry" | cut -d'|' -f3)"

        php_ver="$("$PHP_BIN" -r 'echo PHP_VERSION;' 2>/dev/null)"
        [ -z "$php_ver" ] && return 1
        # Vergleich bewusst nur auf Major.Minor-Ebene (Patch-Version
        # ignorieren) - CONTAO_PHP_COMPAT-Einträge sind Branches wie "8.4",
        # nicht einzelne Patch-Versionen. Sonst würde z.B. PHP 8.4.23 fälschlich
        # als "höher als empfohlenes Maximum 8.4" gewertet.
        php_num="$(_contao_php_ver_to_num "$(echo "$php_ver" | cut -d. -f1,2)")"
        min_num="$(_contao_php_ver_to_num "$e_min")"
        max_num="$(_contao_php_ver_to_num "$e_max")"

        if [ "$php_num" -lt "$min_num" ]; then
            CONTAO_SH_PHP_COMPAT_STATUS="low"
            CONTAO_SH_PHP_COMPAT_MSG="PHP $php_ver ist niedriger als für Contao $branch benötigt (min. $e_min)."
        elif [ "$php_num" -gt "$max_num" ]; then
            CONTAO_SH_PHP_COMPAT_STATUS="high"
            CONTAO_SH_PHP_COMPAT_MSG="PHP $php_ver ist neuer als für Contao $branch offiziell erprobt (empfohlen bis $e_max) - auf Kompatibilität prüfen."
        else
            CONTAO_SH_PHP_COMPAT_STATUS="ok"
        fi
        return 0
    done

    return 1
}

# ---------------------------------------------------------------------------
# Wandelt einen php.ini memory_limit-Wert ("512M", "1G", "-1", Bytes ohne
# Suffix) in MB um. "-1" (unbegrenzt) wird unverändert als "-1" zurückgegeben.
# ---------------------------------------------------------------------------
_contao_mem_to_mb() {
    local v="$1" num unit
    case "$v" in
        -1|"") echo -1; return ;;
    esac
    unit="${v: -1}"
    case "$unit" in
        [Gg]) num="${v%[Gg]}"; num="${num//[!0-9]/}"; echo $(( ${num:-0} * 1024 )) ;;
        [Mm]) num="${v%[Mm]}"; num="${num//[!0-9]/}"; echo "${num:-0}" ;;
        [Kk]) num="${v%[Kk]}"; num="${num//[!0-9]/}"; echo $(( ${num:-0} / 1024 )) ;;
        *) num="${v//[!0-9]/}"; echo $(( ${num:-1048576} / 1048576 )) ;;
    esac
}

# ---------------------------------------------------------------------------
# Baut die Statuszeile (PHP-Version, memory_limit/max_execution_time/
# max_input_vars, Composer-Version) als durchgehenden Segment-Balken -
# einmal pro Skriptlauf in CONTAO_SH_STATUS_LINE berechnet, nicht bei jedem
# Menü-Redraw (Composer-Bootstrap ist zu langsam für "bei jedem Pfeiltasten-
# Druck neu"). Composer-Version wird an die composer.phar-mtime gekoppelt in
# .contao.conf gecacht - nur bei tatsächlicher Änderung (Selfupdate, neuer
# Download) neu ermittelt.
# ---------------------------------------------------------------------------
CONTAO_SH_STATUS_LINE=""

contao_build_status_line() {
    CONTAO_SH_STATUS_LINE=""
    [ -n "${PHP_BIN:-}" ] && [ -x "$PHP_BIN" ] || return 1

    local php_ver ini_raw mem_limit max_exec max_vars
    php_ver="$("$PHP_BIN" -r 'echo PHP_VERSION;' 2>/dev/null)"
    ini_raw="$("$PHP_BIN" -r 'echo ini_get("memory_limit"),"|",ini_get("max_execution_time"),"|",ini_get("max_input_vars");' 2>/dev/null)"
    mem_limit="$(echo "$ini_raw" | cut -d'|' -f1)"
    max_exec="$(echo "$ini_raw" | cut -d'|' -f2)"
    max_vars="$(echo "$ini_raw" | cut -d'|' -f3)"

    local mem_mb mem_col exec_col vars_col php_col
    mem_mb="$(_contao_mem_to_mb "$mem_limit")"
    if [ "$mem_mb" = "-1" ] || [ "${mem_mb:-0}" -ge 256 ] 2>/dev/null; then
        mem_col="$C_BG_GREEN"
    else
        mem_col="$C_BG_ORANGE"
    fi
    if [ "${max_exec:-0}" = "0" ] || { [ -n "${max_exec:-}" ] && [ "$max_exec" -ge 300 ] 2>/dev/null; }; then
        exec_col="$C_BG_GREEN"
    else
        exec_col="$C_BG_ORANGE"
    fi
    if [ -n "$max_vars" ] && [ "$max_vars" -ge 1000 ] 2>/dev/null; then
        vars_col="$C_BG_GREEN"
    else
        vars_col="$C_BG_ORANGE"
    fi
    if [ "$CONTAO_SH_PHP_COMPAT_STATUS" = "low" ] || [ "$CONTAO_SH_PHP_COMPAT_STATUS" = "high" ]; then
        php_col="$C_BG_ORANGE"
    else
        php_col="$C_BG_GREY"
    fi

    # Composer-Version: gecacht in .contao.conf, gekoppelt an die mtime der
    # composer.phar - "composer -V" ist deutlich langsamer als ein reiner
    # "php -r"-Aufruf (Composer-Bootstrap-Overhead), deshalb nicht bei jedem
    # Start neu ermitteln, sondern nur wenn sich composer.phar geändert hat.
    local composer_ver="" composer_sig="" phar_path
    if [ -n "${COMPOSER_CMD+x}" ] && [ "${#COMPOSER_CMD[@]}" -ge 2 ]; then
        phar_path="${COMPOSER_CMD[1]}"
        [ -f "$phar_path" ] && composer_sig="$(date -r "$phar_path" '+%s' 2>/dev/null)"
    fi
    if [ -n "$composer_sig" ] && [ "$composer_sig" = "${CONTAO_SH_COMPOSER_VER_SIG:-}" ] && [ -n "${CONTAO_SH_COMPOSER_VER_CACHE:-}" ]; then
        composer_ver="$CONTAO_SH_COMPOSER_VER_CACHE"
    else
        composer_ver="$("${COMPOSER_CMD[@]-}" -V 2>/dev/null | sed -E 's/^Composer version ([^ ]+).*/\1/')"
        if [ -n "$composer_ver" ] && [ -n "$composer_sig" ] && [ -n "${CONTAO_CONF_FILE:-}" ]; then
            contao_env_set_value "CONTAO_SH_COMPOSER_VER_CACHE" "CONTAO_SH_COMPOSER_VER_CACHE=\"$composer_ver\"" "$CONTAO_CONF_FILE" no_backup
            contao_env_set_value "CONTAO_SH_COMPOSER_VER_SIG" "CONTAO_SH_COMPOSER_VER_SIG=\"$composer_sig\"" "$CONTAO_CONF_FILE" no_backup
            CONTAO_SH_COMPOSER_VER_CACHE="$composer_ver"
            CONTAO_SH_COMPOSER_VER_SIG="$composer_sig"
        fi
    fi

    CONTAO_SH_STATUS_LINE="${php_col} PHP ${php_ver:-?} ${C_RESET}${mem_col} mem ${mem_limit:-?} ${C_RESET}${exec_col} exec ${max_exec:-?}s ${C_RESET}${vars_col} vars ${max_vars:-?} ${C_RESET}${C_BG_GREY} Composer ${composer_ver:-?} ${C_RESET}"
    return 0
}

# WICHTIG: contao_resolve_php muss VOR contao_check_php aufgerufen werden,
# und zwar direkt (nicht per "x=$(contao_resolve_php)") - sonst läuft die
# Funktion in einer Subshell und das global gesetzte PHP_BIN geht beim
# Zurückkehren wieder verloren.
#
# $1 = minimal benötigte Version, z.B. "8.1"
contao_check_php() {
    local required="$1"

    if [ -z "$PHP_BIN" ] || [ ! -x "$PHP_BIN" ]; then
        echo "FEHLER: Kein PHP gefunden (weder im PATH noch unter den bekannten" >&2
        echo "        MAMP-/Server-Standardpfaden). Bei Bedarf PHP_BIN_OVERRIDE im" >&2
        echo "        Konfig-Block des Scripts auf den vollen Pfad setzen." >&2
        return 1
    fi

    local version
    version="$("$PHP_BIN" -r 'echo PHP_VERSION;' 2>/dev/null)"
    if [ -z "$version" ]; then
        echo "FEHLER: PHP-Version konnte nicht ermittelt werden ($PHP_BIN -r fehlgeschlagen)." >&2
        return 1
    fi

    if ! "$PHP_BIN" -r "exit(version_compare(PHP_VERSION, '$required', '>=') ? 0 : 1);" 2>/dev/null; then
        echo "${C_ORANGE}WARNUNG: Gefundene PHP-Version $version ($PHP_BIN) ist niedriger als empfohlen ($required+).${C_RESET}" >&2
        echo "${C_ORANGE}         Contao 5 benötigt mindestens PHP $required. Ggf. PHP_BIN_OVERRIDE setzen.${C_RESET}" >&2
        return 2
    fi

    echo "$version"
    return 0
}

# ---------------------------------------------------------------------------
# composer.phar (neu) herunterladen - wird sowohl automatisch genutzt (falls
# im Zielordner noch keine composer.phar vorhanden ist, damit contao.sh nicht
# mit einem reinen Fehler abbricht), als auch manuell über den Menüpunkt
# "composer.phar herunterladen/aktualisieren", um eine vorhandene Datei
# gezielt durch die aktuelle Version zu ersetzen.
# ---------------------------------------------------------------------------
contao_download_composer_phar() {
    local target_dir="$1" dest
    dest="$target_dir/composer.phar"
    echo "Lade aktuelle composer.phar nach $dest herunter ..." >&2
    if command -v wget >/dev/null 2>&1; then
        wget -q -O "$dest" https://getcomposer.org/download/latest-stable/composer.phar 2>&2
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$dest" https://getcomposer.org/download/latest-stable/composer.phar
    else
        echo "FEHLER: Weder 'wget' noch 'curl' gefunden - composer.phar kann nicht automatisch heruntergeladen werden." >&2
        echo "        Bitte manuell laden: https://getcomposer.org/download/" >&2
        return 1
    fi
    if [ -s "$dest" ]; then
        chmod +x "$dest" 2>/dev/null
        echo "composer.phar erfolgreich heruntergeladen." >&2
        return 0
    fi
    echo "FEHLER: Download von composer.phar fehlgeschlagen." >&2
    rm -f "$dest" 2>/dev/null
    return 1
}

# ---------------------------------------------------------------------------
# Composer-Binary ermitteln (Array statt String wegen Pfaden mit Leerzeichen)
# ---------------------------------------------------------------------------
# Setzt das globale Array COMPOSER_CMD. Bewusst OHNE Fallback auf ein
# globales 'composer' im PATH: Composer-
# Aktionen (Updates, Installationen, Selfupdate) laufen ausschließlich über
# eine composer.phar im Projekt-Root. Grund: ein globales 'composer' ist auf
# Hosting-Umgebungen oft ein veraltetes Distro-Paket (apt/yum) mit alter
# composer-runtime-api, das Contao-Abhängigkeiten nicht auflösen kann und
# kein Selfupdate unterstützt - siehe genau dieses Fehlerbild in der Praxis.
# Fehlt die composer.phar, wird sie automatisch heruntergeladen.
contao_resolve_composer() {
    local root="$1"
    if [ -f "$root/composer.phar" ]; then
        COMPOSER_CMD=("${PHP_BIN:-php}" "$root/composer.phar")
        return 0
    fi
    if contao_download_composer_phar "$root"; then
        COMPOSER_CMD=("${PHP_BIN:-php}" "$root/composer.phar")
        return 0
    fi
    return 1
}

# ---------------------------------------------------------------------------
# Dialog/Whiptail-Erkennung + Theme (dunkelgrau/orange)
# ---------------------------------------------------------------------------
# Setzt DIALOG_BIN auf "dialog", "whiptail" oder "" (=> Fallback-Textmenü,
# nummernbasiert). Kein osascript/GUI - bewusst reine Terminal-Bedienung.
CONTAO_SH_DIALOGRC=""

contao_detect_dialog() {
    # Bewusst deaktiviert: contao.sh nutzt immer die eigene, gebrandete
    # Nummern-/Pfeiltasten-Oberfläche (mit Logo, Gruppierung, Farben) statt
    # dialog/whiptail - deren generisches Aussehen auf manchen Hosts (z.B.
    # per systemweit vorinstalliertem whiptail) sonst automatisch statt der
    # eigenen Optik zum Einsatz käme. Die dialog/whiptail-Unterstützung
    # bleibt im Code erhalten, wird aber nicht mehr automatisch aktiviert.
    DIALOG_BIN=""
}

# 'dialog' unterstützt eine .dialogrc-Datei mit echten Farbpaaren.
# Hinweis: Klassisches ncurses-dialog kennt nur 8 Grundfarben (+ bright-Varianten).
# Ein "echtes" Orange gibt es dort nicht - wir nähern uns mit
# fett/hell-gelb (brightyellow) an, das in den meisten Terminal-Themes warm/orange
# wirkt. Wer ein Terminal-Profil mit "richtigem" Orange auf der gelben Palette
# nutzt (z.B. angepasstes Theme in Terminal.app/iTerm2), bekommt automatisch
# echtes Orange.
contao_setup_theme() {
    CONTAO_SH_DIALOGRC="$(mktemp "${TMPDIR:-/tmp}/contao-sh-dialogrc.XXXXXX")"
    cat > "$CONTAO_SH_DIALOGRC" <<'EOF'
# Automatisch generiert von contao.sh - dunkelgrau/orange Theme
use_shadow = ON
use_colors = ON
screen_color = (WHITE,BLACK,OFF)
shadow_color = (BLACK,BLACK,ON)
dialog_color = (WHITE,BLACK,OFF)
title_color = (YELLOW,BLACK,ON)
border_color = (WHITE,BLACK,OFF)
button_active_color = (BLACK,YELLOW,ON)
button_inactive_color = (WHITE,BLACK,OFF)
button_label_active_color = (BLACK,YELLOW,ON)
button_label_inactive_color = (WHITE,BLACK,ON)
item_color = (WHITE,BLACK,OFF)
item_selected_color = (BLACK,YELLOW,ON)
tag_color = (YELLOW,BLACK,ON)
tag_selected_color = (BLACK,YELLOW,ON)
tag_key_color = (YELLOW,BLACK,ON)
tag_key_selected_color = (BLACK,YELLOW,ON)
check_color = (WHITE,BLACK,OFF)
check_selected_color = (BLACK,YELLOW,ON)
EOF
    export DIALOGRC="$CONTAO_SH_DIALOGRC"
}

# whiptail (Newt) kennt kein DIALOGRC, aber NEWT_COLORS mit denselben 8 Grundfarben.
contao_setup_theme_whiptail() {
    export NEWT_COLORS='
root=white,black
window=white,black
border=white,black
title=yellow,black
button=black,yellow
actbutton=black,yellow
checkbox=white,black
actcheckbox=black,yellow
entry=white,black
label=white,black
listbox=white,black
actlistbox=black,yellow
textbox=white,black
acttextbox=black,yellow
'
}

contao_cleanup_theme() {
    if [ -n "$CONTAO_SH_DIALOGRC" ] && [ -f "$CONTAO_SH_DIALOGRC" ]; then
        rm -f "$CONTAO_SH_DIALOGRC"
    fi
    # Falls das Textmenü mit Pfeiltasten-Navigation den Cursor ausgeblendet
    # hat (z.B. bei Abbruch per Strg+C mitten in der Navigation): sicherheitshalber
    # wieder einblenden.
    printf '\033[?25h' 2>/dev/null
}

# ---------------------------------------------------------------------------
# Logging / Session-Summary
# ---------------------------------------------------------------------------
# Einfache indexierte Arrays statt assoziativer Arrays (Bash-3.2-kompatibel).
# Das Logfile bleibt immer reiner Text (keine ANSI-Codes) - Farben gibt es
# nur auf der Konsole.
CONTAO_SH_LOG_ENTRIES=()

contao_log() {
    local msg ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    msg="[$ts] $1"
    CONTAO_SH_LOG_ENTRIES+=("$msg")

    if [ -n "${PROJECT_ROOT:-}" ]; then
        local logdir="$PROJECT_ROOT/var/log"
        mkdir -p "$logdir" 2>/dev/null
        if [ -d "$logdir" ]; then
            echo "$msg" >> "$logdir/contao-sh.log"
        fi
    fi
}

contao_print_summary() {
    echo ""
    echo "${C_ORANGE}===================== Zusammenfassung =====================${C_RESET}"
    if [ ${#CONTAO_SH_LOG_ENTRIES[@]} -eq 0 ]; then
        echo "Keine Aktionen in dieser Sitzung ausgeführt."
    else
        local entry
        for entry in "${CONTAO_SH_LOG_ENTRIES[@]-}"; do
            echo "$entry"
        done
    fi
    echo "${C_ORANGE}=============================================================${C_RESET}"
    if [ -n "${PROJECT_ROOT:-}" ]; then
        echo "Vollständiges Log: $PROJECT_ROOT/var/log/contao-sh.log"
    fi
}

# ---------------------------------------------------------------------------
# Hilfsfunktionen für Ein-/Ausgabe
# ---------------------------------------------------------------------------
# Wartet ausschließlich auf die Leertaste (keine andere Taste, auch nicht
# Enter, führt weiter) - andere Tasten werden stillschweigend ignoriert.
contao_pause() {
    # Im CLI-Parameter-Modus (siehe CONTAO_SH_CLI_MODE in contao.sh) gibt es
    # kein Terminal, das auf einen Tastendruck wartet - sonst würde ein
    # unbeaufsichtigter Aufruf (z.B. Cron) hier hängen bleiben.
    [ "${CONTAO_SH_CLI_MODE:-0}" = "1" ] && return 0
    echo ""
    printf "Weiter mit der Leertaste ... "
    local key=""
    while [ "$key" != " " ]; do
        IFS= read -n 1 -s -r key
    done
    echo ""
}

# Führt einen Befehl sichtbar aus (Array als Argumente), loggt Erfolg/Fehler.
# $1 = Beschreibung fürs Log, ab $2 = Befehl + Argumente
contao_run() {
    local desc="$1"
    shift
    echo ""
    echo "${C_GREY}-> Ausführen: $*${C_RESET}"
    echo ""
    if "$@"; then
        contao_log "OK: $desc"
        echo "${C_GREEN}OK: $desc${C_RESET}"
        return 0
    else
        local rc=$?
        contao_log "FEHLER (Exit $rc): $desc"
        echo ""
        echo "${C_RED}!! Befehl ist mit Exit-Code $rc fehlgeschlagen: $desc${C_RESET}" >&2
        return "$rc"
    fi
}

# Typisierte Sicherheitsabfrage für gefährliche/verändernde Aktionen.
# $1 = Warntext. Rückgabe 0 nur wenn Nutzer exakt "JA" eingibt.
contao_confirm_dangerous() {
    local warning="$1"
    echo ""
    echo "${C_RED}!!! VERÄNDERNDE AKTION !!!${C_RESET}"
    echo "$warning"
    echo ""
    read -r -p "Zum Bestätigen exakt JA eingeben (alles andere bricht ab): " answer
    [ "$answer" = "JA" ]
}

# ---------------------------------------------------------------------------
# UI-Abstraktion: dialog/whiptail, mit Fallback auf reines Bash-Textmenü,
# falls weder dialog noch whiptail installiert sind (kein Abbruch, kein
# nacktes Fehlschlagen - das Script bleibt in jedem Fall benutzbar).
# Auswahl erfolgt überall per Zahl (Eingabe bestätigen mit Enter).
#
# Gruppen-Header im Textmenü: ein Eintrag mit Tag "#" wird nicht als
# wählbare Option gezeigt, sondern als Leerzeile + fett/orange Label
# (Beschreibung = Label-Text). Für dialog/whiptail werden solche "#"-
# Einträge herausgefiltert (dort keine native Gruppen-Unterstützung -
# die Liste bleibt dort flach, aber weiterhin farbig/scrollbar).
# Tag "0" (immer "Beenden"/"Zurück"/"Abbrechen") wird im Textmenü
# durchgängig orange/fett hervorgehoben.
# ---------------------------------------------------------------------------

# contao_menu TITLE PROMPT [tag1 desc1 ...] - "#" desc = Gruppen-Header
# Ergebnis wird nach stdout geschrieben, leer bei Abbruch/ESC.
contao_menu() {
    local title="$1" prompt="$2"
    shift 2

    if [ "$DIALOG_BIN" = "dialog" ] || [ "$DIALOG_BIN" = "whiptail" ]; then
        local args=("$@")
        local n=${#args[@]}
        local idx=0
        local -a filtered=()
        while [ $idx -lt "$n" ]; do
            if [ "${args[$idx]}" != "#" ]; then
                filtered+=("${args[$idx]}" "${args[$((idx+1))]}")
            fi
            idx=$((idx+2))
        done
        "$DIALOG_BIN" --clear --backtitle "$TOOL_TITLE" --title "$title" \
            --menu "$prompt" 24 78 16 "${filtered[@]-}" 3>&1 1>&2 2>&3
        local rc=$?
        clear
        [ $rc -ne 0 ] && return 1
        return 0
    fi

    # Fallback: Textmenü. Mit echtem Terminal an stdin+stdout per Pfeiltasten
    # (hoch/runter + Enter) bedienbar, alternativ jederzeit Zahl + Enter.
    # Ohne Terminal (z.B. Pipe/Automatisierung/Tests) nur Zahl + Enter -
    # unverändertes bisheriges Verhalten.
    # WICHTIG: Alle reinen Anzeige-Ausgaben gehen nach stderr, da der Rückgabewert
    # dieser Funktion vom Aufrufer per "choice=$(contao_menu ...)" eingefangen wird.
    # Nur die finale Auswahl darf auf stdout landen.
    #
    # Bash 3.2 (macOS-Standard) kennt kein "local -n" (Namerefs, erst ab
    # Bash 4.3) - Übergabe der Listen deshalb über die globalen Arrays
    # CONTAO_SH_MENU_TAGS / CONTAO_SH_MENU_DESCS statt per Array-Referenz.
    CONTAO_SH_MENU_TAGS=()
    CONTAO_SH_MENU_DESCS=()
    local args=("$@")
    local n=${#args[@]}
    local idx=0
    while [ $idx -lt "$n" ]; do
        CONTAO_SH_MENU_TAGS+=("${args[$idx]}")
        CONTAO_SH_MENU_DESCS+=("${args[$((idx+1))]}")
        idx=$((idx+2))
    done

    # WICHTIG: contao_menu wird vom Aufrufer immer per Kommando-Substitution
    # eingefangen ("choice=$(contao_menu ...)") - dabei zeigt stdout (fd 1)
    # auf eine interne Pipe, ist also NIE ein Terminal, selbst in einer ganz
    # normalen interaktiven Sitzung. Alle Anzeige-Ausgaben dieser Funktion
    # laufen deshalb bewusst über stderr (fd 2), und genau das prüfen wir
    # hier auch auf Terminal-Fähigkeit - nicht stdout.
    if [ -t 0 ] && [ -t 2 ]; then
        contao_menu_arrows "$title" "$prompt"
        return $?
    fi

    contao_menu_plain "$title" "$prompt"
}

# Nummern-Fallback ohne Pfeiltasten (für Pipes/Automatisierung/Tests -
# unverändertes Verhalten). Erwartet CONTAO_SH_MENU_TAGS/-DESCS als bereits
# befüllte globale Arrays (siehe contao_menu).
contao_menu_plain() {
    local title="$1" prompt="$2"

    {
        echo ""
        echo "${C_ORANGE}=== $title ===${C_RESET}"
        echo "$prompt"
    } >&2
    local k first=1
    for k in "${!CONTAO_SH_MENU_TAGS[@]}"; do
        if [ "${CONTAO_SH_MENU_TAGS[$k]}" = "#" ]; then
            echo "" >&2
            echo "${C_ORANGE}${CONTAO_SH_MENU_DESCS[$k]}${C_RESET}" >&2
        elif [ "${CONTAO_SH_MENU_TAGS[$k]}" = "0" ]; then
            [ $first -eq 1 ] && echo "" >&2
            printf "  ${C_ORANGE}[%2s] %s${C_RESET}\n" "${CONTAO_SH_MENU_TAGS[$k]}" "${CONTAO_SH_MENU_DESCS[$k]}" >&2
        else
            [ $first -eq 1 ] && echo "" >&2
            printf "  [%2s] %s\n" "${CONTAO_SH_MENU_TAGS[$k]}" "${CONTAO_SH_MENU_DESCS[$k]}" >&2
        fi
        first=0
    done
    echo "" >&2
    read -r -p "Auswahl: " choice
    [ -z "$choice" ] && return 1

    for k in "${!CONTAO_SH_MENU_TAGS[@]}"; do
        if [ "${CONTAO_SH_MENU_TAGS[$k]}" != "#" ] && [ "$choice" = "${CONTAO_SH_MENU_TAGS[$k]}" ]; then
            echo "${CONTAO_SH_MENU_TAGS[$k]}"
            return 0
        fi
    done

    echo "Ungültige Auswahl: $choice" >&2
    return 1
}

# Pfeiltasten-Menü für ein echtes Terminal. Hoch/Runter bewegt die
# Markierung (überspringt "#"-Gruppenüberschriften), Pfeil-rechts ODER
# Enter bestätigt die markierte Zeile, Pfeil-links springt sofort zur
# Kennung "0" (Beenden/Zurück/Abbrechen - laut Konvention immer vorhanden)
# und bestätigt sie direkt, ohne erst dorthin navigieren zu müssen. Esc
# bricht ohne Auswahl ab. Alternativ kann jederzeit eine Zahl getippt
# werden, nach Enter wird direkt zur passenden Kennung gesprungen. Erwartet
# CONTAO_SH_MENU_TAGS/-DESCS als bereits befüllte globale Arrays (siehe
# contao_menu).
#
# Rendert jeden Bildschirm komplett in eine Variable ($frame) und gibt sie
# mit EINEM printf aus (statt zeilenweise) - vermeidet Flackern beim
# Neuzeichnen. Der Timeout beim Lesen der Escape-Sequenz ist bewusst
# ganzzahlig (kein "-t 0.05"): macOS' Standard-Bash 3.2 unterstützt keine
# Nachkommazeit bei "read -t".
contao_menu_arrows() {
    local title="$1" prompt="$2"

    local -a selectable=()
    local k
    for k in "${!CONTAO_SH_MENU_TAGS[@]}"; do
        [ "${CONTAO_SH_MENU_TAGS[$k]}" != "#" ] && selectable+=("$k")
    done
    [ ${#selectable[@]} -eq 0 ] && return 1

    # Kennung "0" (Beenden/Zurück/Abbrechen) für den Pfeil-links-Kurzbefehl
    # vormerken, falls in diesem Menü vorhanden.
    local zero_idx="" m2
    for m2 in "${!CONTAO_SH_MENU_TAGS[@]}"; do
        if [ "${CONTAO_SH_MENU_TAGS[$m2]}" = "0" ]; then
            zero_idx="$m2"
            break
        fi
    done

    local cur=0 redraw=1 key esc numbuf="" frame first_draw=1

    printf '\033[?25l' >&2

    while true; do
        if [ "$redraw" = "1" ]; then
            frame=$'\033[H\033[2J\033[3J'
            frame="${frame}${CONTAO_SH_LOGO_BLOCK:-}"
            frame="${frame}"$'\n'"${C_ORANGE}=== $title ===${C_RESET}"$'\n'
            # Pfad-Zeile (z.B. "Pfad: /var/www/projekt") wird - wie im
            # demo-contao.sh-Vorbild - bei JEDEM Redraw gezeigt, nicht nur
            # beim ersten Zeichnen, damit der Projektkontext immer sichtbar
            # bleibt. Wird von contao.sh global in CONTAO_SH_PATH_LINE gesetzt.
            [ -n "${CONTAO_SH_PATH_LINE:-}" ] && frame="${frame}${CONTAO_SH_PATH_LINE}"$'\n'
            [ -n "${CONTAO_SH_STATUS_LINE:-}" ] && frame="${frame}${CONTAO_SH_STATUS_LINE}"$'\n'
            # Prompt-Text (z.B. der längere Intro-/Marketing-Satz) dagegen
            # nur beim ersten Zeichnen dieses Menüs zeigen - bei erneutem
            # Redraw durch Pfeiltasten-Navigation (selbe Sitzung) nicht
            # wiederholen, um die Ansicht kompakt zu halten.
            [ "$first_draw" = "1" ] && [ -n "$prompt" ] && frame="${frame}${prompt}"$'\n'
            # Bedienungs-Hinweiszeile ebenfalls nur beim allerersten Zeichnen
            # eines Menüs in der gesamten Sitzung zeigen (globaler Flag, wie
            # hint_shown in der demo-contao.sh-Vorlage) - nicht bei jedem
            # Redraw und nicht bei jedem neu geöffneten Menü.
            if [ "$CONTAO_SH_HINT_SHOWN" != "1" ]; then
                frame="${frame}"$'\n'"${C_GREY}(Pfeiltasten hoch/runter, rechts/Enter bestätigt, links = zurück - oder Zahl + Enter)${C_RESET}"$'\n'
                CONTAO_SH_HINT_SHOWN=1
            fi
            local m line
            for m in "${!CONTAO_SH_MENU_TAGS[@]}"; do
                if [ "${CONTAO_SH_MENU_TAGS[$m]}" = "#" ]; then
                    frame="${frame}"$'\n'"${C_ORANGE}${CONTAO_SH_MENU_DESCS[$m]}${C_RESET}"$'\n'
                    continue
                fi
                line="$(printf "[%2s] %s" "${CONTAO_SH_MENU_TAGS[$m]}" "${CONTAO_SH_MENU_DESCS[$m]}")"
                if [ "$m" = "${selectable[$cur]}" ]; then
                    frame="${frame}${C_SELECT} > ${line}${C_RESET}"$'\n'
                elif [ "${CONTAO_SH_MENU_TAGS[$m]}" = "0" ]; then
                    frame="${frame}   ${C_ORANGE}${line}${C_RESET}"$'\n'
                else
                    frame="${frame}   ${line}"$'\n'
                fi
            done
            frame="${frame}"$'\n'
            [ -n "$numbuf" ] && frame="${frame}Auswahl: ${numbuf}"$'\n'
            printf '%s' "$frame" >&2
            redraw=0
            first_draw=0
        fi

        IFS= read -rsn1 key
        case "$key" in
            $'\x1b')
                IFS= read -rsn2 -t 1 esc
                case "$esc" in
                    '[A')
                        cur=$(( (cur - 1 + ${#selectable[@]}) % ${#selectable[@]} ))
                        redraw=1
                        ;;
                    '[B')
                        cur=$(( (cur + 1) % ${#selectable[@]} ))
                        redraw=1
                        ;;
                    '[C')
                        # Pfeil rechts = bestätigen, wie Enter
                        printf '\033[?25h' >&2
                        echo "${CONTAO_SH_MENU_TAGS[${selectable[$cur]}]}"
                        return 0
                        ;;
                    '[D')
                        # Pfeil links = direkt zu "0" springen und bestätigen
                        if [ -n "$zero_idx" ]; then
                            printf '\033[?25h' >&2
                            echo "0"
                            return 0
                        fi
                        ;;
                    '')
                        # Alleinstehendes Esc (kein Pfeiltasten-Code danach) -> Abbruch
                        printf '\033[?25h' >&2
                        return 1
                        ;;
                esac
                ;;
            "")
                printf '\033[?25h' >&2
                if [ -n "$numbuf" ]; then
                    for k in "${!CONTAO_SH_MENU_TAGS[@]}"; do
                        if [ "${CONTAO_SH_MENU_TAGS[$k]}" != "#" ] && [ "$numbuf" = "${CONTAO_SH_MENU_TAGS[$k]}" ]; then
                            echo "${CONTAO_SH_MENU_TAGS[$k]}"
                            return 0
                        fi
                    done
                    echo "Ungültige Auswahl: $numbuf" >&2
                    return 1
                fi
                echo "${CONTAO_SH_MENU_TAGS[${selectable[$cur]}]}"
                return 0
                ;;
            [0-9.])
                numbuf="$numbuf$key"
                redraw=1
                ;;
        esac
    done
}

# contao_yesno TITLE TEXT -> Exit-Code 0 = Ja
contao_yesno() {
    local title="$1" text="$2"
    # Im CLI-Parameter-Modus gilt der Parameter selbst als Zustimmung - keine
    # Rückfrage, sonst nicht unbeaufsichtigt automatisierbar (siehe
    # CONTAO_SH_CLI_MODE in contao.sh).
    [ "${CONTAO_SH_CLI_MODE:-0}" = "1" ] && return 0
    if [ "$DIALOG_BIN" = "dialog" ] || [ "$DIALOG_BIN" = "whiptail" ]; then
        "$DIALOG_BIN" --clear --backtitle "$TOOL_TITLE" --title "$title" --yesno "$text" 12 70
        local rc=$?
        clear
        return $rc
    fi
    echo ""
    echo "${C_ORANGE}=== $title ===${C_RESET}"
    printf '%b\n' "$text"
    read -r -p "Ja/Nein [j/N]: " answer
    case "$answer" in
        j|J|y|Y) return 0 ;;
        *) return 1 ;;
    esac
}

# contao_inputbox TITLE PROMPT DEFAULT -> Ergebnis auf stdout
contao_inputbox() {
    local title="$1" prompt="$2" default="$3"
    if [ "$DIALOG_BIN" = "dialog" ] || [ "$DIALOG_BIN" = "whiptail" ]; then
        "$DIALOG_BIN" --clear --backtitle "$TOOL_TITLE" --title "$title" \
            --inputbox "$prompt" 10 70 "$default" 3>&1 1>&2 2>&3
        local rc=$?
        clear
        [ $rc -ne 0 ] && return 1
        return 0
    fi
    {
        echo ""
        echo "${C_ORANGE}=== $title ===${C_RESET}"
    } >&2
    read -r -p "$prompt [$default]: " value
    echo "${value:-$default}"
    return 0
}

# contao_passwordbox TITLE PROMPT -> Ergebnis auf stdout (maskierte Eingabe)
# Leere Eingabe ist ein gültiges Ergebnis (Aufrufer entscheidet z.B. "leer
# = altes Passwort behalten"). Nur ESC/Abbrechen liefert Exit-Code 1.
contao_passwordbox() {
    local title="$1" prompt="$2"
    if [ "$DIALOG_BIN" = "dialog" ]; then
        "$DIALOG_BIN" --clear --backtitle "$TOOL_TITLE" --title "$title" \
            --insecure --passwordbox "$prompt" 10 70 3>&1 1>&2 2>&3
        local rc=$?
        clear
        [ $rc -ne 0 ] && return 1
        return 0
    fi
    if [ "$DIALOG_BIN" = "whiptail" ]; then
        "$DIALOG_BIN" --clear --backtitle "$TOOL_TITLE" --title "$title" \
            --passwordbox "$prompt" 10 70 3>&1 1>&2 2>&3
        local rc=$?
        clear
        [ $rc -ne 0 ] && return 1
        return 0
    fi
    {
        echo ""
        echo "${C_ORANGE}=== $title ===${C_RESET}"
    } >&2
    local value
    read -r -s -p "$prompt " value
    echo "" >&2
    echo "$value"
    return 0
}

# contao_msgbox TITLE TEXT
contao_msgbox() {
    local title="$1" text="$2"
    if [ "$DIALOG_BIN" = "dialog" ] || [ "$DIALOG_BIN" = "whiptail" ]; then
        "$DIALOG_BIN" --clear --backtitle "$TOOL_TITLE" --title "$title" --msgbox "$text" 12 70
        clear
        return
    fi
    echo ""
    echo "${C_ORANGE}=== $title ===${C_RESET}"
    printf '%b\n' "$text"
    contao_pause
}

# contao_checklist TITLE PROMPT tag1 desc1 status1 [tag2 desc2 status2 ...]
# status = "on"/"off". Ergebnis: durch Leerzeichen getrennte Tags auf stdout.
contao_checklist() {
    local title="$1" prompt="$2"
    shift 2

    if [ "$DIALOG_BIN" = "dialog" ] || [ "$DIALOG_BIN" = "whiptail" ]; then
        "$DIALOG_BIN" --clear --backtitle "$TOOL_TITLE" --title "$title" \
            --checklist "$prompt" 22 78 14 "$@" 3>&1 1>&2 2>&3
        local rc=$?
        clear
        [ $rc -ne 0 ] && return 1
        return 0
    fi

    # TTY-Erkennung wie bei contao_menu: contao_checklist wird immer per
    # Command-Substitution aufgerufen ("sel=$(contao_checklist ...)"), daher
    # auf stderr (fd 2) statt stdout prüfen.
    if [ -t 0 ] && [ -t 2 ]; then
        contao_checklist_arrows "$title" "$prompt" "$@"
        return $?
    fi

    contao_checklist_plain "$title" "$prompt" "$@"
}

# contao_checklist_arrows TITLE PROMPT tag1 desc1 status1 [...]
# Interaktive Checkbox-Liste mit Pfeiltasten-Navigation, analog zum
# Checkbox-Untermenü der demo-contao.sh-Vorlage: hoch/runter bewegt den
# Cursor, Leertaste oder die passende Zifferntaste (1-9) (de)markiert den
# jeweiligen Eintrag, der letzte Eintrag "[ 0] Fertig" übernimmt die
# aktuelle Auswahl (Pfeil-rechts/Enter darauf, Ziffer 0, oder Pfeil-links
# als Kurzbefehl von überall). Ergebnis: durch Leerzeichen getrennte Tags
# auf stdout, leer bei "Fertig" ohne Auswahl, nichts + Rückgabe 1 bei Esc.
# Nur die ersten 9 Einträge sind per Zifferntaste direkt ansteuerbar -
# darüber hinaus nur per Pfeiltasten (0 ist immer für "Fertig" reserviert).
contao_checklist_arrows() {
    local title="$1" prompt="$2"
    shift 2
    local -a args=("$@")
    local n_args=${#args[@]}
    local -a tags=() descs=() checked=()
    local idx=0
    while [ $idx -lt "$n_args" ]; do
        tags+=("${args[$idx]}")
        descs+=("${args[$((idx+1))]}")
        if [ "${args[$((idx+2))]}" = "on" ]; then
            checked+=(1)
        else
            checked+=(0)
        fi
        idx=$((idx+3))
    done
    local n=${#tags[@]}
    [ "$n" -eq 0 ] && return 1

    local cur=0 redraw=1 key esc frame first_draw=1 confirm=0

    printf '\033[?25l' >&2

    while true; do
        if [ "$redraw" = "1" ]; then
            frame=$'\033[H\033[2J\033[3J'
            frame="${frame}${CONTAO_SH_LOGO_BLOCK:-}"
            frame="${frame}"$'\n'"${C_ORANGE}=== $title ===${C_RESET}"$'\n'
            [ -n "${CONTAO_SH_PATH_LINE:-}" ] && frame="${frame}${CONTAO_SH_PATH_LINE}"$'\n'
            [ -n "${CONTAO_SH_STATUS_LINE:-}" ] && frame="${frame}${CONTAO_SH_STATUS_LINE}"$'\n'
            [ "$first_draw" = "1" ] && [ -n "$prompt" ] && frame="${frame}${prompt}"$'\n'
            if [ "$CONTAO_SH_HINT_SHOWN" != "1" ]; then
                frame="${frame}"$'\n'"${C_GREY}(Hoch/runter navigieren, Leertaste/Zifferntaste markiert, rechts/Enter auf \"Fertig\" bestätigt, links = sofort fertig)${C_RESET}"$'\n'
                CONTAO_SH_HINT_SHOWN=1
            fi
            frame="${frame}"$'\n'
            local i mark line
            for (( i = 0; i < n; i++ )); do
                if [ "${checked[$i]}" = "1" ]; then
                    mark="x"
                else
                    mark=" "
                fi
                line="$(printf "[%s] [%2d] %s" "$mark" "$((i+1))" "${descs[$i]}")"
                if [ "$cur" -eq "$i" ]; then
                    frame="${frame}${C_SELECT} > ${line}${C_RESET}"$'\n'
                elif [ "${checked[$i]}" = "1" ]; then
                    frame="${frame}${C_GREEN}   ${line}${C_RESET}"$'\n'
                else
                    frame="${frame}   ${line}"$'\n'
                fi
            done
            frame="${frame}"$'\n'
            if [ "$cur" -eq "$n" ]; then
                frame="${frame}${C_SELECT} > [ 0] Fertig - Auswahl übernehmen${C_RESET}"$'\n'
            else
                frame="${frame}   ${C_ORANGE}[ 0] Fertig - Auswahl übernehmen${C_RESET}"$'\n'
            fi
            printf '%s' "$frame" >&2
            redraw=0
            first_draw=0
        fi

        IFS= read -rsn1 key
        case "$key" in
            $'\x1b')
                IFS= read -rsn2 -t 1 esc
                case "$esc" in
                    '[A')
                        cur=$(( (cur - 1 + (n + 1)) % (n + 1) ))
                        redraw=1
                        ;;
                    '[B')
                        cur=$(( (cur + 1) % (n + 1) ))
                        redraw=1
                        ;;
                    '[C')
                        if [ "$cur" -eq "$n" ]; then
                            confirm=1
                        else
                            if [ "${checked[$cur]}" = "1" ]; then checked[$cur]=0; else checked[$cur]=1; fi
                            redraw=1
                        fi
                        ;;
                    '[D')
                        # Pfeil links = sofort "Fertig" (Kurzbefehl, wie im
                        # normalen Menü der Sprung zu "0")
                        confirm=1
                        ;;
                    '')
                        printf '\033[?25h' >&2
                        return 1
                        ;;
                esac
                ;;
            " ")
                if [ "$cur" -lt "$n" ]; then
                    if [ "${checked[$cur]}" = "1" ]; then checked[$cur]=0; else checked[$cur]=1; fi
                fi
                redraw=1
                ;;
            "")
                if [ "$cur" -eq "$n" ]; then
                    confirm=1
                else
                    if [ "${checked[$cur]}" = "1" ]; then checked[$cur]=0; else checked[$cur]=1; fi
                    redraw=1
                fi
                ;;
            [0-9])
                if [ "$key" = "0" ]; then
                    cur=$n
                    confirm=1
                else
                    local pos=$((key - 1))
                    if [ "$pos" -ge 0 ] && [ "$pos" -lt "$n" ]; then
                        cur=$pos
                        if [ "${checked[$cur]}" = "1" ]; then checked[$cur]=0; else checked[$cur]=1; fi
                        redraw=1
                    fi
                fi
                ;;
        esac
        [ "$confirm" = "1" ] && break
    done

    printf '\033[?25h' >&2
    local result="" i
    for (( i = 0; i < n; i++ )); do
        [ "${checked[$i]}" = "1" ] && result="$result ${tags[$i]}"
    done
    echo "$result"
    return 0
}

# Nummern-Fallback ohne Pfeiltasten (für Pipes/Automatisierung/Tests -
# unverändertes Verhalten).
contao_checklist_plain() {
    local title="$1" prompt="$2"
    shift 2
    local args=("$@")
    local n=${#args[@]}
    local -a tags=() descs=() states=()
    local idx=0
    while [ $idx -lt "$n" ]; do
        tags+=("${args[$idx]}")
        descs+=("${args[$((idx+1))]}")
        states+=("${args[$((idx+2))]}")
        idx=$((idx+3))
    done
    {
        echo ""
        echo "${C_ORANGE}=== $title ===${C_RESET}"
        echo "$prompt"
        echo "(Nummern kommagetrennt eingeben, z.B. 1,3,4)"
        echo ""
    } >&2
    local k
    for k in "${!tags[@]}"; do
        printf "  [%2s] %s\n" "$((k+1))" "${descs[$k]}" >&2
    done
    printf "  ${C_ORANGE}[%2s] %s${C_RESET}\n" "0" "Abbrechen" >&2
    echo "" >&2
    read -r -p "Auswahl: " raw
    raw="$(echo "$raw" | tr -d ' ')"
    if [ -z "$raw" ] || [ "$raw" = "0" ]; then
        echo "Abgebrochen." >&2
        return 1
    fi
    local result="" sel
    IFS=',' read -r -a picks <<< "$raw"
    for sel in "${picks[@]-}"; do
        sel="$(echo "$sel" | tr -d ' ')"
        [ -z "$sel" ] && continue
        [ "$sel" = "0" ] && continue
        local pos=$((sel-1))
        if [ $pos -ge 0 ] && [ $pos -lt ${#tags[@]} ]; then
            result="$result ${tags[$pos]}"
            echo "  [x] ${descs[$pos]}" >&2
        fi
    done

    if [ -z "$result" ]; then
        echo "Keine gültige Auswahl - abgebrochen." >&2
        return 1
    fi

    echo "$result"
    return 0
}

# ---------------------------------------------------------------------------
# .env.local lesen/schreiben (für DATABASE_URL / MAILER_DSN)
# ---------------------------------------------------------------------------

# Liefert den rohen Wert (ohne Anführungszeichen) von KEY aus FILE,
# leer + Exit 1 wenn nicht vorhanden.
contao_env_get_value() {
    local key="$1" file="$2" line val
    [ -f "$file" ] || return 1
    line="$(grep -E "^${key}=" "$file" | tail -n1)"
    [ -z "$line" ] && return 1
    val="${line#*=}"
    val="${val%\"}"
    val="${val#\"}"
    echo "$val"
    return 0
}

# Ersetzt die Zeile "KEY=..." in FILE durch LINE (komplette Zeile inkl.
# KEY=), hängt sie an, falls KEY noch nicht existiert. FILE wird bei Bedarf
# neu angelegt. Vor dem Schreiben wird - falls die Datei existiert und $4
# nicht "no_backup" ist - eine Zeitstempel-Sicherungskopie angelegt. Das
# Backup ist optional, das Speichern selbst erfolgt in jedem Fall.
contao_env_set_value() {
    local key="$1" line="$2" file="$3" skip_backup="${4:-}"
    local tmp replaced=0 l

    if [ -f "$file" ] && [ "$skip_backup" != "no_backup" ]; then
        cp "$file" "$file.bak-$(date '+%Y%m%d%H%M%S')"
    fi

    tmp="$(mktemp "${TMPDIR:-/tmp}/contao-sh-env.XXXXXX")"
    if [ -f "$file" ]; then
        while IFS= read -r l || [ -n "$l" ]; do
            case "$l" in
                "${key}="*)
                    echo "$line" >> "$tmp"
                    replaced=1
                    ;;
                *)
                    echo "$l" >> "$tmp"
                    ;;
            esac
        done < "$file"
    fi

    if [ "$replaced" -eq 0 ]; then
        echo "$line" >> "$tmp"
    fi

    mv "$tmp" "$file"
}

# Entfernt die Zeile "KEY=..." komplett aus FILE (z.B. um eine gespeicherte
# Override-Einstellung wieder auf "automatisch/Standard" zurückzusetzen,
# ohne dabei andere Einstellungen in derselben Datei zu verlieren). Kein
# Fehler, falls FILE oder KEY nicht existiert.
contao_env_unset_value() {
    local key="$1" file="$2"
    [ -f "$file" ] || return 0
    local tmp l
    tmp="$(mktemp "${TMPDIR:-/tmp}/contao-sh-env.XXXXXX")"
    while IFS= read -r l || [ -n "$l" ]; do
        case "$l" in
            "${key}="*) ;;
            *) echo "$l" >> "$tmp" ;;
        esac
    done < "$file"
    mv "$tmp" "$file"
}

# Maskiert das Passwort in einer mysql://... oder smtp://...-URL für die
# Anzeige (user:PASS@ -> user:***@).
contao_env_mask_url() {
    echo "$1" | sed -E 's#(://[^:@/]*:)[^@]*(@)#\1***\2#'
}
