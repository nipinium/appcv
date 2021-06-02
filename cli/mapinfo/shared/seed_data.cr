require "colorize"
require "file_utils"

require "../../../src/tabkv/value_map"

class CV::SeedData
  class_getter rating_fix : ValueMap { ValueMap.new("_db/_seeds/rating_fix.tsv", 2) }
  class_getter status_map : ValueMap { ValueMap.new("_db/_seeds/status_map.tsv", 2) }

  getter sname : String
  getter s_dir : String

  getter _index : ValueMap { ValueMap.new("#{@s_dir}/_index.tsv") }

  getter genres : ValueMap { ValueMap.new("#{@s_dir}/genres.tsv") }
  getter bcover : ValueMap { ValueMap.new("#{@s_dir}/bcover.tsv") }

  getter rating : ValueMap { ValueMap.new("#{@s_dir}/rating.tsv") }
  getter hidden : ValueMap { ValueMap.new("#{@s_dir}/hidden.tsv") }

  getter status : ValueMap { ValueMap.new("#{@s_dir}/status.tsv") }
  getter update : ValueMap { ValueMap.new("#{@s_dir}/update.tsv") }

  INTRO_MAPS = {} of String => ValueMap

  def initialize(@sname)
    @s_dir = "_db/_seeds/#{@sname}"
    ::FileUtils.mkdir_p("#{@s_dir}/intros")
  end

  def get_status(snvid : String) : Int32
    case @sname
    when "zxcs_me"                      then 1
    when "zhwenpg", "hetushu", "yousuu" then self.status.ival(snvid)
    else
      return 0 unless status_str = self.status.fval(snvid)

      unless status_int = SeedData.status_map.fval(status_str)
        print " - status int for <#{status_str}>: "

        if status_int = gets.try(&.strip)
          SeedData.status_map.set!(status_str, status_int)
        end
      end

      status_int.try(&.to_i?) || 0
    end
  end

  def intro_map(snvid : String)
    group = snvid.rjust(6, '0')[0, 3]
    INTRO_MAPS[group] ||= ValueMap.new("#{@s_dir}/intros/#{group}.tsv")
  end

  def set_intro(snvid : String, intro : Array(String)) : Nil
    intro_map(snvid).set!(snvid, intro)
  end

  def get_intro(snvid : String) : Array(String)
    intro_map(snvid).get(snvid) || [] of String
  end

  def get_genres(snvid : String)
    zh_names = genres.get(snvid) || [] of String

    zh_names = zh_names.map { |x| NvGenres.fix_zh_name(x) }.flatten.uniq
    vi_names = zh_names.map { |x| NvGenres.fix_vi_name(x) }.uniq

    vi_names.reject!("Loại khác")
    vi_names.empty? ? ["Loại khác"] : vi_names
  end

  def get_scores(snvid : String) : Array(Int32)
    case @sname
    when "yousuu"
      self.rating.get(snvid).not_nil!.map(&.to_i)
    else
      bname = begin
        _, btitle, author = self._index.get(snvid).not_nil!
        "#{btitle}  #{author}"
      end

      if score = SeedData.rating_fix.get(bname)
        score.map(&.to_i)
      elsif @sname == "hetushu" || @sname == "zxcs_me"
        [Random.rand(30..100), Random.rand(50..65)]
      else
        [Random.rand(25..50), Random.rand(40..50)]
      end
    end
  end

  def save!(clean : Bool = false)
    @@rating_fix.try(&.save!(clean: clean))
    @@status_map.try(&.save!(clean: clean))

    @_index.try(&.save!(clean: clean))

    @bcover.try(&.save!(clean: clean))
    @genres.try(&.save!(clean: clean))

    @status.try(&.save!(clean: clean))
    @hidden.try(&.save!(clean: clean))

    @rating.try(&.save!(clean: clean))
    @update.try(&.save!(clean: clean))

    INTRO_MAPS.each_value(&.save!(clean: clean))
  end

  # def upsert!(snvid : String, fixed = false) : Tuple(String, String, String)
  #   _, btitle, author = _index.get(snvid).not_nil!
  #   bhash, btitle, author = NvInfo.upsert!(btitle, author, fixed: fixed)

  #   genres = get_genres(snvid)
  #   NvGenres.set!(bhash, genres) unless genres.empty?

  #   bintro = get_intro(snvid)
  #   NvBintro.set!(bhash, bintro, force: false) unless bintro.empty?

  #   NvFields.set_status!(bhash, get_status(snvid))

  #   mftime = update.ival_64(snvid)
  #   NvOrders.set_update!(bhash, mftime)
  #   NvOrders.set_access!(bhash, mftime // 60)

  #   {bhash, btitle, author}
  # end

  # def upsert_chinfo!(bhash : String, snvid : String, mode = 0) : Nil
  #   chinfo = ChInfo.new(bhash, @sname, snvid)

  #   mtime, total = chinfo.fetch!(power: 4, mode: mode, valid: 10.years)
  #   chinfo.trans!(reset: false) if chinfo.updated?

  #   mtime = update.ival_64(snvid) if @sname == "zhwenpg"
  #   NvInfo.new(bhash).set_chseed(@sname, snvid, mtime, total)
  # end
end