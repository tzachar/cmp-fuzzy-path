return function(entry1, entry2)
  if entry1.source.name == 'fuzzy_path' and entry2.source.name == 'fuzzy_path' then
    if entry1.completion_item.data.score == entry2.completion_item.data.score then
      return (#entry1.completion_item.data.path < #entry2.completion_item.data.path)
    else
      return (entry1.completion_item.data.score > entry2.completion_item.data.score)
    end
  else
    return nil
  end
end
