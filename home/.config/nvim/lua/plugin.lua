local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({ 'git', 'clone', '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git', '--branch=stable', lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- The library's committed lazy-lock.json is the source of truth for plugin
-- pins. In a dev checkout the config dir is writable and lazy uses that file
-- directly, so plugin updates write pins back into the repo. From the nix
-- store it is read-only: lazy then works against the machine's local copy,
-- which activation refreshes from the library and restores against
-- (modules/home/common/lazy-pins.nix).
local cfgdir = vim.fn.stdpath('config')
local lockfile = cfgdir .. '/lazy-lock.json'
if not vim.uv.fs_access(cfgdir, 'W') then
  lockfile = vim.fn.stdpath('state') .. '/lazy-lock.json'
end
require('lazy').setup('plugins', { lockfile = lockfile })  -- load every file in lua/plugins/

