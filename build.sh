#!/bin/bash
# ==================================================================
# AurumDOS -- build.sh для Git Bash
# Запуск: bash build.sh
# ==================================================================

# ==================== НАСТРОЙКИ ====================

NASM="D:/nasm/nasm.exe"
QEMU="D:/qemu/qemu-system-i386.exe"
RUN_QEMU=0

BOOT_ASM="boot.asm"
KERNEL_ASM="kernel.asm"
OUTPUT_IMG="aurumdos.img"
BUILD_DIR="build"

# Программы: "исходник.asm ИМЯ_НА_ДИСКЕ.BIN"
PROGRAMS=(
    "brainf.asm BRAINF.BIN"
    "atp.asm TABLE.BIN"
    "cubicdoom_wasd.asm DOOM.BIN"
)

# Готовые файлы: "путь/к/файлу ИМЯ_НА_ДИСКЕ.EXT"
EXTRA_FILES=(
    "img.bmp IMG.BMP"
    "logo.bmp LOGO.BMP"
)

# ===================================================

RED='\033[31m'
GREEN='\033[32m'
CYAN='\033[36m'
YELLOW='\033[33m'
NC='\033[0m'

info() { echo -e "${CYAN}[ INFO ]${NC} $1"; }
ok()   { echo -e "${GREEN}[  OK  ]${NC} $1"; }
warn() { echo -e "${YELLOW}[ WARN ]${NC} $1"; }
fail() { echo -e "${RED}[ FAIL ]${NC} $1"; exit 1; }

compile() {
    local src=$1
    local out=$2
    info "Компилирую $src..."
    $NASM -f bin "$src" -o "$out" || fail "Ошибка компиляции: $src"
    ok "$(basename $out) готов"
}

mkdir -p "$BUILD_DIR"

echo ""
echo "========== AurumDOS Build =========="
echo ""

# Компилируем загрузчик и ядро
compile "$BOOT_ASM"   "$BUILD_DIR/boot.bin"
compile "$KERNEL_ASM" "$BUILD_DIR/KERNEL.BIN"

# Компилируем программы
for prog in "${PROGRAMS[@]}"; do
    src=$(echo $prog | cut -d' ' -f1)
    name=$(echo $prog | cut -d' ' -f2)
    [ -f "$src" ] || { warn "Пропускаю $src — не найден"; continue; }
    compile "$src" "$BUILD_DIR/$name"
done

# Собираем FAT12 образ через Python
info "Собираю FAT12 образ..."

python3 - << PYEOF
import os, sys, struct

DISK_SIZE       = 1474560
SECTOR_SIZE     = 512
SECTORS_PER_FAT = 9
NUM_FATS        = 2
ROOT_ENTRIES    = 224
RESERVED        = 1
TOTAL_SECTORS   = 2880
MEDIA           = 0xF0
ROOT_SECTORS    = (ROOT_ENTRIES * 32) // SECTOR_SIZE
DATA_START      = RESERVED + NUM_FATS * SECTORS_PER_FAT + ROOT_SECTORS

BUILD_DIR  = '$BUILD_DIR'
OUTPUT_IMG = '$OUTPUT_IMG'

PROGRAMS    = [$(for p in "${PROGRAMS[@]}"; do name=$(echo $p | cut -d' ' -f2); echo "('$BUILD_DIR/$name','$name'),"; done)]
EXTRA_FILES = [$(for f in "${EXTRA_FILES[@]}"; do src=$(echo $f | cut -d' ' -f1); name=$(echo $f | cut -d' ' -f2); echo "('$src','$name'),"; done)]

def read(path):
    if not os.path.exists(path):
        print(f'[FAIL] Файл не найден: {path}'); sys.exit(1)
    with open(path, 'rb') as f: return f.read()

