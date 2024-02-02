local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)
--lazyを用いたプラグインインストールの開始
require("lazy").setup {
	--タブバーの明快化
	{'romgrk/barbar.nvim',
	 dependencies = {
		'nvim-tree/nvim-web-devicons',
	},
	init = function() vim.g.barbar_auto_setup = false end,
	},
	--カラースキーマの設定。icebergかっこいいよね
	{'cocopon/iceberg.vim',
	priority = 1000,
	config = function()
		vim.cmd.colorscheme 'iceberg'
	end,
	},

}
vim.o.number = true
--ターミナルモードでコマンドモードに戻りやすくする
vim.api.nvim_set_keymap('t', '<Esc>', [[<C-\><C-n>]], {noremap = true, silent = true})
--ターミナル起動時すぐに入力可能にする
vim.api.nvim_create_autocmd("TermOpen", {
	pattern = "*",
	command = "startinsert"
})
--:termだとちょっと長いので、:Tにエイリアスを作成する。
vim.api.nvim_command('command! T term')
