
// Extracted from the git repository.
// CIL used to crash with "Error: Length of array is negative".

int main() {
    const int *a;
    int *ret;
    sizeof(*(ret)) + (sizeof(char [1 - 2*!(__builtin_types_compatible_p(__typeof__(*((ret))), __typeof__(*((a)))))]) - 1);
    return 0;
}