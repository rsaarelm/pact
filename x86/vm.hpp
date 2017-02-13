// Copyright (C) Risto Saarelma 2013
// zlib License

#ifndef _VM_HPP
#define _VM_HPP

#include <cstring>
#include <cassert>
#include <cstdint>
#include <cstdio>
#include <cassert>
#include <algorithm>

class VM {
public:
  enum {
    NOP = 0,
    LIT,
    STORE,
    CSTORE,
    FETCH,
    CFETCH,
    OR,
    AND,
    XOR,
    POP,
    PUSH,
    MULTIPLY,
    ADD,
    SUBTRACT,
    INVERT,
    DIVMOD,
    DROP,
    SWAP,
    DUP,
    OVER,
    DEPTH,
    PICK,
    DECR,
    INCR,
    SHL,
    SHR,
    RETURN,
    LESS,
    EQUALS,
    SYSCALL,
  };

  enum {
    CALL =    0x00000000,
    ZBRANCH = 0x10000000,
    BRANCH =  0x20000000,
  };

  static const int dataStackBits = 6;
  static const int returnStackBits = 8;

  VM() {
    memset(this, 0, sizeof(VM));
  }

  virtual ~VM() {}

  virtual bool syscall(uint32_t code) { return false; }

  void write8(size_t addr, uint8_t val) {
    assert(addr >= 256);
    mem[addr - 256] = val;
  }

  uint8_t read8(size_t addr) {
    assert(addr >= 256);
    return mem[addr - 256];
  }

  void write32(size_t addr, uint32_t val) {
    assert(addr >= 256);
    addr -= 256;
    mem[addr++] = val >> 24;
    mem[addr++] = val >> 16;
    mem[addr++] = val >> 8;
    mem[addr] = val;
  }

  uint32_t read32(size_t addr) {
    assert(addr >= 256);
    addr -= 256;
    uint32_t result = 0;
    result |= mem[addr++] << 24;
    result |= mem[addr++] << 16;
    result |= mem[addr++] << 8;
    result |= mem[addr];
    return result;
  }

  void byte(uint8_t val) {
    write8(here(), val);
    here_++;
    largest = std::max(here_, largest);
  }

  void word(uint32_t word32) {
    write32(here(), word32);
    here_ += 4;
    largest = std::max(here_, largest);
  }

  void dump(const char* filename) {
    FILE* f = fopen(filename, "wb");
    fwrite(mem, largest, 1, f);
    fclose(f);
  }

  void align4() {
    here_ = (here_ + 3) & (~3);
  }

  void read(const char* filename) {
    memset(mem, sizeof(mem), 0);
    FILE* f = fopen(filename, "rb");
    if (!f) {
      return;
    }
    largest = fread(mem, sizeof(mem), 1, f);
    here_ = largest + 1;
  }

  void str(const char* s) {
    while(*s) byte(*s++);
    byte(0);
  }


  /// Push to data stack.
  void dpush(uint32_t val) {
    ds[dsp] = val;
    dsp = wrapDsp(dsp + 1);
  }

  void dpop() { dsp = wrapDsp(dsp - 1); }

  void rpop() { rsp = wrapRsp(rsp - 1); }

  size_t here() const { return here_ + 256; }

  void here(size_t addr) {
    assert(addr >= 256);
    here_ = addr - 256;
  }

  /// Push to return stack.
  void rpush(uint32_t val) {
    rs[rsp] = val;
    rsp = wrapRsp(rsp + 1);
  }

  /// Top of data stack.
  uint32_t& tos() { return ds[wrapDsp(dsp - 1)]; }

  /// Next in data stack.
  uint32_t& nis() { return ds[wrapDsp(dsp - 2)]; }

  /// Top of return stack.
  uint32_t& tor() { return rs[wrapRsp(rsp - 1)]; }

  void run() {
    pc = 256;

    rpush(0);

    while (rsp != 0) {
      uint32_t w = read32(pc);
      uint32_t quot, rem;
      uint32_t code;
      pc += 4;

      switch(w) {
      case NOP:
        break;
      case LIT:
        dpush(read32(pc));
        pc += 4;
        break;
      case STORE:
        write32(tos(), nis());
        dsp = wrapDsp(dsp - 2);
        break;
      case CSTORE:
        write8(tos(), nis());
        dsp = wrapDsp(dsp - 2);
        break;
      case FETCH:
        tos() = read32(tos());
        break;
      case CFETCH:
        tos() = read8(tos());
        break;
      case OR:
        nis() = tos() | nis();
        dpop();
        break;
      case AND:
        nis() = tos() & nis();
        dpop();
        break;
      case XOR:
        nis() = tos() ^ nis();
        dpop();
        break;
      case POP:
        dpush(tor());
        rpop();
        break;
      case PUSH:
        rpush(tos());
        dpop();
        break;
      case MULTIPLY:
        nis() = tos() * nis();
        dpop();
        break;
      case ADD:
        nis() = tos() + nis();
        dpop();
        break;
      case SUBTRACT:
        nis() = nis() - tos();
        dpop();
        break;
      case INVERT:
        tos() = ~tos();
        break;
      case DIVMOD:
        rem = nis() % tos();
        quot = nis() / tos();
        nis() = rem;
        tos() = quot;
        break;
      case DROP:
        dpop();
        break;
      case SWAP:
        tos() = tos() ^ nis();
        nis() = tos() ^ nis();
        tos() = tos() ^ nis();
        break;
      case DUP:
        dpush(tos());
        break;
      case OVER:
        dpush(nis());
        break;
      case DEPTH:
        dpush(dsp);
        break;
      case PICK:
        tos() = ds[tos()];
        break;
      case DECR:
        tos()--;
        break;
      case INCR:
        tos()++;
        break;
      case SHL:
        nis() = nis() << tos();
        dpop();
        break;
      case SHR:
        nis() = nis() >> tos();
        dpop();
        break;
      case RETURN:
        pc = tor();
        rpop();
        break;
      case LESS:
        nis() = nis() < tos() ? -1 : 0;
        dpop();
        break;
      case EQUALS:
        nis() = nis() == tos() ? -1 : 0;
        dpop();
        break;
      case SYSCALL:
        code = tos();
        dpop();
        if (syscall(code)) {
          dpush(-1);
        } else {
          dpush(0);
        }
        break;
      default:
        // Branch op
        size_t addr = (w & 0x0FFFFFFF);
        switch (w & 0xF0000000) {
        case CALL:
          rpush(pc);
          pc = addr;
          break;
        case ZBRANCH:
          if (!tos())
            pc = addr;
          dpop();
          break;
        case BRANCH:
          pc = addr;
        }
      }
    }
  }

  size_t largest;

protected:
  size_t here_;

  int wrapDsp(int val) { return val & ((1 << dataStackBits) - 1); }

  int wrapRsp(int val) { return val & ((1 << returnStackBits) - 1); }

  size_t pc;

  int dsp;
  int rsp;

  uint32_t ds[1 << dataStackBits];
  uint32_t rs[1 << returnStackBits];

  uint8_t mem[1 << 21];
};

inline uint32_t lit(int val) {
  return 0x800000 | (val & 0x7fffff);
}

inline uint32_t call(int val) {
  return (val & 0x1fffff);
}

inline uint32_t branch(int val) {
  return 0x600000 | (val & 0x1fffff);
}

inline uint32_t zbranch(int val) {
  return 0x400000 | (val & 0x1fffff);
}

#endif
