#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <sys/wait.h>
#include <unistd.h>

// Función para obtener tiempo en segundos
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1e9;
}

int main() {
    int n, num_procs;

    printf("Ingrese el tamaño de la matriz (n x n): ");
    scanf("%d", &n);

    printf("Ingrese el numero de procesos: ");
    scanf("%d", &num_procs);

    int total = n * n;

    // ─────────────────────────────────────────
    // Crear segmentos de memoria compartida
    // ─────────────────────────────────────────
    int shm_A = shmget(IPC_PRIVATE, total * sizeof(double), IPC_CREAT | 0666);
    int shm_B = shmget(IPC_PRIVATE, total * sizeof(double), IPC_CREAT | 0666);
    int shm_C = shmget(IPC_PRIVATE, total * sizeof(double), IPC_CREAT | 0666);

    if (shm_A < 0 || shm_B < 0 || shm_C < 0) {
        perror("shmget");
        return 1;
    }

    double *A = (double*) shmat(shm_A, NULL, 0);
    double *B = (double*) shmat(shm_B, NULL, 0);
    double *C = (double*) shmat(shm_C, NULL, 0);

    if (A == (void*)-1 || B == (void*)-1 || C == (void*)-1) {
        perror("shmat");
        return 1;
    }

    // Inicialización con números aleatorios entre 1 y 9
    srand(time(NULL));
    for (int i = 0; i < total; i++) {
        A[i] = (double)(rand() % 9 + 1);
        B[i] = (double)(rand() % 9 + 1);
        C[i] = 0.0;
    }

    // ─────────────────────────────────────────
    // SECUENCIAL
    // ─────────────────────────────────────────
    double start_seq = get_time();

    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            double sum = 0.0;
            for (int k = 0; k < n; k++)
                sum += A[i*n + k] * B[k*n + j];
            C[i*n + j] = sum;
        }
    }

    double time_seq = get_time() - start_seq;
    printf("Tiempo secuencial: %f segundos\n", time_seq);

    // Reiniciar C
    for (int i = 0; i < total; i++) C[i] = 0.0;

    // ─────────────────────────────────────────
    // PARALELO con fork()
    // Cada proceso calcula un bloque de filas
    // ─────────────────────────────────────────
    double start_par = get_time();

    for (int p = 0; p < num_procs; p++) {
        pid_t pid = fork();

        if (pid < 0) {
            perror("fork");
            return 1;
        }

        if (pid == 0) {
            // ── Proceso hijo ──
            // Calcular rango de filas que le corresponden
            int rows_per_proc = n / num_procs;
            int remainder     = n % num_procs;

            int row_start = p * rows_per_proc + (p < remainder ? p : remainder);
            int row_end   = row_start + rows_per_proc + (p < remainder ? 1 : 0);

            for (int i = row_start; i < row_end; i++) {
                for (int j = 0; j < n; j++) {
                    double sum = 0.0;
                    for (int k = 0; k < n; k++)
                        sum += A[i*n + k] * B[k*n + j];
                    C[i*n + j] = sum;
                }
            }

            // Desacoplar memoria compartida en el hijo y salir
            shmdt(A);
            shmdt(B);
            shmdt(C);
            exit(0);
        }
        // El proceso padre continúa el bucle y crea el siguiente hijo
    }

    // Padre espera a que todos los hijos terminen
    for (int p = 0; p < num_procs; p++)
        wait(NULL);

    double time_par = get_time() - start_par;

    double speedup    = time_seq / time_par;
    double efficiency = speedup / num_procs;

    printf("\nTiempo paralelo:  %f segundos\n", time_par);
    printf("Speedup:          %f\n", speedup);
    printf("Eficiencia:       %f\n", efficiency);

    // ─────────────────────────────────────────
    // Limpiar memoria compartida
    // ─────────────────────────────────────────
    shmdt(A); shmdt(B); shmdt(C);
    shmctl(shm_A, IPC_RMID, NULL);
    shmctl(shm_B, IPC_RMID, NULL);
    shmctl(shm_C, IPC_RMID, NULL);

    return 0;
}