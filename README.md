# thmng.sh - Trash & Health Manage

[![MIT License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

Uno script Bash per Debian/Linux che aiuta a:

- Gestire i cestini (`.Trash-UID`, `.Trash`, `.Trash-0`) sui dischi esterni
- Svuotarli, bloccarli o ignorarli in modo interattivo
- Rilevare cestini corrotti e suggerire il blocco
- Analizzare la salute dei dischi con `smartctl`
- Calcolare un punteggio di salute (0–10)
- Mostrare log separati per cestini e dischi
- Fornire suggerimenti su azioni consigliate
- Visualizzare una progress bar ASCII durante la scansione

## ✨ Funzionalità principali

- **Gestione cestini**
  - Trova cestini nascosti sui dischi montati in `/media/`
  - Li svuota, blocca o ignora a scelta
  - Segnala se un cestino è corrotto e suggerisce il blocco
  - Log salvato in `trash_check.log`

- **Controllo salute dischi**
  - Usa `smartctl` per raccogliere parametri SMART
  - Valutazione da 0 a 10 basata su:
    - Reallocated Sectors
    - Pending Sectors
    - Ore di utilizzo (Power_On_Hours)
    - Cicli di accensione (Power_Cycle_Count)
  - Mostra progress bar ASCII durante la scansione
  - Log salvato in `disk_health.log`

- **Suggerimenti finali**
  - Consigli automatici se un cestino è corrotto o un disco mostra warning/errori
  - Azioni suggerite: blocco cestini, monitoraggio dischi, backup/sostituzione

## 🚀 Utilizzo

1. Clona il repo:
   ```bash
   git clone https://github.com/<tuo-username>/thmng.git
   cd thmng
   ```

2. Rendi eseguibile lo script:
   ```bash
   chmod +x thmng.sh
   ```

3. Lancialo:
   ```bash
   ./thmng.sh
   ```

> ⚠️ Lo script richiede **privilegi root** per accedere ai dati SMART.  
> Se non viene lanciato come root, chiederà se rilanciarlo con `sudo`.

## 📂 Log generati

- `trash_check.log` → riepilogo gestione cestini
- `disk_health.log` → stato SMART e punteggi dei dischi

Esempio di voce in `disk_health.log`:
```
[2025-09-19] Disco: /dev/sdd SMART=FAIL Realloc=34 Pending=12 Hours=22000 Cycles=6000 Score=3
```

## 🛠 Requisiti

- Debian o distribuzioni compatibili
- `bash`
- `smartmontools` (installato automaticamente se assente)

## 📜 Licenza

Rilasciato sotto licenza **MIT**.


