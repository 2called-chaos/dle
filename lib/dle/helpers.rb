module Dle
  module Helpers
    BYTE_UNITS = %W(TiB GiB MiB KiB B).freeze

    def human_filesize(s)
      s = s.to_f
      i = BYTE_UNITS.length - 1
      while s > 512 && i > 0
        i -= 1
        s /= 1024
      end
      ((s > 9 || s.modulo(1) < 0.1 ? '%d' : '%.1f') % s) + ' ' + BYTE_UNITS[i]
    end

    def human_number(n)
      n.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse
    end

    def notifier &block
      OpenStruct.new.tap do |o|
        o.callback = block

        def o.perform &block
          t = Thread.new(&callback)
          begin
            block.call(t)
          ensure
            t.kill
          end
        end
      end
    end

    def render_table table, headers = []
      [].tap do |r|
        col_sizes = table.map{|col| col.map(&:to_s).map(&:length).max }
        headers.map(&:length).each_with_index do |length, header|
          col_sizes[header] = [col_sizes[header] || 0, length || 0].max
        end

        # header
        if headers.any?
          r << [].tap do |line|
            col_sizes.count.times do |col|
              line << headers[col].ljust(col_sizes[col])
            end
          end.join(" | ")
          r << "".ljust(col_sizes.inject(&:+) + ((col_sizes.count - 1) * 3), "-")
        end

        # records
        table[0].count.times do |row|
          r << [].tap do |line|
            col_sizes.count.times do |col|
              line << "#{table[col][row]}".ljust(col_sizes[col])
            end
          end.join(" | ")
        end
      end
    end
  end
end
