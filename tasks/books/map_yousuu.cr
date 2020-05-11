require "json"
require "colorize"
require "file_utils"

require "./models/yousuu_info"
require "../../src/models/book_info"

sitemap = [] of String
inputs = {} of String => YousuuInfo

INP_DIR = File.join("data", ".inits", "txt-inp", "yousuu", "infos")
Dir.glob(File.join(INP_DIR, "*.json")).each do |file|
  text = File.read(file)
  next unless text.includes?("{\"success\":true")

  json = NamedTuple(data: JsonData).from_json(text)
  info = json[:data][:bookInfo]

  info.fix_title!
  info.fix_author!

  uuid = BookInfo.uuid_for(info.title, info.author)
  sitemap << {info._id, uuid, info.title, info.author}.join("--")

  next if info.title.empty? || info.author.empty?
  next unless info.scorerCount > 0 || info.commentCount > 0

  if old_info = inputs[uuid]?
    next if old_info.updateAt >= info.updateAt
  end

  info.fix_cover!
  info.fix_tags!

  info.sources = json[:data][:bookSource]

  inputs[uuid] = info
rescue err
  File.delete(file)
  puts "#{file} err: #{err}".colorize(:red)
end

File.write(File.join("data", "sitemaps", "yousuu.txt"), sitemap.join("\n"))

FileUtils.mkdir_p(BookInfo::DIR)

infos = BookInfo.load_all
fresh = 0

inputs.each do |uuid, input|
  unless info = infos[uuid]?
    fresh += 1
    info = BookInfo.new(input.title, input.author, uuid)
  end

  info.zh_intro = input.intro
  info.zh_genre = input.genre

  info.add_tags(input.tags)
  info.add_cover(input.cover)

  info.votes = input.scorerCount
  info.score = (input.score * 10).round / 10
  info.reset_tally

  info.shield = input.shielded ? 2 : 0
  info.set_status(input.status)
  info.set_mftime(input.updateAt.to_unix)

  info.yousuu = input._id.to_s
  if source = input.sources.first?
    info.origin = source.link
  end

  info.word_count = input.countWord.round.to_i
  info.crit_count = input.commentCount

  BookInfo.save!(info)
end

puts "- existed: #{infos.size.colorize(:blue)}, fresh: #{fresh.colorize(:blue)}"
