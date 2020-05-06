require "json"
require "mime"
require "digest"
require "colorize"
require "file_utils"
require "http/client"

require "../engine"

class VpBook
  include JSON::Serializable

  property slug = ""

  property title = ""
  property author = ""

  property intro = ""
  property cover = ""

  property genre = ""
  property tags = [] of String

  # property state = 0
  # property mtime = 0_i64

  # property hidden = 0

  # property votes = 0
  # property score = 0_f64
  # property tally = 0_f64
  # property mtime = 0_i64

  # property word_count = 0
  # property review_count = 0

  # property yousuu_bids = [] of Int32
  # property source_urls = [] of String

  property scrap_sites = {} of String => VSite
  property prefer_site = ""
  property prefer_bsid = ""

  DIR = "src/entity/data"

  def initialize
  end

  def initialize(other : YBook, book : String? = nil, user : String = "local")
    set_title(other.title)
    set_author(other.author)
    set_label()

    set_genre(other.genre)
    set_tags(other.tags)
    set_intro(other.intro, book, user)
    other.covers.each { |cover| set_cover(cover) }

    @status = other.status
    @hidden = other.hidden

    @votes = other.votes
    @score = other.score
    @tally = other.tally
    @mtime = other.mtime

    @word_count = other.word_count.round.to_i
    @review_count = other.review_count

    @yousuu_bids = other.yousuu_bids
    @source_urls = other.source_urls
  end

  def initialize(other : SBook, @hidden : Int32, @votes = 0, @score = 0.0, @word_count = 0, book : String? = nil, user = "local")
    set_title(other.title)
    set_author(other.author)
    set_label()
    absorb(other, book, user)
    @tally = (@votes * @score * 2).round / 2
  end

  def to_s(io : IO)
    io << to_pretty_json
  end

  def absorb(other : SBook, book : String? = nil, user : String = "local")
    changed = false

    if @genre.zh.empty? && !other.genre.empty?
      set_genre(other.genre)
      changed = true
    end

    unless other.tags.empty?
      old_size = @tags.size
      set_tags(other.tags)
      changed = true if @tags.size > old_size
    end

    if @intro_zh.empty? && !other.intro.empty?
      set_intro(other.intro, book, user)
      changed = true
    end

    unless other.cover.empty?
      old_file = @cover_file
      set_cover(other.cover)
      changed = true if old_file != @cover_file
    end

    if other.status > @status
      @status = other.status
      changed = true
    end

    if other.mtime > @mtime
      @mtime = other.mtime
      changed = true
    end

    if @prefer_site.empty?
      @prefer_site = other.site
      @prefer_bsid = other.bsid
      changed = true
    end

    if site = @scrap_sites[other.site]?
      if other.mtime > site.mtime
        site.mtime = other.mtime
        changed = true
      end

      if other.chaps > site.chaps
        site.chaps = other.chaps
        changed = true
      end
    else
      @scrap_sites[other.site] = VSite.new(other)
    end

    changed
  end

  def save!(dir : String = "data/txt-out/serials", name : String = @label.us) : Void
    file = "#{dir}/#{name}.json"
    puts "- saved book <#{file.colorize(:green)}>"
    File.write(file, to_json)
  end

  TITLES = Hash(String, Array(String)).from_json(File.read("#{DIR}/map-titles.json"))

  def set_label
    label_zh = "#{@title.zh}--#{@author.zh}"
    label_hv = "#{@title.hv}--#{@author.hv}"
    label_vi = "#{@title.vi}--#{@author.vi}"
    label_us = "#{@title.us}--#{@author.us}"
    @label.update(label_zh, label_vi, label_hv, label_us)
  end

  def set_title(title_zh : String, title_vi : String? = nil) : Void
    title_hv = Engine.hanviet(title_zh, apply_cap: true).vi_text
    unless title_vi
      if titles = TITLES[title_zh]?
        title_vi = titles.first
      else
        title_vi = title_hv
      end
    end

    @title.update(title_zh, title_vi, title_hv)
  end

  def set_author(author_zh : String, author_vi : String? = nil) : Void
    author_hv = CUtil.titlecase(Engine.hanviet(author_zh).vi_text)
    author_vi ||= author_hv
    @author.update(author_zh, author_vi, author_hv)
  end

  COVER_TMP = "data/txt-tmp/covers"
  COVER_OUT = "data/txt-out/covers"

  def set_cover(cover) : Void
    @cover_urls << cover
    @cover_urls.uniq!

    img_name = VBook.fetch_file(cover)
    return if img_name.empty?

    img_file = File.join(COVER_TMP, img_name)
    return if File.size(img_file) == 0

    new_file = File.join(COVER_OUT, img_name)
    old_file = File.join(COVER_OUT, @cover_file)

    if @cover_file == "blank.png" || File.size(old_file) < File.size(img_file)
      @cover_file = img_name
      FileUtils.cp(img_file, new_file)
    end
  end

  TLS = OpenSSL::SSL::Context::Client.insecure

  def self.fetch_file(url)
    name = Digest::SHA1.hexdigest(url)[0..10]

    files = Dir.glob("#{COVER_TMP}/#{name}.*").reject { |f| File.size(f) == 0 }
    return File.basename(files.first) unless files.empty?

    uri = URI.parse(url)
    tls = url.starts_with?("https") ? TLS : false # TODO: check by uri?

    return "" unless uri.host && uri.full_path

    client = HTTP::Client.new(uri.host.not_nil!, tls: tls)
    client.dns_timeout = 5
    client.read_timeout = 5
    client.connect_timeout = 5

    begin
      res = client.get(uri.full_path.not_nil!)

      exts = MIME.extensions(res.mime_type.to_s)
      ext = exts.empty? ? ".jpg" : exts.first

      file = "#{name}#{ext}"

      File.write(File.join(COVER_TMP, file), res.body_io)
      return file
    rescue err
      puts "Error downloading <#{url}>: #{err.colorize(:red)}"

      inp_file = File.join(COVER_OUT, "blank.png")
      out_file = File.join(COVER_TMP, "#{name}.png")
      FileUtils.cp(inp_file, out_file)

      return "#{name}.png"
    end
  end

  def set_intro(intro : String, book : String? = nil, user = "local", replace = false) : Void
    return unless replace || @intro_zh.empty?

    lines = intro
      .gsub("&lt;", "<")
      .gsub("&gt;", ">")
      .gsub(/<br\s*\/*>/, "\n")
      .gsub("&nbsp;", " ")
      .tr("　 ", " ")
      .split(/\r|\n|\s{2,}/)
      .map(&.strip)
      .reject(&.empty?)

    @intro_zh = lines.join("\n")
    @intro_vi = Engine.convert(lines, :plain, book, user).map(&.vi_text).join("\n")
  end

  GENRES = Hash(String, Tuple(String, Bool)).from_json(File.read("#{DIR}/map-genres.json"))

  def set_genre(genre_zh : String, genre_vi : String? = nil, replace : Bool = false) : Void
    if replace || @genre.zh.empty?
      genre_hv = Engine.hanviet(genre_zh).vi_text
      genre_vi, move_to_tag = GENRES.fetch(genre_zh, {"Loại khác", false})
      @genre.update(genre_zh, genre_vi, genre_hv)
      set_tags(genre_zh) if move_to_tag
    else
      set_tags(genre_zh)
    end
  end

  def set_tags(tags : String) : Void
    set_tags(tags.split("-"))
  end

  def set_tags(tags : Array(String)) : Void
    tags.each do |tag_zh|
      next if tag_zh == @genre.zh
      next if tag_zh == @title.zh
      next if tag_zh == @author.zh
      next if @tags.index(&.zh.==(tag_zh))

      tag_vi = Engine.hanviet(tag_zh).vi_text
      @tags << VTran.new(tag_zh, tag_vi, tag_vi)
    end
  end

  @@dir = "data/txt-out"

  def self.dir
    @@dir
  end

  def self.chdir(dir : String)
    @@dir = dir
  end

  def self.file_path(slug : String)
    "#{@@dir}/serials/#{slug}.json"
  end

  def self.index_path(name : String)
    "#{@@dir}/indexes/#{name}.json"
  end

  def self.load(file : String, label : String = "1/1")
    puts "- <#{label.colorize(:blue)}> loading vbook #{file.colorize(:blue)}"

    file = file_path(file) unless file.ends_with?(".json")
    from_json(File.read(file))
  end

  @@cache = {} of String => VBook

  def self.get(name : String)
    @@cache[name] ||= load(name)
  end

  def all
    @@cache
  end

  alias Index = Array(Tuple(String, Int64 | Float64))

  def self.load_index(name, klass = Index)
    puts "- loading index <#{name.colorize(:blue)}>"
    klass.from_json(File.read(index_path(name)))
  end

  @@sorts = {} of String => Index

  def self.sort_by(sort : String = "update")
    @@sorts[sort] ||= load_index(sort, Index)
  end

  def self.list(limit = 20, offset = 0, sort = "update")
    items = sort_by(sort)
    output = [] of VBook

    items.reverse_each do |slug, _|
      if offset > 0
        offset -= 1
      else
        output << get(slug).not_nil!
        break unless output.size < limit
      end
    end

    output
  end

  def self.total(sort)
    sort_by(sort).size
  end

  class Query
    include JSON::Serializable

    property title : Array(String)
    property author : Array(String)
  end

  @@query = {} of String => Query

  def self.glob(query : String)
    @@query = load_index("query", Hash(String, Query)) if @@query.empty?

    output = [] of VBook

    @@query.each do |slug, data|
      if data.title.find(&.includes?(query)) || data.author.find(&.includes?(query))
        output << get(slug).not_nil!
        break if output.size >= 20
      end
    end

    output
  end

  SORTS = {"access", "update", "score", "votes", "tally"}

  def self.save(book : VBook)
    book.save!
    SORTS.each { |name| update_index(name, book) }
    @books[book.label.us] = book
  end

  def self.update_index(name, book : VpBook)
    changed = false

    sort = sort_by(name)
    slug = book.label.us

    case name
    when "tally"
      value = book.tally
    when "score"
      value = book.score
    when "votes"
      value = book.votes
    when "update"
      value = book.mtime
    else
      value = Time.utc.to_unix_ms
    end

    if index = sort.index(&.[0].==(slug))
      return if sort[index][1] == value
      sort[index] = {slug, value}
    else
      sort << {slug, value}
    end

    sort.sort_by!(&.[1])
    File.write(index_path(name), sort.to_json)
  end
end

# puts VBook.list(3, sort: "update")
# puts VBook.list(3, sort: "tally")