Server.seed do |s|
  s.id          = 1
  s.name        = 'server1-euro'
  s.ip          = '1.2.3.1'
  s.port        = '10001'
  s.password    = '1'
  s.rcon_password = '12345'
  s.region      = 'EU'
  s.in_use      = 0
  s.status      = 'active'
end

Server.seed do |s|
  s.id          = 2
  s.name        = 'server2-euro'
  s.ip          = '1.2.3.2'
  s.port        = '20002'
  s.password    = '2'
  s.rcon_password = '12345'
  s.region      = 'EU'
  s.in_use      = 0
  s.status      = 'active'
end

Server.seed do |s|
  s.id          = 3
  s.name        = 'server3-us'
  s.ip          = '1.2.3.3'
  s.port        = '30003'
  s.password    = '3'
  s.rcon_password = '12345'
  s.region      = 'US'
  s.in_use      = 0
  s.status      = 'active'
end

Server.seed do |s|
  s.id          = 4
  s.name        = 'server4-aus'
  s.ip          = '1.2.3.4'
  s.port        = '40004'
  s.password    = '4'
  s.rcon_password = '12345'
  s.region      = 'AUS'
  s.in_use      = 0
  s.status      = 'active'
end
