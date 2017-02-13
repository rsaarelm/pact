/* Pact bootstrap VM interpreter */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>

#define RAM_SIZE (1 << 20)
#define RETURN_STACK_SIZE (1 << 14)
#define BUFFER_SIZE (1 << 12)

typedef uint32_t cell;

static_assert(sizeof(cell) == sizeof(void*), "Cell size must be machine word size");

#define CELL(a) ((cell*)(&a))

struct {
    /* Next codeword address in C memory */
    void (*next_code)();
    /* Next instruction pointer in VM memory, location is expected to contain
     * an address to a C function, will be moved to next_code. */
    size_t nip;
    /* Stack pointer */
    size_t sp;
    /* Pointer to latest word. */
    size_t current_word;
    /* Current memory cursor position. */
    size_t here;
    /* RAM memory (data stack goes to the top) */
    uint8_t mem[RAM_SIZE];
    /* Return stack */
    uint8_t ret[RETURN_STACK_SIZE];
    /* Scratch buffer */
    uint8_t buffer[BUFFER_SIZE];
} vm;

void init() {
    memset(&vm, 0, sizeof(vm));
    vm.sp = RAM_SIZE - 1;
}

cell pop() {
    assert(vm.sp <= RAM_SIZE - 1 - sizeof(cell));
    cell ret = *CELL(vm.mem[vm.sp]);
    vm.sp += sizeof(cell);
    return ret;
}

void push(cell c) {
    vm.sp -= sizeof(cell);
    *CELL(vm.mem[vm.sp]) = c;
}

/* Advance VM to next code word */
void next() {
    vm.nip += sizeof(cell);
    vm.next_code = (void*)*CELL(vm.mem[vm.nip]);
}

void align() {
    while (vm.here % sizeof(cell) != 0)
        vm.here++;
}

/* Add a definition for a native code word. */
void defcode(const char* name, void (*fn)()) {
    align();
    
    *((cell*)(vm.mem + vm.here)) = vm.current_word;
    vm.current_word = vm.here;
    vm.here += sizeof(cell);
}

/* Pact-style instructions */
void fetch() {
    push(*CELL(vm.mem[pop()]));
}

void set() {
    cell x = pop();
    *CELL(vm.mem[pop()]) = x;
}

void key() {
    push(getc(stdin));
}

void emit() {
    char c = pop();
    putc(c, stdout);
}



int main(int argc, char* argv[]) {
    init();

    printf("Hello, world!\n");
    return 0;
}
