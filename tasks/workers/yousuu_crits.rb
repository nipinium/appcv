require_relative "./yousuu_utils"

class CritCrawler
  def initialize(load_proxy = false, debug_mode = false)
    @http = HttpClient.new(load_proxy, debug_mode)
    @ybids = []
    files = Dir.glob("_db/_oldcv/serials/*.json")
    puts("- inputs: #{files.size}")

    files.each do |file|
      json = JSON.parse(File.read(file))
      ybid = json["yousuu_bid"]
      @ybids << ybid unless ybid.empty?
    end
  end

  def crawl!(page = 1)
    step = 1
    queue = @ybids.dup
    until queue.empty? || proxy_size == 0
      puts("\n[<#{step}-#{page}> queue: #{queue.size}, proxies: #{proxy_size}]".yellow)
      fails = []

      Parallel.each_with_index(queue, in_threads: 15) do |ybid, idx|
        out_file = review_path(ybid, page)
        next if still_good?(out_file)
        case @http.get!(review_url(ybid, page), out_file)
        when :success
          puts(" - <#{idx}/#{queue.size}/#{page}> [#{ybid}] saved.".green)
        when :proxy_error
          puts(" - <#{idx}/#{queue.size}/#{page}> [#{ybid}] proxy failed, remain: #{proxy_size}.".red)
          fails << ybid
        when :no_more_proxy
          puts(" - Out of proxy, aborting!".red)
          return
        end
      end

      step += 1
      queue = fails
    end
  end

  def proxy_size
    @http.proxies.size
  end

  ROOT_DIR = "_db/.cache/yousuu/crits"

  def review_path(ybid, page = 1)
    "#{ROOT_DIR}/#{ybid}-#{page}.json"
  end

  INTERVAL = 3600 * 24 * 5

  def still_good?(file)
    return false unless File.exists?(file)
    interval = INTERVAL
    data = File.read(file)
    interval *= 4 if data.include?("未找到该图书")
    Time.now.to_i - File.mtime(file).to_i <= interval
  end

  def review_url(ybid, page = 1)
    time = (Time.now.to_f * 1000).round
    "https://www.yousuu.com/api/book/#{ybid}/comment?page=#{page}&t=#{time}"
  end
end

load_proxy = ARGV.include?("proxy")
debug_mode = ARGV.include?("debug")
crawler = CritCrawler.new(load_proxy, debug_mode)
page = 1
while crawler.proxy_size > 0
  crawler.crawl!(page)
  page += 1
  break if page == 4
end