return function(entry1, entry2)
  if entry1.source.name == 'fuzzy_path' and entry2.source.name == 'fuzzy_path' then
    return (entry1.completion_item.data.score > entry2.completion_item.data.score)
  else
    return nil
  end
end