class FAT12:
    def __init__(self):
        self.disk = bytearray(DISK_SIZE)
        self.fat  = bytearray(SECTORS_PER_FAT * SECTOR_SIZE)
        self.root = bytearray(ROOT_ENTRIES * 32)
        self.next_cluster = 2
        self.fat[0]=MEDIA; self.fat[1]=0xFF; self.fat[2]=0xFF

    def _fat_set(self, c, v):
        o = (c*3)//2
        if c%2==0:
            self.fat[o]=v&0xFF; self.fat[o+1]=(self.fat[o+1]&0xF0)|((v>>8)&0x0F)
        else:
            self.fat[o]=(self.fat[o]&0x0F)|((v&0x0F)<<4); self.fat[o+1]=(v>>4)&0xFF

    def _write_cluster(self, c, data):
        off=(DATA_START+c-2)*SECTOR_SIZE
        p=bytearray(SECTOR_SIZE); p[:len(data)]=data
        self.disk[off:off+SECTOR_SIZE]=p

    def add_file(self, name, data):
        n83=self._to83(name); clusters=[]
        for i in range(0,max(1,len(data)),SECTOR_SIZE):
            c=self.next_cluster; self.next_cluster+=1
            clusters.append(c); self._write_cluster(c,data[i:i+SECTOR_SIZE])
        for i,c in enumerate(clusters):
            self._fat_set(c, clusters[i+1] if i+1<len(clusters) else 0xFFF)
        e=bytearray(32); e[0:11]=n83; e[11]=0x20
        e[26:28]=struct.pack('<H',clusters[0]); e[28:32]=struct.pack('<I',len(data))
        for i in range(ROOT_ENTRIES):
            o=i*32
            if self.root[o] in(0x00,0xE5): self.root[o:o+32]=e; return
        print('[FAIL] Root full!'); sys.exit(1)

    def _to83(self, fn):
        fn=fn.strip().upper()
        name,ext=(fn.rsplit('.',1) if '.' in fn else (fn,''))
        return (name[:8].ljust(8)+ext[:3].ljust(3)).encode('ascii')

    def build(self, boot):
        self.disk[0:len(boot)]=boot; self.disk[510]=0x55; self.disk[511]=0xAA
        f1=RESERVED*SECTOR_SIZE; f2=f1+SECTORS_PER_FAT*SECTOR_SIZE
        self.disk[f1:f1+len(self.fat)]=self.fat
        self.disk[f2:f2+len(self.fat)]=self.fat
        ro=(RESERVED+NUM_FATS*SECTORS_PER_FAT)*SECTOR_SIZE
        self.disk[ro:ro+len(self.root)]=self.root
        return bytes(self.disk)

boot=read(f'{BUILD_DIR}/boot.bin')
if len(boot)!=512: print(f'[FAIL] boot.bin не 512 байт'); sys.exit(1)

fat=FAT12()
kernel=read(f'{BUILD_DIR}/KERNEL.BIN')
fat.add_file('KERNEL.BIN',kernel)
print(f'[  OK  ] KERNEL.BIN — {len(kernel)} байт')

for src,name in PROGRAMS:
    if not os.path.exists(src): print(f'[ WARN ] Пропускаю {name}'); continue
    d=read(src); fat.add_file(name,d); print(f'[  OK  ] {name} — {len(d)} байт')

for src,name in EXTRA_FILES:
    if not os.path.exists(src): print(f'[ WARN ] Пропускаю {name}'); continue
    d=read(src); fat.add_file(name,d); print(f'[  OK  ] {name} — {len(d)} байт')

disk=fat.build(boot)
with open(OUTPUT_IMG,'wb') as f: f.write(disk)
used=(fat.next_cluster-2)*SECTOR_SIZE//1024
free=(TOTAL_SECTORS-DATA_START-(fat.next_cluster-2))*SECTOR_SIZE//1024
print(f'[  OK  ] Образ: {OUTPUT_IMG}')
print(f'[  OK  ] Использовано: ~{used} KB')
print(f'[  OK  ] Свободно: ~{free} KB')
PYEOF

[ $? -ne 0 ] && fail "Ошибка сборки образа"
ok "Образ собран: $OUTPUT_IMG"

if [ "$RUN_QEMU" = "1" ]; then
    info "Запускаю QEMU..."
    "$QEMU" -fda "$OUTPUT_IMG" &
    ok "QEMU запущен"
fi

echo ""
echo "========== Готово! =========="
echo ""
