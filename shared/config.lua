---@diagnostic disable: lowercase-global, undefined-global

config = {
    impound = {
        price = 50
    },

    default = {
        ped = {
            model = "cs_priest"
        }
    },

    restrictedFactions = {
        -- {
        --     id = "1",
        --     label = "PD"
        -- }
    },

    locations = {
        ["1"] = {
            ped = {
                model = "cs_priest",
                coords = vec4(470.37, -1078.71, 28.2, 180.77),
            },
            minZ = 22.0,
            maxZ = 40.0,
            zone = {
                vec2(406.58, -1064.37),
                vec2(406.58, -1143.61),
                vec2(508.94, -1144.4),
                vec2(507.76, -1061.11)
            },
            parkingZones = {
                vec4(459.2, -1080.2, 29.19, 272.12),
                vec4(459.2, -1083.9, 29.19, 272.12),
                vec4(459.2, -1087.7, 29.19, 272.12),
                vec4(459.2, -1091.5, 29.19, 272.12),
                vec4(459.2, -1095.25, 29.19, 272.12),
                vec4(459.2, -1099.79, 29.19, 272.12)
            }
        },
        ["2"] = {
            ped = {
                model = "cs_priest",
                coords = vec4(221.77, -1392.97, 29.59, 312.53),
            },

            minZ = 20.0,
            maxZ = 40.0,
            zone = {
                vec2(267.69, -1392.26),
                vec2(225.57, -1435.9),
                vec2(169.11, -1406.05),
                vec2(214.13, -1344.60)
            },
            parkingZones = {
                vec4(224.35, -1388.15, 30.53, 266.50),
                vec4(219.60, -1384.63, 30.53, 266.50),
                vec4(217.36, -1381.29, 30.53, 266.50)
            }
        }
    }
}