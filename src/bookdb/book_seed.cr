require "../common/json_data"
require "../parser/seed_info"

require "./chap_info"

class BookSeed
  # seed types: 0 => remote, 1 => manual, 2 => locked
  # index : to be sorted

  include JsonData

  property name = ""
  property sbid = ""
  property type = 0
  property idx = 0

  property mftime = 0_i64
  property latest = ChapInfo.new

  def initialize(@name, @sbid = "", @type = 0)
    @idx = BookSeed.index_for(@name)
    @changes = 1
  end

  def remote?
    @type == 0
  end

  # def update_remote(sbid = @sbid, type = @type, expiry : Time = Time.unix_ms(@mftime), freeze : Bool = false)
  #   source = SeedInfo.new(@seed, sbid, type, expiry: expiry, freeze: freeze)
  #   update_remote(source)
  # end

  def update(source : BookSeed)
    if @sbid != source.sbid
      return if @mftime > source.mftime
    else
      @sbid = source.sbid
      @type = source.type
    end

    update_latest(source.latest, source.mftime)
  end

  # update latest chap
  def update_latest(latest : ChapInfo, mftime = @mftime)
    mftime = @mftime if mftime < @mftime

    if @latest.scid != latest.scid
      mftime = Time.utc.to_unix_ms if mftime == @mftime
      @latest = latest
    else
      @latest.inherit(latest)
    end

    @changes += @latest.reset_changes!
    self.mftime = mftime

    @latest
  end

  # class methods

  NAMES = {
    "hetushu", "jx_la", "rengshu",
    "xbiquge", "nofff", "duokan8",
    "paoshu8", "69shu", "zhwenpg",
  }

  def self.index_for(name : String) : Int32
    NAMES.index(name) || -1
  end
end
