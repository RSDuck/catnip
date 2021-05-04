# Catnip

A nondescriptively named runtime assembler e.g. for JIT recompilers.

**Why not improve the assembler in [laser](https://github.com/numforge/laser)?**

I thought about doing this, but decided against it mainly for two reasons:

- it's only one small part from a pretty big package (both in terms of code size and absolute data size)
- registers are defined as compile time `static` parameters for some reasons? In any way it makes dynamic register allocation impossible (which is irreplacable for any decent JIT recompiler I can think of).

Though I can't deny that the declarative macro for defining the encodings wasn't inspired by it :D.

## Planned things

- Better tests
- Support more x64
- Support assembling aarch64