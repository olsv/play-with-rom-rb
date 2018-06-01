require 'pp'
require 'pry'
require 'rom'

rom = ROM.container(:sql, 'sqlite:memory') do |config|
  # Enable logging to stdout
  config.gateways[:default].use_logger(Logger.new($stdout))

  config.default.connection.create_table(:users) do
    primary_key :id
    column :user_name, String, null: false
    column :email, String, null: false
  end

  config.default.connection.create_table(:profiles) do
    primary_key :id
    foreign_key :user_id, :users, on_delete: :cascade, null: false

    column :first_name, String, null: false
    column :last_name, String, null: false
  end

  config.default.connection.create_table(:blogs) do
    primary_key :id
    foreign_key :user_id, :users, on_delete: :cascade, null: false

    column :name, String, null: false
    column :slug, String, null: false
  end

  config.default.connection.create_table(:posts) do
    primary_key :id
    foreign_key :blog_id, :blogs, on_delete: :cascade, null: false
    foreign_key :user_id, :users, on_delete: :cascade, null: false

    column :name, String, null: false
    column :slug, String, null: false
    column :description, String, null: false
    column :content, String, null: false
  end

  config.default.connection.create_table(:comments) do
    primary_key :id
    foreign_key :post_id, :posts, on_delete: :cascade, null: false
    foreign_key :user_id, :users, on_delete: :cascade, null: false

    column :content, String, null: false
  end

  config.relation(:users) do
    schema(infer: true) do
      associations do
        has_one :profile
        has_many :blogs
        has_many :posts
        has_many :comments
      end
    end

    #auto_struct true
  end

  config.relation(:profiles) do
    schema(infer: true) do
      associations do
        belongs_to :user
      end
    end

    #auto_struct true
  end

  config.relation(:blogs) do
    schema(infer: true) do
      associations do
        has_many :posts
        belongs_to :user
      end
    end

    #auto_struct true
  end

  config.relation(:posts) do
    schema(infer: true) do
      associations do
        has_many :comments
        belongs_to :user
        belongs_to :blog
      end
    end

    #auto_struct true
  end

  config.relation(:comments) do
    schema(infer: true) do
      associations do
        belongs_to :user
        belongs_to :post
      end
    end

    #auto_struct true
  end
end

module BasicCommands
  def self.included(target)
    target.commands :create, update: :by_pk, delete: :by_pk
  end
end

class UserRepo < ROM::Repository[:users];
  include BasicCommands

  # the goad is to hide low level details by the well-defined public interface
  def list_by(conditions)
    users.where(conditions).to_a
  end

  def get(id)
    # without .one! or .one returns ROM::Relation[Users]
    # with .one! raises ROM::TupleCountMismatchError if there is no record
    # .one simply returns nil if there is no record
    users.by_pk(id).one!
  end

  def create_with_profile(user)
    users.combine(:profile).command(:create).call(user)
  end
end

class ProfileRepo < ROM::Repository[:profiles]
  include BasicCommands
end

class BlogRepo < ROM::Repository[:blogs]
  include BasicCommands
end

class PostRepo < ROM::Repository[:posts]
  include BasicCommands
end

class CommentRepo < ROM::Repository[:comments]
  include BasicCommands
end

user_repo = UserRepo.new(rom)
profile_repo = ProfileRepo.new(rom)
blog_repo = BlogRepo.new(rom)
post_repo = PostRepo.new(rom)
comment_repo = CommentRepo.new(rom)

# Basic CRUD Operations
user = user_repo.create(email: 'some@host.com', user_name: 'some')
pp user # #<ROM::Struct::User id=1 user_name="some" email="some@host.com">
updated_user = user_repo.update(user.id, email: 'other@host.com')
pp updated_user # #<ROM::Struct::User id=1 user_name="some" email="other@host.com">
result = user_repo.delete(user.id) # returns deleted record by itself.
pp result #<ROM::Struct::User id=1 user_name="some" email="other@host.com">

