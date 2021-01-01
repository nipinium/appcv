require "myhtml"
require "colorize"
require "file_utils"

require "../../shared/*"

module CV::RmInfo
  extend self

  def init(seed : String, sbid : String, expiry = Time.utc - 30.weeks, freeze = true)
    html_url = seed_url(seed, sbid)
    out_file = path_for(seed, sbid)

    expiry = TimeUtils::DEF_TIME if seed == "jx_la"
    parser_for(seed).new(html_url, out_file, expiry, freeze)
  end

  def path_for(seed : String, sbid : String)
    "_db/.cache/#{seed}/infos/#{sbid}.html"
  end

  def parser_for(seed : String) : Class
    case seed
    when "5200"       then RI_5200
    when "jx_la"      then RI_Jx_la
    when "69shu"      then RI_69shu
    when "nofff"      then RI_Nofff
    when "rengshu"    then RI_Rengshu
    when "xbiquge"    then RI_Xbiquge
    when "paoshu8"    then RI_Paoshu8
    when "duokan8"    then RI_Duokan8
    when "shubaow"    then RI_Shubaow
    when "hetushu"    then RI_Hetushu
    when "zhwenpg"    then RI_Zhwenpg
    when "biquge5200" then RI_Biquge5200
    else                   raise "Unsupported remote source <#{seed}>!"
    end
  end

  def seed_url(seed : String, sbid : String) : String
    case seed
    when "nofff"      then "https://www.nofff.com/#{sbid}/"
    when "69shu"      then "https://www.69shu.com/#{sbid}/"
    when "jx_la"      then "https://www.jx.la/book/#{sbid}/"
    when "qu_la"      then "https://www.qu.la/book/#{sbid}/"
    when "rengshu"    then "http://www.rengshu.com/book/#{sbid}"
    when "xbiquge"    then "https://www.xbiquge.cc/book/#{sbid}/"
    when "zhwenpg"    then "https://novel.zhwenpg.com/b.php?id=#{sbid}"
    when "hetushu"    then "https://www.hetushu.com/book/#{sbid}/index.html"
    when "duokan8"    then "http://www.duokan8.com/#{prefixed(sbid)}/"
    when "paoshu8"    then "http://www.paoshu8.com/#{prefixed(sbid)}/"
    when "5200"       then "https://www.5200.tv/#{prefixed(sbid)}/"
    when "shubaow"    then "https://www.shubaow.net/#{prefixed(sbid)}/"
    when "biquge5200" then "https://www.biquge5200.com/#{prefixed(sbid)}/"
    else                   raise "Unsupported remote source <#{seed}>!"
    end
  end

  private def prefixed(sbid : String)
    "#{sbid.to_i // 1000}_#{sbid}"
  end

  record ChInfo, scid : String, title : String, label : String do
    def inspect(io : IO)
      {scid, title, label}.join(io)
    end
  end

  alias Chlist = Array(ChInfo)

  class RI_Generic
    # input

    getter html_url : String
    getter out_file : String

    # output

    getter html : String { fetch! }
    getter rdoc : Myhtml::Parser { Myhtml::Parser.new(html) }

    getter author : String { meta_data("og:novel:author") || "" }
    getter btitle : String { meta_data("og:novel:book_name") || "" }

    getter bgenre : String { meta_data("og:novel:category") || "" }
    getter tags : Array(String) { [] of String }

    getter bintro : Array(String) { TextUtils.split_html(raw_intro || "") }
    getter bcover : String { raw_cover || "" }

    getter status : Int32 { map_status(raw_status) || 0 }
    getter update : Time { TimeUtils.parse_time(raw_update) }

    getter chlist : Chlist { extract_chlist("#list > dl") }

    def initialize(@html_url, @out_file, @expiry : Time, @freeze : Bool = true)
    end

    def fetch!
      unless html = FileUtils.read(@out_file, @expiry)
        html = HttpUtils.get_html(@html_url)
        File.write(@out_file, html) if @freeze
      end

      html
    end

    def cached?(expiry : Time = @expiry)
      FileUtils.recent?(@out_file, expiry)
    end

    def uncache!
      File.delete(@out_file) if File.exists?(@out_file)
    end

    def map_status(status : String?) : Int32
      case status
      when "完成", "完本", "已经完结", "已经完本", "完结", "已完结"
        1
      when "连载", "连载中....", "连载中", nil
        0
      else
        puts "[UNKNOWN SOURCE STATUS: `#{status}`]".colorize.red
        0
      end
    end

    def raw_intro
      meta_data("og:description")
    end

    def raw_cover
      meta_data("og:image")
    end

    def raw_status
      meta_data("og:novel:status")
    end

    def raw_update
      meta_data("og:novel:update_time")
    end

    def extract_chlist(sel : String)
      chlist = Chlist.new
      return chlist unless node = find_node(sel)

      label = "正文"

      node.children.each do |node|
        case node.tag_sym
        when :dt
          label = node.inner_text.gsub(/《.*》/, "").strip
        when :dd
          next if label.includes?("最新章节")
        end

        next unless link = node.css("a").first?
        next unless href = link.attributes["href"]?

        scid = extract_scid(href)
        title, label = TextUtils.format_title(link.inner_text, label)
        chlist << ChInfo.new(scid, title, label)
      end

      chlist
    end

    def extract_scid(href : String)
      File.basename(href, ".html")
    end

    private def find_node(sel : String)
      rdoc.css(sel).first?
    end

    private def node_attr(sel : String, attr : String)
      find_node(sel).try(&.attributes[attr]?)
    end

    private def meta_data(sel : String)
      node_attr("meta[property=\"#{sel}\"]", "content")
    end

    private def node_text(sel : String)
      find_node(sel).try(&.inner_text.strip)
    end
  end

  class RI_Nofff < RI_Generic; end

  class RI_Paoshu8 < RI_Generic; end

  class RI_Xbiquge < RI_Generic; end

  class RI_Shubaow < RI_Generic; end

  class RI_Rengshu < RI_Generic; end

  class RI_5200 < RI_Generic
    getter chlist : Chlist { extract_chlist(".listmain > dl") }
  end

  class RI_Biquge5200 < RI_Generic
    def raw_update
      node_text("#info > p:last-child").not_nil!.sub("最后更新：", "")
    end
  end

  class RI_Jx_la < RI_Generic
    def raw_cover
      meta_data("og:image").try(&.sub("qu.la", "jx.la"))
    end
  end

  class RI_Duokan8 < RI_Generic
    getter chlist : Chlist { extract_chlist }

    private def extract_chlist
      chlist = Chlist.new

      rdoc.css(".chapter-list a").each do |link|
        next unless href = link.attributes["href"]?
        text = TextUtils.format_title(link.inner_text)
        chlist << ChInfo.new(extract_scid(href), text)
      end

      chlist
    end
  end

  class RI_Hetushu < RI_Generic
    getter author : String { node_text("h2") || "" }
    getter btitle : String { node_text(".book_info a:first-child") || "" }
    getter bintro : Array(String) { rdoc.css(".intro > p").map(&.inner_text).to_a }
    getter tags : Array(String) { rdoc.css(".tag a").map(&.inner_text).to_a }

    getter update : Time { TimeUtils::DEF_TIME }
    getter chlist : Chlist { extract_chlist("#dir") }

    def raw_genre
      node_text(".title > a:nth-child(2)")
    end

    def raw_cover
      url = node_attr(".book_info img", "src")
      "https://www.hetushu.com/#{url.not_nil!}"
    end

    def status : Int32
      unless @status
        classes = node_attr(".book_info", "class").not_nil!
        @status = classes.includes?("finish") ? 1 : 0
      end

      @status.not_nil!
    end
  end

  class RI_Zhwenpg < RI_Generic
    getter author : String { node_text(".fontwt") || "" }
    getter btitle : String { node_text(".cbooksingle h2") || "" }
    getter bgenre : String { "" }
    getter update : Time { TimeUtils::DEF_TIME }
    getter chlist : Chlist { extract_chlist }

    def raw_intro
      node_text("tr:nth-of-type(3)")
    end

    def raw_cover
      node_attr(".cover_wrapper_m img", "data-src")
    end

    def extract_scid(href : String)
      href.sub("r.php?id=", "")
    end

    def extract_chlist
      chlist = Chlist.new

      rdoc.css(".clistitem > a").each do |link|
        scid = extract_scid(link.attributes["href"])
        title, label = TextUtils.format_title(link.inner_text)
        chlist << ChInfo.new(scid, title, label)
      end

      # check if the list is in correct orlder
      if node = find_node(".fontwt0 + a")
        latest_link = node.attributes["href"]
        latest_scid = extract_scid(latest_link)
        chlist.reverse! if latest_scid == chlist.first.scid
      end

      chlist
    end
  end

  class RI_69shu < RI_Generic
    getter author : String { node_text(".mu_beizhu > a[target]") || "" }
    getter btitle : String { node_text(".weizhi > a:last-child") || "" }
    getter bgenre : String { node_text(".weizhi > a:nth-child(2)") || "" }

    getter bintro : Array(String) { [] of String }
    getter status : Int32 { 0 }
    getter chlist : Chlist { extract_chlist }

    COVER_URI = "https://www.69shu.com/files/article/image/"

    def raw_cover
      sbid = File.basename(@out_file, ".html")
      "#{COVER_URI}/#{sbid.to_i % 1000}/#{sbid}/#{sbid}s.jpg"
    end

    def raw_update
      node_text(".mu_beizhu").not_nil!.sub(/.+时间：/m, "")
    end

    def extract_scid(href : String)
      File.basename(href)
    end

    def extract_chlist
      chlist = Chlist.new
      return chlist unless nodes = rdoc.css(".mu_contain").to_a

      nodes.shift if nodes.size > 0
      label = "正文"

      nodes.each do |mulu|
        mulu.children.each do |node|
          case node.tag_sym
          when :h2
            label = node.inner_text.strip
          when :ul
            node.css("a").each do |link|
              title = link.inner_text
              next if title.starts_with?("我要报错！")

              scid = parse_scid(link.attributes["href"])
              chlist << Chinfo.new(scid, title, label)
            end
          end
        end
      end

      chlist
    end
  end
end
