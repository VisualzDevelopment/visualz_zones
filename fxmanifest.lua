fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'Visualz Development'
website 'https://visualz.dk'
description 'Zone system for ESX made by Visualz Development'
version '1.0.0'

shared_scripts {
  '@ox_lib/init.lua',
  '@es_extended/imports.lua',
  'config/config.lua'
}

client_script 'client/*.lua'

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'config/logs.lua',
  'server/*.lua',
}

escrow_ignore {
  'server/functions.lua',
  'config/*.lua'
}
