#!/bin/bash
# =============================================================================
# run_profile.sh — Perfilado y benchmark HPC
# Versiones: Base | Memoria | Compilador (-O3) | OpenMP
# =============================================================================

set -euo pipefail

# ─── Parámetros globales ──────────────────────────────────────────────────────
N_PERFIL=3000                          # tamaño de matriz para perfilado de CPU (gprof + perf)
N_PERFIL_RAM=4000                      # tamaño de matriz para perfilado de memoria RAM
N_BENCH=2000                           # tamaño de matriz para benchmark
RUNS=10                                # iteraciones del benchmark OpenMP
MAX_HILOS=$(nproc)                     # hilos disponibles en la máquina

# Archivos de salida
OUT_DIR="."
PERF_BASE="perfil_cpu_base.txt"
PERF_MEM="perfil_cpu_memoria.txt"
PERF_COMP="perfil_cpu_compilador.txt"
CSV_BENCH="resultados_benchmark.csv"
RAM_BASE="ram_base.txt"
RAM_MEM="ram_memoria.txt"
RAM_COMP="ram_compilador.txt"

# ─── Colores para la consola ─────────────────────────────────────────────────
BOLD="\e[1m"; RESET="\e[0m"; GREEN="\e[32m"; CYAN="\e[36m"; YELLOW="\e[33m"

banner() { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════${RESET}"; \
           echo -e "${BOLD}${CYAN}  $1${RESET}"; \
           echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"; }

info()  { echo -e "${GREEN}[INFO]${RESET} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET} $1"; }

# ─── Verificar dependencias ───────────────────────────────────────────────────
banner "Verificando dependencias"
for cmd in gcc perf gprof /usr/bin/time nproc; do
    if command -v "$cmd" &>/dev/null || [ -x "$cmd" ]; then
        info "$cmd encontrado."
    else
        warn "$cmd NO encontrado. Algunas métricas podrían omitirse."
    fi
done
info "Hilos disponibles (nproc): $MAX_HILOS"

# ─────────────────────────────────────────────────────────────────────────────
# 1. COMPILACIÓN DE VERSIONES
# ─────────────────────────────────────────────────────────────────────────────
banner "1/4  Compilando versiones"

# Base: sin optimización, con gprof
info "Compilando versión BASE (matrizsecuencial.c -pg)..."
gcc -O0 -pg -g matrizsecuencial.c -o bin_base \
    || { echo "Error compilando bin_base"; exit 1; }

# Memoria: matrizhilos.c (memoria contigua), con gprof, 1 hilo para gprof
info "Compilando versión MEMORIA (matrizhilos.c -pg, 1 hilo)..."
gcc -O0 -pg -g -fopenmp matrizhilos.c -o bin_memoria \
    || { echo "Error compilando bin_memoria"; exit 1; }

# Compilador: matrizsecuencial.c con -O3 y gprof
info "Compilando versión COMPILADOR (matrizsecuencial.c -O3 -pg)..."
gcc -O3 -march=native -funroll-loops -pg matrizsecuencial.c -o bin_compilador \
    || { echo "Error compilando bin_compilador"; exit 1; }

# OpenMP: matrizhilos.c con -fopenmp y -O3 (sin -pg, gprof no escala bien en paralelo)
info "Compilando versión OPENMP (matrizhilos.c -fopenmp -O3)..."
gcc -O3 -march=native -funroll-loops -fopenmp matrizhilos.c -o bin_openmp \
    || { echo "Error compilando bin_openmp"; exit 1; }

info "Compilaciones completadas."

# ─────────────────────────────────────────────────────────────────────────────
# 2. FASE DE PERFILADO (versiones secuenciales: Base, Memoria, Compilador)
# ─────────────────────────────────────────────────────────────────────────────
banner "2/4  Perfilado de CPU (N=$N_PERFIL) y RAM (N=$N_PERFIL_RAM)"

# Función: ejecuta gprof sobre un binario y guarda reporte
run_gprof() {
    local bin="$1"
    local label="$2"
    local out_file="$3"
    local stdin_data="$4"

    info "gprof → $label (N=$N_PERFIL)..."

    # Ejecutar para generar gmon.out
    printf "%s" "$stdin_data" | ./"$bin" > /dev/null 2>&1 || true

    # Generar reporte
    if [ -f gmon.out ]; then
        gprof "./$bin" gmon.out > "$out_file" 2>&1
        info "Reporte gprof guardado: $out_file"
        rm -f gmon.out
    else
        warn "gmon.out no generado para $label (puede ser WSL). Saltando gprof."
        echo "gmon.out no disponible en este entorno." > "$out_file"
    fi
}

# Función: perf stat + RAM para un binario
# $5 = stdin para perf stat (N=3000)
# $6 = stdin para RAM       (N=4000)
run_perf_ram() {
    local bin="$1"
    local label="$2"
    local perf_file="$3"
    local ram_file="$4"
    local stdin_cpu="$5"
    local stdin_ram="$6"

    info "perf stat (N=$N_PERFIL) → $label..."
    {
        echo "=== perf stat: $label (N=$N_PERFIL) ==="
        printf "%s" "$stdin_cpu" | \
            perf stat -e cycles,instructions,cache-misses,branch-misses \
            ./"$bin" 2>&1 || \
            echo "[perf no disponible o sin permisos]"
        echo ""
    } > "$perf_file"
    info "perf stat guardado: $perf_file"

    info "RAM máxima (N=$N_PERFIL_RAM) → $label..."
    {
        echo "=== Memoria RAM: $label (N=$N_PERFIL_RAM) ==="
        printf "%s" "$stdin_ram" | \
            /usr/bin/time -v ./"$bin" 2>&1 | grep -E \
            "Maximum resident|Elapsed|Major|Minor" || \
            echo "[/usr/bin/time -v no disponible]"
    } > "$ram_file"
    info "RAM guardada: $ram_file"
}

