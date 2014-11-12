module Rack
  class TrafficLogger
    class SimpleFormatter

      def initialize(color: false, pretty_print: false)
        @color = color
        @pretty_print = pretty_print
      end

      def format(input)
        case input[:event]
          when 'request' then format_request input
          when 'response' then format_response input
          else nil
        end
      end

      private

      REQUEST_TEMPLATES = {
          true => "\e[35m:verb \e[36m:path:qs\e[0m :http",
          false => ':verb :path:qs :http'
      }

      RESPONSE_TEMPLATES = {
          true => ":http \e[:color:code \e[36m:status\e[0m",
          false => ':http :code :status'
      }

      HEADER_TEMPLATES = {
          true => "\n\e[4m:key\e[0m: :val\e[34m:extra\e[0m",
          false => "\n:key: :val:extra"
      }

      BASIC_AUTH_PATTERN = /^basic ([a-z\d+\/]+={0,2})$/i

      def format_request(input)
        result = render REQUEST_TEMPLATES[@color],
                        verb: input['REQUEST_METHOD'],
                        path: input['PATH_INFO'],
                        qs: (q = input['QUERY_STRING']).empty? ? '' : "?#{q}",
                        http: input['HTTP_VERSION'] || 'HTTP/1.1'
        result << format_headers(env_request_headers input)
        result << format_body(input, input['CONTENT_TYPE'] || input['HTTP_CONTENT_TYPE'])
      end

      def format_response(input)
        result = render RESPONSE_TEMPLATES[@color],
                        http: input['http_version'] || 'HTTP/1.1',
                        code: input['status_code'],
                        status: input['status_name']
        headers = input['headers']
        result << format_headers(headers) if headers
        result << format_body(input, headers && headers['Content-Type'])
      end

      def render(template, data)
        template.gsub(/:(\w+)/) { data[$1.to_sym] }
      end

      def format_headers(headers)
        headers = HeaderHash.new(headers) unless HeaderHash === headers
        headers.map do |k, v|
          data = {key: k, val: v}
          data[:extra] = " #{$1.unpack('m').first}" if k == 'Authorization' && v =~ BASIC_AUTH_PATTERN
          render HEADER_TEMPLATES[@color], data
        end.join
      end

      def format_body(input, content_type)
        body = input['body_base64'] ? input['body_base64'].unpack('m').first : input['body']
        return '' unless body
        body = JSON.pretty_generate(JSON.parse body) rescue body if @pretty_print && content_type =~ %r{^application/json(;|$)}
        if body =~ /[^[:print:]\r\n\t]/
          length = body.bytes.length
          body = "<BINARY (#{length} byte#{length == 1 ? '' : 's'})>"
        end
        "\n\n#{body}"
      end

      def env_request_headers(env)
        env.select { |k, _| k =~ /^(CONTENT|HTTP)_(?!VERSION)/ }.map { |(k, v)| [k.sub(/^HTTP_/, ''), v] }.to_h
      end

    end
  end
end
