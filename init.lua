local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local lazy_entry = lazypath .. "/lua/lazy/init.lua"
local lazy_origin = "https://github.com/folke/lazy.nvim.git"

local function apply_safe_editor_opts()
  -- モデル行とプロジェクト配下の .nvim.lua / .exrc からのコマンド実行を無効にする
  vim.opt.modeline = false
  vim.opt.modelines = 0
  vim.opt.modelineexpr = false
  vim.opt.exrc = false
end

local function valid_branch(branch)
  return type(branch) == "string"
    and branch:match("^[%w._/-]+$") ~= nil
    and not branch:find("..", 1, true)
    and branch:sub(1, 1) ~= "-"
end

local function pinned_lazy_spec()
  local f = io.open(vim.fn.stdpath("config") .. "/lazy-lock.json", "r")
  if not f then
    return nil, nil
  end
  local content = f:read("*a")
  f:close()
  local pos = content:find('"lazy.nvim"', 1, true)
  if not pos then
    return nil, nil
  end
  local block = content:sub(pos, pos + 220)
  local commit = block:match('"commit"%s*:%s*"([0-9a-fA-F]+)"')
  local branch = block:match('"branch"%s*:%s*"([^"]+)"')
  if commit and #commit == 40 and valid_branch(branch) then
    return commit:lower(), branch
  end
  return nil, nil
end

local function git_cmd(args)
  -- lazy のプラグインディレクトリの外に置く。:Lazy clean の対象にしない。
  local nohooks = vim.fn.stdpath("cache") .. "/lazy-no-hooks"
  vim.fn.mkdir(nohooks, "p")
  local prev_prompt = vim.env.GIT_TERMINAL_PROMPT
  vim.env.GIT_TERMINAL_PROMPT = "0"
  local cmd = {
    "git",
    "-c", "advice.detachedHead=false",
    "-c", "init.defaultBranch=main",
    "-c", "core.autocrlf=false",
    "-c", "core.fsmonitor=",
    "-c", "core.hooksPath=" .. nohooks,
    "-c", "init.templateDir=",
    "-c", "protocol.file.allow=never",
  }
  vim.list_extend(cmd, args)
  local out = vim.fn.system(cmd)
  local code = vim.v.shell_error
  vim.env.GIT_TERMINAL_PROMPT = prev_prompt
  return out, code
end

local function git_ok(args)
  local out, code = git_cmd(args)
  return code == 0, out
end

local function lazy_head()
  if not vim.loop.fs_stat(lazypath .. "/.git") then
    return nil
  end
  local out, code = git_cmd({ "-C", lazypath, "rev-parse", "HEAD" })
  if code ~= 0 then
    return nil
  end
  return vim.trim(out)
end

local function pin_origin()
  local url, code = git_cmd({ "-C", lazypath, "remote", "get-url", "origin" })
  if code ~= 0 then
    return git_ok({ "-C", lazypath, "remote", "add", "origin", lazy_origin })
  end
  if vim.trim(url) ~= lazy_origin then
    return git_ok({ "-C", lazypath, "remote", "set-url", "origin", lazy_origin })
  end
  return true, ""
end

local function lazy_branch()
  if not vim.loop.fs_stat(lazypath .. "/.git") then
    return nil
  end
  local out, code = git_cmd({ "-C", lazypath, "rev-parse", "--abbrev-ref", "HEAD" })
  if code ~= 0 then
    return nil
  end
  return vim.trim(out)
end

local function pinned_tree_ok(commit, branch)
  if lazy_head() ~= commit or lazy_branch() ~= branch or not vim.loop.fs_stat(lazy_entry) then
    return false
  end
  local status, code = git_cmd({ "-C", lazypath, "status", "--porcelain" })
  return code == 0 and vim.trim(status) == ""
end

local function ensure_pinned_lazy(commit, branch)
  local created = false
  if not vim.loop.fs_stat(lazypath .. "/.git") then
    if vim.loop.fs_stat(lazypath) then
      return false, "lazy.nvim のパスが git リポジトリではありません: " .. lazypath
    end
    created = true
    vim.fn.mkdir(vim.fn.fnamemodify(lazypath, ":h"), "p")
    local ok, out = git_ok({ "init", lazypath })
    if not ok then
      vim.fn.delete(lazypath, "rf")
      return false, out
    end
  end

  local function fail(out)
    if created then
      vim.fn.delete(lazypath, "rf")
    end
    return false, out
  end

  local ok, out = pin_origin()
  if not ok then
    return fail(out)
  end
  ok, out = git_ok({ "-C", lazypath, "fetch", "--depth", "1", "--filter=blob:none", "origin", commit })
  if not ok then
    return fail(out)
  end
  -- detached HEAD だとこの版の lazy.nvim が lockfile 更新時に落ちる
  ok, out = git_ok({ "-C", lazypath, "checkout", "-B", branch, commit })
  if not ok then
    return fail(out)
  end
  ok, out = git_ok({ "-C", lazypath, "reset", "--hard", commit })
  if not ok then
    return fail(out)
  end
  ok, out = git_ok({ "-C", lazypath, "clean", "-fd" })
  if not ok then
    return fail(out)
  end
  ok, out = git_ok({ "-C", lazypath, "update-ref", "refs/remotes/origin/" .. branch, commit })
  if not ok then
    return fail(out)
  end
  ok, out = git_ok({
    "-C", lazypath, "symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/" .. branch,
  })
  if not ok then
    return fail(out)
  end
  if not pinned_tree_ok(commit, branch) then
    return fail("取得した lazy.nvim が固定 commit と一致しません")
  end
  return true, ""
end

apply_safe_editor_opts()

local lazy_commit, lazy_branch = pinned_lazy_spec()
local lazy_ready = false
if not lazy_commit then
  vim.api.nvim_echo({
    { "lazy-lock.json の lazy.nvim に有効な commit / branch が無いため、プラグインマネージャは読み込みません。\n", "ErrorMsg" },
  }, true, {})
elseif pinned_tree_ok(lazy_commit, lazy_branch) then
  local ok, out = pin_origin()
  if ok then
    lazy_ready = true
  else
    vim.api.nvim_echo({
      { "lazy.nvim の origin を HTTPS に固定できませんでした:\n", "ErrorMsg" },
      { out or "", "WarningMsg" },
      { "\n", "WarningMsg" },
    }, true, {})
  end
else
  local ok, out = ensure_pinned_lazy(lazy_commit, lazy_branch)
  if ok then
    lazy_ready = true
  else
    vim.api.nvim_echo({
      { "lazy.nvim を固定 commit で取得できませんでした:\n", "ErrorMsg" },
      { out or "", "WarningMsg" },
      { "\n", "WarningMsg" },
    }, true, {})
  end
end

if lazy_ready then
  vim.opt.rtp:prepend(lazypath)
  --lazyを用いたプラグインインストールの開始
  require("lazy").setup({
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
		"nvim-tree/nvim-tree.lua",
		dependencies = {"nvim-tree/nvim-web-devicons"},
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
	-- 巨大なファイルを開くときに機能を制限する
	{
		"LunarVim/bigfile.nvim",
		config = function()
			require("bigfile").setup {
				filesize = 2,
			}
		end,
	},
	-- coc.nvimの導入
	{
		"neoclide/coc.nvim",
		branch = "release",
		config = function()
		end,	
	},
}, {
    git = {
      url_format = "https://github.com/%s.git",
    },
  })
  apply_safe_editor_opts()
end
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

