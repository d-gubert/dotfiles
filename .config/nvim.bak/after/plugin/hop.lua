local ok, hop = pcall(require, 'hop')

if not ok then
  return
end

hop.setup()

-- vim.keymap.set('n', '<leader>jw', function() hop.hint_words() end, { desc = 'Hop to word' })
-- vim.keymap.set('n', '<leader>jc', function() hop.hint_char1() end, { desc = 'Hop to character' })
vim.keymap.set('n', 's', function() hop.hint_char2() end, { desc = 'Hop to character sequence' })

