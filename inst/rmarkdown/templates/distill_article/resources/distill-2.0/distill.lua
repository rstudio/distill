
function CodeBlock(block)
  if string.byte(block.text, 1) ~= 10 then
    block.text = '\n' .. block.text
  end
  return block
end
