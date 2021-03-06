require 'yajl/json_gem'

module Tail

  def _tail(options)
    amqp_url = options[:url]

    amqp_user = options[:user]
    amqp_password = options[:password]
    amqp_vhost = options[:vhost]
    amqp_port = options[:port]
    amqp_host = options[:host]
    amqp_ssl = options[:ssl]

    exchange_name = options[:exchange]
    exchange_type = options[:exchange_type]
    persistent = options[:persistent]
    durable = options[:durable]
    auto_delete = options[:autodelete]
    routing_key = options[:key]
    metafields = options[:meta].split(',')

    begin
      #connection = AMQP.connect(AMQP_OPTS.merge(:username => "amqp_gem", :password => "amqp_gem_password", :vhost => "amqp_gem_testbed"))
      settings= { :host =>  amqp_host, :vhost => amqp_vhost, :port => amqp_port,
                  :user => amqp_user, :password => amqp_password ,
                  :ssl => amqp_ssl }

      # Aqmp url can override settings
      unless amqp_url.nil?
        settings = aqmp_url
      end

      AMQP.start(settings) do |connection, open_ok|
        channel = AMQP::Channel.new(connection, :auto_recovery => true)

        channel.queue("", :auto_delete => auto_delete, :peristent => persistent , :durable => durable)   do |queue, declare_ok|
          queue.bind(exchange_name, :routing_key => routing_key)
          queue.subscribe do |payload|
            parsed_message = JSON.parse(payload)
            result = Array.new

            metafields.each do |metafield|
              result << parsed_message["@#{metafield}"]
            end

            output = case options[:format]
                     when 'csv' then result.to_csv({:col_sep => options[:delim]})
                     when 'json' then result.to_json
                     when 'plain' then result.join(options[:delim])
                     end

            puts output
            result = []
          end
        end
      end
    rescue AMQP::PossibleAuthenticationFailureError => ex
      puts "Possible Authentication error:\nthe AMQP connection URL used is #{amqp_url}\n\nDetail Info:\n#{ex}"
      exit -1
    rescue Exception => ex
      puts "Error occured: #{ex}"
      exit -1
    end
    trap("INT") { puts "Shutting down..."; connection.close { EM.stop };exit }
  end
end
