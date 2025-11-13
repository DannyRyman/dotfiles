return {
  {
    "vim-test/vim-test",
    cmd = { "TestNearest", "TestFile", "TestSuite", "TestLast", "TestVisit" },
    config = function()
      vim.g["test#strategy"] = "neovim"
      vim.g["test#neovim#term_position"] = "botright"
      vim.g["test#java#runner"] = "gradletest"
      vim.g["test#kotlin#runner"] = "gradletest"
    end,
  },
}
