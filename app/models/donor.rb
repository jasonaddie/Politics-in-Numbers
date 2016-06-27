# Donor class - donation data for parties by give date
class Donor
  include Mongoid::Document
  include Mongoid::Timestamps

  embeds_many :donations, after_add: :calculate_donated_amount, after_remove: :calculate_donated_amount

  NATURE_TYPES = ["private", "organization"]

  field :first_name, type: String
  field :last_name, type: String
  field :tin, type: String
  field :donated_amount, type: Float
  field :nature, type: Integer, default: 0

  validates_presence_of :first_name, :last_name, :tin

  scope :by_donors, -> v { where(:id.in => v) if v.present? }
  #scope :by_party, -> v { where("party_id" => { "$in": v.map{|m| BSON::ObjectId(m) } }) if v.present?}
  scope :by_tin, -> v { where("tin" => v) }
  scope :from_date, -> v { where("donations.give_date" => { "$gte":  v}) if v.present? && v != -1 }
  scope :to_date, -> v { where("donations.give_date" => { "$lte":  v}) if v.present? && v != -1 }
  scope :from_amount, -> v { where("donations.amount" => { "$gte":  v}) if v.present? && v != -1 }
  scope :to_amount, -> v { where("donations.amount" => { "$lte":  v}) if v.present? && v != -1 }
  scope :where_monetary, -> v { where("donations.monetary" => v) if v == true || v == false }
  scope :only_multiple_donations, -> v { where("donations.1" => { "$exists" => true }) if v == true }
  # d.collection.aggregate([{ "$project": { "name": {"$concat": ["$first_name","-","$last_name"] } }}]).first
  #scope :pair_by_donors, -> v { where(:id.in => v).aggregate([{ "$project": { "name": {"$concat": ["$first_name","-","$last_name"] } }}]) if v.present? }
   # d.collection.aggregate([ { "$match": { tin: "17001006279"}}, { "$project": { "name": {"$concat": ["$first_name","-","$last_name"] } }}])
   #

  def calculate_donated_amount(v)
    self.donated_amount = 0
    donations.each{ |e| self.donated_amount += e.amount }
    puts "------------------------#{save}"
  end

  def partial_donated_amount
    donations.sum(:amount)
  end

  def self.sorted
    order_by([[:first_name, :asc], [:last_name, :asc]])
  end



  # def self.by_party(v)
  #   if v.present?
  #     v.map!{|m| BSON::ObjectId(m) }
  #     collection.aggregate([
  #       { "$match": { "donations.party_id": { "$in": v } } },
  #       { "$project": {
  #           first_name: 1,
  #           last_name: 1,
  #           tin: 1,
  #           nature: 1,
  #           donations: {
  #             "$filter": {
  #                 input: "$donations",
  #                 as: "donation",
  #                 cond: { "$$donation.party_id": { "$in": v } }
  #             }
  #           }
  #         }
  #       }
  #     ]).collection.criteria
  #   else
  #     self
  #   end
  # end

  def self.pair_by_donors(ids) #id name
    res = {}
    collection.aggregate([ { "$match": { "_id": { "$in": ids.map{|m| BSON::ObjectId(m) } } } }, { "$project": { "name": {"$concat": ["$first_name"," ","$last_name"] } }}]).each{|d|
      res[d[:_id].to_s] = d[:name]
    }
    res
  end
  def self.filter(params)
    Rails.logger.debug("****************************************#{params}")
    result = []
    options = []
    matches = []
    #projects = []
    conditions = []
    matches.push({ "id": { "$in": params[:donors_id] } }) if params[:donor_ids].present?
    if params[:parties].present?
      tmp = params[:parties].map{|m| BSON::ObjectId(m) }
      matches.push({ "donations.party_id": { "$in": tmp } })
      conditions.push({ "$$donation": { "$$donation.party_id.$in": tmp[0] }});
    end

    tmp = params[:amount][0]
    if tmp.present? && tmp != -1
      matches.push({ "donations.amount": { "$gte": tmp } })
      conditions.push({"$gte": [ "$$donation.amount", tmp ]})
    end

    options.push({ "$match": { "$and": matches } }) if !matches.blank?

    if !conditions.blank?
      options.push({
        "$project": {
          first_name: 1,
          last_name: 1,
          tin: 1,
          nature: 1,
          donations: {
            "$filter": {
              input: "$donations",
              as: "donation",
              # cond: { "$gte": ["$$donation.amount", 5000] }
              cond: { "$and": conditions }
            }
          }
        }
       })
    end

    # sd = dd.collection.aggregate([
    #     { "$match": { "donations.amount": 800 } },
    #    {
    #       "$project": {
    #         first_name: 1,
    #          donations: {
    #             "$filter": {
    #                 input: "$donations",
    #                 as: "donation",
    #                 cond: { "$eq": [ "$$donation.amount", 800 ] }
    #                #cond: { "$$donation": { "$amount": 800 } }
    #             }
    #          }
    #       }
    #    }
    # ])

    Rails.logger.debug("---------------------------------------#{options}-----")
    if !matches.blank? || !conditions.blank?
      result = collection.aggregate(options)
    end
    result
  end
  def self.explore(params)
    limiter = 5

    f = {
      donor_ids: nil,
      parties: nil,
      monetary: nil,
      multiple: nil,
      period: [-1,-1],
      amount: [-1,-1]
    }

    tmp = params[:donor]
    f[:donor_ids] = tmp if tmp.present? && tmp.class == Array && tmp.all?{|t| t.size === 24 }

    tmp = params[:period]
    f[:period] = tmp.map{|t| Time.at(t.to_i/1000) } if tmp.present? && tmp.class == Array && tmp.size == 2 && tmp.all?{|t| t.size == 13 && t.to_i.to_s == t }

    tmp = params[:amount]
    f[:amount] = tmp.map{|t| t.to_i } if tmp.present? && tmp.class == Array && tmp.size == 2 && tmp.all?{|t| t.to_i.to_s == t }

    tmp = params[:party]
    f[:parties] = tmp if tmp.present? && tmp.class == Array && tmp.all?{|t| t.size === 24 }

    tmp = params[:monetary]
    f[:monetary] = tmp == "yes" if tmp == "yes" || tmp == "no"

    f[:multiple] = true if params[:multiple] == "yes"


    data = filter(f)
     Rails.logger.debug("--------------------------------------------#{data.map{|m| m}.length}")
    # donors = Donor
    #         .by_donors(f.donor_ids)
    #         .by_party(f.parties)
    #         .from_date(f.period[0])
    #         .to_date(f.period[1])
    #         .from_amount(f.amount[0])
    #         .to_amount(f.amount[1])
    #         .where_monetary(f.monetary)
    #         .only_multiple_donations(f.multiple)
    #         #.order_by(donated_amount: :desc)

    # chart1 = []
    # chart2 = []
    # table = []
    # total_amount = 0
    # total_donations = 0

    #  Rails.logger.debug("--------------------------------------------#{params[:party]} #{donors.length}")
    # if donor_ids.nil? && parties.nil? # If select anything other than party and donor -> charts show the top 5
    #   chart1 = donors.descending(:donated_amount).limit(limiter).map{|m| { value: m.donated_amount, name: "#{m.first_name} #{m.last_name}" } }

    #   parties = {}
    #   Party.each{|e| parties[e.id] = { value: 0, name: e.title } }
    #   monetary_values = [I18n.t("mongoid.attributes.donation.monetary_values.t"), I18n.t("mongoid.attributes.donation.monetary_values.f")]
    #   nature_values = [I18n.t("mongoid.attributes.donor.nature_values.private"), I18n.t("mongoid.attributes.donor.nature_values.organization")]

    #   donors.each{|e|
    #     total_amount += e.donated_amount
    #     e.donations.each { |ee|
    #       parties[ee.party_id][:value] += ee.amount
    #       total_donations += 1
    #       table.push(["#{ee.id}", "#{e.first_name} #{e.last_name}", nature_values[e.nature], I18n.l(ee.give_date), ee.amount, parties[ee.party_id][:name], monetary_values[ee.monetary ? 0 : 1] ])
    #     }
    #   }
    #   table.unshift([human_attribute_name(:id), human_attribute_name(:name),
    #     human_attribute_name(:nature), human_attribute_name(:give_date),
    #     Donation.human_attribute_name(:amount), Donation.human_attribute_name(:party),
    #     Donation.human_attribute_name(:monetary)])


    #   chart2 = parties.sort_by { |k, v| -1*v[:value] }.first(limiter).map{|k,v| v }

    #  # Rails.logger.debug("--------------------------------------------#{chart1} #{chart2} #{table} #{total_amount} #{total_donations}")
    # elsif donor_ids.nil? && parties.length == 1 # If select 1 party -> top 5 donors for party, last 5 donations for party
    #   chart1 = donors.sort!{ |x,y| y.partial_donated_amount <=> x.partial_donated_amount }.first(limiter).map{|m| { value: m.partial_donated_amount, name: "#{m.first_name} #{m.last_name}" } }
    #   # donors.each{|e|
    #   #   total_amount += e.donated_amount
    #   #   e.donations.each { |ee|
    #   #     # parties[ee.party_id][:value] += ee.amount
    #   #     total_donations += 1
    #   #     # table.push(["#{ee.id}", "#{e.first_name} #{e.last_name}", nature_values[e.nature], I18n.l(ee.give_date), ee.amount, parties[ee.party_id][:name], monetary_values[ee.monetary ? 0 : 1] ])
    #   #   }
    #   # }

    #   Rails.logger.debug("--------------------------------------------#{chart1} #{chart2} #{table} #{total_amount} #{total_donations}")
    # end





    # donor_pairs = donor_ids.present? ? Donor.pair_by_donors(donor_ids) : []



    # { data: donors, donor_info: donor_pairs,  }

{}

    #     What happens when filters are selected (table always show full results):
#

# If select > 1 party -> top 5 donors for parties, total donations for selected parties
# If select 1 donor-> last 5 donations for donor, top 5 parties donated to
# If select > 1 donor-> total donations for each donor, top 5 parties donated to

#     # "donation"=>{"donor"=>["574d9379fbb6bd0313000007", "574d9379fbb6bd0313000014"],
    #  "period"=>["1464724800000", "1464897600000"],
    #   "amount"=>["100", "500"],
    #    "party"=>["5748093cfbb6bd3781000016", "5748093cfbb6bd3781000027"],
    #     "type"=>"monetary",
    #      "multiple"=>"yes"},
    #       "locale"=>"en"}
    #res = Donor.sorted_by_amount.limit(5).map{|m| { value: m.amount, name: "#{m.first_name} #{m.last_name}" } }
    # require 'digest'
    # { data: donors, id: Digest::MD5.hexdigest(["d",donor_ids,period,amount,parties,monetary,multiple].join(";"))}
  end
  # def self.validate_params(params)

  # end

  # def top(params)
  # end

end
