require 'docker'
require 'socket'
require 'celluloid/io'
require 'celluloid/autostart'
require 'json'

module Baleen

  class Server
    include Celluloid::IO
    finalizer :shutdown

    def initialize(docker_host: "127.0.0.1", docker_port: 4243, port: 5533)
      Docker.url = "http://#{docker_host}:#{docker_port}"
      @server = TCPServer.new("0.0.0.0", port)
      async.run
    end

    def run
      loop { async.handle_connection @server.accept }
    end

    def shutdown
      @server.close if @server
    end

    def handle_connection(socket)
      loop { handle_request(socket) }

    rescue Exception => ex
      case ex
        when IOError; nil # when trying to close already closed socket
        else
          warn "Unknown exception occured"
          puts ex.inspect
          raise ex
      end
    end

    def handle_request(socket)
      message = socket.gets

      if message.nil?
        socket.close
        return
      end
      msg = parse_request(message)

      case msg
        when Message::Request::ClientDisconnect
          socket.close
        when Message::Request::Cucumber
          manager = RunnerManager.new(socket, msg)
          manager.run
        else
          warn "Received unknown request"
          puts msg.inspect
      end
    end

    def parse_request(message)
      Baleen::Message::Decoder.new(message).decode
    end
  end

end