// ============================================================
//  Mad Chemist - a chemical particle sandbox
//  AppGameKit Studio (Tier 1 / Basic)
//  49 selectable substances (real elements and compounds),
//  reactions kept in a table, sounds generated in code.
//
//  Controls:
//    Mouse/touch = draw   Right mouse button = erase
//    Buttons on the right = pick a substance (0-9 also work as keys)
//    Q / E = previous / next substance
//    Mouse wheel / up-down arrows = brush size
//    Space = pause   C = clear all   M = sound on/off
// ============================================================

#constant GW 200
#constant GH 144
#constant SCALE 5
#constant PANELX 1000

// Movement class of a substance
#constant K_STATIC 0
#constant K_POWDER 1
#constant K_LIQUID 2
#constant K_GAS 3
#constant K_GASH 4

// Substances (0..NPAL are shown in the panel, the rest are reaction products)
#constant E_EMPTY 0
#constant E_SAND 1
#constant E_WATER 2
#constant E_STONE 3
#constant E_FIRE 4
#constant E_OIL 5
#constant E_PLANT 6
#constant E_SMOKE 7
#constant E_LAVA 8
#constant E_STEAM 9
#constant E_BOMB 10
#constant E_SALT 11
#constant E_BRINE 12
#constant E_ACID 13
#constant E_BASE 14
#constant E_HYDROGEN 15
#constant E_HELIUM 16
#constant E_OXYGEN 17
#constant E_CHLORINE 18
#constant E_CO2 19
#constant E_MERCURY 20
#constant E_BROMINE 21
#constant E_LN2 22
#constant E_GASOLINE 23
#constant E_SULFUR 24
#constant E_PHOSPHORUS 25
#constant E_COAL 26
#constant E_SODIUM 27
#constant E_POTASSIUM 28
#constant E_LITHIUM 29
#constant E_MAGNESIUM 30
#constant E_ALUMINIUM 31
#constant E_IRON 32
#constant E_RUST 33
#constant E_COPPER 34
#constant E_ZINC 35
#constant E_SILVER 36
#constant E_GOLD 37
#constant E_LEAD 38
#constant E_DIAMOND 39
#constant E_THERMITE 40
#constant E_POWDER 41
#constant E_ICE 42
#constant E_SNOW 43
#constant E_DRYICE 44
#constant E_GLASS 45
#constant E_CEMENT 46
#constant E_CONCRETE 47
#constant E_CALCIUM 48
#constant NPAL 48
// Hidden products
#constant E_FWHITE 49
#constant E_FRED 50
#constant E_FVIOLET 51
#constant E_FGREEN 52
#constant E_FYELLOW 53
#constant E_FBLUE 54
#constant E_ASH 55
#constant E_MOLTEN 56
#constant E_SO2 57
#constant E_COUNT 57

#constant MAXRX 500

// Sounds
#constant SR 22050
#constant S_FIRE 1
#constant S_CRACK1 2
#constant S_BOOM1 5
#constant S_HISS 7
#constant S_LAVA 8
#constant S_CLICK 9
#constant S_POP 10
#constant S_FIZZ 11

SetWindowTitle("Mad Chemist")
SetWindowSize(1280, 720, 0)
SetVirtualResolution(1280, 720)
SetOrientationAllowed(0, 0, 1, 1)
SetSyncRate(60, 0)
SetScissor(0, 0, 0, 0)

global dim grid[GW, GH] as integer
global dim stamp[GW, GH] as integer

global dim colR[E_COUNT] as integer
global dim colG[E_COUNT] as integer
global dim colB[E_COUNT] as integer
global dim ename[E_COUNT] as string
global dim ekind[E_COUNT] as integer
global dim edens[E_COUNT] as integer
global dim emov[E_COUNT] as integer
global dim edecTo[E_COUNT] as integer
global dim edecP[E_COUNT] as integer
global dim eblast[E_COUNT] as integer
global dim eact[E_COUNT] as integer
global dim ealias[E_COUNT] as integer

global dim rxTab[E_COUNT, E_COUNT] as integer
global dim rxC[MAXRX] as integer
global dim rxD[MAXRX] as integer
global dim rxP[MAXRX] as integer
global dim rxS[MAXRX] as integer
global nRx as integer = 0

global frame as integer = 1
global cur as integer = 1
global brush as integer = 4
global paused as integer = 0
global lastWheel as float = 0

// Sound state
global nFire as integer = 0
global nLava as integer = 0
global evBoom as integer = 0
global evPop as integer = 0
global evHiss as integer = 0
global evFizz as integer = 0
global evBurn as integer = 0
global tick as integer = 0
global lastHiss as integer = 0
global lastBoom as integer = 0
global lastPop as integer = 0
global lastFizz as integer = 0
global fireInst as integer = 0
global lavaInst as integer = 0
global muted as integer = 0

// Show a loading text before the sounds are generated
CreateText(501, "Generating sounds...")
SetTextSize(501, 40)
SetTextPosition(501, 400, 330)
Sync()

GenerateAllSounds()
DeleteText(501)

SetupElements()
SetupReactions()
ComputeActive()

// Image memblock: 12-byte header + GW*GH*4 bytes of pixels
CreateMemblock(1, 12 + GW * GH * 4)
SetMemblockInt(1, 0, GW)
SetMemblockInt(1, 4, GH)
SetMemblockInt(1, 8, 32)

DrawGrid()
CreateSprite(1, 1)
SetSpriteSize(1, GW * SCALE, GH * SCALE)
SetSpritePosition(1, 0, 0)
SetSpriteDepth(1, 100)

BuildUI()

do
    HandleInput()
    if paused = 0 then SimStep()
    DrawGrid()
    UpdateUI()
    UpdateAudio()
    Sync()
loop

// ------------------------------------------------------------
//  Substance and reaction definitions
// ------------------------------------------------------------
// id, name, movement class, density, rgb, move chance %, decays into, decay chance (per mille), blast resistance
// Note: rgb values must be >= 23 so that the noise subtraction never goes negative.
function DefElem(id as integer, nm as string, k as integer, dn as integer, r as integer, g as integer, b as integer, mv as integer, dt as integer, dp as integer, bl as integer)
    ename[id] = nm
    ekind[id] = k
    edens[id] = dn
    colR[id] = r
    colG[id] = g
    colB[id] = b
    emov[id] = mv
    edecTo[id] = dt
    edecP[id] = dp
    eblast[id] = bl
    ealias[id] = id
