#!/bin/bash
# =============================================================================
# run_openmp_benchmark.sh
# 10 iteraciones de la versión OpenMP por cada tamaño de matriz
# Tamaños: 400 600 800 1600 3000 3200
# Hilos: nproc (máximo disponible)
# =============================================================================

set -euo pipefail

SIZES=(400 600 800 1600 3000 3200)
RUNS=10
MAX_HILOS=$(nproc)
CSV="resultados_openmp_benchmark.csv"
TXT="resultados_openmp_benchmark.txt"

BOLD="\e[1m"; RESET="\e[0m"; GREEN="\e[32m"; CYAN="\e[36m"

echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
echo -e "${BOLD}${CYAN}  Benchmark OpenMP — Multiplicación de matrices${RESET}"
echo -e "${BOLD}${CYAN}  Hilos: $MAX_HILOS | Runs por tamaño: $RUNS${RESET}"
echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
echo ""

# ── Compilar ──────────────────────────────────────────────────────────────────
echo -e "${GREEN}[INFO]${RESET} Compilando matrizhilos.c con -O3 -fopenmp..."
gcc -O3 -march=native -funroll-loops -fopenmp matrizhilos.c -o bin_openmp \
    || { echo "Error compilando matrizhilos.c"; exit 1; }
echo -e "${GREEN}[INFO]${RESET} Compilación exitosa."
echo ""

# ── Inicializar archivos de salida ────────────────────────────────────────────
echo "n;hilos;run;tiempo_seq_seg;tiempo_par_seg;speedup;eficiencia" > "$CSV"
> "$TXT"

# ── Bucle principal ───────────────────────────────────────────────────────────
for n in "${SIZES[@]}"; do

    echo -e "${BOLD}── Tamaño n = $n ──${RESET}" | tee -a "$TXT"

    sum_tpar=0
    sum_tseq=0
    sum_speedup=0
    sum_eficiencia=0

    for run in $(seq 1 $RUNS); do
        result=$(printf "%d\n%d\n" "$n" "$MAX_HILOS" | ./bin_openmp 2>&1)

        t_par=$(echo "$result"  | grep -oP '(?<=Tiempo paralelo: )[0-9.]+')
        speedup=$(echo "$result" | grep -oP '(?<=Speedup: )[0-9.]+')
        efic=$(echo "$result"   | grep -oP '(?<=Eficiencia: )[0-9.]+')

        # Calcular t_seq desde speedup y t_par
        t_seq=$(awk "BEGIN { printf \"%.6f\", ${t_par:-0} * ${speedup:-1} }")

        sum_tpar=$(awk      "BEGIN { print $sum_tpar      + ${t_par:-0} }")
        sum_tseq=$(awk      "BEGIN { print $sum_tseq      + ${t_seq:-0} }")
        sum_speedup=$(awk   "BEGIN { print $sum_speedup   + ${speedup:-0} }")
        sum_eficiencia=$(awk "BEGIN { print $sum_eficiencia + ${efic:-0} }")

        line="  run $run → T_seq=${t_seq}s  T_par=${t_par}s  Speedup=${speedup}  Eficiencia=${efic}"
        echo "$line" | tee -a "$TXT"

        echo "$n;$MAX_HILOS;$run;$t_seq;$t_par;$speedup;$efic" >> "$CSV"
    done

    # Promedios
    avg_tpar=$(awk      "BEGIN { printf \"%.6f\", $sum_tpar      / $RUNS }")
    avg_tseq=$(awk      "BEGIN { printf \"%.6f\", $sum_tseq      / $RUNS }")
    avg_speedup=$(awk   "BEGIN { printf \"%.6f\", $sum_speedup   / $RUNS }")
    avg_efic=$(awk      "BEGIN { printf \"%.6f\", $sum_eficiencia / $RUNS }")

    summary="  PROMEDIO → T_seq=${avg_tseq}s  T_par=${avg_tpar}s  Speedup=${avg_speedup}  Eficiencia=${avg_efic}"
    echo "$summary" | tee -a "$TXT"

    # Fila de promedio en CSV
    echo "$n;$MAX_HILOS;PROMEDIO;$avg_tseq;$avg_tpar;$avg_speedup;$avg_efic" >> "$CSV"
    echo "" | tee -a "$TXT"

done

echo -e "${BOLD}${GREEN}══════════════════════════════════════════${RESET}"
echo -e "${GREEN}Pruebas finalizadas.${RESET}"
echo -e "  → $CSV"
echo -e "  → $TXT"
echo -e "${BOLD}${GREEN}══════════════════════════════════════════${RESET}"
