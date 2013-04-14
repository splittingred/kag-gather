require 'bundler/setup'
require 'socket'
require 'trollop'
opts = Trollop::options do
  opt :host, "Hostname", :type => :string
  opt :port, "Port", :type => :int, :default => 50301
  opt :rcon_password, "RCON Password", :default => "1", :type => :string
end


def socket_get(socket)
  msg = ""
  begin
    ready = IO.select([socket],nil,nil,2)
    if ready
      msg = socket.gets
    else
      msg = ''
    end
  rescue Exception => e
    puts e.message
    puts e.backtrace.join("\n")
  end
  msg
end
def socket_put(socket,msg)
  socket.puts(msg+"\r\n")
end


puts "[Server] Attempting to connect via socket to #{opts[:host]}:#{opts[:port].to_s}"
socket = TCPSocket.new(opts[:host],opts[:port].to_i)
socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
if socket
  success = false
  begin
    socket_put(socket,opts[:rcon_password])
    z = socket_get(socket)
    puts "[RCON] "+z.to_s
    z.include?("now authenticated")
    success = true
  rescue Exception => e
    puts e.message
    puts e.backtrace.join("\n")
  end
  puts "[Server] Connected! #{success.to_s}"
else
  puts "[Server] Could not establish TCP socket to connect"
end
