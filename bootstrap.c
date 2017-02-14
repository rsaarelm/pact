/* Pact bootstrap VM interpreter */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>

typedef uint32_t cell;

static_assert(sizeof(cell) == sizeof(void*), "Only 32-bit binaries are supported.");

#define CELL(addr) *((cell*)((uint8_t*)&mem + addr))

/* The whole structure is one big blob of memory, and is interpreted as a
 * zero-indexed byte array by the VM code. The struct fields show the places of
 * variables or regions needed by the VM code.
 *
 * The order of the fields is important, end of stack and end of return stack
 * are determined by the address of the following field.
 */
struct {
    /* Next instruction pointer in VM memory, location is expected to contain
     * an address to a C function, will be moved to next_code. */
    cell nip;
    /* Stack pointer */
    cell sp;
    /* Return stack pointer */
    cell rsp;
    /* Pointer to latest word. */
    cell current_word;
    /* Current memory cursor position. */
    cell here;
    /* RAM memory (data stack goes to the top) */
    uint8_t ram[256 * 1024];
    /* Return stack */
    uint8_t ret[16 * 1024];
    /* Scratch buffer */
    uint8_t buffer[8 * 1024];
} mem;

#define STACK_TOP ((void*)&mem.ret - (void*)&mem)
#define RSP_TOP ((void*)&mem.buffer - (void*)&mem)

void init() {
    memset(&mem, 0, sizeof(mem));
    mem.sp = STACK_TOP;
    mem.rsp = RSP_TOP;
}

cell pop() {
    assert(mem.sp < STACK_TOP);
    cell ret = CELL(mem.sp);
    mem.sp += sizeof(cell);
    return ret;
}

void push(cell c) {
    mem.sp -= sizeof(cell);
    CELL(mem.sp) = c;
}

cell rsp_pop() {
    assert(mem.rsp < RSP_TOP);
    cell ret = CELL(mem.rsp);
    mem.rsp += sizeof(cell);
    return ret;
}

void rsp_push(cell c) {
    mem.rsp -= sizeof(cell);
    CELL(mem.rsp) = c;
}

/* Advance VM to next code word */
void next() {
    /*
    mem.next_code = // TODO
    mem.nip += sizeof(cell);
    */
}

/* Bytecode inner interpreter */
void docol() {
    // Store next instruction pointer on return stack.
    rsp_push(mem.nip);
    // TODO: Figure out the dereferencing thing here...
}

void align() {
    while (mem.here % sizeof(cell) != 0)
        mem.here++;
}

/* Add a definition for a native code word. */
void defcode(const char* name, void (*fn)()) {
    /* TODO: Maybe this won't be needed, just recognize the names of HW
     * instructions directly in the VM interpreter instead of having them in
     * the mem dictionary. So probably want to remove this. */
    align();
    
    CELL(mem.here) = mem.current_word;
    mem.current_word = mem.here;
    mem.here += sizeof(cell);

    /* Write the null-terminated name. */
    strcpy((void*)(&mem + mem.here), name);
    mem.here += strlen(name) + 1;

    /* Write the code address */
    align();
    CELL(mem.here) = (cell)fn;
    mem.here += sizeof(cell);
}

/* Pact-style instructions */
void fetch() {
    push(CELL(pop()));
}

void set() {
    cell addr = pop();
    CELL(addr) = pop();
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