endfunction

function SetupElements()
    DefElem(E_EMPTY, "Eraser",      K_STATIC, 0,  150, 150, 150, 0,   0,        0,  0)
    DefElem(E_SAND, "Sand",     K_POWDER, 20, 222, 190, 110, 100, 0,        0,  0)
    DefElem(E_WATER, "Water",       K_LIQUID, 10, 40,  100, 220, 100, 0,        0,  0)
    DefElem(E_STONE, "Stone",       K_STATIC, 99, 110, 110, 120, 0,   0,        0,  1)
    DefElem(E_FIRE, "Fire",       K_GAS,    1,  255, 140, 20,  40,  E_SMOKE,  60, 0)
    DefElem(E_OIL, "Oil",       K_LIQUID, 8,  90,  60,  30,  100, 0,        0,  0)
    DefElem(E_PLANT, "Plant",      K_STATIC, 99, 40,  170, 60,  0,   0,        0,  0)
    DefElem(E_SMOKE, "Smoke",       K_GAS,    2,  90,  90,  90,  100, E_EMPTY,  20, 0)
    DefElem(E_LAVA, "Lava",      K_LIQUID, 30, 230, 60,  10,  25,  0,        0,  0)
    DefElem(E_STEAM, "Steam",      K_GAS,    1,  200, 215, 230, 100, E_WATER,  4,  0)
    DefElem(E_BOMB, "Explosive",    K_POWDER, 18, 200, 50,  140, 100, 0,        0,  0)
    DefElem(E_SALT, "Salt",      K_POWDER, 15, 235, 235, 240, 100, 0,        0,  0)
    DefElem(E_BRINE, "Brine",  K_LIQUID, 11, 80,  135, 225, 100, 0,        0,  0)
    DefElem(E_ACID, "Acid",      K_LIQUID, 11, 110, 235, 70,  100, 0,        0,  0)
    DefElem(E_BASE, "Base",       K_LIQUID, 10, 180, 80,  220, 100, 0,        0,  0)
    DefElem(E_HYDROGEN, "Hydrogen",       K_GAS,    1,  150, 170, 255, 100, 0,        0,  0)
    DefElem(E_HELIUM, "Helium",     K_GAS,    1,  255, 190, 215, 100, 0,        0,  0)
    DefElem(E_OXYGEN, "Oxygen",      K_GAS,    1,  170, 255, 255, 100, 0,        0,  0)
    DefElem(E_CHLORINE, "Chlorine",     K_GASH,   6,  225, 225, 80,  100, E_EMPTY,  3,  0)
    DefElem(E_CO2, "CO2",        K_GASH,   5,  110, 120, 150, 100, E_EMPTY,  4,  0)
    DefElem(E_MERCURY, "Mercury",   K_LIQUID, 40, 190, 195, 205, 100, 0,        0,  0)
    DefElem(E_BROMINE, "Bromine",      K_LIQUID, 15, 150, 45,  30,  100, 0,        0,  0)
    DefElem(E_LN2, "LN2",    K_LIQUID, 7,  60,  210, 190, 100, E_STEAM,  8,  0)
    DefElem(E_GASOLINE, "Gasoline",   K_LIQUID, 6,  230, 185, 70,  100, 0,        0,  0)
    DefElem(E_SULFUR, "Sulfur",      K_POWDER, 13, 235, 220, 50,  100, 0,        0,  0)
    DefElem(E_PHOSPHORUS, "Phosphorus",    K_POWDER, 12, 190, 60,  60,  100, 0,        0,  0)
    DefElem(E_COAL, "Coal",      K_POWDER, 14, 55,  50,  50,  100, 0,        0,  0)
    DefElem(E_SODIUM, "Sodium",    K_POWDER, 9,  210, 210, 150, 100, 0,        0,  0)
    DefElem(E_POTASSIUM, "Potassium",     K_POWDER, 8,  170, 170, 220, 100, 0,        0,  0)
    DefElem(E_LITHIUM, "Lithium",     K_POWDER, 5,  195, 195, 195, 100, 0,        0,  0)
    DefElem(E_MAGNESIUM, "Magnesium",  K_POWDER, 17, 225, 230, 235, 100, 0,        0,  0)
    DefElem(E_ALUMINIUM, "Aluminium",   K_STATIC, 99, 185, 190, 200, 0,   0,        0,  1)
    DefElem(E_IRON, "Iron",      K_STATIC, 99, 150, 135, 130, 0,   0,        0,  1)
    DefElem(E_RUST, "Rust",     K_POWDER, 18, 170, 85,  40,  100, 0,        0,  0)
    DefElem(E_COPPER, "Copper",     K_STATIC, 99, 200, 120, 70,  0,   0,        0,  1)
    DefElem(E_ZINC, "Zinc",     K_STATIC, 99, 150, 170, 190, 0,   0,        0,  1)
    DefElem(E_SILVER, "Silver",      K_STATIC, 99, 215, 215, 225, 0,   0,        0,  1)
    DefElem(E_GOLD, "Gold",      K_STATIC, 99, 240, 200, 50,  0,   0,        0,  1)
    DefElem(E_LEAD, "Lead",      K_STATIC, 99, 80,  85,  100, 0,   0,        0,  1)
    DefElem(E_DIAMOND, "Diamond",   K_STATIC, 99, 185, 245, 255, 0,   0,        0,  1)
    DefElem(E_THERMITE, "Thermite",  K_POWDER, 20, 150, 95,  75,  100, 0,        0,  0)
    DefElem(E_POWDER, "Gunpowder",      K_POWDER, 14, 60,  60,  75,  100, 0,        0,  0)
    DefElem(E_ICE, "Ice",        K_STATIC, 99, 150, 220, 240, 0,   0,        0,  0)
    DefElem(E_SNOW, "Snow",       K_POWDER, 3,  235, 240, 250, 100, 0,        0,  0)
    DefElem(E_DRYICE, "Dry Ice",   K_POWDER, 12, 200, 235, 245, 100, E_CO2,    15, 0)
    DefElem(E_GLASS, "Glass",       K_STATIC, 99, 190, 235, 215, 0,   0,        0,  0)
    DefElem(E_CEMENT, "Cement",   K_POWDER, 16, 170, 170, 150, 100, 0,        0,  0)
    DefElem(E_CONCRETE, "Concrete",     K_STATIC, 99, 130, 130, 125, 0,   0,        0,  1)
    DefElem(E_CALCIUM, "Calcium",    K_STATIC, 99, 225, 225, 200, 0,   0,        0,  0)

    // Hidden products: coloured flames, ash, molten iron, sulfur dioxide
    DefElem(E_FWHITE, "White flame", K_GAS,   1,  255, 255, 235, 40,  E_ASH,    50, 0)
    DefElem(E_FRED, "Red flame",  K_GAS,   1,  255, 50,  60,  40,  E_SMOKE,  60, 0)
    DefElem(E_FVIOLET, "Violet flame",  K_GAS,   1,  190, 110, 255, 40,  E_SMOKE,  60, 0)
    DefElem(E_FGREEN, "Green flame",  K_GAS,   1,  80,  255, 120, 40,  E_SMOKE,  60, 0)
    DefElem(E_FYELLOW, "Yellow flame",  K_GAS,   1,  255, 235, 60,  40,  E_SMOKE,  60, 0)
    DefElem(E_FBLUE, "Blue flame",  K_GAS,   1,  80,  130, 255, 40,  E_SO2,    60, 0)
    DefElem(E_ASH, "Ash",       K_POWDER, 10, 170, 170, 170, 100, 0,        0,  0)
    DefElem(E_MOLTEN, "Molten iron",  K_LIQUID, 28, 255, 235, 160, 25,  E_IRON,   6,  0)
    DefElem(E_SO2, "SO2",         K_GAS,   3,  210, 200, 120, 100, E_EMPTY,  5,  0)

    // Flames behave like fire in reactions, molten iron like lava
    ealias[E_FWHITE] = E_FIRE
    ealias[E_FRED] = E_FIRE
    ealias[E_FVIOLET] = E_FIRE
    ealias[E_FGREEN] = E_FIRE
    ealias[E_FYELLOW] = E_FIRE
    ealias[E_FBLUE] = E_FIRE
    ealias[E_MOLTEN] = E_LAVA
