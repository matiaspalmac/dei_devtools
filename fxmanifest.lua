fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Dei'
description 'In-game developer tools overlay for FiveM'
version '1.0'

shared_scripts {
    'config.lua',
}

server_scripts {
    'server/framework.lua',
    'server/main.lua',
}

client_scripts {
    'client/framework.lua',
    'client/nui.lua',
    'client/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/assets/css/*.css',
    'html/assets/js/*.js',
    'html/assets/fonts/*.otf',
}
