"""Build the camera-jump fix for WoW 4.3.4.15595.

Port of the Turtle WoW / vanilla-tweaks "camera skip glitch fix" (by Bon):
instead of warping the cursor to the window centre on every mouselook move,
pin it to the spot where mouselook started (nudged 1px/event away from the
client-rect edges when within 50px). A stale cursor read after a warp then
equals the pin point, so it produces zero camera movement instead of a snap.

Only the recenter function at 0x874750 is rewritten; its base relocations are
repointed so the patch survives ASLR.

usage: build_patch.py <original Wow.exe> <output exe> [patchlist.txt]
"""
import sys, struct
import pefile
from keystone import Ks, KS_ARCH_X86, KS_MODE_32
from capstone import Cs, CS_ARCH_X86, CS_MODE_32

FUNC_VA = 0x874750
FUNC_END = 0x8747DD            # first int3 after the original "ret"
ORIGINAL_FUNC = bytes.fromhex(
    "558bec83ec10565 78d45f0506a00e8dd1d000083c40450ff15e055b8008b75f08b45f82bc6992bc28bc88b45fcd1f903ce8b75f42bc6992bc2"
    "d1f803c6a3486bec008bf0a1ec6cec00890d446bec008bf985c0752e68f470bd00ff150053b80085c07423680071bd0050ff150453b800a3ec6cec00"
    "85c0750aa1fc55b800a3ec6cec005657ffd05f5e8be55dc3".replace(" ", ""))

# globals / imports (image base 0x400000)
PIN_X = 0xEC6B44               # +0 pin x (physical screen), +4 pin y
                               # +8 saved hwnd, +0xC saved x (client), +0x10 saved y (client)
IAT_GetClientRect = 0xB8568C
IAT_ClientToScreen = 0xB85608
SET_CURSOR_LOGICAL = 0x8731A0  # esi=&POINT (screen, logical): LogicalToPhysicalPoint + SetPhysicalCursorPos
GET_CURSOR_PHYSICAL = 0x8730F0 # cdecl (POINT*): GetPhysicalCursorPos

ASM = f"""
    push ebp
    mov ebp, esp
    sub esp, 0x18
    push esi
    push edi
    mov edi, {PIN_X:#x}
    lea eax, [ebp-0x10]
    push eax
    push dword ptr [edi+8]
    call dword ptr [{IAT_GetClientRect:#x}]
    test eax, eax
    mov eax, dword ptr [edi+0xc]
    mov ecx, dword ptr [edi+0x10]
    jz store_pt
    cmp eax, 0x32
    jge l1
    inc eax
l1: cmp ecx, 0x32
    jge l2
    inc ecx
l2: mov edx, dword ptr [ebp-8]
    sub edx, 0x32
    cmp eax, edx
    jle l3
    dec eax
l3: mov edx, dword ptr [ebp-4]
    sub edx, 0x32
    cmp ecx, edx
    jle l4
    dec ecx
l4: mov dword ptr [edi+0xc], eax
    mov dword ptr [edi+0x10], ecx
store_pt:
    mov dword ptr [ebp-0x18], eax
    mov dword ptr [ebp-0x14], ecx
    lea esi, [ebp-0x18]
    push esi
    push dword ptr [edi+8]
    call dword ptr [{IAT_ClientToScreen:#x}]
    call {SET_CURSOR_LOGICAL:#x}
    test eax, eax
    jnz done
    push esi
    call {GET_CURSOR_PHYSICAL:#x}
    add esp, 4
done:
    mov eax, dword ptr [esi]
    mov ecx, dword ptr [esi+4]
    mov dword ptr [edi], eax
    mov dword ptr [edi+4], ecx
    pop edi
    pop esi
    mov esp, ebp
    pop ebp
    ret
"""


def main():
    src, dst = sys.argv[1], sys.argv[2]
    listfile = sys.argv[3] if len(sys.argv) > 3 else None
    data = bytearray(open(src, "rb").read())
    pe = pefile.PE(data=bytes(data))
    base = pe.OPTIONAL_HEADER.ImageBase
    assert base == 0x400000

    foff = pe.get_offset_from_rva(FUNC_VA - base)
    size = FUNC_END - FUNC_VA
    if bytes(data[foff:foff + size]) != ORIGINAL_FUNC:
        sys.exit("Original bytes do not match - not a stock 4.3.4.15595 Wow.exe (or already patched).")

    ks = Ks(KS_ARCH_X86, KS_MODE_32)
    enc, _ = ks.asm(ASM, FUNC_VA)
    code = bytes(enc)
    if len(code) > size:
        sys.exit("new code too big: %d > %d" % (len(code), size))
    new = code + b"\xcc" * (size - len(code))

    # absolute operands that need base relocations
    abs_ops = []
    for const in (PIN_X, IAT_GetClientRect, IAT_ClientToScreen):
        pat = struct.pack("<I", const)
        idx = code.find(pat)
        assert idx >= 0 and code.find(pat, idx + 1) < 0, hex(const)
        abs_ops.append(FUNC_VA + idx)

    # repoint relocation entries that fall inside the function
    entries = []
    for blk in pe.DIRECTORY_ENTRY_BASERELOC:
        for e in blk.entries:
            va = base + e.rva
            if FUNC_VA <= va < FUNC_END:
                assert e.type == 3
                entries.append((e, blk.struct.VirtualAddress))
    assert len(entries) == 11, len(entries)
    patches = [(foff, new)]
    for i, (e, page_rva) in enumerate(entries):
        eoff = e.struct.get_file_offset()
        if i < len(abs_ops):
            word = (3 << 12) | ((abs_ops[i] - base) - page_rva)
        else:
            # IMAGE_REL_BASED_ABSOLUTE (type 0) is skipped by the loader; keep the old
            # offset so entries stay unique (some parsers stop at duplicate entries)
            word = (e.rva - page_rva) & 0x0FFF
        patches.append((eoff, struct.pack("<H", word)))

    for off, b in patches:
        data[off:off + len(b)] = b
    open(dst, "wb").write(data)

    md = Cs(CS_ARCH_X86, CS_MODE_32)
    print("new function: %d bytes (room %d)" % (len(code), size))
    for ins in md.disasm(code, FUNC_VA):
        print("  %08x  %-20s %s %s" % (ins.address, ins.bytes.hex(), ins.mnemonic, ins.op_str))
    print("relocations now at:", ", ".join(hex(a) for a in abs_ops))
    if listfile:
        with open(listfile, "w") as f:
            for off, b in patches:
                f.write("%x %s %s\n" % (off, bytes(open(src, "rb").read()[off:off + len(b)]).hex(), b.hex()))
    print("wrote", dst)


if __name__ == "__main__":
    main()
