require "colorize"
require "file_utils"
require "./chap_item"

class ChapList
  include BaseModel

  getter ubid : String # book ubid
  getter seed : String # seed name
  property sbid = ""   # seed book id
  property type = 0    # seed type, 0 mean remote source, 1 mean manual source

  getter chaps = [] of ChapItem
  getter index = {} of String => Int32 # can be used for manual sort

  # TODO: explicit adding `delegate` calls for better error checking
  forward_missing_to @chaps

  def initialize(@ubid : String, @seed : String)
    @changes = 1
  end

  # should not be used
  def rebuild_index!
    @chaps.each_with_index { |item, idx| @index[item.scid] = idx }
  end

  # add a new chap_item to last position
  def append(chap : ChapItem) : ChapItem
    @index[chap.scid] = @chaps.size
    @chaps.push(chap)
    chap
  end

  # insert or update a chap_item
  def upsert(chap : ChapItem, idx : Int32? = nil)
    upsert(chap.scid, idx, &.inherit(chap))
  end

  # insert or update a chap_item with block
  def upsert(scid : String, idx : Int32? = nil)
    if idx ||= @index[scid]?
      chap = @chaps[idx]
    else
      chap = append(ChapItem.new(scid))
    end

    yield chap
    @changes += chap.reset_changes!

    chap
  end

  # save file and reset change counter
  def save!(file : String = ChapList.path_for(@ubid, @seed)) : Void
    ChapList.mkdir!(@ubid) # prevent missing folder
    File.write(file, to_json)

    @changes = 0
    puts "- <chap_list> [#{file.colorize.yellow}] saved \
            (changes: #{@changes.colorize.yellow})."
  end

  # class methods

  DIR = File.join("var", "chap_lists")
  FileUtils.mkdir_p(DIR)

  # creat new folder inside `DIR` for this book
  def self.mkdir!(ubid : String)
    FileUtils.mkdir_p(File.join(DIR, ubid))
  end

  # all chap list file in `ubid` folder, return all files if no `ubid` provided
  def self.files(ubid : String = "**") : Array(String)
    Dir.glob(File.join(DIR, ubid, "*.json"))
  end

  # generate file path of chap list base from `DIR`
  def self.path_for(ubid : String, seed : String)
    File.join(DIR, ubid, "#{seed}.json")
  end

  # extract ubid name from filename
  def self.ubid_for(file : String) : String
    File.basename(File.dirname(file))
  end

  # extract seed name from filename
  def self.seed_for(file : String) : String
    file.sub(DIR)
    File.basename(file, ".json")
  end

  # check if chap list exists
  def self.exists?(ubid : String, seed : String)
    File.exists?(path_for(ubid, seed))
  end

  # return true if chap list not found or has mtime smaller than `time`
  def self.outdated?(ubid : String, seed : String, time : Time)
    file = path_for(ubid, seed)
    return true unless File.exists?(file)
    File.info(file).modification_time < time
  end

  # read chap list file if exists, raise error if not found
  def self.read!(file : String) : ChapList
    read(file) || raise "<chap_list> file [#{file}] not found!"
  end

  # read file if exists, return nil if error, delete file if parsing error.
  def self.read(file : String) : ChapList?
    return unless File.exists?(file)
    puts "- <chap_list> [#{file.colorize.blue}] loaded."
    from_json(File.read(file))
  rescue err
    puts "- <chap_list> error parsing file [#{file}], err: #{err}".colorize.red
    File.delete(file)
  end

  # load chap list by book `ubid` and `seed` name
  def self.get(ubid : String, seed : String) : ChapList?
    read(path_for(ubid, seed))
  end

  # load chap list, raise error if not found
  def self.get!(ubid : String, seed : String) : ChapList
    get(ubid, seed) || raise "<chap_list> list [#{ubid}/#{seed}] not found!"
  end

  # load chap list or create new one
  def self.get_or_create(ubid : String, seed : String) : ChapList
    get(ubid, seed) || new(ubid, seed)
  end

  # load all chap lists for one book
  def self.load_all!(ubid : String)
    lists = [] of ChapList
    files(ubid).each { |file| lists << read!(file) }

    puts "- <chap_list> loaded all chap lists for [#{ubid}] \
            (count: #{lists.size.colorize.yellow})."

    lists
  end

  # cache chap lists for faster access
  CACHE = {} of String => ChapList
  # only cache newest ones due to low memory constraint
  CACHE_LIMIT = 500

  # load with caching, raise error if chap list does not exists.
  def self.preload!(ubid : String, seed : String) : ChapList
    CACHE.shift if CACHE.size > LIMIT
    CACHE[cache_key(ubid, seed)] ||= get!(ubid, seed)
  end

  # load with caching, create new entry if not exists
  def self.preload_or_create!(ubid : String, seed : String) : ChapList
    CACHE.shift if CACHE.size > LIMIT
    CACHE[cache_key(ubid, seed)] ||= get_or_create(ubid, seed)
  end

  # generate unique cache key
  private def self.cache_key(ubid : String, seed : String) : String
    "#{ubid}/#{seed}"
  end

  # preload all chap lists for one book to cache
  def self.preload_all!(ubid : String)
    lists = [] of ChapList
    files(ubid).each { |file| lists << preload!(ubid, seed_for(file)) }

    puts "- <chap_list> loaded all chap lists for [#{ubid}] to cache \
            (count: #{lists.size.colorize.yellow})."

    lists
  end
end
