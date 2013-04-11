require 'api/controllers/base'
module KAG
  module API
    module Controller
      class Queue < Base
        @@class_key = 'GatherQueue'

        def read(id)
          queue = ::GatherQueue.find(id)
          if queue
            data = SymbolTable.new(queue.attributes)
            data[:players] = []
            queue.users.each do |u|
              data[:players] << u.name
            end

            self.success('',data)
          else
            self.failure('err_nf',c)
          end
        end

        def list
          c = GatherQueue.where(@params)
          if c
            us = []
            c.each do |u|
              ud = SymbolTable.new(u.attributes)

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