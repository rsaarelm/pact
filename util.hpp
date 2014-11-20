// Copyright (C) Risto Saarelma 2013
// zlib License

#ifndef _UTIL_HPP
#define _UTIL_HPP

#include "vm.hpp"

inline uint32_t wordHash(const std::string& token) {
  // 32-bit FNV-1a hash.
  uint32_t hash = 2166136261;
  for (const uint8_t c : token) {
    hash ^= c;
    hash *= 16777619;
  }
  return hash;
}

/// Return whether token parses into number literal. Write number value to
/// address "value" if it's non-null.
inline bool isNumLiteral(const std::string& token, uint32_t* value) {
    int base = 10;
    std::string literal;
    if (token[0] == '$') {
      // Hex literal. Insert the part after the $.
      literal.insert(0, token, 1, std::string::npos);
      base = 16;
    } else {
      literal = token;
    }

    try {
      size_t error = 0;
      uint32_t num = (uint32_t)stoi(literal, &error, base);
      if (error == literal.size()) {
        if (value)
          *value = num;
        return true;
      }
    } catch (...) {}
    return false;
}

#endif
