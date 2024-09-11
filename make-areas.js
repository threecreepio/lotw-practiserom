import fs from 'fs/promises';

const file = Array.from((await fs.readFile('./original.nes'))).slice(0x10);

const roomsWidth = 4;
const roomsHeight = 18;

const itemTypes = {};
itemTypes[0x00] = 'ItemType_Wings       ';
itemTypes[0x01] = 'ItemType_Armor       ';
itemTypes[0x02] = 'ItemType_Mattock     ';
itemTypes[0x03] = 'ItemType_Glove       ';
itemTypes[0x04] = 'ItemType_Rod         ';
itemTypes[0x05] = 'ItemType_PowerBoots  ';
itemTypes[0x06] = 'ItemType_JumpShoes   ';
itemTypes[0x07] = 'ItemType_KeyStick    ';
itemTypes[0x08] = 'ItemType_PowerKnuckle';
itemTypes[0x09] = 'ItemType_FireRod     ';
itemTypes[0x0A] = 'ItemType_Shield      ';
itemTypes[0x0B] = 'ItemType_MagicPotion ';
itemTypes[0x0C] = 'ItemType_Elixir      ';
itemTypes[0x0D] = 'ItemType_Crystal     ';
itemTypes[0x0E] = 'ItemType_Crown       ';
itemTypes[0x0F] = 'ItemType_DragonSlayer';
itemTypes[0xFF] = 'ItemType_None        ';

const DropTypes = {};
DropTypes[0x00] = 'DropType_HP          ';
DropTypes[0x01] = 'DropType_Mana        ';
DropTypes[0x02] = 'DropType_Gold        ';
DropTypes[0x03] = 'DropType_Poison      ';
DropTypes[0x04] = 'DropType_Key         ';
DropTypes[0x05] = 'DropType_Ring        ';
DropTypes[0x06] = 'DropType_Cross       ';
DropTypes[0x07] = 'DropType_Scroll      ';
DropTypes[0x08] = 'DropType_Wings       ';
DropTypes[0x09] = 'DropType_Armor       ';
DropTypes[0x0A] = 'DropType_Mattock     ';
DropTypes[0x0B] = 'DropType_Glove       ';
DropTypes[0x0C] = 'DropType_Rod         ';
DropTypes[0x0D] = 'DropType_PowerBoots  ';
DropTypes[0x0E] = 'DropType_JumpShoes   ';
DropTypes[0x0F] = 'DropType_KeyStick    ';
DropTypes[0x10] = 'DropType_PowerKnuckle';
DropTypes[0x11] = 'DropType_FireRod     ';
DropTypes[0x12] = 'DropType_Shield      ';
DropTypes[0x13] = 'DropType_MagicPotion ';
DropTypes[0x14] = 'DropType_Elixir      ';
DropTypes[0x15] = 'DropType_Crystal     ';
DropTypes[0x16] = 'DropType_Crown       ';
DropTypes[0x17] = 'DropType_DragonSlayer';

