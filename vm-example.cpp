// Copyright (C) Risto Saarelma 2013
// zlib License

#include "vm.hpp"
#include "util.hpp"
#include <cstdio>
#include <algorithm>

using namespace std;

class MyVM : public VM {
public:
  bool syscall(uint32_t code) {
    switch (code) {
    case 1:
      // emit.
      printf("%c", tos());
      dpop();
      return true;
    // Start of nonstandard syscalls.
    case 256:
      // Read a token from input, return literals as is and turn strings into hashes
      // ( -- hash/lit hash? t )
      return readToken();
    case 257:
      // DOT
      printf("%d\n", tos());
      dpop();
      return true;
    default:
      return false;
    }
  }

  bool readToken() {
    string input;
    // Eat whitespace.
    for (int c = getchar(); c >= 0; c = getchar()) {
      if (isspace(c))
        continue;
      input.push_back(c);
      break;
    }
    for (int c = getchar(); c >= 0 && !isspace(c); c = getchar())
      input.push_back(c);

    // EOF. Return failure code.
    if (input.empty())
      return false;

    uint32_t num = 0;
    if (isNumLiteral(input, &num)) {
      dpush(num);
      dpush(0);
    } else {
      dpush(wordHash(input));
      dpush(-1);
    }
    return true;
  }
};

void makeImage(MyVM& vm) {
  size_t start = vm.here();
  vm.word(lit(0)); // Room for jump

  size_t emit = vm.here();
  vm.word(VM::LIT);
  vm.word(1);
  vm.word(VM::SYSCALL);
  vm.word(VM::DROP);
  vm.word(VM::RETURN);

  size_t stringPos = vm.here();
  vm.str("Stringception\n");
  vm.align4();

  size_t putStr = vm.here();
  vm.word(VM::DUP);
  vm.word(VM::CFETCH);
  vm.word(VM::DUP);
  vm.word(VM::ZBRANCH | (vm.here() + 20)); // End of string.
  vm.word(emit);
  vm.word(VM::INCR);
  vm.word(VM::BRANCH | putStr); // recurse
  vm.word(VM::DROP);
  vm.word(VM::RETURN);

  // FNV32 prime 16777619
  // FNV32 offset basis 2166136261
  // fnv321a ( str -- hash )
  size_t fnv321a = vm.here();
  // Compose literal 0x1000193, the FNV32 prime
  vm.word(VM::LIT);
  vm.word(2166136261); // FNV32 offest basis.
  vm.word(VM::OVER);
  vm.word(VM::DUP);
  vm.word(VM::ZBRANCH | (vm.here() + 10 * 4));
  vm.word(VM::CFETCH);
  vm.word(VM::XOR);
  vm.word(VM::LIT);
  vm.word(16777619); // FNV32 prime
  vm.word(VM::MULTIPLY);
  // Increment pointer
  vm.word(VM::SWAP);
  vm.word(VM::INCR);
  vm.word(VM::SWAP);
  vm.word(VM::BRANCH | (vm.here() - 11 * 4));
  vm.word(VM::SWAP);
  vm.word(VM::DROP);
  vm.word(VM::RETURN);

  size_t stringHello = vm.here();
  vm.word(VM::LIT);
  vm.word(stringPos);
  vm.word(putStr);
  vm.word(VM::LIT);
  vm.word(256);
  vm.word(VM::SYSCALL);
  vm.word(VM::DROP);

  vm.word(VM::LIT);
  vm.word(257);
  vm.word(VM::SYSCALL);
  vm.word(VM::DROP);

  vm.word(VM::LIT);
  vm.word(257);
  vm.word(VM::SYSCALL);
  vm.word(VM::DROP);

  vm.word(VM::RETURN);

  vm.write32(start, VM::BRANCH | stringHello);
}

int main(int argc, char* argv[]) {
  MyVM vm;
  makeImage(vm);
  vm.run();
  vm.dump("image.bin");
  return 0;
}