endfunction

// Adds a reaction a + b -> c + d (chance in per mille per contact).
// The reverse order (b + a -> d + c) is added automatically.
// s = sound effect: 0 none, 1 hiss, 2 crackle, 3 big explosion,
//                 4 small pop, 5 fizz, 6 medium pop
function AddRx(a as integer, b as integer, c as integer, d as integer, p as integer, s as integer)
    nRx = nRx + 1
    rxC[nRx] = c
    rxD[nRx] = d
    rxP[nRx] = p
    rxS[nRx] = s
    rxTab[a, b] = nRx
    if a <> b
        nRx = nRx + 1
        rxC[nRx] = d
        rxD[nRx] = c
        rxP[nRx] = p
        rxS[nRx] = s
        rxTab[b, a] = nRx
    endif
endfunction

function SetupReactions()
    // --- Fire (all flames) ---
    AddRx(E_WATER,     E_FIRE,       E_STEAM,    E_EMPTY,    400, 1)
    AddRx(E_BRINE,     E_FIRE,       E_SALT,     E_STEAM,    300, 1)
    AddRx(E_FIRE,      E_PLANT,      E_FIRE,     E_FIRE,     250, 2)
    AddRx(E_FIRE,      E_OIL,        E_FIRE,     E_FIRE,     500, 2)
    AddRx(E_FIRE,      E_GASOLINE,   E_FIRE,     E_FIRE,     800, 2)
    AddRx(E_FIRE,      E_COAL,       E_FIRE,     E_FIRE,     40,  2)
    AddRx(E_FIRE,      E_POWDER,     E_FIRE,     E_FIRE,     900, 2)
    AddRx(E_FIRE,      E_BOMB,       E_FIRE,     E_FIRE,     600, 3)
    AddRx(E_FIRE,      E_HYDROGEN,   E_FIRE,     E_STEAM,    500, 4)
    AddRx(E_FIRE,      E_OXYGEN,     E_FIRE,     E_FIRE,     500, 2)
    AddRx(E_FIRE,      E_CO2,        E_SMOKE,    E_CO2,      500, 0)
    AddRx(E_FIRE,      E_ICE,        E_STEAM,    E_WATER,    250, 1)
    AddRx(E_FIRE,      E_SNOW,       E_STEAM,    E_WATER,    300, 1)
    AddRx(E_FIRE,      E_LN2,        E_EMPTY,    E_STEAM,    400, 1)
    AddRx(E_FIRE,      E_DRYICE,     E_SMOKE,    E_CO2,      400, 1)
    AddRx(E_FIRE,      E_SODIUM,     E_FYELLOW,  E_FYELLOW,  150, 2)
    AddRx(E_FIRE,      E_POTASSIUM,  E_FVIOLET,  E_FVIOLET,  300, 2)
    AddRx(E_FIRE,      E_LITHIUM,    E_FRED,     E_FRED,     150, 2)
    AddRx(E_FIRE,      E_MAGNESIUM,  E_FWHITE,   E_FWHITE,   300, 2)
    AddRx(E_FIRE,      E_PHOSPHORUS, E_FWHITE,   E_FWHITE,   600, 2)
    AddRx(E_FIRE,      E_SULFUR,     E_FBLUE,    E_FBLUE,    150, 2)
    AddRx(E_FIRE,      E_COPPER,     E_FGREEN,   E_COPPER,   150, 0)
    AddRx(E_FIRE,      E_THERMITE,   E_FWHITE,   E_MOLTEN,   500, 2)

    // --- Lava and molten iron ---
    AddRx(E_LAVA,      E_WATER,      E_STONE,    E_STEAM,    300, 1)
    AddRx(E_LAVA,      E_BRINE,      E_STONE,    E_STEAM,    300, 1)
    AddRx(E_LAVA,      E_PLANT,      E_LAVA,     E_FIRE,     300, 2)
    AddRx(E_LAVA,      E_OIL,        E_LAVA,     E_FIRE,     500, 2)
    AddRx(E_LAVA,      E_GASOLINE,   E_LAVA,     E_FIRE,     800, 2)
    AddRx(E_LAVA,      E_COAL,       E_LAVA,     E_FIRE,     100, 2)
    AddRx(E_LAVA,      E_POWDER,     E_LAVA,     E_FIRE,     800, 2)
    AddRx(E_LAVA,      E_BOMB,       E_LAVA,     E_FIRE,     600, 3)
    AddRx(E_LAVA,      E_HYDROGEN,   E_LAVA,     E_STEAM,    500, 4)
    AddRx(E_LAVA,      E_OXYGEN,     E_LAVA,     E_FIRE,     300, 2)
    AddRx(E_LAVA,      E_SAND,       E_LAVA,     E_GLASS,    40,  0)
    AddRx(E_LAVA,      E_ICE,        E_STONE,    E_WATER,    300, 1)
    AddRx(E_LAVA,      E_SNOW,       E_LAVA,     E_STEAM,    500, 1)
    AddRx(E_LAVA,      E_LN2,        E_STONE,    E_STEAM,    600, 1)
    AddRx(E_LAVA,      E_DRYICE,     E_LAVA,     E_CO2,      600, 0)
    AddRx(E_LAVA,      E_THERMITE,   E_LAVA,     E_MOLTEN,   300, 2)
    AddRx(E_LAVA,      E_SODIUM,     E_LAVA,     E_FYELLOW,  300, 2)
    AddRx(E_LAVA,      E_POTASSIUM,  E_LAVA,     E_FVIOLET,  400, 2)
    AddRx(E_LAVA,      E_LITHIUM,    E_LAVA,     E_FRED,     300, 2)
    AddRx(E_LAVA,      E_MAGNESIUM,  E_LAVA,     E_FWHITE,   300, 2)
    AddRx(E_LAVA,      E_PHOSPHORUS, E_LAVA,     E_FWHITE,   500, 2)
    AddRx(E_LAVA,      E_SULFUR,     E_LAVA,     E_FBLUE,    200, 2)

    // --- Alkali and alkaline earth metals ---
    AddRx(E_SODIUM,    E_WATER,      E_FYELLOW,  E_HYDROGEN, 350, 4)
    AddRx(E_SODIUM,    E_BRINE,      E_FYELLOW,  E_HYDROGEN, 350, 4)
    AddRx(E_SODIUM,    E_ACID,       E_FYELLOW,  E_HYDROGEN, 500, 4)
    AddRx(E_SODIUM,    E_SNOW,       E_FYELLOW,  E_HYDROGEN, 200, 4)
    AddRx(E_SODIUM,    E_CHLORINE,   E_SALT,     E_FYELLOW,  400, 2)
    AddRx(E_SODIUM,    E_BROMINE,    E_SALT,     E_FYELLOW,  300, 2)

    AddRx(E_POTASSIUM, E_WATER,      E_FVIOLET,  E_HYDROGEN, 600, 6)
    AddRx(E_POTASSIUM, E_BRINE,      E_FVIOLET,  E_HYDROGEN, 600, 6)
    AddRx(E_POTASSIUM, E_ACID,       E_FVIOLET,  E_HYDROGEN, 700, 6)
    AddRx(E_POTASSIUM, E_SNOW,       E_FVIOLET,  E_HYDROGEN, 400, 6)
    AddRx(E_POTASSIUM, E_CHLORINE,   E_SALT,     E_FVIOLET,  400, 2)
    AddRx(E_POTASSIUM, E_BROMINE,    E_SALT,     E_FVIOLET,  300, 2)

    AddRx(E_LITHIUM,   E_WATER,      E_FRED,     E_HYDROGEN, 150, 5)
    AddRx(E_LITHIUM,   E_BRINE,      E_FRED,     E_HYDROGEN, 150, 5)
    AddRx(E_LITHIUM,   E_ACID,       E_FRED,     E_HYDROGEN, 300, 4)
    AddRx(E_LITHIUM,   E_CHLORINE,   E_SALT,     E_FRED,     400, 2)
    AddRx(E_LITHIUM,   E_BROMINE,    E_SALT,     E_FRED,     300, 2)

    AddRx(E_CALCIUM,   E_WATER,      E_BASE,     E_HYDROGEN, 40,  5)
    AddRx(E_CALCIUM,   E_ACID,       E_BRINE,    E_HYDROGEN, 300, 5)
    AddRx(E_MAGNESIUM, E_WATER,      E_ASH,      E_HYDROGEN, 6,   5)
    AddRx(E_MAGNESIUM, E_ACID,       E_BRINE,    E_HYDROGEN, 400, 5)

    // --- Acid, base and halogens ---
    AddRx(E_ACID,      E_IRON,       E_BRINE,    E_HYDROGEN, 80,  5)
    AddRx(E_ACID,      E_ZINC,       E_BRINE,    E_HYDROGEN, 150, 5)
    AddRx(E_ACID,      E_ALUMINIUM,  E_BRINE,    E_HYDROGEN, 100, 5)
    AddRx(E_ACID,      E_STONE,      E_BRINE,    E_CO2,      60,  5)
    AddRx(E_ACID,      E_CONCRETE,   E_BRINE,    E_CO2,      60,  5)
    AddRx(E_ACID,      E_PLANT,      E_BRINE,    E_SMOKE,    150, 5)
    AddRx(E_ACID,      E_RUST,       E_BRINE,    E_EMPTY,    100, 5)
    AddRx(E_ACID,      E_BASE,       E_BRINE,    E_WATER,    400, 1)
    AddRx(E_BASE,      E_CHLORINE,   E_BRINE,    E_EMPTY,    200, 1)
    AddRx(E_CHLORINE,  E_WATER,      E_EMPTY,    E_ACID,     40,  1)
    AddRx(E_PLANT,     E_CHLORINE,   E_EMPTY,    E_CHLORINE, 100, 0)
    AddRx(E_PLANT,     E_BROMINE,    E_EMPTY,    E_BROMINE,  80,  0)
    AddRx(E_ALUMINIUM, E_MERCURY,    E_ASH,      E_MERCURY,  40,  0)
    AddRx(E_ALUMINIUM, E_BROMINE,    E_FWHITE,   E_ASH,      100, 2)

    // --- Rusting, sulfur and phosphorus ---
    AddRx(E_IRON,      E_WATER,      E_RUST,     E_WATER,    4,   0)
    AddRx(E_IRON,      E_BRINE,      E_RUST,     E_BRINE,    12,  0)
    AddRx(E_PHOSPHORUS, E_OXYGEN,    E_FWHITE,   E_OXYGEN,   300, 2)
    AddRx(E_SO2,       E_WATER,      E_EMPTY,    E_ACID,     100, 1)
    AddRx(E_PLANT,     E_SO2,        E_EMPTY,    E_SO2,      60,  0)

    // --- Salt ---
    AddRx(E_SALT,      E_WATER,      E_BRINE,    E_WATER,    150, 0)
    AddRx(E_SALT,      E_ICE,        E_BRINE,    E_WATER,    100, 1)
    AddRx(E_SALT,      E_SNOW,       E_BRINE,    E_WATER,    120, 1)

    // --- Cold ---
    AddRx(E_ICE,       E_STEAM,      E_ICE,      E_WATER,    80,  0)
    AddRx(E_WATER,     E_ICE,        E_ICE,      E_ICE,      10,  0)
    AddRx(E_SNOW,      E_WATER,      E_WATER,    E_WATER,    100, 0)
    AddRx(E_LN2,       E_WATER,      E_STEAM,    E_ICE,      250, 1)
    AddRx(E_LN2,       E_BRINE,      E_STEAM,    E_ICE,      250, 1)
    AddRx(E_DRYICE,    E_WATER,      E_CO2,      E_WATER,    200, 5)

    // --- Other ---
    AddRx(E_CEMENT,    E_WATER,      E_CONCRETE, E_EMPTY,    100, 0)
    AddRx(E_PLANT,     E_WATER,      E_PLANT,    E_PLANT,    40,  0)
    AddRx(E_PLANT,     E_BRINE,      E_EMPTY,    E_BRINE,    15,  0)
