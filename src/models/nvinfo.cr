require "./_models"
require "./author"
require "./btitle"
require "./bgenre"

require "../shared/core_utils"

# Book info
class CV::Models::Nvinfo
  include Clear::Model
  self.table = "nvinfos"

  primary_key type: :serial

  belongs_to author : Author, foreign_key_type: Int32
  belongs_to btitle : Btitle, foreign_key_type: Int32

  column b_hash : String
  column b_slug : String
  column vslug : String?

  column bgenre_ids : Array(Int32), presence: false
  column vi_bgenres : Array(String), presence: false

  column intro_by : String? # source name
  column zh_intro : String?
  column vi_intro : String?

  column status : Int32, presence: false
  column shield : Int32, presence: false

  column cover_name : String?
  column yousuu_bid : String?
  column origin_url : String?

  column word_count : Int32, presence: false
  column chap_count : Int32, presence: false

  column view_count : Int32, presence: false
  column read_count : Int32, presence: false

  column nvmark_count : Int32, presence: false

  column zh_voters : Int32, presence: false # seed voters (yousuu or custom)
  column zh_rating : Int32, presence: false # seed rating (yousuu or custom)

  column vi_voters : Int32, presence: false # chivi genuine voters
  column vi_rating : Int32, presence: false # chivi genuine rating

  column cv_voters : Int32, presence: false # chivi genuine voters
  column cv_rating : Int32, presence: false # chivi genuine rating

  column cv_weight : Int32, presence: false # to be sorted by

  column update_tz : Int64, presence: false
  column access_tz : Int64, presence: false

  timestamps

  def fix_weight : Nil
    cv_voters = zh_voters + vi_voters
    return if cv_voters < 1

    cv_rating = (zh_voters * zh_rating + vi_voters * vi_rating) // cv_voters
    cv_weight = Math.log(cv_voters).*(cv_rating * 100).round.to_i
  end

  def set_bgenre(zh_genre : String) : Nil
    bgenres = Bgenre.upsert_all!(zh_genre)

    ids = bgenre_ids_column.value([] of Int32)
    self.bgenre_ids = ids.concat(bgenres.map(&.id)).uniq

    names = vi_bgenres_column.value([] of String)
    self.vi_bgenres = names.concat(bgenres.map(&.vi_name)).uniq
  end

  def set_status(value : Int32, force : Bool = false) : Nil
    self.status = value if force || value > status_column.value(0)
  end

  def set_update_tz(value : Int64, force : Bool = false) : Nil
    self.update_tz = value if force || value > update_tz_column.value(0)
  end

  def set_access_tz(value : Int64, force : Bool = false) : Nil
    self.access_tz = value if force || value > access_tz_column.value(0)
  end

  def fix_b_slug!(slug : String? = nil) : Nil
    slug = short_slug(self.b_slug) unless slug

    if slug != self.b_slug
      begin
        self.b_slug = slug
        save!
      rescue
        self.b_slug_column.revert
      end
    end
  end

  def fix_vslug!(slug : String? = nil) : Nil
    return unless slug || vslug_column.value(nil)
    slug = short_slug(self.vslug.not_nil!) unless slug

    unless slug.empty? || slug == self.vslug
      begin
        self.vslug = slug
        save!
      rescue
        self.vslug_column.revert
      end
    end
  end

  def short_slug(slug : String)
    slug.sub(/-#{self.b_hash}$/, "")
  end

  def set_intro(zh_intro : Array(String), intro_by : String)
    return if zh_intro.empty?

    self.intro_by = intro_by
    self.zh_intro = zh_intro.join("\n")

    engine = Convert.content(b_hash) # TODO: change to b_slug
    self.vi_intro = zh_intro.map { |x| engine.tl_plain(x) }.join("\n")
  end

  def self.find(btitle : Btitle, author : Author)
    find({btitle_id: btitle.id, author_id: author.id})
  end

  def self.upsert!(zh_btitle : String, zh_author : String) : self
    btitle = Btitle.upsert!(zh_btitle)
    author = Author.upsert!(zh_author)

    unless model = find(btitle, author)
      model = new({btitle: btitle, author: author})

      # TODO: replace `--` with `  `
      b_hash = CoreUtils.digest32("#{btitle}--#{author}")
      b_slug = btitle.hv_name_tsv.join("-")
      vslug = btitle.vi_name_tsv.join("-")

      model.b_hash = b_hash
      model.b_slug = "#{b_slug}-#{b_hash}"
      model.vslug = "#{vslug}-#{b_hash}" unless vslug.empty?

      model.save!
    end

    model.tap do |x|
      x.fix_b_slug!
      x.fix_vslug!
    end
  end
end
