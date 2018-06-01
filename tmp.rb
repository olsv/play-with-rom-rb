require 'pp'
require 'pry'
require 'rom'

require 'rom-repository'

rom = ROM.container(:sql, 'sqlite::memory') do |config|
  config.default.create_table(:users) do
    primary_key :id
    column :name, String, null: false
    column :email, String, null: false
  end

  config.default.create_table(:tasks) do
    primary_key :id
    foreign_key :user_id, :users
    column :title, String, null: false
  end

  config.relation(:users) do
    schema(infer: true) do
      associations do
        has_many :tasks
      end
    end
  end

  config.relation(:tasks) do
    schema(infer: true) do
      associations do
        belongs_to :user
      end
    end
  end
end

class UserRepo < ROM::Repository[:users]
  def create_with_tasks(user)
    users.combine(:tasks).command(:create).call(user)
  end
end

user_repo = UserRepo.new(rom)

pp user_repo.create_with_tasks(
  name: 'Jane',
  email: 'jane@doe.org',
  tasks: [{ title: 'Task 1' }, { title: 'Task 2' }]
)
