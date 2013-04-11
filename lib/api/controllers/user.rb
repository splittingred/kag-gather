require 'api/controllers/base'
module KAG
  module API
    module Controller
      class User < Base
        @@class_key = 'User'

        def read(id)
          c = ::User.find(id)
          if c
            d = SymbolTable.new(c.attributes)
            d[:stats] = {}
            c.stats.each do |s|
              d[:stats][s.name] = s.value
            end
            d.delete(:host)
            self.success('',d)
          else
            self.failure('err_nf',c)
          end
        end

        def list
          c = Object.const_get(@@class_key).where(@params)
          if c
            us = []
            c.each do |u|
              ud = SymbolTable.new(u.attributes)
              ud.delete(:host)
              us << ud
            end
            self.success('',us)
          else
            self.failure('err_nf',c)
          end
        end

      end
    end
  end
end