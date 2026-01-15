require 'clausewitz/lexing/token'
include Clausewitz::Lexing

module TokenRefiner
  refine Token do
    def insert(*tokens)
      (tokens + [self.next_token]).reduce(self) do |current_token, token|
        current_token.append(token)
        current_token = token
      end
      return self
    end
  end
end
