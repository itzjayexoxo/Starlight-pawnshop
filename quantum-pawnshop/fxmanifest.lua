fx_version 'cerulean'
game 'gta5'

name 'quantum-pawnshop'
author 'Ethereal Developments'
description 'Server-authoritative Qbox pawnshop job with offline buyer, employee offers, appraiser and society management.'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/utils.lua'
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
    'client/peds.lua',
    'client/menus.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/society.lua',
    'server/transactions.lua',
    'server/main.lua'
}

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'oxmysql'
}
