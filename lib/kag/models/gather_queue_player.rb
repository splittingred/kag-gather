require 'kag/models/model'

class GatherQueuePlayer < KAG::Model
  belongs_to :gather_queue
  belongs_to :user
end