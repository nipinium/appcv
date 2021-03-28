require "file_utils"
require "../../src/appcv/nvinfo"

class CV::Seeds::FixCovers
  INP_DIR = "_db/bcover"
  OUT_DIR = "_db/nvdata/bcovers"

  ::FileUtils.mkdir_p(OUT_DIR)

  def fix!(redo : Bool = false)
    checked = Set(String).new

    bhashes = Dir.children(Nvinfo::DIR).map { |x| File.basename(x, ".tsv") }
    bhashes.each_with_index(1) do |bhash, idx|
      if idx % 20 == 0
        puts "- [fix_covers] <#{idx}/#{bhashes.size}>".colorize.blue
        MAP.each_value { |map| map.save!(clean: false) }
      end

      nvinfo = Nvinfo.new(bhash)
      covers = {} of String => String

      nvinfo._meta.fval("yousuu").try { |x| covers["yousuu"] = x }
      snames = nvinfo._meta.get("chseed") || [] of String
      snames.each { |s| covers[s] = nvinfo.get_chseed(s)[0] }

      max_width = 0
      out_cover = nil

      covers.each do |sname, snvid|
        next unless cover_file = cover_path(sname, snvid)

        unless cover_width = width_map(sname).fval(cover_file).try(&.to_i)
          cover_width = image_width(cover_file)

          if mtime = File.info?(cover_file).try(&.modification_time)
            values = [cover_width.to_s, mtime.to_unix.to_s]
            width_map(sname).set!(cover_file, values)
          end
        end

        if cover_width > max_width
          max_width = cover_width
          out_cover = cover_file
        end
      end

      next unless out_cover

      sname = File.basename(File.dirname(out_cover))
      out_file = "#{OUT_DIR}/#{sname}-#{File.basename(out_cover)}"

      nvinfo._meta.set!("bcover", File.basename(out_file))
      nvinfo.save!(clean: false)

      FileUtils.cp(out_cover, out_file) unless File.exists?(out_file)

      out_webp = out_file + ".webp"
      `convert "#{out_file}" -resize "300>x" "#{out_webp}"` unless File.exists?(out_webp)
    rescue err
      puts err
    end

    MAP.each_value { |map| map.save!(clean: true) }
  end

  MAP = {} of String => ValueMap

  private def width_map(sname : String)
    MAP[sname] ||= ValueMap.new("#{INP_DIR}/_index/#{sname}.tsv")
  end

  # next unless cover_file = cover_path(snam
  def cover_path(sname : String, snvid : String) : String?
    {"html", "jpg.gz", ".pc", ".apple", ".ascii"}.each do |ext|
      file = "#{INP_DIR}/#{sname}/#{snvid}.#{ext}"
      return if File.exists?(file)
    end

    {"webp", "gif", "png", "tiff", "jpg"}.each do |ext|
      file = "#{INP_DIR}/#{sname}/#{snvid}.#{ext}"
      return file if File.exists?(file)
    end
  end

  def image_width(fname : String)
    if fname.ends_with?(".gif")
      return case fname
      when .includes?("yousuu") then 10000
      when .includes?("jx_la")  then 0
      else                           400
      end
    end

    `identify -format '%w %h' "#{fname}"`.split(" ").first.to_i? || 0
  rescue
    0
  end
end

worker = CV::Seeds::FixCovers.new
worker.fix!(ARGV.includes?("redo"))
