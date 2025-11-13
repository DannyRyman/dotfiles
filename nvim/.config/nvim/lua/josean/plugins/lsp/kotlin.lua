local function detect_java_21_home()
  local java_home_output = vim.fn.system({ "/usr/libexec/java_home", "-v", "21" })
  if vim.v.shell_error == 0 then
    local resolved = vim.fn.trim(java_home_output)
    if resolved ~= "" then
      return resolved
    end
  end

  if vim.env.JAVA_HOME and vim.env.JAVA_HOME ~= "" then
    return vim.env.JAVA_HOME
  end
end

return {
  {
    "neovim/nvim-lspconfig",
    config = function()
      local java_home = detect_java_21_home()
      if not java_home then
        vim.notify(
          "[kotlin] Unable to find a Java 21 runtime; falling back to system java",
          vim.log.levels.WARN
        )
        return
      end

      vim.g._kotlin_java_home = java_home
      vim.notify(string.format("[kotlin] Using JAVA_HOME=%s", java_home), vim.log.levels.INFO, {
        title = "kotlin-language-server",
      })

      vim.lsp.config("kotlin_language_server", {
        cmd_env = {
          JAVA_HOME = java_home,
          PATH = java_home .. "/bin:" .. (vim.env.PATH or ""),
        },
        settings = {
          kotlin = {
            compiler = {
              jvm = {
                target = "21",
              },
            },
          },
        },
      })
    end,
  },
}
