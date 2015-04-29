%% The ID for the server PID.
-define (SERVER, snake_server).

%% The ID of the TCP handler PID.
-define (TCP, tcp_handler).

%% The ID of the UDP handler PID.
-define (UDP, udp_handler).

%% The default TCP settings for use when creating a socket to listen on.
-define (TCP_SETTINGS, [binary, {active, false}]).

%% The default UDP settings for use when opening UDP sockets.
-define (UDP_SETTINGS, [binary, {active, false}]).

%% The maximum time receive packets from connections.
-define (TIMEOUT, infinity).

%% The ID of the clients ETS.
-define (CLIENTS, snake_clients).

%% The settings used for the clients ETS.
-define (CLIENTS_SETTINGS, [set, protected, named_table, {write_concurrency, false}, {read_concurrency, true}]).

%% The maximum number of clients the server accepts.
-define (MAX_CLIENTS, 4).