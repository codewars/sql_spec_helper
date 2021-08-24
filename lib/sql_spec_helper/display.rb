require 'json'

class SqlSpecHelper
  module Display
    class << self
      def table(data, label: "Table", tab: false, allow_preview: false)
        print(tab ? "TAB" : "LOG", data.to_json, mode: "TABLE", label: label)
        prop("preview", true) if allow_preview && data.count > 10
      end

      def daff_table(data, label: "Daff", tab: false, allow_preview: false)
        print(tab ? "TAB" : "LOG", data.to_json, mode: "DAFF", label: label)
        prop("preview", true) if allow_preview && data.count > 10
      end

      def log(msg, label = "", mode = "")
        print('LOG', msg, mode: mode, label: label)
      end

      def status(msg)
        print("STATUS", msg)
      end

      private

      def prop(name, value)
        print("PROP", value)
      end

      def print(type, msg, mode: "", label: "")
        puts format_msg("<#{type.upcase}:#{mode.upcase}:#{label}>#{msg}")
      end

      def format_msg(msg)
        msg.gsub("\n", '<:LF:>')
      end
    end
  end
end
