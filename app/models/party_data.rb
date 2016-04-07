# PartyData - trace category and detail data for party
# based on specific period
class PartyData
  include Mongoid::Document
  include Mongoid::Timestamps

  embeds_many :category_datas
  embeds_many :detail_datas
  #belongs_to :party

  field :party_id, type: BSON::ObjectId
  field :period_id, type: BSON::ObjectId

  validates_presence_of :party_id, :period_id
  accepts_nested_attributes_for :category_datas, :detail_datas

  def party
    Party.find(party_id)
  end

  def period
    Period.find(period_id)
  end
end
