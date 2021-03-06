require "json"
require "./shared/*"

puts "\n[Load counters]".colorize.cyan.bold

alias Counter = Hash(String, Int32)

def read_counter(file : String)
  Counter.from_json(File.read(QtUtil.path(file)))
end

COUNT_WORDS = read_counter(".count/count-words.json")
COUNT_BOOKS = read_counter(".count/count-books.json")

puts "\n[Load history]".colorize.cyan.bold

CHECKED = ValueSet.load(".temps/checked.tsv", false)
EXISTED = ValueSet.load(".temps/existed.tsv", false)
LEXICON = ValueSet.load(".temps/lexicon.tsv", true)

Dir.glob(QtUtil.path("localqt/logs/*.log")) do |file|
  puts "- load file: [#{file.colorize(:blue)}]"

  File.each_line(file) do |line|
    key = line.split("\t", 2).first

    CHECKED.add(key)
    EXISTED.add(key)
  end
end

inp_regular = QtDict.load(".temps/regular.txt", false)
inp_suggest = QtDict.load(".temps/suggest.txt", false)
inp_various = QtDict.load(".temps/various.txt", false)
inp_recycle = QtDict.load(".temps/recycle.txt", false)

puts "\n[Load localqt]".colorize.cyan

INPUT = QtDict.load(".temps/localqt.txt", false)

{
  "qtrans/localqt/names2.txt",
  "qtrans/localqt/names1.txt",
  "qtrans/localqt/vietphrase.txt",
}.each do |file|
  QtDict.load(file).each do |key, vals|
    EXISTED << key
    INPUT.set(key, vals, :old_first)
  end
end

# replace localqt with manually checked
Dir.glob(QtUtil.path("localqt/fixes/*.txt")) do |file|
  QtDict.new(file).each do |key, vals|
    CHECKED.add(key)
    EXISTED.add(key)

    INPUT.set(key, vals, :keep_new)
  end
end

puts "- localqt: #{INPUT.size} entries.".colorize.blue

puts "\n[Parse localqt]".colorize.cyan.bold

INPUT.each do |key, vals|
  vals = vals.reject(&.includes?("*"))
  next if vals.empty?
  categorize(key, vals.first)

  book_count = COUNT_BOOKS[key]? || 0
  word_count = COUNT_WORDS[key]? || 0

  checked = CHECKED.includes?(key)
  ondicts = LEXICON.includes?(key)

  words, names = vals.uniq.partition { |x| x == x.downcase }
  words = words.first(4)
  names = names.first(4)

  unless words.empty?
    if (ondicts || book_count >= 40) && (checked || word_count >= 200)
      inp_regular.set(key, words)
    elsif checked || ondicts || book_count >= 20 || word_count >= 100
      inp_suggest.set(key, words)
    elsif word_count >= 20
      inp_recycle.set(key, words)
    end
  end

  unless names.empty?
    if (ondicts || book_count >= 40) && (checked || word_count >= 200)
      inp_regular.set(key, names, :new_first)
    elsif checked || ondicts || book_count >= 20 || word_count >= 100
      inp_suggest.set(key, names, :new_first)
    elsif word_count >= 20
      inp_recycle.set(key, names, :new_first)
    end

    next unless words.empty? && key !~ /^\P{Han}/
    next unless inp_regular.has_key?(key)

    next unless checked && word_count >= 200 && key.size > 1
    inp_various.set(key, names, :new_first)
  end
end

puts "\n[Load persist]".colorize.cyan

Dir.glob(QtUtil.path("qtrans/fixture/*.txt")).each do |file|
  QtDict.new(file).tap(&.load!).each do |key, vals|
    CHECKED.add(key)
    EXISTED.add(key)

    if COUNT_WORDS.fetch(key, 0) >= 100
      inp_regular.set(key, vals, :new_first)
    else
      inp_suggest.set(key, vals, :new_first)
    end
  end
end

Dir.glob(QtUtil.path("qtrans/fixture/pop-fictions/*.txt")).each do |file|
  QtDict.new(file).tap(&.load!).each do |key, vals|
    CHECKED.add(key)
    EXISTED.add(key)

    if COUNT_BOOKS.fetch(key, 0) >= 20
      inp_regular.set(key, vals, :old_first)
    else
      inp_suggest.set(key, vals, :old_first)
    end
  end
end

puts "\n[Load suggest]".colorize.cyan

Dir.glob(QtUtil.path("qtrans/manmade/other-names/*.txt")).each do |file|
  QtDict.new(file).tap(&.load!).each do |key, vals|
    CHECKED.add(key)
    EXISTED.add(key)

    inp_suggest.set(key, vals, :old_first)
  end
end

# # extra

puts "\n[Load outerqt]".colorize.cyan.bold

QtDict.load("qtrans/outerqt/lowercase.txt").each do |key, vals|
  vals = vals.reject(&.includes?("*"))
  next if vals.empty?
  # categorize(key, vals.first)

  next if EXISTED.includes?(key)

  book_count = COUNT_BOOKS[key]? || 0
  word_count = COUNT_WORDS[key]? || 0

  ondicts = LEXICON.includes?(key)

  if ondicts && book_count >= 40 && word_count >= 400
    inp_regular.set(key, vals, :old_first)
  elsif (ondicts || key.size != 2) && (book_count >= 40 || word_count >= 400)
    inp_suggest.set(key, vals, :old_first)
  elsif word_count >= 100
    inp_recycle.set(key, vals, :old_first)
  end
end

QtDict.load("qtrans/outerqt/uppercase.txt").each do |key, vals|
  vals = vals.reject(&.includes?("*"))
  next if vals.empty?
  # categorize(key, vals.first)

  next if EXISTED.includes?(key)

  book_count = COUNT_BOOKS[key]? || 0
  word_count = COUNT_WORDS[key]? || 0

  ondicts = LEXICON.includes?(key)

  if (ondicts || key.size > 2) && book_count >= 40 && word_count >= 400
    inp_regular.set(key, vals, :old_first)
  elsif (ondicts || key.size > 2) && (book_count >= 20 || word_count >= 200)
    inp_suggest.set(key, vals, :old_first)
  elsif word_count >= 100
    inp_recycle.set(key, vals, :old_first)
  end
end

puts "\n[Save temps]"

inp_regular.save!
inp_suggest.save!
inp_various.save!
inp_recycle.save!

CHECKED.save!
EXISTED.save!