endfunction

// Only moving or decaying substances start reactions
// (static ones such as stone react when a neighbour starts the reaction).
function ComputeActive()
    local i as integer
    for i = 0 to E_COUNT
        eact[i] = 0
        if ekind[i] <> K_STATIC then eact[i] = 1
        if edecP[i] > 0 then eact[i] = 1
    next i
    eact[0] = 0
endfunction

// ------------------------------------------------------------
//  User interface (panel on the right, 4 columns)
// ------------------------------------------------------------
function BuildUI()
    local i as integer
    local col as integer
    local row as integer
    local bx as integer
    local by as integer

    CreateSprite(9, 0)
    SetSpriteSize(9, 1280 - PANELX, 720)
    SetSpritePosition(9, PANELX, 0)
    SetSpriteColor(9, 20, 20, 28, 255)
    SetSpriteDepth(9, 30)

    for i = 0 to NPAL
        col = Mod(i, 4)
        row = trunc(i / 4)
        bx = PANELX + 2 + col * 70
        by = 4 + row * 55

        CreateSprite(100 + i, 0)
        SetSpriteSize(100 + i, 66, 50)
        SetSpritePosition(100 + i, bx, by)
        SetSpriteDepth(100 + i, 20)

        CreateSprite(200 + i, 0)
        SetSpriteSize(200 + i, 66, 6)
        SetSpritePosition(200 + i, bx, by)
        SetSpriteColor(200 + i, colR[i], colG[i], colB[i], 255)
        SetSpriteDepth(200 + i, 19)

        CreateText(300 + i, ename[i])
        SetTextSize(300 + i, 11)
        SetTextPosition(300 + i, bx + 4, by + 22)
        SetTextColor(300 + i, 255, 255, 255, 255)
        SetTextDepth(300 + i, 5)
    next i

    CreateText(500, "")
    SetTextSize(500, 16)
    SetTextPosition(500, 10, 696)
    SetTextColor(500, 255, 255, 255, 255)
    SetTextDepth(500, 4)
