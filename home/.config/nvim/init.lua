require('vim_config')
require('plugin')
require('keys')

-- Machine-local tweaks live outside everything the library manages and
-- survive every update. Absent file, silent skip.
local local_cfg = (os.getenv('XDG_CONFIG_HOME') or (os.getenv('HOME') .. '/.config'))
    .. '/dotfiles-local/nvim.lua'
if vim.uv.fs_stat(local_cfg) then
  dofile(local_cfg)
end