const tileTypeNames = {};
tileTypeNames[0x00] = 'Tile_Ladder    ';
tileTypeNames[0x01] = 'Tile_Door      ';
tileTypeNames[0x02] = 'Tile_LockedDoor';
tileTypeNames[0x03] = 'Tile_Princess  ';
tileTypeNames[0x04] = 'Tile_ShopSign  ';
tileTypeNames[0x05] = 'Tile_InnSign   ';
tileTypeNames[0x06] = 'Tile_BG06      ';
tileTypeNames[0x07] = 'Tile_BG07      ';
tileTypeNames[0x08] = 'Tile_BG08      ';
tileTypeNames[0x09] = 'Tile_BG09      ';
tileTypeNames[0x0A] = 'Tile_BG0A      ';
tileTypeNames[0x0B] = 'Tile_BG0B      ';
tileTypeNames[0x0C] = 'Tile_BG0C      ';
tileTypeNames[0x0D] = 'Tile_BG0D      ';
tileTypeNames[0x0E] = 'Tile_BG0E      ';
tileTypeNames[0x0F] = 'Tile_BG0F      ';
tileTypeNames[0x10] = 'Tile_BG10      ';
tileTypeNames[0x11] = 'Tile_BG11      ';
tileTypeNames[0x12] = 'Tile_BG12      ';
tileTypeNames[0x13] = 'Tile_BG13      ';
tileTypeNames[0x14] = 'Tile_BG14      ';
tileTypeNames[0x15] = 'Tile_BG15      ';
tileTypeNames[0x16] = 'Tile_BG16      ';
tileTypeNames[0x17] = 'Tile_BG17      ';
tileTypeNames[0x18] = 'Tile_BG18      ';
tileTypeNames[0x19] = 'Tile_BG19      ';
tileTypeNames[0x1A] = 'Tile_BG1A      ';
tileTypeNames[0x1B] = 'Tile_BG1B      ';
tileTypeNames[0x1C] = 'Tile_BG1C      ';
tileTypeNames[0x1D] = 'Tile_BG1D      ';
tileTypeNames[0x1E] = 'Tile_BG1E      ';
tileTypeNames[0x1F] = 'Tile_BG1F      ';
tileTypeNames[0x20] = 'Tile_BG20      ';
tileTypeNames[0x21] = 'Tile_BG21      ';
tileTypeNames[0x22] = 'Tile_BG22      ';
tileTypeNames[0x23] = 'Tile_BG23      ';
tileTypeNames[0x24] = 'Tile_BG24      ';
tileTypeNames[0x25] = 'Tile_BG25      ';
tileTypeNames[0x26] = 'Tile_BG26      ';
tileTypeNames[0x27] = 'Tile_BG27      ';
tileTypeNames[0x28] = 'Tile_BG28      ';
tileTypeNames[0x29] = 'Tile_BG29      ';
tileTypeNames[0x2A] = 'Tile_BG2A      ';
tileTypeNames[0x2B] = 'Tile_BG2B      ';
tileTypeNames[0x2C] = 'Tile_BG2C      ';
tileTypeNames[0x2D] = 'Tile_BG2D      ';
tileTypeNames[0x2E] = 'Tile_BG2E      ';
tileTypeNames[0x2F] = 'Tile_BG2F      ';
tileTypeNames[0x30] = 'Tile_Spike     ';
tileTypeNames[0x31] = 'Tile_FG31      ';
tileTypeNames[0x32] = 'Tile_FG32      ';
tileTypeNames[0x33] = 'Tile_FG33      ';
tileTypeNames[0x34] = 'Tile_FG34      ';
tileTypeNames[0x35] = 'Tile_FG35      ';
tileTypeNames[0x36] = 'Tile_FG36      ';
tileTypeNames[0x37] = 'Tile_FG37      ';
tileTypeNames[0x38] = 'Tile_FG38      ';
tileTypeNames[0x39] = 'Tile_FG39      ';
tileTypeNames[0x3A] = 'Tile_FG3A      ';
tileTypeNames[0x3B] = 'Tile_FG3B      ';
tileTypeNames[0x3C] = 'Tile_FG3C      ';
tileTypeNames[0x3D] = 'Tile_FG3D      ';
tileTypeNames[0x3E] = 'Tile_FG3E      ';
tileTypeNames[0x3F] = 'Tile_FG3F      ';
tileTypeNames[0x3E] = 'Tile_BreakBlock';

