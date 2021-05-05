import
    macros

type
    Register8* = enum
        regAl
        regCl
        regDl
        regBl
        regSpl
        regBpl
        regSil
        regDil
        regR8b
        reg98b
        regR10b
        regR11b
        regR12b
        regR13b
        regR14b
        regR15b

    Register16* = enum
        regAx
        regCx
        regDx
        regBx
        regSp
        regBp
        regSi
        regDi
        regR8w
        regR9w
        regR10w
        regR11w
        regR12w
        regR14w
        regR15w

    Register32* = enum
        regEax
        regEcx
        regEdx
        regEbx
        regEsp
        regEbp
        regEsi
        regEdi
        regR8d
        regR9d
        regR10d
        regR11d
        regR12d
        regR13d
        regR14d
        regR15d

    Register64* = enum
        regRax
        regRcx
        regRdx
        regRbx
        regRsp
        regRbp
        regRsi
        regRdi
        regR8
        regR9
        regR10
        regR11
        regR12
        regR13
        regR14
        regR15

    Condition* = enum
        condOverflow
        condNotOverflow
        condBelow
        condNotBelow
        condZero
        condNotZero
        condBequal
        condNbequal
        condSign
        condNotSign
        condParityEven
        condParityOdd
        condLess
        condNotLess
        condLequal
        condNotLequal

    RmScale* = enum
        rmScale1
        rmScale2
        rmScale4
        rmScale8

    RmKind = enum
        rmDirect
        rmIndirectScaled
        rmIndirectScaledAndBase
        rmIndirectGlobal

    Rm*[T] = object
        case kind: RmKind
        of rmDirect:
            directReg: T
        of rmIndirectScaled:
            simpleIndex: Register64
            simpleScale: RmScale
            simpleDisp: int32
        of rmIndirectScaledAndBase:
            base, baseIndex: Register64
            baseScale: RmScale
            baseDisp: int32
        of rmIndirectGlobal:
            globalPtr: pointer

    Rm8 = Rm[Register8]
    Rm16 = Rm[Register16]
    Rm32 = Rm[Register32]
    Rm64 = Rm[Register64]

    BackwardsLabel = distinct int
    ForwardsLabel = object
        isLongJmp: bool
        offset: int32

    AssemblerX64* = object
        data*: ptr UncheckedArray[byte]
        offset*: int

proc curAdr(assembler: AssemblerX64): int64 =
    cast[int64](assembler.data) + assembler.offset

proc initAssemblerX64*(data: ptr UncheckedArray[byte]): AssemblerX64 =
    result.data = data

proc getFuncStart*[T](assembler: AssemblerX64): T =
    cast[T](assembler.curAdr)

proc label*(assembler: AssemblerX64): BackwardsLabel =
    BackwardsLabel(assembler.offset)

proc fitsInt8(imm: int32): bool =
    int32(cast[int8](imm)) == imm

proc label*(assembler: AssemblerX64, label: ForwardsLabel) =
    let offset = int32(assembler.offset) - label.offset
    if label.isLongJmp:
        copyMem(addr assembler.data[label.offset - 4], unsafeAddr offset, 4)
    else:
        assert offset.fitsInt8()
        copyMem(addr assembler.data[label.offset - 1], unsafeAddr offset, 1)

proc reg*[T](reg: T): Rm[T] =
    Rm[T](kind: rmDirect, directReg: reg)