endfunction

function UpdateUI()
    local i as integer
    local s as string
    for i = 0 to NPAL
        if i = cur
            SetSpriteColor(100 + i, 80, 80, 130, 255)
        else
            SetSpriteColor(100 + i, 34, 34, 46, 255)
        endif
    next i
    s = "Element: " + ename[cur] + "   Brush: " + str(brush) + "   FPS: " + str(ScreenFPS(), 0)
    s = s + "   0-9 / Q / E change element"
    if paused = 1 then s = s + "   [PAUSED]"
    if muted = 1 then s = s + "   [SOUND OFF]"
    SetTextString(500, s)
endfunction

// ------------------------------------------------------------
//  Input
// ------------------------------------------------------------
function SelectElement(i as integer)
    if cur <> i
        cur = i
        PlaySound(S_CLICK, 40, 0)
    endif
endfunction

function HandleInput()
    local i as integer
    local col as integer
    local row as integer
    local w as float
    local px as float
    local py as float

    for i = 0 to 9
        if GetRawKeyPressed(48 + i) = 1 then SelectElement(i)
    next i
    if GetRawKeyPressed(81) = 1 then SelectElement(Mod(cur + NPAL, NPAL + 1))
    if GetRawKeyPressed(69) = 1 then SelectElement(Mod(cur + 1, NPAL + 1))

    if GetRawKeyPressed(32) = 1 then paused = 1 - paused
    if GetRawKeyPressed(67) = 1 then ClearAll()
    if GetRawKeyPressed(38) = 1 then brush = brush + 1
    if GetRawKeyPressed(40) = 1 then brush = brush - 1

    if GetRawKeyPressed(77) = 1
        muted = 1 - muted
        if muted = 1
            SetSoundSystemVolume(0)
        else
            SetSoundSystemVolume(100)
        endif
    endif

    w = GetRawMouseWheel()
    if w > lastWheel then brush = brush + 1
    if w < lastWheel then brush = brush - 1
    lastWheel = w
    if brush < 1 then brush = 1
    if brush > 20 then brush = 20

    px = GetPointerX()
    py = GetPointerY()

    if px >= PANELX
        if GetPointerPressed() = 1
            col = trunc((px - PANELX - 2) / 70)
            row = trunc((py - 4) / 55)
            if col >= 0 and col <= 3 and row >= 0
                i = row * 4 + col
                if i >= 0 and i <= NPAL then SelectElement(i)
            endif
        endif
    else
        if GetPointerState() = 1
            Paint(trunc(px / SCALE), trunc(py / SCALE), cur)
        endif
        if GetRawMouseRightState() = 1
            Paint(trunc(px / SCALE), trunc(py / SCALE), 0)
        endif
    endif
endfunction

function Paint(cx as integer, cy as integer, e as integer)
    local dx as integer
    local dy as integer
    local x as integer
    local y as integer
    for dy = -brush to brush
        for dx = -brush to brush
            if dx * dx + dy * dy <= brush * brush
                x = cx + dx
                y = cy + dy
                if x >= 0 and x < GW and y >= 0 and y < GH
                    if e = 0
                        grid[x, y] = 0
                    elseif grid[x, y] = 0
                        if ekind[e] = K_STATIC or Random(0, 2) > 0 then SetCell(x, y, e)
                    endif
                endif
            endif
        next dx
    next dy
