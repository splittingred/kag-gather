require 'kag/config'
require 'active_record'
require 'symboltable'
require 'logger'
module KAG
  def self.ensure_database
    ActiveRecord::Base.logger = Logger.new('log/debug.log') if KAG::Config.instance[:debug]
    config = KAG::Config.instance['database']
    if config
      branch = (KAG::Config.instance[:branch].to_sym or :development)
      db = config[branch]
      ActiveRecord::Base.establish_connection(
        :adapter => db[:adapter].to_sym,
        :host => db[:host].to_s,
        :database => db[:database].to_s,
        :username => db[:username].to_s,
        :password => db[:password].to_s,
        :pool => db[:pool].to_i,
        :timeout => db[:timeout].to_i
      )
      true
    else
      false
    end
  end
end