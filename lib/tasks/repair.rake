require 'fileutils'

### BEFORE RE-METHODS CHECK FILE VERSIONS

namespace :repair do
  desc "Repair parts"
  task :category => :environment do |t, args|

    categories_cell = []
    categories_data = []
    up_path = Rails.public_path.join("upload")
    workbook = RubyXL::Parser.parse("#{up_path}/categories.xlsx")
    cat_id = 1
    level = 0
    parenting = [nil, nil, nil, nil, nil]
    orders = [0, 0, 0, 0, 0, 0]
    parent_id = nil
    versions = [1,2,3]
    ln = 12 + versions.length*2

    cat_info = {}
    Category.non_virtual.each{|c|
      cat_cells = []
      cat_codes = []
      if c.forms.present?
        c.forms.each_with_index { |ee, ee_index|
          cat_cells << "#{ee}/#{c.cells[ee_index]}"
          cat_codes << "#{c.codes[ee_index]}" if c.codes.present?
        }
        cat_cells = cat_cells.join("&")
        cat_codes = cat_codes.join(",")
        cat_info["#{cat_cells}#{cat_codes}"] = c.id
      end
    }

    workbook[0].each_with_index { |row, row_i|
      next if row_i == 0
      if row && row.cells
        cells = Array.new(ln, nil) # Level0  Level1  Level2  Level3  Level4  Cells_V1 Codes_V1 Details Short Alias ka ru Cells_V2 Codes_V2 Cells_V3 Codes_V3
        row.cells.each_with_index do |c, c_i|
          if c && c.value.present?
            cells[c_i] = c.value.class != String ? c.value : c.value.to_s.strip
          end
        end

        has_level = false
        (0..4).step(1) { |lvl|
          if cells[lvl].present?
            if lvl > level
              orders[lvl] = 1
            else
              orders[lvl] += 1
            end
            level = lvl
            has_level = true
          end
        }
        next if !has_level

        parenting[0] = cat_id if level == 0

        parenting[level] = cat_id
        parent_id = parenting[level-1].present? && level != 0 ? parenting[level-1] : nil

        pointers = []
        #puts "--------------------------#{cells[level].strip}"
        str_cat_id = ""
        versions.each_with_index{|ver,ver_i|
          tmp_index = ver_i == 0 ? 5 : 10 + ver_i*2
          forms_and_cells = Category.parse_formula(cells[tmp_index])
          #(puts "Form or Cell or Both are empty"; exit) if forms_and_cells.nil? && ver_i == 0

          codes = Category.parse_codes(cells[tmp_index+1])
          #(puts "Code is empty";) if codes.nil? && ver_i == 0
          forms_tmp = forms_and_cells.present? ? forms_and_cells[0] : nil
          cells_tmp = forms_and_cells.present? ? forms_and_cells[1] : nil
          codes_tmp = codes.present? ? codes : nil
          pointers << { forms: forms_tmp, cells: cells_tmp, codes: codes_tmp, version: ver } if forms_tmp.present? || cells_tmp.present? || codes_tmp.present?
          str_cat_id = "#{cells[tmp_index]}#{cells[tmp_index+1]}" if ver_i == 0

        }

        dt = cells[7].present? ? cells[7] : nil
        tmp = { tmp_id: cat_id, str_cat_id: str_cat_id, virtual: false, level: level, parent_id: parent_id, title_translations: { en: cells[level].strip }.merge!(cells[10].present? ? {ka: cells[10].strip} : { }).merge!(cells[11].present? ? {ru: cells[11].strip} : { }), detail_id: dt, order: orders[level], sym: cells[9], pointers: pointers,
          blah_id: pointers.map{|p| "#{p[:version]}#{p[:forms].join('')}#{p[:cells].join('')}#{p[:codes].present? ? p[:codes].join('') : ''}"}.join(''),
          order_n: cells[16]

         }

        categories_cell << (cells << cat_id)
        categories_data << tmp
        cat_id += 1
      end
    }

    # puts "#{categories_data.inspect}"

    Category.each{|c|
      pp = c.pointers.map{|p| "#{p[:version]}#{p[:forms].join('')}#{p[:cells].join('')}#{p[:codes].present? ? p[:codes].join('') : ''}"}.join('')
      cat = categories_data.select{|s| s[:blah_id] == pp }
      if cat.length > 1
        puts 'error'
      else
        cat = cat.first
        # puts "#{cat[:order_n]}#{cat[:title_translations][:en]}"
        c.order = cat[:order_n]
        c.save

      end
      puts 'done'
    }
  end
end