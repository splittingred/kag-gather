require 'active_record'

module KAG
  class Model < ActiveRecord::Base
    self.abstract_class = true
  end
end