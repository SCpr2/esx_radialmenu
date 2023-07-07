fx_version 'cerulean'
game 'gta5'

description 'QB-RadialMenu --CONVERTED TO ESX BY SERDADU#7004'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    '@es_extended/locale.lua',
    'config.lua',
    'locales/en.lua' -- Change this to your preferred language
}

client_scripts {
    'client/*.lua',
}

server_scripts {
    'server/*.lua',
}

files {
    'html/index.html',
    'html/css/main.css',
    'html/js/main.js',
    'html/js/RadialMenu.js',
}

lua54 'yes'