# ── Entradas stdin separadas por tamaño ──────────────────────────────────────
# CPU (N=3000): gprof + perf stat
STDIN_CPU_SEQ="$(printf "%d\n" $N_PERFIL)"
STDIN_CPU_HLS="$(printf "%d\n1\n" $N_PERFIL)"   # 1 hilo para gprof en bin_memoria

# RAM (N=4000): /usr/bin/time -v
STDIN_RAM_SEQ="$(printf "%d\n" $N_PERFIL_RAM)"
STDIN_RAM_HLS="$(printf "%d\n1\n" $N_PERFIL_RAM)"

# ── BASE ──────────────────────────────────────────────────────────────────────
run_gprof    "bin_base"      "BASE"        "$PERF_BASE"            "$STDIN_CPU_SEQ"
run_perf_ram "bin_base"      "BASE"        "perf_base.txt"         "$RAM_BASE"  "$STDIN_CPU_SEQ" "$STDIN_RAM_SEQ"

# ── MEMORIA ───────────────────────────────────────────────────────────────────
run_gprof    "bin_memoria"   "MEMORIA"     "$PERF_MEM"             "$STDIN_CPU_HLS"
run_perf_ram "bin_memoria"   "MEMORIA"     "perf_memoria.txt"      "$RAM_MEM"   "$STDIN_CPU_HLS" "$STDIN_RAM_HLS"

# ── COMPILADOR (-O3) ──────────────────────────────────────────────────────────
run_gprof    "bin_compilador" "COMPILADOR" "$PERF_COMP"            "$STDIN_CPU_SEQ"
run_perf_ram "bin_compilador" "COMPILADOR" "perf_compilador.txt"   "$RAM_COMP"  "$STDIN_CPU_SEQ" "$STDIN_RAM_SEQ"

# ─────────────────────────────────────────────────────────────────────────────
# 3. FASE DE BENCHMARK (OpenMP — 10 iteraciones)
# ─────────────────────────────────────────────────────────────────────────────
banner "3/4  Benchmark OpenMP (N=$N_BENCH | hilos=$MAX_HILOS | runs=$RUNS)"

echo "n;hilos;run;tiempo_paralelo_seg;speedup;eficiencia" > "$CSV_BENCH"

total_tiempo=0

for run in $(seq 1 $RUNS); do
    result=$(printf "%d\n%d\n" "$N_BENCH" "$MAX_HILOS" | ./bin_openmp 2>&1)

    tiempo=$(echo "$result" | grep -oP '(?<=Tiempo paralelo:\s{1,10})[0-9.]+' || \
             echo "$result" | grep -oP '(?<=Tiempo paralelo: )[0-9.]+')
    speedup=$(echo "$result"    | grep -oP '(?<=Speedup: )[0-9.]+')
    eficiencia=$(echo "$result" | grep -oP '(?<=Eficiencia: )[0-9.]+')

    # Acumular tiempo para el promedio
    total_tiempo=$(awk "BEGIN { print $total_tiempo + ${tiempo:-0} }")

    echo "$N_BENCH;$MAX_HILOS;$run;$tiempo;$speedup;$eficiencia" >> "$CSV_BENCH"
    echo "  run $run → T=${tiempo}s  Speedup=${speedup}  Eficiencia=${eficiencia}"
done

# Calcular promedio de tiempo
promedio=$(awk "BEGIN { printf \"%.6f\", $total_tiempo / $RUNS }")
echo "" >> "$CSV_BENCH"
echo "PROMEDIO;;;$promedio;;" >> "$CSV_BENCH"
info "Tiempo paralelo promedio ($RUNS runs): ${promedio}s"

# ─────────────────────────────────────────────────────────────────────────────
# 4. RESUMEN FINAL
# ─────────────────────────────────────────────────────────────────────────────
banner "4/4  Resumen de archivos generados"

echo -e "
${BOLD}PERFILADO DE CPU (gprof):${RESET}
  ├─ ${PERF_BASE}       ← Base (sin optimización)
  ├─ ${PERF_MEM}    ← Memoria contigua (matrizhilos)
  └─ ${PERF_COMP}  ← Compilador (-O3)

${BOLD}MÉTRICAS perf stat:${RESET}
  ├─ perf_base.txt
  ├─ perf_memoria.txt
  └─ perf_compilador.txt

${BOLD}MEMORIA RAM máxima:${RESET}
  ├─ ${RAM_BASE}
  ├─ ${RAM_MEM}
  └─ ${RAM_COMP}

${BOLD}BENCHMARK OpenMP (${RUNS} iteraciones, N=${N_BENCH}, hilos=${MAX_HILOS}):${RESET}
  └─ ${CSV_BENCH}
     Tiempo promedio: ${promedio} segundos
"
