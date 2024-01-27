local ok, hop = pcall(require, 'hop')

if not ok then
  return
end

vim.keymap.set('n', '<leader>jw', function() hop.hint_words() end, { desc = 'Hop to word' })
vim.keymap.set('n', '<leader>jc', function() hop.hint_char1() end, { desc = 'Hop to character' })
