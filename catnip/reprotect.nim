type
    MemPerm* = enum
        memperm_R
        memperm_W
        memperm_X

when defined(windows):
    import winlean
    
    proc virtualProtect(lpAddress: pointer, dwSize: WinSizeT, flNewProtect: DWORD,
            lpflOldProtect: PDWORD): WINBOOL
        {.stdcall, dynlib: "kernel32", importc: "VirtualProtect", sideeffect.}
else:
    import posix

proc reprotectMemory*(adr: pointer, size: int, perms: set[MemPerm]): bool =
    when defined(windows):
        let perms =
            if perms == {memperm_R}: PAGE_READONLY
            elif perms == {memperm_R, memperm_W}: PAGE_READWRITE
            elif perms == {memperm_R, memperm_W, memperm_X}: PAGE_EXECUTE_READWRITE
            else: raiseAssert("unsupported protection")
        var oldProtect: DWORD
        int32(virtualProtect(adr, WinSizeT size, perms, addr oldProtect)) != 0
    else:
        var permsTranslated = PROT_NONE
        if memperm_R in perms:
            permsTranslated = permsTranslated or PROT_READ
        if memperm_W in perms:
            permsTranslated = permsTranslated or PROT_WRITE
        if memperm_X in perms:
            permsTranslated = permsTranslated or PROT_EXEC

        mprotect(adr, size, permsTranslated) == 0
