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

#define CELLS(bytes) ((cell*)(bytes))

struct {
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
    cell ret = CELLS(vm.mem)[vm.sp / sizeof(cell)];
    vm.sp += sizeof(cell);
    return ret;
}

void push(cell c) {
    vm.sp -= sizeof(cell);
    CELLS(vm.mem)[vm.sp / sizeof(cell)] = c;
}

/* Add a definition for a native code word. */
void defcode(const char* name, void (*fn)()) {
    assert(vm.here % sizeof(cell) == 0);
    
    *((cell*)(vm.mem + vm.here)) = vm.current_word;
    vm.current_word = vm.here;
    vm.here += sizeof(cell);

}

/* Pact-style instructions */
void fetch() {
    cell addr = pop();
    push(*((cell*)(vm.mem + addr)));
}

void set() {
    cell x = pop();
    cell addr = pop();
    *((cell*)(vm.mem + addr)) = x;
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