endfunction

function ClearAll()
    local x as integer
    local y as integer
    for y = 0 to GH - 1
        for x = 0 to GW - 1
            grid[x, y] = 0
        next x
    next y
endfunction

// ------------------------------------------------------------
//  Helper functions
// ------------------------------------------------------------
function Cell(x as integer, y as integer)
    if x < 0 or x >= GW or y < 0 or y >= GH then exitfunction E_STONE
endfunction grid[x, y]

function SetCell(x as integer, y as integer, e as integer)
    if x >= 0 and x < GW and y >= 0 and y < GH
        grid[x, y] = e
        stamp[x, y] = frame
    endif
endfunction

function SwapCells(x1 as integer, y1 as integer, x2 as integer, y2 as integer)
    local t as integer
    t = grid[x1, y1]
    grid[x1, y1] = grid[x2, y2]
    grid[x2, y2] = t
    stamp[x1, y1] = frame
    stamp[x2, y2] = frame
endfunction

// Can substance a displace substance b? (empty always, heavier displaces lighter liquid)
function CanDisplace(a as integer, b as integer)
    if b = 0 then exitfunction 1
    if ekind[b] = K_LIQUID
        if ekind[a] = K_POWDER or ekind[a] = K_LIQUID
            if edens[a] > edens[b] then exitfunction 1
        endif
    endif
endfunction 0

function TryMove(x as integer, y as integer, nx as integer, ny as integer)
    if CanDisplace(grid[x, y], Cell(nx, ny)) = 1
        SwapCells(x, y, nx, ny)
        exitfunction 1
    endif
endfunction 0

function LiquidMove(x as integer, y as integer, d as integer)
    local r as integer
    r = TryMove(x, y, x, y + 1)
    if r = 0 then r = TryMove(x, y, x + d, y + 1)
    if r = 0 then r = TryMove(x, y, x - d, y + 1)
    if r = 0 then r = TryMove(x, y, x + d, y)
    if r = 0 then r = TryMove(x, y, x - d, y)
endfunction

function GasMove(x as integer, y as integer, d as integer)
    local r as integer
    r = TryMove(x, y, x, y - 1)
    if r = 0 then r = TryMove(x, y, x + d, y - 1)
    if r = 0 then r = TryMove(x, y, x - d, y - 1)
    if r = 0 then r = TryMove(x, y, x + d, y)
    if r = 0 then r = TryMove(x, y, x - d, y)
endfunction

// ------------------------------------------------------------
//  Simulation
// ------------------------------------------------------------
function SimStep()
    local x as integer
    local y as integer
    local e as integer
    local d as integer
    local r as integer
    local k as integer

    frame = frame + 1

    for y = GH - 1 to 0 step -1
        for x = 0 to GW - 1
            e = grid[x, y]
            if e <> 0
                if eact[e] = 1 and stamp[x, y] <> frame
                    d = Random(0, 1) * 2 - 1
                    TryReact(x, y)

                    if grid[x, y] = e and stamp[x, y] <> frame
                        if edecP[e] > 0 and Random(1, 1000) <= edecP[e]
                            SetCell(x, y, edecTo[e])
                        elseif Random(1, 100) <= emov[e]
                            k = ekind[e]
                            if k = K_POWDER
                                r = TryMove(x, y, x, y + 1)
                                if r = 0 then r = TryMove(x, y, x + d, y + 1)
                                if r = 0 then r = TryMove(x, y, x - d, y + 1)
                            elseif k = K_LIQUID or k = K_GASH
                                LiquidMove(x, y, d)
                            elseif k = K_GAS
                                GasMove(x, y, d)
                            endif
                        endif
                    endif
                endif
            endif
        next x
    next y
endfunction

// Picks a random neighbour and tries the reaction table
// (flames and molten iron are looked up through their alias)
function TryReact(x as integer, y as integer)
    local a as integer
    local b as integer
    local nx as integer
    local ny as integer
    local idx as integer
    local s as integer

    a = grid[x, y]
    nx = x + Random(-1, 1)
    ny = y + Random(-1, 1)
    if nx < 0 or nx >= GW or ny < 0 or ny >= GH then exitfunction

    b = grid[nx, ny]
    idx = rxTab[ealias[a], ealias[b]]
    if idx = 0 then exitfunction
    if Random(1, 1000) > rxP[idx] then exitfunction

    SetCell(x, y, rxC[idx])
    SetCell(nx, ny, rxD[idx])

    s = rxS[idx]
    if s = 1
        evHiss = evHiss + 1
    elseif s = 2
        evBurn = evBurn + 1
    elseif s = 3
        Explode(x, y, 7)
    elseif s = 4
        Explode(x, y, 2)
    elseif s = 5
        evFizz = evFizz + 1
    elseif s = 6
        Explode(x, y, 4)
    endif
endfunction

// Explosion: core turns to fire, rim to fire/smoke, water to steam.
// Stone, metals, diamond and concrete survive.
function Explode(cx as integer, cy as integer, r as integer)
    local dx as integer
    local dy as integer
    local x as integer
    local y as integer
    local dd as integer
    local e as integer

    if r >= 5
        evBoom = evBoom + r
    else
        evPop = evPop + 1
    endif

    for dy = -r to r
        for dx = -r to r
            dd = dx * dx + dy * dy
            if dd <= r * r
                x = cx + dx
                y = cy + dy
                if x >= 0 and x < GW and y >= 0 and y < GH
                    e = grid[x, y]
                    if eblast[e] = 0
                        if dd <= (r * r) / 4
                            SetCell(x, y, E_FIRE)
                        elseif e = E_WATER or e = E_BRINE
                            SetCell(x, y, E_STEAM)
                        elseif ekind[e] = K_POWDER and e <> E_BOMB and e <> E_POWDER and e <> E_THERMITE
                            SetCell(x, y, E_EMPTY)
                        else
                            if Random(0, 2) > 0
                                SetCell(x, y, E_FIRE)
                            else
                                SetCell(x, y, E_SMOKE)
                            endif
                        endif
                    endif
                endif
            endif
        next dx
    next dy
endfunction

