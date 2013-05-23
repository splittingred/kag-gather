require 'kag/models/model'

class Kill < KAG::Model
  belongs_to :victim, :class_name => 'User', :foreign_key => 'victim_id'
  belongs_to :killer, :class_name => 'User', :foreign_key => 'killer_id'


end