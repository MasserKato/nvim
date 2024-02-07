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
		'lewis6991/gitsigns.nvim',
		'nvim-tree/nvim-web-devicons',
	},
	init = function() vim.g.barbar_auto_setup = false end,
	opts = {
		animation = true,
		},
	},
	--カラースキーマの設定。icebergかっこいいよね
	{'cocopon/iceberg.vim',
	priority = 1000,
	config = function()
		vim.cmd.colorscheme 'iceberg'
	end,
	},
	-- Telescopeによるファジーファインダー機能
	{
		"nvim-telescope/telescope.nvim",
		dependencies = {"nvim-lua/plenary.nvim"},
		config = function() 
			require("telescope").setup{} 
		end,
	},

	-- nvim-treeによるファイルビュー機能
	{
		"kyazdani42/nvim-tree.lua",
		dependencies = {"kyazdani42/nvim-web-devicons"},
		config = function() 
			require("nvim-tree").setup {} 
			require("nvim-tree.api").tree.open()
		end,
	},
	-- Github Copilot
	{
		"github/copilot.vim",
		lazy = false,
	},

}
--ターミナルモードでコマンドモードに戻りやすくする
vim.api.nvim_set_keymap('t', '<Esc>', [[<C-\><C-n>]], {noremap = true, silent = true})
--ターミナル起動時すぐに入力可能にする
vim.api.nvim_create_autocmd("TermOpen", {
	pattern = "*",
	command = "startinsert"
})
--:termだと長いので、:Tにエイリアスを作成する。
vim.api.nvim_command('command! T term')

--nvim-treeがあるのでnetrwは無効化
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

--ヤンクをクリップボードにコピーする
vim.opt.clipboard = "unnamedplus"

--行番号を表示しないバッファを指定
vim.api.nvim_create_autocmd({"BufEnter", "FocusGained", "InsertLeave", "WinEnter"}, {
    pattern = "*",
    callback = function()
        if vim.fn.win_gettype() ~= 'popup' and vim.bo.filetype ~= 'NvimTree' then
            vim.wo.number = true
        end
    end,
})

