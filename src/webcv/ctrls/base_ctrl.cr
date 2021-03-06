class CV::BaseCtrl < Amber::Controller::Base
  LAYOUT = false

  protected getter cv_dname : String { session["cv_uname"]? || "Khách" }
  protected getter cv_uname : String { cv_dname.downcase }
  protected getter cu_privi : Int32 { ViUser.get_power(cv_uname) }

  def add_etag(etag : String)
    response.headers.add("ETag", etag)
  end

  def cache_control(type = "public", max_age = 0)
    if max_age > 0
      control = "#{type}, max-age=#{max_age * 60}"
      response.headers.add("Cache-Control", control)
    end
  end

  def render_json(data : String, status_code = 200)
    render_json(status_code) do |res|
      res.puts(data)
    end
  end

  def render_json(data : Object, status_code = 200)
    render_json(status_code) do |res|
      data.to_json(response)
    end
  end

  def save_session!
    return unless session.changed?

    session.set_session
    cookies.write(response.headers)
  end

  def render_json(status_code = 200)
    response.status_code = status_code
    response.content_type = "application/json"

    yield response
  end

  def halt!(status_code : Int32 = 200, content = "")
    response.headers["Content-Type"] = "text/plain; charset=UTF-8"
    response.status_code = status_code
    response.puts(content)
  end
end

class Amber::Validators::Params
  def fetch_str(name : String | Symbol, df = "") : String
    self[name]? || df
  end

  def fetch_int(name : String | Symbol, min = 0, max = Int32::MAX) : Int32
    val = self[name]?.try(&.to_i?) || 0
    val < min ? min : (val > max ? max : val)
  end
end
