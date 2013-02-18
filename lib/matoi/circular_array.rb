module Matoi
  class CircularArray < Array
    def initialize(n)
      @size = n
    end

    def push(*others)
      overflow = (self.size + others.size) - @size
      self.shift(overflow) if 0 < overflow
      super
    end

    def <<(o)
      self.push o
    end
  end
end
