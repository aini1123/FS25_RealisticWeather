RW_WheelsUtil = {}

-- ##############################################################################

-- NOTES

-- Wheel types are registered when the game is launched through game.lua (source)
-- Wheel types have coefficients for normal, wet and snowy ground conditions
-- 6 wheel types in total, each coeffecient has 4 different coefficient types
-- GROUND_ROAD, GROUND_HARD_TERRAIN, GROUND_SOFT_TERRAIN, GROUND_FIELD

-- ##############################################################################


-- MUD TIRES


local mudTireCoeffs = {
    [WheelsUtil.GROUND_ROAD] = 1.2,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 1.2,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 1.05,
    [WheelsUtil.GROUND_FIELD] = 1.05

    -- ORIG: 1.15, 1.15, 1.1, 0.95
}
local mudTireCoeffsWet = {
    [WheelsUtil.GROUND_ROAD] = 1.05,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 1.05,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 0.85,
    [WheelsUtil.GROUND_FIELD] = 0.75

    -- ORIG: 1.05, 1.05, 1, 0.7
}
local mudTireCoeffsSnow = {
    [WheelsUtil.GROUND_ROAD] = 0.5,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 0.48,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 0.4,
    [WheelsUtil.GROUND_FIELD] = 0.38

    -- ORIG: 0.45, 0.45, 0.4, 0.35
}


-- OFF-ROAD TIRES


local offRoadTireCoeffs = {
    [WheelsUtil.GROUND_ROAD] = 1.25,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 1.25,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 1.15,
    [WheelsUtil.GROUND_FIELD] = 1.1

    -- ORIG: 1.2, 1.15, 1.05, 1
}
local offRoadTireCoeffsWet = {
    [WheelsUtil.GROUND_ROAD] = 1,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 1,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 1,
    [WheelsUtil.GROUND_FIELD] = 0.85

    -- ORIG: 1.05, 1, 0.95, 0.6
}
local offRoadTireCoeffsSnow = {
    [WheelsUtil.GROUND_ROAD] = 0.35,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 0.33,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 0.32,
    [WheelsUtil.GROUND_FIELD] = 0.3

    -- ORIG: 0.45, 0.4, 0.35, 0.3
}


-- STREET TIRES


local streetTireCoeffs = {
    [WheelsUtil.GROUND_ROAD] = 1.5,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 1.35,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 0.55,
    [WheelsUtil.GROUND_FIELD] = 0.45

    -- ORIG: 1.25, 1.15, 1, 0.9
}
local streetTireCoeffsWet = {
    [WheelsUtil.GROUND_ROAD] = 1.3,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 1.2,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 0.35,
    [WheelsUtil.GROUND_FIELD] = 0.25

    -- ORIG: 1.15, 1, 0.85, 0.45
}
local streetTireCoeffsSnow = {
    [WheelsUtil.GROUND_ROAD] = 0.28,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 0.26,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 0.22,
    [WheelsUtil.GROUND_FIELD] = 0.2

    -- ORIG: 0.55, 0.4, 0.3, 0.35
}


-- CRAWLER TRACKS


local crawlerCoeffs = {
    [WheelsUtil.GROUND_ROAD] = 1.35,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 1.35,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 1.25,
    [WheelsUtil.GROUND_FIELD] = 1.25

    -- ORIG: 1.15, 1.15, 1.15, 1.15
}
local crawlerCoeffsWet = {
    [WheelsUtil.GROUND_ROAD] = 1.3,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 1.3,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 0.95,
    [WheelsUtil.GROUND_FIELD] = 0.95

    -- ORIG: 1.05, 1.05, 1.05, 0.85
}
local crawlerCoeffsSnow = {
    [WheelsUtil.GROUND_ROAD] = 0.9,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 0.9,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 0.8,
    [WheelsUtil.GROUND_FIELD] = 0.8

    -- ORIG: 0.65, 0.65, 0.65, 0.65
}


-- CHAINS


local chainsCoeffs = {
    [WheelsUtil.GROUND_ROAD] = 1.55,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 1.55,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 1.15,
    [WheelsUtil.GROUND_FIELD] = 1.15

    -- ORIG: 1.15, 1.15, 1.15, 1.15
}
local chainsCoeffsWet = {
    [WheelsUtil.GROUND_ROAD] = 1.15,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 1.15,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 1.12,
    [WheelsUtil.GROUND_FIELD] = 1.12

    -- ORIG: 1.05, 1.05, 1.05, 0.95
}
local chainsCoeffsSnow = {
    [WheelsUtil.GROUND_ROAD] = 1.35,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 1.35,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 1.1,
    [WheelsUtil.GROUND_FIELD] = 1.1

    -- ORIG: 1.05, 1.05, 1.05, 1.05
}


-- METAL SPIKES


local metalCoeffs = {
    [WheelsUtil.GROUND_ROAD] = 1.05,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 1.05,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 1.75,
    [WheelsUtil.GROUND_FIELD] = 1.75

    -- ORIG: 1.15, 1.15, 1.15, 1.15
}
local metalCoeffsWet = {
    [WheelsUtil.GROUND_ROAD] = 0.95,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 0.95,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 1.5,
    [WheelsUtil.GROUND_FIELD] = 1.5

    -- ORIG: 1.15, 1.15, 1.15, 1.15
}
local metalCoeffsSnow = {
    [WheelsUtil.GROUND_ROAD] = 0.9,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 0.9,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 1.35,
    [WheelsUtil.GROUND_FIELD] = 1.35

    -- ORIG: 1.15, 1.15, 1.15, 1.15
}



WheelsUtil.unregisterTireType("mud")
WheelsUtil.unregisterTireType("offRoad")
WheelsUtil.unregisterTireType("street")
WheelsUtil.unregisterTireType("crawler")
WheelsUtil.unregisterTireType("chains")
WheelsUtil.unregisterTireType("metalSpikes")

WheelsUtil.registerTireType("mud", mudTireCoeffs, mudTireCoeffsWet, mudTireCoeffsSnow)
WheelsUtil.registerTireType("offRoad", offRoadTireCoeffs, offRoadTireCoeffsWet, offRoadTireCoeffsSnow)
WheelsUtil.registerTireType("street", streetTireCoeffs, streetTireCoeffsWet, streetTireCoeffsSnow)
WheelsUtil.registerTireType("crawler", crawlerCoeffs, crawlerCoeffsWet, crawlerCoeffsSnow)
WheelsUtil.registerTireType("chains", chainsCoeffs, chainsCoeffsWet, chainsCoeffsSnow)
WheelsUtil.registerTireType("metalSpikes", metalCoeffs, metalCoeffsWet, metalCoeffsSnow)