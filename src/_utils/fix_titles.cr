module Utils
  # fixes chapter titles

  NUMS = "零〇一二两三四五六七八九十百千"
  LBLS = "章节幕回折"
  SEPS = ".，,、：:"

  SPLIT_RE_0 = /^(第[#{NUMS}\d]+[集卷].*?)(第?[#{NUMS}\d]+[#{LBLS}].*)$/
  SPLIT_RE_1 = /^(第[#{NUMS}\d]+[集卷].*?)(（\p{N}+）.*)$/
  SPLIT_RE_2 = /^【(第[#{NUMS}\d]+[集卷])】(.+)$/

  def self.split_label(title : String)
    label = "正文"

    if match = SPLIT_RE_0.match(title) || SPLIT_RE_1.match(title) || SPLIT_RE_2.match(title)
      _, label, title = match
      label = clean_spaces(label)
    end

    {format_title(title), label}
  end

  TITLE_RE_0 = /^第?([#{NUMS}\d]+)([#{LBLS}])[#{SEPS}\s]*(.*)$/
  TITLE_RE_1 = /^([#{NUMS}\d]+)[#{SEPS}\s]*(.*)$/
  TITLE_RE_2 = /^（(\p{N}+)）[#{SEPS}\s]*(.*)$/
  TITLE_RE_3 = /^(\d+)\.\s*第.+[#{LBLS}][#{SEPS}\s]*(.+)/ # 69shu

  def self.format_title(title : String)
    if match = TITLE_RE_0.match(title)
      _, idx, tag, title = match
      return "第#{idx}#{tag} #{clean_spaces(title)}"
    end

    if match = TITLE_RE_1.match(title) || TITLE_RE_2.match(title) || TITLE_RE_3.match(title)
      _, idx, title = match
      return "#{idx}. #{clean_spaces(title)}"
    end

    return clean_spaces(title)
  end

  def self.clean_spaces(title : String)
    title.gsub(/\p{Z}+/, " ").strip
  end
end