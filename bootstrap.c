/* Pact bootstrap VM interpreter */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>
#include <ctype.h>

typedef uint32_t cell;

static_assert(sizeof(cell) == sizeof(void*), "Only 32-bit binaries are supported.");

#define CELL(addr) *((cell*)((uint8_t*)&mem + addr))
#define POS(field) ((void*)&field - (void*)&mem)

/* The whole structure is one big blob of memory, and is interpreted as a
 * zero-indexed byte array by the VM code. The struct fields show the places of
 * variables or regions needed by the VM code.
 *
 * The order of the fields is important, end of stack and end of return stack
 * are determined by the address of the following field.
 */
struct {
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
    /* Next instruction pointer in VM memory, location is expected to contain
     * an address to a C function, will be moved to next_code. */
    cell nip;
    /* Stack pointer */
    cell sp;
    /* Return stack pointer */
    cell rsp;
} mem;

#define STACK_TOP POS(mem.ret)
#define RSP_TOP POS(mem.buffer)
#define BUFFER_TOP POS(mem.nip)
#define BUFFER_SIZE (POS(mem.nip) - POS(mem.buffer))

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

/* : word ( -- addr )
 * Read whitespace-separated token into scratch buffer as null-terminated string.
 */
void word() {
    int c = ' ';

    /* Eat whitespace */
    while (isspace(c))
        c = getc(stdin);

    char* input = (char*)&mem.buffer;
    for (size_t i = 0; i < BUFFER_SIZE - 1; i++) {
        *input++ = c;
        c = getc(stdin);
        if (isspace(c))
            break;
    }
    *input = 0;
    push(POS(mem.buffer));
}


int main(int argc, char* argv[]) {
    init();

    printf("Hello, world!\n");
    for (;;) {
        printf("? ");
        fflush(stdout);
        word();
        pop();
        printf("%s\n", mem.buffer);
    }
    return 0;
}
