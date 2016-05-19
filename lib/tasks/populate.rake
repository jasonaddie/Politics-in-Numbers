namespace :populate do
  desc "Read and upload all annual files"
  task :annual => :environment do |t, args|

    lg = Logger.new File.new('log/tasks/populate.log', 'w')
    lg.formatter = proc do |severity, datetime, progname, msg|
      "#{msg}\n"
    end

    Dataset.destroy_all # only for dev

    I18n.locale = :en

    upload_path = Rails.public_path.join("upload/annuals")
    files = []
    filenames = []
    Dir.entries(upload_path).each {|f|
      if File.file?("#{upload_path}/#{f}") && f != ".gitkeep"
        files << "#{upload_path}/#{f}"
        filenames << f.to_s.gsub(".xlsx","")
      end
    }


    files.each_with_index {|f,f_i|
      lg.info filenames[f_i]

      tmp_id = filenames[f_i].split(".")
      year = tmp_id[1]
      tmp_id = tmp_id[0]

      prt = Party.find_by(tmp_id: tmp_id)
      per = Period.find_or_create_by({start_date: Date.strptime("01.01.#{year}", "%d.%m.%Y"), type: Period.type_is(:annual)})

      dataset = nil
      if prt.present? && per.present?
        party_id = prt._id
        period_id = per._id
        dataset = Dataset.new({party_id: party_id, period_id: period_id, source: File.open(f) })
        dataset.save
        Job.dataset_file_process(dataset._id, User.all[1]._id, []) # [admin_dataset_url(id: "_id")])
      else
        lg.info "File #{filenames[f_i]}, Party for id #{tmp_id} is missing" if prt.nil?
        lg.info "File #{filenames[f_i]}, Period for id #{year} is missing" if per.nil?
        next
      end

      lg.close
    }
  end

  desc "Read and upload all election files"
  task :election => :environment do |t, args|

    lg = Logger.new File.new('log/tasks/populate_election.log', 'w')
    lg.formatter = proc do |severity, datetime, progname, msg|
      "#{msg}\n"
    end

    Dataset.destroy_all # only for dev

    I18n.locale = :en

    files = []
    filenames = []
    upload_path = Rails.public_path.join("upload/elections/2013")
    Dir.entries(upload_path).each {|f|
      if File.file?("#{upload_path}/#{f}") && f != ".gitkeep"
        files << "#{upload_path}/#{f}"
        filenames << f.to_s.gsub(".xlsx","")
      end
    }
    upload_path = Rails.public_path.join("upload/elections/2014")
    Dir.entries(upload_path).each {|f|
      if File.file?("#{upload_path}/#{f}") && f != ".gitkeep"
        files << "#{upload_path}/#{f}"
        filenames << f.to_s.gsub(".xlsx","")
      end
    }

    puts files.length
      ps = []
    files.each_with_index {|f,f_i|
      lg.info filenames[f_i]

      tmp_id = filenames[f_i].split("_")
      periods = tmp_id[1].split("-")
      start_date = Date.strptime(periods[0], '%d.%m.%Y')
      end_date = Date.strptime(periods[1], '%d.%m.%Y')
      #puts "#{periods.inspect}:
      # ps |= ["#{start_date} #{end_date}"]
      tmp_id = tmp_id[0]

      prt = Party.find_by(tmp_id: tmp_id)
      per = Period.find_or_create_by({ start_date: start_date, end_date: end_date, type: Period.type_is(:election) })

      dataset = nil
      if prt.present? && per.present?
        dataset = Dataset.new({party_id: prt._id, period_id: period_id = per._id, source: File.open(f) })
        dataset.save
        Job.dataset_file_process(dataset._id, User.all[1]._id, [])
      else
        lg.info "File #{filenames[f_i]}, Party for id #{tmp_id} is missing" if prt.nil?
        lg.info "File #{filenames[f_i]}, Period for id #{tmp_id} is missing" if per.nil?
        next
      end

    }
    # puts ps.inspect
    lg.close
  end
end