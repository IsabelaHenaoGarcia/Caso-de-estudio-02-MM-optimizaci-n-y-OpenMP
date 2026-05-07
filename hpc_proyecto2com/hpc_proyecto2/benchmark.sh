#!/bin/bash
# benchmark.sh  - Compila y ejecuta los tres programas para distintos k y T/P
# Uso: bash benchmark.sh

CC="gcc"
CFLAGS="-O2 -Wall"

echo "==========================================="
echo "  Compilando los tres programas..."
echo "==========================================="
$CC $CFLAGS -o jacobi_serial  jacobi_serial.c  -lm         && echo "  [OK] serial"
$CC $CFLAGS -o jacobi_threads jacobi_threads.c -lm -lpthread && echo "  [OK] threads"
$CC $CFLAGS -o jacobi_fork    jacobi_fork.c    -lm          && echo "  [OK] fork"
echo ""

# Tabla de resultados
printf "%-8s %-8s %-10s %-10s %-10s\n" "Versión" "k(nk)" "Tiempo(s)" "Iters" "Error_RMS"
printf "%-8s %-8s %-10s %-10s %-10s\n" "-------" "------" "---------" "-----" "---------"

for k in 5 7 9; do
    nk=$(( (1 << k) + 1 ))

    # Serial
    out=$(./jacobi_serial $k 2>&1)
    time_s=$(echo "$out" | awk -F':' '/Tiempo/{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' | awk '{print $1}')
    iter_s=$(echo "$out" | awk -F':' '/Iteraciones/{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
    err_s=$(echo  "$out" | awk -F':' '/Error RMS/{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
    printf "%-8s %-8s %-10s %-10s %-10s\n" "serial" "k=$k($nk)" "$time_s" "$iter_s" "$err_s"

    # Threads: 2 y 4 hilos
    for T in 2 4; do
        out=$(./jacobi_threads $k $T 2>&1)
        time_t=$(echo "$out" | awk -F':' '/Tiempo/{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' | awk '{print $1}')
        iter_t=$(echo "$out" | awk -F':' '/Iteraciones/{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
        err_t=$(echo  "$out" | awk -F':' '/Error RMS/{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
        printf "%-8s %-8s %-10s %-10s %-10s\n" "T=$T" "k=$k($nk)" "$time_t" "$iter_t" "$err_t"
    done

    # Fork: 2 y 4 procesos
    for P in 2 4; do
        out=$(./jacobi_fork $k $P 2>&1)
        time_f=$(echo "$out" | awk -F':' '/Tiempo/{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' | awk '{print $1}')
        iter_f=$(echo "$out" | awk -F':' '/Iteraciones/{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
        err_f=$(echo  "$out" | awk -F':' '/Error RMS/{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
        printf "%-8s %-8s %-10s %-10s %-10s\n" "P=$P" "k=$k($nk)" "$time_f" "$iter_f" "$err_f"
    done
    echo ""
done
