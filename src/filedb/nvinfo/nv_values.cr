require "./nv_helper"

module CV::NvValues
  extend self

  class_getter _index : TokenMap { NvHelper.token_map("_index") }

  class_getter btitle : ValueMap { NvHelper.value_map("btitle") }
  class_getter author : ValueMap { NvHelper.value_map("author") }

  class_getter genres : ValueMap { NvHelper.value_map("genres") }

  class_getter bcover : ValueMap { NvHelper.value_map("bcover") }
  class_getter yousuu : ValueMap { NvHelper.value_map("yousuu") }
  class_getter origin : ValueMap { NvHelper.value_map("origin") }

  class_getter voters : OrderMap { NvHelper.order_map("voters") }
  class_getter rating : OrderMap { NvHelper.order_map("rating") }
  class_getter weight : OrderMap { NvHelper.order_map("weight") }

  class_getter hidden : ValueMap { NvHelper.value_map("hidden") }
  class_getter status : ValueMap { NvHelper.value_map("status") }

  class_getter _atime : OrderMap { NvHelper.order_map("_atime") }
  class_getter _utime : OrderMap { NvHelper.order_map("_utime") }

  def save!(clean : Bool = false)
    @@_index.try(&.save!(clean: clean))

    @@btitle.try(&.save!(clean: clean))
    @@author.try(&.save!(clean: clean))

    @@genres.try(&.save!(clean: clean))
    @@bcover.try(&.save!(clean: clean))

    @@yousuu.try(&.save!(clean: clean))
    @@origin.try(&.save!(clean: clean))

    @@hidden.try(&.save!(clean: clean))
    @@status.try(&.save!(clean: clean))

    @@voters.try(&.save!(clean: clean))
    @@rating.try(&.save!(clean: clean))
    @@weight.try(&.save!(clean: clean))

    @@_atime.try(&.save!(clean: clean))
    @@_utime.try(&.save!(clean: clean))
  end

  def set_score(bhash : String, z_voters : Int32, z_rating : Int32)
    if z_voters == 0
      z_voters = Random.rand(1..9)
      z_rating = Random.rand(30..50)
    elsif z_voters < 10
      sum = Random.rand(30..50) * (10 - z_voters) + z_voters * z_rating
      z_rating = sum // 10
    end

    voters.upsert!(bhash, z_voters)
    rating.upsert!(bhash, z_rating)

    score = Math.log(z_voters + 10).*(z_rating * 10).round.to_i
    weight.upsert!(bhash, score)
  end

  {% for field in {:hidden, :status} %}
    def set_{{field.id}}(bhash, value : Int32, force : Bool = false)
      return false unless force || value > {{field.id}}.ival(bhash)
      {{field.id}}.upsert!(bhash, value)
    end
  {% end %}

  {% for field in {:_atime, :_utime} %}
    def set{{field.id}}(bhash, value : Int64, force : Bool = false)
      return false unless force || value > {{field.id}}.ival_64(bhash)
      {{field.id}}.upsert!(bhash, value)
    end

    def set{{field.id}}(bhash, value : Time, force : Bool = false)
      set{{field.id}}(bhash, value.to_unix, force: force)
    end
  {% end %}
end
