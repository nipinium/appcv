module CV::Improving
  def fix_nouns!(node = @root, mode = 2) : MtNode
    if succ = node.succ
      case succ
      when .kmen?
        node.fuse_right!("các #{node.val}")
      when .ntitle?
        node.fuse_right!("#{node.val} #{succ.val}")
      end
    end

    node = nouns_fuse_left!(node, mode: mode)
    return node if node.prev.try(&.verbs?) || mode == 1

    if succ = node.succ
      case succ
      when .space?
        case succ.key
        when "上"
          node.fuse_right!("trên #{node.val}")
        else
          node.fuse_right!("#{succ.val} #{node.val}")
        end
        node.tag = PosTag::Nform
      when .place?
        node.fuse_right!("#{succ.val} #{node.val}")
        node.tag = PosTag::Nform
      end
    end

    node
  end

  def nouns_fuse_left!(node, mode = 2) : MtNode
    return node if node.veno? || node.nother?

    while prev = node.prev
      case prev
      when .penum?
        val = prev.prev.not_nil!.val
        prev.fuse_left!
        node.fuse_left!("#{val}, ")
        next
      when .concoord?
        prev_2 = prev.prev.not_nil!
        break unless prev_2.tag == node.tag || prev_2.propers? || prev_2.prodeic?

        prev.fuse_left!("#{prev_2.val} ")
        node.fuse_left!("#{prev.val} ")
        next
      when .number?, .nquant?, .quanti?
        break if node.veno? || node.ajno?
        node.fuse_left!("#{prev.val} ")
      when .propers?
        break if prev.prev.try(&.verb?)

        if node.nform?
          node.fuse_left!("#{prev.val} ")
        else
          node.fuse_left!("", " của #{prev.val}")
        end
        next
      when .prodeic?
        case prev.key
        when .ends_with?("个")
          right = prev.val.sub("cái", "").strip
          node.fuse_left!("cái ", " #{right}")
        when .starts_with?("这")
          left = prev.val.sub("này", "").strip
          node.fuse_left!("#{left} ", " này")
        when "各"  then node.fuse_left!("các ")
        when "这"  then node.fuse_left!("", " này")
        when "那些" then node.fuse_left!("chút ", " kia")
        when "其他" then node.fuse_left!("các ", " khác")
        when "任何" then node.fuse_left!("bất kỳ ")
        else           node.fuse_left!("", " #{prev.val}")
        end
      when .prointr?
        case prev.key
        when "什么" then node.fuse_left!("cái ", " gì")
        else           node.fuse_left!("", " #{prev.val}")
        end
      when .amorp?
        node.fuse_left!("#{prev.val} ")
        next
      when .adjts?
        case prev.key
        when "一般" then node.fuse_left!("", " thông thường")
        else           node.fuse_left!("", " #{prev.val}")
        end

        next
      when .ude1?
        break if node == 1
        prev_2 = prev.prev.not_nil!

        case prev_2
        when .adjts?, .nquant?, .quanti?, .veno?, .nmorp?,
             .vintr?, .nform?, .adverb?, .time?, .place?
          prev.fuse_left!(prev_2.val)
          node.fuse_left!("", " #{prev.val}")
        when .nouns?, .propers?
          if (prev_3 = prev_2.prev)
            if verb_subject?(prev_3)
              # break
              node.val = "#{node.val} #{prev_3.val} #{prev_2.val}"
              node.prev = prev_3
            elsif prev_3.vintr?
              prev.fuse_left!(prev_2.val)
              node.fuse_left!("", " #{prev.val}")
            else
              break
            end
          else
            prev.fuse_left!(prev_2.val)
            node.fuse_left!("", " của #{prev.val}")
          end
        else
          break
        end
      else
        break
      end

      node.tag = PosTag::Nform
    end

    node
  end

  def verb_subject?(node : MtNode)
    return false unless node.verb?
    return true unless prev = node.prev
    return false if prev.comma? || prev.penum?
    prev.ends? || prev.vshi? || prev.quantis?
  end

  # private def fix_nouns!(node = @root)
  #   while node = node.succ
  #     prev = node.prev.not_nil!
  #     if node.cat == 1
  #       skip, left, right = false, "", ""

  #       case prev.key
  #       when "这", "这位", "这具", "这个", "这种",
  #            "这些", "这样", "这段", "这份", "这帮",
  #            "这条"
  #         skip, left, right = true, suffix(prev.key[1]?), " này"
  #       when "那位", "那具", "那个", "那种",
  #            "那些", "那样", "那段", "那份", "那帮",
  #            "那条"
  #         skip, left, right = true, suffix(prev.key[1]?), " kia"
  #       when "那"
  #         # TODO: skipping if 那 is in front
  #         skip, left, right = true, suffix(prev.key[1]?), " kia"
  #       when "什么"
  #         skip, right = true, " cái gì"
  #       when "没什么"
  #         skip, left, right = true, "không có ", " gì"
  #       when "这样的"
  #         skip, right = true, " như vậy"
  #       when "其他", "其她", "其它"
  #         skip, left, right = true, "cái ", " khác"
  #       when "别的"
  #         skip, right = true, " khác"
  #       when "某个"
  #         skip, right = true, " nào đó"
  #       when "一串", "一个", "一只", "几个"
  #         skip, left = true, "#{prev.val} "
  #       when "另一个"
  #         skip, left, right = true, "một cái ", " khác"
  #       end
  #       node.fuse_left!(left, right) if skip
  #     end
  #   end

  #   self
  # end
end