let i = -1;
for (let ay=0; ay<roomsHeight; ++ay) {
    for (let ax=0; ax<roomsWidth; ++ax) {
        i += 1;
        const tiles = file.slice(i * 0x400).slice(0, 0x400);
        
        let roomData = [];
        for (let r=0; r<4; ++r) {
            for (let y=0; y<0x10; ++y) {
                let result = [];
                for (let x=0; x<12; ++x) {
                    let n = tiles[(r * 0x10 * 12) + (y * 12) + x];
                    const pal = (n >> 6) & 0b11;
                    const tilenum = (n & 0b00111111);
                    let tileName = `TPal_${pal}|${tileTypeNames[tilenum]}`;
                    result.push(tileName.padStart(12, ' '));
                }
                roomData.push(`.byte ${result.join(',')}`);
            }
            roomData.push('');
        }

        roomData.push(`.byte >MTiles${(tiles[0x300])}&$1F           ; BG metatiles`);
        roomData.push(`.byte ${h(tiles[0x301])}                    ; Enemy gfx`);
        roomData.push(`.byte ${tileName(tiles[0x302])} ; Block swap from`);
        roomData.push(`.byte ${tileName(tiles[0x303])} ; Block swap to`);
        roomData.push(`.byte ${tileName(tiles[0x304])} ; Block break to`);
        roomData.push(`.byte ${h(tiles[0x305])}                    ; CHR`);
        roomData.push(`.byte ${h(tiles[0x306])}                    ; Area data bank`);
        roomData.push('');
        roomData.push(`.byte ${h(tiles[0x307])}                    ; Chest Active`);
        roomData.push(`.byte ${h(tiles[0x308])}                    ; Chest X Tile`);
        roomData.push(`.byte ${h(tiles[0x309])}                    ; Chest Y Px`);
        roomData.push(`.byte ${DropTypes[tiles[0x30A]]} ; Chest Item Type`);
        roomData.push('');
        roomData.push(`.byte ${h(tiles[0x30B])}                    ; Area music`);
        roomData.push(`.byte ${h(tiles[0x30C])}                    ; Princess door X area`);
        roomData.push(`.byte ${h(tiles[0x30D])}                    ; Princess door Y area`);
        roomData.push(`.byte ${h(tiles[0x30E])}                    ; Princess door X tile`);
        roomData.push(`.byte ${h(tiles[0x30F])}                    ; Princess door Y pixel`);
        roomData.push('');
        roomData.push(`.byte ${itemTypes[tiles[0x310]]}  ; Shop Item 1 Type`);
        roomData.push(`.byte ${String(tiles[0x311]).padEnd(3)}                    ; Shop Item 1 Cost`);
        roomData.push(`.byte ${itemTypes[tiles[0x312]]}  ; Shop Item 2 Type`);
        roomData.push(`.byte ${String(tiles[0x313]).padEnd(3)}                    ; Shop Item 2 Cost`);
        roomData.push('');
        roomData.push(`.byte ${h(tiles[0x314])}                    ; Unk`);
        roomData.push(`.byte ${h(tiles[0x315])}                    ; Unk`);
        roomData.push(`.byte ${h(tiles[0x316])}                    ; Unk`);
        roomData.push(`.byte ${h(tiles[0x317])}                    ; Unk`);
        roomData.push(`.byte ${h(tiles[0x318])}                    ; Unk`);
        roomData.push(`.byte ${h(tiles[0x319])}                    ; Unk`);
        roomData.push(`.byte ${h(tiles[0x31A])}                    ; Unk`);
        roomData.push(`.byte ${h(tiles[0x31B])}                    ; Unk`);
        roomData.push(`.byte ${h(tiles[0x31C])}                    ; Unk`);
        roomData.push(`.byte ${h(tiles[0x31D])}                    ; Unk`);
        roomData.push(`.byte ${h(tiles[0x31E])}                    ; Unk`);
        roomData.push(`.byte ${h(tiles[0x31F])}                    ; Unk`);
        roomData.push('');

        roomData.push(';EnemyGFX  PAL    X    Y   HP  DMG  GFX ');
        for (let n=0; n<12; ++n) {
            const s = 0x320 + (n * 0x10);
            roomData.push(`.byte ${tiles.slice(s, s + 0x10).map(h).join(', ')}`);
        }
        roomData.push('');

        roomData.push('; Palette ');
        for (let n=0; n<8; ++n) {
            const slice = tiles.slice(0x3E0 + (n * 4), 0x3E0 + ((n + 1) * 4));
            roomData.push(`.byte ${slice.map(h).join(', ')}`);
        }


        roomData.push('');

        //fs.writeFile(`rooms/ROOM_${i}.s`, roomData.join('\n'));
        console.log(`src/areas/Y${String(ay).padStart(2, '0')}X${String(ax).padStart(2, '0')}.s`);
        await fs.writeFile(`src/areas/Y${String(ay).padStart(2, '0')}X${String(ax).padStart(2, '0')}.s`, roomData.join('\n'));
    }
}

// metatile tables
let mtilefile = [];
for (let i=0; i<0x20; ++i) {
    mtilefile.push(`MTiles${i}:`);
    const tiles = 0x40;
    const start = 0x12000;
    const tbl = file.slice(start + i * 0x4 * tiles, start + (i + 1) * 0x4 * tiles);
    for (let t=0; t<tiles; ++t) {
        const data = tbl.slice(t * 4, (t + 1) * 4);
        mtilefile.push(`.byte ${data.map(h).join(',')}    ; ${tileTypeNames[t]}`);
    }
    mtilefile.push('');
}
await fs.writeFile(`src/metatiles.s`, mtilefile.join('\n'));


function h(value) {
    return `\$${value.toString(16).padStart(2, '0').toUpperCase()}`;
}

function tileName(n) {
    const pal = (n >> 6) & 0b11;
    const tilenum = (n & 0b00111111);
    let tileName = `TPal_${pal}|${tileTypeNames[tilenum]}`;
    return tileName;
}

for (let [key, value] of Object.entries(tileTypeNames)) {
    console.log(`${value} = ${h(Number(key))}`);
}
