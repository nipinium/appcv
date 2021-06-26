class CV::Btitle < Granite::Base
  connection pg
  table btitles

  column id : Int64, primary: true
  timestamps

  has_one :cvbook, foreign_key: :id

  has_many :ysbook
  has_many :zhbook
  has_many :yscrit
  has_many :yslist, through: :yscrit

  belongs_to :author
  column bgenre_ids : Array(Int32) = [0]
  column zhseed_ids : Array(Int32) = [0]

  column bhash : String # unique string generate from zh_title & zh_author
  column bslug : String # unique string generate from hv_title & bhash

  column ztitle : String # chinese title
  column htitle : String # hanviet title
  column vtitle : String # localization

  # for text searching
  column ztitle_ts : String # auto generated from zname
  column htitle_ts : String # auto generated from hname
  column vtitle_ts : String # auto generated from vname

  getter bgenres : Array(String) { Bgenre.all(bgenre_ids) }
  getter zhseeds : Array(String) { Zhseed.all(zhseed_ids) }

  column bcover : String = ""
  column bintro : String = ""

  # 0: ongoing, 2: completed, 3: axed/hiatus, 4: unknown
  column status : Int32 = 0

  # 0: public (anyone can see), 1: protected (show to registered users),
  # 2: private (show to power users), 3: hidden (show to administrators only)
  column shield : Int32 = 0 # default to 0

  column bumped : Int64 = 0 # value by minute from the epoch, update whenever an registered user viewing book info
  column mftime : Int64 = 0 # value by minute from the epoch, max value of nvseed mftime and ys_mftime

  column weight : Int32 = 0 # voters * rating + ???
  column voters : Int32 = 0 # = ys_voters + vi_voters * 2 + random_seed (if < 25)
  column rating : Int32 = 0 # delivered from above values

end