# scene
first_user = user_repo.create(email: 'first@host.com', user_name: 'first')
first_profile = profile_repo.create(user_id: first_user.id, first_name: 'first', last_name: 'user')
second_user = user_repo.create(email: 'second@host.com', user_name: 'second')
second_profile = profile_repo.create(user_id: second_user.id, first_name: 'second', last_name: 'user')
first_blog = blog_repo.create(user_id: first_user.id, name: 'first blog', slug: 'first-blog')
second_blog = blog_repo.create(user_id: second_user.id, name: 'second blog', slug: 'second-blog')

first_post_1 = post_repo.create(
  user_id: first_user.id,
  blog_id: first_blog.id,
  name: 'first post 1',
  slug: 'first-post-1',
  content: 'first content 1',
  description: 'first description 1'
)

first_post_2 = post_repo.create(
  user_id: first_user.id,
  blog_id: first_blog.id,
  name: 'first post 2',
  slug: 'first-post-2',
  content: 'first content 2',
  description: 'first description 2'
)

second_post_1 = post_repo.create(
  user_id: second_user.id,
  blog_id: second_blog.id,
  name: 'second post 1',
  slug: 'second-post-1',
  content: 'second content 1',
  description: 'second description 1'
)

second_post_2 = post_repo.create(
  user_id: second_user.id,
  blog_id: second_blog.id,
  name: 'second post 2',
  slug: 'second-post-2',
  content: 'second content 2',
  description: 'second description 2'
)

first_comment_1 = comment_repo.create(
  post_id: second_post_1.id,
  user_id: first_user.id,
  content: "first comment"
)

second_comment_1 = comment_repo.create(
  post_id: first_post_1.id,
  user_id: second_user.id,
  content: "second comment"
)

first_comment_2 = comment_repo.create(
  post_id: first_post_1.id,
  user_id: first_user.id,
  content: "first reply"
)

second_comment_2 = comment_repo.create(
  post_id: second_post_1.id,
  user_id: second_user.id,
  content: "second reply"
)

# basic aggregates operations
user_repo.aggregate(:profile).to_a
# [#<ROM::Struct::User id=2 user_name="first" email="first@host.com" profile=#<ROM::Struct::Profile id=1 user_id=2 first_name="first" last_name="user">>,
#<ROM::Struct::User id=3 user_name="second" email="second@host.com" profile=#<ROM::Struct::Profile id=2 user_id=3 first_name="second" last_name="user">>]

user_repo.aggregate(blogs: [:posts]).to_a
# [#<ROM::Struct::User id=2 user_name="first" email="first@host.com" blogs=[#<ROM::Struct::Blog id=1 user_id=2 name="first blog" slug="first-blog" posts=[#<ROM::Struct::Post id=1 blog_id=1 user_id=2 name="first post 1" slug="first-post-1" description="first description 1" content="first content 1">, #<ROM::Struct::Post id=2 blog_id=1 user_id=2 name="first post 2" slug="first-post-2" description="first description 2" content="first content 2">]>]>,
#  #<ROM::Struct::User id=3 user_name="second" email="second@host.com" blogs=[#<ROM::Struct::Blog id=2 user_id=3 name="second blog" slug="second-blog" posts=[#<ROM::Struct::Post id=3 blog_id=2 user_id=3 name="second post 1" slug="second-post-1" description="second description 1" content="second content 1">, #<ROM::Struct::Post id=4 blog_id=2 user_id=3 name="second post 2" slug="second-post-2" description="second description 2" content="second content 2">]>]>]

# create with aggregate
user_with_profile = user_repo.create_with_profile(
  email: 'third@host.com',
  user_name: 'third',
  profile: {
    first_name: 'third',
    last_name: 'user'
  }
)

# TODO dies with
# rom-mapper-1.2.1/lib/rom/struct.rb:112:in `rescue in method_missing': undefined method `[]=' for #<ROM::Struct::User:0x007fe3ef994a28> (ROM::Struct::MissingAttribute)
# Did you mean?  [] (attribute not loaded?)
# tmp however works as expected. What's causing the issue above? - auto_struct true causes the error above
# what auto_struct does? Need links

binding.pry

p '1'
