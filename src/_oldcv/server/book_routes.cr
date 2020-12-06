require "./_shared"

module Oldcv::Server::Params
  extend self

  def search_type(type : String?)
    case type
    when "title"  then :title
    when "author" then :author
    else               :fuzzy
    end
  end

  def search_order(order : String?)
    case order
    when "weight", "tally" then :weight
    when "rating", "score" then :rating
    when "access"          then :access
    when "update"          then :update
    else                        :access
    end
  end

  def search_page(page : String?)
    return 1 unless page = page.try(&.to_i?)
    page = 1 if page < 1
    page
  end

  def search_limit(limit : String?, upper = 20)
    return upper unless limit = limit.try(&.to_i?)
    limit < 1 || limit > upper ? upper : limit
  end
end

module Oldcv::Server
  get "/_books" do |env|
    word = env.params.query.fetch("word", "")
    type = Params.search_type(env.params.query["type"]?)

    genre = env.params.query.fetch("genre", "")

    order = Params.search_order(env.params.query["order"]?)
    anchor = env.params.query.fetch("anchor", "")

    page = Params.search_page(env.params.query["page"]?)
    limit = Params.search_limit(env.params.query["limit"]?)
    offset = (page - 1) * limit

    opts = BookDB::Query::Opts.new(word, type, genre, order, limit, offset, anchor)

    infos, total = BookDB::Query.fetch!(opts)

    items = infos.map do |info|
      {
        ubid:       info.ubid,
        slug:       info.slug,
        vi_title:   info.vi_title,
        zh_title:   info.zh_title,
        vi_author:  info.vi_author,
        vi_genres:  info.vi_genres,
        main_cover: info.main_cover,
        rating:     info.rating,
        voters:     info.voters,
      }
    end

    {items: items, total: total, query: opts}.to_json(env.response)
  end

  get "/_books/:slug" do |env|
    slug = env.params.url["slug"]

    unless info = BookDB.find(slug)
      halt env, status_code: 404, response: Utils.json_error("Book not found!")
    end

    # BookDB.bump_access(info)
    # BookDB.inc_counter(info, read: false)

    if uslug = env.session.string?("uslug")
      mark = UserDB.get_book_mark(uslug, info.ubid) || ""
    else
      mark = ""
    end

    env.response.headers.add("ETag", info.mftime.to_s)
    env.response.headers.add("Cache-Control", "max-age=300")
    {book: info, mark: mark}.to_json(env.response)
  end

  get "/_chaps/:slug/:seed" do |env|
    slug = env.params.url["slug"]
    seed = env.params.url["seed"]
    mode = env.params.query["mode"]?.try(&.to_i?) || 0

    unless info = BookDB.find(slug)
      halt env, status_code: 404, response: Utils.json_error("Book not found!")
    end

    unless fetched = Kernel.load_list(info, seed, mode: mode)
      halt env, status_code: 404, response: Utils.json_error("Seed not found!")
    end

    BookDB.bump_access(info, Time.utc.to_unix_ms)
    # BookDB.inc_counter(info, read: false)

    chlist, mftime = fetched
    chlist = chlist.chaps.map do |chap|
      {
        scid:     chap.scid,
        vi_label: chap.vi_label,
        vi_title: chap.vi_title,
        url_slug: chap.url_slug,
      }
    end

    env.response.headers.add("ETag", mftime.to_s)
    env.response.headers.add("Cache-Control", "max-age=300")
    {chlist: chlist, mftime: mftime}.to_json(env.response)
  end

  get "/_texts/:slug/:seed/:scid" do |env|
    slug = env.params.url["slug"]

    unless info = BookDB.find(slug)
      halt env, status_code: 404, response: Utils.json_error("Book not found!")
    end

    BookDB.bump_access(info, Time.utc.to_unix_ms)
    # BookDB.inc_counter(info, read: true)

    seed = env.params.url["seed"]
    unless fetched = Kernel.load_list(info, seed, mode: 0)
      halt env, status_code: 404, response: Utils.json_error("Seed not found!")
    end

    scid = env.params.url["scid"]
    list, _ = fetched

    unless index = list.index[scid]?
      halt env, status_code: 404, response: Utils.json_error("Chapter not found!")
    end

    curr_chap = list.chaps[index]
    prev_chap = list.chaps[index - 1] if index > 0
    next_chap = list.chaps[index + 1] if index < list.size - 1

    mode = env.params.query.fetch("mode", "0").try(&.to_i?) || 0
    chap = Kernel.get_text(info.ubid, seed, list.sbid, scid, mode: mode)

    {
      cvdata: chap.cv_text,
      mftime: chap.cv_time,

      bslug: info.slug,
      bname: info.vi_title,

      ubid: info.ubid,
      seed: seed,
      scid: curr_chap.scid,

      ch_title: curr_chap.vi_title,
      ch_label: curr_chap.vi_label,
      ch_index: index + 1,
      ch_total: list.size,

      curr_url: curr_chap.try(&.slug_for(seed)),
      prev_url: prev_chap.try(&.slug_for(seed)),
      next_url: next_chap.try(&.slug_for(seed)),

    }.to_json(env.response)
  rescue err
    message = err.message || "Unknown error!"
    halt env, status_code: 500, response: Utils.json_error(message)
  end
end