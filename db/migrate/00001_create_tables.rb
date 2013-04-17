class CreateTables < ActiveRecord::Migration
  def self.up
    create_table :gather_queues do |t|
      t.datetime :ended_at
      t.timestamps
    end

    create_table :gather_queue_players do |t|
      t.integer :gather_queue_id
      t.integer :user_id
      t.timestamps
    end
    add_index :gather_queue_players, :gather_queue_id
    add_index :gather_queue_players, :user_id

    create_table :ignore_reports do |t|
      t.integer    :user_id
      t.text       :reason
      t.integer    :created_by
      t.timestamps
    end
    add_index :ignore_reports, :user_id

    create_table :ignores do |t|
      t.integer    :user_id
      t.integer    :hours
      t.text       :reason
      t.integer    :created_by
      t.datetime   :ends_at
      t.timestamps
    end
    add_index :ignores, :user_id

  end

  def self.down
    drop_table :gather_queues
    drop_table :gather_queue_players
    drop_table :ignore_reports
    drop_table :ignores
  end
end
