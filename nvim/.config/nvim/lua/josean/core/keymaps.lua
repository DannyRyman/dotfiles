vim.g.mapleader = " "

local keymap = vim.keymap -- for conciseness

keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode with jk" })

keymap.set("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })

-- increment/decrement numbers
keymap.set("n", "<leader>+", "<C-a>", { desc = "Increment number" }) -- increment
keymap.set("n", "<leader>-", "<C-x>", { desc = "Decrement number" }) -- decrement

-- window management
keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" }) -- split window vertically
keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" }) -- split window horizontally
keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" }) -- make split windows equal width & height
keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" }) -- close current split window

keymap.set("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "Open new tab" }) -- open new tab
keymap.set("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab" }) -- close current tab
keymap.set("n", "<leader>tn", "<cmd>tabn<CR>", { desc = "Go to next tab" }) --  go to next tab
keymap.set("n", "<leader>tp", "<cmd>tabp<CR>", { desc = "Go to previous tab" }) --  go to previous tab
keymap.set("n", "<leader>tf", "<cmd>tabnew %<CR>", { desc = "Open current buffer in new tab" }) --  move current buffer to new tab

-- saving buffer
vim.keymap.set("n", "<C-s>", ":wa<CR>", { desc = "Save all buffers" })

local gradle_root_markers = {
  "build.gradle.kts",
  "build.gradle",
  "settings.gradle.kts",
  "settings.gradle",
  "gradlew",
  "gradlew.bat",
}

local gradle_build_files = {
  "build.gradle.kts",
  "build.gradle",
}

local function find_gradle_root(bufnr)
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  local directory = (filepath ~= "" and vim.fs.dirname(filepath)) or vim.loop.cwd()

  if not directory or directory == "" then
    return nil
  end

  local marker = vim.fs.find(gradle_root_markers, {
    upward = true,
    stop = vim.loop.os_homedir(),
    path = directory,
  })[1]

  if not marker then
    return nil
  end

  local marker_dir = vim.fs.dirname(marker)

  if vim.fn.isdirectory(marker) == 1 then
    return marker
  end

  return marker_dir
end

local function find_gradle_module_dir(filepath, root)
  if not filepath or filepath == "" then
    return root
  end

  local directory = vim.fs.dirname(filepath)

  while directory and directory ~= "" do
    if root and directory == root then
      return root
    end

    for _, build_file in ipairs(gradle_build_files) do
      local candidate = vim.fs.joinpath(directory, build_file)
      if vim.loop.fs_stat(candidate) then
        return directory
      end
    end

    local parent = vim.fs.dirname(directory)
    if not parent or parent == directory then
      break
    end
    directory = parent
  end

  return root
end

local gradle_keymap_group = vim.api.nvim_create_augroup("GradleProjectKeymaps", { clear = true })

local gradle_errorformat = table.concat({
  [[%E\|\|\ e:\ file:///%f:%l:%c\ %m]],
  [[%W\|\|\ w:\ file:///%f:%l:%c\ %m]],
  [[%Ee:\ file:///%f:%l:%c\ %m]],
  [[%Ww:\ file:///%f:%l:%c\ %m]],
  [[%Efile:///%f:%l:%c\ %m]],
  [[%Wfile:///%f:%l:%c\ %m]],
  [[%E%f:%l:%c:\ error:\ %m]],
  [[%W%f:%l:%c:\ warning:\ %m]],
  [[%E%f:%l:\ error:\ %m]],
  [[%W%f:%l:\ warning:\ %m]],
}, ",")

local file_search_cache = {}

local function strip_gradle_prefix(line)
  local cleaned = (line or ""):gsub("^%s*||%s*", "")
  cleaned = cleaned:gsub("^%s*>+%s*", "")
  return cleaned
end

local function is_absolute_path(path)
  if not path then
    return false
  end
  return path:match("^/") or path:match("^%a:[/\\]")
end

local function resolve_project_file(root, path)
  if not path or path == "" then
    return nil
  end

  if is_absolute_path(path) then
    return path
  end

  local key = string.format("%s::%s", root or "", path)
  if file_search_cache[key] ~= nil then
    return file_search_cache[key]
  end

  local candidates = { path }
  local basename = path:match("([^/\\]+%.%a+)$")
  if basename and basename ~= path then
    table.insert(candidates, basename)
  end

  local resolved
  for _, name in ipairs(candidates) do
    local matches = vim.fs.find(name, {
      path = root or vim.loop.cwd(),
      upward = false,
      limit = 1,
      type = "file",
    })
    if matches and matches[1] then
      resolved = matches[1]
      break
    end
  end

  file_search_cache[key] = resolved
  return resolved
end

local function convert_gradle_line(line, root)
  local cleaned = strip_gradle_prefix(line)
  if cleaned == "" then
    return nil
  end

  local file_uri, lnum, col, msg = cleaned:match("(file:///%S+):(%d+):(%d+)%s*(.*)")
  if file_uri then
    local ok, fname = pcall(vim.uri_to_fname, file_uri)
    if ok and fname and fname ~= "" then
      return string.format("%s:%s:%s %s", fname, lnum, col, msg)
    end
  end

  local path_col, lnum_col, col_col, msg_col = cleaned:match("([%w%._%-%/%\\:]+%.%a+):(%d+):(%d+)%s*(.*)")
  if path_col then
    local resolved = resolve_project_file(root, path_col)
    if resolved then
      return string.format("%s:%s:%s %s", resolved, lnum_col, col_col, msg_col)
    end
  end

  local path_simple, lnum_simple, msg_simple = cleaned:match("([%w%._%-%/%\\:]+%.%a+):(%d+)%s*(.*)")
  if path_simple then
    local resolved = resolve_project_file(root, path_simple)
    if resolved then
      return string.format("%s:%s:0 %s", resolved, lnum_simple, msg_simple)
    end
  end

  local fname_in_parens, lnum_in_parens = cleaned:match("%(([%w%._%-%/%\\:]+%.%a+):(%d+)%)")
  if fname_in_parens then
    local resolved = resolve_project_file(root, fname_in_parens)
    if resolved then
      return string.format("%s:%s:0 %s", resolved, lnum_in_parens, cleaned)
    end
  end

  return nil
end

local function append_to_qf(lines, title, root)
  if not lines then
    return
  end

  local qf_ready = {}
  for _, line in ipairs(lines) do
    local converted = convert_gradle_line(line, root)
    if converted then
      table.insert(qf_ready, converted)
    end
  end

  if #qf_ready == 0 then
    return
  end

  vim.fn.setqflist({}, "a", {
    title = title,
    lines = qf_ready,
    efm = gradle_errorformat,
  })
end

local function run_gradle(root, args_list, description)
  vim.notify("Running " .. table.concat(args_list, " ") .. "…", vim.log.levels.INFO, { title = "Gradle" })
  vim.fn.setqflist({}, "r")

  vim.fn.jobstart(args_list, {
    cwd = root,
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      append_to_qf(data, description, root)
    end,
    on_stderr = function(_, data)
      append_to_qf(data, description, root)
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        local level = code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
        local msg = description .. (code == 0 and " completed" or (" failed (exit " .. code .. ")"))
        vim.notify(msg, level, { title = "Gradle" })

        if code == 0 then
          if #vim.fn.getqflist() > 0 then
            vim.cmd("cclose")
          end
        else
          vim.cmd("copen")
        end
      end)
    end,
  })
end

local function run_vim_test(command, description)
  local ok, err = pcall(vim.cmd, command)
  if not ok then
    vim.notify(("Failed to run %s: %s"):format(description or command, err), vim.log.levels.ERROR, { title = "Gradle" })
  end
end

local function extract_kotlin_package(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, math.min(200, vim.api.nvim_buf_line_count(bufnr)), false)
  for _, line in ipairs(lines) do
    local package_name = line:match("^%s*package%s+([%w%._]+)")
    if package_name then
      return package_name
    end
  end
end

local function build_kotlin_test_filter(bufnr)
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if filepath == "" then
    return nil
  end

  local class_name = vim.fn.fnamemodify(filepath, ":t:r")
  if class_name == "" then
    return nil
  end

  local package_name = extract_kotlin_package(bufnr)
  local identifier = package_name and (package_name .. "." .. class_name) or class_name

  -- append wildcard to capture nested classes / parameterized names
  return identifier .. "*"
end

local function ensure_gradle_keymaps(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local root = find_gradle_root(bufnr)
  if not root then
    return
  end

  local has_mapping = pcall(vim.api.nvim_buf_get_var, bufnr, "gradle_build_keymap_set")
  if has_mapping then
    return
  end

  vim.api.nvim_buf_set_var(bufnr, "gradle_build_keymap_set", true)

  vim.keymap.set("n", "<leader>gb", function()
    run_gradle(root, { "./gradlew", "build", "--console=plain" }, "./gradlew build --console=plain")
  end, { buffer = bufnr, desc = "Gradle build" })

  vim.keymap.set("n", "<leader>gc", function()
    run_gradle(
      root,
      { "./gradlew", "build", "-x", "test", "--console=plain" },
      "./gradlew build -x test --console=plain"
    )
  end, { buffer = bufnr, desc = "Gradle compile only" })

  vim.keymap.set("n", "<leader>gt", function()
    run_vim_test("TestNearest", "TestNearest")
  end, { buffer = bufnr, desc = "Gradle test nearest" })

  vim.keymap.set("n", "<leader>gT", function()
    local filter = build_kotlin_test_filter(bufnr)
    if not filter then
      vim.notify("Unable to determine test class for buffer", vim.log.levels.WARN, { title = "Gradle" })
      return
    end

    local module_dir = find_gradle_module_dir(vim.api.nvim_buf_get_name(bufnr), root)
    local args = { "./gradlew" }
    if module_dir and module_dir ~= root then
      table.insert(args, "-p")
      table.insert(args, module_dir)
    end
    vim.list_extend(args, { "test", "--tests", filter, "--console=plain" })

    run_gradle(
      root,
      args,
      string.format("./gradlew%s test --tests %s", module_dir and (" -p " .. module_dir) or "", filter)
    )
  end, { buffer = bufnr, desc = "Gradle test file" })

  vim.keymap.set("n", "<leader>gA", function()
    run_vim_test("TestSuite", "TestSuite")
  end, { buffer = bufnr, desc = "Gradle test suite" })
end

vim.api.nvim_create_autocmd({ "BufEnter", "BufReadPost", "BufNewFile" }, {
  group = gradle_keymap_group,
  callback = function(args)
    ensure_gradle_keymaps(args.buf)
  end,
})

vim.api.nvim_create_autocmd("VimEnter", {
  group = gradle_keymap_group,
  callback = function()
    ensure_gradle_keymaps(vim.api.nvim_get_current_buf())
  end,
})

vim.api.nvim_create_autocmd("DirChanged", {
  group = gradle_keymap_group,
  callback = function()
    ensure_gradle_keymaps(vim.api.nvim_get_current_buf())
  end,
})

ensure_gradle_keymaps(vim.api.nvim_get_current_buf())
