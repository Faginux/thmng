#!/bin/bash
# ======================================================================
#  thmng.sh
#  Trash & Health Manage
#  Oscar - Debian 12 BTRFS
#
#  Funzionalità:
#   - Scansione dischi esterni in /media/
#   - Rilevamento cestini (.Trash-UID, .Trash, .Trash-0)
#   - Verifica leggibilità cestini (consigli su svuotare/bloccare)
#   - Interfaccia interattiva per scegliere azioni
#   - Log separati: trash_check.log e disk_health.log
#   - Controllo salute dischi con smartctl (score 0-10)
#   - Progress bar ASCII durante la scansione
#   - Suggerimenti finali per azioni consigliate
# ======================================================================

TRASH_LOG="./trash_check.log"
HEALTH_LOG="./disk_health.log"
EXCLUDES=("oscar-it12" "nomachine" "cdrom")
UIDNUM=$(id -u)
TRASH_NAMES=(".Trash-$UIDNUM" ".Trash" ".Trash-0")
actions=()
recommendations=()

progress_bar() {
    local current=$1
    local total=$2
    local width=40
    local percent=$(( 100 * current / total ))
    local filled=$(( width * current / total ))
    local empty=$(( width - filled ))
    printf "["
    for ((i=0; i<filled; i++)); do printf "#"; done
    for ((i=0; i<empty; i++)); do printf "."; done
    printf "] %3d%%\r" $percent
}

if [ "$EUID" -ne 0 ]; then
    echo "+-----------------------------------------------------+"
    echo "| ATTENZIONE: questo script richiede privilegi di root |"
    echo "+-----------------------------------------------------+"
    read -rp "Vuoi rilanciarlo con sudo? (s/n): " ans
    if [[ "$ans" =~ ^[sS]$ ]]; then
        exec sudo "$0" "$@"
    else
        echo "Uscita senza modifiche."
        exit 1
    fi
fi

if ! command -v smartctl &>/dev/null; then
    echo "+-----------------------------------------------------+"
    echo "| smartctl non trovato: serve per controllare i dischi |"
    echo "+-----------------------------------------------------+"
    read -rp "Vuoi installarlo adesso? (s/n): " ans
    if [[ "$ans" =~ ^[sS]$ ]]; then
        apt update && apt install -y smartmontools
    else
        echo "Uscita senza installare smartctl."
        exit 1
    fi
fi

echo "======================================================="
echo "           TRASH & HEALTH MANAGE (thmng.sh)            "
echo "======================================================="
echo " Log cestini: $TRASH_LOG"
echo " Log salute : $HEALTH_LOG"
echo "-------------------------------------------------------"

echo "=== LOG CESTINI ($(date)) ===" > "$TRASH_LOG"
echo "=== LOG SALUTE DISCHI ($(date)) ===" > "$HEALTH_LOG"

echo ""
echo "+-----------------------------------------------------+"
echo "| SEZIONE 1: ANALISI E GESTIONE CESTINI               |"
echo "+-----------------------------------------------------+"