template declareMemCtors(size: untyped): untyped =
    proc `mem size`*(index: Register64, disp = 0'i32, scale = rmScale1): `Rm size` =
        `Rm size`(kind: rmIndirectScaled, simpleIndex: index, simpleScale: scale, simpleDisp: disp)
    proc `mem size`*(base, index: Register64, disp = 0'i32, scale = rmScale1): `Rm size` =
        `Rm size`(kind: rmIndirectScaledAndBase, base: base, baseIndex: index, baseScale: scale, baseDisp: disp)
    proc `mem size`*[T](data: ptr T): `Rm size` =
        `Rm size`(kind: rmIndirectGlobal, globalPtr: data)

declareMemCtors(8)
declareMemCtors(16)
declareMemCtors(32)
declareMemCtors(64)

proc isDirectReg[T](rm: Rm[T], reg: T): bool =
    rm.kind == rmDirect and rm.directReg == reg

proc write[T](assembler: var AssemblerX64, data: T) =
    copyMem(addr assembler.data[assembler.offset], unsafeAddr data, sizeof(T))
    assembler.offset += sizeof(T)

proc writeField(assembler: var AssemblerX64, top, middle, bottom: byte) =
    assembler.write ((top and 0x3'u8) shl 6) or ((middle and 0x7'u8) shl 3) or (bottom and 0x7'u8)

proc writeRex(assembler: var AssemblerX64, w, r, x, b: bool) =
    assembler.write 0x40'u8 or (uint8(w) shl 3) or (uint8(r) shl 2) or (uint8(x) shl 1) or uint8(b)

proc needsRex8[T](reg: T): bool =
    when T is Register8:
        reg in {regSpl, regBpl, regSil, regDil}
    else:
        false

proc writeRex[T, U](assembler: var AssemblerX64, rm: Rm[T], reg: U, is64Bit: bool) =
    let precond = is64Bit or ord(reg) >= 8 or reg.needsRex8()

    case rm.kind
    of rmDirect:
        if precond or ord(rm.directReg) >= 8 or rm.directReg.needsRex8():
            assembler.writeRex is64Bit, ord(reg) >= 8, false, ord(rm.directReg) >= 8
    of rmIndirectScaled:
        if precond or ord(rm.simpleIndex) >= 8 or rm.simpleIndex.needsRex8():
            if rm.simpleScale == rmScale1:
                assembler.writeRex is64Bit, ord(reg) >= 8, false, ord(rm.simpleIndex) >= 8
            else:
                assembler.writeRex is64Bit, ord(reg) >= 8, ord(rm.simpleIndex) >= 8, false
    of rmIndirectScaledAndBase:
        if precond or ord(rm.base) >= 8 or ord(rm.baseIndex) >= 8:
            assembler.writeRex is64Bit, ord(reg) >= 8, ord(rm.baseIndex) >= 8, ord(rm.base) >= 8
    of rmIndirectGlobal:
        if precond:
            assembler.writeRex is64Bit, ord(reg) >= 8, false, false

proc writeModrm[T, U](assembler: var AssemblerX64, rm: Rm[T], reg: U): int =
    case rm.kind
    of rmDirect:
        assembler.writeField 0b11, byte(reg), byte(rm.directReg)
        -1
    of rmIndirectScaled:
        if rm.simpleScale == rmScale1:
            if rm.simpleIndex != regRsp and rm.simpleIndex != regR12:
                # most simple form
                # no SIB byte necessary
                if rm.simpleDisp == 0 and rm.simpleIndex != regRbp and rm.simpleIndex != regR13:
                    assembler.writeField 0b00, byte(reg), byte(rm.simpleIndex)
                elif rm.simpleDisp.fitsInt8():
                    assembler.writeField 0b01, byte(reg), byte(rm.simpleIndex)
                    assembler.write cast[int8](rm.simpleDisp)
                else:
                    assembler.writeField 0b10, byte(reg), byte(rm.simpleIndex)
                    assembler.write rm.simpleDisp
            else:
                if rm.simpleDisp == 0:
                    assembler.writeField 0b00, byte(reg), 0b100
                    assembler.writeField 0b00, 0b100, byte(rm.simpleIndex)
                elif rm.simpleDisp.fitsInt8():
                    assembler.writeField 0b01, byte(reg), 0b100
                    assembler.writeField 0b00, 0b100, byte(rm.simpleIndex)
                    assembler.write cast[int8](rm.simpleDisp)
                else:
                    assembler.writeField 0b10, byte(reg), 0b100
                    assembler.writeField 0b00, 0b100, byte(rm.simpleIndex)
                    assembler.write rm.simpleDisp
        else:
            assert rm.simpleIndex != regRsp, "rsp cannot be scaled"
            assembler.writeField 0b00, byte(reg), 0b100
            assembler.writeField byte(rm.simpleScale), byte(rm.simpleIndex), 0b101
            assembler.write rm.simpleDisp
        -1
    of rmIndirectScaledAndBase:
        assert rm.baseIndex != regRsp, "rsp cannot be scaled"
        if rm.baseDisp == 0 and rm.base != regRbp and rm.base != regR13:
            assembler.writeField 0b00, byte(reg), 0b100
            assembler.writeField byte(rm.baseScale), byte(rm.baseIndex), byte(rm.base)
        elif rm.baseDisp.fitsInt8():
            assembler.writeField 0b01, byte(reg), 0b100
            assembler.writeField byte(rm.baseScale), byte(rm.baseIndex), byte(rm.base)
            assembler.write cast[int8](rm.baseDisp)
        else:
            assembler.writeField 0b10, byte(reg), 0b100
            assembler.writeField byte(rm.baseScale), byte(rm.baseIndex), byte(rm.base)
            assembler.write rm.baseDisp
        -1
    of rmIndirectGlobal:
        assembler.writeField 0b00, byte(reg), 0b101
        let offset = assembler.offset
        assembler.write 0'i32
        offset

proc fixupRip[T](assembler: var AssemblerX64, modrm: Rm[T], location: int) =
    if location != -1:
        let offset = int32(cast[int64](modrm.globalPtr) - assembler.curAdr)
        copyMem(addr assembler.data[location], unsafeAddr offset, 4)

proc genEmit(desc, assembler: NimNode): NimNode =
    if desc.kind notin {nnkTupleConstr, nnkPar}:
        return desc

    result = newStmtList()

    var fixupRipOffset = nskLet.genSym("fixupRipOffset")

    # first pass find modrms

    var
        hasModrm = false
        modrmReg, modrmRm: NimNode

    for child in desc:
        if child.kind == nnkCall and $child[0] == "modrm":
            child.expectLen 3
            hasModrm = true
            modrmRm = child[1]
            modrmReg = child[2]
            break

    for child in desc:
        child.expectKind {nnkIntLit, nnkInfix, nnkIdent, nnkCall}
        if child.kind == nnkIntLit or child.kind == nnkInfix:
            result.add(quote do:
                write(`assembler`, cast[uint8](`child`)))
        elif child.kind == nnkIdent:
            case $child
            of "op16":
                result.add(quote do:
                    write(`assembler`, 0x66'u8))
            of "rex":
                if not hasModrm:
                    error("rex without modrm", child)
                result.add(quote do:
                    writeRex(`assembler`, `modrmRm`, `modrmReg`, false))
            of "op64":
                if hasModrm:
                    result.add(quote do:
                        writeRex(`assembler`, `modrmRm`, `modrmReg`, true))
                else:
                    result.add(quote do:
                        writeRex(`assembler`, true, false, false, false))
            of "imm":
                let imm = ident"imm"
                result.add(quote do:
                    write(`assembler`, `imm`))
            of "imm8":
                let imm = ident"imm"
                result.add(quote do:
                    write(`assembler`, cast[int8](`imm`)))
            else: error("unknown param", child)
        elif child.kind == nnkCall:
            case $child[0]
            of "modrm":
                result.add(quote do:
                    let `fixupRipOffset` = writeModrm(`assembler`, `modrmRm`, `modrmReg`))
            of "rex":
                let base = child[1]
                if hasModrm:
                    error("modrm with explicit param?", child)
                result.add(quote do:
                    if `base`:
                        writeRex(`assembler`, false, false, false, true))
            of "op64":
                if hasModrm:
                    error("modrm with explicit param?", child)
                let base = child[1]
                result.add(quote do:
                    writeRex(`assembler`, true, false, false, `base`))
            else:
                error("unknown param", child)

    if hasModrm:
        result.add(quote do:
            `assembler`.fixupRip(`modrmRm`, `fixupRipOffset`))

macro genAssembler(name, instr: untyped): untyped =
    result = newStmtList()

    for variant in instr:
        variant.expectKind nnkCall

        let
            params = variant[0]
            emit = block:
                variant[1].expectKind nnkStmtList
                variant[1].expectLen 1
                variant[1]

            finalProc = nnkProcDef.newTree(nnkPostfix.newTree(ident"*", name), 
                newEmptyNode(),
                newEmptyNode(),
                nnkFormalParams.newTree(newEmptyNode()),
                newEmptyNode(),
                newEmptyNode(),
                nil)

            assembler = nskParam.genSym("assembler")
        result.add finalProc

        params.expectKind {nnkTupleConstr, nnkPar}

        finalProc[3].add(newIdentDefs(assembler, nnkVarTy.newTree(bindSym"AssemblerX64")))

        for param in params:
            case $param
            of "reg8":
                finalProc[3].add(newIdentDefs(ident"reg", bindSym"Register8"))
            of "reg16":
                finalProc[3].add(newIdentDefs(ident"reg", bindSym"Register16"))
            of "reg32":
                finalProc[3].add(newIdentDefs(ident"reg", bindSym"Register32"))
            of "reg64":
                finalProc[3].add(newIdentDefs(ident"reg", bindSym"Register64"))
            of "rm8":
                finalProc[3].add(newIdentDefs(ident"rm", bindSym"Rm8"))
            of "rm16":
                finalProc[3].add(newIdentDefs(ident"rm", bindSym"Rm16"))
            of "rm32":
                finalProc[3].add(newIdentDefs(ident"rm", bindSym"Rm32"))
            of "rm64":
                finalProc[3].add(newIdentDefs(ident"rm", bindSym"Rm64"))
            of "imm8":
                finalProc[3].add(newIdentDefs(ident"imm", bindSym"int8"))
            of "imm16":
                finalProc[3].add(newIdentDefs(ident"imm", bindSym"int16"))
            of "imm32":
                finalProc[3].add(newIdentDefs(ident"imm", bindSym"int32"))
            of "imm64":
                finalProc[3].add(newIdentDefs(ident"imm", bindSym"int64"))
            of "cond":
                finalProc[3].add(newIdentDefs(ident"cond", bindSym"Condition"))
            else:
                error("invalid param", param)

        if emit.len == 1 and emit[0].kind == nnkIfStmt:
            for branch in emit[0]:
                branch[^1][^1] = genEmit(branch[^1][^1], assembler)
        else:
            emit[^1] = genEmit(emit[^1], assembler)

        finalProc[^1] = emit

template normalOp(name, opRmLeft8, opRmLeft, opRmRight8, opRmRight, opAl, opAx, opImm): untyped {.dirty.} =
    genAssembler name:
        # rm to the left
        (rm8, reg8): (rex, opRmLeft8, modrm(rm, reg))
        (rm16, reg16): (op16, rex, opRmLeft, modrm(rm, reg))
        (rm32, reg32): (rex, opRmLeft, modrm(rm, reg))
        (rm64, reg64): (op64, opRmLeft, modrm(rm, reg))

        # rm to the right
        (reg8, rm8): (rex, opRmRight8, modrm(rm, reg))
        (reg16, rm16): (op16, rex, opRmRight, modrm(rm, reg))
        (reg32, rm32): (rex, opRmRight, modrm(rm, reg))
        (reg64, rm64): (op64, opRmRight, modrm(rm, reg))

        # immediate forms
        (rm8, imm8):
            if rm.isDirectReg regAl:
                (opAl, imm)
            else:
                (rex, 0x80, modrm(rm, opImm))
        (rm16, imm16):
            # for 16-bit both the specialised ax variant and the 8-bit imm variant
            # produce a four byte sequence, so we prioritise the ax variant as it can hold a
            # larger imm
            if rm.isDirectReg regAx:
                (op16, opAx, imm)
            elif imm.fitsInt8():
                (op16, rex, 0x83, modrm(rm, opImm), imm8)
            else:
                (op16, rex, 0x81, modrm(rm, opImm), imm)
        (rm32, imm32):
            # for 32-bit the 8-bit variant (3 bytes) will always be shorter than the ax variant (5 bytes)
            # if the immediate fits
            if imm.fitsInt8():
                (rex, 0x83, modrm(rm, opImm), imm8)
            elif rm.isDirectReg regEax:
                (opAx, imm)
            else:
                (rex, 0x81, modrm(rm, opImm), imm)
        (rm64, imm32):
            if imm.fitsInt8():
                (op64, 0x83, modrm(rm, opImm), imm8)
            elif rm.isDirectReg regRax:
                (op64, opAx, imm)
            else:
                (op64, 0x81, modrm(rm, opImm), imm)

normalOp(add, opRmLeft8 = 0x00, opRmLeft = 0x01, opRmRight8 = 0x2, opRmRight = 0x03, opAl = 0x04, opAx = 0x05, opImm = 0x0)
normalOp(adc, opRmLeft8 = 0x10, opRmLeft = 0x11, opRmRight8 = 0x12, opRmRight = 0x13, opAl = 0x14, opAx = 0x15, opImm = 0x2)
normalOp(sub, opRmLeft8 = 0x28, opRmLeft = 0x29, opRmRight8 = 0x2A, opRmRight = 0x2B, opAl = 0x2C, opAx = 0x2D, opImm = 0x5)
normalOp(sbb, opRmLeft8 = 0x18, opRmLeft = 0x19, opRmRight8 = 0x1A, opRmRight = 0x1B, opAl = 0x1C, opAx = 0x1D, opImm = 0x3)
normalOp(aand, opRmLeft8 = 0x20, opRmLeft = 0x21, opRmRight8 = 0x22, opRmRight = 0x23, opAl = 0x24, opAx = 0x25, opImm = 0x4)
normalOp(oor, opRmLeft8 = 0x08, opRmLeft = 0x09, opRmRight8 = 0x0A, opRmRight = 0x0B, opAl = 0x0C, opAx = 0x0D, opImm = 0x1)
normalOp(xxor, opRmLeft8 = 0x30, opRmLeft = 0x31, opRmRight8 = 0x32, opRmRight = 0x33, opAl = 0x34, opAx = 0x35, opImm = 0x6)
normalOp(cmp, opRmLeft8 = 0x38, opRmLeft = 0x39, opRmRight8 = 0x3A, opRmRight = 0x3B, opAl = 0x3C, opAx = 0x3D, opImm = 0x7)

genAssembler mov:
    (rm8, reg8): (rex, 0x88, modrm(rm, reg))
    (rm16, reg16): (op16, rex, 0x89, modrm(rm, reg))
    (rm32, reg32): (rex, 0x89, modrm(rm, reg))
    (rm64, reg64): (op64, 0x89, modrm(rm, reg))

    (reg8, rm8): (rex, 0x8A, modrm(rm, reg))
    (reg16, rm16): (op16, rex, 0x8B, modrm(rm, reg))
    (reg32, rm32): (rex, 0x8B, modrm(rm, reg))
    (reg64, rm64): (op64, 0x8B, modrm(rm, reg))

    (rm8, imm8):
        if rm.kind == rmDirect:
            (rex(ord(rm.directReg) >= 8), 0xB0 + (ord(rm.directReg) and 0x7), imm)
        else:
            (rex, 0xC6, modrm(rm, 0), imm)
    (rm16, imm16):
        if rm.kind == rmDirect:
            (op16, rex(ord(rm.directReg) >= 8), 0xB8 + (ord(rm.directReg) and 0x7), imm)
        else:
            (op16, rex, 0xC7, modrm(rm, 0), imm)
    (rm32, imm32):
        if rm.kind == rmDirect:
            (rex(ord(rm.directReg) >= 8), 0xB8 + (ord(rm.directReg) and 0x7), imm)
        else:
            (rex, 0xC7, modrm(rm, 0))
    (rm64, imm32):
        (op64, 0xC7, modrm(rm, 0), imm)
    (reg64, imm64):
        (op64(ord(reg) >= 8), 0xB8 + (ord(reg) and 0x7), imm)

template extendOp(name, from8, from16): untyped {.dirty.} =
    genAssembler name:
        (reg16, rm8): (op16, rex, 0x0F, from8, modrm(rm, reg))
        (reg32, rm8): (rex, 0x0F, from8, modrm(rm, reg))
        (reg64, rm8): (op64, 0x0F, from8, modrm(rm, reg))

        (reg32, rm16): (rex, 0x0F, from16, modrm(rm, reg))
        (reg64, rm16): (op64, 0x0F, from16, modrm(rm, reg))
extendOp(movzx, 0xB6, 0xB7)
extendOp(movsx, 0xBE, 0xBF)

template shiftOp(name, op): untyped {.dirty.} =
    genAssembler name:
        (rm8, imm8):
            if imm == 1:
                (rex, 0xD0, modrm(rm, op))
            else:
                (rex, 0xC0, modrm(rm, op), imm)
        (rm16, imm8):
            if imm == 1:
                (op16, rex, 0xD1, modrm(rm, op))
            else:
                (op16, rex, 0xC1, modrm(rm, op), imm)
        (rm32, imm8):
            if imm == 1:
                (rex, 0xD1, modrm(rm, op))
            else:
                (rex, 0xC1, modrm(rm, op), imm)
        (rm64, imm8):
            if imm == 1:
                (rex, 0xD1, modrm(rm, op))
            else:
                (op64, 0xC1, modrm(rm, op), imm)
shiftOp(rcl, 2)
shiftOp(rcr, 3)
shiftOp(sshr, 5)
shiftOp(sshl, 6)
shiftOp(asr, 7)

genAssembler test:
    (rm8, reg8): (rex, 0x84, modrm(rm, reg))
    (rm16, reg16): (op16, rex, 0x85, modrm(rm, reg))
    (rm32, reg32): (rex, 0x85, modrm(rm, reg))
    (rm64, reg64): (op64, 0x85, modrm(rm, reg))

    # immediate forms
    (rm8, imm8):
        if rm.isDirectReg regAl:
            (0xA8, imm)
        else:
            (rex, 0xF6, modrm(rm, 0))
    (rm16, imm16):
        if rm.isDirectReg regAx:
            (op16, 0xA9, imm)
        else:
            (op16, rex, 0xF7, modrm(rm, 0), imm)
    (rm32, imm32):
        if rm.isDirectReg regEax:
            (0xA9, imm)
        else:
            (rex, 0xF7, modrm(rm, 0), imm)
    (rm64, imm32):
        if rm.isDirectReg regRax:
            (op64, 0xA9, imm)
        else:
            (op64, 0xF7, modrm(rm, 0), imm)

template unop(name, op): untyped {.dirty.} =
    genAssembler name:
        (rm8): (rex, 0xF6, modrm(rm, op))
        (rm16): (op16, rex, 0xF7, modrm(rm, op))
        (rm32): (rex, 0xF7, modrm(rm, op))
        (rm64): (op64, 0xF7, modrm(rm, op))
unop(nnot, 2)
unop(neg, 3)

template pushPopOp(name, regBaseOp, modrmOp, regOp): untyped {.dirty.} =
    genAssembler name:
        (rm64):
            if rm.kind == rmDirect:
                (rex(ord(rm.directReg) >= 8), regBaseOp + (ord(rm.directReg) and 0x7))
            else:
                (rex, modrmOp, modrm(rm, regOp))
pushPopOp(push, 0x50, 0xFF, 6)
pushPopOp(pop, 0x58, 0x8F, 0)

genAssembler setcc:
    (rm8, cond): (rex, 0x0F, 0x90 + ord(cond), modrm(rm, 0))

genAssembler bswap:
    (reg32): (rex(ord(reg) >= 8), 0x0F, 0xC8 + (ord(reg) and 0x7))
    (reg64): (op64(ord(reg) >= 8), 0x0F, 0xC8 + (ord(reg) and 0x7))

genAssembler ret: (): (0xC3)

template bitcountOp(name, op) {.dirty.} =
    genAssembler name:
        (reg16, rm16): (op16, rex, 0x0F, op, modrm(rm, reg))
        (reg32, rm32): (rex, 0x0F, op, modrm(rm, reg))
        (reg64, rm64): (op64, 0x0F, op, modrm(rm, reg))

bitcountOp(bsf, 0xBC)
bitcountOp(bsr, 0xBD)

template bitToCarryOp(name, opRm, opImm) {.dirty.} =
    genAssembler name:
        (rm16, imm8): (op16, rex, 0x0F, 0xBA, modrm(rm, opImm), imm)
        (rm32, imm8): (rex, 0x0F, 0xBA, modrm(rm, opImm), imm)
        (rm64, imm8): (op64, 0x0F, 0xBA, modrm(rm, opImm), imm)

        (rm16, reg16): (op16, rex, 0x0F, opRm, modrm(rm, reg))
        (rm32, reg32): (rex, 0x0F, opRm, modrm(rm, reg))
        (rm64, reg64): (op64, 0x0F, opRm, modrm(rm, reg))

bitToCarryOp(bt, 0xA3, 4)
bitToCarryOp(bts, 0xAB, 5)
bitToCarryOp(btr, 0xB3, 6)
bitToCarryOp(btc, 0xBB, 7)

genAssembler cmc: (): (0xF5)
genAssembler clc: (): (0xF8)
genAssembler stc: (): (0xF9)

genAssembler imul:
    (rm8): (rex, 0xF6, modrm(rm, 5))
    (rm16): (op16, rex, 0xF7, modrm(rm, 5))
    (rm32): (rex, 0xF7, modrm(rm, 5))
    (rm64): (op64, 0xF7, modrm(rm, 5))

    (reg16, rm16): (op16, rex, 0x0F, 0xAF, modrm(rm, reg))
    (reg32, rm32): (rex, 0x0F, 0xAF, modrm(rm, reg))
    (reg64, rm64): (op64, 0x0F, 0xAF, modrm(rm, reg))

    (reg16, rm16, imm16):
        if imm.fitsInt8():
            (op16, rex, 0x6B, modrm(rm, reg), imm8)
        else:
            (op16, rex, 0x69, modrm(rm, reg), imm)
    (reg32, rm32, imm32):
        if imm.fitsInt8():
            (rex, 0x6B, modrm(rm, reg), imm8)
        else:
            (rex, 0x69, modrm(rm, reg), imm)
    (reg64, rm64, imm32):
        if imm.fitsInt8():
            (op64, 0x6B, modrm(rm, reg), imm8)
        else:
            (op64, 0x69, modrm(rm, reg), imm)

unop(mul, 4)
unop(ddiv, 6)
unop(idiv, 7)

genAssembler lea:
    (reg16, rm32): (0x67, op16, rex, 0x8D, modrm(rm, reg))
    (reg16, rm64): (op16, rex, 0x8D, modrm(rm, reg))
    (reg32, rm32): (0x67, rex, 0x8D, modrm(rm, reg))
    (reg32, rm64): (rex, 0x8D, modrm(rm, reg))
    (reg64, rm32): (0x67, op64, rex, 0x8D, modrm(rm, reg))
    (reg64, rm64): (op64, rex, 0x8D, modrm(rm, reg))

proc jmp*(assembler: var AssemblerX64, target: pointer) =
    let offset8 = int32(cast[int64](target) - (assembler.curAdr + 2))
    if offset8.fitsInt8():
        assembler.write 0xEB'u8
        assembler.write cast[int8](offset8)
    else:
        let offset = int32(cast[int64](target) - (assembler.curAdr + 5))
        assembler.write 0xE9'u8
        assembler.write offset

proc jmp*(assembler: var AssemblerX64, label: BackwardsLabel) =
    assembler.jmp(cast[pointer](cast[int](assembler.data) + int(label)))

proc jmp*(assembler: var AssemblerX64, longJmp: bool): ForwardsLabel =
    if longJmp:
        assembler.write 0xE9'u8
        assembler.write 0x00'i32
    else:
        assembler.write 0xEB'u8
        assembler.write 0x00'i8
    ForwardsLabel(isLongJmp: longJmp, offset: int32(assembler.offset))

genAssembler jmp:
    (rm64): (rex, 0xFF, modrm(rm, 2))

proc call*(assembler: var AssemblerX64, target: pointer) =
    let offset = int32(cast[int64](target) - (cast[int64](assembler.data) + assembler.offset + 5))
    assembler.write 0xE8'u8
    assembler.write offset

proc call*(assembler: var AssemblerX64, label: BackwardsLabel) =
    assembler.call(cast[pointer](cast[int](assembler.data) + int(label)))

proc call*(assembler: var AssemblerX64, longJmp: bool): ForwardsLabel =
    assembler.write 0xE8'u8
    assembler.write 0x00'i32
    ForwardsLabel(isLongJmp: longJmp, offset: int32(assembler.offset))

genAssembler call:
    (rm64): (rex, 0xFF, modrm(rm, 4))

proc jcc*(assembler: var AssemblerX64, cc: Condition, target: pointer) =
    let offset8 = int32(cast[int64](target) - (assembler.curAdr + 2))
    if offset8.fitsInt8():
        assembler.write 0x70'u8 + uint8(cc)
        assembler.write offset8
    else:
        let offset = int32(cast[int64](target) - (assembler.curAdr + 6))
        assembler.write 0x0F'u8
        assembler.write 0x80'u8 + uint8(cc)
        assembler.write offset

proc jcc*(assembler: var AssemblerX64, cc: Condition, label: BackwardsLabel) =
    assembler.jcc(cc, cast[pointer](cast[int](assembler.data) + int(label)))

proc jcc*(assembler: var AssemblerX64, cc: Condition, longJmp: bool): ForwardsLabel =
    if longJmp:
        assembler.write 0x0F'u8
        assembler.write 0x80'u8 + uint8(cc)
        assembler.write 0'i32
    else:
        assembler.write 0x70'u8 + uint8(cc)
        assembler.write 0'i8
    ForwardsLabel(isLongJmp: longJmp, offset: int32(assembler.offset))

proc nop*(assembler: var AssemblerX64, bytes = 1) =
    var remainingBytes = bytes
    while remainingBytes > 0:
        case remainingBytes
        of 1:
            assembler.write 0x90'u8
            break
        of 2:
            assembler.write 0x66'u8
            assembler.write 0x90'u8
            break
        of 3:
            assembler.write 0x0F'u8
            assembler.write 0x1F'u8
            assembler.write 0x00'u8
            break
        of 4:
            assembler.write 0x0F'u8
            assembler.write 0x1F'u8
            assembler.write 0x40'u8
            assembler.write 0x00'u8
            break
        of 5:
            assembler.write 0x0F'u8
            assembler.write 0x1F'u8
            assembler.write 0x44'u8
            assembler.write 0x00'u16
            break
        of 6:
            assembler.write 0x66'u8
            assembler.write 0x0F'u8
            assembler.write 0x1F'u8
            assembler.write 0x44'u8
            assembler.write 0x00'u16
            break
        of 7:
            assembler.write 0x0F'u8
            assembler.write 0x1F'u8
            assembler.write 0x80'u8
            assembler.write 0x00'u32
            break
        of 8:
            assembler.write 0x0F'u8
            assembler.write 0x1F'u8
            assembler.write 0x84'u8
            assembler.write 0x00'u8
            assembler.write 0x00'u32
            break
        else:
            assembler.write 0x66'u8
            assembler.write 0x0F'u8
            assembler.write 0x1F'u8
            assembler.write 0x84'u8
            assembler.write 0x00'u8 
            assembler.write 0x00'u32
            remainingBytes -= 9
