#include <stdio.h>
#include <stdlib.h>
#include <time.h>

int main() {
    int n;
    if (scanf("%d", &n) != 1) {
        return 1;
    }

    int **A = (int **)malloc(n * sizeof(int *));
    int **B = (int **)malloc(n * sizeof(int *));
    int **C = (int **)malloc(n * sizeof(int *));

    for (int i = 0; i < n; i++) {
        A[i] = (int *)malloc(n * sizeof(int));
        B[i] = (int *)malloc(n * sizeof(int));
        C[i] = (int *)malloc(n * sizeof(int));
    }

    srand(time(NULL));

    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            A[i][j] = rand() % 10;
            B[i][j] = rand() % 10;
            C[i][j] = 0;
        }
    }

    struct timespec ts_inicio, ts_fin;
    clock_gettime(CLOCK_MONOTONIC, &ts_inicio);

    for (int i = 0; i < n; i++) {          // fijamos una fila de A
        for (int k = 0; k < n; k++) {      // recorremos los elementos de esa fila
            const int aik = A[i][k];
            for (int j = 0; j < n; j++) {  // actualizamos toda la fila i de C
                C[i][j] += aik * B[k][j];
            }
        }
    }

    clock_gettime(CLOCK_MONOTONIC, &ts_fin);

    double tiempo = (ts_fin.tv_sec - ts_inicio.tv_sec)
                  + (ts_fin.tv_nsec - ts_inicio.tv_nsec) / 1e9;

    printf("TIEMPO=%.6f\n", tiempo);

    for (int i = 0; i < n; i++) {
        free(A[i]);
        free(B[i]);
        free(C[i]);
    }
    free(A);
    free(B);
    free(C);

    return 0;
}
