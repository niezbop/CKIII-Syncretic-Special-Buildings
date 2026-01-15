require 'clausewitz/parsing/tree/block'
include Clausewitz::Parsing::Tree

module BlockRefiner
  refine Block do
    def recursive_children
      result = []
      self.children.each do |child|
        next unless child.is_a? Statement
        if child.right.is_a? Block
          child.right.recursive_children.each do |recursive_child|
            result << recursive_child.unshift(child)
          end
        else
          result << [child]
        end
      end

      return result
    end
  end
end
