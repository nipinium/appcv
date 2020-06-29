require "json"
require "colorize"

require "../kernel/chap_text"
require "../kernel/import/remote_text"

require "../engine"

module ChapRepo
  extend self

  # modes:
  # 2 => load saved chap_text
  # 1 => load saved chap_text then convert
  # 0 => fetch text from external hosts then convert

  def load_text(host : String, bsid : String, csid : String, udic : String = "local", bdic = "tonghop", mode : Int32 = 2)
    chap = ChapText.new(host, bsid, csid, preload: false)

    if chap.exists? && mode > 0
      chap.load!

      return chap if mode > 1
      zh_lines = chap.zh_lines
    else
      zh_lines = RemoteText.fetch!(host, bsid, csid, keep_html: false)
    end

    chap.data = Engine.cv_mixed(zh_lines, bdic, udic).map(&.to_s).join("\n")
    chap.save!
  end
end