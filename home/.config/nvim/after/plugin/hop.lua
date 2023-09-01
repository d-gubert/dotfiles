local hop = require('hop')

vim.keymap.set('n', '<leader>jw', function() hop.hint_words() end, { desc = 'Hop to word' })
vim.keymap.set('n', '<leader>jc', function() hop.hint_char1() end, { desc = 'Hop to word' })
