require "file_utils"
require "compress/zip"

require "../../mtlv2/mt_core"
require "../../seeds/rm_text"
require "../../cutil/ram_cache"

class CV::ChText
  CACHED = RamCache(self).new(512)

  def self.load(bname : String, sname : String, snvid : String,
                chidx : Int32, schid : String)
    CACHED.get("#{sname}/#{snvid}/#{schid}") do
      new(bname, sname, snvid, chidx, schid)
    end
  end

  @zh_text : Array(String)? = nil
  @cv_data : String?
  @cv_time : Time

  def initialize(@bname : String, @sname : String, @snvid : String,
                 @chidx : Int32, @schid : String)
    @text_dir = "_db/chseed/#{@sname}/#{@snvid}"

    zip_bname = (@chidx // 100).to_s.rjust(3, '0')
    @zip_file = File.join(@text_dir, zip_bname + ".zip")

    @cv_data = nil
    @cv_time = Time.unix(0)
  end

  def get_cv!(power = 4, mode = 0) : String
    if @cv_data && mode == 0
      return @cv_data.not_nil! if @cv_time >= Time.utc - cv_ttl(power)
    end

    zh_lines = get_zh!(power, reset: mode > 1) || [""]

    @cv_time = Time.utc
    @cv_data = trans!(zh_lines) || ""
  end

  private def cv_ttl(power = 4)
    case power
    when 0 then 1.week
    when 1 then 1.days
    when 2 then 3.hours
    else        10.minutes
    end
  end

  def trans!(lines : Array(String), mode = 2)
    return "" if lines.empty?

    String.build do |io|
      mtl = MtCore.generic_mtl(@bname, mode: mode)
      mtl.cv_title_full(lines[0], mode: mode).to_str(io)

      1.upto(lines.size - 1) do |i|
        io << "\n"
        para = lines.unsafe_fetch(i)
        mtl.cv_plain(para, mode: mode).to_str(io)
      end

      puts "- <ch_text> [#{@sname}/#{@snvid}/#{@chidx}] converted.".colorize.cyan
    end
  end

  def get_zh!(power = 4, reset = false)
    @zh_text ||= load_zh!

    if RmUtil.remote?(@sname, power)
      @zh_text = nil if reset || @zh_text.try(&.empty?)
    end

    @zh_text ||= fetch_zh!(reset ? 3.minutes : 3.years) || @zh_text
  end

  def load_zh!
    if File.exists?(@zip_file)
      Compress::Zip::File.open(@zip_file) do |zip|
        next unless entry = zip["#{@schid}.txt"]?
        return entry.open(&.gets_to_end).split('\n')
      end
    end

    [] of String
  end

  def fetch_zh!(ttl = 10.years, mkdir = true, label = "1/1") : Array(String)?
    RmText.mkdir!(@sname, @snvid) if mkdir

    puller = RmText.new(@sname, @snvid, @schid, ttl: ttl, label: label)
    lines = [puller.title].concat(puller.paras)
    lines.tap { |x| save_zh!(x) }
  rescue err
    puts "- Fetch zh_text error: #{err}".colorize.red
  end

  def set_zh!(lines : Array(String))
    @zh_text = lines
    @cv_data = nil

    save_zh!(lines)
  end

  def save_zh!(lines : Array(String)) : Nil
    ::FileUtils.mkdir_p(@text_dir)
    out_file = File.join(@text_dir, "#{@schid}.txt")
    File.open(out_file, "w") { |io| lines.join(io, "\n") }

    `zip -jqm "#{@zip_file}" "#{out_file}"`
    puts "- <zh_text> [#{out_file}] saved.".colorize.yellow
  end
end
