class CreateTables < ActiveRecord::Migration
  def self.up
    return true if ActiveRecord::Base.connection.table_exists? 'gather_queues'

    create_table :clans do |t|
      t.string :name
      t.timestamps
    end

    create_table :clan_stats do |t|
      t.integer    :clan_id, :null => false, :default => 0
      t.string     :name, :limit => 255, :null => false, :default => ''
      t.integer    :value, :null => false, :default => 0
      t.timestamps
    end
    add_index :clan_stats, :clan_id

    create_table :gather_queues do |t|
      t.datetime :ended_at
      t.timestamps
    end

    create_table :gather_queue_players do |t|
      t.integer :gather_queue_id, :null => false, :default => 0
      t.integer :user_id, :null => false, :default => 0
      t.timestamps
    end
    add_index :gather_queue_players, :gather_queue_id
    add_index :gather_queue_players, :user_id

    create_table :ignore_reports do |t|
      t.integer    :user_id, :null => false, :default => 0
      t.text       :reason
      t.integer    :created_by, :null => false, :default => 0
      t.timestamps
    end
    add_index :ignore_reports, :user_id

    create_table :ignores do |t|
      t.integer    :user_id, :null => false, :default => 0
      t.integer    :hours, :null => false, :default => 0
      t.text       :reason
      t.integer    :created_by
      t.datetime   :ends_at
      t.timestamps
    end
    add_index :ignores, :user_id

    create_table :matches do |t|
      t.integer    :server_id, :null => false, :default => 0
      t.integer    :num_players, :null => false, :default => 0
      t.integer    :num_teams, :null => false, :default => 0
      t.datetime   :started_at
      t.datetime   :ended_at
      t.integer    :end_votes, :null => false, :default => 0
      t.integer    :subs_needed, :null => false, :default => 0
      t.text       :stats
      t.timestamps
    end
    add_index :matches, :server_id

    create_table :players do |t|
      t.integer    :user_id, :null => false, :default => 0
      t.integer    :match_id, :null => false, :default => 0
      t.integer    :team_id, :null => false, :default => 0
      t.string     :cls, :limit => 100, :default => ''
      t.integer    :kills, :null => false, :default => 0
      t.integer    :deaths, :null => false, :default => 0
      t.boolean    :won, :null => false, :default => 0
      t.boolean    :deserted, :null => false, :default => 0
      t.boolean    :is_sub, :null => false, :default => 0
      t.timestamps
    end
    add_index :players, :user_id
    add_index :players, :match_id
    add_index :players, :team_id

    create_table :servers do |t|
      t.string     :name, :limit => 255, :default => ''
      t.string     :ip, :limit => 255, :default => '127.0.0.1'
      t.string     :port, :limit => 40, :default => '50301'
      t.string     :password, :limit => 100, :default => '1'
      t.string     :rcon_password, :limit => 100
      t.integer    :in_use, :limit => 11
      t.string     :status, :limit => 100, :default => 'inactive'
      t.timestamps
    end

    create_table :substitutions do |t|
      t.integer    :team_id, :null => false, :default => 0
      t.integer    :match_id, :null => false, :default => 0
      t.string     :cls, :limit => 100, :null => false, :default => 'Knight'
      t.integer    :old_player_id, :null => false, :default => 0
      t.integer    :new_player_id, :null => false, :default => 0
      t.string     :status, :limit => 100, :default => 'open'
      t.timestamps
    end
    add_index :substitutions, :team_id
    add_index :substitutions, :match_id
    add_index :substitutions, :old_player_id
    add_index :substitutions, :new_player_id

    create_table :teams do |t|
      t.integer    :match_id, :null => false, :default => 0
      t.string     :name, :limit => 255, :null => false, :default => ''
      t.string     :color, :null => false, :default => ''
      t.integer    :num_players, :limit => 4, :null => false, :default => 10
      t.timestamps
    end
    add_index :teams, :match_id

    create_table :user_stats do |t|
      t.integer    :user_id, :null => false, :default => 0
      t.string     :name, :limit => 255, :null => false, :default => ''
      t.integer    :value, :null => false, :default => 0
      t.timestamps
    end
    add_index :user_stats, :user_id

    create_table :users do |t|
      t.integer    :clan_id, :limit => 11, :null => false, :default => 0
      t.string     :authname, :limit => 120, :null => false, :default => ''
      t.string     :nick, :limit => 120, :null => false, :default => ''
      t.string     :kag_user, :limit => 120, :null => false, :default => ''
      t.string     :host, :limit => 255, :null => false, :default => ''
      t.boolean    :temp, :limit => 1,:null => false,:default => false
      t.datetime   :temp_end_at
      t.float      :score, :precision => 2,:null =>false,:default => 0.00
      t.timestamps
    end
    add_index :users, :clan_id
  end

  def self.down
    drop_table :gather_queues
    drop_table :gather_queue_players
    drop_table :ignore_reports
    drop_table :ignores
    drop_table :matches
    drop_table :players
    drop_table :servers
    drop_table :substitutions
    drop_table :teams
    drop_table :user_stats
    drop_table :users
  end
end
