require "./_routes"

module Chivi::Server
  get "/api/chaps/:ubid/:seed" do |env|
    ubid = env.params.url["ubid"]

    unless info = Oldcv::BookInfo.get(ubid)
      halt env, status_code: 404, response: "Book not found!"
    end

    seed = env.params.url["seed"]
    mode = env.params.query["mode"]?.try(&.to_i?) || 0

    unless fetched = Oldcv::Kernel.load_list(info, seed, mode: mode)
      halt env, status_code: 404, response: "Seed not found!"
    end

    chdata, mftime = fetched

    limit = env.params.query["limit"]?.try(&.to_i?) || 30
    limit = 30 if limit > 30
    offset = env.params.query["offset"]?.try(&.to_i?) || 0
    offset = 0 if offset < 0

    chlist = chdata.chaps[offset, limit].map do |chap|
      {
        scid:  chap.scid,
        label: chap.vi_label,
        title: chap.vi_title,
        uslug: chap.url_slug,
      }
    end

    Utils.json(env, cached: mftime) do |res|
      {total: chdata.chaps.size, chaps: chlist}.to_json(res)
    end
  end
end
