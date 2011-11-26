# encoding: utf-8
class User < ActiveRecord::Base
  extend ActiveHash::Associations::ActiveRecordExtensions

  belongs_to   :shop
  has_many     :articles       , dependent: :destroy
  has_many     :permissions    , dependent: :destroy

  # Include default devise modules. Others available are:
  # :encryptable, :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :token_authenticatable,
         :recoverable, :rememberable, :trackable
         #, :validatable # 校验要限制在shop范围下，因此不能使用devise自带校验 issue#287

  # Setup accessible (or protected) attributes for your model
  attr_accessible :id, :email, :password, :password_confirmation, :remember_me,:name, :shop_attributes,:phone, :bio,  :receive_announcements,:avatar_image

  validates_presence_of   :email
  validates :email, uniqueness: {scope: :shop_id}, format: {with: /\A[^@]+@([^@\.]+\.)+[^@\.]+\z/ }, if: :email_changed?
  validates_presence_of     :password, if: :password_required?
  validates_confirmation_of :password, if: :password_required?
  validates_length_of       :password, within: 6..20, allow_blank: true
  validates_size_of :avatar_image, maximum: 8000.kilobytes
  validates_property :mime_type, of: :avatar_image, in: %w(image/jpeg image/jpg image/png image/gif), message:  "格式不正确"
  before_create :ensure_authentication_token # 生成login token，只使用一次
  accepts_nested_attributes_for :shop
  image_accessor :avatar_image do
    storage_path{ |image|
      "#{self.shop_id}/users/#{self.id}/#{image.basename}_#{rand(1000)}.#{image.format}"
    }
  end

  def is_admin?
    admin
  end

  def default_avatar_image_url
    self.avatar_image_uid? ? self.avatar_image.thumb('50x50').url : 'avatar.jpg'
  end

  def after_token_authentication # 登录后取消token
    self.authentication_token = nil
  end

  after_create do
    Subscribe.create shop: shop, user: self #增加商店提醒给用户
    KeyValues::Resource.all.each do |resource|
      Permission.create user_id: self.id  , resource_id: resource.id
    end
  end

  protected
  def self.find_for_database_authentication(warden_conditions) # http://j.mp/ogzr2M 重载devise方法，校验域名
    conditions = warden_conditions.dup
    host = conditions.delete(:host)
    shop_domain = ShopDomain.from(host)
    where(conditions).where(shop_id: shop_domain.shop_id).first
  end

  def password_required? # copy from devise
    !persisted? || !password.nil? || !password_confirmation.nil?
  end

end

Blog
