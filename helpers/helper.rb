# frozen_string_literal: true

module Helpers
  class Helper
    # Prints visual separator in shell for easier reading for humans
    # @example output
    #   [Title Text] -----------------------
    # @param msg [String]
    # @return [void]
    def self.headline(msg)
      line_length = 70 - (msg.size + 3)
      puts "\n[\033[1;34m#{msg}\033[0m] \033[1;31m#{"—" * line_length}\033[0m"
    end
  end
end
