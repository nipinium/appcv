require "colorize"
require "http/client"

# require "crest"

module CV::HttpUtils
  extend self

  def get_html(url : String, encoding : String) : String
    cmd = "curl -L -k -s -m 30 '#{url}'"
    cmd += " | iconv -c -f #{encoding} -t UTF-8" if encoding != "UTF-8"

    try = 0

    loop do
      puts "[GET: <#{url}> (try: #{try})]".colorize.magenta
      html = `#{cmd}`.strip
      return fix_charset(html, encoding) if html.size > 10
    rescue err
      puts err.colorize.red
    ensure
      try += 1
      sleep 500.milliseconds * try
      raise "500 Server Error!" if try > 3
    end
  end

  private def fix_charset(html : String, encoding : String)
    return html if encoding == "UTF-8"
    html.sub(/charset=#{encoding}/i, "charset=utf-8")
  end

  def encoding_for(s_name : String) : String
    case s_name
    when "jx_la", "hetushu", "paoshu8", "zhwenpg", "zxcs_me"
      "UTF-8"
    else
      "GBK"
    end
  end

  def save_file(url : String, out_file : String) : Nil
    cmd = "curl -L -k -s -m 100 '#{url}' -o '#{out_file}'"
    try = 0

    loop do
      puts "[SAVE_FILE: <#{url}> (try: #{try})]".colorize.magenta
      `#{cmd}`
      return if File.exists?(out_file)

      try += 1
      sleep 500.milliseconds * try
      raise "500 Server Error!" if try > 3
    end
  end
end
