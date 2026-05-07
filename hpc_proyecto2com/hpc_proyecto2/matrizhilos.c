#include <stdio.h>
#include <stdlib.h>
#include <omp.h>
#include <time.h>

int main() {

    int n;
    int num_threads;

    printf("Ingrese el tamaño de la matriz (n x n): ");
    scanf("%d", &n);

    printf("Ingrese el numero de hilos: ");
    scanf("%d", &num_threads);

    omp_set_num_threads(num_threads);

    double *A = (double*) malloc(n * n * sizeof(double));
    double *B = (double*) malloc(n * n * sizeof(double));
    double *C = (double*) calloc(n * n, sizeof(double));

    if (!A || !B || !C) {
        printf("Error al asignar memoria\n");
        return 1;
    }

    // Inicialización con números aleatorios entre 1 y 9
    srand(time(NULL));
    for (int i = 0; i < n*n; i++) {
        A[i] = (double)(rand() % 9 + 1);
        B[i] = (double)(rand() % 9 + 1);
    }

    // =========================
    // SECUENCIAL — orden IKJ (cache-friendly)
    // A[i*n+k] fijo por iteración de k → B[k*n+j] acceso secuencial por fila
    // =========================
    double start_seq = omp_get_wtime();

    for (int i = 0; i < n; i++) {
        for (int k = 0; k < n; k++) {
            double aik = A[i*n + k];
            for (int j = 0; j < n; j++) {
                C[i*n + j] += aik * B[k*n + j];
            }
        }
    }

    double end_seq = omp_get_wtime();
    double time_seq = end_seq - start_seq;

    // Reiniciar C
    for (int i = 0; i < n*n; i++)
        C[i] = 0.0;

    // =========================
    // PARALELO — orden IKJ + OpenMP + tiling (bloques de BLOCK_SIZE)
    // Cada hilo trabaja sobre un bloque de filas; acceso a B por filas en cada bloque
    // =========================
    const int BLOCK = 64;   // bloque de 64 doubles = 512 bytes = 8 líneas de caché

    double start_par = omp_get_wtime();

    #pragma omp parallel for schedule(static)
    for (int ii = 0; ii < n; ii += BLOCK) {
        int i_end = ii + BLOCK < n ? ii + BLOCK : n;
        for (int kk = 0; kk < n; kk += BLOCK) {
            int k_end = kk + BLOCK < n ? kk + BLOCK : n;
            for (int jj = 0; jj < n; jj += BLOCK) {
                int j_end = jj + BLOCK < n ? jj + BLOCK : n;
                // Mini-multiplicación del bloque (ii:i_end, kk:k_end) x (kk:k_end, jj:j_end)
                for (int i = ii; i < i_end; i++) {
                    for (int k = kk; k < k_end; k++) {
                        double aik = A[i*n + k];
                        for (int j = jj; j < j_end; j++) {
                            C[i*n + j] += aik * B[k*n + j];
                        }
                    }
                }
            }
        }
    }

    double end_par = omp_get_wtime();
    double time_par = end_par - start_par;

    double speedup = time_seq / time_par;
    double efficiency = speedup / num_threads;

    printf("\nTiempo paralelo: %f segundos\n", time_par);
    printf("Speedup: %f\n", speedup);
    printf("Eficiencia: %f\n", efficiency);

    free(A);
    free(B);
    free(C);

    return 0;
}