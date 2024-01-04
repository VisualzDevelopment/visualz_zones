fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'Visualz Development'
website 'https://visualz.dk'
description 'Drug system for FiveM, contains selling, zone system'
version '1.0.0'

shared_scripts {
  '@ox_lib/init.lua',
  '@es_extended/imports.lua',
  'config/*.lua'
}

client_script 'client/*.lua'

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/*.lua',
  'functions/*.lua',
}
