fx_version "cerulean"
game "gta5"

author "BerkieB & Bebo"
description "Vehicle or garage management resource"
version "1.0.1"

shared_scripts {
	"@ox_lib/init.lua",
	"bridge/**/shared.lua",
	"init.lua",
	"data.lua",
	"config.lua",
}

client_scripts {
	"bridge/**/client.lua",
	"client/*.lua",
}

server_scripts {
	"@oxmysql/lib/MySQL.lua",
	"bridge/**/server.lua",
	"server/*.lua",
}

files {
	"locales/*.json",
}

dependencies {
	"/onesync",
	"/server:6129",
	"oxmysql",
	"ox_lib",
	"ox_inventory",
}

lua54 "yes"
use_experimental_fxv2_oal "yes"