// ------------------------------------------------------------
//  Drawing: grid -> memblock -> image -> sprite
// ------------------------------------------------------------
function DrawGrid()
    local x as integer
    local y as integer
    local e as integer
    local a as integer
    local n as integer
    local off as integer
    local c as integer

    nFire = 0
    nLava = 0
    off = 12
    for y = 0 to GH - 1
        for x = 0 to GW - 1
            e = grid[x, y]
            if e = 0
                c = 12 + 12 * 256 + 18 * 65536 - 16777216
            else
                a = ealias[e]
                if a = E_FIRE
                    nFire = nFire + 1
                    n = Random(0, 9)
                elseif a = E_LAVA
                    nLava = nLava + 1
                    n = Random(0, 9)
                else
                    n = Mod(x * 31 + y * 17, 24)
                endif
                c = (colR[e] - n) + (colG[e] - n) * 256 + (colB[e] - n) * 65536 - 16777216
            endif
            SetMemblockInt(1, off, c)
            off = off + 4
        next x
    next y

    if GetImageExists(1) = 1 then DeleteImage(1)
    CreateImageFromMemblock(1, 1)
    SetImageMagFilter(1, 0)
    SetImageMinFilter(1, 0)

    if GetSpriteExists(1) = 1
        SetSpriteImage(1, 1)
        SetSpriteSize(1, GW * SCALE, GH * SCALE)
    endif
endfunction

// ------------------------------------------------------------
//  Sound playback (called once per frame)
// ------------------------------------------------------------
function UpdateLoop(id as integer, inst as integer, vol as integer)
    if vol <= 0
        if inst > 0
            if GetSoundInstancePlaying(inst) = 1 then StopSoundInstance(inst)
        endif
        exitfunction 0
    endif
    if inst > 0
        if GetSoundInstancePlaying(inst) = 1
            SetSoundInstanceVolume(inst, vol)
            exitfunction inst
        endif
    endif
    inst = PlaySound(id, vol, 1)
endfunction inst

function UpdateAudio()
    local f as integer
    local l as integer
    local v as integer
    local p as integer

    tick = tick + 1
    f = nFire
    l = nLava
    if paused = 1
        f = 0
        l = 0
        evBoom = 0
        evPop = 0
        evHiss = 0
        evFizz = 0
        evBurn = 0
    endif

    // Flame roar: volume grows with the amount of fire
    v = trunc(sqrt(f) * 6)
    if v > 85 then v = 85
    fireInst = UpdateLoop(S_FIRE, fireInst, v)

    // Lava rumble and bubbles
    v = trunc(sqrt(l) * 5)
    if v > 70 then v = 70
    lavaInst = UpdateLoop(S_LAVA, lavaInst, v)

    // Crackles: random, more frequent when something ignites
    if f > 0 or evBurn > 0
        p = 4 + f / 6 + evBurn * 25
        if p > 70 then p = 70
        if Random(1, 100) <= p
            PlaySound(S_CRACK1 + Random(0, 2), 25 + Random(0, 45), 0)
        endif
    endif

    // Hiss (water + fire/lava, cooling, neutralisation)
    if evHiss > 0 and tick - lastHiss >= 5
        v = 30 + evHiss * 5
        if v > 100 then v = 100
        PlaySound(S_HISS, v, 0)
        lastHiss = tick
    endif

    // Fizz (acids, dry ice)
    if evFizz > 0 and tick - lastFizz >= 4
        v = 25 + evFizz * 6
        if v > 75 then v = 75
        PlaySound(S_FIZZ, v, 0)
        lastFizz = tick
    endif

    // Small pop (hydrogen, sodium)
    if evPop > 0 and tick - lastPop >= 2
        v = 40 + evPop * 4
        if v > 90 then v = 90
        PlaySound(S_POP, v, 0)
        lastPop = tick
    endif

    // Big explosion
    if evBoom > 0 and tick - lastBoom >= 6
        v = 50 + evBoom * 3
        if v > 100 then v = 100
        PlaySound(S_BOOM1 + Random(0, 1), v, 0)
        lastBoom = tick
    endif

    evBoom = 0
    evPop = 0
    evHiss = 0
    evFizz = 0
    evBurn = 0
endfunction

// ------------------------------------------------------------
//  Sound generation (mono, 16-bit, 22050 Hz)
//  Note: AGK's Sin() uses degrees.
// ------------------------------------------------------------
function NewSoundMem(frames as integer)
    local m as integer
    m = CreateMemblock(12 + frames * 2)
    SetMemblockShort(m, 0, 1)     // channels
    SetMemblockShort(m, 2, 16)    // bits per sample
    SetMemblockInt(m, 4, SR)      // sample rate
    SetMemblockInt(m, 8, frames)  // number of frames
endfunction m

function FinishSound(id as integer, m as integer)
    if GetSoundExists(id) = 1 then DeleteSound(id)
    CreateSoundFromMemblock(id, m)
    DeleteMemblock(m)
endfunction

function Clamp16(v as integer)
    if v > 32000 then exitfunction 32000
    if v < -32000 then exitfunction -32000
endfunction v

function GenerateAllSounds()
    local i as integer
    GenFire(S_FIRE)
    for i = 0 to 2
        GenCrackle(S_CRACK1 + i)
    next i
    GenExplosion(S_BOOM1, 1600, 100.0)
    GenExplosion(S_BOOM1 + 1, 1100, 130.0)
    GenHiss(S_HISS)
    GenLava(S_LAVA)
    GenClick(S_CLICK)
    GenPop(S_POP)
    GenFizz(S_FIZZ)
endfunction

// Crackle: a few sharp clicks (high-frequency noise, fast decay)
function GenCrackle(id as integer)
    local frames as integer
    local m as integer
    local i as integer
    local n as float
    local prev as float
    local env as float
    local v as integer

    frames = 3300
    m = NewSoundMem(frames)
    env = 0
    prev = 0
    for i = 0 to frames - 1
        n = Random(-1000, 1000) / 1000.0
        if i = 0 or Random(1, 1000) <= 1 then env = 0.5 + Random(0, 500) / 1000.0
        v = Clamp16(trunc((n - prev) * env * 12000))
        prev = n
        env = env * 0.994
        SetMemblockShort(m, 12 + i * 2, v)
    next i
    FinishSound(id, m)
endfunction

