---@diagnostic disable: undefined-global
fx_version "cerulean"

description "Galaxy Garage"
author "Csucsi"
version '1.0.0'

lua54 'yes'

games {
  "gta5",
  "rdr3"
}

ui_page 'web/index.html'

shared_scripts{
    "shared/config.lua"
}

client_scripts{
    "@callback/lib/client.lua",
    "@PolyZone/client.lua",
    "@PolyZone/BoxZone.lua",
    "@PolyZone/EntityZone.lua",
    "@PolyZone/CircleZone.lua",
    "@PolyZone/ComboZone.lua",
    "client/utils.lua",
    "client/client.lua"
}
server_scripts{
    "@callback/lib/server.lua",
    "@mysql-async/lib/MySQL.lua",
    "server/server.lua"
}

files {
    "web/**/*"
}