for disk in /media/*; do
    name=$(basename "$disk")
    if [[ " ${EXCLUDES[@]} " =~ " $name " ]]; then
        continue
    fi

    echo ""
    echo "-------------------------------------------------------"
    echo " DISCO: $name"
    echo "-------------------------------------------------------"
    echo "[$(date)] Disco: $name" >> "$TRASH_LOG"

    found=false
    for trash in "${TRASH_NAMES[@]}"; do
        fullpath="$disk/$trash"
        if [ -d "$fullpath" ]; then
            found=true
            echo " - Cestino trovato: $trash"
            if ls "$fullpath" &>/dev/null; then
                echo "   Stato: leggibile"
                echo "   Cestino leggibile: $trash" >> "$TRASH_LOG"
            else
                echo "   Stato: NOT leggibile (corrotto o permessi errati)"
                echo "   -> Consiglio: bloccare il cestino invece di svuotarlo"
                recommendations+=("Sul disco $name è consigliato BLOCCARE il cestino $trash per evitare errori futuri.")
                echo "   Cestino corrotto: $trash" >> "$TRASH_LOG"
            fi

            echo "   Azioni possibili:"
            echo "     1) Svuotare il cestino"
            echo "     2) Bloccare la cartella del cestino"
            echo "     3) Ignorare"
            read -rp "   Scegli azione (1/2/3): " choice

            case $choice in
                1)
                    echo "   [Dry-run] Svuoterei $fullpath/*"
                    actions+=("rm -rf \"$fullpath\"/*")
                    ;;
                2)
                    echo "   [Dry-run] Bloccherei $fullpath"
                    actions+=("rm -rf \"$fullpath\" && touch \"$fullpath\" && chmod 000 \"$fullpath\"")
                    ;;
                3|*)
                    echo "   Nessuna azione selezionata."
                    ;;
            esac
            break
        fi
    done

    if ! $found; then
        echo " - Nessun cestino trovato."
        echo "   Nessun cestino trovato" >> "$TRASH_LOG"
    fi
done

echo ""
echo "+-----------------------------------------------------+"
echo "| RIEPILOGO AZIONI CESTINI                            |"
echo "+-----------------------------------------------------+"
if [ ${#actions[@]} -eq 0 ]; then
    echo " Nessuna azione pianificata."
else
    for act in "${actions[@]}"; do
        echo " - $act"
    done
    echo "-------------------------------------------------------"
    read -rp "Vuoi applicare queste modifiche? (s/n): " confirm
    if [[ "$confirm" =~ ^[sS]$ ]]; then
        for act in "${actions[@]}"; do
            eval "$act"
        done
        echo " Operazioni completate."
    else
        echo " Nessuna modifica applicata."
    fi
fi

echo ""
echo "+-----------------------------------------------------+"
echo "| SEZIONE 2: CONTROLLO SALUTE DISCHI                  |"
echo "+-----------------------------------------------------+"

echo "Parametri di riferimento:"
echo " - Reallocated sectors: 0 ottimo; >5 warning; >20 rischio"
echo " - Pending sectors    : 0 ottimo; >0 da osservare"
echo " - Ore di utilizzo    : <20000 ottimo; 20000-40000 medio; >40000 usura"
echo " - Cicli accensione   : <10000 ottimo; 10000-20000 medio; >20000 alto"
echo "-------------------------------------------------------"

devices=(/dev/sd? /dev/nvme?n1)
total=${#devices[@]}
current=0

for dev in "${devices[@]}"; do
    if [ -b "$dev" ]; then
        current=$((current + 1))
        progress_bar $current $total

        echo ""
        echo "======================================================="
        echo " DISCO: $dev"
        echo "======================================================="

        score=10
        log_entry="[$(date)] Disco: $dev "

        if ! smartctl -H "$dev" | grep -q "PASSED"; then
            score=$((score - 5))
            echo " Stato SMART: NOT PASSED"
            log_entry+="SMART=FAIL "
            recommendations+=("Il disco $dev ha stato SMART NOT PASSED. Consigliato BACKUP urgente e sostituzione.")
        else
            echo " Stato SMART: PASSED"
            log_entry+="SMART=PASS "
        fi

        realloc=$(smartctl -A "$dev" | grep -E "Reallocated_Sector_Ct" | awk '{print $10}')
        realloc=${realloc:-0}
        if (( realloc == 0 )); then
            echo " Reallocated sectors: $realloc (ottimo)"
        elif (( realloc <= 5 )); then
            echo " Reallocated sectors: $realloc (warning)"
            score=$((score - 1))
        elif (( realloc <= 20 )); then
            echo " Reallocated sectors: $realloc (medio alto)"
            score=$((score - 3))
        else
            echo " Reallocated sectors: $realloc (grave)"
            score=$((score - 5))
            recommendations+=("Il disco $dev ha molti settori riallocati ($realloc). Valutare sostituzione.")
        fi
        log_entry+="Realloc=$realloc "

        pending=$(smartctl -A "$dev" | grep -E "Current_Pending_Sector" | awk '{print $10}')
        pending=${pending:-0}
        if (( pending == 0 )); then
            echo " Pending sectors: $pending (ottimo)"
        else
            echo " Pending sectors: $pending (warning)"
            score=$((score - 3))
            recommendations+=("Il disco $dev ha $pending settori pending. Da monitorare con attenzione.")
        fi
        log_entry+="Pending=$pending "

        hours=$(smartctl -A "$dev" | grep -i "Power_On_Hours" | awk '{print $10}')
        if [[ -n "$hours" ]]; then
            if (( hours < 20000 )); then
                echo " Ore di utilizzo: $hours (ottimo)"
            elif (( hours < 40000 )); then
                echo " Ore di utilizzo: $hours (medio)"
                score=$((score - 1))
            else
                echo " Ore di utilizzo: $hours (usura alta)"
                score=$((score - 2))
                recommendations+=("Il disco $dev ha oltre $hours ore di utilizzo. È vecchio, valutare sostituzione.")
            fi
        fi
        log_entry+="Hours=${hours:-N/A} "

        cycles=$(smartctl -A "$dev" | grep -Ei "Power_Cycle_Count|Start_Stop_Count" | awk '{print $10}' | head -n1)
        if [[ -n "$cycles" ]]; then
            if (( cycles < 10000 )); then
                echo " Cicli accensione: $cycles (ottimo)"
            elif (( cycles < 20000 )); then
                echo " Cicli accensione: $cycles (medio)"
                score=$((score - 1))
            else
                echo " Cicli accensione: $cycles (usura alta)"
                score=$((score - 2))
                recommendations+=("Il disco $dev ha $cycles cicli di accensione. Usura meccanica elevata.")
            fi
        fi
        log_entry+="Cycles=${cycles:-N/A} "

        if (( score < 0 )); then score=0; fi
        echo "-------------------------------------------------------"
        echo " Salute stimata: $score / 10"
        echo "-------------------------------------------------------"
        log_entry+="Score=$score"

        echo "$log_entry" >> "$HEALTH_LOG"

        if (( score < 8 )); then
            read -rp "Vuoi vedere i dettagli smartctl per $dev? (s/n): " ans
            if [[ "$ans" =~ ^[sS]$ ]]; then
                smartctl -a "$dev" | less
            fi
        fi
    fi
done

echo ""
echo "======================================================="
echo " ANALISI COMPLETATA"
echo " Report cestini: $TRASH_LOG"
echo " Report salute : $HEALTH_LOG"
echo "======================================================="

if [ ${#recommendations[@]} -eq 0 ]; then
    echo " Nessuna azione urgente necessaria."
else
    echo " AZIONI CONSIGLIATE:"
    for rec in "${recommendations[@]}"; do
        echo " - $rec"
    done
fi