// Flame roar (loop): low-pass filtered noise + slow volume
// waving + random small pops
function GenFire(id as integer)
    local frames as integer
    local m as integer
    local i as integer
    local n as float
    local prev as float
    local lp as float
    local a as float
    local g as float
    local t as float
    local amp as float
    local pe as float
    local fade as float
    local v as integer

    frames = SR * 2
    m = NewSoundMem(frames)
    a = 0.15
    g = sqrt((2.0 - a) / a) * 0.6
    lp = 0
    prev = 0
    pe = 0
    for i = 0 to frames - 1
        t = i * 1.0 / frames
        n = Random(-1000, 1000) / 1000.0
        lp = lp + a * (n - lp)
        amp = 0.7 + 0.2 * sin(360.0 * 3.0 * t) + 0.1 * sin(360.0 * 7.0 * t)
        if Random(1, 1000) <= 1 then pe = 1.0
        fade = 1.0
        if i < 300 then fade = i / 300.0
        if i > frames - 300 then fade = (frames - i) / 300.0
        v = Clamp16(trunc((lp * g * amp + (n - prev) * pe * 0.35) * fade * 14000))
        prev = n
        pe = pe * 0.99
        SetMemblockShort(m, 12 + i * 2, v)
    next i
    FinishSound(id, m)
endfunction

// Explosion: noise whose filter darkens + a low, falling boom
function GenExplosion(id as integer, ms as integer, baseHz as float)
    local frames as integer
    local m as integer
    local i as integer
    local n as float
    local lp as float
    local a as float
    local g as float
    local t as float
    local att as float
    local decay as float
    local freq as float
    local phase as float
    local v as integer

    frames = SR * ms / 1000
    m = NewSoundMem(frames)
    lp = 0
    phase = 0
    decay = 1.0
    for i = 0 to frames - 1
        t = i * 1.0 / frames
        a = 0.5 - 0.48 * t
        g = sqrt((2.0 - a) / a) * 0.6
        n = Random(-1000, 1000) / 1000.0
        lp = lp + a * (n - lp)

        att = 1.0
        if i < 80 then att = i / 80.0
        decay = decay * 0.99988

        freq = baseHz - 70.0 * t
        phase = phase + 360.0 * freq / SR
        if phase > 360.0 then phase = phase - 360.0

        v = Clamp16(trunc((lp * g * 0.9 + sin(phase) * 0.8) * att * decay * 17000))
        SetMemblockShort(m, 12 + i * 2, v)
    next i
    FinishSound(id, m)
endfunction

// Hiss: high-frequency noise that fades out
function GenHiss(id as integer)
    local frames as integer
    local m as integer
    local i as integer
    local n as float
    local prev as float
    local att as float
    local decay as float
    local v as integer

    frames = SR * 600 / 1000
    m = NewSoundMem(frames)
    prev = 0
    decay = 1.0
    for i = 0 to frames - 1
        n = Random(-1000, 1000) / 1000.0
        att = 1.0
        if i < 200 then att = i / 200.0
        decay = decay * 0.99978
        v = Clamp16(trunc((n - prev) * att * decay * 7000))
        prev = n
        SetMemblockShort(m, 12 + i * 2, v)
    next i
    FinishSound(id, m)
endfunction

// Lava rumble (loop): low noise + random bubbles
function GenLava(id as integer)
    local frames as integer
    local m as integer
    local i as integer
    local n as float
    local lp as float
    local a as float
    local g as float
    local t as float
    local amp as float
    local be as float
    local bf as float
    local bp as float
    local fade as float
    local v as integer

    frames = SR * 2
    m = NewSoundMem(frames)
    a = 0.04
    g = sqrt((2.0 - a) / a) * 0.6
    lp = 0
    be = 0
    bf = 150
    bp = 0
    for i = 0 to frames - 1
        t = i * 1.0 / frames
        n = Random(-1000, 1000) / 1000.0
        lp = lp + a * (n - lp)
        amp = 0.6 + 0.4 * sin(360.0 * 2.0 * t)
        if Random(1, 1000) <= 1
            be = 1.0
            bf = Random(110, 260)
            bp = 0
        endif
        bp = bp + 360.0 * bf / SR
        if bp > 360.0 then bp = bp - 360.0
        fade = 1.0
        if i < 300 then fade = i / 300.0
        if i > frames - 300 then fade = (frames - i) / 300.0
        v = Clamp16(trunc((lp * g * amp * 0.8 + sin(bp) * be * 0.5) * fade * 14000))
        be = be * 0.9992
        SetMemblockShort(m, 12 + i * 2, v)
    next i
    FinishSound(id, m)
endfunction

// Button click: short sine pulse
function GenClick(id as integer)
    local frames as integer
    local m as integer
    local i as integer
    local phase as float
    local env as float
    local v as integer

    frames = 1300
    m = NewSoundMem(frames)
    phase = 0
    env = 1.0
    for i = 0 to frames - 1
        phase = phase + 360.0 * 1000.0 / SR
        if phase > 360.0 then phase = phase - 360.0
        v = Clamp16(trunc(sin(phase) * env * 9000))
        env = env * 0.996
        SetMemblockShort(m, 12 + i * 2, v)
    next i
    FinishSound(id, m)
endfunction

// Pop: a short low thump + a burst of noise
function GenPop(id as integer)
    local frames as integer
    local m as integer
    local i as integer
    local n as float
    local t as float
    local freq as float
    local phase as float
    local env as float
    local envn as float
    local v as integer

    frames = 4000
    m = NewSoundMem(frames)
    phase = 0
    env = 1.0
    envn = 1.0
    for i = 0 to frames - 1
        t = i * 1.0 / frames
        freq = 180.0 - 120.0 * t
        phase = phase + 360.0 * freq / SR
        if phase > 360.0 then phase = phase - 360.0
        n = Random(-1000, 1000) / 1000.0
        v = Clamp16(trunc((sin(phase) * 0.7 + n * 0.5 * envn) * env * 16000))
        env = env * 0.9993
        envn = envn * 0.997
        SetMemblockShort(m, 12 + i * 2, v)
    next i
    FinishSound(id, m)
endfunction

// Fizz: randomly gated high-frequency noise
function GenFizz(id as integer)
    local frames as integer
    local m as integer
    local i as integer
    local n as float
    local prev as float
    local gate as float
    local decay as float
    local v as integer

    frames = SR * 400 / 1000
    m = NewSoundMem(frames)
    prev = 0
    gate = 0
    decay = 1.0
    for i = 0 to frames - 1
        n = Random(-1000, 1000) / 1000.0
        if Random(1, 60) = 1 then gate = 1.0
        gate = gate * 0.93
        decay = decay * 0.99985
        v = Clamp16(trunc((n - prev) * gate * decay * 9000))
        prev = n
        SetMemblockShort(m, 12 + i * 2, v)
    next i
    FinishSound(id, m)
endfunction
